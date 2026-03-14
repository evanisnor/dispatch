#!/usr/bin/env bash
# load-plan.sh — fetch plan YAML from plan storage repository
# Usage: load-plan.sh <plan-file-path>
#   plan-file-path: path relative to PLAN_REPO (e.g. plans/EPIC-123.yaml)

set -euo pipefail

PLAN_FILE="${1:-}"
if [[ -z "${PLAN_FILE}" ]]; then
  echo "Usage: load-plan.sh <plan-file-path>" >&2
  exit 1
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

FULL_PATH="${PLAN_REPO}/${PLAN_FILE}"

if [[ ! -f "${FULL_PATH}" ]]; then
  echo "Error: plan file not found: ${FULL_PATH}" >&2
  exit 1
fi

cat "${FULL_PATH}"
