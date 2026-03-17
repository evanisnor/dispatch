#!/usr/bin/env bash
# check-pr-status.sh — single-shot check of PR state and CI/review status
# Usage: check-pr-status.sh <pr-url-or-number>
#
# Outputs only state-change events — never full API response payloads.
# State is persisted in /tmp/dispatch-pr-status-<pr-number>.yaml between invocations.
#
# Exit codes:
#   0 = approved + all CI checks pass
#   1 = changes requested by reviewer
#   2 = CI failure
#   3 = PR closed/merged
#   4 = still in progress (no terminal state reached)

set -euo pipefail

PR="${1:-}"
if [[ -z "${PR}" ]]; then
  echo "Usage: check-pr-status.sh <pr-url-or-number>" >&2
  exit 4
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

# Extract PR number for state file naming
PR_NUMBER="$(printf '%s' "${PR}" | grep -oE '[0-9]+$' || echo "${PR}")"
STATE_FILE="/tmp/dispatch-pr-status-${PR_NUMBER}.yaml"

# Initialize state file if absent
if [[ ! -f "${STATE_FILE}" ]]; then
  printf 'last_state: ""\nstate_since: 0\n' > "${STATE_FILE}"
fi

LAST_STATE="$(yq e '.last_state' "${STATE_FILE}" 2>/dev/null || echo "")"
STATE_SINCE="$(yq e '.state_since' "${STATE_FILE}" 2>/dev/null || echo "0")"
NOW="$(date +%s)"

# Fetch only required fields — never inject full payloads into agent context
RESULT="$(gh pr view "${PR}" \
  --json state,reviewDecision,statusCheckRollup \
  2>/dev/null || echo '{"state":"UNKNOWN","reviewDecision":null,"statusCheckRollup":[]}')"

STATE="$(printf '%s\n' "${RESULT}" | jq -r '.state')"
REVIEW_DECISION="$(printf '%s\n' "${RESULT}" | jq -r '.reviewDecision // "NONE"')"

# Summarise CI checks: count by conclusion, never emit raw log text
# StatusContext objects have .state (not .conclusion/.status), so normalise both types
CI_SUMMARY="$(printf '%s\n' "${RESULT}" | jq -r '
  .statusCheckRollup
  | map(. + {_label: (
      if .conclusion != null then .conclusion
      elif .status != null then .status
      elif .state != null then .state
      else "UNKNOWN"
      end
    )})
  | if length == 0 then "no-checks"
    else
      group_by(._label)
      | map("\(.[0]._label):\(length)")
      | join(" ")
    end
' 2>/dev/null || echo "unknown")"

CI_FAILURES="$(printf '%s\n' "${RESULT}" | jq -r '
  [.statusCheckRollup[] | select(
    .conclusion == "FAILURE" or .conclusion == "TIMED_OUT"
    or .state == "FAILURE" or .state == "ERROR"
  )]
  | length
' 2>/dev/null || echo "0")"

CI_PENDING="$(printf '%s\n' "${RESULT}" | jq -r '
  [.statusCheckRollup[] | select(
    (.conclusion == null and .status != null and .status != "COMPLETED")
    or (.state == "PENDING" or .state == "EXPECTED")
  )]
  | length
' 2>/dev/null || echo "0")"

# Compare with last known state
CURRENT_STATE="${STATE}:${REVIEW_DECISION}:${CI_SUMMARY}"

cleanup_state_file() {
  rm -f "${STATE_FILE}"
}

if [[ "${CURRENT_STATE}" != "${LAST_STATE}" ]]; then
  echo "State change: state=${STATE} review=${REVIEW_DECISION} ci=${CI_SUMMARY}"
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

# Terminal: approved + all CI pass
if [[ "${REVIEW_DECISION}" == "APPROVED" && "${CI_FAILURES}" == "0" && "${CI_PENDING}" == "0" ]]; then
  echo "Result: approved and CI passing"
  cleanup_state_file
  exit 0
fi

# Terminal: changes requested
if [[ "${REVIEW_DECISION}" == "CHANGES_REQUESTED" ]]; then
  echo "Result: changes requested"
  cleanup_state_file
  exit 1
fi

# Terminal: CI failure
if [[ "${CI_FAILURES}" -gt 0 ]]; then
  echo "Result: CI failure (${CI_FAILURES} check(s) failed)"
  cleanup_state_file
  exit 2
fi

# Terminal: PR closed/merged
if [[ "${STATE}" == "MERGED" || "${STATE}" == "CLOSED" ]]; then
  echo "Result: PR ${STATE}"
  cleanup_state_file
  exit 3
fi

# Still in progress
exit 4
