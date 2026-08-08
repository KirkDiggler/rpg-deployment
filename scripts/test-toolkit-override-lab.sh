#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUBJECT="$ROOT/scripts/toolkit-override-lab.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/api/scripts" "$TMP/toolkit/encounter"
printf 'module github.com/KirkDiggler/rpg-api\n' > "$TMP/api/go.mod"
printf 'module github.com/KirkDiggler/rpg-toolkit/encounter\n' > "$TMP/toolkit/encounter/go.mod"
: > "$TMP/api/Dockerfile.local-toolkit"
cat > "$TMP/api/scripts/toolkit-local-override.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
module=github.com/KirkDiggler/rpg-toolkit/encounter
case "$1" in
  on)
    mkdir -p "$root/local-toolkit/encounter"
    printf '\nreplace %s => ./local-toolkit/encounter\n' "$module" >> "$root/go.mod"
    [ "${FAKE_OVERRIDE_ON_FAIL:-false}" != true ] || exit 42
    ;;
  status)
    if grep -q '^replace ' "$root/go.mod"; then echo "Override ON: $module => ./local-toolkit/encounter"
    else echo "Active replace modules (0): none"; echo "Override OFF: $module resolves to its published version."
    fi ;;
  off) sed -i '\|^replace github.com/KirkDiggler/rpg-toolkit/encounter => ./local-toolkit/encounter$|d' "$root/go.mod"; rm -rf "$root/local-toolkit" ;;
  *) exit 2 ;;
esac
MOCK
chmod +x "$TMP/api/scripts/toolkit-local-override.sh"
cat > "$TMP/bin/docker" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
if [ "${1:-} ${2:-}" = "container inspect" ]; then
  [ "${3:-}" = "${FAKE_CONTAINER_EXISTS:-__none__}" ] && exit 0
  exit 1
fi
if [ "${1:-} ${2:-}" = "image inspect" ]; then
  [ "${3:-}" = "${FAKE_IMAGE_EXISTS:-__none__}" ] && exit 0
  exit 1
fi
if [ "${1:-} ${2:-}" = "network inspect" ]; then exit 0; fi
if [ "${1:-}" = inspect ]; then echo true; exit 0; fi
if [ "${1:-}" = run ]; then echo fake-id; exit 0; fi
exit 0
MOCK
cat > "$TMP/bin/curl" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$TMP/bin/docker" "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH" FAKE_DOCKER_LOG="$TMP/docker.log"

output="$($SUBJECT up --api "$TMP/api" --toolkit "$TMP/toolkit" --name testsafe --envoy-port 48181 --vite-port 45173)"
grep -q "API URL: http://localhost:48181" <<<"$output"
grep -q "VITE_API_HOST=http://localhost:48181 npm run dev -- --port 45173" <<<"$output"
grep -q "build -f $TMP/api/Dockerfile.local-toolkit -t rpg-api:toolkit-lab-testsafe $TMP/api" "$FAKE_DOCKER_LOG"
grep -q -- "--name rpg-toolkit-lab-testsafe-api" "$FAKE_DOCKER_LOG"
grep -q -- "--name rpg-toolkit-lab-testsafe-envoy" "$FAKE_DOCKER_LOG"
grep -q "address: rpg-toolkit-lab-testsafe-api" "$ROOT/tmp/toolkit-labs/testsafe/envoy.yaml"

$SUBJECT down --api "$TMP/api" --name testsafe >/dev/null
! grep -q '^replace ' "$TMP/api/go.mod"
[ ! -e "$TMP/api/local-toolkit" ]
[ ! -e "$ROOT/tmp/toolkit-labs/testsafe" ]
# Down is deliberately idempotent.
$SUBJECT down --api "$TMP/api" --name testsafe >/dev/null

if FAKE_CONTAINER_EXISTS=rpg-toolkit-lab-collide-api \
  $SUBJECT up --api "$TMP/api" --toolkit "$TMP/toolkit" --name collide --envoy-port 48182 >/dev/null 2>"$TMP/collision.err"; then
  echo "expected container collision failure" >&2
  exit 1
fi
grep -q "already exists" "$TMP/collision.err"
! grep -q '^replace ' "$TMP/api/go.mod"

# A helper that mutates go.mod/local-toolkit and then fails must still be rolled back.
if FAKE_OVERRIDE_ON_FAIL=true \
  $SUBJECT up --api "$TMP/api" --toolkit "$TMP/toolkit" --name partialon --envoy-port 48184 >/dev/null 2>"$TMP/partial.err"; then
  echo "expected partial override activation failure" >&2
  exit 1
fi
grep -q "partial API override state were removed" "$TMP/partial.err"
! grep -q '^replace ' "$TMP/api/go.mod"
[ ! -e "$TMP/api/local-toolkit" ]
[ ! -e "$ROOT/tmp/toolkit-labs/partialon" ]

# A genuinely pre-existing approved override is restored byte-for-byte on failure.
"$TMP/api/scripts/toolkit-local-override.sh" on
printf 'preserve-me\n' > "$TMP/api/local-toolkit/encounter/marker"
cp "$TMP/api/go.mod" "$TMP/preexisting.go.mod"
if FAKE_OVERRIDE_ON_FAIL=true \
  $SUBJECT up --api "$TMP/api" --toolkit "$TMP/toolkit" --name preserve --envoy-port 48185 >/dev/null 2>"$TMP/preserve.err"; then
  echo "expected startup failure with pre-existing override" >&2
  exit 1
fi
cmp "$TMP/preexisting.go.mod" "$TMP/api/go.mod"
grep -qx 'preserve-me' "$TMP/api/local-toolkit/encounter/marker"
grep -q "pre-existing API override was restored" "$TMP/preserve.err"
"$TMP/api/scripts/toolkit-local-override.sh" off

# Cleanup must report a stuck name-scoped resource instead of claiming success.
if FAKE_CONTAINER_EXISTS=rpg-toolkit-lab-stuck-envoy FAKE_IMAGE_EXISTS=rpg-api:toolkit-lab-stuck \
  $SUBJECT down --api "$TMP/api" --name stuck >"$TMP/stuck.out" 2>"$TMP/stuck.err"; then
  echo "expected stuck-resource cleanup failure" >&2
  exit 1
fi
grep -q "failed to remove name-scoped container" "$TMP/stuck.err"
grep -q "failed to remove name-scoped image" "$TMP/stuck.err"
grep -q "cleanup is incomplete" "$TMP/stuck.err"
! grep -q "is down" "$TMP/stuck.out"

python3 -m http.server 48183 --bind 127.0.0.1 >"$TMP/http.log" 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; rm -rf "$TMP"' EXIT
sleep 0.2
! $SUBJECT up --api "$TMP/api" --toolkit "$TMP/toolkit" --name portcheck --envoy-port 48183 >/dev/null 2>"$TMP/port.err"
grep -q "already in use" "$TMP/port.err"
! grep -q '^replace ' "$TMP/api/go.mod"
kill "$server_pid"
trap 'rm -rf "$TMP"' EXIT

echo "toolkit override lab tests: PASS"
