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

# --- Fork-point guard: strip local-only main commits before pushing ---
_REBASE_HAPPENED="false"
_GIT_DIR="$(git rev-parse --git-dir)"
_FORK_POINT_FILE="${_GIT_DIR}/dispatch-fork-point"

if [[ -f "${_FORK_POINT_FILE}" ]]; then
  _FORK_POINT="$(cat "${_FORK_POINT_FILE}")"
  git fetch origin main --quiet
  _ORIGIN_MAIN="$(git rev-parse origin/main)"

  if [[ "${_FORK_POINT}" != "${_ORIGIN_MAIN}" ]]; then
    echo "Rebasing task commits onto origin/main (stripping local-only main commits)..." >&2
    if ! git rebase --onto "${_ORIGIN_MAIN}" "${_FORK_POINT}"; then
      git rebase --abort 2>/dev/null || true
      echo "Error: rebase onto origin/main failed due to conflicts. Resolve and retry." >&2
      exit 1
    fi
    git rev-parse origin/main > "${_FORK_POINT_FILE}"
    _REBASE_HAPPENED="true"
  fi
fi

# Stage and commit if a commit message was provided
if [[ -n "${COMMIT_MSG}" ]]; then
  git add -A
  git commit -m "${COMMIT_MSG}"
fi

if [[ "${_REBASE_HAPPENED}" == "true" ]]; then
  git push --force-with-lease origin "${BRANCH}"
else
  git push origin "${BRANCH}"
fi
echo "Pushed to origin/${BRANCH}"
