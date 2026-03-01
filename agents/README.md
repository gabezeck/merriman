# Agent Directory Format

Each agent is a self-contained directory under `agents/`. The runner reads
`agent.yml` for configuration and `prompt.md` for the task to execute.

```
agents/
  morning-briefing/
    agent.yml      ← schedule, notify targets, runtime override, metadata
    prompt.md      ← the task prompt given to the agent
    hooks/         ← optional: agent-scoped omp hooks (TypeScript)
  inbox-check/
    agent.yml
    prompt.md
```

## agent.yml schema

```yaml
name: Morning Briefing                # Human-readable name (required)
description: Daily task and calendar  # Short description (optional)
enabled: true                         # Set false to disable without deleting (default: true)

schedule:
  cron: "0 7 * * 1-5"               # Standard cron expression
  timezone: America/Chicago           # IANA timezone name

notify:
  channels: [telegram]               # Which channels to deliver to.
                                     # References plugins configured in config.yml.
                                     # Multiple: [telegram, discord]

runtime: omp                         # Override global runtime for this agent.
                                     # Options: omp | claude | api
                                     # Omit to inherit global default from config.yml.

silent_if: NOTHING_TO_REPORT         # Optional sentinel string. If the agent's
                                     # output starts with this string, notification
                                     # is suppressed. Useful for polling agents
                                     # that should be silent when nothing is actionable.
```

## prompt.md

Plain text (Markdown) file containing the task prompt. The entire file is
passed to the configured runtime as the task instruction. You can use any
Markdown formatting — it will be rendered or stripped depending on the runtime
and notification channel.

The prompt can reference:
- MCP tools (configured in `.mcp.json`) — e.g. "check my Todoist tasks due today"
- Memory (if OpenMemory is running) — the system prompt instructs the agent on scoping
- Any instructions the runtime supports

## Running an agent manually

```bash
# Run an agent
bash scripts/run-agent.sh agents/morning-briefing

# Preview config and prompt without executing
bash scripts/run-agent.sh agents/morning-briefing --dry-run
```

## Adding a new agent

1. Create a directory: `agents/<your-agent-name>/`
2. Write `agent.yml` using the schema above
3. Write `prompt.md` with the task you want the agent to perform
4. Add a scheduler entry (see `scheduling/`) to run it on a schedule
5. Test manually: `bash scripts/run-agent.sh agents/<your-agent-name> --dry-run`

See `docs/adding-an-agent.md` for a full walkthrough.
