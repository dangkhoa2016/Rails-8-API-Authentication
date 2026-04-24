# Access Control Reference
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](ACCESS_CONTROL.vi.md)

This document describes the differences in access rights among three types of users in the system: **Guest**, **Regular User**, and **Admin**.

## Core Concepts

- **Role** is stored in the `role` column of the `users` table, type `string`, defaulting to `"user"`.
- Two valid values: `"user"` and `"admin"` (declared via `enum :role` in the `User` model).
- Authentication is based on **JWT** (Devise + devise-jwt). The token is sent in the header `Authorization: Bearer <token>`.
- Email must be **confirmed** before a successful login can occur.

---

## Access Control Matrix

| Endpoint | Method | Guest | Regular User | Admin |
|---|---|---|---|---|
| `/` | GET | ✅ | ✅ | ✅ |
| `/up` | GET | ✅ | ✅ | ✅ |
| `/users` | POST (Register) | ✅ | ⚠️ Not a supported flow while already signed in | ⚠️ Not a supported flow while already signed in |
| `/users/sign_in` | POST | ✅ | ✅ | ✅ |
| `/users/confirmation` | GET | ✅ | ✅ | ✅ |
| `/users/password` | POST | ✅ | ✅ | ✅ |
| `/users/password` | PUT/PATCH | ✅ with valid reset token | ✅ with valid reset token | ✅ with valid reset token |
| `/users/sign_out` | DELETE | ❌ 422 | ✅ | ✅ |
| `/user/profile` | GET | ❌ 422 + token info | ✅ (Self) | ✅ |
| `/users` | GET (List) | ❌ 401 | ❌ 401 | ✅ |
| `/users/create` | POST | ❌ 401 | ❌ 401 | ✅ |
| `/users/:id` | GET | ❌ 401 | ✅ if `id` matches | ✅ Any |
| `/users/:id` | PUT | ❌ 401 | ✅ if `id` matches | ✅ Any |
| `/users/:id` | DELETE | ❌ 401 | ✅ if `id` matches | ✅ Any |
| Change user `role` | PUT `/users/:id` | ❌ | ❌ (Field ignored) | ✅ |

For Devise-managed endpoints, the matrix assumes any required confirmation or reset token is present. `POST /users` is intended for guest registration; calling it while already authenticated is not part of the supported flow.

---

## User Type Descriptions

### Guest

- No JWT or JWT is invalid/expired.
- `current_user` returns `nil`.
- Can only access public endpoints: home page, registration, login, email confirmation, password reset.
- Calling `GET /user/profile` with a faulty token still receives a `422` error accompanied by **token metadata** (information about the token status, no user data).
- Calling any endpoint in the `UsersController` will return `401 Unauthorized`.

### Regular User (`role = "user"`)

- Has a valid JWT and a confirmed email.
- Can sign out (`DELETE /users/sign_out`).
- Can view, update, and delete **their own account** (validated via `current_user.id == params[:id]`).
- **Cannot** view the list of all users, view/edit/delete other users, or create users outside the Devise registration flow.
- The `role` field in the request body is **completely ignored** — they cannot escalate their own privileges.

### Admin (`role = "admin"`)

- All rights of a Regular User, plus:
- View the entire user list (`GET /users`).
- View, update, and delete **any user** without ID verification.
- Create users directly via `POST /users/create` (outside the Devise flow).
- **Change the `role`** of other users when calling `PUT /users/:id` with `{ "user": { "role": "admin" } }`.

---

## Authorization Workflow

All requests to the `UsersController` pass through `before_action :authorize_user_access` (defined in `app/controllers/concerns/user_access_control.rb`). `current_user` is resolved by Devise/Warden from the incoming JWT before this concern runs:

```
Request → Warden / Devise resolves current_user from JWT
        → authorize_user_access
              ├─ current_user nil?     → 401 "Unauthorized"
              ├─ current_user.admin?   → ✅ Authorized
              ├─ action is show/update/destroy
              │    └─ current_user.id == params[:id]? → ✅ Authorized
              └─ otherwise             → 401 "You must be an administrator..."
```

---

## Handling `GET /user/profile` with Faulty Tokens

`SessionsController#show` **does not** use `authorize_user_access`. It handles both cases:

```
GET /user/profile
    ├─ Valid token, user exists
    │    → 200 { user: { ... }, token_info: { token, jti, expired_at, ... } }
    └─ Missing / Invalid / Expired / Revoked token
         → 422 { user: null, token_info: { token, jti, expired: true/false, expired_in: -N, ... } }
```

This behavior is intentional: it allows the client to retrieve token status information even when authentication fails, enabling appropriate messages (e.g., expired token vs. revoked token).

---

## Developer Notes

- **Promoting a user to admin:** Only an admin can do this via `PUT /users/:id` with the body `{ "user": { "role": "admin" } }`. There is no self-service endpoint.
- **Creating the first admin:** `bin/rails db:seed` creates `admin@admin.admin` with a random password in development. Outside development it reads `ADMIN_EMAIL` / `ADMIN_PASSWORD` from env or credentials.
- **Manual email confirmation (Development):** Run `bin/rails console` → `User.find_by(email: "...").confirm`.
- **Token Revocation:** After `DELETE /users/sign_out`, the JTI is recorded in the `jwt_denylists` table. Production recurring tasks can clean expired rows hourly via `config/recurring.yml`, and `bin/rails jwt_denylist:cleanup` remains available for manual cleanup.
- **Rate limiting:** Applied to sign_in (5 req/60s per IP, 10 req/60s per email), registration (10 req/hr per IP), and password reset (5 req/hr per IP). Localhost is automatically safelisted.
