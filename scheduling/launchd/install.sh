#!/bin/bash
# scheduling/launchd/install.sh — Install Merriman agents as macOS launchd jobs
#
# Usage: bash scheduling/launchd/install.sh [--agent <name>]
#
#   --agent <name>   Install only the named agent (e.g. morning-briefing)
#                    Omit to install all enabled agents.
#
# Each installed agent runs via scripts/run-agent.sh, which reads agent.yml
# and prompt.md from the agent directory. Schedules are derived from the
# cron expression in agent.yml.
#
# Plists are written to ~/Library/LaunchAgents/ and bootstrapped into the
# current user session. Safe to re-run — existing jobs are unloaded first.
#
# Requirements: macOS, Python 3 (for cron → launchd XML conversion)

set -euo pipefail

MERRIMAN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="${MERRIMAN_DIR}/agents"
LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
SCRIPT_DIR="$(dirname "$0")"
PLIST_GEN="${SCRIPT_DIR}/plist_for_agent.py"
TARGET_AGENT=""

# Parse --agent flag
if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "Error: --agent requires an agent name" >&2
    exit 1
  fi
fi

# ── Preflight checks ──────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: launchd scheduling is macOS only. Use scheduling/systemd/ or scheduling/cron/ on Linux." >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required for plist generation." >&2
  exit 1
fi

if ! command -v yq &>/dev/null; then
  echo "Warning: yq not found — skipping enabled-flag check. All agents with agent.yml will be processed." >&2
fi

mkdir -p "$LAUNCH_AGENTS"
mkdir -p "${MERRIMAN_DIR}/logs"

echo "Merriman — installing launchd agents"
echo "  Repo:   $MERRIMAN_DIR"
echo "  Target: $LAUNCH_AGENTS"
echo ""

installed=0
skipped=0
failed=0

for agent_dir in "${AGENTS_DIR}"/*/; do
  [[ -d "$agent_dir" ]] || continue
  [[ -f "${agent_dir}/agent.yml" ]] || continue

  agent_name="$(basename "$agent_dir")"

  # Filter by --agent flag if provided
  if [[ -n "$TARGET_AGENT" && "$agent_name" != "$TARGET_AGENT" ]]; then
    continue
  fi

  label="com.merriman.${agent_name}"
  dest="${LAUNCH_AGENTS}/${label}.plist"

  # Generate plist via Python helper
  plist_output=$(python3 "$PLIST_GEN" "$agent_dir" "$MERRIMAN_DIR" 2>&1)
  exit_code=$?

  if [[ $exit_code -eq 2 ]]; then
    echo "  - $agent_name (disabled — skipping)"
    (( skipped++ )) || true
    continue
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo "  [FAIL] $agent_name: $plist_output" >&2
    (( failed++ )) || true
    continue
  fi

  # Write plist
  echo "$plist_output" > "$dest"

  # Unload if already running (ignore errors — may not be loaded yet)
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true

  # Bootstrap into current user session
  if launchctl bootstrap "gui/$(id -u)" "$dest" 2>/dev/null; then
    echo "  + $label"
    (( installed++ )) || true
  else
    echo "  [FAIL] Failed to bootstrap $label — check $dest for errors" >&2
    (( failed++ )) || true
  fi
done

echo ""
echo "${installed} installed  ${skipped} skipped  ${failed} failed"
echo ""

if [[ $installed -gt 0 ]]; then
  echo "Useful commands:"
  echo "  Status:    launchctl list | grep com.merriman"
  echo "  Run now:   launchctl kickstart -k gui/$(id -u)/com.merriman.<name>"
  echo "  Logs:      tail -f ${MERRIMAN_DIR}/logs/launchd.log"
  echo "  Uninstall: bash scheduling/launchd/uninstall.sh"
  echo ""
fi

[[ $failed -eq 0 ]]
