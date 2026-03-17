#!/usr/bin/env bash
# save-session-state.sh <memory-dir> <plan-file> [--independent-prs <yaml>] [--pending-reviews <yaml>]
#
# Writes a dispatch-session-state.yaml snapshot to the Claude Code memory directory.
# Used by the Orchestrating Agent to cache session state for warm-start on next session.
#
# Exit codes:
#   0 — success
#   1 — usage error or file not found
#   2 — structure error (could not discover tasks path)

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse arguments ---
if [[ $# -lt 2 ]]; then
  echo "Usage: save-session-state.sh <memory-dir> <plan-file> [--independent-prs <yaml>] [--pending-reviews <yaml>]" >&2
  exit 1
fi

MEMORY_DIR="$1"
PLAN_FILE="$2"
shift 2

INDEPENDENT_PRS_YAML=""
PENDING_REVIEWS_YAML=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --independent-prs)
      INDEPENDENT_PRS_YAML="$2"
      shift 2
      ;;
    --pending-reviews)
      PENDING_REVIEWS_YAML="$2"
      shift 2
      ;;
    *)
      echo "save-session-state.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "save-session-state.sh: plan file not found: $PLAN_FILE" >&2
  exit 1
fi

if [[ ! -d "$MEMORY_DIR" ]]; then
  echo "save-session-state.sh: memory directory not found: $MEMORY_DIR" >&2
  exit 1
fi

# --- Discover TASKS_PATH ---
TASKS_PATH=$("${_SCRIPT_DIR}/discover-tasks-path.sh" "$PLAN_FILE")
discover_exit=$?
if [[ $discover_exit -ne 0 ]]; then
  echo "save-session-state.sh: could not discover tasks path (exit $discover_exit)" >&2
  exit 2
fi

# --- Extract plan metadata ---
# Try envelope keys for plan_id
PLAN_ID=""
for envelope in plan epic project milestone; do
  val=$(yq e ".$envelope.id // .$envelope.project // \"\"" "$PLAN_FILE" 2>/dev/null || true)
  if [[ -n "$val" && "$val" != "null" ]]; then
    PLAN_ID="$val"
    break
  fi
done
# Fallback: use filename without extension
if [[ -z "$PLAN_ID" ]]; then
  PLAN_ID=$(basename "$PLAN_FILE" .yaml)
fi

# Extract issue tracking status
IT_STATUS=""
IT_ROOT_ID=""
for envelope in epic project milestone; do
  val=$(yq e ".$envelope.issue_tracking.status // \"\"" "$PLAN_FILE" 2>/dev/null || true)
  if [[ -n "$val" && "$val" != "null" ]]; then
    IT_STATUS="$val"
  fi
  val=$(yq e ".$envelope.issue_tracking.root_id // \"\"" "$PLAN_FILE" 2>/dev/null || true)
  if [[ -n "$val" && "$val" != "null" ]]; then
    IT_ROOT_ID="$val"
  fi
  if [[ -n "$IT_STATUS" ]]; then
    break
  fi
done
# Fallback to root-level
if [[ -z "$IT_STATUS" ]]; then
  IT_STATUS=$(yq e '.issue_tracking.status // ""' "$PLAN_FILE" 2>/dev/null || true)
fi
if [[ -z "$IT_ROOT_ID" ]]; then
  IT_ROOT_ID=$(yq e '.issue_tracking.root_id // ""' "$PLAN_FILE" 2>/dev/null || true)
fi

# --- Extract task list ---
TASKS_YAML=$(yq e "$TASKS_PATH[] | {\"id\": .id, \"status\": .status, \"pr_url\": (.pr_url // \"null\"), \"agent_id\": (.agent_id // \"null\")}" "$PLAN_FILE" 2>/dev/null || true)

# --- Build output ---
OUTPUT_FILE="${MEMORY_DIR}/dispatch-session-state.yaml"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ABSOLUTE_PLAN=$(cd "$(dirname "$PLAN_FILE")" && echo "$(pwd)/$(basename "$PLAN_FILE")")

{
  echo "plan_file: \"$ABSOLUTE_PLAN\""
  echo "plan_id: \"$PLAN_ID\""
  echo "tasks_path: \"$TASKS_PATH\""
  echo "updated_at: \"$TIMESTAMP\""
  echo "tasks:"

  # Output each task as a YAML list item
  if [[ -n "$TASKS_YAML" ]]; then
    echo "$TASKS_YAML" | yq e '.' - 2>/dev/null | while IFS= read -r line; do
      # yq outputs documents separated by ---; convert to list items
      if [[ "$line" == "---" ]]; then
        continue
      fi
      # Indent and prefix first field of each object with -
      if echo "$line" | grep -q '^id:'; then
        echo "  - $line"
      else
        echo "    $line"
      fi
    done
  else
    echo "  []"
  fi

  echo "issue_tracking:"
  echo "  status: \"${IT_STATUS:-null}\""
  echo "  root_id: \"${IT_ROOT_ID:-null}\""

  echo "independent_prs:"
  if [[ -n "$INDEPENDENT_PRS_YAML" ]]; then
    echo "$INDEPENDENT_PRS_YAML" | sed 's/^/  /'
  else
    echo "  []"
  fi

  echo "pending_reviews:"
  if [[ -n "$PENDING_REVIEWS_YAML" ]]; then
    echo "$PENDING_REVIEWS_YAML" | sed 's/^/  /'
  else
    echo "  []"
  fi
} > "$OUTPUT_FILE"

exit 0
