#!/bin/bash
# =============================================================================
#  Admin User - Full Route & Feature Test Script
#  Tests all routes accessible by an admin user, including user management CRUD,
#  pagination, ETag caching, toggle active status, and inactive login blocks.
#
#  Usage:
#    bash scripts/test_admin.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# ---- Configuration ----
init_suite
init_admin_credentials

CREATED_USER_ID=""

# =====================================================================
#  1 - Sign In
# =====================================================================
section "1. Sign In as Admin"

sign_in "$ADMIN_EMAIL" "$ADMIN_PASSWORD" || true
assert_status "Sign in with admin credentials" "200" "$SIGN_IN_HTTP"

if [ -z "$TOKEN" ]; then
  echo -e "  ${RED}Failed to obtain JWT token. Aborting.${NC}"
  exit 1
fi
echo -e "  ${GREEN}Token obtained${NC}: ${TOKEN:0:30}..."

if [ -z "$REFRESH_TOKEN" ]; then
  echo -e "  ${RED}No refresh_token returned at sign-in. Aborting.${NC}"
  exit 1
fi
echo -e "  ${GREEN}Refresh token obtained${NC}: ${REFRESH_TOKEN:0:30}..."

# =====================================================================
#  2 - Get Profile (3 endpoints)
# =====================================================================
section "2. Get Admin Profile"

check_profile_endpoints
ADMIN_ID=$PROFILE_ID
echo -e "  ${YELLOW}Admin user ID:${NC} $ADMIN_ID"

# =====================================================================
#  3 - List All Users (Pagination & ETag Caching)
# =====================================================================
section "3. List All Users (Pagination & ETag Caching)"

HTTP=$(api_status -X GET "$BASE_URL/users")
assert_status "GET /users (index)" "200" "$HTTP"

BODY=$(api_body -X GET "$BASE_URL/users")
USER_COUNT=$(echo "$BODY" | jq '.users | length')
echo -e "  ${YELLOW}Total users returned:${NC} $USER_COUNT"

# Test Pagination params
PAGY_RESP=$(api_body -X GET "$BASE_URL/users?page=1&per_page=2")
PER_PAGE_RES=$(echo "$PAGY_RESP" | jq -r '.meta.per_page // 0')
if [ "$PER_PAGE_RES" = "2" ]; then
  echo -e "  ${GREEN}✓${NC} GET /users pagination (per_page=2)"
  passed=$((passed + 1))
else
  echo -e "  ${RED}✗${NC} GET /users pagination expected per_page=2, got $PER_PAGE_RES"
  failed=$((failed + 1))
fi

# Test ETag Caching
HEADERS=$(curl -s -D - -o /dev/null -H "Authorization: Bearer $TOKEN" "$BASE_URL/users")
ETAG=$(echo "$HEADERS" | tr -d '\r' | grep -i "^etag:" | sed 's/^[eE][tT][aA][gG]:[[:space:]]*//' || true)

if [ -z "$ETAG" ]; then
  echo -e "  ${RED}✗${NC} GET /users ETag header present (expected an ETag, got none)"
  failed=$((failed + 1))
else
  STALE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $TOKEN" \
    -H "If-None-Match: $ETAG" \
    "$BASE_URL/users")
  assert_status "GET /users with If-None-Match (ETag caching, expect 304)" "304" "$STALE_STATUS"
fi

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

TARGET_SUFFIX=$(date +%s)
TARGET_EMAIL="test_target_${TARGET_SUFFIX}@test.com"
TARGET_PASS="Password1!"

BODY=$(api_body -X POST -d "{
  \"user\": {
    \"email\": \"$TARGET_EMAIL\",
    \"username\": \"test_target_${TARGET_SUFFIX}\",
    \"first_name\": \"Target\",
    \"last_name\": \"User\",
    \"password\": \"$TARGET_PASS\",
    \"password_confirmation\": \"$TARGET_PASS\"
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

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"role\": \"admin\"
  }
}" "$BASE_URL/users/$CREATED_USER_ID")
assert_status "PUT /users/$CREATED_USER_ID (update role)" "200" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"role\": \"user\"
  }
}" "$BASE_URL/users/$CREATED_USER_ID")
assert_status "PUT /users/$CREATED_USER_ID (revert role)" "200" "$HTTP"

# =====================================================================
#  8 - Confirm User by Admin (before toggle-status, so user can sign in)
# =====================================================================
section "8. Confirm User by Admin"

HTTP=$(api_status -X PUT "$BASE_URL/users/$CREATED_USER_ID/confirm_by_admin")
assert_status "PUT /users/$CREATED_USER_ID/confirm_by_admin" "200" "$HTTP"

HTTP=$(api_status -X PUT "$BASE_URL/users/999999/confirm_by_admin")
assert_status "PUT /users/999999/confirm_by_admin (not found, expect 404)" "404" "$HTTP"

# =====================================================================
#  9 - Toggle Active Status & Inactive Sign-In Verification
# =====================================================================
section "9. Toggle Active Status & Inactive Sign-In Verification"

# Deactivate user
HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": false }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (deactivate)" "200" "$HTTP"

# Verify sign-in fails for deactivated user
DEACTIVATED_SIGNIN=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$TARGET_EMAIL\",
      \"password\": \"$TARGET_PASS\"
    }
  }" "$BASE_URL/users/sign_in")
DEACTIVATED_HTTP=$(echo "$DEACTIVATED_SIGNIN" | tail -1)
assert_status "POST /users/sign_in as deactivated user (expect 401)" "401" "$DEACTIVATED_HTTP"

# Reactivate user
HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": true }
}" "$BASE_URL/users/$CREATED_USER_ID/status")
assert_status "PUT /users/$CREATED_USER_ID/status (reactivate)" "200" "$HTTP"

# Verify sign-in succeeds after reactivation (user is already confirmed above)
REACTIVATED_SIGNIN=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$TARGET_EMAIL\",
      \"password\": \"$TARGET_PASS\"
    }
  }" "$BASE_URL/users/sign_in")
REACTIVATED_HTTP=$(echo "$REACTIVATED_SIGNIN" | tail -1)
assert_status "POST /users/sign_in after reactivation (expect 200)" "200" "$REACTIVATED_HTTP"

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

update_profile_via_devise "Admin" "Master" "$ADMIN_PASSWORD"

# =====================================================================
# 13 - Refresh Token Flow
# =====================================================================
section "13. Refresh Token Flow"
test_refresh_token_flow

# =====================================================================
# 14 - Sign Out
# =====================================================================
section "14. Sign Out"
test_sign_out_flow "$ADMIN_EMAIL" "$ADMIN_PASSWORD"

print_summary_and_exit
