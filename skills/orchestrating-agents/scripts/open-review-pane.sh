#!/usr/bin/env bash
# open-review-pane.sh — split a tmux pane showing git diff for review
# Usage: open-review-pane.sh <pane-name> <worktree-path>
#
# Splits a new pane in the SAME tmux window as the Orchestrating Agent.
# Never creates a new tmux session or window.
# Outputs the pane ID on success.

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

# Must be running inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session. Cannot open review pane." >&2
  exit 1
fi

# Split a new pane in the current window
PANE_ID="$(tmux split-window -P -F '#{pane_id}' \
  "git -C \"${WORKTREE_PATH}\" diff HEAD; echo '--- end of diff ---'; read -r -p 'Press Enter to close...' _")"

echo "${PANE_ID}"
