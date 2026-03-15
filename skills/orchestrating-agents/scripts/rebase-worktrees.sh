#!/usr/bin/env bash
# rebase-worktrees.sh — rebase all active non-main worktrees onto origin/main
# Usage: rebase-worktrees.sh
#
# Must be run from within the main repository.
# On rebase conflict: prints the worktree path and task ID, exits non-zero
# so the caller (Orchestrating Agent) can notify the relevant Task Agent.

set -euo pipefail

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

# Determine the main worktree path (first entry in git worktree list)
MAIN_WORKTREE="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

# Fetch latest origin/main and fast-forward the local main branch
git fetch origin main --quiet
git -C "${MAIN_WORKTREE}" merge --ff-only origin/main --quiet

FAILED_WORKTREES=()

# Parse all worktrees from porcelain output
while IFS= read -r line; do
  if [[ "${line}" == worktree\ * ]]; then
    CURRENT_PATH="${line#worktree }"
  elif [[ "${line}" == branch\ * ]]; then
    CURRENT_BRANCH="${line#branch refs/heads/}"
  elif [[ -z "${line}" && -n "${CURRENT_PATH:-}" ]]; then
    # End of a worktree block — process if it's not the main worktree
    if [[ "${CURRENT_PATH}" != "${MAIN_WORKTREE}" ]]; then
      # Derive task ID from the last path component
      TASK_ID="$(basename "${CURRENT_PATH}")"

      echo "Rebasing worktree: ${CURRENT_PATH} (task: ${TASK_ID}, branch: ${CURRENT_BRANCH:-unknown})"

      if ! git -C "${CURRENT_PATH}" rebase origin/main 2>&1; then
        echo "Rebase conflict in worktree: ${CURRENT_PATH} (task: ${TASK_ID})" >&2
        git -C "${CURRENT_PATH}" rebase --abort 2>/dev/null || true
        FAILED_WORKTREES+=("${CURRENT_PATH}:${TASK_ID}")
      fi
    fi
    CURRENT_PATH=""
    CURRENT_BRANCH=""
  fi
done < <(git worktree list --porcelain; echo "")

if [[ "${#FAILED_WORKTREES[@]}" -gt 0 ]]; then
  echo "Rebase conflicts detected in the following worktrees:" >&2
  for entry in "${FAILED_WORKTREES[@]}"; do
    echo "  ${entry}" >&2
  done
  exit 1
fi

echo "All worktrees rebased successfully."
