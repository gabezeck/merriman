#!/bin/bash
# scheduling/systemd/uninstall.sh — Remove Merriman systemd timer units
#
# Usage: bash scheduling/systemd/uninstall.sh [--agent <name>]

set -euo pipefail

SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"
TARGET_AGENT=""

if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "Error: --agent requires an agent name" >&2
    exit 1
  fi
fi

if [[ "$(uname)" != "Linux" ]]; then
  echo "Error: systemd is Linux only." >&2
  exit 1
fi

echo "Merriman — uninstalling systemd units"
echo ""

removed=0

if [[ -n "$TARGET_AGENT" ]]; then
  pattern="${SYSTEMD_USER_DIR}/merriman-${TARGET_AGENT}.timer"
else
  pattern="${SYSTEMD_USER_DIR}/merriman-*.timer"
fi

for timer in $pattern; do
  [[ -f "$timer" ]] || continue
  name=$(basename "$timer" .timer)
  service="${SYSTEMD_USER_DIR}/${name}.service"

  systemctl --user disable --now "${name}.timer" 2>/dev/null || true
  rm -f "$timer" "$service"

  echo "  - ${name} removed"
  (( removed++ )) || true
done

if [[ $removed -gt 0 ]]; then
  systemctl --user daemon-reload
  echo ""
  echo "$removed unit(s) uninstalled."
else
  echo "  No Merriman units found in $SYSTEMD_USER_DIR"
fi
