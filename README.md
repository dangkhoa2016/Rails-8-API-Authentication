# Rails 8 API Authentication with JWT

[![Ruby 3.4.7](https://img.shields.io/badge/Ruby-3.4.7-red?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails 8.1.3](https://img.shields.io/badge/Rails-8.1.3-CC0000?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

This project is a Rails 8 API authentication service built with Devise and JWT. It supports registration, email confirmation, sign in, sign out, profile lookup, and user-management operations with admin-only access controls.

## Features

- User registration with email confirmation.
- JWT-based sign in and sign out with token revocation via denylist.
- Profile lookup with token metadata via `/user/profile` and compatibility aliases `/user/me`, `/user/whoami`.
- Self-service account update and account deletion.
- Admin-only user listing, user creation, role updates, and user deletion.
- Rate limiting on sign-in, registration, and password-reset endpoints.
- JWT denylist cleanup via job/task support.
- Docker + Kamal deployment scaffolding with a health check endpoint.
- CI with Brakeman, RuboCop, the full Rails test suite, and a dedicated auth regression job.
- SSRF protection: blocks loopback, private, and link-local addresses, including IPv6 `fe80::/10`.

## Technologies Used

- Rails 8
- Devise
- devise-jwt
- SQLite
- Docker + Kamal deployment scaffolding

## Quick Start

1. Install dependencies and prepare the database.

```bash
bin/setup
```

2. Start the application.

```bash
bin/dev
```

3. Call the API on `http://localhost:3000` by default. If you set `PORT` in your shell or `.env`, use that value instead.

4. Use the snippets in `manual/` as copy/paste references for auth and user-management requests:

- `manual/registration.sh`
- `manual/session.sh`
- `manual/password.sh`
- `manual/user.sh`

## Local Auth Quick Start

This flow is intended for a clean local checkout and matches the routes covered by the auth integration tests.

1. Start the app with `bin/dev` and keep it running on `http://localhost:3000` unless you have overridden `PORT`.

2. Register a new user in a separate terminal.

```bash
curl -sS -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "username": "user1",
      "password": "password",
      "password_confirmation": "password"
    }
  }' | jq .
```

3. Fetch the confirmation token from the local database.

```bash
bin/rails runner 'puts User.find_by!(email: "user@example.com").confirmation_token'
```

4. Confirm the account.

```bash
curl -sS "http://localhost:3000/users/confirmation?confirmation_token=<token>" | jq .
```

5. Sign in and capture the JWT from the `Authorization` response header.

```bash
TOKEN=$(curl -is -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password"
    }
  }' | sed -n 's/^authorization: Bearer //p' | tr -d '\r')
```

6. Read the primary profile endpoint with that JWT.

```bash
curl -sS http://localhost:3000/user/profile \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

7. Sign out and revoke the token.

```bash
curl -sS -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

8. Optionally inspect the broader request references in `manual/session.sh`, `manual/registration.sh`, `manual/password.sh`, and `manual/user.sh` for invalid-token, expired-token, password-reset, and admin/user-management examples.

## Environment

Copy `.env.sample` to `.env` for local development:

```bash
cp .env.sample .env
```

Minimum required settings for local development:

```env
RAILS_ENV=development
RAILS_LOG_TO_STDOUT=true
PORT=4000
RAILS_MAX_THREADS=3
```

If you do not set `PORT`, `bin/dev` boots on `3000` locally. The shipped `.env.sample` sets `PORT=4000`, so copying it unchanged moves local development to `http://localhost:4000`. The full variable reference — including production secrets, Puma concurrency, mailer, admin seed, CORS, and the manual JWT token slot — is documented in `.env.sample`.

For browser clients running on a different origin, the default CORS config allows requests from `CORS_ALLOWED_ORIGINS` but does **not** expose the `Authorization` response header. If your frontend needs to read the JWT from the sign-in response, update `config/initializers/cors.rb` to expose that header explicitly.

## Code Coverage

Generate a coverage report locally with SimpleCov by running the test suite with `COVERAGE=1`:

```bash
COVERAGE=1 bin/rails test
```

When `COVERAGE=1` is set, the test suite runs without Rails parallel workers so the SimpleCov report stays accurate.

The report is written to `public/coverage`. While the Rails server is running in development, open `http://localhost:3000/coverage` to view the latest generated report. This development-only endpoint redirects to the static HTML report.

Internally, the app redirects `/coverage` to `/coverage/` before the static file server handles the request. The trailing slash matters because the generated SimpleCov HTML references assets with relative paths such as `./assets/...`.

## Current Route Contract

The route contract below reflects `config/routes.rb` and the current controller implementation.

### Authentication Routes

| Method | Path | Purpose |
| --- | --- | --- |
| POST | `/users` | Register a new account |
| POST | `/users/sign_in` | Sign in and receive JWT in the `Authorization` response header |
| DELETE | `/users/sign_out` | Sign out and revoke the current token |
| GET | `/users/confirmation` | Confirm email via Devise confirmable flow |
| POST | `/users/password` | Send password reset instructions |
| PUT/PATCH | `/users/password` | Reset password with a token |
| PUT/PATCH | `/users` | Update the current signed-in account |
| DELETE | `/users` | Delete the current signed-in account |

### Profile Routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/user/profile` | Primary profile endpoint |
| GET | `/user/me` | Compatibility alias |
| GET | `/user/whoami` | Compatibility alias |

All three profile routes hit the same controller action and return the same payload shape.

### Admin and User Management Routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/users` | List users, admin only |
| POST | `/users/create` | Create a user as admin |
| GET | `/users/:id` | View a user; admin or self |
| PUT | `/users/:id` | Update a user; admin or self |
| DELETE | `/users/:id` | Delete a user; admin or self |

### Utility Routes

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/` | Root welcome endpoint |
| GET | `/home` | Welcome endpoint alias |
| GET | `/up` | Health check for uptime/load balancers |

## Request Format Notes

Devise endpoints expect payloads nested under the `user` key.

Example sign-up request:

```json
{
  "user": {
    "email": "user@example.com",
    "username": "user1",
    "password": "password",
    "password_confirmation": "password"
  }
}
```

Example sign-in request:

```json
{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}
```

Self-service account updates on `PUT /users` or `PATCH /users` must include `current_password`. Admin-managed updates on `PUT /users/:id` go through `UsersController` and do not require `current_password`.

Profile lookup also has two different unauthenticated failure modes:

- Missing, expired, or revoked token: `422` with `user: null` plus `token_info`
- Malformed token: `422` with `{ "error": "Invalid token" }`

## Example Flow

### 1. Register

```bash
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "username": "user1",
      "password": "password",
      "password_confirmation": "password"
    }
  }'
```

### 2. Confirm Email

Use the confirmation link generated by Devise, for example:

```bash
curl "http://localhost:3000/users/confirmation?confirmation_token=<token>"
```

### 3. Sign In

```bash
curl -i -X POST http://localhost:3000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password"
    }
  }'
```

The JWT is returned in the `Authorization` response header.

### 4. Read Profile

```bash
curl http://localhost:3000/user/profile \
  -H "Authorization: Bearer <jwt_token>"
```

`/user/me` and `/user/whoami` are compatibility aliases for the same response.

### 5. Sign Out

```bash
curl -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer <jwt_token>"
```

## Manual References

The files below currently reflect the implementation more accurately than the original README examples, but they include sample output blocks and should be treated as reference notes rather than shell scripts you execute verbatim:

- [manual/registration.sh](./manual/registration.sh)
- [manual/session.sh](./manual/session.sh)
- [manual/password.sh](./manual/password.sh)
- [manual/user.sh](./manual/user.sh)

## Additional Documentation

The `docs/` folder contains deeper implementation and operations notes for the current authentication stack:

- [docs/ACCESS_CONTROL.md](./docs/ACCESS_CONTROL.md) - Authorization rules for guest, self-service, and admin flows
- [docs/JWT_LIFECYCLE.md](./docs/JWT_LIFECYCLE.md) - JWT issuance, profile-token metadata, revocation, and cleanup
- [docs/RATE_LIMITING.md](./docs/RATE_LIMITING.md) - Current Rack::Attack thresholds, error responses, and proxy considerations
- [docs/DEPLOYMENT.md](./docs/DEPLOYMENT.md) - Kamal, Docker, environment variables, health checks, and SQLite persistence

## Improvement Planning

Project improvement artifacts are tracked in:

- [manual/PROJECT_IMPROVEMENT_REPORT.md](./manual/PROJECT_IMPROVEMENT_REPORT.md)
- [manual/IMPLEMENTATION_TRACKER.md](./manual/IMPLEMENTATION_TRACKER.md)

## License

This project is licensed under the MIT License.

