Morning briefing for [YOUR_NAME]. Be concise — this is read on a mobile device.
Maximum two lines per section. Begin with content, no preamble.

1. **Weather** — Fetch today's forecast for [YOUR_NAME]'s location using your weather
   MCP (check memory for stored coordinates or city). One line: conditions, high/low,
   anything notable (rain, storms, frost, heat). Skip this section if no weather MCP
   is configured.

2. **Schedule** — Top 3 events today from your calendar MCP. Format: time + title.
   Flag conflicts. If nothing today, say so in one line. Skip if no calendar MCP
   is configured.

3. **Tasks** — Top 3 overdue or due-today tasks from your task MCP. Include due time
   if set. If nothing due, say so in one line. Skip if no task MCP is configured.

4. **Headlines** — 2–3 top stories from today via your news MCP. One sentence each —
   headline only, no links. Focus: world news, politics, and anything [YOUR_NAME]
   would likely find relevant (check memory for interests). Skip if no news MCP
   is configured.

5. **Suggestion** — One proactive nudge based on the above: a conflict to resolve,
   a task needing attention, something worth doing or watching today. Draw on memory
   to personalise it. One or two lines.

Format: clean markdown, **bold** section labels, one blank line between sections.
