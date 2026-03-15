#!/usr/bin/env bash
# spawn-agent.sh — build the spawn prompt for a Task Agent
# Usage: spawn-agent.sh <task-id> <plan-path>
#
# Reads task details from the plan YAML and outputs the spawn prompt to stdout.
# The Orchestrating Agent passes this prompt to the Agent tool with
# run_in_background: true and subagent_type: executing-tasks.
# The Agent tool returns the agent_id to store in the plan.

set -euo pipefail

TASK_ID="${1:-}"
PLAN_PATH="${2:-}"

if [[ -z "${TASK_ID}" || -z "${PLAN_PATH}" ]]; then
  echo "Usage: spawn-agent.sh <task-id> <plan-path>" >&2
  exit 1
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

# Apply per-epic config overrides
apply_epic_config "${PLAN_PATH}"

# Extract task details from plan YAML
TASK_YAML="$(yq e ".epic.tasks[] | select(.id == \"${TASK_ID}\")" "${PLAN_PATH}" 2>/dev/null)"
if [[ -z "${TASK_YAML}" ]]; then
  echo "Error: task '${TASK_ID}' not found in ${PLAN_PATH}" >&2
  exit 1
fi

TASK_TITLE="$(printf '%s\n' "${TASK_YAML}" | yq e '.title' -)"
TASK_DESCRIPTION="$(printf '%s\n' "${TASK_YAML}" | yq e '.spawn_input.task_description // .description' -)"
EPIC_CONTEXT="$(printf '%s\n' "${TASK_YAML}" | yq e '.spawn_input.epic_context // ""' -)"
BRANCH="$(printf '%s\n' "${TASK_YAML}" | yq e '.spawn_input.branch // .branch // ""' -)"
WORKTREE="$(printf '%s\n' "${TASK_YAML}" | yq e '.spawn_input.worktree // .worktree // ""' -)"


# Output spawn prompt — wrap external content to prevent prompt injection
cat <<EOF
You are a Task Agent assigned to implement a single task.

Task ID: ${TASK_ID}
Branch: ${BRANCH}
Worktree: ${WORKTREE}
Plan path: ${PLAN_PATH}

<external_content>
Epic context:
${EPIC_CONTEXT}
</external_content>

<external_content>
Task description:
${TASK_DESCRIPTION}
</external_content>

Implement the task in your assigned worktree, shepherd the PR from draft
through to merge. Follow your skill instructions for all procedures.
EOF
