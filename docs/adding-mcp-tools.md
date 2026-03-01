# Adding MCP tools

MCP (Model Context Protocol) servers give the agent access to external
services — calendar, email, tasks, weather, search, and more. Each server
exposes a set of tools that the agent can call during a run.

---

## How it works

When omp starts, it reads `.mcp.json` from the project root and connects
to each configured server. The available tools are then part of the agent's
context for the duration of the run. No per-agent configuration is required —
any tool in `.mcp.json` is available to all agents.

The system prompt (`.omp/SYSTEM.md`) tells the agent what tools exist and
how to use them. Adding a server without updating the system prompt works,
but the agent may not use the tool unless prompted explicitly.

---

## 1. Find or build an MCP server

Many services already have community-maintained MCP servers:

| Service         | Package                                 | Notes                      |
| --------------- | --------------------------------------- | -------------------------- |
| Todoist         | `mcp-remote https://ai.todoist.net/mcp` | Official, no local install |
| Google Calendar | `@cocal/google-calendar-mcp`            | Requires OAuth setup       |
| Gmail           | `@gongrzhe/server-gmail-autoauth-mcp`   | Requires OAuth setup       |
| The Guardian    | `guardian-mcp-server`                   | Free API key               |
| open-meteo      | `open-meteo-mcp-server`                 | No API key                 |
| Notion          | `@makenotion/notion-mcp-server`         | Requires integration token |
| GitHub          | `@modelcontextprotocol/server-github`   | Requires PAT               |
| Slack           | `@modelcontextprotocol/server-slack`    | Requires bot token         |
| Linear          | `linear-mcp`                            | Requires API key           |

Browse the [MCP server directory](https://github.com/modelcontextprotocol/servers)
for the full catalogue.

---

## 2. Add the server to `.mcp.json`

Open `.mcp.json` and add an entry under `mcpServers`. The structure
depends on how the server is distributed:

### npx-based server (most common)

```json
"my-service": {
    "command": "npx",
    "args": ["-y", "@org/my-service-mcp"],
    "env": {
        "MY_SERVICE_API_KEY": "your-key-here"
    }
}
```

### HTTP/SSE remote server

```json
"my-service": {
    "type": "http",
    "url": "https://my-service.example.com/mcp",
    "headers": {
        "x-api-key": "your-key-here"
    }
}
```

### Local binary

```json
"my-service": {
    "command": "/usr/local/bin/my-service-mcp",
    "args": []
}
```

Keep API keys directly in `.mcp.json` (which is gitignored). Do not
put them in `.env` — they are not needed by the shell scripts.

---

## 3. Verify the tool is available

Run omp interactively from the repo root to confirm the server connects
and its tools appear:

```bash
omp
```

Ask the agent: _"What tools do you have available?"_ It should list
the tools from your new server. If the server fails to connect, omp
will show an error at startup.

Alternatively, do a quick test run:

```bash
bash scripts/run-agent.sh agents/morning-briefing --dry-run
# Then:
bash scripts/run-agent.sh agents/morning-briefing
```

---

## 4. Update `.omp/SYSTEM.md`

Add a row to the Available Tools table in `.omp/SYSTEM.md`:

```markdown
| **my-service** | What the service provides and how to use it |
```

The agent reads the system prompt at the start of every run. Without
this entry, it may not think to use the tool even when it would be
appropriate.

If the tool has important usage patterns (specific field names, known
quirks, rate limits), add a brief note. Examples from the existing
system prompt show the right level of detail.

---

## 5. Reference the tool in your agent prompts

For scheduled agents, prompt the agent explicitly:

```markdown
Check my GitHub notifications using the GitHub MCP tool.
Summarise any mentions or review requests. One line per item.
```

Explicit references ensure the agent uses the right tool even when
other tools might seem relevant.

---

## Removing a tool

Remove or comment out the server entry in `.mcp.json`. Remove the
corresponding row from `.omp/SYSTEM.md`. The agent will no longer
have access to those tools on the next run.

---

## Troubleshooting

**Server connects but tools don't appear**

Some servers require the `npx` package to be installed first. Try:
`npx -y @org/my-service-mcp` in the repo directory to trigger
installation, then restart omp.

**Authentication errors**

API keys in `.mcp.json` are passed as environment variables to the
server process (`"env"` block) or as HTTP headers (`"headers"` block).
Check the server's documentation for which mechanism it uses.

**Tool calls fail with "not found" errors**

The tool name in your prompt may not match what the server registers.
Run omp interactively and ask it to list available tools to see exact
names. Tool names are also visible in `logs/hooks.log` if the logging
hook is enabled.
