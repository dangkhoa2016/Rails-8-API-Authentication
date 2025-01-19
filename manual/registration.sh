# 1 - Sign Up
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password",
    "password_confirmation": "password"
  }
}' "http://localhost:4000/users" | jq .
{
  "message": "A message with a confirmation link has been sent to your email address. Please follow the link to activate your account.",
  "user": {
    "id": 2,
    "email": "user@example.com",
    "username": "",
    "first_name": "",
    "last_name": "",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T13:27:43.182Z",
    "updated_at": "2025-01-19T13:27:43.182Z"
  }
}
# http://localhost:4000/users/confirmation?confirmation_token=MjRUbw87mVdKk8jCRH8h

# 1 - Sign In as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c

# 2 - Get user's profile edit form
curl -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  "http://localhost:4000/users/edit" | jq .

# 2 - Update user's profile
curl -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  -d '{
    "user": {
      "username": "user1",
      "first_name": "User 1",
      "last_name": "Name 1",
      "current_password": "password"
    }
  }' "http://localhost:4000/users/3" | jq .
  | jq .
{
  "message": "Your account has been updated successfully.",
  "user": {
    "first_name": "User 1",
    "last_name": "Name 1",
    "username": "user1",
    "email": "user@example.com",
    "id": 2,
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T09:33:01.862Z"
  }
}

# 3 - Update user's email
curl -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  -d '{
    "user": {
      "email": "test_updated@local.test",
      "current_password": "password"
    }
  }' "http://localhost:4000/users" | jq .
{
  "message": "Your account has been updated successfully.",
  "user": {
    "email": "user@example.com",
    "id": 2,
    "username": "user1",
    "first_name": "User 1",
    "last_name": "Name 1",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T09:44:42.161Z",
    "unconfirmed_email": "test_updated@local.test"
  }
}

# 4 - Delete user's account
curl -X DELETE -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  "http://localhost:4000/users" | jq .
{
  "message": "Bye! Your account has been successfully cancelled. We hope to see you again soon.",
  "user": {
    "id": 2,
    "email": "user@example.com",
    "username": "user1",
    "first_name": "User 1",
    "last_name": "Name 1",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:31:38.073Z"
  }
}
