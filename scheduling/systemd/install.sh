#!/bin/bash
# scheduling/systemd/install.sh — Install Merriman agents as systemd timer units
#
# Usage: bash scheduling/systemd/install.sh [--agent <name>]
#
#   --agent <name>   Install only the named agent.
#                    Omit to install all enabled agents.
#
# Generates a .service + .timer unit pair per agent, installs them into
# ~/.config/systemd/user/ (user scope — no root required), and enables them.
#
# Requirements: Linux with systemd, Python 3

set -euo pipefail

MERRIMAN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
AGENTS_DIR="${MERRIMAN_DIR}/agents"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
SCRIPT_DIR="$(dirname "$0")"
SERVICE_TMPL="${SCRIPT_DIR}/agent.service.template"
TIMER_TMPL="${SCRIPT_DIR}/agent.timer.template"
ONCAL_PY="${SCRIPT_DIR}/oncalendar_for_agent.py"
TARGET_AGENT=""

if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "Error: --agent requires an agent name" >&2
    exit 1
  fi
fi

# ── Preflight ─────────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Linux" ]]; then
  echo "Error: systemd scheduling is Linux only. Use scheduling/launchd/ on macOS." >&2
  exit 1
fi

if ! command -v systemctl &>/dev/null; then
  echo "Error: systemctl not found. Is systemd running?" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 is required for cron → OnCalendar conversion." >&2
  exit 1
fi

# Build PATH for the service units
AGENT_PATH="${HOME}/.bun/bin:/usr/local/bin:/usr/bin:/bin"

mkdir -p "$SYSTEMD_USER_DIR"

echo "Merriman — installing systemd units"
echo "  Repo:   $MERRIMAN_DIR"
echo "  Target: $SYSTEMD_USER_DIR"
echo ""

installed=0
skipped=0
failed=0

for agent_dir in "${AGENTS_DIR}"/*/; do
  [[ -d "$agent_dir" ]] || continue
  [[ -f "${agent_dir}/agent.yml" ]] || continue

  agent_name="$(basename "$agent_dir")"

  if [[ -n "$TARGET_AGENT" && "$agent_name" != "$TARGET_AGENT" ]]; then
    continue
  fi

  yml=$(cat "${agent_dir}/agent.yml")

  # Check enabled flag
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

  # Convert cron to OnCalendar
  oncalendar=$(python3 "$ONCAL_PY" "$cron" 2>&1) || {
    echo "  [FAIL] $agent_name: could not convert cron expression: $cron" >&2
    (( failed++ )) || true
    continue
  }

  service_name="merriman-${agent_name}"
  service_file="${SYSTEMD_USER_DIR}/${service_name}.service"
  timer_file="${SYSTEMD_USER_DIR}/${service_name}.timer"

  # Generate .service unit
  sed \
    -e "s|__AGENT_NAME__|${agent_name}|g" \
    -e "s|__AGENT_DIR__|${MERRIMAN_DIR}|g" \
    -e "s|__USER__|${USER}|g" \
    -e "s|__PATH__|${AGENT_PATH}|g" \
    "$SERVICE_TMPL" > "$service_file"

  # Generate .timer unit
  sed \
    -e "s|__AGENT_NAME__|${agent_name}|g" \
    -e "s|__CRON__|${cron}|g" \
    -e "s|__ONCALENDAR__|${oncalendar}|g" \
    "$TIMER_TMPL" > "$timer_file"

  # Enable and start the timer
  systemctl --user daemon-reload
  systemctl --user enable --now "${service_name}.timer" 2>/dev/null && {
    echo "  + ${service_name}.timer"
    (( installed++ )) || true
  } || {
    echo "  [FAIL] Failed to enable ${service_name}.timer" >&2
    (( failed++ )) || true
  }
done

echo ""
echo "${installed} installed  ${skipped} skipped  ${failed} failed"
echo ""

if [[ $installed -gt 0 ]]; then
  echo "Useful commands:"
  echo "  Status:    systemctl --user list-timers 'merriman-*'"
  echo "  Run now:   systemctl --user start merriman-<name>.service"
  echo "  Logs:      journalctl --user -u merriman-<name>"
  echo "  Uninstall: bash scheduling/systemd/uninstall.sh"
  echo ""
fi

[[ $failed -eq 0 ]]
