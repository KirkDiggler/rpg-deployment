#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Optional real workspace overlays for the combined default-dev contract.
WORKSPACE_ROOT=${GAME_DEV_ROOT:-}

render() {
  local project="$1" image="$2" port="$3" mode="$4"
  local files=(-f "$ROOT/docker-compose.local-dev.yml")
  [ "$mode" = toolkit ] && files+=(-f "$ROOT/docker-compose.api.yml")
  files+=(-f "$ROOT/docker-compose.local-api-src.yml")
  if [[ -n "$WORKSPACE_ROOT" ]]; then
    files+=(-f "$WORKSPACE_ROOT/docker-compose.local-redis-port.yml"
            -f "$WORKSPACE_ROOT/docker-compose.dev-redis.yml")
  fi
  RPG_API_IMAGE="$image" RPG_API_HOST_PORT="$port" RPG_REDIS_VOLUME_NAME="$project-redis-data" \
    docker compose -p "$project" "${files[@]}" config --format json
}

assert_config() {
  local json="$1" project="$2" image="$3" port="$4" expected_ports=1
  [[ -z "$WORKSPACE_ROOT" ]] || expected_ports=2
  jq -e --arg project "$project" --arg image "$image" --arg port "$port" \
    --argjson expected_ports "$expected_ports" '
    .name == $project and
    .services["rpg-api"].image == $image and
    ([.services | to_entries[] | select(.value.container_name? != null)] | length) == 0 and
    ([.services | to_entries[] | .value.ports[]?] | length) == $expected_ports and
    .services.envoy.ports[0].target == 8080 and
    .services.envoy.ports[0].published == $port and
    .networks["rpg-network"].name == ($project + "_rpg-network") and
    .services["rpg-api"].environment.REDIS_ADDR == "redis:6379" and
    (.services | keys | sort) == ["envoy", "nginx-local", "redis", "rpg-api"] and
    (.services["rpg-api"].depends_on | keys) == ["redis"]
  ' <<<"$json" >/dev/null
  if [[ -n "$WORKSPACE_ROOT" ]]; then
    jq -e --arg project "$project" '
      .volumes["dev-redis-data"].external == true and
      .volumes["dev-redis-data"].name == ($project + "-redis-data") and
      any(.services.redis.volumes[]; .source == "dev-redis-data" and .target == "/data") and
      any(.services.redis.ports[]; .target == 6379 and .host_ip == "127.0.0.1")
    ' <<<"$json" >/dev/null
  fi
}

a="$(render rpg-contract-a rpg-api:test-a 18080 normal)"
b="$(render rpg-contract-b rpg-api:test-b 18081 toolkit)"
assert_config "$a" rpg-contract-a rpg-api:test-a 18080
assert_config "$b" rpg-contract-b rpg-api:test-b 18081
[ "$(jq -r '.networks["rpg-network"].name' <<<"$a")" != \
  "$(jq -r '.networks["rpg-network"].name' <<<"$b")" ]
printf 'PASS: isolated local Compose contract\n'
