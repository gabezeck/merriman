#!/bin/bash
# _common.sh — Shared utilities for all agent scripts
# Source this at the top of every agent script:
#   source "$(dirname "$0")/_common.sh"

set -euo pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
# MERRIMAN_DIR is always the repo root (parent of scripts/)
MERRIMAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${MERRIMAN_DIR}/logs"
CONFIG_FILE="${MERRIMAN_DIR}/config.yml"

# ── Logging helper ────────────────────────────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# ── yq wrapper ───────────────────────────────────────────────────────────────
# yq is required for YAML parsing. https://github.com/mikefarah/yq
#   macOS: brew install yq
#   Linux: snap install yq  |  or download binary from GitHub releases
_yq() {
  if ! command -v yq &>/dev/null; then
    echo "[ERROR] 'yq' is required but was not found." >&2
    echo "  Install: brew install yq  (macOS)  |  snap install yq  (Linux)" >&2
    echo "  Or: https://github.com/mikefarah/yq/releases" >&2
    exit 1
  fi
  yq "$@"
}

# ── load_config() ─────────────────────────────────────────────────────────────
# Validates that config.yml exists. Call before reading any config values.
load_config() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] config.yml not found at $CONFIG_FILE" >&2
    echo "  Copy config.example.yaml to config.yml and edit it." >&2
    exit 1
  fi
}

# ── load_secrets() ────────────────────────────────────────────────────────────
# Exports all variables from .env into the current shell environment.
# The .env file uses KEY=value syntax; comments (#) and blank lines are ignored.
load_secrets() {
  local env_file="${MERRIMAN_DIR}/.env"
  if [[ ! -f "$env_file" ]]; then
    echo "[ERROR] .env file not found at $env_file" >&2
    echo "  Copy .env.example to .env and fill in your values." >&2
    exit 1
  fi
  # Export variables while skipping comments and blank lines
  set -a
  # shellcheck source=/dev/null
  source <(grep -v '^\s*#' "$env_file" | grep -v '^\s*$')
  set +a
}

# ── Runtime adapters ──────────────────────────────────────────────────────────
# Each adapter file defines its _run_*() function. Source all three so
# run_agent() can dispatch without knowing AGENT_RUNTIME at source time.
_ADAPTERS_DIR="${MERRIMAN_DIR}/adapters"

# shellcheck source=adapters/omp.sh
source "${_ADAPTERS_DIR}/omp.sh"
# shellcheck source=adapters/claude.sh
source "${_ADAPTERS_DIR}/claude.sh"
# shellcheck source=adapters/api.sh
source "${_ADAPTERS_DIR}/api.sh"

# ── run_agent() ───────────────────────────────────────────────────────────────
# Main dispatch function. Reads AGENT_RUNTIME (set from agent.yml or config.yml
# by run-agent.sh) and calls the appropriate adapter.
#
# Usage: run_agent "<prompt>" "<logfile>"
# Returns: agent output on stdout
run_agent() {
  local prompt="$1" log="$2"
  local runtime="${AGENT_RUNTIME:-omp}"
  case "$runtime" in
    omp)    _run_omp    "$prompt" "$log" ;;
    claude) _run_claude "$prompt" "$log" ;;
    api)    _run_api    "$prompt" "$log" ;;
    *)
      echo "[ERROR] Unknown runtime: '$runtime'. Valid options: omp, claude, api" >&2
      exit 1
      ;;
  esac
}

# ── Notification channel handlers ─────────────────────────────────────────────
# Full implementations will live in notify/ (Step 3).
# These stubs call the notify/ scripts if they exist, or warn if not yet built.

_notify_telegram() {
  local message="$1"
  local script="${MERRIMAN_DIR}/notify/telegram.sh"
  if [[ -x "$script" ]]; then
    echo "$message" | "$script"
  else
    echo "[WARN] notify/telegram.sh not found — is it executable?" >&2
  fi
}

_notify_discord() {
  local message="$1"
  local script="${MERRIMAN_DIR}/notify/discord.sh"
  if [[ -x "$script" ]]; then
    echo "$message" | "$script"
  else
    echo "[WARN] notify/discord.sh not found — is it executable?" >&2
  fi
}

_notify_ntfy() {
  local message="$1"
  local script="${MERRIMAN_DIR}/notify/ntfy.sh"
  if [[ -x "$script" ]]; then
    echo "$message" | "$script"
  else
    echo "[WARN] notify/ntfy.sh not found — is it executable?" >&2
  fi
}

_notify_email() {
  local message="$1"
  local script="${MERRIMAN_DIR}/notify/email.sh"
  if [[ -x "$script" ]]; then
    echo "$message" | "$script"
  else
    echo "[WARN] notify/email.sh not found — is it executable?" >&2
  fi
}

# ── notify() ─────────────────────────────────────────────────────────────────
# Fans out a message to all configured channels.
#
# Channel selection priority:
#   1. agent.yml notify.channels (if agent_dir is provided and has the key)
#   2. All globally enabled plugins from config.yml
#
# Usage: notify "<message>" [agent_dir]
notify() {
  local message="$1"
  local agent_dir="${2:-}"
  local -a channels=()

  # 1. Try agent-scoped channel list
  if [[ -n "$agent_dir" && -f "$agent_dir/agent.yml" ]]; then
    local agent_channels
    agent_channels=$(_yq '.notify.channels // [] | .[]' "$agent_dir/agent.yml" 2>/dev/null || true)
    if [[ -n "$agent_channels" ]]; then
      mapfile -t channels <<< "$agent_channels"
    fi
  fi

  # 2. Fall back to all globally configured plugin types
  if [[ ${#channels[@]} -eq 0 && -f "$CONFIG_FILE" ]]; then
    local global_channels
    global_channels=$(_yq '.notify.plugins // [] | .[].type' "$CONFIG_FILE" 2>/dev/null || true)
    if [[ -n "$global_channels" ]]; then
      mapfile -t channels <<< "$global_channels"
    fi
  fi

  if [[ ${#channels[@]} -eq 0 ]]; then
    echo "[WARN] No notify channels configured. Check config.yml and agent.yml." >&2
    return 0
  fi

  for channel in "${channels[@]}"; do
    case "$channel" in
      telegram) _notify_telegram "$message" ;;
      discord)  _notify_discord  "$message" ;;
      ntfy)     _notify_ntfy     "$message" ;;
      email)    _notify_email    "$message" ;;
      *)        echo "[WARN] Unknown notify channel: '$channel'" >&2 ;;
    esac
  done
}
