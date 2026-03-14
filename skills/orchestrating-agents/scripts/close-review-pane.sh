#!/usr/bin/env bash
# close-review-pane.sh — close a tmux review pane
# Usage: close-review-pane.sh <pane-id>

set -euo pipefail

PANE_ID="${1:-}"

if [[ -z "${PANE_ID}" ]]; then
  echo "Usage: close-review-pane.sh <pane-id>" >&2
  exit 1
fi

if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session." >&2
  exit 1
fi

tmux kill-pane -t "${PANE_ID}"
echo "Closed review pane: ${PANE_ID}"
