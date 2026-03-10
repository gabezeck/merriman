# Getting started

This guide walks you through a complete Merriman installation: from a
fresh machine to a running morning briefing agent.

**Time:** 20–30 minutes for a developer familiar with the terminal.

---

## 1. Install prerequisites

### Bun and omp

omp (the agent runtime) is distributed via Bun:

```bash
curl -fsSL https://bun.sh/install | bash
bun install -g @oh-my-pi/pi-coding-agent
omp --version   # confirm it works
```

If you have an existing subscription through an AI provider, you may be
able to integrate via an OAuth login. Run `omp` and the invoke the
`/login` command. [See here](https://github.com/can1357/oh-my-pi?tab=readme-ov-file#api-keys--oauth) for more details.

### Docker

Install [Docker Desktop](https://docs.docker.com/get-docker/) (macOS/Windows)
or Docker Engine (Linux). Verify:

```bash
docker --version
docker compose version
```

### Shell utilities

```bash
# macOS
brew install yq jq python3

# Debian/Ubuntu
apt install yq jq python3 python3-pip python3-venv
```

`yq` is used for YAML parsing in shell scripts. `jq` is used in notify plugins.

---

## 2. Clone the repository

```bash
git clone https://github.com/your-org/merriman
cd merriman
```

---

## 3. Configure the environment

### `.env`

```bash
cp .env.example .env
```

Open `.env` and fill in at minimum:

- `ANTHROPIC_API_KEY` — your Anthropic API key if using API-based models. Other providers are available.
- At least one notification channel (e.g. `TELEGRAM_BOT_TOKEN` + `TELEGRAM_CHAT_ID`)
- `OM_API_KEY` — any strong random string (used to authenticate against OpenMemory)

Generate a random API key: `openssl rand -hex 32`

### `config.yml`

```bash
cp config.example.yaml config.yml
```

Review and adjust:

- `runtime` — `omp` is recommended and the default
- `timezone` — your local IANA timezone (e.g. `America/New_York`)
- `notify.plugins` — comment out channels you're not using
- `hooks.enabled` — leave `openmemory-user-id` on

### `.omp/SYSTEM.md`

This is Merriman's system prompt — his personality and instructions.
Find every instance of `[YOUR_NAME]` and `[your-name-slug]` and replace
them with your name and its lowercase slug:

```bash
# Example: replace Gabriel / gabriel
sed -i 's/\[YOUR_NAME\]/Gabriel/g; s/\[your-name-slug\]/gabriel/g' .omp/SYSTEM.md
```

### `.mcp.json`

```bash
cp .mcp.json.example .mcp.json
```

The only required entry is **openmemory** — add your `OM_API_KEY` to the
`openmemory.headers.x-api-key` field (use the same value you set in `.env`).

The example file also includes calendar, email, task, weather, and news servers
as a starting point. Keep what you want, remove what you don't, and add any
other MCP-compatible service you use.

See [docs/adding-mcp-tools.md](adding-mcp-tools.md) for a guide to adding
new integrations.

---

## 4. Start OpenMemory

OpenMemory builds from source. Clone it into `services/openmemory`:

```bash
git clone https://github.com/CaviraOSS/OpenMemory services/openmemory
```

Start the service:

```bash
docker compose up -d
```

The first run will build the Docker image, which takes a few minutes.
Watch progress with `docker compose logs -f openmemory`.

Verify everything is healthy:

```bash
bash scripts/check-services.sh
```

All three checks should pass: Docker, container status, HTTP endpoint.

---

## 5. Install Python dependencies

This step is optional. It enables rich markdown formatting for Telegram
(bold, code blocks, links). Without it, Telegram messages are sent as
plain text.

```bash
python3 -m venv .venv
source .venv/bin/activate        # fish: source .venv/bin/activate.fish
pip install -r requirements.txt
```

---

## 6. Activate hooks

```bash
bash hooks/install.sh
```

This creates symlinks in `.omp/hooks/pre/` for the hooks listed in
`config.yml`. By default, `openmemory-user-id` is activated, which
enforces correct memory scoping on every write.

---

## 7. Install scheduling

Choose the mechanism that matches your platform.

### macOS (launchd — recommended)

```bash
bash scheduling/launchd/install.sh
```

launchd runs missed jobs when the Mac wakes from sleep, which makes it
more reliable than cron for laptop use.

Verify:

```bash
launchctl list | grep com.merriman
```

### Linux (systemd timers — recommended)

```bash
bash scheduling/systemd/install.sh
```

`Persistent=true` in the timer units ensures missed jobs run on the next
system start.

Verify:

```bash
systemctl --user list-timers 'merriman-*'
```

### Any platform (cron)

```bash
bash scheduling/cron/install.sh
```

Note: cron does not run missed jobs. For reliability on laptops, prefer
launchd or systemd.

---

## 8. Run your first agent

### Dry run — preview without executing

```bash
bash scripts/run-agent.sh agents/morning-briefing --dry-run
```

This prints the resolved config and full prompt without invoking omp.
Use it to verify the agent is configured correctly.

### Live run

```bash
bash scripts/run-agent.sh agents/morning-briefing
```

If Telegram is configured, you should receive the briefing within a
minute or two (depending on how many MCP tools are called).

Check the log:

```bash
tail -f logs/morning-briefing.log
```

---

## Troubleshooting

**omp not found at runtime (scheduled jobs only)**

Schedulers run with a minimal PATH. The launchd and systemd install
scripts include common omp install locations. If omp is installed
elsewhere, check `$HOME/.bun/bin/omp` or run `which omp` in your shell
and add that directory to the PATH in the scheduling template.

**`config.yml not found`**

You haven't copied `config.example.yaml` to `config.yml`. Run:
`cp config.example.yaml config.yml`

**OpenMemory returns 401**

The `x-api-key` in `.mcp.json` must match `OM_API_KEY` in `.env`.
They are set independently and must be identical.

**Telegram messages arrive without formatting**

The Python venv is not activated at the time of the run, or
`telegramify-markdown` is not installed. Scheduled jobs use the venv
automatically if it exists at `.venv/`. Verify:
`ls .venv/bin/python3` and `.venv/bin/pip show telegramify-markdown`

**Agent output is empty or the run exits immediately**

Check `logs/<agent-name>.log` for the error. Common causes: missing
`ANTHROPIC_API_KEY`, MCP server not running, or a network timeout.
