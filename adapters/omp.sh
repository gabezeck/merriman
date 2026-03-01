#!/bin/bash
# adapters/omp.sh — omp (Oh My Pi) runtime adapter
#
# omp is the recommended runtime. It is the only adapter that supports:
#   - The hook system (.omp/hooks/) for enforcing invariants like memory scoping
#   - Session continuity and context across runs
#   - RPC mode for the Phase 2 web chat interface (streaming, session resume)
#   - Thinking display and thinking-level configuration
#   - MCP servers configured via .mcp.json in the project root
#
# Install omp:
#   curl -fsSL https://bun.sh/install | bash
#   bun install -g @openagentsinc/omp
#
# Sourced by scripts/_common.sh. Do not execute directly.

# ── Binary resolution ─────────────────────────────────────────────────────────
# Probes known install locations rather than relying on PATH alone.
# Schedulers (launchd, systemd) run with a stripped PATH.
_omp_bin() {
  local bin=""
  for candidate in \
    "$(command -v omp 2>/dev/null)" \
    "$HOME/.bun/bin/omp" \
    "/opt/homebrew/bin/omp" \
    "/usr/local/bin/omp"; do
    if [[ -x "$candidate" ]]; then
      bin="$candidate"
      break
    fi
  done
  if [[ -z "$bin" ]]; then
    echo "[ERROR] omp binary not found. Searched PATH and common install locations." >&2
    echo "  Install: curl -fsSL https://bun.sh/install | bash" >&2
    echo "           bun install -g @openagentsinc/omp" >&2
    exit 1
  fi
  echo "$bin"
}

# ── _run_omp <prompt> [logfile] ───────────────────────────────────────────────
# Runs omp in prompt (-p) mode. Runs from MERRIMAN_DIR so omp picks up:
#   - .omp/SYSTEM.md (system prompt)
#   - .omp/hooks/   (pre/post tool call hooks)
#   - .mcp.json     (MCP server configuration)
#
# Filters omp's spurious "Warning: No models match pattern" stderr noise.
# Output is printed to stdout; callers (run-agent.sh) capture it.
_run_omp() {
  local prompt="$1"
  local omp_bin
  omp_bin=$(_omp_bin)

  cd "${MERRIMAN_DIR}"
  "$omp_bin" -p "$prompt" 2>&1 | grep -v 'Warning: No models match pattern' || true
}

# ── _run_omp_rpc [session_path] ───────────────────────────────────────────────
# Starts omp in RPC mode for the Phase 2 WebSocket chat bridge.
# Not called by run-agent.sh — invoked directly by the server's WebSocket handler.
#
# RPC mode: omp reads JSONL from stdin and writes JSONL to stdout.
# The server bridges this to/from the WebSocket client.
#
# With --resume: omp restores the prior session, giving context continuity
# across page reloads and devices.
_run_omp_rpc() {
  local session_path="${1:-}"
  local omp_bin
  omp_bin=$(_omp_bin)

  cd "${MERRIMAN_DIR}"
  if [[ -n "$session_path" && -f "$session_path" ]]; then
    "$omp_bin" --mode rpc --resume "$session_path"
  else
    "$omp_bin" --mode rpc
  fi
}
