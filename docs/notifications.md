# Notifications

Merriman fans out agent output to one or more notification channels after
each run. Channels are configured globally in `config.yml` and selected
per-agent in `agent.yml`.

---

## How it works

After an agent run completes, `scripts/run-agent.sh` calls `notify()` in
`scripts/_common.sh`. That function reads the agent's channel list from
`agent.yml`, falls back to all globally configured channels if none are
listed, and invokes the corresponding script in `notify/` for each.

Each `notify/*.sh` script reads the message from stdin and sends it to
its service. They are independent — a failure in one channel does not
prevent delivery to others.

---

## Configuring channels

### Global configuration — `config.yml`

Declare which plugins are available. Only the plugins listed here can be
referenced by agents:

```yaml
notify:
  plugins:
    - type: telegram
      token_env: TELEGRAM_BOT_TOKEN
      chat_id_env: TELEGRAM_CHAT_ID
    - type: discord
      webhook_env: DISCORD_WEBHOOK_URL
    - type: ntfy
      topic_env: NTFY_TOPIC
    - type: email
      smtp_env: SMTP_URL
      to_env: NOTIFY_EMAIL
```

Comment out any plugin you are not using.

### Per-agent selection — `agent.yml`

Each agent specifies which configured channels to use:

```yaml
notify:
  channels: [telegram] # single channel
  # channels: [telegram, discord]  # fan-out to both
```

If `channels` is omitted, the agent delivers to all globally configured
plugins.

---

## Channel setup

### Telegram

1. Create a bot: message [@BotFather](https://t.me/BotFather) and
   follow the prompts. Copy the token.
2. Find your chat ID: message [@userinfobot](https://t.me/userinfobot),
   send `/start`. Copy the ID.
3. Add to `.env`:
   ```
   TELEGRAM_BOT_TOKEN=123456:ABC-your-token
   TELEGRAM_CHAT_ID=987654321
   ```

**Markdown formatting:** If the `.venv` and `telegramify-markdown` are
installed, output is converted to Telegram's entity format (bold, code,
links render correctly). Otherwise, plain text is sent.

**Test manually:**

```bash
echo "Test from Merriman" | bash notify/telegram.sh
```

### Discord

1. In your Discord server: Server Settings → Integrations → Webhooks →
   New Webhook. Copy the URL.
2. Add to `.env`:
   ```
   DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
   ```

Discord renders Markdown natively. Long messages are split at 2000
characters automatically.

**Test:**

```bash
echo "Test from Merriman" | bash notify/discord.sh
```

### ntfy

[ntfy](https://ntfy.sh) sends push notifications to your phone or desktop.
You can use the public server or [self-host](https://docs.ntfy.sh/install/).

1. Choose a topic name (it acts as a shared secret — pick something unguessable).
2. Subscribe in the ntfy app on your phone.
3. Add to `.env`:
   ```
   NTFY_TOPIC=my-merriman-alerts
   # NTFY_URL=http://your-server:8080   # self-hosted only
   ```

**Test:**

```bash
echo "Test from Merriman" | bash notify/ntfy.sh
```

### Email

Uses `curl`'s SMTP support — no external mail utilities needed.

1. Add to `.env`:

   ```
   SMTP_URL=smtp://user:password@smtp.gmail.com:587
   NOTIFY_EMAIL=you@example.com
   ```

   For Gmail with 2FA: use an [App Password](https://support.google.com/accounts/answer/185833).
   For TLS (port 465): use `smtps://` instead of `smtp://`.

2. Optionally set a sender address:
   ```
   NOTIFY_FROM=merriman@example.com
   ```

**Test:**

```bash
echo "Test from Merriman" | bash notify/email.sh
```

---

## Adding a new channel

1. Create `notify/<channel-name>.sh`. The script reads the message from
   stdin. Credentials come from environment variables set in `.env`.
   See `notify/ntfy.sh` for a minimal example.

2. Make it executable: `chmod +x notify/<channel-name>.sh`

3. Add a handler in `scripts/_common.sh`:

   ```bash
   _notify_myservice() {
     local message="$1"
     local script="${MERRIMAN_DIR}/notify/myservice.sh"
     if [[ -x "$script" ]]; then
       echo "$message" | "$script"
     fi
   }
   ```

4. Add a case in the `notify()` function's dispatch loop:

   ```bash
   myservice) _notify_myservice "$message" ;;
   ```

5. Add a plugin entry in `config.yml`:

   ```yaml
   - type: myservice
     token_env: MYSERVICE_TOKEN
   ```

6. Add the credential to `.env.example` and `.env`.

That's it. Agents can now specify `channels: [myservice]` in their
`agent.yml`.

---

## Suppressing notifications

### Per-agent sentinel

Add `silent_if: NOTHING_TO_REPORT` to `agent.yml`. If the agent's
output starts with that string, the run is logged but no notification
is sent. Used for polling agents that should be silent when there is
nothing actionable.

### Disabling an agent entirely

Set `enabled: false` in `agent.yml`. The runner exits immediately
and produces no output or notifications.
