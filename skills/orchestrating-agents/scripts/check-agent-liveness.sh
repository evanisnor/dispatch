#!/usr/bin/env bash
# check-agent-liveness.sh — check whether a Task Agent is healthy, stalled, or dead
#
# Usage:
#   check-agent-liveness.sh <agent_id> <last_activity_timestamp> [<stall_timeout_minutes>]
#
# Arguments:
#   agent_id                  — Claude Agent SDK agent ID
#   last_activity_timestamp   — ISO 8601 timestamp of the agent's last known output
#   stall_timeout_minutes     — optional; defaults to POLLING_TIMEOUT_MINUTES from config
#
# Exit codes:
#   0 — healthy (running and recently active)
#   1 — dead (stopped or errored)
#   2 — stalled (running but no activity within stall_timeout_minutes)

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

AGENT_ID="${1:?agent_id required}"
LAST_ACTIVITY="${2:?last_activity_timestamp required}"
STALL_TIMEOUT="${3:-${POLLING_TIMEOUT_MINUTES}}"

# Query agent status from Claude Agent SDK
# claude agent status outputs: running | stopped | error
_STATUS="$(claude agent status "${AGENT_ID}" 2>/dev/null || echo "error")"

if [[ "${_STATUS}" == "stopped" || "${_STATUS}" == "error" ]]; then
  exit 1  # dead
fi

# Agent is running — check for stall
_NOW="$(date -u +%s)"
_LAST="$(date -u -d "${LAST_ACTIVITY}" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "${LAST_ACTIVITY}" +%s 2>/dev/null || echo 0)"
_ELAPSED_MINUTES=$(( (_NOW - _LAST) / 60 ))

if (( _ELAPSED_MINUTES >= STALL_TIMEOUT )); then
  exit 2  # stalled
fi

exit 0  # healthy
