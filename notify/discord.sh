#!/bin/bash
# notify/discord.sh — Send a message via Discord webhook
#
# Reads message from stdin. Called by _notify_discord() in scripts/_common.sh.
#
# Required environment variables (set in .env):
#   DISCORD_WEBHOOK_URL  — from Server Settings → Integrations → Webhooks
#
# Discord renders markdown natively in message content.
# Content limit: 2000 characters per message.
# Long messages are split into multiple webhook posts automatically.

set -euo pipefail

message=$(cat)
[[ -z "$message" ]] && exit 0

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  echo "[ERROR] notify/discord.sh: DISCORD_WEBHOOK_URL is not set." >&2
  echo "  Set it in your .env file." >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "[ERROR] notify/discord.sh: 'jq' is required but was not found." >&2
  exit 1
fi

# Discord content limit: 2000 characters
CHUNK_SIZE=2000
total=${#message}
offset=0

while [[ $offset -lt $total ]]; do
  chunk="${message:$offset:$CHUNK_SIZE}"
  offset=$(( offset + CHUNK_SIZE ))

  response=$(curl -s -w "\n%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg content "$chunk" '{content: $content}')")

  http_code=$(echo "$response" | tail -1)
  # 204 No Content is success for Discord webhooks
  if [[ "$http_code" != "200" && "$http_code" != "204" ]]; then
    body=$(echo "$response" | head -n -1)
    echo "[WARN] notify/discord.sh: webhook returned HTTP $http_code" >&2
    echo "$body" >&2
  fi
done
