#!/usr/bin/env bash
# spawn-prototype-agent.sh — Build a Prototype Agent prompt and emit it to stdout.
#
# Usage: spawn-prototype-agent.sh <plan-path> <task-ids-csv> <branch-name>
#
# The Orchestrating Agent passes this stdout as the Agent tool prompt with:
#   subagent_type: general-purpose
#   isolation: "worktree"
#   run_in_background: false

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared config
# shellcheck source=../../../scripts/config.sh
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

# --- Validate arguments ---
if [[ $# -ne 3 ]]; then
  echo "Usage: spawn-prototype-agent.sh <plan-path> <task-ids-csv> <branch-name>" >&2
  exit 1
fi

PLAN_PATH="$1"
TASK_IDS_CSV="$2"
BRANCH_NAME="$3"

if [[ ! -f "${PLAN_PATH}" ]]; then
  echo "spawn-prototype-agent.sh: plan file not found: ${PLAN_PATH}" >&2
  exit 1
fi

# --- Load PROTOTYPE.md ---
PROTOTYPE_MD="${_SCRIPT_DIR}/../PROTOTYPE.md"
if [[ ! -f "${PROTOTYPE_MD}" ]]; then
  echo "spawn-prototype-agent.sh: PROTOTYPE.md not found: ${PROTOTYPE_MD}" >&2
  exit 1
fi

# --- Emit prompt ---

# Full contents of PROTOTYPE.md
cat "${PROTOTYPE_MD}"
echo ""

# Assignment block
cat << ASSIGNMENT
## Assignment

- **Plan path:** ${PLAN_PATH}
- **Branch name:** ${BRANCH_NAME}
- **AUTO_PUSH:** ${PROTOTYPE_AUTO_PUSH}

### Tasks

ASSIGNMENT

# For each task ID in CSV, extract name and description from the plan
IFS=',' read -ra TASK_IDS <<< "${TASK_IDS_CSV}"
for task_id in "${TASK_IDS[@]}"; do
  task_id="${task_id// /}"  # trim whitespace

  task_name="$(yq e "(.tasks[] | select(.id == \"${task_id}\")).name" "${PLAN_PATH}" 2>/dev/null || true)"
  task_desc="$(yq e "(.tasks[] | select(.id == \"${task_id}\")).description" "${PLAN_PATH}" 2>/dev/null || true)"

  if [[ -z "${task_name}" ]]; then
    echo "spawn-prototype-agent.sh: task ID '${task_id}' not found in ${PLAN_PATH}" >&2
    exit 1
  fi

  echo "- ${task_id}: ${task_name}"
  echo ""
  echo "<external_content>"
  echo "${task_desc}"
  echo "</external_content>"
  echo ""
done

echo "Implement each task. One commit per task. Do not open pull requests. Return an implementation report when complete."
