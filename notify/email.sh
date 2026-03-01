#!/bin/bash
# notify/email.sh — Send a message via SMTP using curl
#
# Reads message from stdin. Called by _notify_email() in scripts/_common.sh.
#
# Required environment variables (set in .env):
#   SMTP_URL      — SMTP connection string
#                   e.g. smtp://user:password@smtp.gmail.com:587
#                        smtps://user:password@smtp.gmail.com:465
#   NOTIFY_EMAIL  — recipient address
#
# Optional environment variables:
#   NOTIFY_FROM   — sender address (defaults to NOTIFY_EMAIL)
#
# Gmail note: use an App Password if you have 2FA enabled.
#   https://support.google.com/accounts/answer/185833

set -euo pipefail

message=$(cat)
[[ -z "$message" ]] && exit 0

if [[ -z "${SMTP_URL:-}" ]]; then
  echo "[ERROR] notify/email.sh: SMTP_URL is not set." >&2
  echo "  Set it in your .env file (e.g. smtp://user:pass@smtp.example.com:587)." >&2
  exit 1
fi

if [[ -z "${NOTIFY_EMAIL:-}" ]]; then
  echo "[ERROR] notify/email.sh: NOTIFY_EMAIL is not set." >&2
  echo "  Set it in your .env file." >&2
  exit 1
fi

SMTP_FROM="${NOTIFY_FROM:-$NOTIFY_EMAIL}"

# Use first non-empty, non-formatting line as the email subject
subject=$(echo "$message" | grep -m1 '[a-zA-Z0-9]' | sed 's/\*\*//g; s/^#* *//' | cut -c1-100)
[[ -z "$subject" ]] && subject="Agent notification"

# Build a minimal RFC 2822 email
email_payload="From: ${SMTP_FROM}
To: ${NOTIFY_EMAIL}
Subject: ${subject}
Content-Type: text/plain; charset=utf-8
MIME-Version: 1.0

${message}"

response=$(echo "$email_payload" | curl -s -w "\n%{http_code}" \
  --url "$SMTP_URL" \
  --mail-from "$SMTP_FROM" \
  --mail-rcpt "$NOTIFY_EMAIL" \
  --upload-file -)

http_code=$(echo "$response" | tail -1)
if [[ "$http_code" != "250" && "$http_code" != "200" ]]; then
  body=$(echo "$response" | head -n -1)
  echo "[WARN] notify/email.sh: SMTP returned HTTP $http_code" >&2
  echo "$body" >&2
fi
