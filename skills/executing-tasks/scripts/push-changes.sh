#!/usr/bin/env bash
# push-changes.sh — push changes to a feature branch
# Usage: push-changes.sh <branch-name> [commit-message]
#
# Refuses to push to any protected branch.

set -euo pipefail

BRANCH="${1:-}"
COMMIT_MSG="${2:-}"

if [[ -z "${BRANCH}" ]]; then
  echo "Usage: push-changes.sh <branch-name> [commit-message]" >&2
  exit 1
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

# Refuse to push to any protected branch
for protected in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "${BRANCH}" == "${protected}" ]]; then
    echo "Error: refusing to push to protected branch '${BRANCH}'." >&2
    exit 1
  fi
done

# Stage and commit if a commit message was provided
if [[ -n "${COMMIT_MSG}" ]]; then
  git add -A
  git commit -m "${COMMIT_MSG}"
fi

git push origin "${BRANCH}"
echo "Pushed to origin/${BRANCH}"
