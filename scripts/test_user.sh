#!/bin/bash
# =============================================================================
#  Regular User - Full Route Test Script
#  Tests all routes accessible by a regular (non-admin) user.
#
#  Usage:
#    bash scripts/test_user.sh
# =============================================================================

set -euo pipefail

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

# ---- Configuration ----
BASE_URL="${API_BASE_URL:-http://localhost:4000}"
USER_EMAIL="${USER_EMAIL:-user@example.com}"
USER_PASSWORD="${USER_PASSWORD:-password@123A}"

COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT

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

# =====================================================================
#  1 - Sign In
# =====================================================================
section "1. Sign In as Regular User"

SIGN_IN_RESPONSE=$(curl -s -w "\n%{http_code}" -c "$COOKIE_JAR" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$USER_EMAIL\",
      \"password\": \"$USER_PASSWORD\"
    }
  }" "$BASE_URL/users/sign_in")

SIGN_IN_HTTP=$(echo "$SIGN_IN_RESPONSE" | tail -1)
SIGN_IN_BODY=$(echo "$SIGN_IN_RESPONSE" | sed '$d')

assert_status "Sign in with valid credentials" "200" "$SIGN_IN_HTTP"

TOKEN=$(echo "$SIGN_IN_BODY" | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  # Extract from Authorization header instead
  SIGN_IN_RAW=$(curl -s -D - -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"email\": \"$USER_EMAIL\",
        \"password\": \"$USER_PASSWORD\"
      }
    }" "$BASE_URL/users/sign_in")
  TOKEN=$(echo "$SIGN_IN_RAW" | grep -i "^authorization:" | sed 's/.*Bearer //' | tr -d '\r\n')
fi

if [ -z "$TOKEN" ]; then
  echo -e "  ${RED}Failed to obtain JWT token. Aborting.${NC}"
  exit 1
fi

echo -e "  ${GREEN}Token obtained${NC}: ${TOKEN:0:30}..."

REFRESH_TOKEN=$(echo "$SIGN_IN_BODY" | jq -r '.refresh_token // empty')

if [ -z "$REFRESH_TOKEN" ]; then
  echo -e "  ${RED}No refresh_token returned at sign-in. Aborting.${NC}"
  exit 1
fi
echo -e "  ${GREEN}Refresh token obtained${NC}: ${REFRESH_TOKEN:0:30}..."

# Shortcut for authenticated requests
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

# =====================================================================
#  2 - Get Profile (3 endpoints)
# =====================================================================
section "2. Get User Profile"

HTTP=$(api_status -X GET "$BASE_URL/user/profile")
assert_status "GET /user/profile" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/user/me")
assert_status "GET /user/me" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/user/whoami")
assert_status "GET /user/whoami" "200" "$HTTP"

# Extract own user ID from profile
OWN_ID=$(api_body -X GET "$BASE_URL/user/profile" | jq -r '.user.id')
echo -e "  ${YELLOW}Own user ID:${NC} $OWN_ID"

# =====================================================================
#  3 - Show Own Profile via UsersController
# =====================================================================
section "3. Show Own User Record"

HTTP=$(api_status -X GET "$BASE_URL/users/$OWN_ID")
assert_status "GET /users/$OWN_ID (own record)" "200" "$HTTP"

# =====================================================================
#  4 - Update Own Profile via UsersController
# =====================================================================
section "4. Update Own Profile"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"first_name\": \"Regular\",
    \"last_name\": \"Tester\"
  }
}" "$BASE_URL/users/$OWN_ID")
assert_status "PUT /users/$OWN_ID (update own name)" "200" "$HTTP"

# =====================================================================
#  5 - Update Own Profile via Devise Registrations
# =====================================================================
section "5. Update Own Profile (Devise)"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"first_name\": \"Regular\",
    \"last_name\": \"Tester\",
    \"current_password\": \"$USER_PASSWORD\"
  }
}" "$BASE_URL/users")
assert_status "PUT /users (Devise account update)" "200" "$HTTP"

# =====================================================================
#  6 - Verify Access Denied on Admin Routes
# =====================================================================
section "6. Verify Forbidden on Admin-Only Routes"

HTTP=$(api_status -X GET "$BASE_URL/users")
assert_status "GET /users (index, expect 403)" "403" "$HTTP"

HTTP=$(api_status -X POST -d "{
  \"user\": {
    \"email\": \"should_not_work@test.com\",
    \"username\": \"should_not_work\",
    \"password\": \"password123\"
  }
}" "$BASE_URL/users/create")
assert_status "POST /users/create (expect 403)" "403" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": false }
}" "$BASE_URL/users/1/status")
assert_status "PUT /users/1/status (expect 403)" "403" "$HTTP"

HTTP=$(api_status -X PUT "$BASE_URL/users/1/confirm_by_admin")
assert_status "PUT /users/1/confirm_by_admin (expect 403)" "403" "$HTTP"

# =====================================================================
#  7 - Verify Cannot Access Other User's Profile
# =====================================================================
section "7. Verify Cannot Access Other User's Record"

# Find another user ID (not own)
OTHER_ID=$((OWN_ID + 1))

HTTP=$(api_status -X GET "$BASE_URL/users/$OTHER_ID")
assert_status "GET /users/$OTHER_ID (other user, expect 403)" "403" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"first_name\": \"Hacked\" }
}" "$BASE_URL/users/$OTHER_ID")
assert_status "PUT /users/$OTHER_ID (update other, expect 403)" "403" "$HTTP"

# =====================================================================
# 8 - Refresh Token Flow
# =====================================================================
section "8. Refresh Token Flow"

# a. Refresh via HttpOnly cookie (cookie jar) -> RT1
RT_RESP=$(refresh_via_cookie)
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Refresh via cookie jar" "200" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
assert_body_contains "cookie refresh returns access_token" "access_token" "$RT_BODY"
RT1=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
echo -e "  ${YELLOW}Rotated refresh token (cookie):${NC} ${RT1:0:30}..."

# b. Refresh via X-Refresh-Token header -> RT2
RT_RESP=$(refresh_via_header "$RT1")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Refresh via X-Refresh-Token header" "200" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
RT2=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
echo -e "  ${YELLOW}Rotated refresh token (header):${NC} ${RT2:0:30}..."

# c. Refresh via JSON body -> RT3
RT_RESP=$(refresh_via_body "$RT2")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Refresh via JSON body" "200" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
RT3=$(echo "$RT_BODY" | jq -r '.refresh_token // empty')
echo -e "  ${YELLOW}Rotated refresh token (body):${NC} ${RT3:0:30}..."

# d. Reuse detection: RT2 already revoked by rotation in step c
RT_RESP=$(refresh_via_body "$RT2")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Reuse of rotated token (expect 401)" "401" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
assert_body_contains "reuse detection message" "reuse detected" "$RT_BODY"

# e. Family revoked: RT3 was revoked together with its family in step d
RT_RESP=$(refresh_via_body "$RT3")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Family token revoked (expect 401)" "401" "$RT_HTTP"

# f. Missing token
RT_RESP=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/users/tokens/refresh")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Missing refresh token (expect 401)" "401" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
assert_body_contains "missing token message" "Refresh token is missing" "$RT_BODY"

# g. Invalid token
RT_RESP=$(refresh_via_body "garbage-token")
RT_HTTP=$(echo "$RT_RESP" | tail -1)
assert_status "Invalid refresh token (expect 401)" "401" "$RT_HTTP"
RT_BODY=$(echo "$RT_RESP" | sed '$d')
assert_body_contains "invalid token message" "Invalid refresh token" "$RT_BODY"

# =====================================================================
# 9 - Sign Out
# =====================================================================
section "9. Sign Out"

HTTP=$(api_status -X DELETE "$BASE_URL/users/sign_out")
assert_status "DELETE /users/sign_out" "200" "$HTTP"

# Sign out revokes the refresh token: re-sign-in, sign out with cookie, then refresh fails
RE_SIGN_IN=$(curl -s -c "$COOKIE_JAR" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$USER_EMAIL\",
      \"password\": \"$USER_PASSWORD\"
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

# =====================================================================
#  Summary
# =====================================================================
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
