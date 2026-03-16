#!/usr/bin/env bash
# open-in-editor.sh — open a worktree in the configured editor or IDE
# Usage: open-in-editor.sh <worktree-path>
#
# Reads EDITOR_APP from config. Tries the value as a CLI command first (e.g. "code", "cursor"),
# then falls back to macOS "open -a <App Name>" for GUI apps (e.g. "Xcode", "Visual Studio Code").

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/config.sh"

WORKTREE_PATH="${1:-}"

if [[ -z "${WORKTREE_PATH}" ]]; then
  echo "Usage: open-in-editor.sh <worktree-path>" >&2
  exit 1
fi

if [[ ! -d "${WORKTREE_PATH}" ]]; then
  echo "Error: worktree path does not exist: ${WORKTREE_PATH}" >&2
  exit 1
fi

if [[ -z "${EDITOR_APP}" ]]; then
  echo "Error: no editor configured. Set editor.app in .dispatch.yaml" >&2
  exit 1
fi

# Try as a CLI command first (e.g. "code", "cursor")
if command -v "${EDITOR_APP}" &>/dev/null; then
  "${EDITOR_APP}" "${WORKTREE_PATH}"
  exit 0
fi

# macOS: try open -a <App Name> (e.g. "Xcode", "Visual Studio Code", "Cursor")
if [[ "$(uname)" == "Darwin" ]]; then
  if open -a "${EDITOR_APP}" "${WORKTREE_PATH}" 2>/dev/null; then
    exit 0
  fi
fi

echo "Error: editor '${EDITOR_APP}' not found as a command or macOS app" >&2
exit 1
