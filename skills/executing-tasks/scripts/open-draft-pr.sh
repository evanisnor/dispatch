#!/usr/bin/env bash
# open-draft-pr.sh — create a draft pull request
# Usage: open-draft-pr.sh <branch-name> <pr-title> <pr-body>
#
# Outputs the PR URL on success.

set -euo pipefail

BRANCH="${1:-}"
TITLE="${2:-}"
BODY="${3:-}"

if [[ -z "${BRANCH}" || -z "${TITLE}" || -z "${BODY}" ]]; then
  echo "Usage: open-draft-pr.sh <branch-name> <pr-title> <pr-body>" >&2
  exit 1
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

# --- Defensive check: reject PR if local-only main commits are present ---
_GIT_DIR="$(git rev-parse --git-dir)"
_FORK_POINT_FILE="${_GIT_DIR}/dispatch-fork-point"

if [[ -f "${_FORK_POINT_FILE}" ]]; then
  _FORK_POINT="$(cat "${_FORK_POINT_FILE}")"
  _ORIGIN_MAIN="$(git rev-parse origin/main 2>/dev/null || echo "")"
  if [[ -n "${_ORIGIN_MAIN}" && "${_FORK_POINT}" != "${_ORIGIN_MAIN}" ]]; then
    echo "Error: local-only main commits detected. Run push-changes.sh before opening a PR." >&2
    exit 1
  fi
fi

PR_URL="$(gh pr create \
  --draft \
  --title "${TITLE}" \
  --body "${BODY}" \
  --base main \
  --head "${BRANCH}")"

echo "${PR_URL}"
