#!/bin/bash
# adapters/api.sh — Anthropic Messages API direct adapter
#
# Calls the Anthropic API directly via curl. No MCP tools, no hook system,
# no session management, no memory — raw text generation only.
#
# Use this when:
#   - omp and claude are not installed (CI environments, minimal servers)
#   - The task does not require tool use (summarisation, formatting, analysis of
#     text already in the prompt)
#
# Limitations vs omp:
#   - No MCP tool access (no calendar, email, tasks, memory, weather, etc.)
#   - No hook system
#   - No session continuity
#   - No streaming output (response arrives all at once)
#
# Requirements: curl, jq
# Environment:  ANTHROPIC_API_KEY (set in .env)
#
# Optional config.yml keys:
#   api_model: claude-opus-4-6-20251101   # override the default model
#   api_max_tokens: 4096                  # override max response tokens
#
# Sourced by scripts/_common.sh. Do not execute directly.

# ── _run_api <prompt> [logfile] ──────────────────────────────────────────────
_run_api() {
  local prompt="$1"

  # Validate dependencies
  if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "[ERROR] ANTHROPIC_API_KEY is required for the 'api' runtime." >&2
    echo "  Set it in your .env file." >&2
    exit 1
  fi

  if ! command -v jq &>/dev/null; then
    echo "[ERROR] 'jq' is required for the api runtime but was not found." >&2
    echo "  Install: brew install jq  (macOS)  |  apt install jq  (Debian/Ubuntu)" >&2
    exit 1
  fi

  # Read model and token limit from config.yml, with sensible defaults
  local model="claude-opus-4-6-20251101"
  local max_tokens=4096

  if [[ -f "${CONFIG_FILE:-}" ]]; then
    local cfg_model cfg_tokens
    cfg_model=$(_yq '.api_model // ""' "$CONFIG_FILE" 2>/dev/null || true)
    cfg_tokens=$(_yq '.api_max_tokens // ""' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -n "$cfg_model"  && "$cfg_model"  != "null" ]] && model="$cfg_model"
    [[ -n "$cfg_tokens" && "$cfg_tokens" != "null" ]] && max_tokens="$cfg_tokens"
  fi

  # Call the API, capturing both body and HTTP status code
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    https://api.anthropic.com/v1/messages \
    -H "x-api-key: $ANTHROPIC_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -H "content-type: application/json" \
    -d "$(jq -n \
      --arg model      "$model" \
      --argjson tokens "$max_tokens" \
      --arg prompt     "$prompt" \
      '{
        model:      $model,
        max_tokens: $tokens,
        messages:   [{ role: "user", content: $prompt }]
      }')")

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)

  if [[ "$http_code" != "200" ]]; then
    echo "[ERROR] Anthropic API returned HTTP $http_code" >&2
    echo "$body" | jq -r '.error.message // .error // "Unknown error"' >&2 2>/dev/null || echo "$body" >&2
    exit 1
  fi

  echo "$body" | jq -r '.content[0].text'
}
