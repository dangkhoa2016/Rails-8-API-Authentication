# =============================================================================
#  Admin User Management & Role-Based Access Control
# =============================================================================
#  Source config first:
#    source manual/config.sh
#
#  These tests require two tokens. Run the sign-in commands below to get them:
#    export USER_TOKEN="<token-from-user-sign-in>"
#    export ADMIN_TOKEN="<token-from-admin-sign-in>"
# =============================================================================

# ---- 1 - Sign In as role: user ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}' "$BASE_URL/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms

# ---- 2 - Sign In as role: admin ----
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "admin@admin.admin",
    "password": "adminadmin"
  }
}' "$BASE_URL/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU

# ---- 3 - Get /user/profile as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/user/profile" | jq .

# ---- 4 - Get /user/profile as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/user/profile" | jq .

# ---- 5 - Get /user/me as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/user/me" | jq .

# ---- 6 - Get /user/me as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/user/me" | jq .

# ---- 7 - Get /user/whoami as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/user/whoami" | jq .

# ---- 8 - Get /user/whoami as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/user/whoami" | jq .

# ---- 9 - try to access /users as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users" | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# ---- 10 - try to access /users as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users" | jq .
[
  {
    "id": 1,
    "email": "admin@admin.admin",
    "username": "admin",
    "first_name": "Admin",
    "last_name": "Master",
    "avatar": null,
    "role": "admin",
    "created_at": "2025-01-17T11:03:25.018Z",
    "updated_at": "2025-02-01T14:29:59.900Z"
  },
  {
    "id": 2,
    "email": "user@example.com",
    "username": "user1",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-19T07:51:09.661Z"
  }
]

# ---- 11 - try to access /users/1 as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users/1" | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# ---- 12 - try to access /users/1 as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users/1" | jq .
{
  "id": 1,
  "email": "admin@admin.admin",
  "username": "admin",
  "first_name": "Admin",
  "last_name": "Master",
  "avatar": null,
  "role": "admin",
  "created_at": "2025-01-17T11:03:25.018Z",
  "updated_at": "2025-01-19T07:50:00.393Z"
}

# ---- 13 - Try to access /users/2 as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users/2" | jq .
{
  "id": 2,
  "email": "user@example.com",
  "username": "user1",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T07:51:09.661Z"
}

# ---- 14 - Try to access /users/2 as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users/2" | jq .
{
  "id": 2,
  "email": "user@example.com",
  "username": "user1",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T07:51:09.661Z"
}

# ---- 15 - Try to access /users/me as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users/me" | jq .
{
  "error": "Route not found"
}

# ---- 16 - Try to access /users/me as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users/me" | jq .
{
  "error": "Route not found"
}

# ---- 17 - Try to access /users/100 as role: user ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users/100" | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# ---- 18 - Try to access /users/100 as role: admin ----
curl -s -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users/100" | jq .
{
  "errors": "User not found"
}

# ---- 19 - Try to create a new user as role: user ----
curl -s -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "username": "test1_user",
    "password": "password",
    "password_confirmation": "password"
  }
}' "$BASE_URL/users/create" \
  -H "Authorization: Bearer $USER_TOKEN" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# ---- 20 - Try to create a new user as role: admin ----
curl -s -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "username": "test1_user",
    "password": "password",
    "password_confirmation": "password"
  }
}' "$BASE_URL/users/create" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq .
{
  "id": 4,
  "email": "test1@local.test",
  "username": "test1_user",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-19T08:22:14.332Z",
  "updated_at": "2025-01-19T08:22:14.332Z"
}

# ---- 21 - Try to update user 2 as role: user ----
curl -s -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "$BASE_URL/users/2" \
  -H "Authorization: Bearer $USER_TOKEN" \
  | jq .
{
  "email": "user@example.com",
  "id": 2,
  "username": "user1",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user", # don't allow to update role
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T08:24:58.305Z",
  "unconfirmed_email": "user_update@example.com"
}

# ---- 22 - Try to update user 2 as role: admin ----
curl -s -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update2@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "$BASE_URL/users/2" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  | jq .
{
  "email": "user@example.com",
  "id": 2,
  "username": "user1",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "admin", # admin can update role
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T08:46:41.150Z",
  "unconfirmed_email": "user_update@example.com"
}

# ---- 23 - Try to delete user 2 as role: user ----
curl -s -X DELETE -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER_TOKEN" \
  "$BASE_URL/users/2" | jq .
{
  "message": "User [user@example.com] with id [2] has been deleted"
}

# ---- 24 - Try to delete user 2 as role: admin ----
curl -s -X DELETE -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  "$BASE_URL/users/2" | jq .
{
  "errors": "User not found"
}
