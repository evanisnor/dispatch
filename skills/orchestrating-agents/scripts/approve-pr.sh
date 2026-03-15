#!/usr/bin/env bash
# approve-pr.sh — approve an incoming pull request review
# Usage: approve-pr.sh <pr-url>

set -euo pipefail

PR_URL="${1:?Usage: approve-pr.sh <pr-url>}"

gh pr review "${PR_URL}" --approve
