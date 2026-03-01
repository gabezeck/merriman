#!/bin/bash
# scheduling/cron/install.sh — Add Merriman agents to the user crontab
#
# Usage: bash scheduling/cron/install.sh [--agent <name>]
#
#   --agent <name>   Install only the named agent.
#                    Omit to install all enabled agents.
#
# Appends one crontab entry per enabled agent, using the cron expression from
# agent.yml. Safe to re-run — each entry is only added once (duplicate check
# by agent name).
#
# Unlike launchd and systemd, cron does NOT run missed jobs after a system
# wake/resume. For reliability on laptops, prefer launchd (macOS) or systemd
# timers with Persistent=true (Linux).

set -euo pipefail

MERRIMAN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="${MERRIMAN_DIR}/agents"
TARGET_AGENT=""

if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "Error: --agent requires an agent name" >&2
    exit 1
  fi
fi

if ! command -v crontab &>/dev/null; then
  echo "Error: crontab not found." >&2
  exit 1
fi

# ── Build PATH for cron entries ───────────────────────────────────────────────
CRON_PATH="${HOME}/.bun/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# ── Read existing crontab ─────────────────────────────────────────────────────
existing_crontab=$(crontab -l 2>/dev/null || echo "")

echo "Merriman — installing cron entries"
echo "  Repo: $MERRIMAN_DIR"
echo ""

installed=0
skipped=0
failed=0

# ── Header block (add once) ───────────────────────────────────────────────────
header="# Merriman agents — managed by scheduling/cron/install.sh"
new_entries=""

if ! echo "$existing_crontab" | grep -qF "$header"; then
  new_entries+="${header}
PATH=${CRON_PATH}
MERRIMAN_DIR=${MERRIMAN_DIR}
"
fi

for agent_dir in "${AGENTS_DIR}"/*/; do
  [[ -d "$agent_dir" ]] || continue
  [[ -f "${agent_dir}/agent.yml" ]] || continue

  agent_name="$(basename "$agent_dir")"

  if [[ -n "$TARGET_AGENT" && "$agent_name" != "$TARGET_AGENT" ]]; then
    continue
  fi

  yml=$(cat "${agent_dir}/agent.yml")

  # Check enabled
  enabled=$(echo "$yml" | grep -E "^enabled:" | awk '{print $2}' || echo "true")
  if [[ "$enabled" == "false" ]]; then
    echo "  - $agent_name (disabled — skipping)"
    (( skipped++ )) || true
    continue
  fi

  # Extract cron expression
  cron=$(echo "$yml" | grep -E "^\s*cron:" | sed 's/.*cron:\s*//' | tr -d '"'"'" || echo "")
  if [[ -z "$cron" ]]; then
    echo "  [FAIL] $agent_name: no schedule.cron in agent.yml" >&2
    (( failed++ )) || true
    continue
  fi

  # Duplicate check — skip if a line for this agent already exists
  if echo "$existing_crontab" | grep -qF "run-agent.sh \$MERRIMAN_DIR/agents/${agent_name}"; then
    echo "  = $agent_name (already in crontab — skipping)"
    (( skipped++ )) || true
    continue
  fi

  log_file="\$MERRIMAN_DIR/logs/${agent_name}.log"
  entry="${cron}  /bin/bash \$MERRIMAN_DIR/scripts/run-agent.sh \$MERRIMAN_DIR/agents/${agent_name} >> ${log_file} 2>&1"

  new_entries+="${entry}
"
  echo "  + $agent_name ($cron)"
  (( installed++ )) || true
done

if [[ -n "$new_entries" ]]; then
  # Append to crontab
  (echo "$existing_crontab"; echo ""; echo "$new_entries") | crontab -
fi

echo ""
echo "${installed} installed  ${skipped} skipped  ${failed} failed"
echo ""

if [[ $installed -gt 0 ]]; then
  echo "View your crontab: crontab -l"
  echo "Remove entries:    bash scheduling/cron/uninstall.sh"
  echo ""
  echo "Note: cron does not run missed jobs after system sleep/wake."
  echo "Consider scheduling/launchd/ (macOS) or scheduling/systemd/ (Linux) for reliability."
  echo ""
fi

[[ $failed -eq 0 ]]
