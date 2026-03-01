#!/bin/bash
# scheduling/launchd/uninstall.sh — Remove all Merriman launchd agents
#
# Usage: bash scheduling/launchd/uninstall.sh [--agent <name>]
#
#   --agent <name>   Remove only the named agent's plist.
#                    Omit to remove all com.merriman.* plists.

set -euo pipefail

LAUNCH_AGENTS="${HOME}/Library/LaunchAgents"
TARGET_AGENT="${2:-}"

if [[ "${1:-}" == "--agent" ]]; then
  TARGET_AGENT="${2:-}"
  if [[ -z "$TARGET_AGENT" ]]; then
    echo "Error: --agent requires an agent name" >&2
    exit 1
  fi
fi

if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: launchd is macOS only." >&2
  exit 1
fi

echo "Merriman — uninstalling launchd agents"
echo ""

removed=0

if [[ -n "$TARGET_AGENT" ]]; then
  pattern="${LAUNCH_AGENTS}/com.merriman.${TARGET_AGENT}.plist"
else
  pattern="${LAUNCH_AGENTS}/com.merriman.*.plist"
fi

for plist in $pattern; do
  [[ -f "$plist" ]] || continue
  label=$(basename "$plist" .plist)

  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  rm "$plist"

  echo "  - $label removed"
  (( removed++ )) || true
done

if [[ $removed -eq 0 ]]; then
  echo "  No Merriman agents found in $LAUNCH_AGENTS"
else
  echo ""
  echo "$removed agent(s) uninstalled."
fi
