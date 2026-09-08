#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_command curl
require_command jq
require_command mktemp
require_command sed
require_command tr

API_BASE_URL="$(normalize_base_url "${API_BASE_URL:-}")"
JWT_AUTH_HEADER="${JWT_AUTH_HEADER:-Authorization}"
SMOKE_EMAIL="${SMOKE_EMAIL:-}"
SMOKE_PASSWORD="${SMOKE_PASSWORD:-}"
VALIDATE_ONLY=false
[[ "${1:-}" == "--validate-only" ]] && VALIDATE_ONLY=true

[[ -n "${API_BASE_URL}" ]] || die "API_BASE_URL is required"
if [[ -n "${SMOKE_EMAIL}" || -n "${SMOKE_PASSWORD}" ]]; then
  [[ -n "${SMOKE_EMAIL}" && -n "${SMOKE_PASSWORD}" ]] || die "SMOKE_EMAIL and SMOKE_PASSWORD must be supplied together"
fi

if [[ "${VALIDATE_ONLY}" == true ]]; then
  status_line PASS "smoke configuration" "valid"
  exit 0
fi

health_code="$(curl -sS -o /dev/null -w '%{http_code}' "${API_BASE_URL}/up")"
[[ "${health_code}" == "200" ]] || die "/up expected 200, got ${health_code}"
status_line PASS "deployment health" "${API_BASE_URL}/up -> 200"

if [[ -z "${SMOKE_EMAIL}" ]]; then
  status_line "NOT RUN" "authentication smoke" "SMOKE_EMAIL/SMOKE_PASSWORD not supplied"
  exit 0
fi

headers="$(mktemp)"
body="$(mktemp)"
trap 'rm -f "${headers}" "${body}"' EXIT

signin_code="$(curl -sS -D "${headers}" -o "${body}" -w '%{http_code}' \
  -X POST "${API_BASE_URL}/users/sign_in" \
  -H 'Content-Type: application/json' \
  --data "$(jq -nc --arg email "${SMOKE_EMAIL}" --arg password "${SMOKE_PASSWORD}" '{user:{email:$email,password:$password}}')")"
[[ "${signin_code}" == "200" ]] || die "sign-in expected 200, got ${signin_code}"

token="$(awk -v header="${JWT_AUTH_HEADER}" 'BEGIN{IGNORECASE=1} $0 ~ "^" header ":" {sub(/^[^:]+:[[:space:]]*[Bb]earer[[:space:]]+/, ""); gsub(/\r/, ""); print; exit}' "${headers}")"
if [[ -z "${token}" ]]; then
  token="$(jq -r '.token // empty' "${body}")"
fi
[[ -n "${token}" ]] || die "sign-in succeeded but no JWT was returned"
status_line PASS "authentication sign-in" "JWT received via ${JWT_AUTH_HEADER} or JSON fallback"

profile_code="$(curl -sS -o "${body}" -w '%{http_code}' \
  "${API_BASE_URL}/user/profile" \
  -H "${JWT_AUTH_HEADER}: Bearer ${token}")"
[[ "${profile_code}" == "200" ]] || die "profile expected 200, got ${profile_code}"
jq -e '.user != null' "${body}" >/dev/null || die "profile response does not contain a user"
status_line PASS "authenticated profile" "/user/profile -> 200"

status_line PASS "deployment smoke" "health + authentication"
