#!/usr/bin/env bash
# discover-tasks-path.sh <plan-file-path>
#
# Discovers the yq path to the task sequence in a plan YAML file.
# Encapsulates the TASKS_PATH discovery logic from PLAN_STORAGE.md § Structure Inspection.
#
# Output: Prints discovered path to stdout (e.g., ".epic.tasks", ".tasks")
# Exit codes:
#   0 — found a task sequence
#   1 — file not found
#   2 — no task sequence found

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: discover-tasks-path.sh <plan-file-path>" >&2
  exit 1
fi

PLAN_FILE="$1"

if [[ ! -f "$PLAN_FILE" ]]; then
  echo "discover-tasks-path.sh: file not found: $PLAN_FILE" >&2
  exit 1
fi

# Step 1: Inspect top-level keys
TOP_KEY=$(yq e 'keys | .[0]' "$PLAN_FILE")

if [[ -z "$TOP_KEY" || "$TOP_KEY" == "null" ]]; then
  echo "discover-tasks-path.sh: no top-level keys found in $PLAN_FILE" >&2
  exit 2
fi

# Step 2: Probe for a nested tasks-like sequence under the first top-level key.
# Look for a key whose value is a sequence with items containing both id and status.
TASKS_PATH=""
nested_keys=$(yq e ".$TOP_KEY | keys | .[]" "$PLAN_FILE" 2>/dev/null || true)

if [[ -n "$nested_keys" ]]; then
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    has_id=$(yq e ".$TOP_KEY.$key[0].id" "$PLAN_FILE" 2>/dev/null || true)
    has_status=$(yq e ".$TOP_KEY.$key[0].status" "$PLAN_FILE" 2>/dev/null || true)
    if [[ "$has_id" != "null" && -n "$has_id" && "$has_status" != "null" && -n "$has_status" ]]; then
      TASKS_PATH=".$TOP_KEY.$key"
      break
    fi
  done <<< "$nested_keys"
fi

# If nested probe found nothing, check root-level keys for a tasks-like sequence
if [[ -z "$TASKS_PATH" ]]; then
  root_keys=$(yq e 'keys | .[]' "$PLAN_FILE" 2>/dev/null || true)
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    has_id=$(yq e ".$key[0].id" "$PLAN_FILE" 2>/dev/null || true)
    has_status=$(yq e ".$key[0].status" "$PLAN_FILE" 2>/dev/null || true)
    if [[ "$has_id" != "null" && -n "$has_id" && "$has_status" != "null" && -n "$has_status" ]]; then
      TASKS_PATH=".$key"
      break
    fi
  done <<< "$root_keys"
fi

# Fallback to .tasks if nothing was found via probing
if [[ -z "$TASKS_PATH" ]]; then
  # Verify .tasks exists and has items with id+status before accepting fallback
  fallback_id=$(yq e '.tasks[0].id' "$PLAN_FILE" 2>/dev/null || true)
  fallback_status=$(yq e '.tasks[0].status' "$PLAN_FILE" 2>/dev/null || true)
  if [[ "$fallback_id" != "null" && -n "$fallback_id" && "$fallback_status" != "null" && -n "$fallback_status" ]]; then
    TASKS_PATH=".tasks"
  else
    echo "discover-tasks-path.sh: no task sequence found in $PLAN_FILE" >&2
    exit 2
  fi
fi

printf '%s' "$TASKS_PATH"
