#!/usr/bin/env bash
# load-knowledge.sh — Read and filter knowledge entries from the knowledge store
#
# Usage:
#   load-knowledge.sh [--category <cat>] [--tags <tag1,tag2>] [--limit <n>]
#
# Options:
#   --category <cat>    Filter by category (may be specified multiple times)
#   --tags <tag1,tag2>  Filter by tags (comma-separated; entry must match at least one)
#   --limit <n>         Maximum entries to output (default: $KNOWLEDGE_MAX_LOAD_ENTRIES)
#
# Outputs filtered YAML entries to stdout.
# If knowledge.yaml does not exist or KNOWLEDGE_REPO is empty, exits 0 silently.

set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_SCRIPT_DIR}/config.sh"

# --- Parse arguments ---

categories=()
tags=()
limit="${KNOWLEDGE_MAX_LOAD_ENTRIES:-30}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --category)
      categories+=("$2")
      shift 2
      ;;
    --tags)
      IFS=',' read -r -a _tag_arr <<< "$2"
      tags+=("${_tag_arr[@]}")
      shift 2
      ;;
    --limit)
      limit="$2"
      shift 2
      ;;
    *)
      echo "load-knowledge.sh: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# --- Guard: no-op if KNOWLEDGE_REPO is unset or empty ---

if [[ -z "${KNOWLEDGE_REPO:-}" ]]; then
  echo "load-knowledge.sh: KNOWLEDGE_REPO is not configured — no entries loaded" >&2
  exit 0
fi

knowledge_file="${KNOWLEDGE_REPO}/knowledge.yaml"

if [[ ! -f "${knowledge_file}" ]]; then
  exit 0
fi

# --- Build yq filter ---

# Base: select all entries
filter='.[]'

# Category filter: entry.category must be in the categories list
if [[ ${#categories[@]} -gt 0 ]]; then
  cat_exprs=()
  for cat in "${categories[@]}"; do
    cat_exprs+=(".category == \"${cat}\"")
  done
  cat_filter="$(IFS=' or '; echo "${cat_exprs[*]}")"
  filter="${filter} | select(${cat_filter})"
fi

# Tags filter: entry must have at least one matching tag
if [[ ${#tags[@]} -gt 0 ]]; then
  tag_exprs=()
  for tag in "${tags[@]}"; do
    tag_exprs+=("(.tags // [] | contains([\"${tag}\"]))")
  done
  tag_filter="$(IFS=' or '; echo "${tag_exprs[*]}")"
  filter="${filter} | select(${tag_filter})"
fi

# Apply filter and limit
yq e "[${filter}] | .[:${limit}] | .[]" "${knowledge_file}"
