#!/bin/bash
# =============================================================================
#  Shared helpers for API test scripts (test_user.sh / test_admin.sh)
#
#  Usage (at the top of each suite script):
#    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#    source "$SCRIPT_DIR/test_helpers.sh"
#
#  Provides: require_command checks, colors, pass/fail counters, section/assert
#  helpers, authenticated request shortcuts, and shared feature flows
#  (refresh-token rotation, sign-out + revocation) and a summary printer.
#
#  Call init_suite() from each suite script before invoking shared functions;
#  it defines BASE_URL, COOKIE_JAR and a cleanup trap. TOKEN is set by sign_in().
# =============================================================================

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
}

require_command curl
require_command jq
require_command sed
require_command tail
require_command grep
require_command tr
require_command head
require_command date
require_command mktemp

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

passed=0
failed=0

section() {
  echo ""
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}========================================${NC}"
}

assert_status() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo -e "  ${GREEN}✓${NC} $label (HTTP $actual)"
    passed=$((passed + 1))
  else
    echo -e "  ${RED}✗${NC} $label (expected HTTP $expected, got $actual)"
    failed=$((failed + 1))
  fi
}

assert_body_contains() {
  local label="$1" needle="$2" body="$3"
  if echo "$body" | grep -q "$needle"; then
    echo -e "  ${GREEN}✓${NC} $label"
    passed=$((passed + 1))
  else
    echo -e "  ${RED}✗${NC} $label (expected body to contain \"$needle\", got: $body)"
    failed=$((failed + 1))
  fi
}

# ---- Refresh token request helpers ----
refresh_via_cookie() {
  curl -s -w "\n%{http_code}" -X POST \
    -b "$COOKIE_JAR" -c "$COOKIE_JAR" \
    "$BASE_URL/users/tokens/refresh"
}

refresh_via_header() {
  local token="$1"
  curl -s -w "\n%{http_code}" -X POST \
    -H "X-Refresh-Token: $token" \
    "$BASE_URL/users/tokens/refresh"
}

refresh_via_body() {
  local token="$1"
  curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"refresh_token\": \"$token\"}" \
    "$BASE_URL/users/tokens/refresh"
}

# ---- Authenticated request shortcuts ----
# Requires: TOKEN (JWT obtained at sign-in)
api() {
  curl -s -w "\n%{http_code}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    "$@"
}

api_body() {
  local response
  response=$(api "$@")
  echo "$response" | sed '$d'
}

api_status() {
  local response
  response=$(api "$@")
  echo "$response" | tail -1
}

# =============================================================================
#  Shared feature flows
# =============================================================================

# Full refresh-token rotation / reuse-detection / family-revocation flow.
test_refresh_token_flow() {
  RT_RESP=$(refresh_via_cookie)
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Refresh via cookie jar" "200" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  assert_body_contains "cookie refresh returns access_token" "access_token" "$RT_BODY"
  RT1=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
  echo -e "  ${YELLOW}Rotated refresh token (cookie):${NC} ${RT1:0:30}..."

  RT_RESP=$(refresh_via_header "$RT1")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Refresh via X-Refresh-Token header" "200" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  RT2=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
  echo -e "  ${YELLOW}Rotated refresh token (header):${NC} ${RT2:0:30}..."

  RT_RESP=$(refresh_via_body "$RT2")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Refresh via JSON body" "200" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  RT3=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
  echo -e "  ${YELLOW}Rotated refresh token (body):${NC} ${RT3:0:30}..."

  RT_RESP=$(refresh_via_body "$RT2")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Reuse of rotated token (expect 401)" "401" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  assert_body_contains "reuse detection message" "reuse detected" "$RT_BODY"

  RT_RESP=$(refresh_via_body "$RT3")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Family token revoked (expect 401)" "401" "$RT_HTTP"

  RT_RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/users/tokens/refresh")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Missing refresh token (expect 401)" "401" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  assert_body_contains "missing token message" "Refresh token is missing" "$RT_BODY"

  RT_RESP=$(refresh_via_body "garbage-token")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Invalid refresh token (expect 401)" "401" "$RT_HTTP"
  RT_BODY=$(echo "$RT_RESP" | sed '$d')
  assert_body_contains "invalid token message" "Invalid refresh token" "$RT_BODY"
}

# Sign-out + refresh-token revocation flow.
test_sign_out_flow() {
  local email="$1" password="$2"

  HTTP=$(api_status -X DELETE "$BASE_URL/users/sign_out")
  assert_status "DELETE /users/sign_out" "200" "$HTTP"

  RE_SIGN_IN=$(curl -s -c "$COOKIE_JAR" -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"email\": \"$email\",
        \"password\": \"$password\"
      }
    }" "$BASE_URL/users/sign_in")
  RE_TOKEN=$(echo "$RE_SIGN_IN" | jq -r '.token // empty')
  RE_REFRESH=$(echo "$RE_SIGN_IN" | jq -r '.refresh_token // empty')

  HTTP=$(curl -s -w "\n%{http_code}" -X DELETE -b "$COOKIE_JAR" \
    -H "Authorization: Bearer $RE_TOKEN" \
    "$BASE_URL/users/sign_out" | tail -1)
  assert_status "Sign out with refresh cookie" "200" "$HTTP"

  RT_RESP=$(refresh_via_body "$RE_REFRESH")
  RT_HTTP=$(echo "$RT_RESP" | tail -1)
  assert_status "Refresh after sign out (expect 401)" "401" "$RT_HTTP"
}

# Print summary and exit non-zero when any assertion failed.
print_summary_and_exit() {
  echo ""
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}  SUMMARY${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo -e "  ${GREEN}Passed:${NC} $passed"
  echo -e "  ${RED}Failed:${NC} $failed"
  echo ""

  if [ "$failed" -gt 0 ]; then
    exit 1
  fi
}

# ---- Suite initialization ----
# Requires nothing; sets BASE_URL, COOKIE_JAR and a cleanup trap for EXIT.
init_suite() {
  BASE_URL="${API_BASE_URL:-http://localhost:4000}"
  COOKIE_JAR=$(mktemp)
  trap 'rm -f "$COOKIE_JAR"' EXIT
}

# Admin credentials, defined once here and shared by test_admin.sh and
# test_user.sh (used to bootstrap the regular user). Honors env overrides.
init_admin_credentials() {
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@admin.admin}"
  ADMIN_PASSWORD="${ADMIN_PASSWORD:-adminAdmin@1}"
}

# Sign in as the given user. Sets SIGN_IN_HTTP, SIGN_IN_BODY, TOKEN,
# REFRESH_TOKEN. Returns 0 only when the sign-in HTTP status is 200.
# Callers must guard bare calls with `|| true` (suites run under set -euo pipefail).
sign_in() {
  local email="$1" password="$2"
  local raw
  raw=$(curl -s -D - -c "$COOKIE_JAR" -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"email\": \"$email\",
        \"password\": \"$password\"
      }
    }" "$BASE_URL/users/sign_in" || true)
  SIGN_IN_HTTP=$(echo "$raw" | head -1 | grep -Eo '[0-9]{3}' || true)
  SIGN_IN_BODY=$(echo "$raw" | tr -d '\r' | sed -n '/^$/,$ p' | tail -n +2)
  TOKEN=$(echo "$raw" | tr -d '\r' | grep -i "^authorization:" | sed 's/.*[Bb]earer //' | tr -d '\r\n')
  if [ -z "$TOKEN" ]; then
    TOKEN=$(echo "$SIGN_IN_BODY" | jq -r '.token // empty')
  fi
  REFRESH_TOKEN=$(echo "$SIGN_IN_BODY" | jq -r '.refresh_token // empty')
  [ "$SIGN_IN_HTTP" = "200" ]
}

# Verify the three profile endpoints and capture the caller's own user id.
check_profile_endpoints() {
  local http
  http=$(api_status -X GET "$BASE_URL/user/profile")
  assert_status "GET /user/profile" "200" "$http"
  http=$(api_status -X GET "$BASE_URL/user/me")
  assert_status "GET /user/me" "200" "$http"
  http=$(api_status -X GET "$BASE_URL/user/whoami")
  assert_status "GET /user/whoami" "200" "$http"
  PROFILE_ID=$(api_body -X GET "$BASE_URL/user/profile" | jq -r '.user.id')
}

# Devise account update (PUT /users) with current_password validation.
update_profile_via_devise() {
  local first_name="$1" last_name="$2" current_password="$3"
  local http
  http=$(api_status -X PUT -d "{
    \"user\": {
      \"first_name\": \"$first_name\",
      \"last_name\": \"$last_name\",
      \"current_password\": \"$current_password\"
    }
  }" "$BASE_URL/users")
  assert_status "PUT /users (Devise account update)" "200" "$http"
}
