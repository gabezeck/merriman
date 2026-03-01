#!/bin/bash
# run-agent.sh — Generic agent runner
#
# Usage: bash scripts/run-agent.sh <agent-directory> [--dry-run]
#
# Reads agent.yml and prompt.md from <agent-directory>, dispatches to the
# configured runtime, and fans out output to configured notify channels.
#
# This is the entry point called by all scheduler templates (launchd, systemd, cron).

# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
usage() {
  echo "Usage: $(basename "$0") <agent-directory> [--dry-run]" >&2
  echo "" >&2
  echo "  <agent-directory>  Path to an agent dir containing agent.yml and prompt.md" >&2
  echo "  --dry-run          Print resolved config and prompt without running" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage

AGENT_DIR="${1}"
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

# Resolve to absolute path
AGENT_DIR="$(cd "$AGENT_DIR" && pwd)"

# ── Validate agent directory ──────────────────────────────────────────────────
if [[ ! -f "$AGENT_DIR/agent.yml" ]]; then
  echo "[ERROR] $AGENT_DIR/agent.yml not found." >&2
  exit 1
fi

if [[ ! -f "$AGENT_DIR/prompt.md" ]]; then
  echo "[ERROR] $AGENT_DIR/prompt.md not found." >&2
  echo "  Create a prompt.md in your agent directory." >&2
  exit 1
fi

# ── Load config and secrets ───────────────────────────────────────────────────
load_config
load_secrets

# ── Read agent.yml ────────────────────────────────────────────────────────────
AGENT_NAME=$(_yq '.name' "$AGENT_DIR/agent.yml")
AGENT_ENABLED=$(_yq '.enabled // true' "$AGENT_DIR/agent.yml")
AGENT_RUNTIME=$(_yq '.runtime // ""' "$AGENT_DIR/agent.yml")
AGENT_SILENT_IF=$(_yq '.silent_if // ""' "$AGENT_DIR/agent.yml")

# Per-agent runtime overrides global; global falls back to "omp"
if [[ -z "$AGENT_RUNTIME" || "$AGENT_RUNTIME" == "null" ]]; then
  AGENT_RUNTIME=$(_yq '.runtime // "omp"' "$CONFIG_FILE" 2>/dev/null || echo "omp")
fi
export AGENT_RUNTIME

# ── Check enabled flag ────────────────────────────────────────────────────────
if [[ "$AGENT_ENABLED" == "false" ]]; then
  log "Agent '$AGENT_NAME' is disabled (enabled: false in agent.yml). Exiting."
  exit 0
fi

# ── Read prompt ───────────────────────────────────────────────────────────────
PROMPT="$(cat "$AGENT_DIR/prompt.md")"

# ── Dry run ───────────────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == "true" ]]; then
  echo "=== Dry run: $AGENT_NAME ==="
  echo "  Agent dir:  $AGENT_DIR"
  echo "  Runtime:    $AGENT_RUNTIME"
  echo "  Enabled:    $AGENT_ENABLED"
  echo "  Silent if:  ${AGENT_SILENT_IF:-<not set>}"
  echo ""
  echo "--- prompt.md ---"
  echo "$PROMPT"
  echo ""
  echo "(dry run — not executing)"
  exit 0
fi

# ── Set up logging ────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"
AGENT_ID="$(basename "$AGENT_DIR")"
LOG_FILE="$LOG_DIR/${AGENT_ID}.log"

log "Starting agent: $AGENT_NAME (runtime: $AGENT_RUNTIME)" >> "$LOG_FILE"

# ── Run the agent ─────────────────────────────────────────────────────────────
OUTPUT=""
OUTPUT=$(run_agent "$PROMPT" "$LOG_FILE")
EXIT_CODE=$?

echo "$OUTPUT" >> "$LOG_FILE"
log "Completed (exit: $EXIT_CODE)." >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

if [[ $EXIT_CODE -ne 0 ]]; then
  echo "[ERROR] Agent run failed with exit code $EXIT_CODE. See $LOG_FILE." >&2
  exit $EXIT_CODE
fi

# ── Notify ────────────────────────────────────────────────────────────────────
# Check silent_if sentinel before delivering
if [[ -n "$AGENT_SILENT_IF" && "$OUTPUT" =~ ^${AGENT_SILENT_IF} ]]; then
  log "Output starts with '${AGENT_SILENT_IF}' — skipping notification." >> "$LOG_FILE"
  exit 0
fi

notify "$OUTPUT" "$AGENT_DIR"
