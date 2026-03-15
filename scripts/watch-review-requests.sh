#!/usr/bin/env bash
# watch-review-requests.sh — poll GitHub for incoming PR review requests
#
# Emits state-change events only:
#   NEW_REVIEW_REQUEST <pr-url> <pr-number> <title> <author>
#   REVIEW_REMOVED <pr-url> <pr-number>
#
# State is persisted in /tmp/dispatch-review-state.yaml (yq required).
#
# Exit codes:
#   0 = normal exit (SIGTERM or no more reviews)
#   3 = polling timeout

set -euo pipefail

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

STATE_FILE="/tmp/dispatch-review-state.yaml"
POLL_INTERVAL=30
TIMEOUT_SECONDS=$(( POLLING_TIMEOUT_MINUTES * 60 ))
ELAPSED=0

# Initialize state file if absent
if [[ ! -f "${STATE_FILE}" ]]; then
  printf 'reviews: []\n' > "${STATE_FILE}"
fi

echo "Watching for review requests (timeout: ${POLLING_TIMEOUT_MINUTES} minutes)"

while true; do
  # Fetch PRs where the current user is a requested reviewer
  # Only extract fields needed — never pass full API payload to agent context
  RAW="$(gh pr list --review-requested @me \
    --json number,title,url,author \
    --jq '.[] | [.number | tostring, .title, .url, .author.login] | @tsv' \
    2>/dev/null || true)"

  # Build a set of currently-seen PR numbers
  declare -A CURRENT_PRS=()
  while IFS=$'\t' read -r NUMBER TITLE URL AUTHOR; do
    [[ -z "${NUMBER}" ]] && continue
    CURRENT_PRS["${NUMBER}"]="${URL}	${TITLE}	${AUTHOR}"
  done <<< "${RAW}"

  # Detect new review requests (present now, not in state file)
  for NUMBER in "${!CURRENT_PRS[@]}"; do
    KNOWN="$(yq e ".reviews[] | select(.number == \"${NUMBER}\") | .number" "${STATE_FILE}" 2>/dev/null || true)"
    if [[ -z "${KNOWN}" ]]; then
      IFS=$'\t' read -r URL TITLE AUTHOR <<< "${CURRENT_PRS[${NUMBER}]}"
      echo "NEW_REVIEW_REQUEST ${URL} ${NUMBER} ${TITLE} ${AUTHOR}"
      # Record in state file
      yq e ".reviews += [{\"number\": \"${NUMBER}\", \"url\": \"${URL}\", \"title\": \"${TITLE}\", \"author\": \"${AUTHOR}\"}]" \
        "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
    fi
  done

  # Detect removed review requests (in state file, not present now)
  KNOWN_NUMBERS="$(yq e '.reviews[].number' "${STATE_FILE}" 2>/dev/null || true)"
  while IFS= read -r NUMBER; do
    [[ -z "${NUMBER}" ]] && continue
    if [[ -z "${CURRENT_PRS[${NUMBER}]+x}" ]]; then
      URL="$(yq e ".reviews[] | select(.number == \"${NUMBER}\") | .url" "${STATE_FILE}")"
      echo "REVIEW_REMOVED ${URL} ${NUMBER}"
      # Remove from state file
      yq e "del(.reviews[] | select(.number == \"${NUMBER}\"))" \
        "${STATE_FILE}" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "${STATE_FILE}"
    fi
  done <<< "${KNOWN_NUMBERS}"

  unset CURRENT_PRS

  # Check timeout
  ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  if [[ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]]; then
    echo "Result: timeout after ${POLLING_TIMEOUT_MINUTES} minutes"
    exit 3
  fi

  sleep "${POLL_INTERVAL}"
done
