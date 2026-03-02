import type { HookAPI } from "@oh-my-pi/pi-coding-agent/extensibility/hooks";
import * as fs from "node:fs";
import * as path from "node:path";

/**
 * logging.ts — Log every tool call to logs/hooks.log.
 *
 * Writes a timestamped JSON line for each tool call, including the tool
 * name and a sanitised copy of the input (long string values are truncated
 * to avoid bloating the log).
 *
 * Useful for debugging, auditing which tools the agent is using, and
 * understanding how the agent interprets prompts.
 *
 * This hook is disabled by default. Enable it in config.yml:
 *   hooks:
 *     enabled:
 *       - openmemory-user-id
 *       - logging              ← add this line
 * Then run: bash hooks/install.sh
 *
 * View the log: tail -f logs/hooks.log
 */

const MAX_VALUE_LENGTH = 200;

function sanitise(input: Record<string, unknown>): Record<string, unknown> {
	const out: Record<string, unknown> = {};
	for (const [k, v] of Object.entries(input)) {
		if (typeof v === "string" && v.length > MAX_VALUE_LENGTH) {
			out[k] = `${v.slice(0, MAX_VALUE_LENGTH)}…`;
		} else {
			out[k] = v;
		}
	}
	return out;
}

export default function (omp: HookAPI) {
	// Resolve log file relative to the working directory (the repo root,
	// since run-agent.sh cds to MERRIMAN_DIR before invoking omp).
	const logFile = path.join(process.cwd(), "logs", "hooks.log");

	// Ensure the logs directory exists
	try {
		fs.mkdirSync(path.dirname(logFile), { recursive: true });
	} catch {
		// Ignore — directory may already exist
	}

	omp.on(
		"tool_call",
		async (event: { toolName: string; input: Record<string, unknown> }) => {
			const entry = JSON.stringify({
				ts: new Date().toISOString(),
				tool: event.toolName,
				input: sanitise(event.input),
			});

			try {
				fs.appendFileSync(logFile, `${entry}\n`);
			} catch {
				// Non-fatal — do not block the tool call if logging fails
			}

			return undefined; // Always allow the call through
		},
	);
}
