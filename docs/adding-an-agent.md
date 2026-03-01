# Adding an agent

An agent is a directory under `agents/` containing two files:
`agent.yml` (configuration) and `prompt.md` (the task). The runner
does the rest.

---

## 1. Create the agent directory

```bash
mkdir agents/my-agent
```

Replace `my-agent` with a short, lowercase, hyphenated name. This name
becomes the log file name, the scheduler job label, and the agent's
identifier throughout the system.

---

## 2. Write `agent.yml`

```yaml
name: My Agent
description: Brief description of what this agent does
enabled: true

schedule:
  cron: "0 9 * * 1-5" # weekdays at 9am
  timezone: America/Chicago

notify:
  channels: [telegram] # telegram | discord | ntfy | email


# runtime: omp           # optional: overrides global default in config.yml
# silent_if: NOTHING_TO_REPORT  # suppress delivery when output starts with this
```

### Cron syntax reference

```
┌─ minute (0–59)
│  ┌─ hour (0–23)
│  │  ┌─ day of month (1–31)
│  │  │  ┌─ month (1–12)
│  │  │  │  ┌─ day of week (0=Sun, 1=Mon … 6=Sat)
│  │  │  │  │
0  7  *  *  1-5    weekdays at 7:00 AM
0  8  *  *  *      every day at 8:00 AM
*/30 * *  *  *     every 30 minutes
0    9  *  *  1    Mondays at 9:00 AM
```

### The `silent_if` sentinel

For agents that poll and should be quiet when there is nothing to act on,
add `silent_if: NOTHING_TO_REPORT` to `agent.yml` and end your prompt
with an instruction like:

> If there is nothing requiring attention, respond with exactly
> `NOTHING_TO_REPORT` and nothing else.

The runner checks whether the output starts with the sentinel string and
skips notification delivery if it does. The run is still logged.

---

## 3. Write `prompt.md`

This is the task you give the agent. Write it the same way you would
write a prompt for any LLM — be specific, state what you want, and
describe the output format.

```markdown
Daily standup summary for [YOUR_NAME].

1. **Overdue tasks** — Check Todoist for tasks past their due date.
   List each one: task name, original due date. Max 5 items.

2. **Today's focus** — The 3 most important tasks due today or
   created in the last 24 hours.

Format as clean markdown, **bold** section labels, bullet points.
Keep it to one screen on a phone.
```

**Tips:**

- Tell the agent which MCP tools to use ("Check Todoist", "use open-meteo
  for Chicago IL")
- Specify the output format explicitly — the output goes straight to
  a notification, so formatting matters
- For polling agents, include the `NOTHING_TO_REPORT` sentinel instruction
- Reference memory queries if the agent should personalise output
  ("check memory for [YOUR_NAME]'s current priorities")

---

## 4. Preview it

```bash
bash scripts/run-agent.sh agents/my-agent --dry-run
```

This prints the resolved `agent.yml` fields and the full prompt without
calling omp. Verify the schedule, runtime, and prompt look right before
running for real.

---

## 5. Run it manually

```bash
bash scripts/run-agent.sh agents/my-agent
```

Check the output in `logs/my-agent.log`. If Telegram (or your chosen
channel) is configured, the notification should arrive within a minute.

---

## 6. Add to the scheduler

Once the agent runs correctly, add it to your chosen scheduler.

### macOS (launchd)

```bash
bash scheduling/launchd/install.sh --agent my-agent
```

Trigger it immediately to test:

```bash
launchctl kickstart -k gui/$(id -u)/com.merriman.my-agent
```

### Linux (systemd)

```bash
bash scheduling/systemd/install.sh --agent my-agent
systemctl --user start merriman-my-agent.service   # test run
```

### Cron

```bash
bash scheduling/cron/install.sh --agent my-agent
```

---

## Agent-scoped hooks

If you want a hook that applies only to this agent (not all agents),
create a `hooks/pre/` directory inside the agent directory:

```bash
mkdir -p agents/my-agent/hooks/pre
```

Add TypeScript hook files there. omp loads them automatically for this
agent. See [hooks/README.md](../hooks/README.md) for the hook authoring
guide.

---

## Disabling an agent

Set `enabled: false` in `agent.yml`. The runner exits immediately if
this flag is false, so scheduled runs become no-ops. The scheduler entry
remains installed; the agent simply does nothing when triggered.

To uninstall from the scheduler entirely:

```bash
# macOS
bash scheduling/launchd/uninstall.sh --agent my-agent

# Linux
bash scheduling/systemd/uninstall.sh --agent my-agent

# Cron
bash scheduling/cron/uninstall.sh --agent my-agent
```
