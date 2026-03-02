# Merriman

A self-hosted personal AI agent platform. Delivers scheduled briefings,
monitors your inbox, and maintains long-term memory — entirely on
infrastructure you control.

Named after the butler in *The Importance of Being Earnest*. Composed,
unhurried, and quietly indispensable.

---

## What it does

- **Scheduled agents** run on your chosen cadence (morning briefing,
  inbox check, deadline alerts, or anything you write a prompt for)
- **Notifications** delivered to Telegram, Discord, ntfy, or email
- **Long-term memory** via self-hosted [OpenMemory][openmemory], scoped
  to entities so the agent builds a real picture of your life over time
- **MCP tool access** — calendar, email, tasks, weather, news, and
  anything else the MCP ecosystem supports
- **Hook system** to enforce invariants on every tool call (memory
  scoping, rate limits, confirmation on destructive actions)
- **Config-driven** — agent behaviour lives in files, not code

Everything runs on your machine or your server. No cloud dependency
except the LLM API you choose.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| [omp][omp] | Agent runtime (required) | `bun install -g @openagentsinc/omp` |
| [Docker][docker] | Runs OpenMemory | [docs.docker.com/get-docker][docker-install] |
| Python 3 | Telegram markdown + scheduling helpers | system or `brew install python` |
| [yq][yq] | YAML parsing in shell scripts | `brew install yq` |
| [jq][jq] | JSON processing in notify scripts | `brew install jq` |

omp requires [Bun][bun]: `curl -fsSL https://bun.sh/install | bash`

---

## Quick start

```bash
# 1. Clone and configure
git clone https://github.com/your-org/merriman
cd merriman
cp .env.example .env               # fill in ANTHROPIC_API_KEY, notification tokens
cp config.example.yaml config.yml  # review runtime, timezone, notify channels
cp .mcp.json.example .mcp.json     # add MCP server API keys

# Edit .omp/SYSTEM.md — replace [YOUR_NAME] and [your-name-slug] with your name
```

```bash
# 2. Start OpenMemory
git clone https://github.com/CaviraOSS/OpenMemory services/openmemory
docker compose up -d
bash scripts/check-services.sh     # confirm everything is healthy
```

```bash
# 3. Install Python dependencies (optional — for Telegram rich formatting)
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

```bash
# 4. Activate hooks and install scheduling
bash hooks/install.sh

# macOS:
bash scheduling/launchd/install.sh

# Linux:
bash scheduling/systemd/install.sh
```

```bash
# 5. Run your first agent
bash scripts/run-agent.sh agents/morning-briefing --dry-run  # preview
bash scripts/run-agent.sh agents/morning-briefing            # run it
```

That's it. See [docs/getting-started.md](docs/getting-started.md) for
the full walkthrough including MCP tool configuration.

---

## Architecture

```
Scheduler (launchd / systemd / cron)
    │
    ▼
scripts/run-agent.sh          reads agent.yml + prompt.md
    │
    ▼
adapters/omp.sh               omp -p "<prompt>"
    │  loads .omp/SYSTEM.md, .mcp.json, hooks/
    ▼
LLM + MCP Tools               calendar, email, tasks, memory, weather, news
    │
    ▼
notify/telegram.sh            (or discord, ntfy, email)
    │
    ▼
Your phone
```

Each agent is a directory under `agents/` with two files:

```
agents/morning-briefing/
    agent.yml    ← schedule, notify channels, runtime override
    prompt.md    ← the task, in plain English
```

The runner, adapters, and notify plugins are shared infrastructure. You
add agents by adding directories — no code changes required.

---

## Docs

| Document | Contents |
|----------|----------|
| [Getting started](docs/getting-started.md) | Full setup walkthrough |
| [Adding an agent](docs/adding-an-agent.md) | Create, schedule, and test a new agent |
| [Adding MCP tools](docs/adding-mcp-tools.md) | Configure new tool integrations |
| [Runtimes](docs/runtimes.md) | omp vs claude vs api — when to use each |
| [Notifications](docs/notifications.md) | Configure channels, add a new channel |
| [Memory](docs/memory.md) | OpenMemory setup, entity model, query patterns |
| [Hooks](hooks/README.md) | Write and manage pre-tool-call hooks |
| [vs. OpenClaw](docs/vs-openclaw.md) | Design comparison and positioning |

---

## License

[AGPL-3.0](LICENSE). Anyone deploying a modified version — including as
a hosted service — must publish their changes under the same licence.

[omp]: https://github.com/openagentsinc/omp
[openmemory]: https://github.com/CaviraOSS/OpenMemory
[docker]: https://www.docker.com
[docker-install]: https://docs.docker.com/get-docker/
[bun]: https://bun.sh
[yq]: https://github.com/mikefarah/yq
[jq]: https://jqlang.github.io/jq/
