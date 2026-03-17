#!/usr/bin/env bash
# append-knowledge.sh — Append a validated knowledge entry to the knowledge store
#
# Usage:
#   echo '<yaml-entry>' | append-knowledge.sh
#
# Reads a single YAML entry from stdin.
# Validates required fields: id, category, tags (non-empty list), context, lesson.
# Appends to $KNOWLEDGE_REPO/knowledge.yaml using the git write-with-lock pattern.
# If KNOWLEDGE_REPO is empty, exits 0 silently.
# Generates a unique id if not provided (k-<timestamp>-<random>).

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/config.sh"

# --- Guard: no-op if KNOWLEDGE_REPO is unset or empty ---

if [[ -z "${KNOWLEDGE_REPO:-}" ]]; then
  exit 0
fi

# --- Read entry from stdin ---

entry="$(cat)"

if [[ -z "${entry}" ]]; then
  echo "append-knowledge.sh: no input provided" >&2
  exit 1
fi

# Write to a temp file for validation and processing
_tmp_entry="$(mktemp /tmp/dispatch-knowledge-entry-XXXXXX.yaml)"
trap 'rm -f "${_tmp_entry}"' EXIT
printf '%s\n' "${entry}" > "${_tmp_entry}"

# --- Validate required fields ---

_validate_field() {
  local field="$1"
  local value
  value="$(yq e "${field} // \"\"" "${_tmp_entry}" 2>/dev/null || true)"
  if [[ -z "${value}" || "${value}" == "null" ]]; then
    echo "append-knowledge.sh: missing required field: ${field}" >&2
    exit 1
  fi
}

_validate_field '.category'
_validate_field '.context'
_validate_field '.lesson'

# Validate tags: must be a non-empty list
tags_count="$(yq e '(.tags // []) | length' "${_tmp_entry}" 2>/dev/null || echo "0")"
if [[ "${tags_count}" -eq 0 ]]; then
  echo "append-knowledge.sh: 'tags' must be a non-empty list" >&2
  exit 1
fi

# Validate category value
category="$(yq e '.category' "${_tmp_entry}")"
valid_categories=("planning" "ci" "conflict" "pr-review" "general" "prototype" "implementation")
is_valid=false
for c in "${valid_categories[@]}"; do
  if [[ "${category}" == "${c}" ]]; then
    is_valid=true
    break
  fi
done
if [[ "${is_valid}" == "false" ]]; then
  echo "append-knowledge.sh: invalid category '${category}'. Must be one of: ${valid_categories[*]}" >&2
  exit 1
fi

# --- Generate id if not provided ---

existing_id="$(yq e '.id // ""' "${_tmp_entry}" 2>/dev/null || true)"
if [[ -z "${existing_id}" || "${existing_id}" == "null" ]]; then
  timestamp="$(date -u +%Y%m%d%H%M%S)"
  random="$(head -c 4 /dev/urandom | xxd -p | head -c 6)"
  generated_id="k-${timestamp}-${random}"
  yq e -i ".id = \"${generated_id}\"" "${_tmp_entry}"
fi

# --- Add timestamp if not provided ---

existing_ts="$(yq e '.timestamp // ""' "${_tmp_entry}" 2>/dev/null || true)"
if [[ -z "${existing_ts}" || "${existing_ts}" == "null" ]]; then
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  yq e -i ".timestamp = \"${ts}\"" "${_tmp_entry}"
fi

# --- Ensure knowledge.yaml and KNOWLEDGE_REPO exist ---

if [[ ! -d "${KNOWLEDGE_REPO}" ]]; then
  mkdir -p "${KNOWLEDGE_REPO}"
fi

if ! git -C "${KNOWLEDGE_REPO}" rev-parse --git-dir &>/dev/null; then
  git -C "${KNOWLEDGE_REPO}" init --quiet
fi

knowledge_file="${KNOWLEDGE_REPO}/knowledge.yaml"

# Initialize knowledge.yaml as empty list if it doesn't exist
if [[ ! -f "${knowledge_file}" ]]; then
  printf '[]\n' > "${knowledge_file}"
  git -C "${KNOWLEDGE_REPO}" add knowledge.yaml
  git -C "${KNOWLEDGE_REPO}" commit -m "knowledge: initialize" --quiet
fi

# --- Write-with-lock pattern ---

_has_remote() {
  git -C "${KNOWLEDGE_REPO}" remote get-url origin &>/dev/null
}

_push_if_remote() {
  if _has_remote; then
    git -C "${KNOWLEDGE_REPO}" push origin main --quiet
  fi
}

# Step 1: Pull latest
if _has_remote; then
  git -C "${KNOWLEDGE_REPO}" pull --rebase --quiet origin main || true
fi

# Step 2: Acquire lock with retry
_lock_file="${KNOWLEDGE_REPO}/.lock"
_lock_acquired=false
_delays=(2 4 8)
_attempt=0

while [[ ${_attempt} -le ${#_delays[@]} ]]; do
  echo "locked by agent $$ at $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${_lock_file}"
  git -C "${KNOWLEDGE_REPO}" add .lock
  git -C "${KNOWLEDGE_REPO}" commit -m "lock: acquire" --quiet

  if ! _has_remote || git -C "${KNOWLEDGE_REPO}" push origin main --quiet 2>/dev/null; then
    _lock_acquired=true
    break
  fi

  # Push failed: contention — roll back and retry
  git -C "${KNOWLEDGE_REPO}" reset --soft HEAD~1 --quiet
  git -C "${KNOWLEDGE_REPO}" restore --staged .lock 2>/dev/null || true
  rm -f "${_lock_file}"

  if [[ ${_attempt} -ge ${#_delays[@]} ]]; then
    echo "append-knowledge.sh: failed to acquire lock after ${_attempt} attempts — escalate to Orchestrating Agent" >&2
    exit 1
  fi

  sleep "${_delays[${_attempt}]}"
  ((_attempt++))

  if _has_remote; then
    git -C "${KNOWLEDGE_REPO}" pull --rebase --quiet origin main || true
  fi
done

if [[ "${_lock_acquired}" != "true" ]]; then
  echo "append-knowledge.sh: could not acquire lock" >&2
  exit 1
fi

# Step 3: Append entry to knowledge.yaml in-place
yq e -i ". += [$(cat "${_tmp_entry}")]" "${knowledge_file}"

# Step 4: Commit and push
git -C "${KNOWLEDGE_REPO}" add knowledge.yaml
git -C "${KNOWLEDGE_REPO}" commit -m "knowledge: append entry $(yq e '.id' "${_tmp_entry}")" --quiet
_push_if_remote

# Step 5: Release lock
git -C "${KNOWLEDGE_REPO}" rm -f .lock --quiet
git -C "${KNOWLEDGE_REPO}" commit -m "lock: release" --quiet
_push_if_remote

echo "append-knowledge.sh: entry $(yq e '.id' "${_tmp_entry}") appended successfully"
