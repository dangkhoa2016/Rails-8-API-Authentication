# Implementation Tracker

Track the implementation status of authentication and user-management features.

## Authentication

| Feature | Scope | Endpoint | Status |
|---------|-------|----------|--------|
| Registration | Public | `POST /users` | Done |
| Email confirmation | Public | `GET /users/confirmation` | Done |
| Sign in | Public | `POST /users/sign_in` | Done |
| Sign out | Authenticated | `DELETE /users/sign_out` | Done |
| JWT revocation on logout | Authenticated | Denylist model + job | Done |
| Password reset request | Public | `POST /users/password` | Done |
| Password reset confirm | Public | `PUT/PATCH /users/password` | Done |

## Profile

| Feature | Scope | Endpoint | Status |
|---------|-------|----------|--------|
| View profile | Authenticated | `GET /user/profile` | Done |
| Profile alias | Authenticated | `GET /user/me` | Done |
| Profile alias | Authenticated | `GET /user/whoami` | Done |

## Account Management

| Feature | Scope | Endpoint | Status |
|---------|-------|----------|--------|
| Update account | Self-service | `PUT/PATCH /users` | Done |
| Delete account | Self-service | `DELETE /users` | Done |

## Admin

| Feature | Scope | Endpoint | Status |
|---------|-------|----------|--------|
| List users | Admin only | `GET /users` | Done |
| Create user | Admin only | `POST /users/create` | Done |
| View user | Admin or self | `GET /users/:id` | Done |
| Update user | Admin or self | `PUT /users/:id` | Done |
| Delete user | Admin or self | `DELETE /users/:id` | Done |

## Infrastructure

| Feature | Status |
|---------|--------|
| Rate limiting (Rack::Attack) | Done |
| CORS configuration | Done |
| Docker deployment | Done |
| Kamal deployment | Done |
| Health check (`/up`) | Done |
| Catch-all 404 route | Done |
| Environment validation at boot | Done |

## CI Pipeline

| Job | Tools | Status |
|-----|-------|--------|
| Lint | RuboCop | Done |
| Security | Brakeman | Done |
| Audit | bundler-audit | Done |
| Test | Rails test suite (72 tests) | Done |
| Auth regression | Auth-specific test files | Done |
| Coverage | SimpleCov + badge generation | Done |
