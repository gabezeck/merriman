# Memory

Merriman uses [OpenMemory](https://github.com/CaviraOSS/OpenMemory) for
long-term semantic and factual memory. Memories persist across all agent
runs and accumulate over time, giving the agent an increasingly accurate
picture of your life, preferences, and priorities.

---

## How it works

OpenMemory is a self-hosted service running in Docker. The agent accesses
it via the `openmemory` MCP server configured in `.mcp.json`. Every read
and write goes through the MCP interface — there is no direct database
access in prompts.

The system prompt (`.omp/SYSTEM.md`) instructs the agent to write
memories aggressively, query them at the start of relevant runs, and
keep them clean by avoiding duplicates.

The `openmemory-user-id` hook (enabled by default) enforces that every
write includes a valid `user_id`, preventing memories from being stored
without entity scoping.

---

## Entity model

Every memory is scoped to an entity via `user_id`. This is the
fundamental organising principle: memories about you, memories about
Merriman itself, and memories about people in your life are all kept
separate and queryable independently.

| `user_id`        | What it tracks                                                        |
| ---------------- | --------------------------------------------------------------------- |
| `your-name-slug` | Your preferences, routines, goals, decisions, projects                |
| `merriman`       | Agent self-observations: tool quirks, workflow patterns, corrections  |
| `<first-name>`   | A person in your life — facts about them, not about your relationship |

**Your name slug** is the lowercase version of your name as set in
`.omp/SYSTEM.md` (e.g. `alice`, `james`, `maria`). Keep it consistent —
every memory about you should use this exact string.

**Person slugs** use first names, with a last-initial only for
disambiguation (`john` vs `john-w` vs `john-r`). Prefer readable over
unique. The hook enforces the format `^[a-z][a-z0-9_-]*$`.

---

## Memory types

The `openmemory_store` tool accepts a `type` field:

| Type                   | Storage                                   | Best for                                                               |
| ---------------------- | ----------------------------------------- | ---------------------------------------------------------------------- |
| `contextual` (default) | Semantic full-text                        | Preferences, habits, routines, observations                            |
| `factual`              | Structured subject/predicate/object graph | Discrete facts that may change (project status, someone's role)        |
| `both`                 | Both layers                               | Information that benefits from semantic search AND structured querying |

When in doubt, use `contextual`. Use `factual` for things like _"Alice's
current project is X"_ where you want to be able to query for the
current value by subject and predicate.

---

## Writing memories

The system prompt instructs the agent to write at three moments:

1. **End of any session** where new information emerged — sweep and store
2. **In the moment** when a preference, decision, or fact is revealed
3. **After completing a task** — note what was done and any outcomes

### Examples

```
# Storing a preference
openmemory_store({
    user_id: "alice",
    content: "Prefers meetings after 10am. Avoids scheduling anything on Fridays.",
    tags: ["schedule", "preferences"]
})

# Storing a factual attribute
openmemory_store({
    user_id: "alice",
    type: "factual",
    facts: [{ subject: "alice", predicate: "current_focus", object: "Q2 product launch" }],
    content: "Alice's current main focus is the Q2 product launch, running until end of June.",
    tags: ["work", "priorities"]
})

# Storing a self-observation
openmemory_store({
    user_id: "merriman",
    content: "The Guardian MCP returns 429 errors if more than 5 searches are made in one run.",
    tags: ["tools", "guardian", "rate-limits"]
})

# Storing a fact about a person
openmemory_store({
    user_id: "sarah",
    type: "both",
    content: "Sarah is Alice's sister, lives in Austin, works as a nurse.",
    facts: [
        { subject: "sarah", predicate: "relationship_to_alice", object: "sister" },
        { subject: "sarah", predicate: "lives_in", object: "Austin" }
    ],
    tags: ["family"]
})
```

### Before storing

Always query first to avoid duplicates:

```
openmemory_query({ user_id: "alice", query: "Friday scheduling preference" })
```

If an existing memory covers the same ground, use `openmemory_reinforce`
with its `id` to boost salience rather than creating a new entry. If the
fact has changed, delete the stale entry and store a fresh one.

---

## Querying memories

### At session start

The system prompt instructs the agent to front-load memory queries before
the conversation is underway:

```
openmemory_query({ user_id: "alice", query: "current priorities and active projects" })
openmemory_query({ user_id: "merriman", query: "tool quirks rate limits" })
```

Use `type: "contextual"` (or omit it) for general recall. Use
`type: "factual"` with a `fact_pattern` for structured lookups:

```
openmemory_query({
    user_id: "alice",
    type: "factual",
    fact_pattern: { subject: "alice", predicate: "current_focus" }
})
```

Use `openmemory_get` with a specific `id` for deep retrieval once you
have identified a relevant memory from a query result.

---

## Hook enforcement

The `openmemory-user-id` hook blocks any `openmemory_store` call that:

- Is missing `user_id` entirely
- Has a `user_id` that does not match `^[a-z][a-z0-9_-]*$`

The hook returns a `block: true` response with a clear instruction,
causing the agent to retry with a corrected call. This prevents orphaned
memories that cannot be queried.

The hook is activated by default. Disable it only if you are not using
OpenMemory:

```yaml
# config.yml
hooks:
  enabled: [] # remove openmemory-user-id
```

Then run `bash hooks/install.sh` to update the symlinks.

---

## Keeping memories clean

- **No duplicates.** Query before storing. The agent accumulates a lot
  of memory over time; duplicates degrade query precision.
- **No transient information.** Today's weather, a one-off task, a
  meeting that already happened — these don't belong in long-term memory.
- **Reinforce, don't repeat.** When a fact is re-confirmed, use
  `openmemory_reinforce` to boost salience. This improves recall ordering
  without creating duplicate entries.
- **Delete stale facts.** If a project ends or someone changes roles,
  delete the old factual entry and store a fresh one with a note about
  what changed.

---

## Backup and restore

The OpenMemory database is stored in the `openmemory-data` Docker volume.
To back it up:

```bash
docker run --rm \
  -v merriman_openmemory-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/openmemory-$(date +%Y%m%d).tar.gz /data
```

To restore:

```bash
docker run --rm \
  -v merriman_openmemory-data:/data \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/openmemory-YYYYMMDD.tar.gz -C /
```

To use a host path instead of a named volume (simpler for backups), see
`docker-compose.override.yml.example`.
