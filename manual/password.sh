
# 1 - Sign In as role: user
curl -X POST -H "Content-Type: application/json" -d '{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}' "http://localhost:4000/users/sign_in" -i
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c

# 2 - Get user's password edit form
curl -X GET -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  "http://localhost:4000/users/password/new" | jq .

# 3 - Create a password reset request
curl -X POST -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  "http://localhost:4000/users/password" \
  -d '{
      "user": {
        "email": "user@example.com"
      }
    }' -i
{
  "message": "You will receive an email with instructions on how to reset your password in a few minutes.",
  "user": {
    "id": 2,
    "email": "user@example.com",
    "username": "user",
    "first_name": "User",
    "last_name": "Name",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:27:19.898Z"
  }
}

# 3 - Update user's password
curl -X PUT -H "Content-Type: application/json" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIyIiwic2NwIjoidXNlciIsImF1ZCI6bnVsbCwiaWF0IjoxNzM3Mjg4OTE0LCJleHAiOjE3MzcyOTI1MTQsImp0aSI6ImU4NDI0NWUzLTJlNzItNGRmZi1hN2NlLTc5NjYyOGJhNzNkYSJ9.Eg6ANKg_H5ZdOlUOBFMIS5xtzVyo5JKcQD7GfQZGv_c" \
  "http://localhost:4000/users/password" \
  -d '{
      "user": {
        "reset_password_token": "FN9-TyuDrzB7VUXPLoM5",
        "password": "password",
        "new_password": "password1",
        "new_password_confirmation": "password1"
      }
    }' | jq .
{
  "message": "Your password has been changed successfully.",
  "user": {
    "email": "user@example.com",
    "id": 2,
    "username": "user",
    "first_name": "User",
    "last_name": "Name",
    "avatar": null,
    "role": "user",
    "created_at": "2025-01-19T08:01:33.378Z",
    "updated_at": "2025-01-19T12:31:38.073Z"
  }
}
