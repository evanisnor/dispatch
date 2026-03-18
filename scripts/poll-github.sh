#!/usr/bin/env bash
# poll-github.sh — consolidated single-shot GitHub polling
#
# Orchestrates check-review-requests.sh, check-pr-status.sh, and check-merge-queue.sh
# into a single call with unified YAML output.
#
# Input: YAML on stdin listing PRs to check (with in_merge_queue flag).
#   prs:
#     - number: 123
#       url: https://github.com/org/repo/pull/123
#       in_merge_queue: false
#
# Output: Structured YAML on stdout.
#   review_requests:
#     exit_code: 0
#     events: |
#       NEW_REVIEW_REQUEST <url> <number> <title> <author>
#   prs:
#     - number: 123
#       exit_code: 0
#       in_merge_queue: false
#       output: |
#         Result: approved and CI passing
#
# Exit codes:
#   0 = completed successfully (results in stdout)
#   1 = usage error or script failure

set -euo pipefail

_POLL_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths to subscripts
_CHECK_REVIEWS="${_POLL_SCRIPT_DIR}/check-review-requests.sh"
_CHECK_PR_STATUS="${_POLL_SCRIPT_DIR}/../skills/orchestrating-agents/scripts/check-pr-status.sh"
_CHECK_MERGE_QUEUE="${_POLL_SCRIPT_DIR}/check-merge-queue.sh"

# Validate subscripts exist
for _script in "${_CHECK_REVIEWS}" "${_CHECK_PR_STATUS}" "${_CHECK_MERGE_QUEUE}"; do
  if [[ ! -f "${_script}" ]]; then
    echo "poll-github.sh: missing subscript: ${_script}" >&2
    exit 1
  fi
done

# Read all stdin first (subscripts may also use stdin)
INPUT="$(cat)"

# --- Step 1: Check review requests ---
REVIEW_OUTPUT=""
REVIEW_EXIT=0
REVIEW_OUTPUT="$("${_CHECK_REVIEWS}" 2>&1)" || REVIEW_EXIT=$?

# --- Step 2: Check each PR ---
PR_COUNT=0
if [[ -n "${INPUT}" ]]; then
  PR_COUNT="$(printf '%s' "${INPUT}" | yq e '.prs | length' - 2>/dev/null || echo "0")"
fi

# Collect per-PR results in parallel arrays (bash 3.2 compatible)
PR_NUMBERS=""
PR_URLS=""
PR_IN_MQ=""
PR_EXITS=""
PR_OUTPUTS=""

idx=0
while [[ "${idx}" -lt "${PR_COUNT}" ]]; do
  NUMBER="$(printf '%s' "${INPUT}" | yq e ".prs[${idx}].number" - 2>/dev/null || echo "")"
  URL="$(printf '%s' "${INPUT}" | yq e ".prs[${idx}].url" - 2>/dev/null || echo "")"
  IN_MQ="$(printf '%s' "${INPUT}" | yq e ".prs[${idx}].in_merge_queue" - 2>/dev/null || echo "false")"

  if [[ -z "${URL}" || "${URL}" == "null" ]]; then
    idx=$(( idx + 1 ))
    continue
  fi

  PR_OUTPUT=""
  PR_EXIT=0

  if [[ "${IN_MQ}" == "true" ]]; then
    PR_OUTPUT="$("${_CHECK_MERGE_QUEUE}" "${URL}" 2>&1)" || PR_EXIT=$?
  else
    PR_OUTPUT="$("${_CHECK_PR_STATUS}" "${URL}" 2>&1)" || PR_EXIT=$?
  fi

  # Store results with delimiter
  PR_NUMBERS="${PR_NUMBERS}${NUMBER}"$'\x1e'
  PR_URLS="${PR_URLS}${URL}"$'\x1e'
  PR_IN_MQ="${PR_IN_MQ}${IN_MQ}"$'\x1e'
  PR_EXITS="${PR_EXITS}${PR_EXIT}"$'\x1e'
  PR_OUTPUTS="${PR_OUTPUTS}${PR_OUTPUT}"$'\x1f'

  idx=$(( idx + 1 ))
done

# --- Step 3: Emit structured YAML output ---
{
  echo "review_requests:"
  echo "  exit_code: ${REVIEW_EXIT}"
  if [[ -n "${REVIEW_OUTPUT}" ]]; then
    echo "  events: |"
    printf '%s\n' "${REVIEW_OUTPUT}" | while IFS= read -r line; do
      echo "    ${line}"
    done
  else
    echo "  events: \"\""
  fi

  echo "prs:"
  if [[ -z "${PR_NUMBERS}" ]]; then
    echo "  []"
  else
    # Split delimited strings back into per-PR entries
    _pr_idx=0
    _remaining_numbers="${PR_NUMBERS}"
    _remaining_urls="${PR_URLS}"
    _remaining_mq="${PR_IN_MQ}"
    _remaining_exits="${PR_EXITS}"
    _remaining_outputs="${PR_OUTPUTS}"

    while [[ -n "${_remaining_numbers}" ]]; do
      # Extract next value up to record separator
      _number="${_remaining_numbers%%$'\x1e'*}"
      _remaining_numbers="${_remaining_numbers#*$'\x1e'}"

      _url="${_remaining_urls%%$'\x1e'*}"
      _remaining_urls="${_remaining_urls#*$'\x1e'}"

      _mq="${_remaining_mq%%$'\x1e'*}"
      _remaining_mq="${_remaining_mq#*$'\x1e'}"

      _exit="${_remaining_exits%%$'\x1e'*}"
      _remaining_exits="${_remaining_exits#*$'\x1e'}"

      # Outputs use unit separator (0x1f) because they may contain newlines
      _output="${_remaining_outputs%%$'\x1f'*}"
      _remaining_outputs="${_remaining_outputs#*$'\x1f'}"

      [[ -z "${_number}" ]] && continue

      echo "  - number: ${_number}"
      echo "    exit_code: ${_exit}"
      echo "    in_merge_queue: ${_mq}"
      if [[ -n "${_output}" ]]; then
        echo "    output: |"
        printf '%s\n' "${_output}" | while IFS= read -r line; do
          echo "      ${line}"
        done
      else
        echo "    output: \"\""
      fi

      _pr_idx=$(( _pr_idx + 1 ))
    done
  fi
}
