# Runtimes

Merriman supports three agent runtimes. The runtime controls how prompts are
executed and which features are available.

## Comparison

| Feature             | omp                 | claude                           | api               |
| ------------------- | ------------------- | -------------------------------- | ----------------- |
| MCP tool access     | ✅ via `.mcp.json`  | ⚠️ via `~/.claude/settings.json` | ❌ none           |
| Hook system         | ✅ `.omp/hooks/`    | ❌                               | ❌                |
| System prompt       | ✅ `.omp/SYSTEM.md` | ✅ `CLAUDE.md`                   | ❌                |
| Session continuity  | ✅                  | ❌                               | ❌                |
| RPC mode (web chat) | ✅ required for v2  | ❌                               | ❌                |
| Thinking display    | ✅                  | ❌                               | ❌                |
| Requires install    | omp binary          | claude binary                    | curl + jq         |
| API key required    | ANTHROPIC_API_KEY   | managed by claude                | ANTHROPIC_API_KEY |

**omp is the recommended runtime.** The claude and api adapters exist as fallbacks
for environments where omp is not available or not appropriate.

---

## omp

[Oh My Pi](https://github.com/can1357/oh-my-pi) — the primary runtime.

**MCP tools** are configured in `.mcp.json` at the project root. Any MCP server
listed there is available to all agents. The system prompt in `.omp/SYSTEM.md`
tells the agent what tools exist and how to use them.

**Hooks** in `.omp/hooks/pre/` are TypeScript files that run before each tool
call. They can block calls or enforce invariants — for example, the bundled
`openmemory-user-id.ts` hook prevents storing memories without a valid `user_id`.

**Session continuity** means the agent retains context across runs within a
session. The Phase 2 web chat uses `omp --mode rpc` to stream responses and
resume sessions across page loads and devices.

### Installation

```bash
curl -fsSL https://bun.sh/install | bash
bun install -g @openagentsinc/omp
```

### Setting omp as the runtime

In `config.yml`:

```yaml
runtime: omp
```

Or per-agent in `agent.yml`:

```yaml
runtime: omp
```

---

## claude

Uses the [Claude Code](https://claude.ai/download) CLI (`claude -p`).

A reasonable fallback if you already have Claude Code installed and do not want
to install omp separately. Agents can still use MCP tools, but they must be
configured in `~/.claude/settings.json` (or a `CLAUDE.md` file) rather than
`.mcp.json`.

**Known limitations:**

- No hook system — invariants cannot be enforced on tool calls
- Each run is stateless — no session continuity between executions
- Cannot be used for the Phase 2 web chat (no RPC mode)

### Setting claude as the runtime

In `config.yml`:

```yaml
runtime: claude
```

---

## api

Calls the Anthropic Messages API directly via `curl`. No tool use, no memory,
no hooks — raw text generation only.

Use this when:

- omp and claude are not available (CI environments, minimal servers)
- The task requires no tool access (summarising text already in the prompt,
  reformatting content, simple Q&A from provided context)

**Known limitations:**

- No MCP tools (no calendar, email, tasks, weather, memory)
- No hook system
- No session continuity
- Response arrives all at once (no streaming)

### Configuration

The model and token limit can be set in `config.yml`:

```yaml
api_model: claude-haiku-4-5-20251001 # default: claude-opus-4-6-20251101
api_max_tokens: 2048 # default: 4096
```

`ANTHROPIC_API_KEY` must be set in `.env`.

### Setting api as the runtime

In `config.yml`:

```yaml
runtime: api
```

---

## Switching runtimes

The runtime is resolved in this order:

1. `runtime:` in the agent's `agent.yml` (per-agent override)
2. `runtime:` in `config.yml` (global default)
3. Falls back to `omp` if neither is set

To switch all agents at once, change the global `runtime:` in `config.yml`.
To use a different runtime for a single agent, set `runtime:` in that agent's
`agent.yml`.
