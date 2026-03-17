#!/usr/bin/env bash
# open-verification-pane.sh — open a tmux window at the task worktree for runtime verification
# Usage: open-verification-pane.sh <window-name> <worktree-path> [startup-command]
#
# Opens a new named window in the current tmux session with CWD set to <worktree-path>.
# If <startup-command> is provided, it is sent to the window automatically.
# Outputs the tmux window ID on success.

set -euo pipefail

WINDOW_NAME="${1:-}"
WORKTREE_PATH="${2:-}"
STARTUP_CMD="${3:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tmux-helpers.sh"

if [[ -z "${WINDOW_NAME}" || -z "${WORKTREE_PATH}" ]]; then
  echo "Usage: open-verification-pane.sh <window-name> <worktree-path> [startup-command]" >&2
  exit 1
fi

if [[ ! -d "${WORKTREE_PATH}" ]]; then
  echo "Error: worktree path does not exist: ${WORKTREE_PATH}" >&2
  exit 1
fi

# Must be running inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session. Cannot open verification window." >&2
  exit 1
fi

# Open a new named window in the current session, starting in the worktree directory
WINDOW_ID="$(tmux_new_window_reliable -n "${WINDOW_NAME}" -c "${WORKTREE_PATH}")"

# Send the startup command if provided
if [[ -n "${STARTUP_CMD}" ]]; then
  tmux send-keys -t "${WINDOW_ID}" "${STARTUP_CMD}" Enter
fi

echo "${WINDOW_ID}"
