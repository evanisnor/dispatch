#!/usr/bin/env bash
# watch-pr-status.sh — poll PR state and CI/review status
# Usage: watch-pr-status.sh <pr-url-or-number>
#
# Outputs only state-change events — never full API response payloads.
#
# Exit codes:
#   0 = approved + all CI checks pass
#   1 = changes requested by reviewer
#   2 = CI failure
#   3 = polling timeout

set -euo pipefail

PR="${1:-}"
if [[ -z "${PR}" ]]; then
  echo "Usage: watch-pr-status.sh <pr-url-or-number>" >&2
  exit 3
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

POLL_INTERVAL=30
TIMEOUT_SECONDS=$(( POLLING_TIMEOUT_MINUTES * 60 ))
ELAPSED=0
LAST_STATE=""

echo "Watching PR: ${PR}"
echo "Timeout: ${POLLING_TIMEOUT_MINUTES} minutes"

while true; do
  # Fetch only required fields — never inject full payloads into agent context
  RESULT="$(gh pr view "${PR}" \
    --json state,reviewDecision,statusCheckRollup \
    2>/dev/null || echo '{"state":"UNKNOWN","reviewDecision":null,"statusCheckRollup":[]}')"

  STATE="$(printf '%s\n' "${RESULT}" | jq -r '.state')"
  REVIEW_DECISION="$(printf '%s\n' "${RESULT}" | jq -r '.reviewDecision // "NONE"')"

  # Summarise CI checks: count by conclusion, never emit raw log text
  CI_SUMMARY="$(printf '%s\n' "${RESULT}" | jq -r '
    .statusCheckRollup
    | if length == 0 then "no-checks"
      else
        group_by(.conclusion // .status)
        | map("\(.[0].conclusion // .[0].status):\(length)")
        | join(" ")
      end
  ' 2>/dev/null || echo "unknown")"

  CI_FAILURES="$(printf '%s\n' "${RESULT}" | jq -r '
    [.statusCheckRollup[] | select(.conclusion == "FAILURE" or .conclusion == "TIMED_OUT")]
    | length
  ' 2>/dev/null || echo "0")"

  CI_PENDING="$(printf '%s\n' "${RESULT}" | jq -r '
    [.statusCheckRollup[] | select(.conclusion == null and .status != "COMPLETED")]
    | length
  ' 2>/dev/null || echo "0")"

  # Only emit on state change
  CURRENT_STATE="${STATE}:${REVIEW_DECISION}:${CI_SUMMARY}"
  if [[ "${CURRENT_STATE}" != "${LAST_STATE}" ]]; then
    echo "State change: state=${STATE} review=${REVIEW_DECISION} ci=${CI_SUMMARY}"
    LAST_STATE="${CURRENT_STATE}"
  fi

  # Terminal: approved + all CI pass
  if [[ "${REVIEW_DECISION}" == "APPROVED" && "${CI_FAILURES}" == "0" && "${CI_PENDING}" == "0" ]]; then
    echo "Result: approved and CI passing"
    exit 0
  fi

  # Terminal: changes requested
  if [[ "${REVIEW_DECISION}" == "CHANGES_REQUESTED" ]]; then
    echo "Result: changes requested"
    exit 1
  fi

  # Terminal: CI failure
  if [[ "${CI_FAILURES}" -gt 0 ]]; then
    echo "Result: CI failure (${CI_FAILURES} check(s) failed)"
    exit 2
  fi

  # Terminal: PR closed/merged unexpectedly
  if [[ "${STATE}" == "MERGED" || "${STATE}" == "CLOSED" ]]; then
    echo "Result: PR ${STATE}"
    exit 0
  fi

  ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  if [[ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]]; then
    echo "Result: timeout after ${POLLING_TIMEOUT_MINUTES} minutes"
    exit 3
  fi

  sleep "${POLL_INTERVAL}"
done
