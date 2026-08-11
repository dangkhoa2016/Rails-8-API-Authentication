# 1 - Sign Up
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user1@example.com",
    "password": "password@123A",
    "password_confirmation": "password@123A"
  }
}' "http://localhost:4000/users" | jq .
# http://localhost:4000/users/confirmation?confirmation_token=MjRUbw87mVdKk8jCRH8h
{
  "message": "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account.",
  "user": {
    "id": 2,
    "active": true,
    "avatar": null,
    "created_at": "2025-01-16T17:32:30.315Z",
    "email": "user@example.com",
    "first_name": "",
    "last_name": "",
    "role": "user",
    "updated_at": "2025-01-16T17:32:30.315Z",
    "username": ""
  }
}


# 2 - Sign In
curl -X POST -H "Content-Type: application/json" -d '{
  "email": "user@example.com",
  "password": "password@123A"
}' "http://localhost:4000/users/sign_in" | jq .
{
  "error": "You need to sign in or sign up before continuing."
}

curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "http://localhost:4000/users/sign_in" | jq .
{
  "error": "You have to confirm your email address before continuing."
}

# 3 - Confirm Email
curl -X GET "http://localhost:4000/users/confirmation?confirmation_token=SgoszqA3BsrLpyNYqvem" -i
{
  "id": 2,
  "active": true,
  "email": "user@example.com",
  "username": "",
  "first_name": "",
  "last_name": "",
  "avatar": null,
  "role": "user",
  "created_at": "2025-01-16T17:32:30.315Z",
  "updated_at": "2025-01-16T17:40:50.662Z"
}

# 4 - Sign In Again
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password@123A"
  }
}' "http://localhost:4000/users/sign_in" -i

HTTP/1.1 200 OK
x-frame-options: SAMEORIGIN
x-xss-protection: 0
x-content-type-options: nosniff
x-permitted-cross-domain-policies: none
referrer-policy: strict-origin-when-cross-origin
location: /
content-type: application/json; charset=utf-8
authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTAyODUwLCJleHAiOjE3MzcxMDY0NTAsImp0aSI6IjQ1OWEzMzhmLTA3MzgtNDJkYi04ODZmLTc5ZjM1MTliODc5OCJ9.7so7q1Mo_sJku4H_wpseN-fw4l8gigqU64zOpu4UmZc
set-cookie: refresh_token=e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a; path=/; HttpOnly; SameSite=Lax; expires=Sat, 31 Jan 2026 08:34:10 GMT
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
    "username": ""
  },
  "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTAyODUwLCJleHAiOjE3MzcxMDY0NTAsImp0aSI6IjQ1OWEzMzhmLTA3MzgtNDJkYi04ODZmLTc5ZjM1MTliODc5OCJ9.7so7q1Mo_sJku4H_wpseN-fw4l8gigqU64zOpu4UmZc",
  "refresh_token": "e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a"
}


# Sign In with invalid password
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com1",
    "password": "password@123A1"
  }
}' "http://localhost:4000/users/sign_in" -i
{"error":"Invalid Email or password."}

# 5 - Sign Out: Valid Token
curl -X DELETE -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTAyODUwLCJleHAiOjE3MzcxMDY0NTAsImp0aSI6IjQ1OWEzMzhmLTA3MzgtNDJkYi04ODZmLTc5ZjM1MTliODc5OCJ9.7so7q1Mo_sJku4H_wpseN-fw4l8gigqU64zOpu4UmZc" \
"http://localhost:4000/users/sign_out" | jq .
{
  "message": "Your account: user@example.com has been signed out successfully."
}

# 5 - Sign Out: Invalid Token
curl -X DELETE -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer test" \
"http://localhost:4000/users/sign_out" -i
{"error":"Invalid token"}

# 6 - Get Signed In User JSON Data
curl -X GET -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw" \
"http://localhost:4000/user/profile" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# 6 - Get Signed In User JSON Data
curl -X GET -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw" \
"http://localhost:4000/user/me" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# 6 - Get Signed In User JSON Data
curl -X GET -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw" \
"http://localhost:4000/user/whoami" | jq .
{
  "user": {
    "id": 2,
    "active": true,
    "email": "user@example.com",
    "username": "",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-17T12:36:46.006Z",
    "updated_at": "2025-01-17T13:59:07.175Z"
  },
  "token_info": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MjYxNTk3LCJleHAiOjE3MzcyNjUxOTcsImp0aSI6IjNlNGNlYmZmLTRkZGMtNGMzNy05MTI1LTBkNjdhMWM2ODAxZSJ9.5lHosClrKK6fK52ONzhxFR-uTt5Lc5mYPSwSkLs31gw",
    "user_id": 2,
    "expired_at": "2025-01-17T14:41:53.000+00:00",
    "expired_in": 2566,
    "expired": false,
    "jti": "94685384-da89-4f1a-b849-114c4c7ad4f9"
  }
}

# 7 - Get Signed In User JSON Data: Invalid Token
curl -X GET -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTIxMzEzLCJleHAiOjE3MzcxMjQ5MTMsImp0aSI6Ijk0Njg1Mzg0LWRhODktNGYxYS1iODQ5LTExNGM0YzdhZDRmOSJ9.J1mlfI4_aGwS1h2buVXolYq7vIQGiDtnwBN9_QtVnDk" \
"http://localhost:4000/user/profile" | jq .
{
  "error": "Invalid token"
}

# 7 - Get Signed In User JSON Data: Expired Token
curl -X GET -H "Content-Type: application/json" -H "${JWT_AUTH_HEADER:-Authorization}: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTAyODUwLCJleHAiOjE3MzcxMDY0NTAsImp0aSI6IjQ1OWEzMzhmLTA3MzgtNDJkYi04ODZmLTc5ZjM1MTliODc5OCJ9.7so7q1Mo_sJku4H_wpseN-fw4l8gigqU64zOpu4UmZc" \
"http://localhost:4000/user/profile" | jq .
{
  "user": null,
  "token_info": {
    "token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTAyODUwLCJleHAiOjE3MzcxMDY0NTAsImp0aSI6IjQ1OWEzMzhmLTA3MzgtNDJkYi04ODZmLTc5ZjM1MTliODc5OCJ9.7so7q1Mo_sJku4H_wpseN-fw4l8gigqU64zOpu4UmZc",
    "user_id": "2",
    "expired_at": "2025-01-17T09:34:10.000+00:00",
    "expired_in": -16482,
    "expired": true,
    "jti": "459a338f-0738-42db-886f-79f3519b8798"
  }
}

# 8 - Refresh Access Token (rotation)
# The refresh token is returned at sign-in (body field "refresh_token") and as
# an HttpOnly cookie. Use any ONE of the three transports below.

# 8a - Refresh via cookie (already set by sign-in)
curl -X POST -H "Content-Type: application/json" \
  -b "refresh_token=e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a" \
  "http://localhost:4000/users/tokens/refresh" -i

# 8b - Refresh via X-Refresh-Token header
curl -X POST -H "Content-Type: application/json" \
  -H "X-Refresh-Token: e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a" \
  "http://localhost:4000/users/tokens/refresh" | jq .

# 8c - Refresh via JSON body
curl -X POST -H "Content-Type: application/json" -d '{
  "refresh_token": "e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a"
}' "http://localhost:4000/users/tokens/refresh" | jq .

# Response (each refresh rotates the refresh token and returns a fresh access token):
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
    "username": ""
  },
  "access_token": "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3MTY5OTk5LCJleHAiOjE3MzcxNzM1OTksImp0aSI6IjEwZmNmNjljLWQ5YjAtNGNjMi1hZDAwLTQ2ZDU4Y2M3Y2VjNyJ9.new-signature-here",
  "refresh_token": "6a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
}

# 8d - Reuse of an already-rotated token is detected -> whole family is revoked
curl -X POST -H "Content-Type: application/json" -H "X-Refresh-Token: e549695f690decd11555422ea86d7237a84bb64d3d07f7458c977528f55de30a" \
  "http://localhost:4000/users/tokens/refresh" -i
{
  "error": "Security alert: Refresh token reuse detected. All sessions revoked."
}
