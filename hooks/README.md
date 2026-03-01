# Hook System

Hooks are TypeScript files that intercept tool calls before they execute.
They can inspect, modify, or block any MCP tool call made by the agent.

Hooks are loaded and executed by omp at runtime. They run in Node.js and
have access to the full Node.js standard library.

---

## Directory layout

```
hooks/
  global/              ← hooks that apply to all agents
    openmemory-user-id.ts   (enabled by default)
    logging.ts              (disabled by default — opt in via config.yml)
  examples/            ← annotated starting points — copy to global/ to use
    rate-limiter.ts
    confirm-destructive.ts
  install.sh           ← symlinks enabled hooks into .omp/hooks/pre/
  package.json         ← type dependencies for editor support
  tsconfig.json

.omp/hooks/pre/        ← where omp actually loads hooks from
  openmemory-user-id.ts → ../../hooks/global/openmemory-user-id.ts (symlink)
```

**Global hooks** in `hooks/global/` apply to every agent run. They are
activated by the install script, which creates symlinks in `.omp/hooks/pre/`.

**Agent-scoped hooks** live in `agents/<name>/hooks/pre/` and are loaded
automatically by omp for that agent only. No install step required.

---

## Enabling and disabling hooks

Edit `hooks.enabled` in `config.yml`, then run `bash hooks/install.sh`:

```yaml
hooks:
  enabled:
    - openmemory-user-id    # always recommended
    # - logging             # uncomment to log all tool calls
```

The install script creates symlinks for everything in the list and removes
symlinks for anything that was removed from it. Re-run it any time you
change the list.

---

## Writing a hook

Every hook exports a default function that receives the `HookAPI` object:

```typescript
import type { HookAPI } from "@oh-my-pi/pi-coding-agent";

export default function (omp: HookAPI) {
    omp.on("tool_call", async (event) => {
        // event.toolName  — fully-qualified tool name, e.g. "mcp__openmemory__openmemory_store"
        // event.input     — the tool's input arguments as a plain object

        // Allow the call:
        return undefined;

        // Block the call:
        // return { block: true, reason: "explanation for the agent" };
    });
}
```

### Finding tool names

Tool names follow the pattern `mcp__<server>__<tool>`. The exact names
depend on which MCP servers are configured in `.mcp.json`. Use the
`logging` hook to discover them, or run `omp` interactively and inspect
the tool calls in the session output.

### Module-level state

Variables declared at module scope persist for the lifetime of a single
`omp` invocation (one agent run). This makes them suitable for per-session
counters (see `examples/rate-limiter.ts`) but not for cross-run persistence
(use OpenMemory for that).

### Returning a reason

When blocking, the `reason` string is passed back to the agent. Write it
as an instruction, not an error message — the agent will read it and decide
what to do next. Be specific about what the agent should change and retry.

```typescript
return {
    block: true,
    reason: "Missing required field. Re-send with `user_id` set to a " +
            "lowercase name slug (e.g. alice, merriman, john-w).",
};
```

### Non-blocking hooks

Return `undefined` to let the call through. The `logging` hook is an
example — it records every call but never blocks.

---

## Editor setup

Run once in the `hooks/` directory to get proper editor type support:

```bash
cd hooks
npm install    # or: bun install / pnpm install
```

This installs `@oh-my-pi/pi-coding-agent` and `@types/node` as dev
dependencies. These are only needed for TypeScript type checking in your
editor — omp provides the actual runtime.

---

## Global vs agent-scoped hooks

| | Global (`hooks/global/`) | Agent-scoped (`agents/<name>/hooks/pre/`) |
|--|--|--|
| Applies to | All agents | One agent only |
| Activation | `hooks/install.sh` (via config.yml) | Automatic — omp loads them if present |
| Use for | System-wide invariants (memory scoping, logging, safety) | Per-agent constraints (tool restrictions, input transforms) |

---

## Included hooks

### `global/openmemory-user-id` (enabled by default)

Blocks any `openmemory_store` call that is missing a `user_id` or whose
`user_id` does not match the required format (`^[a-z][a-z0-9_-]*$`).

Without this, memories can be stored without entity scoping, making them
impossible to query by user and polluting the memory store.

Disable only if you are not using OpenMemory.

### `global/logging` (disabled by default)

Appends a JSON line to `logs/hooks.log` for every tool call. Fields:
`ts` (ISO timestamp), `tool` (tool name), `input` (sanitised arguments).

Useful for debugging prompt behaviour, auditing tool usage, and
understanding what the agent does during a run.

Enable via config.yml and run `bash hooks/install.sh`.

---

## Example hooks

Copy an example to `hooks/global/`, add its name to `hooks.enabled` in
`config.yml`, and run `bash hooks/install.sh`.

### `examples/rate-limiter`

Limits how many times each tool can be called per session. Configurable
per-tool. Useful for controlling costs or preventing runaway loops with
search tools.

### `examples/confirm-destructive`

Blocks irreversible tool calls (send email, delete task, etc.) and
instructs the agent to ask the user for explicit confirmation before
proceeding. A soft guard for unattended scheduled agents.
