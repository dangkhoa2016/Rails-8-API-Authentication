#!/usr/bin/env bash
set -Eeuo pipefail

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

BASE_URL="${1:-${API_BASE_URL:-}}"
E2E_EMAIL="${EMAIL_E2E_RECIPIENT:-}"
E2E_PASSWORD="${EMAIL_E2E_PASSWORD:-Password1!}"
RESEND_API_KEY="${RESEND_API_KEY:-}"

[[ -n "$BASE_URL" ]] || die 'usage: email_delivery_e2e.sh https://<modal-url> (or set API_BASE_URL)'
[[ "$BASE_URL" =~ ^https://[^[:space:]]+$ ]] || die 'API URL must use https://'
while [[ "$BASE_URL" == */ ]]; do BASE_URL="${BASE_URL%/}"; done

[[ -n "$E2E_EMAIL" ]] || die 'EMAIL_E2E_RECIPIENT is required and must be a fresh address on an allowed provider'
[[ -n "$RESEND_API_KEY" ]] || die 'RESEND_API_KEY is required locally for delivery-status verification'

command -v curl >/dev/null 2>&1 || die 'curl is required'
command -v python3 >/dev/null 2>&1 || die 'python3 is required'

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

request() {
  local method="$1" url="$2" body="$3"
  shift 3
  curl --silent --show-error --max-time 30     --request "$method"     --output "$body"     --write-out '%{http_code}'     "$@" "$url"
}

registration_payload() {
  local email="$1"
  python3 - "$email" "$E2E_PASSWORD" <<'PY'
import json, sys
email, password = sys.argv[1:3]
username = "e2e_" + email.split("@", 1)[0].replace("+", "_")[-40:]
print(json.dumps({"user": {
    "email": email,
    "username": username,
    "password": password,
    "password_confirmation": password,
}}))
PY
}

wait_for_resend_delivery() {
  local recipient="$1"
  local deadline=$((SECONDS + 90))
  local list="$tmpdir/resend-list.json"

  while (( SECONDS < deadline )); do
    curl --silent --show-error --max-time 20       -H "Authorization: Bearer $RESEND_API_KEY"       "https://api.resend.com/emails?limit=100" > "$list"

    if python3 - "$list" "$recipient" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
recipient = sys.argv[2].strip().lower()
for item in payload.get("data", []):
    targets = [str(x).lower() for x in (item.get("to") or [])]
    if recipient in targets:
        event = str(item.get("last_event") or "")
        if event in {"delivered", "opened", "clicked"}:
            print(f"[PASS] Resend delivery evidence id={item.get('id')} event={event}")
            raise SystemExit(0)
raise SystemExit(1)
PY
    then
      return 0
    fi

    sleep 3
  done

  return 1
}

blocked="blocked-$(date +%s)-$RANDOM@example.com"
registration_payload "$blocked" > "$tmpdir/blocked.json"
status="$(request POST "$BASE_URL/users" "$tmpdir/blocked-response.json"   -H 'Content-Type: application/json' --data-binary "@$tmpdir/blocked.json")"
[[ "$status" == "422" ]] || die "unsupported-domain registration expected 422, got $status"
pass 'unsupported provider is rejected before outbound delivery'

registration_payload "$E2E_EMAIL" > "$tmpdir/register.json"
status="$(request POST "$BASE_URL/users" "$tmpdir/register-response.json"   -H 'Content-Type: application/json' --data-binary "@$tmpdir/register.json")"
[[ "$status" == "201" ]] || die "allowed-provider registration expected 201, got $status; use a fresh EMAIL_E2E_RECIPIENT"

wait_for_resend_delivery "$E2E_EMAIL" || die 'Resend did not report delivered/opened/clicked for the registration email within 90 seconds'
pass 'registration confirmation email is delivered through the public Modal runtime'

info 'Manual acceptance step: open the confirmation email in the recipient inbox and follow its HTTPS confirmation link.'
info 'After confirmation, verify sign-in and then request password reset from the public API.'
pass 'Modal + Resend delivery acceptance completed'
