#!/usr/bin/env bash
# watch-merge-queue.sh — poll merge queue status for a PR
# Usage: watch-merge-queue.sh <pr-url-or-number>
#
# Exit codes:
#   0 = merged successfully
#   1 = conflicts detected
#   2 = CI failure
#   3 = ejected from queue or polling timeout

set -euo pipefail

PR="${1:-}"
if [[ -z "${PR}" ]]; then
  echo "Usage: watch-merge-queue.sh <pr-url-or-number>" >&2
  exit 3
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

POLL_INTERVAL=30  # seconds between polls
TIMEOUT_SECONDS=$(( POLLING_TIMEOUT_MINUTES * 60 ))
ELAPSED=0
LAST_STATE=""

echo "Watching merge queue for PR: ${PR}"
echo "Timeout: ${POLLING_TIMEOUT_MINUTES} minutes"

while true; do
  # Fetch only the fields we need — never inject full API payloads into context
  RESULT="$(gh pr view "${PR}" --json mergeStateStatus,state,merged 2>/dev/null || echo '{"mergeStateStatus":"UNKNOWN","state":"UNKNOWN","merged":false}')"

  STATE="$(printf '%s' "${RESULT}" | jq -r '.state')"
  MERGE_STATE="$(printf '%s' "${RESULT}" | jq -r '.mergeStateStatus')"
  MERGED="$(printf '%s' "${RESULT}" | jq -r '.merged')"

  # Only emit output on state changes to avoid flooding agent context
  CURRENT_STATE="${STATE}:${MERGE_STATE}"
  if [[ "${CURRENT_STATE}" != "${LAST_STATE}" ]]; then
    echo "State change: state=${STATE} mergeStateStatus=${MERGE_STATE}"
    LAST_STATE="${CURRENT_STATE}"
  fi

  # Terminal states
  if [[ "${MERGED}" == "true" ]] || [[ "${STATE}" == "MERGED" ]]; then
    echo "Result: merged"
    exit 0
  fi

  if [[ "${STATE}" == "CLOSED" ]]; then
    echo "Result: ejected (PR closed)"
    exit 3
  fi

  if [[ "${MERGE_STATE}" == "CONFLICTING" ]]; then
    echo "Result: conflicts detected"
    exit 1
  fi

  if [[ "${MERGE_STATE}" == "BLOCKED" ]]; then
    echo "Result: CI failure (merge blocked)"
    exit 2
  fi

  # Check timeout
  ELAPSED=$(( ELAPSED + POLL_INTERVAL ))
  if [[ "${ELAPSED}" -ge "${TIMEOUT_SECONDS}" ]]; then
    echo "Result: timeout after ${POLLING_TIMEOUT_MINUTES} minutes"
    exit 3
  fi

  sleep "${POLL_INTERVAL}"
done
