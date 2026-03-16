#!/usr/bin/env bash
# update-main.sh — bring local main up to date after a merge
# Usage: update-main.sh
#
# Must be run from within the main repository.
# Strategy is controlled by MAIN_UPDATE_STRATEGY (set via config.sh):
#   "rebase"        — git rebase origin/main (default)
#   "merge-ff-only" — git merge --ff-only origin/main

set -euo pipefail

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

# Determine the main worktree path (first entry in git worktree list)
MAIN_WORKTREE="$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')"

# Fetch latest from origin
git fetch origin main --quiet

case "${MAIN_UPDATE_STRATEGY}" in
  rebase)
    git -C "${MAIN_WORKTREE}" rebase origin/main --quiet
    echo "Local main updated via rebase."
    ;;
  merge-ff-only)
    git -C "${MAIN_WORKTREE}" merge --ff-only origin/main --quiet
    echo "Local main updated via fast-forward merge."
    ;;
  *)
    echo "Unknown MAIN_UPDATE_STRATEGY '${MAIN_UPDATE_STRATEGY}'; falling back to rebase." >&2
    git -C "${MAIN_WORKTREE}" rebase origin/main --quiet
    echo "Local main updated via rebase."
    ;;
esac
