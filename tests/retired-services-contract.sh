#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check_stack() {
  local label="$1" file json
  shift
  local args=()
  for file in "$@"; do args+=(-f "$ROOT/$file"); done
  json=$(docker compose -p retirement-contract "${args[@]}" config --format json)
  jq -e '
    ([.services | keys[] | select(test("^dnd-(api|database|redis)$"))] | length) == 0 and
    all(.services[];
      ((.environment // {}) | has("DND5E_API_URL") or has("MONGODB_URI") | not) and
      ([((.depends_on // {}) | keys[]) | select(test("^dnd-"))] | length) == 0
    )
  ' <<<"$json" >/dev/null || { echo "FAIL: retired dependency in $label" >&2; exit 1; }
  printf 'PASS: %s has no retired services or dependencies\n' "$label"
}

check_stack named-local docker-compose.local-dev.yml docker-compose.local-api-src.yml
check_stack toolkit-local docker-compose.local-dev.yml docker-compose.api.yml docker-compose.local-api-src.yml
check_stack parallel-labs docker-compose.local-dev.yml docker-compose.local-lab.yml
check_stack legacy-full docker-compose.yml docker-compose.local.yml
check_stack modular docker-compose.base.yml docker-compose.dnd.yml docker-compose.api.yml docker-compose.web.yml
check_stack containerized-local docker-compose.local-src.yml
check_stack local-production docker-compose.local-prod.yml
check_stack production docker-compose.prod.yml

if grep -En '^[^#]*(dnd-api|dnd_api_service|DND5E_API_URL|MONGODB_URI)' \
  "$ROOT"/envoy/*.yaml "$ROOT"/nginx/nginx-local*.conf \
  "$ROOT"/scripts/toolkit-override-lab.sh; then
  echo 'FAIL: retired upstream remains in a proxy or lab launcher' >&2
  exit 1
fi
printf 'PASS: proxies and lab launcher do not route to retired services\n'
