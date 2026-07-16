#!/bin/bash
# =============================================================================
#  Admin User - Full Route Test Script
#  Tests all routes accessible by an admin user, including user management CRUD
#  and toggle active status.
#
#  Usage:
#    bash scripts/test_admin.sh
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
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@admin.admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-adminAdmin@1}"

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

passed=0
failed=0
CREATED_USER_ID=""

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

# =====================================================================
#  1 - Sign In
# =====================================================================
section "1. Sign In as Admin"

SIGN_IN_RAW=$(curl -s -D - -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$ADMIN_EMAIL\",
      \"password\": \"$ADMIN_PASSWORD\"
    }
  }" "$BASE_URL/users/sign_in")

SIGN_IN_HTTP=$(echo "$SIGN_IN_RAW" | head -1 | grep -oP '\d{3}')
SIGN_IN_BODY=$(echo "$SIGN_IN_RAW" | sed -n '/^\r$/,$ p' | tail -n +2)

assert_status "Sign in with admin credentials" "200" "$SIGN_IN_HTTP"

TOKEN=$(echo "$SIGN_IN_RAW" | grep -i "^authorization:" | sed 's/.*Bearer //' | tr -d '\r\n')

if [ -z "$TOKEN" ]; then
  echo -e "  ${RED}Failed to obtain JWT token. Aborting.${NC}"
  exit 1
fi

echo -e "  ${GREEN}Token obtained${NC}: ${TOKEN:0:30}..."

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
section "2. Get Admin Profile"

HTTP=$(api_status -X GET "$BASE_URL/user/profile")
assert_status "GET /user/profile" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/user/me")
assert_status "GET /user/me" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/user/whoami")
assert_status "GET /user/whoami" "200" "$HTTP"

ADMIN_ID=$(api_body -X GET "$BASE_URL/user/profile" | jq -r '.user.id')
echo -e "  ${YELLOW}Admin user ID:${NC} $ADMIN_ID"

# =====================================================================
#  3 - List All Users (Admin Only)
# =====================================================================
section "3. List All Users"

HTTP=$(api_status -X GET "$BASE_URL/users")
assert_status "GET /users (index)" "200" "$HTTP"

BODY=$(api_body -X GET "$BASE_URL/users")
USER_COUNT=$(echo "$BODY" | jq '.users | length')
echo -e "  ${YELLOW}Total users returned:${NC} $USER_COUNT"

# =====================================================================
#  4 - Show Specific User
# =====================================================================
section "4. Show Specific User"

HTTP=$(api_status -X GET "$BASE_URL/users/$ADMIN_ID")
assert_status "GET /users/$ADMIN_ID (admin self)" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/users/999999")
assert_status "GET /users/999999 (non-existent, expect 404)" "404" "$HTTP"

# =====================================================================
#  5 - Create User (Admin Only)
# =====================================================================
section "5. Create New User"

CREATE_SUFFIX=$(date +%s)
HTTP=$(api_status -X POST -d "{
  \"user\": {
    \"email\": \"admin_created_${CREATE_SUFFIX}@test.com\",
    \"username\": \"admin_created_${CREATE_SUFFIX}\",
    \"first_name\": \"Created\",
    \"last_name\": \"ByAdmin\",
    \"password\": \"Password1!\",
    \"password_confirmation\": \"Password1!\"
  }
}" "$BASE_URL/users/create")
assert_status "POST /users/create" "201" "$HTTP"

# Extract created user ID for later tests
TARGET_SUFFIX=$(date +%s)
BODY=$(api_body -X POST -d "{
  \"user\": {
    \"email\": \"test_target_${TARGET_SUFFIX}@test.com\",
    \"username\": \"test_target_${TARGET_SUFFIX}\",
    \"first_name\": \"Target\",
    \"last_name\": \"User\",
    \"password\": \"Password1!\",
    \"password_confirmation\": \"Password1!\"
  }
}" "$BASE_URL/users/create")
CREATED_USER_ID=$(echo "$BODY" | jq -r '.id')
echo -e "  ${YELLOW}Created target user ID:${NC} $CREATED_USER_ID"

# =====================================================================
#  6 - Create User with Role
# =====================================================================
section "6. Create User with Role"

HTTP=$(api_status -X POST -d "{
  \"user\": {
    \"email\": \"admin_role_$(date +%s)@test.com\",
    \"username\": \"admin_role_$(date +%s)\",
    \"password\": \"Password1!\",
    \"role\": \"admin\"
  }
}" "$BASE_URL/users/create")
assert_status "POST /users/create (with admin role)" "201" "$HTTP"

# =====================================================================
#  7 - Update User
# =====================================================================
section "7. Update User"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"first_name\": \"Updated\",
    \"last_name\": \"ByAdmin\"
  }
}" "$BASE_URL/users/$CREATED_USER_ID")
assert_status "PUT /users/$CREATED_USER_ID (update name)" "200" "$HTTP"

# Update role
HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"role\": \"admin\"
  }
}" "$BASE_URL/users/$CREATED_USER_ID")
assert_status "PUT /users/$CREATED_USER_ID (update role)" "200" "$HTTP"

# Revert role back to user
HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"role\": \"user\"
  }
}" "$BASE_URL/users/$CREATED_USER_ID")
assert_status "PUT /users/$CREATED_USER_ID (revert role)" "200" "$HTTP"

# =====================================================================
#  8 - Toggle Active Status (Admin Only)
# =====================================================================
section "8. Toggle Active Status"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": false }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (deactivate)" "200" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": true }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (reactivate)" "200" "$HTTP"

# Test boolean string parsing
HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": \"no\" }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (string 'no')" "200" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": \"yes\" }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (string 'yes')" "200" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": \"invalid\" }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (invalid string, expect 422)" "422" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": false }
}" "$BASE_URL/users/999999/status")
assert_status "PUT /users/999999/status (not found, expect 404)" "404" "$HTTP"

# =====================================================================
#  9 - Confirm User by Admin
# =====================================================================
section "9. Confirm User by Admin"

HTTP=$(api_status -X PUT "$BASE_URL/users/$CREATED_USER_ID/confirm_by_admin")
assert_status "PUT /users/$CREATED_USER_ID/confirm_by_admin" "200" "$HTTP"

HTTP=$(api_status -X PUT "$BASE_URL/users/999999/confirm_by_admin")
assert_status "PUT /users/999999/confirm_by_admin (not found, expect 404)" "404" "$HTTP"

# =====================================================================
# 10 - Delete User
# =====================================================================
section "10. Delete User"

HTTP=$(api_status -X DELETE "$BASE_URL/users/$CREATED_USER_ID")
assert_status "DELETE /users/$CREATED_USER_ID" "200" "$HTTP"

HTTP=$(api_status -X GET "$BASE_URL/users/$CREATED_USER_ID")
assert_status "GET /users/$CREATED_USER_ID (after delete, expect 404)" "404" "$HTTP"

# =====================================================================
# 11 - Verify Cannot Demote Self
# =====================================================================
section "11. Verify Admin Cannot Demote Self"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"role\": \"user\" }
}" "$BASE_URL/users/$ADMIN_ID")
assert_status "PUT /users/$ADMIN_ID (self-demotion, expect 422)" "422" "$HTTP"

# =====================================================================
# 12 - Update Profile via Devise
# =====================================================================
section "12. Update Profile (Devise)"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"first_name\": \"Admin\",
    \"last_name\": \"Master\",
    \"current_password\": \"$ADMIN_PASSWORD\"
  }
}" "$BASE_URL/users")
assert_status "PUT /users (Devise account update)" "200" "$HTTP"

# =====================================================================
# 13 - Sign Out
# =====================================================================
section "13. Sign Out"

HTTP=$(api_status -X DELETE "$BASE_URL/users/sign_out")
assert_status "DELETE /users/sign_out" "200" "$HTTP"

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
