#!/usr/bin/env bash
# build-completed-tasks-context.sh — Assemble context about completed tasks for Task Agent spawn prompts
#
# Usage:
#   build-completed-tasks-context.sh <plan-file> <task-id> [--max-other <n>]
#
# Arguments:
#   <plan-file>      Path to the plan YAML
#   <task-id>        ID of the task being spawned (used to determine depends_on predecessors)
#   --max-other <n>  Maximum non-predecessor completed tasks to include (default: 15)
#
# Output: Formatted markdown to stdout, intended to be wrapped in <external_content> tags.
# Outputs nothing (exit 0) if no completed tasks exist.
#
# Exit codes:
#   0 — success (may output nothing)
#   1 — usage error or file not found
#   2 — structure error (could not discover tasks path)

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Parse arguments ---

if [[ $# -lt 2 ]]; then
  echo "Usage: build-completed-tasks-context.sh <plan-file> <task-id> [--max-other <n>]" >&2
  exit 1
fi

PLAN_FILE="$1"
TASK_ID="$2"
shift 2

MAX_OTHER=15

while [[ $# -gt 0 ]]; do
  case "$1" in
    --max-other)
      MAX_OTHER="$2"
      shift 2
      ;;
    *)
      echo "build-completed-tasks-context.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${PLAN_FILE}" ]]; then
  echo "build-completed-tasks-context.sh: plan file not found: ${PLAN_FILE}" >&2
  exit 1
fi

# --- Discover tasks path ---

TASKS_PATH=$("${_SCRIPT_DIR}/discover-tasks-path.sh" "${PLAN_FILE}")

# --- Read target task's depends_on list ---

depends_on_raw=$(yq e "($TASKS_PATH[] | select(.id == \"${TASK_ID}\")).depends_on | .[]" "${PLAN_FILE}" 2>/dev/null || true)

# Build a newline-separated string of predecessor IDs for matching
predecessor_ids=""
if [[ -n "${depends_on_raw}" ]]; then
  predecessor_ids="${depends_on_raw}"
fi

# --- Collect completed tasks ---

done_count=$(yq e "[${TASKS_PATH}[] | select(.status == \"done\")] | length" "${PLAN_FILE}" 2>/dev/null || true)

if [[ -z "${done_count}" || "${done_count}" == "0" ]]; then
  exit 0
fi

# --- Partition and emit ---

# Helper: check if an ID is in the predecessor list
_is_predecessor() {
  local check_id="$1"
  if [[ -z "${predecessor_ids}" ]]; then
    return 1
  fi
  echo "${predecessor_ids}" | grep -qxF "${check_id}"
}

# Helper: get first line of a string, or fallback
_first_line() {
  local text="$1"
  local fallback="$2"
  if [[ -z "${text}" || "${text}" == "null" ]]; then
    echo "${fallback}"
  else
    echo "${text}" | head -n 1
  fi
}

# Collect predecessor blocks and other blocks separately
predecessor_output=""
other_output=""
other_count=0

# Iterate over completed tasks
while IFS= read -r task_id; do
  [[ -z "${task_id}" ]] && continue

  task_title=$(yq e "($TASKS_PATH[] | select(.id == \"${task_id}\")).title // ($TASKS_PATH[] | select(.id == \"${task_id}\")).name // \"\"" "${PLAN_FILE}" 2>/dev/null || true)
  task_summary=$(yq e "($TASKS_PATH[] | select(.id == \"${task_id}\")).result.summary // \"\"" "${PLAN_FILE}" 2>/dev/null || true)
  task_commit_sha=$(yq e "($TASKS_PATH[] | select(.id == \"${task_id}\")).result.commit_sha // \"\"" "${PLAN_FILE}" 2>/dev/null || true)
  task_pr_url=$(yq e "($TASKS_PATH[] | select(.id == \"${task_id}\")).pr_url // ($TASKS_PATH[] | select(.id == \"${task_id}\")).result.pr_url // \"\"" "${PLAN_FILE}" 2>/dev/null || true)

  # Normalize nulls
  if [[ "${task_summary}" == "null" ]]; then task_summary=""; fi
  if [[ "${task_commit_sha}" == "null" ]]; then task_commit_sha=""; fi
  if [[ "${task_pr_url}" == "null" ]]; then task_pr_url=""; fi
  if [[ "${task_title}" == "null" ]]; then task_title=""; fi

  if _is_predecessor "${task_id}"; then
    predecessor_output="${predecessor_output}
- **${task_id}: ${task_title}**
  Summary: ${task_summary:-no summary recorded}
  Commit: ${task_commit_sha:-none}
  PR: ${task_pr_url:-none}
"
  else
    if [[ ${other_count} -lt ${MAX_OTHER} ]]; then
      first_line=$(_first_line "${task_summary}" "no summary recorded")
      other_output="${other_output}
- **${task_id}: ${task_title}** — ${first_line} (Commit: ${task_commit_sha:-none}, PR: ${task_pr_url:-none})"
      other_count=$((other_count + 1))
    fi
  fi
done < <(yq e "[$TASKS_PATH[] | select(.status == \"done\")].[] | .id" "${PLAN_FILE}" 2>/dev/null)

# --- Output ---

# Only output if we have content
if [[ -z "${predecessor_output}" && -z "${other_output}" ]]; then
  exit 0
fi

echo "## Completed Task Context"
echo ""

if [[ -n "${predecessor_output}" ]]; then
  echo "### Direct Predecessors"
  echo ""
  echo "These tasks are direct dependencies. Their code is on the base branch. Inspect their commits for implementation details."
  echo "${predecessor_output}"
fi

if [[ -n "${other_output}" ]]; then
  echo "### Other Completed Tasks"
  echo ""
  echo "These tasks were completed earlier in this plan. Their code is on the base branch."
  echo "${other_output}"
  echo ""
fi

echo "To inspect any task's changes: \`git show <commit-sha>\`"
echo "To see files changed: \`git show --name-only <commit-sha>\`"
