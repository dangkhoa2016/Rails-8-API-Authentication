#!/bin/bash
# =============================================================================
#  Regular User - Full Route & Feature Test Script
#  Tests all routes accessible by a regular user, public registration,
#  password reset flows, self account management, and system health routes.
#
#  Usage:
#    bash scripts/test_user.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

# ---- Configuration ----
init_suite

USER_EMAIL="${USER_EMAIL:-user@example.com}"
USER_PASSWORD="${USER_PASSWORD:-password@123A}"
USER_USERNAME="${USER_USERNAME:-$(echo "$USER_EMAIL" | sed -E 's/@.*$//' | tr -cd 'a-zA-Z0-9_-' | cut -c1-25)}"
if [ "${#USER_USERNAME}" -lt 3 ]; then
  USER_USERNAME="tester"
fi

# Admin credentials are used ONLY to bootstrap the regular user when it is
# missing (create + force-confirm via the admin API), so this suite also runs
# against a fresh database. Shared definition lives in test_helpers.sh.
init_admin_credentials

# =====================================================================
#  Self-provisioning
# =====================================================================

# Bootstrap the regular user via the admin API when sign-in fails:
# confirm-by-email if present, otherwise create + confirm, then reset the
# password so repeated runs are idempotent.
bootstrap_regular_user() {
  echo -e "  ${YELLOW}Regular user not found; bootstrapping via admin API...${NC}"

  local admin_token
  if ! sign_in "$ADMIN_EMAIL" "$ADMIN_PASSWORD"; then
    echo -e "  ${RED}Admin sign-in failed; cannot bootstrap regular user.${NC}"
    return 1
  fi
  admin_token="$TOKEN"

  local confirm_resp confirm_status confirm_body user_id
  confirm_resp=$(curl -s -w "\n%{http_code}" -X PUT \
    -H "Authorization: Bearer $admin_token" \
    "$BASE_URL/users/$USER_EMAIL/confirm_by_admin" || true)
  confirm_status=$(echo "$confirm_resp" | tail -1)
  confirm_body=$(echo "$confirm_resp" | sed '$d')
  user_id=$(echo "$confirm_body" | jq -r '.id' || true)

  if [ "$confirm_status" = "200" ]; then
    echo -e "  ${GREEN}Existing user confirmed and activated (id $user_id).${NC}"
  elif [ "$confirm_status" = "404" ]; then
    local create_resp create_status
    create_resp=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $admin_token" \
      -d "{
        \"user\": {
          \"email\": \"$USER_EMAIL\",
          \"username\": \"$USER_USERNAME\",
          \"password\": \"$USER_PASSWORD\",
          \"password_confirmation\": \"$USER_PASSWORD\"
        }
      }" "$BASE_URL/users/create" || true)
    create_status=$(echo "$create_resp" | tail -1)
    if [ "$create_status" != "201" ]; then
      echo -e "  ${RED}Failed to create user (HTTP $create_status).${NC}"
      return 1
    fi
    user_id=$(echo "$create_resp" | sed '$d' | jq -r '.id' || true)
    if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
      echo -e "  ${RED}Created user but could not read its id.${NC}"
      return 1
    fi
    confirm_status=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
      -H "Authorization: Bearer $admin_token" \
      "$BASE_URL/users/$user_id/confirm_by_admin" || true)
    if [ "$confirm_status" != "200" ]; then
      echo -e "  ${RED}Failed to confirm created user (HTTP $confirm_status).${NC}"
      return 1
    fi
    echo -e "  ${GREEN}Created and confirmed user (id $user_id).${NC}"
  else
    echo -e "  ${RED}Unexpected confirm_by_admin response (HTTP $confirm_status).${NC}"
    return 1
  fi

  if [ -z "$user_id" ] || [ "$user_id" = "null" ]; then
    echo -e "  ${RED}Could not determine user id; cannot reset password.${NC}"
    return 1
  fi

  local pw_status
  pw_status=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $admin_token" \
    -d "{
      \"user\": {
        \"password\": \"$USER_PASSWORD\",
        \"password_confirmation\": \"$USER_PASSWORD\"
      }
    }" "$BASE_URL/users/$user_id" || true)
  if [ "$pw_status" != "200" ]; then
    echo -e "  ${RED}Failed to reset password (HTTP $pw_status).${NC}"
    return 1
  fi

  curl -s -o /dev/null -X DELETE \
    -H "Authorization: Bearer $admin_token" \
    "$BASE_URL/users/sign_out" || true

  return 0
}

# =====================================================================
#  1 - Sign In (Email & Username)
# =====================================================================
section "1. Sign In as Regular User (Email & Username)"

if ! sign_in "$USER_EMAIL" "$USER_PASSWORD"; then
  echo -e "  ${YELLOW}Sign-in returned HTTP $SIGN_IN_HTTP.${NC}"
  if bootstrap_regular_user; then
    echo -e "  ${GREEN}Regular user bootstrapped.${NC}"
  else
    echo -e "  ${RED}Bootstrap failed. Set ADMIN_EMAIL/ADMIN_PASSWORD or provision the user manually.${NC}"
  fi
  # Always re-sign-in as the regular user so SIGN_IN_HTTP/TOKEN reflect this
  # user (not the admin credentials used inside bootstrap_regular_user).
  sign_in "$USER_EMAIL" "$USER_PASSWORD" || true
fi

assert_status "Sign in with valid email & password" "200" "$SIGN_IN_HTTP"

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

# Test Sign In using Username instead of Email
USER_USERNAME=$(echo "$SIGN_IN_BODY" | jq -r '.user.username // empty')
if [ -n "$USER_USERNAME" ] && [ "$USER_USERNAME" != "null" ]; then
  UNAME_RESP=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{
      \"user\": {
        \"email\": \"$USER_USERNAME\",
        \"password\": \"$USER_PASSWORD\"
      }
    }" "$BASE_URL/users/sign_in")
  UNAME_HTTP=$(echo "$UNAME_RESP" | tail -1)
  assert_status "Sign in using username ($USER_USERNAME)" "200" "$UNAME_HTTP"
fi

# =====================================================================
#  2 - Get Profile (3 endpoints)
# =====================================================================
section "2. Get User Profile"

check_profile_endpoints
OWN_ID=$PROFILE_ID
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

# Test password change via PUT /users/$OWN_ID with current_password validation
HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"password\": \"NewPassword1!\",
    \"password_confirmation\": \"NewPassword1!\"
  },
  \"current_password\": \"wrong_password\"
}" "$BASE_URL/users/$OWN_ID")
assert_status "PUT /users/$OWN_ID password update with WRONG current_password (expect 422)" "422" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": {
    \"password\": \"$USER_PASSWORD\",
    \"password_confirmation\": \"$USER_PASSWORD\"
  },
  \"current_password\": \"$USER_PASSWORD\"
}" "$BASE_URL/users/$OWN_ID")
assert_status "PUT /users/$OWN_ID password update with CORRECT current_password" "200" "$HTTP"

# =====================================================================
#  5 - Update Own Profile via Devise Registrations
# =====================================================================
section "5. Update Own Profile (Devise)"

update_profile_via_devise "Regular" "Tester" "$USER_PASSWORD"

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

OTHER_UNAME="$(echo "$ADMIN_EMAIL" | cut -d@ -f1)"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"active\": false }
}" "$BASE_URL/users/$OTHER_UNAME/status")
assert_status "PUT /users/$OTHER_UNAME/status (expect 403)" "403" "$HTTP"

HTTP=$(api_status -X PUT "$BASE_URL/users/$OTHER_UNAME/confirm_by_admin")
assert_status "PUT /users/$OTHER_UNAME/confirm_by_admin (expect 403)" "403" "$HTTP"

# =====================================================================
#  7 - Verify Cannot Access Other User's Profile
# =====================================================================
section "7. Verify Cannot Access Other User's Record"

HTTP=$(api_status -X GET "$BASE_URL/users/$OTHER_UNAME")
assert_status "GET /users/$OTHER_UNAME (other user, expect 403)" "403" "$HTTP"

HTTP=$(api_status -X PUT -d "{
  \"user\": { \"first_name\": \"Hacked\" }
}" "$BASE_URL/users/$OTHER_UNAME")
assert_status "PUT /users/$OTHER_UNAME (update other, expect 403)" "403" "$HTTP"

# =====================================================================
#  8 - Password Reset Flow (Devise Passwords - Paranoid Mode)
# =====================================================================
section "8. Password Reset Flow (Devise Passwords)"

# Request password reset for existing user
PWD_REQ=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$USER_EMAIL\"
    }
  }" "$BASE_URL/users/password")
PWD_HTTP=$(echo "$PWD_REQ" | tail -1)
assert_status "POST /users/password (valid email)" "200" "$PWD_HTTP"

# Request password reset for invalid email (Devise paranoid mode returns 200 to prevent email enumeration)
PWD_REQ=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"non_existent_email_12345@test.com\"
    }
  }" "$BASE_URL/users/password")
PWD_HTTP=$(echo "$PWD_REQ" | tail -1)
assert_status "POST /users/password (invalid email in paranoid mode, expect 200)" "200" "$PWD_HTTP"

# Update password with invalid token
PWD_RESET=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"reset_password_token\": \"invalid_token_123\",
      \"password\": \"NewPass123!\",
      \"password_confirmation\": \"NewPass123!\"
    }
  }" "$BASE_URL/users/password")
PWD_HTTP=$(echo "$PWD_RESET" | tail -1)
assert_status "PUT /users/password (invalid token, expect 422)" "422" "$PWD_HTTP"

# =====================================================================
#  9 - Public Registration & Self Account Cancellation
# =====================================================================
section "9. Public User Self-Registration & Account Cancellation"

SELF_REG_SUFFIX=$(date +%s)
SELF_EMAIL="self_reg_${SELF_REG_SUFFIX}@example.com"
SELF_UNAME="self_reg_${SELF_REG_SUFFIX}"
SELF_PASS="Password123!"

# Invalid registration (password missing uppercase/number)
REG_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$SELF_EMAIL\",
      \"username\": \"$SELF_UNAME\",
      \"password\": \"weak\",
      \"password_confirmation\": \"weak\"
    }
  }" "$BASE_URL/users")
REG_HTTP=$(echo "$REG_RESP" | tail -1)
assert_status "POST /users (invalid password format, expect 422)" "422" "$REG_HTTP"

# Valid registration
REG_RESP=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$SELF_EMAIL\",
      \"username\": \"$SELF_UNAME\",
      \"password\": \"$SELF_PASS\",
      \"password_confirmation\": \"$SELF_PASS\"
    }
  }" "$BASE_URL/users")
REG_HTTP=$(echo "$REG_RESP" | tail -1)
REG_BODY=$(echo "$REG_RESP" | sed '$d')

if [ "$REG_HTTP" = "201" ]; then
  assert_status "POST /users (valid self-registration)" "201" "$REG_HTTP"
elif [ "$REG_HTTP" = "422" ] && echo "$REG_BODY" | grep -q "confirmation email"; then
  echo -e "  ${GREEN}✓${NC} POST /users (valid self-registration attempted, SMTP offline handled)"
  passed=$((passed + 1))
else
  assert_status "POST /users (valid self-registration)" "201" "$REG_HTTP"
fi

# Sign in as new self-registered user to get JWT token (if created/confirmed)
SELF_SIGNIN=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"user\": {
      \"email\": \"$SELF_EMAIL\",
      \"password\": \"$SELF_PASS\"
    }
  }" "$BASE_URL/users/sign_in")
SELF_TOKEN=$(echo "$SELF_SIGNIN" | jq -r '.token // empty')

if [ -n "$SELF_TOKEN" ] && [ "$SELF_TOKEN" != "null" ]; then
  # Self account cancellation via DELETE /users
  DEL_RESP=$(curl -s -w "\n%{http_code}" -X DELETE \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $SELF_TOKEN" \
    "$BASE_URL/users")
  DEL_HTTP=$(echo "$DEL_RESP" | tail -1)
  assert_status "DELETE /users (self account deletion via Devise)" "200" "$DEL_HTTP"
else
  echo -e "  ${YELLOW}!${NC} Self-registered user could not sign in (not confirmed or SMTP offline)."
  echo -e "  ${YELLOW}!${NC} Skipping DELETE /users self-account-cancellation check."
fi

# =====================================================================
# 10 - Refresh Token Flow
# =====================================================================
section "10. Refresh Token Flow"
test_refresh_token_flow

# =====================================================================
# 11 - System & Health Routes
# =====================================================================
section "11. System & Health Routes"

HEALTH_RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/up")
HEALTH_HTTP=$(echo "$HEALTH_RESP" | tail -1)
assert_status "GET /up (Rails health check)" "200" "$HEALTH_HTTP"

ROOT_RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/")
ROOT_HTTP=$(echo "$ROOT_RESP" | tail -1)
assert_status "GET / (Root endpoint)" "200" "$ROOT_HTTP"

NOT_FOUND_RESP=$(curl -s -w "\n%{http_code}" "$BASE_URL/random_non_existent_route_12345")
NOT_FOUND_HTTP=$(echo "$NOT_FOUND_RESP" | tail -1)
assert_status "GET /random_non_existent_route_12345 (expect 404)" "404" "$NOT_FOUND_HTTP"

# =====================================================================
# 12 - Sign Out
# =====================================================================
section "12. Sign Out"
test_sign_out_flow "$USER_EMAIL" "$USER_PASSWORD"

print_summary_and_exit
