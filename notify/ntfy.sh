#!/bin/bash
# notify/ntfy.sh — Send a push notification via ntfy
#
# Reads message from stdin. Called by _notify_ntfy() in scripts/_common.sh.
#
# Required environment variables (set in .env):
#   NTFY_TOPIC  — topic name (e.g. my-alerts) or full URL (e.g. https://ntfy.sh/my-alerts)
#
# Optional environment variables:
#   NTFY_URL    — base server URL (default: https://ntfy.sh)
#                 Override for self-hosted: http://localhost:8080
#
# Self-hosted ntfy: https://docs.ntfy.sh/install/
# ntfy.sh (public):  https://ntfy.sh
#
# ntfy message limit: 4096 bytes. Messages exceeding this are truncated.

set -euo pipefail

message=$(cat)
[[ -z "$message" ]] && exit 0

if [[ -z "${NTFY_TOPIC:-}" ]]; then
  echo "[ERROR] notify/ntfy.sh: NTFY_TOPIC is not set." >&2
  echo "  Set it in your .env file." >&2
  exit 1
fi

# Build endpoint: use NTFY_TOPIC directly if it's already a URL
if [[ "$NTFY_TOPIC" =~ ^https?:// ]]; then
  NTFY_ENDPOINT="$NTFY_TOPIC"
else
  NTFY_BASE="${NTFY_URL:-https://ntfy.sh}"
  NTFY_ENDPOINT="${NTFY_BASE%/}/${NTFY_TOPIC}"
fi

# Truncate at 4000 bytes (safe margin under the 4096 limit)
if [[ ${#message} -gt 4000 ]]; then
  message="${message:0:4000}…"
fi

# Use first non-empty, non-formatting line as the notification title
title=$(echo "$message" | grep -m1 '[a-zA-Z0-9]' | sed 's/\*\*//g; s/^#* *//' | cut -c1-100)
[[ -z "$title" ]] && title="Agent notification"

response=$(curl -s -w "\n%{http_code}" -X POST "$NTFY_ENDPOINT" \
  -H "Title: ${title}" \
  -H "Content-Type: text/plain; charset=utf-8" \
  --data-binary "$message")

http_code=$(echo "$response" | tail -1)
if [[ "$http_code" != "200" ]]; then
  body=$(echo "$response" | head -n -1)
  echo "[WARN] notify/ntfy.sh: server returned HTTP $http_code" >&2
  echo "$body" >&2
fi
