#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

render() {
  local project="$1" image="$2" port="$3" mode="$4"
  local files=(-f "$ROOT/docker-compose.local-dev.yml")
  [ "$mode" = toolkit ] && files+=(-f "$ROOT/docker-compose.api.yml")
  files+=(-f "$ROOT/docker-compose.local-api-src.yml")
  RPG_API_IMAGE="$image" RPG_API_HOST_PORT="$port" \
    docker compose -p "$project" "${files[@]}" config --format json
}

assert_config() {
  local json="$1" project="$2" image="$3" port="$4"
  jq -e --arg project "$project" --arg image "$image" --arg port "$port" '
    .name == $project and
    .services["rpg-api"].image == $image and
    ([.services | to_entries[] | select(.value.container_name? != null)] | length) == 0 and
    ([.services | to_entries[] | .value.ports[]?] | length) == 1 and
    .services.envoy.ports[0].target == 8080 and
    .services.envoy.ports[0].published == $port and
    .networks["rpg-network"].name == ($project + "_rpg-network") and
    .services["rpg-api"].environment.REDIS_ADDR == "redis:6379" and
    (.services["rpg-api"].environment.DND5E_API_URL | startswith("http://dnd-api:3000/"))
  ' <<<"$json" >/dev/null
}

a="$(render rpg-contract-a rpg-api:test-a 18080 normal)"
b="$(render rpg-contract-b rpg-api:test-b 18081 toolkit)"
assert_config "$a" rpg-contract-a rpg-api:test-a 18080
assert_config "$b" rpg-contract-b rpg-api:test-b 18081
[ "$(jq -r '.networks["rpg-network"].name' <<<"$a")" != \
  "$(jq -r '.networks["rpg-network"].name' <<<"$b")" ]
printf 'PASS: isolated local Compose contract\n'
