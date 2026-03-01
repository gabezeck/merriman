#!/bin/bash
# notify/telegram.sh — Send a message via Telegram Bot API
#
# Reads message from stdin. Called by _notify_telegram() in scripts/_common.sh.
#
# Required environment variables (set in .env):
#   TELEGRAM_BOT_TOKEN  — from @BotFather: https://core.telegram.org/bots#botfather
#   TELEGRAM_CHAT_ID    — your chat ID (send /start to @userinfobot to find it)
#
# Formatting:
#   If scripts/telegramify.py is present and Python is available, markdown is
#   converted to Telegram MessageEntity objects for rich formatting (bold, code,
#   links, etc.) without escaping headaches.
#   Otherwise, falls back to plain text with automatic chunking.
#
# Telegram message limit: 4096 UTF-16 code units per message.
# Long messages are split into multiple messages automatically.

set -euo pipefail

# MERRIMAN_DIR is set when sourced via _common.sh; resolve it here for standalone use
: "${MERRIMAN_DIR:="$(cd "$(dirname "$0")/.." && pwd)"}"

message=$(cat)
[[ -z "$message" ]] && exit 0

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  echo "[ERROR] notify/telegram.sh: TELEGRAM_BOT_TOKEN is not set." >&2
  echo "  Set it in your .env file." >&2
  exit 1
fi

if [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
  echo "[ERROR] notify/telegram.sh: TELEGRAM_CHAT_ID is not set." >&2
  echo "  Set it in your .env file." >&2
  exit 1
fi

API_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

# ── Helper: send a single pre-built JSON payload ─────────────────────────────
_tg_post() {
  local payload="$1"
  local response http_code body
  response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -H "Content-Type: application/json" \
    -d "$payload")
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | head -n -1)
  if [[ "$http_code" != "200" ]]; then
    echo "[WARN] notify/telegram.sh: API returned HTTP $http_code" >&2
    echo "$body" | jq -r '.description // "Unknown error"' >&2 2>/dev/null || true
  fi
}

# ── Rich formatting path (requires Python + telegramify-markdown) ─────────────
# Install: pip install telegramify-markdown  (or: pip install -r requirements.txt)
TELEGRAMIFY="${MERRIMAN_DIR}/scripts/telegramify.py"
PYTHON_BIN=""

for candidate in python3 python "${MERRIMAN_DIR}/.venv/bin/python3"; do
  if command -v "$candidate" &>/dev/null 2>&1; then
    PYTHON_BIN="$candidate"
    break
  fi
done

if [[ -n "$PYTHON_BIN" && -f "$TELEGRAMIFY" ]]; then
  json_output=$(echo "$message" | "$PYTHON_BIN" "$TELEGRAMIFY" 2>/dev/null) || json_output=""

  if [[ -n "$json_output" ]] && echo "$json_output" | jq -e '.chunks | length > 0' &>/dev/null 2>&1; then
    echo "$json_output" | jq -c '.chunks[]' | while IFS= read -r chunk; do
      text=$(echo "$chunk" | jq -r '.text')
      entities=$(echo "$chunk" | jq '.entities')
      _tg_post "$(jq -n \
        --arg chat_id  "$TELEGRAM_CHAT_ID" \
        --arg text     "$text" \
        --argjson ents "$entities" \
        '{chat_id: $chat_id, text: $text, entities: $ents}')"
    done
    exit 0
  fi
fi

# ── Plain text fallback ───────────────────────────────────────────────────────
# Split at 4000-char boundaries (safe margin under the 4096 UTF-16 limit).
CHUNK_SIZE=4000
total=${#message}
offset=0

while [[ $offset -lt $total ]]; do
  chunk="${message:$offset:$CHUNK_SIZE}"
  offset=$(( offset + CHUNK_SIZE ))
  _tg_post "$(jq -n \
    --arg chat_id "$TELEGRAM_CHAT_ID" \
    --arg text    "$chunk" \
    '{chat_id: $chat_id, text: $text}')"
done
