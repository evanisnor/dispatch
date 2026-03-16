#!/usr/bin/env bash
# watch-ci.sh — poll CI check status for a commit or PR
# Usage: watch-ci.sh <commit-sha-or-pr-number>
#
# Outputs only state-change summaries (pass/fail/in-progress per check name).
# Never outputs full CI log text — untrusted content defense.
#
# Exit codes:
#   0 = all checks pass
#   1 = any check failed
#   3 = polling timeout

set -euo pipefail

TARGET="${1:-}"
if [[ -z "${TARGET}" ]]; then
  echo "Usage: watch-ci.sh <commit-sha-or-pr-number>" >&2
  exit 3
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

POLL_INTERVAL=30
TIMEOUT_SECONDS=$(( POLLING_TIMEOUT_MINUTES * 60 ))
ELAPSED=0
LAST_SUMMARY=""

echo "Watching CI for: ${TARGET}"
echo "Timeout: ${POLLING_TIMEOUT_MINUTES} minutes"

# Determine whether TARGET looks like a PR number/URL or a commit SHA
if [[ "${TARGET}" =~ ^[0-9]+$ ]] || [[ "${TARGET}" == https://* ]]; then
  MODE="pr"
else
  MODE="commit"
fi

while true; do
  if [[ "${MODE}" == "pr" ]]; then
    # Fetch check status via PR — output only per-check name + conclusion
    RAW="$(gh pr checks "${TARGET}" --json name,state,conclusion 2>/dev/null || echo '[]')"
  else
    # Fetch check runs for a commit SHA
    RAW="$(gh run list --commit "${TARGET}" --json name,status,conclusion --limit 50 2>/dev/null || echo '[]')"
  fi

  # Summarise: emit check name + conclusion only — never log text
  SUMMARY="$(printf '%s\n' "${RAW}" | jq -r '
    if type == "array" then
      .[]
      | "\(.name // "unknown"): \(.conclusion // .state // "pending")"
    else empty end
  ' 2>/dev/null | sort | tr '\n' ' ')"

  FAILED_COUNT="$(printf '%s\n' "${RAW}" | jq -r '
    [.[] | select(.conclusion == "failure" or .conclusion == "timed_out")] | length
  ' 2>/dev/null || echo "0")"

  PENDING_COUNT="$(printf '%s\n' "${RAW}" | jq -r '
    [.[] | select(.conclusion == null and (.status // .state) != "completed")] | length
  ' 2>/dev/null || echo "0")"

  TOTAL="$(printf '%s\n' "${RAW}" | jq -r 'length' 2>/dev/null || echo "0")"

  # Only emit on state change
  if [[ "${SUMMARY}" != "${LAST_SUMMARY}" ]]; then
    echo "CI update: ${SUMMARY}"
    LAST_SUMMARY="${SUMMARY}"
  fi

  # Terminal: all checks complete with no failures
  if [[ "${TOTAL}" -gt 0 && "${PENDING_COUNT}" -eq 0 && "${FAILED_COUNT}" -eq 0 ]]; then
    echo "Result: all ${TOTAL} check(s) passed"
    exit 0
  fi

  # Terminal: any failure
  if [[ "${FAILED_COUNT}" -gt 0 ]]; then
    echo "Result: ${FAILED_COUNT} check(s) failed"
    exit 1
  fi

  ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  if [[ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]]; then
    echo "Result: timeout after ${POLLING_TIMEOUT_MINUTES} minutes"
    exit 3
  fi

  sleep "${POLL_INTERVAL}"
done
