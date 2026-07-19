# =============================================================================
#  Password Management
# =============================================================================
#  Source config first:
#    source manual/config.sh
#    export TEST_JWT_TOKEN="<token>"
# =============================================================================

# ---- 1 - Sign In as role: user (to obtain token) ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "$BASE_URL/users/sign_in" -i
# ${TEST_JWT_TOKEN:-<your-jwt-token-here>}
# Response:
{
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "created_at": "2025-01-19T08:01:33.378Z",
    "email": "user@example.com",
    "first_name": "User",
    "last_name": "Name",
    "role": "user",
    "updated_at": "2025-01-19T12:27:19.898Z",
    "username": "user"
  },
  "token": "${TEST_JWT_TOKEN:-<your-jwt-token-here>}",
  "refresh_token": "<your-refresh-token>"
}

# ---- 2 - Get user's password edit form ----
api -X GET "$BASE_URL/users/password/new" | jq .

# ---- 3 - Create a password reset request ----
api -X POST -d '{
  "user": {
    "email": "user@example.com"
  }
}' "$BASE_URL/users/password" -i
{
  "message": "You will receive an email with instructions on how to reset your password in a few minutes.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "email": "user@example.com",
    "first_name": "User",
    "last_name": "Name",
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:27:19.898Z",
    "username": "user"
  }
}

# ---- 3 - Update user's password ----
api -X PUT -d '{
  "user": {
    "reset_password_token": "FN9-TyuDrzB7VUXPLoM5",
    "password": "password@123A",
    "new_password": "password@123A1",
    "new_password_confirmation": "password@123A1"
  }
}' "$BASE_URL/users/password" | jq .
{
  "message": "Your password has been changed successfully.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "email": "user@example.com",
    "first_name": "User",
    "last_name": "Name",
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:31:38.073Z",
    "username": "user"
  }
}
