# =============================================================================
#  Registration & Profile Management
# =============================================================================
#  Source config first:
#    source manual/config.sh
#    export TEST_JWT_TOKEN="<token>"
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

# ---- 1b - Sign In as role: user ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "$BASE_URL/users/sign_in" -i
# ${TEST_JWT_TOKEN:-<your-jwt-token-here>}
# Response: {"user": {...}, "token": "<access-token>", "refresh_token": "<refresh-token>"}
# The refresh token is also set as an HttpOnly cookie named "refresh_token".

# ---- 2 - Get user's profile edit form ----
api -X GET "$BASE_URL/users/edit" | jq .

# ---- 2 - Update user's profile ----
api -X PUT -d '{
  "user": {
    "username": "user1",
    "first_name": "User 1",
    "last_name": "Name 1",
    "current_password": "password@123A"
  }
}' "$BASE_URL/users" | jq .
{
  "message": "Your account has been updated successfully.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "email": "user@example.com",
    "first_name": "User 1",
    "last_name": "Name 1",
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T09:33:01.862Z",
    "username": "user1"
  }
}

# ---- 3 - Update user's email ----
api -X PUT -d '{
  "user": {
    "email": "test_updated@local.test",
    "current_password": "password@123A"
  }
}' "$BASE_URL/users" | jq .
{
  "message": "Your account has been updated successfully.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "email": "user@example.com",
    "first_name": "User 1",
    "last_name": "Name 1",
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "unconfirmed_email": "test_updated@local.test",
    "updated_at": "2025-01-19T09:44:42.161Z",
    "username": "user1"
  }
}

# ---- 4 - Delete user's account ----
api -X DELETE "$BASE_URL/users" | jq .
{
  "message": "Bye! Your account has been successfully cancelled. We hope to see you again soon.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "email": "user@example.com",
    "first_name": "User 1",
    "last_name": "Name 1",
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:31:38.073Z",
    "username": "user1"
  }
}
