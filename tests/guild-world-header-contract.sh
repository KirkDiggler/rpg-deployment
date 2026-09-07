#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_root}"

failures=0

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  failures=$((failures + 1))
}

# nginx forwards request headers by default. Keep both production gRPC-Web
# routes on that normal path instead of reconstructing or interpreting the
# untrusted guild selector at the proxy boundary.
for nginx_config in nginx/nginx-http.conf nginx/nginx-ssl.conf; do
  route_count=$(grep -Fc 'location ~ ^/[a-zA-Z0-9]+(\.[a-zA-Z0-9]+)+Service/' "${nginx_config}" || true)
  if [[ "${route_count}" -ne 1 ]]; then
    fail "${nginx_config} must contain exactly one production gRPC-Web route (found ${route_count})"
  fi

  active_config=$(sed 's/[[:space:]]*#.*$//' "${nginx_config}")

  if grep -Eiq '^[[:space:]]*proxy_pass_request_headers[[:space:]]+off[[:space:]]*;' <<<"${active_config}"; then
    fail "${nginx_config} disables normal request-header forwarding"
  fi

  # Any active selector-specific nginx reference would risk overriding,
  # dropping, validating, mapping, setting, or manufacturing the field.
  if grep -Fiq 'x-rpg-guild-id' <<<"${active_config}"; then
    fail "${nginx_config} must not contain selector-specific nginx behavior"
  fi
done

# Every synchronized Envoy CORS allow-list must contain exactly one standalone,
# lowercase selector token. This is a static contract only; live duplicate and
# comma-combination behavior is intentionally left to deployed-path testing.
for envoy_config in envoy/envoy.yaml envoy/envoy-lab.yaml envoy/envoy-lab2.yaml; do
  mapfile -t allow_lines < <(grep -E '^[[:space:]]*allow_headers:' "${envoy_config}" || true)
  if [[ "${#allow_lines[@]}" -ne 1 ]]; then
    fail "${envoy_config} must contain exactly one allow_headers line (found ${#allow_lines[@]})"
    continue
  fi

  allow_line=${allow_lines[0]}
  exact_members=$(awk -F: '
    {
      value = substr($0, index($0, ":") + 1)
      count = split(value, members, ",")
      matches = 0
      for (i = 1; i <= count; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", members[i])
        if (members[i] == "x-rpg-guild-id") matches++
      }
      print matches
    }
  ' <<<"${allow_line}")
  case_insensitive_occurrences=$(tr '[:upper:]' '[:lower:]' <<<"${allow_line}" | awk '
    BEGIN { token = "x-rpg-guild-id"; matches = 0 }
    {
      value = $0
      while ((position = index(value, token)) > 0) {
        matches++
        value = substr(value, position + length(token))
      }
    }
    END { print matches }
  ')

  if [[ "${exact_members}" -ne 1 || "${case_insensitive_occurrences}" -ne 1 ]]; then
    fail "${envoy_config} allow_headers must contain exactly one lowercase x-rpg-guild-id token"
  fi
done

if [[ "${failures}" -ne 0 ]]; then
  exit 1
fi

printf 'guild world header contract: PASS\n'
