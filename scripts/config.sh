#!/usr/bin/env bash
# config.sh — shared configuration loader
# Sourced by all skill scripts via:
#   source "${CLAUDE_SKILL_DIR}/../../scripts/config.sh"
#
# Resolution priority (highest to lowest):
#   1. epic.config.* in the loaded plan YAML (applied by caller via apply_epic_config)
#   2. .dispatch.yaml defaults.* (per-project)
#   3. settings.yaml defaults.* (plugin fallback)

set -euo pipefail

# Locate plugin root relative to this script's directory
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PLUGIN_ROOT="${_SCRIPT_DIR}"

# Per-project config (gitignored, optional)
_PROJECT_CONFIG="${PWD}/.dispatch.yaml"

# Plugin defaults (committed)
_SETTINGS="${_PLUGIN_ROOT}/settings.yaml"

# Helper: read a value from .dispatch.yaml, fall back to settings.yaml defaults.*
# Usage: _cfg <yq-path-in-project-config> <yq-path-in-settings-defaults> <fallback-literal>
_cfg() {
  local project_path="$1"
  local settings_path="$2"
  local fallback="$3"

  local value=""

  if [[ -f "${_PROJECT_CONFIG}" ]]; then
    value="$(yq e "${project_path} // \"\"" "${_PROJECT_CONFIG}" 2>/dev/null || true)"
  fi

  if [[ -z "${value}" ]] && [[ -f "${_SETTINGS}" ]]; then
    value="$(yq e "${settings_path} // \"\"" "${_SETTINGS}" 2>/dev/null || true)"
  fi

  if [[ -z "${value}" ]]; then
    value="${fallback}"
  fi

  printf '%s' "${value}"
}

# Helper: resolve ~ in a path
_expand_path() {
  local path="$1"
  if [[ "${path}" == "~"* ]]; then
    path="${HOME}${path:1}"
  fi
  printf '%s' "${path}"
}

# Helper: read a YAML array from config, outputs one value per line
_cfg_array() {
  local project_path="$1"
  local settings_path="$2"
  local fallback_items="$3"

  local items=""

  if [[ -f "${_PROJECT_CONFIG}" ]]; then
    items="$(yq e "${project_path} // [] | .[]" "${_PROJECT_CONFIG}" 2>/dev/null || true)"
  fi

  if [[ -z "${items}" ]] && [[ -f "${_SETTINGS}" ]]; then
    items="$(yq e "${settings_path} // [] | .[]" "${_SETTINGS}" 2>/dev/null || true)"
  fi

  if [[ -z "${items}" ]]; then
    items="${fallback_items}"
  fi

  printf '%s' "${items}"
}

# --- Export configuration variables ---

export PLAN_REPO
PLAN_REPO="$(_expand_path "$(_cfg '.plan_storage.repo_path' '.defaults.plan_storage_repo_path // ""' '~/plans')")"

# PROTECTED_BRANCHES as a bash array
_protected_raw="$(_cfg_array '.git.protected_branches' '.defaults.protected_branches' $'main\nmaster')"
export PROTECTED_BRANCHES
IFS=$'\n' read -r -d '' -a PROTECTED_BRANCHES <<< "${_protected_raw}" || true

export ISSUE_TRACKING_TOOL
ISSUE_TRACKING_TOOL="$(_cfg '.issue_tracking.tool' '.defaults.issue_tracking_tool // ""' '')"

export ISSUE_TRACKING_READ_ONLY
ISSUE_TRACKING_READ_ONLY="$(_cfg '.issue_tracking.read_only' '.defaults.issue_tracking_read_only // ""' 'false')"

export ISSUE_TRACKING_PROMPT
ISSUE_TRACKING_PROMPT="$(_cfg '.issue_tracking.prompt' '.defaults.issue_tracking_prompt' '')"

# ALLOWED_DOMAINS as a bash array
_domains_raw="$(_cfg_array '.sandbox.network.allowed_domains' '.defaults.allowed_domains' $'github.com\napi.github.com\nregistry.npmjs.org')"
export ALLOWED_DOMAINS
IFS=$'\n' read -r -d '' -a ALLOWED_DOMAINS <<< "${_domains_raw}" || true

export MAX_CI_FIX_ATTEMPTS
MAX_CI_FIX_ATTEMPTS="$(_cfg '.defaults.max_ci_fix_attempts' '.defaults.max_ci_fix_attempts' '3')"

export MAX_AGENT_RESTARTS
MAX_AGENT_RESTARTS="$(_cfg '.defaults.max_agent_restarts' '.defaults.max_agent_restarts' '2')"

export POLLING_TIMEOUT_MINUTES
POLLING_TIMEOUT_MINUTES="$(_cfg '.defaults.polling_timeout_minutes' '.defaults.polling_timeout_minutes' '60')"

export DIFF_MODE
DIFF_MODE="$(_cfg '.diff.mode' '.defaults.diff_mode' 'split')"

# Enforce valid values
if [[ "${DIFF_MODE}" != "split" && "${DIFF_MODE}" != "unified" ]]; then
  DIFF_MODE="split"
fi

export PR_TEMPLATE_PATH
PR_TEMPLATE_PATH="$(_expand_path "$(_cfg '.pr.template_path' '.defaults.pr_template_path' '')")"

export PR_DESCRIPTION_PROMPT
PR_DESCRIPTION_PROMPT="$(_cfg '.pr.description_prompt' '.defaults.pr_description_prompt' '')"

export VERIFICATION_MANUAL_GATE
VERIFICATION_MANUAL_GATE="$(_cfg '.verification.manual_gate' '.defaults.verification_manual_gate' 'false')"

export VERIFICATION_STARTUP_COMMAND
VERIFICATION_STARTUP_COMMAND="$(_cfg '.verification.startup_command' '.defaults.verification_startup_command' '')"

export VERIFICATION_PROMPT
VERIFICATION_PROMPT="$(_cfg '.verification.prompt' '.defaults.verification_prompt' '')"

export CODE_REVIEW_PROMPT
CODE_REVIEW_PROMPT="$(_cfg '.code_review.prompt' '.defaults.code_review_prompt' '')"

# KNOWLEDGE_REPO defaults to PLAN_REPO when knowledge.repo_path is empty
_knowledge_repo_raw="$(_cfg '.knowledge.repo_path' '.knowledge.repo_path // ""' '')"
export KNOWLEDGE_REPO
if [[ -n "${_knowledge_repo_raw}" ]]; then
  KNOWLEDGE_REPO="$(_expand_path "${_knowledge_repo_raw}")"
else
  KNOWLEDGE_REPO="${PLAN_REPO}"
fi

export KNOWLEDGE_MAX_LOAD_ENTRIES
KNOWLEDGE_MAX_LOAD_ENTRIES="$(_cfg '.knowledge.max_load_entries' '.knowledge.max_load_entries // ""' '30')"

# Helper: check whether the plan repo has a remote named 'origin'
_has_remote() {
  git -C "${PLAN_REPO}" remote get-url origin &>/dev/null
}

# --- Per-epic config override ---
# Scripts that accept a plan path (e.g. spawn-agent.sh) should call
# apply_epic_config <plan_yaml_path> after sourcing this file to layer
# epic-level overrides on top of the values set above.
apply_epic_config() {
  local plan_path="$1"
  if [[ ! -f "${plan_path}" ]]; then
    return 0
  fi

  local epic_max_ci
  epic_max_ci="$(yq e '.epic.config.max_ci_fix_attempts // ""' "${plan_path}" 2>/dev/null || true)"
  [[ -n "${epic_max_ci}" ]] && export MAX_CI_FIX_ATTEMPTS="${epic_max_ci}"

  local epic_max_restarts
  epic_max_restarts="$(yq e '.epic.config.max_agent_restarts // ""' "${plan_path}" 2>/dev/null || true)"
  [[ -n "${epic_max_restarts}" ]] && export MAX_AGENT_RESTARTS="${epic_max_restarts}"

  local epic_timeout
  epic_timeout="$(yq e '.epic.config.polling_timeout_minutes // ""' "${plan_path}" 2>/dev/null || true)"
  [[ -n "${epic_timeout}" ]] && export POLLING_TIMEOUT_MINUTES="${epic_timeout}"
}
