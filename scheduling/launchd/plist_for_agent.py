#!/usr/bin/env python3
"""
plist_for_agent.py — Generate a launchd plist for a Merriman agent.

Reads agent.yml from <agent_dir>, converts the cron schedule to
StartCalendarInterval or StartInterval XML, and prints a complete plist
to stdout.

Usage:
    python3 scheduling/launchd/plist_for_agent.py <agent_dir> <merriman_dir>

Exit codes:
    0  success — plist written to stdout
    2  agent is disabled (enabled: false) — skip silently
    1  error
"""

import sys
import os
import re
from pathlib import Path


# ── Simple agent.yml reader ───────────────────────────────────────────────────
# Avoids requiring PyYAML. Handles the flat key: value format in agent.yml.

def _read_yaml_value(text: str, key: str, default: str = "") -> str:
    """Extract a top-level YAML string value by key (no nesting support needed)."""
    pattern = rf"^{re.escape(key)}\s*:\s*(.+)$"
    m = re.search(pattern, text, re.MULTILINE)
    if not m:
        return default
    val = m.group(1).strip().strip("\"'")
    return val


def _read_cron(text: str) -> str:
    """Extract schedule.cron from agent.yml (nested under schedule:)."""
    # Match 'cron:' anywhere after 'schedule:' in the file
    m = re.search(r"cron\s*:\s*[\"']?([^\"'\n]+)[\"']?", text)
    return m.group(1).strip() if m else ""


# ── Cron → launchd XML converter ─────────────────────────────────────────────

def _expand_day_field(dow: str) -> list[int]:
    """Expand cron day-of-week field to a sorted list of integers.

    Cron days: 0 or 7 = Sunday, 1 = Monday … 6 = Saturday.
    launchd days: 0 = Sunday, 1 = Monday … 6 = Saturday, 7 = Sunday.
    We pass cron values through unchanged; both use the same convention.
    """
    days = []
    for part in dow.split(","):
        part = part.strip()
        if "-" in part:
            a, b = part.split("-", 1)
            days.extend(range(int(a), int(b) + 1))
        else:
            days.append(int(part))
    # Normalise: treat cron's 7 (Sunday) as 0 to avoid duplicates
    normalised = sorted({0 if d == 7 else d for d in days})
    return normalised


def _dict_entry(entries: dict) -> str:
    lines = ["        <dict>"]
    for k, v in entries.items():
        lines.append(f"            <key>{k}</key>")
        lines.append(f"            <integer>{v}</integer>")
    lines.append("        </dict>")
    return "\n".join(lines)


def cron_to_launchd_xml(cron: str) -> str:
    """Convert a 5-field cron expression to a launchd schedule XML block.

    Returns a string containing one of:
        <key>StartCalendarInterval</key><array>...</array>
        <key>StartInterval</key><integer>N</integer>

    Supported patterns:
        M H * * *         daily at H:M
        M H * * D         specific weekday
        M H * * D-E       weekday range
        M H * * D,E,...   weekday list
        */N * * * *       every N minutes
        * * * * *         every minute
    """
    parts = cron.strip().split()
    if len(parts) != 5:
        raise ValueError(f"Expected 5 cron fields, got {len(parts)}: {cron!r}")

    minute, hour, dom, month, dow = parts

    # ── Interval-based schedules ──────────────────────────────────────────────
    if minute == "*" and hour == "*" and dom == "*" and month == "*" and dow == "*":
        return "    <key>StartInterval</key>\n    <integer>60</integer>"

    if re.match(r"^\*/(\d+)$", minute) and hour == "*" and dom == "*" and month == "*" and dow == "*":
        n = int(re.match(r"^\*/(\d+)$", minute).group(1))
        return f"    <key>StartInterval</key>\n    <integer>{n * 60}</integer>"

    # ── Calendar-based schedules ──────────────────────────────────────────────
    try:
        min_val = int(minute)
        hour_val = int(hour)
    except ValueError:
        raise ValueError(
            f"Unsupported cron minute/hour pattern: {minute!r} {hour!r}. "
            "Only fixed integers are supported for calendar scheduling."
        )

    time_fields: dict = {"Hour": hour_val, "Minute": min_val}

    if dow == "*":
        dicts = [_dict_entry(time_fields)]
    else:
        day_list = _expand_day_field(dow)
        dicts = [_dict_entry({"Weekday": d, **time_fields}) for d in day_list]

    inner = "\n".join(dicts)
    return f"    <key>StartCalendarInterval</key>\n    <array>\n{inner}\n    </array>"


# ── Plist template ────────────────────────────────────────────────────────────

PLIST_TEMPLATE = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{label}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>{merriman_dir}/scripts/run-agent.sh</string>
        <string>{agent_dir}</string>
    </array>

{schedule_xml}

    <key>WorkingDirectory</key>
    <string>{merriman_dir}</string>

    <key>StandardOutPath</key>
    <string>{merriman_dir}/logs/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>{merriman_dir}/logs/launchd.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>{path}</string>
    </dict>
</dict>
</plist>
"""


def build_path(merriman_dir: str) -> str:
    """Construct a PATH string that includes common omp install locations."""
    home = str(Path.home())
    candidates = [
        f"{home}/.bun/bin",
        "/opt/homebrew/bin",
        "/opt/homebrew/sbin",
        "/usr/local/bin",
        "/usr/bin",
        "/bin",
        "/usr/sbin",
        "/sbin",
    ]
    # Deduplicate while preserving order
    seen: set = set()
    parts = []
    for c in candidates:
        if c not in seen:
            seen.add(c)
            parts.append(c)
    return ":".join(parts)


# ── Main ──────────────────────────────────────────────────────────────────────

def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: plist_for_agent.py <agent_dir> <merriman_dir>", file=sys.stderr)
        return 1

    agent_dir = str(Path(sys.argv[1]).resolve())
    merriman_dir = str(Path(sys.argv[2]).resolve())
    agent_yml_path = os.path.join(agent_dir, "agent.yml")

    if not os.path.isfile(agent_yml_path):
        print(f"Error: {agent_yml_path} not found", file=sys.stderr)
        return 1

    with open(agent_yml_path) as f:
        yml = f.read()

    # Check enabled flag
    enabled = _read_yaml_value(yml, "enabled", "true").lower()
    if enabled == "false":
        return 2  # Silently skip disabled agents

    # Read required fields
    agent_name = os.path.basename(agent_dir)
    label = f"com.merriman.{agent_name}"
    cron = _read_cron(yml)

    if not cron:
        print(f"Error: no schedule.cron found in {agent_yml_path}", file=sys.stderr)
        return 1

    try:
        schedule_xml = cron_to_launchd_xml(cron)
    except ValueError as e:
        print(f"Error parsing cron expression {cron!r}: {e}", file=sys.stderr)
        return 1

    plist = PLIST_TEMPLATE.format(
        label=label,
        agent_dir=agent_dir,
        merriman_dir=merriman_dir,
        schedule_xml=schedule_xml,
        path=build_path(merriman_dir),
    )

    print(plist, end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())
