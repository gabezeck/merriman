#!/bin/bash
# hooks/install.sh — Activate global hooks by symlinking them into .omp/hooks/pre/
#
# Usage: bash hooks/install.sh
#
# Reads hooks.enabled from config.yml and creates a symlink in .omp/hooks/pre/
# for each listed hook. Removes symlinks for hooks that are no longer enabled.
#
# Run this whenever you change the hooks.enabled list in config.yml.
#
# What this does:
#   - Links hooks/global/<name>.ts → .omp/hooks/pre/<name>.ts
#   - omp loads all .ts files from .omp/hooks/pre/ at startup
#   - Agent-scoped hooks (agents/<name>/hooks/) are loaded per-agent by omp
#     automatically; no install step required for those.

set -euo pipefail

MERRIMAN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_GLOBAL="${MERRIMAN_DIR}/hooks/global"
HOOKS_DEST="${MERRIMAN_DIR}/.omp/hooks/pre"
CONFIG_FILE="${MERRIMAN_DIR}/config.yml"

# ── Preflight ─────────────────────────────────────────────────────────────────
if ! command -v yq &>/dev/null; then
  echo "[ERROR] 'yq' is required to read config.yml." >&2
  echo "  Install: brew install yq  (macOS)  |  snap install yq  (Linux)" >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "[ERROR] config.yml not found at $CONFIG_FILE" >&2
  echo "  Copy config.example.yaml to config.yml first." >&2
  exit 1
fi

mkdir -p "$HOOKS_DEST"

echo "Merriman — installing hooks"
echo "  Source: $HOOKS_GLOBAL"
echo "  Target: $HOOKS_DEST"
echo ""

# ── Read enabled hooks from config.yml ───────────────────────────────────────
mapfile -t enabled_hooks < <(yq '.hooks.enabled // [] | .[]' "$CONFIG_FILE" 2>/dev/null || true)

if [[ ${#enabled_hooks[@]} -eq 0 ]]; then
  echo "  No hooks listed under hooks.enabled in config.yml."
  echo "  Add hook names to enable them, e.g.:"
  echo "    hooks:"
  echo "      enabled:"
  echo "        - openmemory-user-id"
  echo ""
fi

# ── Create symlinks for enabled hooks ─────────────────────────────────────────
installed=0
for hook_name in "${enabled_hooks[@]}"; do
  src="${HOOKS_GLOBAL}/${hook_name}.ts"
  dest="${HOOKS_DEST}/${hook_name}.ts"

  if [[ ! -f "$src" ]]; then
    echo "  [WARN] hooks/global/${hook_name}.ts not found — skipping" >&2
    continue
  fi

  # Relative path from dest directory to src
  rel_src="$(python3 -c "import os; print(os.path.relpath('${src}', '${HOOKS_DEST}'))")"

  if [[ -L "$dest" ]]; then
    current_target=$(readlink "$dest")
    if [[ "$current_target" == "$rel_src" ]]; then
      echo "  = ${hook_name} (already linked)"
      (( installed++ )) || true
      continue
    fi
    rm "$dest"  # Replace stale symlink
  elif [[ -f "$dest" ]]; then
    echo "  [WARN] ${hook_name}.ts already exists in .omp/hooks/pre/ as a regular file — not replacing" >&2
    continue
  fi

  ln -s "$rel_src" "$dest"
  echo "  + ${hook_name}"
  (( installed++ )) || true
done

# ── Remove symlinks for hooks no longer in the enabled list ──────────────────
removed=0
if [[ -d "$HOOKS_DEST" ]]; then
  for link in "${HOOKS_DEST}"/*.ts; do
    [[ -L "$link" ]] || continue  # Only touch symlinks, not hand-written hooks
    hook_name="$(basename "$link" .ts)"

    # Check if this hook is in the enabled list
    still_enabled=false
    for e in "${enabled_hooks[@]}"; do
      [[ "$e" == "$hook_name" ]] && still_enabled=true && break
    done

    if [[ "$still_enabled" == "false" ]]; then
      rm "$link"
      echo "  - ${hook_name} (removed — no longer enabled)"
      (( removed++ )) || true
    fi
  done
fi

echo ""
echo "${installed} active  ${removed} removed"
echo ""

if [[ $installed -gt 0 ]]; then
  echo "Active hooks will be loaded by omp on the next agent run."
  echo "Verify with: ls -la ${HOOKS_DEST}/"
  echo ""
fi
