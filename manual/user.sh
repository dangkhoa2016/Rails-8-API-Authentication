
# 1 - Sign In as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10

# 2 - Sign In as role: admin
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "admin@admin.admin",
    "password": "adminadmin"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s

# 3 - try to access /users/1 as role: user
curl -X GET "http://localhost:4000/users/1" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 4 - try to access /users/1 as role: admin
curl -X GET "http://localhost:4000/users/1" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
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

# 5 - Try to access /users/2 as role: user
curl -X GET "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "id": 2,
  "email": "user@example.com",
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T07:51:09.661Z"
}

# 6 - Try to access /users/2 as role: admin
curl -X GET "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "id": 2,
  "email": "user@example.com",
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T07:51:09.661Z"
}

# 7 - Try to access /users/me as role: user
curl -X GET "http://localhost:4000/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "error": "Route not found"
}

# 8 - Try to access /users/me as role: admin
curl -X GET "http://localhost:4000/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "error": "Route not found"
}

# 9 - Try to access /users/100 as role: user
curl -X GET "http://localhost:4000/users/100" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 10 - Try to access /users/100 as role: admin
curl -X GET "http://localhost:4000/users/100" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "errors": "User not found"
}

# 11 - Try to create a new user as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "password": "password",
    "password_confirmation": "password"
  }
}' "http://localhost:4000/users/create" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 12 - Try to create a new user as role: admin
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "password": "password",
    "password_confirmation": "password"
  }
}' "http://localhost:4000/users/create" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "id": 4,
  "email": "test1@local.test",
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-19T08:22:14.332Z",
  "updated_at": "2025-01-19T08:22:14.332Z"
}

# 13 - Try to update user 2 as role: user
curl -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "email": "user@example.com",
  "id": 2,
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user", # don't allow to update role
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T08:24:58.305Z",
  "unconfirmed_email": "user_update@example.com"
}

# 14 - Try to update user 2 as role: admin
curl -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update2@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "email": "user@example.com",
  "id": 2,
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "admin", # admin can update role
  "created_at": "2025-01-17T12:36:46.006Z",
  "updated_at": "2025-01-19T08:46:41.150Z",
  "unconfirmed_email": "user_update@example.com"
}

# 15 - Try to delete user 2 as role: user
curl -X DELETE "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTAzLCJleHAiOjE3MzcyNzYxMDMsImp0aSI6ImU4MmJjNjlmLTg2NTYtNGExZi1hODZjLTIwZGM3NDFmNWU3MyJ9.VJPZWp0gvQwgwFVVaNyP_kyuDf7Ka4df2f86zAX2n10" \
  | jq .
{
  "message": "User [user@example.com] with id [2] has been deleted"
}

# 16 - Try to delete user 2 as role: admin
curl -X DELETE "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjcyNTgzLCJleHAiOjE3MzcyNzYxODMsImp0aSI6ImNlYzE0ZmQ3LTdmNTctNDhjNi1iM2U4LTdlMjkxNjEyYmQ4MyJ9.wkkcebgFpo9djuOi4vK7RNimLCw5ujHvQ3YadT6DK0s" \
  | jq .
{
  "errors": "User not found"
}
