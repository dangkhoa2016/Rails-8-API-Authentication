# JWT Lifecycle
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](JWT_LIFECYCLE.vi.md)

This document explains the full lifecycle of a JWT within the system — from creation to revocation and cleanup from the database.

## Overview

```
[POST /users/sign_in]
        │
        ▼
  Devise authenticates email + password
        │
        ▼
  devise-jwt calls User#on_jwt_dispatch(token, payload)
  → stores token + payload in user.token_info (attr_accessor, in-memory)
        │
        ▼
  JWT returned in response header: Authorization: Bearer <token>
        │
        ▼
  Client stores token, sends it with every subsequent request:
  Authorization: Bearer <token>
        │
        ▼
  Warden::JWTAuth::Strategy.authenticate!
  → Decode token (verify signature + exp)
  → Check JTI in jwt_denylists (is it revoked?)
  → If valid: call JwtDenylist.jwt_revoked? → set user.token_info = { payload: ... }
        │
        ▼
  [DELETE /users/sign_out]
  → devise-jwt records JTI into jwt_denylists table
  → Token can no longer be used even if it hasn't expired
        │
        ▼
      [Scheduled cleanup]
      config/recurring.yml → CleanExpiredJwtDenylistsJob (every hour in production)
      → Deletes rows where exp < Time.current
```

---

## JWT Payload

Tokens are signed using the HS256 algorithm (devise-jwt default). The payload includes:

| Field | Meaning |
|---|---|
| `sub` | User ID (string) |
| `scp` | Scope — always `"user"` |
| `aud` | Audience — `nil` in current configuration |
| `iat` | Issued At — token creation timestamp (seconds) |
| `exp` | Expiration — expiration timestamp (seconds) |
| `jti` | JWT ID — random UUID used for revocation |

The current token duration is **3600 seconds (1 hour)**. This can be modified in `config/initializers/devise.rb` via `jwt.expiration_time`.

---

## Signing Key

Priority order for the signing key:

1. `Rails.application.credentials.devise_jwt_secret_key` (in encrypted credentials)
2. `ENV["DEVISE_JWT_SECRET_KEY"]` (environment variable)
3. `Rails.application.secret_key_base` (fallback)

> **Production Note:** It is recommended to set a separate `DEVISE_JWT_SECRET_KEY` to allow rotating JWT keys without regenerating the entire Rails master key. See `.env.sample` for setup instructions.

---

## Revocation — The `jwt_denylists` table

When a user signs out, the token's `jti` is recorded in the `jwt_denylists` table:

```
jwt_denylists
┌────────┬──────────────────────────────────────┬─────────────────────┐
│ id     │ jti                                  │ exp                 │
├────────┼──────────────────────────────────────┼─────────────────────┤
│ 1      │ 3f2e1a4b-...                         │ 2026-04-24 10:00:00 │
│ 2      │ 9c8d7e6f-...                         │ 2026-04-23 08:30:00 │
└────────┴──────────────────────────────────────┴─────────────────────┘
```

For every request with a JWT, `JwtDenylist.jwt_revoked?(payload, user)` checks if the `jti` exists in this table. If it does, the request is rejected, even if the token has not reached its `exp` time.

### Check current token status

```bash
# View the number of revoked JTIs
bin/rails runner 'puts JwtDenylist.count'

# View expired JTIs (ready for cleanup)
bin/rails runner 'puts JwtDenylist.expired_before.count'
```

---

## Cleanup — Denylist table maintenance

Rows in `jwt_denylists` have an `exp` field — when `exp < Time.current`, the token is already expired regardless of revocation and cannot be reused. These rows are safe to delete.

### Manual Execution

```bash
# Production / staging
RAILS_ENV=production bin/rails jwt_denylist:cleanup

# Development / test
bin/rails jwt_denylist:cleanup
```

### Automation (Recommended)

This repository already ships with a recurring Solid Queue schedule in `config/recurring.yml`:

| Environment | Job key | Class | Queue | Schedule |
|---|---|---|---|---|
| `production` | `clean_expired_jwt_denylists` | `CleanExpiredJwtDenylistsJob` | `background` | `every hour` |

If you prefer cron instead, you can still schedule `bin/rails jwt_denylist:cleanup` yourself.

---

## `GET /user/profile` with Faulty Tokens

This endpoint returns **token metadata even when authentication fails**. This behavior is intentional to allow the client to distinguish between different error scenarios:

| Scenario | Status | `user` | `token_info.expired` | `token_info.expired_in` |
|---|---|---|---|---|
| Valid Token | 200 | object | `false` | positive number |
| Expired Token | 422 | `null` | `true` | negative number |
| Revoked Token | 422 | `null` | `false` | positive number |
| Invalid Token (bad format) | 422 | — | — | — |

> A **revoked** token is different from an **expired** token: a revoked token is still within its `exp` duration, but its JTI has been blacklisted in `jwt_denylists`. If `expired: false` + `expired_in > 0` but you still receive a 422, the token is certainly revoked.

---

## Related Files

| File | Role |
|---|---|
| `app/models/jwt_denylist.rb` | Model storing revoked JTIs, provides `jwt_revoked?` and `delete_expired!` |
| `app/models/user.rb` | `on_jwt_dispatch` — callback receiving the newly created token |
| `app/controllers/users/sessions_controller.rb` | Sign out (records denylist), profile endpoint (reads token metadata) |
| `app/controllers/application_controller.rb` | `decode_token` — manual decoding when payload needs to be read from header |
| `config/initializers/devise.rb` | `jwt.secret`, `jwt.request_formats` |
| `config/initializers/devise_jwt.rb` | Patch `skip_trackable` for JWT strategy |
| `config/recurring.yml` | Production recurring schedule for `CleanExpiredJwtDenylistsJob` |
| `lib/tasks/jwt_denylist.rake` | Rake task `jwt_denylist:cleanup` |
