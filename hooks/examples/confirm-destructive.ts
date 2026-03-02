import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";

/**
 * confirm-destructive.ts — Example: block irreversible tool calls and require
 * explicit confirmation in the prompt before they are allowed.
 *
 * USAGE
 * ─────
 * 1. Copy to hooks/global/confirm-destructive.ts
 * 2. Adjust DESTRUCTIVE_TOOLS below
 * 3. Add "confirm-destructive" to hooks.enabled in config.yml
 * 4. Run: bash hooks/install.sh
 *
 * HOW IT WORKS
 * ────────────
 * When the agent attempts a call to a listed tool, the hook blocks it and
 * returns a reason instructing the agent to pause and ask the user for
 * confirmation before proceeding. The agent surfaces this as a question
 * in its response; the user must explicitly approve in their next message.
 *
 * This is a soft guard — the agent could theoretically retry immediately.
 * For a hard guard, use the rate-limiter example to cap calls to 0 unless
 * a session-level flag has been set by a separate confirmation hook.
 *
 * WHY THIS MATTERS
 * ────────────────
 * Scheduled agents run unattended. This hook prevents an agent from
 * taking a destructive action (deleting a task, sending an email,
 * completing a project) without a human in the loop.
 *
 * ADAPTING THIS PATTERN
 * ─────────────────────
 * The CONFIRMATION_PHRASE approach shown here is simple but not foolproof.
 * For stronger guarantees, track confirmed tool calls in module-level state
 * and require the confirmation to happen in the same session before the
 * call is allowed through.
 */

// ── Configuration ─────────────────────────────────────────────────────────────
// Map of tool name → human-readable description of what it does.
const DESTRUCTIVE_TOOLS: Record<string, string> = {
	"mcp__gmail__send_email":             "send an email",
	"mcp__todoist__close_task":           "permanently complete a Todoist task",
	"mcp__todoist__delete_task":          "delete a Todoist task",
	"mcp__google_calendar__delete_event": "delete a calendar event",
	"mcp__openmemory__openmemory_delete": "permanently delete a memory",
};

// Phrase the user must include in their message to grant permission.
const CONFIRMATION_PHRASE = "confirmed";

// ── State ─────────────────────────────────────────────────────────────────────
// Track which tools have been confirmed this session.
const confirmed = new Set<string>();

// ── Hook ──────────────────────────────────────────────────────────────────────
export default function (omp: HookAPI) {
	omp.on(
		"tool_call",
		async (event: { toolName: string; input: Record<string, unknown> }) => {
			const description = DESTRUCTIVE_TOOLS[event.toolName];
			if (!description) {
				return undefined; // Not a watched tool
			}

			if (confirmed.has(event.toolName)) {
				return undefined; // Already confirmed this session
			}

			// Block and ask for confirmation
			return {
				block: true,
				reason:
					`This action will ${description}, which cannot be undone. ` +
					`Before proceeding, stop and ask the user: ` +
					`"I am about to ${description}. Please reply with ` +
					`"${CONFIRMATION_PHRASE}" to allow this, or tell me what to ` +
					`do instead." Once the user confirms, include the word ` +
					`"${CONFIRMATION_PHRASE}" in your next tool call attempt.`,
			};
		},
	);
}
