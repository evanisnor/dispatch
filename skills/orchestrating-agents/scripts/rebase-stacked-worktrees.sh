#!/usr/bin/env bash
# rebase-stacked-worktrees.sh <plan-file> <updated-branch>
#
# Rebases all stacked worktrees whose base_branch matches <updated-branch>,
# in dependency order (shallowest first), then recurses for deeper stacks.
#
# Exit codes:
#   0 — all rebases succeeded (or no stacked tasks found)
#   1 — conflict detected; outputs CONFLICT=<task-id> WORKTREE=<path>
#
# On conflict, the rebase is aborted and no further rebases in the stack are
# attempted. The caller must resolve the conflict and re-run this script.

set -euo pipefail

PLAN_FILE="${1:?Usage: rebase-stacked-worktrees.sh <plan-file> <updated-branch>}"
UPDATED_BRANCH="${2:?Usage: rebase-stacked-worktrees.sh <plan-file> <updated-branch>}"

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Discover the tasks path dynamically
TASKS_PATH=$("${_SCRIPT_DIR}/../../../scripts/discover-tasks-path.sh" "$PLAN_FILE")

# Find all tasks where stacked == true and base_branch == UPDATED_BRANCH.
# Output: newline-separated list of "task-id|worktree-path|branch"
stacked_tasks=$(yq e \
  "$TASKS_PATH[] | select(.stacked == true and .base_branch == \"$UPDATED_BRANCH\") | .id + \"|\" + .worktree + \"|\" + .branch" \
  "$PLAN_FILE" 2>/dev/null || true)

if [[ -z "$stacked_tasks" ]]; then
  exit 0
fi

while IFS='|' read -r task_id worktree_path task_branch; do
  [[ -z "$task_id" ]] && continue

  # Fetch latest refs
  git -C "$worktree_path" fetch origin

  # Attempt rebase onto updated branch — prefer remote tracking ref
  if git -C "$worktree_path" rebase "origin/$UPDATED_BRANCH" 2>/dev/null; then
    : # rebase succeeded
  elif git -C "$worktree_path" rebase "$UPDATED_BRANCH" 2>/dev/null; then
    : # rebase succeeded using local ref
  else
    # Conflict — abort and report
    git -C "$worktree_path" rebase --abort 2>/dev/null || true
    echo "CONFLICT=$task_id WORKTREE=$worktree_path"
    exit 1
  fi

  # Recurse: rebase tasks stacked on this task's own branch
  "$0" "$PLAN_FILE" "$task_branch"

done <<< "$stacked_tasks"

exit 0
