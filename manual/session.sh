# =============================================================================
#  Session & Authentication
# =============================================================================
#  Source config first:
#    source manual/config.sh
# =============================================================================

# ---- 1 - Sign Up (username is required) ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "username": "user1",
    "password": "password@123A",
    "password_confirmation": "password@123A"
  }
}' "$BASE_URL/users" | jq .
{
  "message": "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "created_at": "2025-01-19T13:27:43.182Z",
    "email": "user@example.com",
    "first_name": "",
    "last_name": "",
    "role": "user",
    "updated_at": "2025-01-19T13:27:43.182Z",
    "username": "user1"
  }
}
# http://localhost:4000/users/confirmation?confirmation_token=MjRUbw87mVdKk8jCRH8h

# ---- 2 - Sign In without 'user' root key ----
curl -X POST -H "Content-Type: application/json" -d '{
  "email": "user@example.com",
  "password": "password@123A"
}' "$BASE_URL/users/sign_in" | jq .
{
  "error": "You need to sign in or sign up before continuing."
}

curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "$BASE_URL/users/sign_in" | jq .
{
  "error": "You have to confirm your email address before continuing."
}

# ---- 3 - Confirm Email ----
curl -X GET "$BASE_URL/users/confirmation?confirmation_token=SgoszqA3BsrLpyNYqvem" -i
{
  "id": 2,
  "active": true,
  "email": "user@example.com",
  "username": "user1",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-16T17:32:30.315Z",
  "updated_at": "2025-01-16T17:40:50.662Z"
}

# ---- 4 - Sign In Again ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "$BASE_URL/users/sign_in" -i

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
location: /
content-type: application/json; charset=utf-8
authorization: Bearer ${TEST_JWT_TOKEN:-<your-jwt-token-here>}
set-cookie: refresh_token=<your-refresh-token>; path=/; HttpOnly; SameSite=Lax
etag: W/"f8df4ddaed8726a8beed27240b4408ca"
cache-control: max-age=0, private, must-revalidate
x-request-id: 60a01b68-f862-467c-8a34-1181d2fba3ca
x-runtime: 0.257309
server-timing: start_processing.action_controller;dur=0.01, sql.active_record;dur=3.41, instantiation.active_record;dur=0.07, start_transaction.active_record;dur=0.01, transaction.active_record;dur=4.30, process_action.action_controller;dur=251.65
Content-Length: 485

{
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "created_at": "2025-01-16T17:32:30.315Z",
    "email": "user@example.com",
    "first_name": "",
    "last_name": "",
    "role": "user",
    "updated_at": "2025-01-17T08:34:10.527Z",
    "username": "user1"
  },
  "token": "${TEST_JWT_TOKEN:-<your-jwt-token-here>}",
  "refresh_token": "<your-refresh-token>"
}

# ---- Sign In with invalid password ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com1",
    "password": "password@123A1"
  }
}' "$BASE_URL/users/sign_in" -i
{"error":"Invalid Email or password."}

# ---- 5 - Sign Out: Valid Token ----
api -X DELETE "$BASE_URL/users/sign_out" | jq .
{
  "message": "Your account: user@example.com has been signed out successfully."
}

# ---- 5 - Sign Out: Invalid Token ----
curl -s -X DELETE -H "Content-Type: application/json" \
  -H "Authorization: Bearer test" \
  "$BASE_URL/users/sign_out" -i
{"error":"Invalid token"}

# ---- 6 - Get Signed In User JSON Data (/user/profile) ----
api -X GET "$BASE_URL/user/profile" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "user1",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "<your-jwt-token-here>",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# ---- 6 - Get Signed In User JSON Data (/user/me) ----
api -X GET "$BASE_URL/user/me" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "user1",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "<your-jwt-token-here>",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# ---- 6 - Get Signed In User JSON Data (/user/whoami) ----
api -X GET "$BASE_URL/user/whoami" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "user1",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "<your-jwt-token-here>",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# ---- 7 - Get Signed In User JSON Data: Invalid Token ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TEST_JWT_TOKEN:-<your-jwt-token-here>}" \
  "$BASE_URL/user/profile" | jq .
{
  "error": "Invalid token"
}

# ---- 7 - Get Signed In User JSON Data: Expired Token ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TEST_JWT_TOKEN:-<your-jwt-token-here>}" \
  "$BASE_URL/user/profile" | jq .
{
  "user": null,
  "token_info": {
    "token": "<your-jwt-token-here>",
    "user_id": "2",
    "expired_at": "2025-01-17T09:34:10.000+00:00",
    "expired_in": -16482,
    "expired": true,
    "jti": "459a338f-0738-42db-886f-79f3519b8798"
  }
}

# ---- 8 - Refresh Access Token (rotation) ----
# Use any ONE of the three transports below. Each call rotates the refresh
# token and returns a fresh access token.

# 8a - Refresh via X-Refresh-Token header
curl -s -X POST -H "Content-Type: application/json" \
  -H "X-Refresh-Token: <your-refresh-token>" \
  "$BASE_URL/users/tokens/refresh" | jq .

# 8b - Refresh via JSON body
curl -s -X POST -H "Content-Type: application/json" -d '{
  "refresh_token": "<your-refresh-token>"
}' "$BASE_URL/users/tokens/refresh" | jq .

# 8c - Refresh via cookie
curl -s -X POST -H "Content-Type: application/json" \
  -b "refresh_token=<your-refresh-token>" \
  "$BASE_URL/users/tokens/refresh" | jq .

# Response:
{
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "created_at": "2025-01-16T17:32:30.315Z",
    "email": "user@example.com",
    "first_name": "",
    "last_name": "",
    "role": "user",
    "updated_at": "2025-01-17T09:00:00.000Z",
    "username": "user1"
  },
  "access_token": "<your-new-access-token>",
  "refresh_token": "<your-new-refresh-token>"
}

# 8d - Reuse of an already-rotated token -> whole family is revoked
curl -s -X POST -H "Content-Type: application/json" \
  -H "X-Refresh-Token: <your-old-refresh-token>" \
  "$BASE_URL/users/tokens/refresh" | jq .
{
  "error": "Security alert: Refresh token reuse detected. All sessions revoked."
}
