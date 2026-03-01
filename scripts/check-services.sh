#!/bin/bash
# check-services.sh — Verify all Merriman infrastructure services are running
#
# Usage: bash scripts/check-services.sh
#
# Checks:
#   1. Docker is installed and the daemon is running
#   2. services/openmemory source is present (needed to build the image)
#   3. OpenMemory container is running and healthy
#   4. OpenMemory HTTP endpoint is reachable

set -euo pipefail

# shellcheck source=scripts/_common.sh
source "$(dirname "$0")/_common.sh"

PASS=0
FAIL=0
WARN=0

_pass() { echo "  [OK]   $*"; (( PASS++ )) || true; }
_fail() { echo "  [FAIL] $*" >&2; (( FAIL++ )) || true; }
_warn() { echo "  [WARN] $*"; (( WARN++ )) || true; }
_section() { echo ""; echo "── $* ──────────────────────────────────────────────"; }

# ── 1. Docker ─────────────────────────────────────────────────────────────────
_section "Docker"

if ! command -v docker &>/dev/null; then
  _fail "docker CLI not found. Install Docker Desktop or Docker Engine."
  echo ""
  echo "  Install: https://docs.docker.com/get-docker/"
  exit 1
fi
_pass "docker CLI found: $(docker --version)"

if ! docker info &>/dev/null 2>&1; then
  _fail "Docker daemon is not running. Start Docker Desktop or: sudo systemctl start docker"
  exit 1
fi
_pass "Docker daemon is running"

if ! docker compose version &>/dev/null 2>&1; then
  _fail "docker compose (v2) not found. Update Docker Desktop or install the compose plugin."
  exit 1
fi
_pass "docker compose found: $(docker compose version --short)"

# ── 2. OpenMemory source ──────────────────────────────────────────────────────
_section "OpenMemory source"

OPENMEMORY_SRC="${MERRIMAN_DIR}/services/openmemory"
OPENMEMORY_PKG="${OPENMEMORY_SRC}/packages/openmemory-js"

if [[ ! -d "$OPENMEMORY_SRC" ]]; then
  _fail "services/openmemory not found."
  echo ""
  echo "  Clone it:"
  echo "    git clone https://github.com/CaviraOSS/OpenMemory services/openmemory"
  echo ""
  echo "  Then start services:"
  echo "    docker compose up -d"
  exit 1
fi
_pass "services/openmemory directory found"

if [[ ! -f "${OPENMEMORY_PKG}/Dockerfile" ]]; then
  _fail "services/openmemory/packages/openmemory-js/Dockerfile not found."
  echo "  The cloned repository may be incomplete. Try re-cloning."
  exit 1
fi
_pass "OpenMemory Dockerfile found"

# ── 3. Container status ───────────────────────────────────────────────────────
_section "Container status"

cd "${MERRIMAN_DIR}"

# Check if the compose project is up at all
if ! docker compose ps --quiet 2>/dev/null | grep -q .; then
  _fail "No Merriman containers are running."
  echo ""
  echo "  Start them:"
  echo "    docker compose up -d"
  exit 1
fi

# Check openmemory specifically
OM_STATUS=$(docker compose ps --format json openmemory 2>/dev/null \
  | grep -o '"State":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "")

if [[ -z "$OM_STATUS" ]]; then
  _fail "openmemory container not found in compose project."
elif [[ "$OM_STATUS" == "running" ]]; then
  _pass "openmemory container is running"
else
  _fail "openmemory container state: $OM_STATUS (expected: running)"
  echo "  Check logs: docker compose logs openmemory"
fi

# Check health status
OM_HEALTH=$(docker inspect "$(docker compose ps -q openmemory 2>/dev/null)" \
  --format '{{.State.Health.Status}}' 2>/dev/null || echo "unknown")

case "$OM_HEALTH" in
  healthy)    _pass "openmemory health check: healthy" ;;
  starting)   _warn "openmemory health check: still starting (wait a moment and re-run)" ;;
  unhealthy)  _fail "openmemory health check: unhealthy — check logs: docker compose logs openmemory" ;;
  *)          _warn "openmemory health status: $OM_HEALTH (no health check configured?)" ;;
esac

# ── 4. HTTP reachability ──────────────────────────────────────────────────────
_section "HTTP endpoints"

# Determine the memory URL from config.yml or fall back to default
MEMORY_URL="http://localhost:2444"
if [[ -f "$CONFIG_FILE" ]] && command -v yq &>/dev/null; then
  CFG_URL=$(_yq '.memory_url // ""' "$CONFIG_FILE" 2>/dev/null || true)
  [[ -n "$CFG_URL" && "$CFG_URL" != "null" ]] && MEMORY_URL="$CFG_URL"
fi

HEALTH_URL="${MEMORY_URL%/}/health"

if curl -sf --max-time 5 "$HEALTH_URL" &>/dev/null; then
  _pass "OpenMemory health endpoint reachable: $HEALTH_URL"
else
  _fail "OpenMemory health endpoint not reachable: $HEALTH_URL"
  echo "  Container may still be starting, or the port mapping may be wrong."
  echo "  Check: docker compose ps"
fi

MCP_URL="${MEMORY_URL%/}/mcp"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$MCP_URL" 2>/dev/null || echo "000")

if [[ "$HTTP_CODE" =~ ^(200|401|403)$ ]]; then
  # 401/403 means the server is up but rejecting unauthenticated requests — that's fine
  _pass "OpenMemory MCP endpoint responding: $MCP_URL (HTTP $HTTP_CODE)"
elif [[ "$HTTP_CODE" == "000" ]]; then
  _fail "OpenMemory MCP endpoint unreachable: $MCP_URL (connection refused or timeout)"
else
  _warn "OpenMemory MCP endpoint returned unexpected HTTP $HTTP_CODE: $MCP_URL"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────"
echo "  Results: ${PASS} passed  ${WARN} warnings  ${FAIL} failed"
echo "────────────────────────────────────────────────────────"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo "Some checks failed. See above for remediation steps."
  echo ""
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo "All critical checks passed with warnings. Review above if unexpected."
  echo ""
  exit 0
else
  echo "All checks passed. Merriman infrastructure is ready."
  echo ""
  exit 0
fi
