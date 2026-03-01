#!/bin/bash
# scheduling/cron/uninstall.sh — Remove Merriman entries from the user crontab
#
# Usage: bash scheduling/cron/uninstall.sh [--agent <name>]
#
# Removes lines containing 'merriman' or 'run-agent.sh' that were added by
# install.sh, including the header block.

set -euo pipefail

TARGET_AGENT="${2:-}"
if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
fi

existing=$(crontab -l 2>/dev/null || echo "")
if [[ -z "$existing" ]]; then
  echo "Crontab is empty — nothing to remove."
  exit 0
fi

echo "Merriman — removing cron entries"
echo ""

if [[ -n "$TARGET_AGENT" ]]; then
  # Remove only lines referencing this agent
  new_crontab=$(echo "$existing" | grep -v "agents/${TARGET_AGENT}" || true)
  removed=$(echo "$existing" | grep -c "agents/${TARGET_AGENT}" || echo "0")
else
  # Remove all Merriman-managed lines (header + agent entries)
  new_crontab=$(echo "$existing" | grep -v "Merriman agents" | grep -v "run-agent.sh" | grep -v "MERRIMAN_DIR" || true)
  removed=$(echo "$existing" | grep -c "run-agent.sh" || echo "0")
fi

echo "$new_crontab" | crontab -

if [[ "$removed" -gt 0 ]]; then
  echo "  $removed line(s) removed."
else
  echo "  No Merriman entries found in crontab."
fi
echo ""
