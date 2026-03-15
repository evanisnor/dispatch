#!/usr/bin/env bash
# save-plan.sh — persist plan YAML to plan storage with git-based mutex lock
# Usage: save-plan.sh <plan-file-path> < <updated-yaml>
#   plan-file-path: path relative to PLAN_REPO (e.g. plans/EPIC-123.yaml)
#   updated YAML is read from stdin

set -euo pipefail

PLAN_FILE="${1:-}"
if [[ -z "${PLAN_FILE}" ]]; then
  echo "Usage: save-plan.sh <plan-file-path> < updated-yaml" >&2
  exit 1
fi

source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"

FULL_PATH="${PLAN_REPO}/${PLAN_FILE}"
LOCK_FILE="${PLAN_REPO}/.lock"

# Read updated YAML content from stdin before acquiring lock
UPDATED_YAML="$(cat)"

# Initialise plan repo as a git repo if it is not already one
if [[ ! -d "${PLAN_REPO}/.git" ]]; then
  git -C "${PLAN_REPO}" init --quiet
fi

# Detect whether a remote named 'origin' is configured
_has_remote() {
  git -C "${PLAN_REPO}" remote get-url origin &>/dev/null
}

# Warn if operating without a remote — non-blocking, surfaces to Orchestrating Agent
if ! _has_remote; then
  echo "WARNING: plan storage has no remote — plans are saved locally only. Add a remote to enable sync and backup." >&2
fi

_acquire_lock() {
  local attempt="$1"
  local delay="$2"

  cd "${PLAN_REPO}"
  if _has_remote; then
    git pull --rebase --quiet origin main 2>/dev/null || true
  fi

  # Attempt to create lock file and commit it
  echo "locked by save-plan.sh pid=$$ at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${LOCK_FILE}"
  git add "${LOCK_FILE}"

  if git commit -m "lock: acquire for plan update (attempt ${attempt})" --quiet 2>/dev/null; then
    if _has_remote; then
      if git push origin main --quiet 2>/dev/null; then
        return 0
      fi
      # Push failed — someone else committed first; clean up local commit
      git reset --soft HEAD~1 --quiet
      git restore --staged "${LOCK_FILE}" 2>/dev/null || true
      rm -f "${LOCK_FILE}"
    else
      # No remote — local commit is sufficient as the lock
      return 0
    fi
  else
    # Commit failed — clean up staged file
    git restore --staged "${LOCK_FILE}" 2>/dev/null || true
    rm -f "${LOCK_FILE}"
  fi

  echo "Lock acquisition attempt ${attempt} failed; retrying in ${delay}s..." >&2
  sleep "${delay}"
  return 1
}

_release_lock() {
  cd "${PLAN_REPO}"
  if [[ -f "${LOCK_FILE}" ]]; then
    git rm -f "${LOCK_FILE}" --quiet
    git commit -m "lock: release after plan update" --quiet
    if _has_remote; then
      git push origin main --quiet
    fi
  fi
}

# Exponential backoff: up to 3 retries at 2s / 4s / 8s
DELAYS=(2 4 8)
LOCKED=false
for i in 0 1 2 3; do
  if [[ "${i}" -gt 0 ]]; then
    delay="${DELAYS[$((i-1))]}"
  else
    delay=0
  fi

  if [[ "${delay}" -gt 0 ]]; then
    sleep "${delay}"
  fi

  if _acquire_lock "$((i+1))" "${DELAYS[$i]:-0}" 2>/dev/null; then
    LOCKED=true
    break
  fi
  [[ "${i}" -lt 3 ]] || true
done

if [[ "${LOCKED}" != "true" ]]; then
  echo "Error: failed to acquire plan lock after 4 attempts. Another process may be writing. Escalate to Primary Agent." >&2
  exit 1
fi

# Lock acquired — pull latest (if remote), write, commit, push (if remote), then release
trap '_release_lock' EXIT

cd "${PLAN_REPO}"
if _has_remote; then
  git pull --rebase --quiet origin main
fi

mkdir -p "$(dirname "${FULL_PATH}")"
printf '%s\n' "${UPDATED_YAML}" > "${FULL_PATH}"

git add "${FULL_PATH}"
git commit -m "plan: update ${PLAN_FILE}" --quiet
if _has_remote; then
  git push origin main --quiet
fi

echo "Plan saved: ${FULL_PATH}"
