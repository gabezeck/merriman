# Merriman vs. OpenClaw

[OpenClaw](https://github.com/openclaw/openclaw) is the most prominent self-hosted
personal AI assistant project. If you're evaluating Merriman, you've probably seen
it. This document explains how the two systems differ, where they overlap, and why
Merriman makes the architectural choices it does.

The short version: these are different tools for different problems. OpenClaw is a
conversational AI you access through the messaging apps you already use. Merriman
is a scheduled, proactive agent that tells you things without being asked — and
whose interactive surface stays on hardware you fully control.

---

## The fundamental difference

OpenClaw's core premise is that your AI assistant should be reachable wherever you
already communicate. Connect Telegram, WhatsApp, Discord, Signal, iMessage, and
23+ other channels; your assistant lives in all of them simultaneously.

Merriman's core premise is that a useful AI doesn't need to wait for you to ask.
It runs on a schedule, gathers what you need to know, and delivers a briefing. The
flow is always: agent → you. Not you → agent → you.

This isn't a limitation imposed by technical constraints. It's a deliberate boundary
that shapes everything else — the architecture, the privacy model, the dependency
surface, and the trust model.

---

## Interactive use

Merriman is not purely one-directional. Two interactive modes exist today:

**Terminal session.** `cd` into the project folder and invoke the runtime directly:

```bash
omp      # full session with tools, memory, hooks
claude   # Claude Code CLI session
```

This gives you a full bidirectional conversation with the same agent, using the
same system prompt, MCP tools, and hook configuration as the scheduled agents.
It's intentionally local: the session runs on your machine and nowhere else.

**v2: local network web interface.** The planned web client (tracked in the
roadmap) will allow interactive chat, MCP configuration, skill creation, and
agent management through a browser — accessible from any device on your local
network without being tethered to the machine running the agent. The interactive
surface is bounded by your LAN. No credentials, conversation history, or agent
context leave your network.

---

## Privacy and the trust boundary

OpenClaw's bidirectional channel model is powerful, but it has a structural
consequence: the AI's context must flow through whichever third-party platform
you're using to reach it. When you chat with your OpenClaw instance via Telegram,
Telegram's infrastructure is in the path of that conversation.

OpenClaw acknowledges this and mitigates it thoughtfully — DM pairing codes,
Docker sandbox isolation for group sessions, SSRF allowlists, namespace-join
blocking. These are real and well-engineered controls. But they exist precisely
because the attack surface is real.

Merriman's notification channels (Telegram, Discord, ntfy, email) are used only
for delivery. A push notification carries your morning briefing outbound. There
is no inbound command path through those services. No one can trigger your agent
by sending a Telegram message. The notification channel and the agent's execution
environment are structurally separate.

The v2 web interface extends this model rather than changing it. Interaction is
local-network-only. There is no relay, no cloud proxy, no OAuth handshake with
a third-party messaging platform required to talk to your own agent.

---

## Scheduling as the core primitive

In OpenClaw, scheduled tasks are a skill — a plugin layered on top of the
conversational core.

In Merriman, the scheduler _is_ the architecture. Every agent has a cron schedule
in `agent.yml`. The runner, adapter, and notify pipeline are built around the
assumption that agents are triggered by time. Platform-specific schedulers
(launchd, systemd, cron) are first-class concerns with their own install scripts
and missed-job recovery semantics.

This means Merriman is well-suited for agents that run reliably at 7am every
weekday and aren't expected to respond to ad-hoc queries. Its focus isn't
"ask me anything" use cases — which is fine, because that's not its primary job.
As stated above, invoke the agent from the repo root and you get a full interactive
session with the same tools and context as the scheduled version.

---

## No persistent process

OpenClaw requires a continuously-running Gateway process (a WebSocket server,
bound to `ws://127.0.0.1:18789`) that orchestrates all channels, sessions, tools,
and extensions. This is the right design for a system that must be reachable at
any moment through 23 messaging platforms.

Merriman has no long-running daemon. The scheduler wakes the runner, the agent
executes, output is delivered, and the process exits. Nothing needs to be alive
between runs. This makes it more resilient on hardware that sleeps, and eliminates
"is the service running?" operational overhead. The only persistent service
Merriman runs is OpenMemory — and that's optional; it's only needed if you want
long-term memory across sessions.

---

## Simplicity and auditability

OpenClaw is a substantial TypeScript monorepo: 16,000+ commits, companion apps
for macOS, iOS, and Android, a Skills platform, Canvas/A2UI, voice integration,
and a WebSocket gateway.

Merriman's runtime surface is Bash scripts, YAML, and Markdown. An agent is two
files:

```
agents/morning-briefing/
    agent.yml    ← schedule, notify channels, runtime override
    prompt.md    ← the task, in plain English
```

A non-developer can read `prompt.md` and know exactly what the agent will do.
Agents are plain text, version-controllable, diffable, and shareable without any
special tooling.

This simplicity is a deliberate constraint. Merriman is designed to be the kind
of system you can audit and trust, not just install and hope.

---

## Comparison table

|                                 | Merriman                                    | OpenClaw                         |
| ------------------------------- | ------------------------------------------- | -------------------------------- |
| **Primary interaction model**   | Scheduled, proactive push                   | On-demand, conversational        |
| **Interactive chat**            | Local terminal (today); LAN web client (v2) | 23+ external messaging channels  |
| **External channel role**       | Outbound delivery only                      | Bidirectional command surface    |
| **Persistent process required** | No (scheduler + ephemeral runs)             | Yes (WebSocket gateway)          |
| **Scheduling**                  | Core architecture                           | Plugin/skill                     |
| **Agent definition**            | `agent.yml` + `prompt.md`                   | Runtime configuration            |
| **Privacy boundary**            | Your machine / LAN                          | Your machine + channel providers |
| **Mobile access**               | LAN web client (v2)                         | Native companion apps            |
| **Voice**                       | No                                          | Yes (macOS, iOS, Android)        |
| **Browser automation**          | Via MCP tools                               | Built-in managed Chromium        |
| **Dependency surface**          | Bash, yq, jq, Python (optional)             | Node 22, Docker, TypeScript      |
| **License**                     | AGPL-3.0                                    | MIT                              |
| **Recommended model**           | Claude Opus 4.6                             | Claude Opus 4.6                  |

---

## When to use Merriman

- You want proactive briefings and monitoring rather than an on-demand chatbot
- You prefer interactive sessions to stay within your local network
- You want to understand exactly what your agent is doing (readable config files,
  auditable hook system, no opaque runtime)
- You're running on a laptop or home server and don't want to maintain a
  long-running process
- You're willing to trade mobile app convenience for a tighter privacy boundary

## When OpenClaw is the better fit

- You want to reach your AI from WhatsApp, Telegram, iMessage, or other apps
  you're already in throughout the day
- You need voice interaction or native mobile apps
- You want an assistant that responds to ad-hoc queries instantly from any device
- The complexity and capability of the Skills platform and Canvas/A2UI is something
  you'll actually use

---

## Roadmap note

The v2 web interface is the point where Merriman's interactive capability
approaches OpenClaw's for users who spend their day on their home or office
network. The goal is not feature parity — voice, companion apps, and 23-channel
support are explicitly out of scope. The goal is that a non-technical user can
configure their agent, manage MCP connections, and chat with it from their phone
without installing anything or connecting any external messaging service.

That interface will remain LAN-only by design. Remote access, if you want it,
is Tailscale or a VPN — infrastructure you control, not a relay Merriman provides.
