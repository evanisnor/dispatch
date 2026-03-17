#!/usr/bin/env bash
# tmux-helpers.sh — shared tmux utility functions for the Orchestrating Agent
# Source this file; do not execute directly.

# tmux_new_window_reliable — create a tmux window with post-creation verification and retry.
# Wraps `tmux new-window -P -F '#{window_id}'` so callers must NOT pass -P or -F.
# All other tmux new-window flags/args are forwarded as-is.
# Outputs the window ID on stdout. Returns non-zero after 3 failed attempts.
tmux_new_window_reliable() {
  local max_attempts=3
  local attempt=0
  local window_id=""

  while [ "${attempt}" -lt "${max_attempts}" ]; do
    attempt=$((attempt + 1))
    window_id="$(tmux new-window -P -F '#{window_id}' "$@" 2>/dev/null)" || true

    if [ -n "${window_id}" ] && tmux list-windows -F '#{window_id}' | grep -qF "${window_id}"; then
      echo "${window_id}"
      return 0
    fi

    echo "tmux-helpers: window creation attempt ${attempt}/${max_attempts} failed (id='${window_id}')" >&2
    if [ "${attempt}" -lt "${max_attempts}" ]; then
      sleep 0.5
    fi
  done

  echo "Error: failed to create tmux window after ${max_attempts} attempts" >&2
  return 1
}
