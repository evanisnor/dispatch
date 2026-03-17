#!/usr/bin/env bash
# open-review-pane.sh — open a new tmux window showing the branch diff for review
# Usage: open-review-pane.sh <window-name> <worktree-path> [diff-range-or-mode] [mode]
#
# If the third argument contains "...", it is treated as a git diff range
# (e.g. "origin/main...origin/feature-branch") and mode shifts to arg4.
# Otherwise, the third argument is treated as the display mode.
#
# mode: "split" (delta --side-by-side) or "unified" (delta default).
#       Defaults to $DIFF_MODE from config.sh, then "split".
#       Has no effect when delta is not installed.
#
# Opens a new named window in the current tmux session — never modifies the
# current window layout. Each review gets the full screen.
# Outputs the tmux window ID on success.

set -euo pipefail

WINDOW_NAME="${1:-}"
WORKTREE_PATH="${2:-}"
DIFF_RANGE=""

# Disambiguate arg3: "..." means diff range, otherwise display mode
_ARG3="${3:-}"
if [[ "${_ARG3}" == *"..."* ]]; then
  DIFF_RANGE="${_ARG3}"
  MODE="${4:-${DIFF_MODE:-split}}"
else
  MODE="${_ARG3:-${DIFF_MODE:-split}}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/tmux-helpers.sh"

if [[ -z "${WINDOW_NAME}" || -z "${WORKTREE_PATH}" ]]; then
  echo "Usage: open-review-pane.sh <window-name> <worktree-path> [diff-range-or-mode] [mode]" >&2
  exit 1
fi

if [[ ! -d "${WORKTREE_PATH}" ]]; then
  echo "Error: worktree path does not exist: ${WORKTREE_PATH}" >&2
  exit 1
fi

# Must be running inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session. Cannot open review window." >&2
  exit 1
fi

# When using a remote diff range, fetch origin to ensure refs are fresh
if [[ -n "${DIFF_RANGE}" ]]; then
  git -C "${WORKTREE_PATH}" fetch origin --quiet 2>/dev/null || true
fi

# Determine the diff range
if [[ -n "${DIFF_RANGE}" ]]; then
  RANGE="${DIFF_RANGE}"
else
  # Detect the base branch from the remote HEAD pointer; fall back to origin/main
  BASE_BRANCH="$(git -C "${WORKTREE_PATH}" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's@^refs/remotes/@@')" || true
  BASE_BRANCH="${BASE_BRANCH:-origin/main}"
  RANGE="${BASE_BRANCH}...HEAD"
fi

# Build diff command — use delta when available, respecting the requested mode
if command -v delta &>/dev/null; then
  if [[ "${MODE}" == "split" ]]; then
    DIFF_CMD="git -C \"${WORKTREE_PATH}\" diff \"${RANGE}\" | delta --side-by-side"
  else
    DIFF_CMD="git -C \"${WORKTREE_PATH}\" diff \"${RANGE}\" | delta"
  fi
else
  DIFF_CMD="git -C \"${WORKTREE_PATH}\" diff \"${RANGE}\""
fi

# Open a new named window in the current session
WINDOW_ID="$(tmux_new_window_reliable -n "${WINDOW_NAME}" \
  "${DIFF_CMD}; printf '\n--- end of diff ---\n'; read -r -p 'When done reviewing, return to Claude and approve or request changes. Press Enter to close this window.' _")"

echo "${WINDOW_ID}"
