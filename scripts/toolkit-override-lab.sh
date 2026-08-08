#!/usr/bin/env bash
# Run an unpublished rpg-toolkit/encounter checkout through an isolated API + Envoy lab.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE="github.com/KirkDiggler/rpg-toolkit/encounter"
ACTION="${1:-}"
[ $# -gt 0 ] && shift || true
API_DIR=""
TOOLKIT_DIR=""
LAB_NAME=""
ENVOY_PORT=""
VITE_PORT=""
NETWORK="rpg-deployment_rpg-network"

usage() {
  cat >&2 <<'EOF'
Usage:
  scripts/toolkit-override-lab.sh up --api <rpg-api-worktree> --toolkit <rpg-toolkit-worktree> \
      --name <unique-name> --envoy-port <port> [--vite-port <port>] [--network <docker-network>]
  scripts/toolkit-override-lab.sh down --api <rpg-api-worktree> --name <unique-name>
EOF
  exit 2
}

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --api) [ $# -ge 2 ] || usage; API_DIR="$2"; shift 2 ;;
    --toolkit) [ $# -ge 2 ] || usage; TOOLKIT_DIR="$2"; shift 2 ;;
    --name) [ $# -ge 2 ] || usage; LAB_NAME="$2"; shift 2 ;;
    --envoy-port) [ $# -ge 2 ] || usage; ENVOY_PORT="$2"; shift 2 ;;
    --vite-port) [ $# -ge 2 ] || usage; VITE_PORT="$2"; shift 2 ;;
    --network) [ $# -ge 2 ] || usage; NETWORK="$2"; shift 2 ;;
    *) usage ;;
  esac
done

[ "$ACTION" = up ] || [ "$ACTION" = down ] || usage
[ -n "$API_DIR" ] && [ -n "$LAB_NAME" ] || usage
[[ "$LAB_NAME" =~ ^[a-z0-9][a-z0-9-]{0,31}$ ]] || die "lab name must match [a-z0-9][a-z0-9-]{0,31}"
API_DIR="$(cd "$API_DIR" 2>/dev/null && pwd)" || die "API worktree does not exist: $API_DIR"
OVERRIDE="$API_DIR/scripts/toolkit-local-override.sh"
[ -x "$OVERRIDE" ] || die "missing executable override helper: $OVERRIDE"
API_CONTAINER="rpg-toolkit-lab-${LAB_NAME}-api"
ENVOY_CONTAINER="rpg-toolkit-lab-${LAB_NAME}-envoy"
IMAGE="rpg-api:toolkit-lab-${LAB_NAME}"
STATE_DIR="$ROOT/tmp/toolkit-labs/$LAB_NAME"

container_exists() { docker container inspect "$1" >/dev/null 2>&1; }
image_exists() { docker image inspect "$1" >/dev/null 2>&1; }

verify_clean() {
  local failed=0 clean_status=""
  if ! clean_status="$("$OVERRIDE" status)"; then
    echo "error: API override helper status check failed after cleanup" >&2
    failed=1
  elif ! grep -Fq "Active replace modules (0): none" <<<"$clean_status"; then
    echo "error: API override helper still reports an active replace after cleanup" >&2
    failed=1
  fi
  if grep -Eq "^[[:space:]]*replace[[:space:]]+$MODULE[[:space:]]*=>[[:space:]]*\./local-toolkit/encounter" "$API_DIR/go.mod"; then
    echo "error: override residue remains in $API_DIR/go.mod; run '$OVERRIDE off' and inspect the worktree" >&2
    failed=1
  fi
  if [ -e "$API_DIR/local-toolkit" ]; then
    echo "error: override residue remains at $API_DIR/local-toolkit" >&2
    failed=1
  fi
  return "$failed"
}

remove_lab_resources() {
  local failed=0
  for container in "$ENVOY_CONTAINER" "$API_CONTAINER"; do
    for _ in 1 2 3; do
      container_exists "$container" || break
      docker rm -f "$container" >/dev/null 2>&1 || true
      for _ in 1 2 3 4 5; do
        container_exists "$container" || break 2
        sleep 0.2
      done
    done
    if container_exists "$container"; then
      echo "error: failed to remove name-scoped container '$container'" >&2
      failed=1
    fi
  done
  for _ in 1 2 3; do
    image_exists "$IMAGE" || break
    docker image rm "$IMAGE" >/dev/null 2>&1 || true
    sleep 0.2
  done
  if image_exists "$IMAGE"; then
    echo "error: failed to remove name-scoped image '$IMAGE'" >&2
    failed=1
  fi
  rm -rf "$STATE_DIR"
  if [ -e "$STATE_DIR" ]; then
    echo "error: failed to remove generated lab state '$STATE_DIR'" >&2
    failed=1
  fi
  return "$failed"
}

cleanup() {
  local failed=0
  if ! remove_lab_resources; then failed=1; fi
  if ! "$OVERRIDE" off; then
    echo "error: API override helper cleanup failed" >&2
    failed=1
  fi
  if ! verify_clean; then failed=1; fi
  if [ "$failed" -ne 0 ]; then
    echo "error: lab '$LAB_NAME' cleanup is incomplete; inspect the errors above" >&2
    return 1
  fi
  echo "Lab '$LAB_NAME' is down; containers, image, generated Envoy config, and API override residue removed."
}

if [ "$ACTION" = down ]; then
  cleanup
  exit 0
fi

[ -n "$TOOLKIT_DIR" ] && [ -n "$ENVOY_PORT" ] || usage
TOOLKIT_DIR="$(cd "$TOOLKIT_DIR" 2>/dev/null && pwd)" || die "toolkit worktree does not exist: $TOOLKIT_DIR"
[ -f "$TOOLKIT_DIR/encounter/go.mod" ] || die "toolkit checkout lacks encounter/go.mod: $TOOLKIT_DIR"
[ -f "$API_DIR/Dockerfile.local-toolkit" ] || die "API worktree lacks Dockerfile.local-toolkit"

docker network inspect "$NETWORK" >/dev/null 2>&1 || die "Docker network '$NETWORK' does not exist; start the local dependency stack first"
for container in "$API_CONTAINER" "$ENVOY_CONTAINER"; do
  container_exists "$container" && die "container '$container' already exists; choose another --name or run this lab's down command"
done

validate_port() {
  local label="$1" port="$2"
  [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || die "$label must be an integer from 1024 to 65535"
  python3 - "$port" <<'PY' || die "$label $port is already in use; choose another port"
import socket, sys
port = int(sys.argv[1])
sockets = []
for family, address in ((socket.AF_INET, "0.0.0.0"), (socket.AF_INET6, "::")):
    try:
        sock = socket.socket(family, socket.SOCK_STREAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0)
        if family == socket.AF_INET6:
            sock.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 1)
        sock.bind((address, port))
        sockets.append(sock)
    except OSError:
        sys.exit(1)
PY
}
validate_port "Envoy port" "$ENVOY_PORT"
if [ -n "$VITE_PORT" ]; then
  [ "$VITE_PORT" != "$ENVOY_PORT" ] || die "Vite port must differ from Envoy port"
  validate_port "Vite port" "$VITE_PORT"
fi

initial_status=""
if ! initial_status="$("$OVERRIDE" status)"; then
  die "API override helper status failed before startup; inspect the API worktree"
fi
override_preexisting=false
if grep -Fq "Override ON: $MODULE" <<<"$initial_status"; then
  override_preexisting=true
elif ! grep -Fq "Active replace modules (0): none" <<<"$initial_status"; then
  die "API override state is neither clean nor the approved encounter override"
fi

mkdir -p "$STATE_DIR"
sed "s/address: rpg-api  # Docker service name/address: $API_CONTAINER  # isolated toolkit lab/" \
  "$ROOT/envoy/envoy.yaml" > "$STATE_DIR/envoy.yaml"
grep -q "address: $API_CONTAINER" "$STATE_DIR/envoy.yaml" || die "failed to generate isolated Envoy upstream"

PREEXISTING_BACKUP="$STATE_DIR/preexisting-api-override"
if [ "$override_preexisting" = true ]; then
  mkdir -p "$PREEXISTING_BACKUP"
  cp -a "$API_DIR/go.mod" "$PREEXISTING_BACKUP/go.mod"
  if [ -e "$API_DIR/go.sum" ]; then cp -a "$API_DIR/go.sum" "$PREEXISTING_BACKUP/go.sum"; fi
  [ -e "$API_DIR/local-toolkit" ] || die "approved pre-existing override has no local-toolkit directory to preserve"
  cp -a "$API_DIR/local-toolkit" "$PREEXISTING_BACKUP/local-toolkit"
fi

up_failed() {
  local status=$? rollback_failed=0 restored_status=""
  if [ "$status" -ne 0 ]; then
    if [ "$override_preexisting" = true ]; then
      cp -a "$PREEXISTING_BACKUP/go.mod" "$API_DIR/go.mod" || rollback_failed=1
      if [ -e "$PREEXISTING_BACKUP/go.sum" ]; then
        cp -a "$PREEXISTING_BACKUP/go.sum" "$API_DIR/go.sum" || rollback_failed=1
      else
        rm -f "$API_DIR/go.sum" || rollback_failed=1
      fi
      rm -rf "$API_DIR/local-toolkit"
      cp -a "$PREEXISTING_BACKUP/local-toolkit" "$API_DIR/local-toolkit" || rollback_failed=1
      if ! restored_status="$("$OVERRIDE" status)" || ! grep -Fq "Override ON: $MODULE" <<<"$restored_status"; then
        echo "error: failed to restore the pre-existing approved API override" >&2
        rollback_failed=1
      fi
    else
      if ! "$OVERRIDE" off; then
        echo "error: API helper failed while rolling back a partial override activation" >&2
        rollback_failed=1
      fi
      if ! verify_clean; then rollback_failed=1; fi
    fi
    if ! remove_lab_resources; then rollback_failed=1; fi
    if [ "$rollback_failed" -ne 0 ]; then
      echo "error: lab startup failed and rollback is incomplete; inspect the errors above" >&2
    elif [ "$override_preexisting" = true ]; then
      echo "error: lab startup failed; isolated resources were removed and the pre-existing API override was restored" >&2
    else
      echo "error: lab startup failed; isolated resources and partial API override state were removed" >&2
    fi
  fi
  exit "$status"
}
trap up_failed EXIT

"$OVERRIDE" on --src "$TOOLKIT_DIR"
status_output="$("$OVERRIDE" status)"
grep -Fq "Override ON: $MODULE" <<<"$status_output" || die "existing override helper did not activate the approved encounter module"

docker build -f "$API_DIR/Dockerfile.local-toolkit" -t "$IMAGE" "$API_DIR"
docker run -d --name "$API_CONTAINER" --network "$NETWORK" \
  --label "rpg.toolkit-lab=$LAB_NAME" \
  -e PORT=50051 -e LOG_LEVEL=info -e REDIS_ADDR=redis:6379 -e AUTH_DEV_MODE=true \
  -e DND5E_API_URL=http://dnd-api:3000/api/2014/ "$IMAGE" >/dev/null
docker run -d --name "$ENVOY_CONTAINER" --network "$NETWORK" \
  --label "rpg.toolkit-lab=$LAB_NAME" -p "$ENVOY_PORT:8080" \
  -v "$STATE_DIR/envoy.yaml:/etc/envoy/envoy.yaml:ro" envoyproxy/envoy:v1.31-latest \
  /usr/local/bin/envoy -c /etc/envoy/envoy.yaml -l info >/dev/null

for _ in $(seq 1 30); do
  [ "$(docker inspect -f '{{.State.Running}}' "$API_CONTAINER")" = true ] || die "API container exited; inspect with: docker logs $API_CONTAINER"
  [ "$(docker inspect -f '{{.State.Running}}' "$ENVOY_CONTAINER")" = true ] || die "Envoy container exited; inspect with: docker logs $ENVOY_CONTAINER"
  if curl -sS -o /dev/null "http://localhost:$ENVOY_PORT/"; then break; fi
  sleep 1
done
curl -sS -o /dev/null "http://localhost:$ENVOY_PORT/" || die "Envoy did not become reachable on port $ENVOY_PORT"

trap - EXIT
cat <<EOF
Lab '$LAB_NAME' is ready.
API URL: http://localhost:$ENVOY_PORT
Vite command:
  VITE_API_HOST=http://localhost:$ENVOY_PORT npm run dev${VITE_PORT:+ -- --port $VITE_PORT}
Cleanup:
  $ROOT/scripts/toolkit-override-lab.sh down --api $API_DIR --name $LAB_NAME

Re-run 'up' after toolkit edits (run 'down' first). This lab shares the existing local Redis/D&D dependencies but does not recreate primary, lab1, or lab2.
EOF
