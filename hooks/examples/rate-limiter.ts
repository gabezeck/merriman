import type { HookAPI } from "@oh-my-pi/pi-coding-agent";

/**
 * rate-limiter.ts — Example: limit how often a tool can be called per session.
 *
 * This hook tracks how many times each tool has been called in the current
 * session and blocks calls that exceed the configured limit.
 *
 * USAGE
 * ─────
 * 1. Copy to hooks/global/rate-limiter.ts
 * 2. Adjust LIMITS below for your needs
 * 3. Add "rate-limiter" to hooks.enabled in config.yml
 * 4. Run: bash hooks/install.sh
 *
 * WHY THIS MATTERS
 * ────────────────
 * Some MCP tools have rate limits or per-call costs. Without guardrails,
 * an agent in a complex task can make dozens of calls to a single tool.
 * This hook provides a simple session-level circuit breaker.
 *
 * LIMITATIONS
 * ───────────
 * State is in-memory and resets each time omp is invoked. This limits
 * calls within a single agent run, not across multiple runs.
 *
 * HOW HOOKS WORK
 * ──────────────
 * A hook module exports a default function that receives the HookAPI object.
 * Call omp.on("tool_call", handler) to register a pre-call interceptor.
 * Return { block: true, reason: "..." } to block; return undefined to allow.
 * Module-level variables persist for the lifetime of the omp process.
 */

// ── Configuration ─────────────────────────────────────────────────────────────
// Keys are exact tool names (use the logging hook to discover them).
// Values are the maximum number of calls allowed per session.
const LIMITS: Record<string, number> = {
	// Limit web search to avoid runaway research loops
	"mcp__exa__search": 10,
	// Limit memory writes to encourage batching
	"mcp__openmemory__openmemory_store": 20,
	// Limit email sending as a safety measure
	"mcp__gmail__send_email": 3,
};

// ── State ─────────────────────────────────────────────────────────────────────
// Module-level: persists across tool calls within a single omp invocation.
const callCounts = new Map<string, number>();

// ── Hook ──────────────────────────────────────────────────────────────────────
export default function (omp: HookAPI) {
	omp.on(
		"tool_call",
		async (event: { toolName: string; input: Record<string, unknown> }) => {
			const limit = LIMITS[event.toolName];
			if (limit === undefined) {
				return undefined; // No limit configured for this tool
			}

			const count = (callCounts.get(event.toolName) ?? 0) + 1;
			callCounts.set(event.toolName, count);

			if (count > limit) {
				return {
					block: true,
					reason:
						`Rate limit reached for ${event.toolName}: ` +
						`${count - 1}/${limit} calls already made this session. ` +
						"Consolidate remaining work into fewer calls, or proceed " +
						"without this tool.",
				};
			}

			return undefined;
		},
	);
}
