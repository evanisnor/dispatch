#!/usr/bin/env bash
# open-plan-review-pane.sh — open a tmux window to review a plan YAML before saving
# Usage: open-plan-review-pane.sh <window-name> <temp-plan-file> [original-plan-file] [mode]
#
# New plan (no original-plan-file):
#   Displays the temp file with bat --language yaml if available, otherwise plain cat.
#
# Amendment (original-plan-file provided):
#   Shows git diff --no-index <original-plan-file> <temp-plan-file>, piped through
#   delta if available (respecting mode), otherwise plain diff output.
#
# mode: "split" (delta --side-by-side) or "unified" (delta default).
#       Defaults to $DIFF_MODE from config.sh, then "split".
#       Has no effect when delta is not installed.
#
# Opens a new named window in the current tmux session — never modifies the
# current window layout. Each review gets the full screen.
# Outputs the tmux window ID on success.
#
# The plan is NOT saved by this script. Saving only happens after human approval,
# via the Planning Agent following the write-with-lock pattern in PLAN_STORAGE.md.

set -euo pipefail

WINDOW_NAME="${1:-}"
TEMP_PLAN_FILE="${2:-}"
ORIGINAL_PLAN_FILE="${3:-}"
MODE="${4:-${DIFF_MODE:-split}}"

if [[ -z "${WINDOW_NAME}" || -z "${TEMP_PLAN_FILE}" ]]; then
  echo "Usage: open-plan-review-pane.sh <window-name> <temp-plan-file> [original-plan-file] [mode]" >&2
  exit 1
fi

if [[ ! -f "${TEMP_PLAN_FILE}" ]]; then
  echo "Error: temp plan file does not exist: ${TEMP_PLAN_FILE}" >&2
  exit 1
fi

if [[ -n "${ORIGINAL_PLAN_FILE}" && ! -f "${ORIGINAL_PLAN_FILE}" ]]; then
  echo "Error: original plan file does not exist: ${ORIGINAL_PLAN_FILE}" >&2
  exit 1
fi

# Must be running inside tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: not running inside a tmux session. Cannot open plan review window." >&2
  exit 1
fi

if [[ -n "${ORIGINAL_PLAN_FILE}" ]]; then
  # Amendment mode: show a diff between the original and the proposed plan
  if command -v delta &>/dev/null; then
    if [[ "${MODE}" == "split" ]]; then
      DISPLAY_CMD="git diff --no-index \"${ORIGINAL_PLAN_FILE}\" \"${TEMP_PLAN_FILE}\" | delta --side-by-side"
    else
      DISPLAY_CMD="git diff --no-index \"${ORIGINAL_PLAN_FILE}\" \"${TEMP_PLAN_FILE}\" | delta"
    fi
  else
    DISPLAY_CMD="git diff --no-index \"${ORIGINAL_PLAN_FILE}\" \"${TEMP_PLAN_FILE}\" || true"
  fi
  SEPARATOR="--- end of plan diff ---"
else
  # New plan mode: show the full plan YAML
  if command -v bat &>/dev/null; then
    DISPLAY_CMD="bat --language yaml --style plain \"${TEMP_PLAN_FILE}\""
  else
    DISPLAY_CMD="cat \"${TEMP_PLAN_FILE}\""
  fi
  SEPARATOR="--- end of plan ---"
fi

# Open a new named window in the current session
WINDOW_ID="$(tmux new-window -P -F '#{window_id}' -n "${WINDOW_NAME}" \
  "bash -c '${DISPLAY_CMD}; printf \"\n${SEPARATOR}\n\"; read -r -p \"Press Enter to close...\" _'")"

echo "${WINDOW_ID}"
