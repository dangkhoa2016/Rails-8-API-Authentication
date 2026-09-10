#!/usr/bin/env bash
set -Eeuo pipefail

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

BASE_URL="${1:-${API_BASE_URL:-}}"
[[ -n "$BASE_URL" ]] || die 'usage: smoke.sh https://<modal-url> (or set API_BASE_URL)'
[[ "$BASE_URL" =~ ^https?://[^[:space:]]+$ ]] || die 'API URL must start with http:// or https://'
while [[ "$BASE_URL" == */ ]]; do BASE_URL="${BASE_URL%/}"; done

if [[ -n "${SMOKE_EMAIL:-}" || -n "${SMOKE_PASSWORD:-}" ]]; then
  [[ -n "${SMOKE_EMAIL:-}" && -n "${SMOKE_PASSWORD:-}" ]] || die 'SMOKE_EMAIL and SMOKE_PASSWORD must be supplied together'
fi

command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v python3 >/dev/null 2>&1 || die 'python3 is required'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

request_status() {
  local method="$1" url="$2" headers_file="$3" body_file="$4"
  shift 4
  curl --silent --show-error --max-time 30 \
    --request "$method" \
    --dump-header "$headers_file" \
    --output "$body_file" \
    --write-out '%{http_code}' \
    "$@" "$url"
}

status="$(request_status GET "$BASE_URL/up" "$tmpdir/up.h" "$tmpdir/up.b")"
[[ "$status" == "200" ]] || die "public /up expected 200, got $status"
pass 'public /up works without Modal credentials'

if [[ -z "${SMOKE_EMAIL:-}" ]]; then
  info 'authentication/rate-limit smoke NOT RUN: SMOKE_EMAIL and SMOKE_PASSWORD not supplied'
  exit 0
fi

# Start the auth/throttle sequence away from the end of a wall-clock minute so
# all requests are very likely to stay in the same 60-second Rack::Attack window.
seconds="$(date +%S)"
if (( 10#$seconds >= 50 )); then
  sleep $((61 - 10#$seconds))
fi

login_payload="$tmpdir/login.json"
python3 - "$SMOKE_EMAIL" "$SMOKE_PASSWORD" > "$login_payload" <<'PY'
import json, sys
print(json.dumps({"user": {"email": sys.argv[1], "password": sys.argv[2]}}))
PY

status="$(request_status POST "$BASE_URL/users/sign_in" "$tmpdir/login.h" "$tmpdir/login.b" \
  -H 'Content-Type: application/json' --data-binary "@$login_payload")"
[[ "$status" == "200" ]] || die "Rails sign-in expected 200, got $status"
pass 'Rails sign-in works on public Modal URL'

access_token="$(python3 - "$tmpdir/login.h" <<'PY'
import sys
for raw in open(sys.argv[1], encoding='iso-8859-1'):
    if raw.lower().startswith('authorization:'):
        value = raw.split(':', 1)[1].strip()
        if value.lower().startswith('bearer '):
            print(value[7:].strip())
            break
PY
)"
[[ -n "$access_token" ]] || die 'sign-in response did not expose Authorization: Bearer access JWT'

status="$(request_status GET "$BASE_URL/user/profile" "$tmpdir/profile.h" "$tmpdir/profile.b" \
  -H "Authorization: Bearer $access_token")"
[[ "$status" == "200" ]] || die "JWT profile expected 200, got $status"
pass 'standard Authorization Bearer JWT reaches Rails profile endpoint'
unset access_token

spoof_email="modal-spoof-$(date +%s)-$RANDOM@example.invalid"
spoof_payload="$tmpdir/spoof.json"
python3 - "$spoof_email" > "$spoof_payload" <<'PY'
import json, sys
print(json.dumps({"user": {"email": sys.argv[1], "password": "definitely-wrong"}}))
PY

for i in 11 12 13 14; do
  status="$(request_status POST "$BASE_URL/users/sign_in" "$tmpdir/spoof-$i.h" "$tmpdir/spoof-$i.b" \
    -H 'Content-Type: application/json' \
    -H "X-Forwarded-For: 198.51.100.$i" \
    --data-binary "@$spoof_payload")"
  [[ "$status" != "429" ]] || die "spoof-resistance sequence throttled too early at X-Forwarded-For 198.51.100.$i"
done

status="$(request_status POST "$BASE_URL/users/sign_in" "$tmpdir/spoof-15.h" "$tmpdir/spoof-15.b" \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 198.51.100.15' \
  --data-binary "@$spoof_payload")"
[[ "$status" == "429" ]] || die 'caller-controlled changing X-Forwarded-For appears able to bypass sign_in/ip throttling'
pass 'caller-supplied X-Forwarded-For does not bypass sign-in IP throttle'

for i in $(seq 1 20); do
  status="$(request_status POST "$BASE_URL/users/tokens/refresh" "$tmpdir/refresh-$i.h" "$tmpdir/refresh-$i.b" \
    -H "X-Refresh-Token: invalid-$i-$RANDOM")"
  [[ "$status" != "429" ]] || die "refresh-token throttle fired too early on request $i"
done
status="$(request_status POST "$BASE_URL/users/tokens/refresh" "$tmpdir/refresh-21.h" "$tmpdir/refresh-21.b" \
  -H "X-Refresh-Token: invalid-21-$RANDOM")"
[[ "$status" == "429" ]] || die "refresh-token request 21 expected 429, got $status"
pass 'refresh-token IP throttle returns 429 on request 21'

pass 'Modal public deployment acceptance smoke completed'
