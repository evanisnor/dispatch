#!/usr/bin/env bash
# check-merge-queue.sh — single-shot check of merge queue status for a PR
# Usage: check-merge-queue.sh <pr-url-or-number>
#
# State is persisted in /tmp/dispatch-mq-status-<pr-number>.yaml between invocations.
#
# Exit codes:
#   0 = merged successfully
#   1 = conflicts detected
#   2 = CI failure (merge blocked)
#   3 = ejected (PR closed)
#   4 = still in queue

set -euo pipefail

PR="${1:-}"
if [[ -z "${PR}" ]]; then
  echo "Usage: check-merge-queue.sh <pr-url-or-number>" >&2
  exit 4
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

# Extract PR number for state file naming
PR_NUMBER="$(printf '%s' "${PR}" | grep -oE '[0-9]+$' || echo "${PR}")"
STATE_FILE="/tmp/dispatch-mq-status-${PR_NUMBER}.yaml"

# Initialize state file if absent
if [[ ! -f "${STATE_FILE}" ]]; then
  printf 'last_state: ""\nstate_since: 0\n' > "${STATE_FILE}"
fi

LAST_STATE="$(yq e '.last_state' "${STATE_FILE}" 2>/dev/null || echo "")"
STATE_SINCE="$(yq e '.state_since' "${STATE_FILE}" 2>/dev/null || echo "0")"
NOW="$(date +%s)"

# Fetch only the fields we need — never inject full API payloads into context
RESULT="$(gh pr view "${PR}" --json mergeStateStatus,state,merged 2>/dev/null || echo '{"mergeStateStatus":"UNKNOWN","state":"UNKNOWN","merged":false}')"

STATE="$(printf '%s' "${RESULT}" | jq -r '.state')"
MERGE_STATE="$(printf '%s' "${RESULT}" | jq -r '.mergeStateStatus')"
MERGED="$(printf '%s' "${RESULT}" | jq -r '.merged')"

CURRENT_STATE="${STATE}:${MERGE_STATE}"

cleanup_state_file() {
  rm -f "${STATE_FILE}"
}

if [[ "${CURRENT_STATE}" != "${LAST_STATE}" ]]; then
  echo "State change: state=${STATE} mergeStateStatus=${MERGE_STATE}"
  # Update state file with new state and reset timer
  yq e -n ".last_state = \"${CURRENT_STATE}\" | .state_since = ${NOW}" > "${STATE_FILE}"
else
  # State unchanged — check for timeout
  if [[ "${STATE_SINCE}" -gt 0 ]]; then
    ELAPSED_MINUTES=$(( (NOW - STATE_SINCE) / 60 ))
    TIMEOUT_MINUTES="${POLLING_TIMEOUT_MINUTES:-60}"
    if [[ "${ELAPSED_MINUTES}" -ge "${TIMEOUT_MINUTES}" ]]; then
      echo "TIMEOUT state unchanged for ${ELAPSED_MINUTES} minutes"
    fi
  fi
fi

# Terminal states
if [[ "${MERGED}" == "true" ]] || [[ "${STATE}" == "MERGED" ]]; then
  echo "Result: merged"
  cleanup_state_file
  exit 0
fi

if [[ "${STATE}" == "CLOSED" ]]; then
  echo "Result: ejected (PR closed)"
  cleanup_state_file
  exit 3
fi

if [[ "${MERGE_STATE}" == "CONFLICTING" ]]; then
  echo "Result: conflicts detected"
  cleanup_state_file
  exit 1
fi

if [[ "${MERGE_STATE}" == "BLOCKED" ]]; then
  echo "Result: CI failure (merge blocked)"
  cleanup_state_file
  exit 2
fi

# Still in queue
exit 4
