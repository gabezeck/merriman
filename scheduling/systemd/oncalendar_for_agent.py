#!/usr/bin/env python3
"""
oncalendar_for_agent.py — Convert a cron expression to a systemd OnCalendar string.

Usage:
    python3 scheduling/systemd/oncalendar_for_agent.py "<cron expression>"

Examples:
    "0 7 * * 1-5"  →  "Mon..Fri *-*-* 07:00:00"
    "0 8 * * *"    →  "*-*-* 08:00:00"
    "*/30 * * * *" →  "*-*-* *:00/30:00"

Supported patterns:
    M H * * *         daily at H:M
    M H D * *         specific day-of-month
    M H * Mo *        specific month
    M H D Mo *        specific month + day-of-month
    M H * * D         specific weekday (0=Sun, 1=Mon … 6=Sat, 7=Sun)
    M H * * D-E       weekday range
    M H * * D,E,...   weekday list
    */N * * * *       every N minutes
    * * * * *         every minute

Note: combining day-of-month and day-of-week is not supported.
"""

import sys
import re

DOW_NAMES = {
    0: "Sun", 1: "Mon", 2: "Tue", 3: "Wed", 4: "Thu", 5: "Fri", 6: "Sat",
}
# Both 0 and 7 map to Sunday in cron
DOW_NAMES[7] = "Sun"

CONSECUTIVE_RANGES = [
    (1, 2, "Mon..Tue"),
    (1, 3, "Mon..Wed"),
    (1, 4, "Mon..Thu"),
    (1, 5, "Mon..Fri"),
    (1, 6, "Mon..Sat"),
    (0, 6, "Sun..Sat"),
    (2, 5, "Tue..Fri"),
    (2, 6, "Tue..Sat"),
]


def _expand_days(dow: str) -> list[int]:
    days = []
    for part in dow.split(","):
        if "-" in part:
            a, b = part.split("-", 1)
            days.extend(range(int(a), int(b) + 1))
        else:
            days.append(int(part))
    # Normalise Sunday (7 → 0)
    return sorted({0 if d == 7 else d for d in days})


def _days_to_oncalendar(days: list[int]) -> str:
    """Convert a sorted list of day integers to an OnCalendar day prefix."""
    # Check for named consecutive ranges first (cleaner output)
    for start, end, name in CONSECUTIVE_RANGES:
        if days == list(range(start, end + 1)):
            return name
    # Single day
    if len(days) == 1:
        return DOW_NAMES[days[0]]
    # Comma-separated list
    return ",".join(DOW_NAMES[d] for d in days)


def cron_to_oncalendar(cron: str) -> str:
    parts = cron.strip().split()
    if len(parts) != 5:
        raise ValueError(f"Expected 5 cron fields, got {len(parts)}: {cron!r}")

    minute, hour, dom, month, dow = parts

    # ── Every minute ─────────────────────────────────────────────────────────
    if minute == "*" and hour == "*" and dom == "*" and month == "*" and dow == "*":
        return "*-*-* *:*:00"

    # ── Every N minutes ───────────────────────────────────────────────────────
    m = re.match(r"^\*/(\d+)$", minute)
    if m and hour == "*" and dom == "*" and month == "*" and dow == "*":
        n = m.group(1)
        return f"*-*-* *:00/{n}:00"

    # ── Calendar-based ────────────────────────────────────────────────────────
    try:
        min_val = int(minute)
        hour_val = int(hour)
    except ValueError:
        raise ValueError(
            f"Unsupported cron minute/hour: {minute!r} {hour!r}. "
            "Only fixed integers are supported for calendar scheduling."
        )

    time_str = f"{hour_val:02d}:{min_val:02d}:00"

    if dom != "*" and dow != "*":
        raise ValueError(
            "Combining day-of-month and day-of-week in a single cron expression "
            "is not supported for systemd scheduling."
        )

    if dow == "*":
        day_prefix = ""
    else:
        days = _expand_days(dow)
        day_prefix = _days_to_oncalendar(days) + " "

    date_part = f"*-{month}-{dom}"
    return f"{day_prefix}{date_part} {time_str}"


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: oncalendar_for_agent.py '<cron expression>'", file=sys.stderr)
        sys.exit(1)
    try:
        print(cron_to_oncalendar(sys.argv[1]))
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
