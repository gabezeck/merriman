import type { HookAPI } from "@oh-my-pi/pi-coding-agent";

/**
 * openmemory-user-id.ts — Enforce user_id scoping on all memory writes.
 *
 * Blocks any `openmemory_store` call that is missing a `user_id` or whose
 * `user_id` does not match the required format: lowercase letters, hyphens,
 * and underscores only, starting with a letter.
 *
 * Without this hook, the agent can accidentally store memories without a
 * scope, making them unqueryable and polluting the memory store.
 *
 * Valid user_id examples:
 *   - your name slug (e.g. alice, james)
 *   - merriman (the agent's self-observations)
 *   - a person's first-name slug (e.g. sarah, john-w)
 *
 * This hook is enabled by default. Disable it in config.yml by removing
 * "openmemory-user-id" from the hooks.enabled list and re-running
 * `bash hooks/install.sh`.
 */
export default function (omp: HookAPI) {
	omp.on(
		"tool_call",
		async (event: { toolName: string; input: Record<string, unknown> }) => {
			if (event.toolName !== "mcp__openmemory__openmemory_store") {
				return undefined;
			}

			if (!event.input.user_id) {
				return {
					block: true,
					reason:
						"openmemory_store requires an explicit user_id. " +
						"Re-send with user_id set to your name slug (e.g. alice), " +
						"merriman (for agent self-observations), " +
						"or the person's first-name slug (e.g. sarah, john-w). " +
						"Do not omit or leave it blank.",
				};
			}

			const userId = String(event.input.user_id);
			if (!/^[a-z][a-z0-9_-]*$/.test(userId)) {
				return {
					block: true,
					reason:
						`openmemory_store received an invalid user_id: "${userId}". ` +
						"user_id must contain only lowercase letters, digits, hyphens, or " +
						"underscores, and must start with a letter. " +
						"Examples: alice, merriman, sarah, john-w. " +
						"Do not include quotes, spaces, or uppercase letters.",
				};
			}

			return undefined;
		},
	);
}
