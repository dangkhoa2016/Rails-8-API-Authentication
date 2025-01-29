

# Rails v8 API Authentication with JWT

This is a simple Rails v8 API server with JWT-based authentication. The server handles user registration, login, profile updates, and user management with role-based access.


## Features

- **User Registration:**
  - Fields: `email`, `password`, `username`
  - Validation: `email` and `username` are unique, `password` is required.

- **User Login:**
  - Fields: `username`, `password`
  - Returns a JWT token upon successful login.

- **User Logout:**
  - Invalidates the JWT token on the client side.

- **Get User Info:**
  - Retrieves information for the logged-in user.
  - Admins can also view information for other users.

- **Update User Info (Basic):**
  - Allows a user to update their profile information (e.g., email, username).

- **Update User Role (Admin Only):**
  - Admins can update the `role` of a user (e.g., admin, regular user).

- **Delete User (Self-Delete):**
  - A user can delete their own account.

- **Delete User (Admin Only):**
  - Admins can delete any user.


## Technologies Used

- **Ruby on Rails v8**: Web framework.
- **SQLite/PostgreSQL**: Database (SQLite used in the example).
- **devise**: Flexible authentication solution for Rails with Warden.
- **devise JWT**: ForJWT token authentication with devise and rails.

## Setup

### 1. Install Rails

If you don’t have Rails 8 installed yet, run:
```bash
gem install rails -v 8
```

## Installation

1. Clone the repository:
    ```bash
    git clone <repository-url>
    cd <repository-folder>
    ```

2. Install dependencies:
    ```bash
    bundle install
    ```

3. Create a `.env` file at the root of your project for environment variables:
    ```env
    RAILS_LOG_TO_STDOUT=true
    RAILS_ENV=development
    PORT=4000
    RAILS_MAX_THREADS=1
    PORT=3000
    ```

## API Endpoints

### 1. **POST /register**
- Registers a new user.
- **Body**:
    ```json
    {
      "email": "user@example.com",
      "password": "password123",
      "username": "user123"
    }
    ```
- **Response**:
    ```json
    {
      "message": "User created successfully."
    }
    ```

### 2. **POST /login**
- Logs in an existing user and returns a JWT token.
- **Body**:
    ```json
    {
      "username": "user123",
      "password": "password123"
    }
    ```
- **Response**:
    ```json
    {
      "token": "<jwt_token>",
      "message": "Login successful",
      "user": {
        "username": "user123",
        ...
      }
    }
    ```

### 3. **POST /logout**
- Logs out the user by invalidating their token.
- **Response**:
    ```json
    {
      "message": "Logout successful."
    }
    ```

### 4. **GET /user**
- Retrieves the logged-in user's information.
- **Headers**:
    - `Authorization`: `Bearer <jwt_token>`
- **Response**:
    ```json
    {
      "username": "user123",
      "email": "user@example.com",
      "role": "user"
    }
    ```

### 5. **PUT /user**
- Updates basic information of the logged-in user (email or username).
- **Headers**:
    - `Authorization`: `Bearer <jwt_token>`
- **Body**:
    ```json
    {
      "email": "new_email@example.com",
      "username": "new_username"
    }
    ```
- **Response**:
    ```json
    {
      "message": "User information updated successfully."
    }
    ```

### 6. **DELETE /user**
- Deletes the logged-in user account.
- **Headers**:
    - `Authorization`: `Bearer <jwt_token>`
- **Response**:
    ```json
    {
      "message": "Bye! Your account has been successfully cancelled. We hope to see you again soon."
    }
    ```

### 7. **DELETE /user/2**
- Deletes a user account (only accessible by admin).
- **Headers**:
    - `Authorization`: `Bearer <jwt_token>`
- **Body**:
    ```json
    {
    }
    ```
- **Response**:
    ```json
    {
      "message": "User deleted successfully."
    }
    ```

## Example Usage

1. Register a user:
    ```bash
    curl -X POST http://localhost:4000/users/register -H "Content-Type: application/json" -d '{"email": "user@example.com", "password": "password123", "username": "user123"}'
    ```

2. Log in to get the JWT token:
    ```bash
    curl -X POST http://localhost:4000/users/login -H "Content-Type: application/json" -d '{"username": "user123", "password": "password123"}'
    ```

3. Get user information:
    ```bash
    curl -X GET http://localhost:4000/user/me -H "Authorization: Bearer <jwt_token>"
    ```

for more information, please check the [registration.sh](./manual/registration.sh), [session.sh](./manual/session.sh) and [user.sh](./manual/user.sh) file.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

