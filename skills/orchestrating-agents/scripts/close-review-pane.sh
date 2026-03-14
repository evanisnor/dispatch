#!/usr/bin/env bash
# close-review-pane.sh — close a tmux review window
# Usage: close-review-pane.sh <window-name-or-id>

set -euo pipefail

WINDOW="${1:-}"

if [[ -z "${WINDOW}" ]]; then
  echo "Usage: close-review-pane.sh <window-name-or-id>" >&2
  exit 1
fi

if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session." >&2
  exit 1
fi

SESSION="$(tmux display-message -p '#S')"

tmux kill-window -t "${SESSION}:${WINDOW}"
echo "Closed review pane: ${WINDOW}"
