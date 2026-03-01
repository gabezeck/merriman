#!/bin/bash
# adapters/claude.sh — Claude CLI (claude-code) runtime adapter
#
# Uses the `claude` CLI (Claude Code) in non-interactive prompt mode.
# A reasonable fallback when omp is not available, but with notable limitations.
#
# Limitations vs omp:
#   - No hook system: cannot enforce invariants on tool calls (e.g. memory scoping)
#   - No session management: each run is independent and stateless
#   - MCP servers configured separately via ~/.claude/settings.json (not .mcp.json)
#   - No RPC mode: cannot be used for the Phase 2 web chat interface
#   - No thinking display
#
# Install Claude Code:
#   https://claude.ai/download
#
# Sourced by scripts/_common.sh. Do not execute directly.

# ── Binary resolution ─────────────────────────────────────────────────────────
_claude_bin() {
  local bin=""
  for candidate in \
    "$(command -v claude 2>/dev/null)" \
    "$HOME/.claude/local/claude" \
    "/usr/local/bin/claude"; do
    if [[ -x "$candidate" ]]; then
      bin="$candidate"
      break
    fi
  done
  if [[ -z "$bin" ]]; then
    echo "[ERROR] claude CLI binary not found." >&2
    echo "  Install Claude Code: https://claude.ai/download" >&2
    exit 1
  fi
  echo "$bin"
}

# ── _run_claude <prompt> [logfile] ───────────────────────────────────────────
# Runs claude -p "<prompt>" from MERRIMAN_DIR.
# MCP servers and system prompts must be configured via ~/.claude/settings.json
# or a CLAUDE.md in the project root — not via .mcp.json.
_run_claude() {
  local prompt="$1"
  local claude_bin
  claude_bin=$(_claude_bin)

  cd "${MERRIMAN_DIR}"
  "$claude_bin" -p "$prompt" 2>&1
}
