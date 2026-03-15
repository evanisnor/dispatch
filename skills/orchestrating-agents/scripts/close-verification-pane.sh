#!/usr/bin/env bash
# close-verification-pane.sh — close a tmux verification window
# Usage: close-verification-pane.sh <window-id>

set -euo pipefail

WINDOW_ID="${1:-}"

if [[ -z "${WINDOW_ID}" ]]; then
  echo "Usage: close-verification-pane.sh <window-id>" >&2
  exit 1
fi

if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session." >&2
  exit 1
fi

# No-op if the window no longer exists
if tmux list-windows -F '#{window_id}' | grep -qF "${WINDOW_ID}"; then
  tmux kill-window -t "${WINDOW_ID}"
  echo "Closed verification window: ${WINDOW_ID}"
else
  echo "Verification window ${WINDOW_ID} already closed."
fi
