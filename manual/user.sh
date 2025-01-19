
# 1 - Sign In as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms

# 2 - Sign In as role: admin
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "admin@admin.admin",
    "password": "adminadmin"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU

# 3 - try to access /users as role: user
curl -X GET "http://localhost:4000/users" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 4 - try to access /users as role: admin
curl -X GET "http://localhost:4000/users" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
  | jq .
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
    "username": "",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-19T07:51:09.661Z"
  }
]

# 5 - try to access /users/1 as role: user
curl -X GET "http://localhost:4000/users/1" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 6 - try to access /users/1 as role: admin
curl -X GET "http://localhost:4000/users/1" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
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

# 7 - Try to access /users/2 as role: user
curl -X GET "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
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

# 8 - Try to access /users/2 as role: admin
curl -X GET "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
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

# 9 - Try to access /users/me as role: user
curl -X GET "http://localhost:4000/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "error": "Route not found"
}

# 10 - Try to access /users/me as role: admin
curl -X GET "http://localhost:4000/users/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
  | jq .
{
  "error": "Route not found"
}

# 11 - Try to access /users/100 as role: user
curl -X GET "http://localhost:4000/users/100" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 12 - Try to access /users/100 as role: admin
curl -X GET "http://localhost:4000/users/100" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
  | jq .
{
  "errors": "User not found"
}

# 13 - Try to create a new user as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "password": "password",
    "password_confirmation": "password"
  }
}' "http://localhost:4000/users/create" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "errors": "You must be an administrator to perform this action"
}

# 14 - Try to create a new user as role: admin
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "test1@local.test",
    "password": "password",
    "password_confirmation": "password"
  }
}' "http://localhost:4000/users/create" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
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

# 15 - Try to update user 2 as role: user
curl -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
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

# 16 - Try to update user 2 as role: admin
curl -X PUT -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user_update2@example.com",
    "password": "password1",
    "role": "admin"
  }
}' "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
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

# 17 - Try to delete user 2 as role: user
curl -X DELETE "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjY2LCJleHAiOjE3Mzg0ODYyNjYsImp0aSI6IjYyMDk0MjA2LWQ4YjMtNDUxYS1hY2YzLTI0MDBmNmVjZDIxOSJ9.l_Y5BcoeAV8vYWcxLk8tcKiWpYRgAGFFw-JqM4pUyms" \
  | jq .
{
  "message": "User [user@example.com] with id [2] has been deleted"
}

# 18 - Try to delete user 2 as role: admin
curl -X DELETE "http://localhost:4000/users/2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM4NDgyNjg0LCJleHAiOjE3Mzg0ODYyODQsImp0aSI6IjQxZDA1NmU1LTM5NWQtNDYwOS04ZDNmLTkwNDkxZDI2NDc0ZCJ9.14j0iDRsGF2YpO1WrAa_49srpK0Y77TWp0V3wURSJMU" \
  | jq .
{
  "errors": "User not found"
}
