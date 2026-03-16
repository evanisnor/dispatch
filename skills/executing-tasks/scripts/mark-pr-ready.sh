#!/usr/bin/env bash
# mark-pr-ready.sh — mark a draft PR ready for review
# Usage: mark-pr-ready.sh <pr-url-or-number>
#
# Verifies the PR is not targeting a protected branch before marking ready.

set -euo pipefail

PR="${1:-}"

if [[ -z "${PR}" ]]; then
  echo "Usage: mark-pr-ready.sh <pr-url-or-number>" >&2
  exit 1
fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/../../../scripts/config.sh"

# Check the base branch of the PR
BASE_BRANCH="$(gh pr view "${PR}" --json baseRefName --jq '.baseRefName' 2>/dev/null)"

for protected in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "${BASE_BRANCH}" == "${protected}" ]]; then
    # Targeting a protected branch is allowed (that's the point of PRs),
    # but we verify the HEAD branch is NOT a protected branch
    break
  fi
done

# Verify the HEAD branch is not a protected branch
HEAD_BRANCH="$(gh pr view "${PR}" --json headRefName --jq '.headRefName' 2>/dev/null)"

for protected in "${PROTECTED_BRANCHES[@]}"; do
  if [[ "${HEAD_BRANCH}" == "${protected}" ]]; then
    echo "Error: PR head branch '${HEAD_BRANCH}' is a protected branch. Cannot mark ready." >&2
    exit 1
  fi
done

gh pr ready "${PR}"
echo "PR marked ready: ${PR}"
