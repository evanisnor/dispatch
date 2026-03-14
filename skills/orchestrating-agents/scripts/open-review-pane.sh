#!/usr/bin/env bash
# open-review-pane.sh — open a tmux window showing git diff for review
# Usage: open-review-pane.sh <pane-name> <worktree-path>
#
# Must open in the SAME tmux session as the Orchestrating Agent.
# Never creates a new tmux session.
# Outputs the window ID on success.

set -euo pipefail

PANE_NAME="${1:-}"
WORKTREE_PATH="${2:-}"

if [[ -z "${PANE_NAME}" || -z "${WORKTREE_PATH}" ]]; then
  echo "Usage: open-review-pane.sh <pane-name> <worktree-path>" >&2
  exit 1
fi

if [[ ! -d "${WORKTREE_PATH}" ]]; then
  echo "Error: worktree path does not exist: ${WORKTREE_PATH}" >&2
  exit 1
fi

# Resolve current tmux session — must be running inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session. Cannot open review pane." >&2
  exit 1
fi

SESSION="$(tmux display-message -p '#S')"

# Create a new window in the SAME session showing git diff
WINDOW_ID="$(tmux new-window -t "${SESSION}" -n "${PANE_NAME}" -P -F '#{window_id}' \
  "git -C \"${WORKTREE_PATH}\" diff HEAD; echo '--- end of diff ---'; read -r -p 'Press Enter to close...' _")"

echo "${WINDOW_ID}"
