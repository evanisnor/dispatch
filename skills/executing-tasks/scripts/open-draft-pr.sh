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

PR_URL="$(gh pr create \
  --draft \
  --title "${TITLE}" \
  --body "${BODY}" \
  --base main \
  --head "${BRANCH}")"

echo "${PR_URL}"
