#!/usr/bin/env bash
# probe-repo.sh — detect whether the current repo has merge queue and required CI checks
#
# Exports:
#   MERGE_QUEUE_ENABLED  — "true" if a merge queue rule is active on any branch
#   HAS_REQUIRED_CHECKS  — "true" if required status checks are configured on the default branch
#
# Usage: source probe-repo.sh
# Prints a one-line summary to stdout on success.
# Exits 1 if repo info cannot be determined.

set -euo pipefail

REPO="$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true)"
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef -q '.defaultBranchRef.name' 2>/dev/null || true)"

if [[ -z "${REPO}" || -z "${DEFAULT_BRANCH}" ]]; then
  echo "probe-repo.sh: could not determine repo info" >&2
  exit 1
fi

# Check for a merge_queue rule in repository rulesets (modern GitHub API).
# Returns "false" gracefully if rulesets are not available (older plans, 404s).
_has_merge_queue() {
  gh api "repos/${REPO}/rulesets" \
    --jq '[.[] | .rules[]? | select(.type == "merge_queue")] | length > 0' \
    2>/dev/null || echo "false"
}

# Check for required CI checks via:
#   1. Classic branch protection (required_status_checks.contexts)
#   2. Repository rulesets (required_status_checks rule type)
# Returns "true" if either source reports at least one required check.
_has_required_checks() {
  local classic_count=0
  local ruleset_count=0

  classic_count="$(
    gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" \
      --jq '.required_status_checks.contexts | length' \
      2>/dev/null || echo "0"
  )"

  ruleset_count="$(
    gh api "repos/${REPO}/rulesets" \
      --jq '[.[] | .rules[]? | select(.type == "required_status_checks")] | length' \
      2>/dev/null || echo "0"
  )"

  if [[ "${classic_count}" -gt 0 || "${ruleset_count}" -gt 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}

# Check for required PR reviews via:
#   1. Classic branch protection (required_pull_request_reviews)
#   2. Repository rulesets (pull_request rule type)
# Returns "true" if at least one approving review is required before merge.
_has_required_reviews() {
  local classic
  classic="$(
    gh api "repos/${REPO}/branches/${DEFAULT_BRANCH}/protection" \
      --jq '.required_pull_request_reviews.required_approving_review_count > 0' \
      2>/dev/null || echo "false"
  )"

  if [[ "${classic}" == "true" ]]; then
    echo "true"
    return
  fi

  local ruleset_count=0
  ruleset_count="$(
    gh api "repos/${REPO}/rulesets" \
      --jq '[.[] | .rules[]? | select(.type == "pull_request")] | length' \
      2>/dev/null || echo "0"
  )"

  if [[ "${ruleset_count}" -gt 0 ]]; then
    echo "true"
  else
    echo "false"
  fi
}

export MERGE_QUEUE_ENABLED
MERGE_QUEUE_ENABLED="$(_has_merge_queue)"

export HAS_REQUIRED_CHECKS
HAS_REQUIRED_CHECKS="$(_has_required_checks)"

export HAS_REQUIRED_REVIEWS
HAS_REQUIRED_REVIEWS="$(_has_required_reviews)"

echo "Repo probe: merge_queue=${MERGE_QUEUE_ENABLED} required_checks=${HAS_REQUIRED_CHECKS} required_reviews=${HAS_REQUIRED_REVIEWS}"
