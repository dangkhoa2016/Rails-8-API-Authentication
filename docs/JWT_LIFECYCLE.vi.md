# Vòng đời của JWT
> 🌐 Language / Ngôn ngữ: [English](JWT_LIFECYCLE.md) | **Tiếng Việt**

Tài liệu này giải thích vòng đời đầy đủ của một JWT trong hệ thống — từ lúc được tạo ra đến lúc bị thu hồi và dọn dẹp khỏi database.

## Tổng quan

```
[POST /users/sign_in]
        │
        ▼
  Devise xác thực email + password
        │
        ▼
  devise-jwt gọi User#on_jwt_dispatch(token, payload)
  → lưu token + payload vào user.token_info (attr_accessor, in-memory)
        │
        ▼
  JWT trả về trong response header: <JWT_AUTH_HEADER (mặc định: Authorization)>: Bearer <token>
        │
        ▼
  Client lưu token, gửi kèm mọi request tiếp theo:
  <JWT_AUTH_HEADER (mặc định: Authorization)>: Bearer <token>
        │
        ▼
  Warden::JWTAuth::Strategy.authenticate!
  → Decode token (verify signature + exp)
  → Kiểm tra JTI trong jwt_denylists (thu hồi chưa?)
  → Nếu hợp lệ: gọi JwtDenylist.jwt_revoked? → set user.token_info = { payload: ... }
        │
        ▼
  [DELETE /users/sign_out]
  → devise-jwt ghi JTI vào bảng jwt_denylists
  → Token không thể dùng lại dù chưa hết hạn
        │
        ▼
      [Scheduled cleanup]
      config/recurring.yml → CleanExpiredJwtDenylistsJob (mỗi giờ trong production)
      → Xóa các row có exp < Time.current
```

Ghi chú:
- Vì ứng dụng bật Devise `:confirmable`, user mới đăng ký phải xác nhận email trước khi đăng nhập thành công.
- `DELETE /users/sign_out` khi không có user đã xác thực sẽ trả `422 { "message": "No user is signed in" }` và không ghi denylist row.

---

## JWT Payload

Token được ký bằng thuật toán HS256 (mặc định của devise-jwt). Payload bao gồm:

| Field | Ý nghĩa |
|---|---|
| `sub` | ID của user (string) |
| `scp` | Scope — luôn là `"user"` |
| `aud` | Audience — `nil` trong cấu hình hiện tại |
| `iat` | Issued At — timestamp tạo token (seconds) |
| `exp` | Expiration — timestamp hết hạn (seconds) |
| `jti` | JWT ID — UUID ngẫu nhiên, dùng để thu hồi |

Thời hạn token hiện tại là **900 giây (15 phút)**. Có thể thay đổi trong `config/initializers/devise.rb` qua `jwt.expiration_time`.

---

## Khóa ký (Signing Key)

Ưu tiên theo thứ tự:

1. `Rails.application.credentials.devise_jwt_secret_key` (trong credentials encrypted)
2. `ENV["DEVISE_JWT_SECRET_KEY"]` (biến môi trường)
3. `Rails.application.secret_key_base` (fallback)

> **Lưu ý production:** Nên đặt `DEVISE_JWT_SECRET_KEY` riêng để có thể rotate khóa JWT mà không cần regenerate toàn bộ Rails master key. Xem `.env.sample` để biết cách đặt.

---

## Revocation — Bảng `jwt_denylists`

Khi user sign out, `jti` của token được ghi vào bảng `jwt_denylists`:

```
jwt_denylists
┌────────┬──────────────────────────────────────┬─────────────────────┐
│ id     │ jti                                  │ exp                 │
├────────┼──────────────────────────────────────┼─────────────────────┤
│ 1      │ 3f2e1a4b-...                          │ 2026-04-24 10:00:00 │
│ 2      │ 9c8d7e6f-...                          │ 2026-04-23 08:30:00 │
└────────┴──────────────────────────────────────┴─────────────────────┘
```

Mỗi lần request đến với JWT, `JwtDenylist.jwt_revoked?(payload, user)` kiểm tra `jti` có tồn tại trong bảng này không. Nếu có → từ chối request, dù token chưa hết hạn `exp`.

### Xem trạng thái token hiện tại

```bash
# Xem số lượng JTI đã thu hồi
bin/rails runner 'puts JwtDenylist.count'

# Xem các JTI đã hết hạn (có thể dọn dẹp)
bin/rails runner 'puts JwtDenylist.expired_before.count'
```

---

## Cleanup — Dọn dẹp bảng denylist

Các row trong `jwt_denylists` có trường `exp` — khi `exp < Time.current`, token đó dù không bị revoke cũng đã hết hạn và không thể dùng lại. Các row này an toàn để xóa.

### Chạy thủ công

```bash
# Production / staging
RAILS_ENV=production bin/rails jwt_denylist:cleanup

# Development / test
bin/rails jwt_denylist:cleanup
```

### Tự động hóa (khuyến nghị)

Repo này đã có sẵn lịch recurring cho Solid Queue trong `config/recurring.yml`:

| Môi trường | Job key | Class | Queue | Lịch |
|---|---|---|---|---|
| `production` | `clean_expired_jwt_denylists` | `CleanExpiredJwtDenylistsJob` | `background` | `every hour` |

Nếu muốn dùng cron thay thế, bạn vẫn có thể tự schedule `bin/rails jwt_denylist:cleanup`.

---

## `GET /user/profile`, `/user/me`, `/user/whoami` với token lỗi

Ba route này cùng trỏ vào một action controller. Chúng trả về **token metadata ngay cả khi xác thực thất bại** cho các trường hợp token thiếu, hết hạn, hoặc đã thu hồi. Hành vi này có chủ ý để client phân biệt được các trường hợp lỗi:

| Tình huống | Status | `user` | `token_info.expired` | `token_info.expired_in` |
|---|---|---|---|---|
| Token hợp lệ | 200 | object | `false` | số dương |
| Thiếu token | 422 | `null` | `true` | số không dương |
| Token hết hạn | 422 | `null` | `true` | số âm |
| Token bị thu hồi | 422 | `null` | `false` | số dương |
| Token không hợp lệ (bad format / decode error) | 401 | chỉ có error body | — | — |

> Token bị **thu hồi** (revoked) khác với token **hết hạn** (expired): revoked token vẫn còn trong thời hạn `exp` nhưng JTI đã nằm trong `jwt_denylists`. `expired: false` + `expired_in > 0` mà vẫn nhận 422 → chắc chắn là token bị thu hồi.

JWT bị malformed sẽ không có `token_info`; `ApplicationController` rescue `JWT::DecodeError` và trả `401 Unauthorized` (`{ "error": "Invalid token" }`).

---

## Refresh Tokens

Access JWT chỉ sống được **15 phút**. Để tránh bắt user nhập lại credentials, hệ thống còn cấp một **refresh token** dài hạn với thời hạn **7 ngày**.

### Cách refresh token được cấp

Tại `POST /users/sign_in`, `Users::SessionsController#create` tạo refresh token mới và:

1. Chỉ lưu **SHA-256 digest** của token vào bảng `refresh_tokens` (token thô không bao giờ được lưu trực tiếp).
2. Trả về cho client theo 2 cách:
   - Dưới dạng **HttpOnly, Secure, SameSite=Lax cookie** tên `refresh_token` (bảo vệ web client khỏi XSS).
   - Trong JSON body dưới khóa `refresh_token` (cho mobile / client không dùng cookie).

### Chính sách bảo mật transport

Hai transport có đối tượng và quy tắc riêng:

- **Browser client** phải dùng **HttpOnly, Secure, SameSite=Lax cookie** `refresh_token`. Token thô **không được** lưu trong `localStorage` hoặc `sessionStorage`, vì mọi script chạy trên trang đều đọc được.
- **Native / mobile / CLI client** không quản lý cookie sẽ nhận token thô trong JSON body (`refresh_token`) và gửi lại qua param `refresh_token` hoặc header `X-Refresh-Token`.

Quy tắc áp dụng cho mọi client:

- Gửi request refresh token qua **TLS trong production** — token là bearer credential và không bao giờ được truyền dạng plaintext.
- Không bao giờ lưu token thô trong log ứng dụng, analytics, hay crash report; chỉ SHA-256 digest được lưu server-side.
- Với client không dùng cookie, lưu token thô trong secure platform storage; hãy coi như mật khẩu.

Việc loại refresh token khỏi JSON body để API chỉ dùng **cookie** là breaking change cho non-cookie client và sẽ được phát hành ở release riêng.

### Bảng `refresh_tokens`

| Cột | Mục đích |
|---|---|
| `token_digest` | SHA-256 của token thô (duy nhất) |
| `family_id` | Nhóm các token đã rotate thuộc cùng một phiên đăng nhập |
| `expires_at` | Thời điểm hết hạn (`7.days.from_now`) |
| `revoked_at` | Được set khi token bị rotate, user sign out, hoặc phát hiện reuse |
| `user_agent` / `ip_address` | Bối cảnh được ghi tại thời điểm cấp token |

### Refresh Token Rotation

`POST /users/tokens/refresh` nhận refresh token (qua cookie `refresh_token`, param `refresh_token`, hoặc header `X-Refresh-Token`) và:

1. Tra token theo digest.
2. Nếu token đã bị **revoked** → **phát hiện reuse**: toàn bộ nhóm `family_id` bị thu hồi và trả `401 Security alert` (bảo vệ khỏi replay token bị đánh cắp).
3. Nếu hết hạn hoặc tài khoản bị vô hiệu → token bị revoke và trả `401`.
4. Ngược lại token cũ được **rotate**: bị revoke và token mới có cùng **`family_id`** được cấp, kèm một access JWT mới.

### Sign out

`DELETE /users/sign_out` giờ cũng thu hồi refresh token đang hoạt động (từ cookie, param, hoặc header `X-Refresh-Token`) trước khi xóa cookie.

### Dọn dẹp

`CleanExpiredRefreshTokensJob` chạy mỗi giờ trong production (xem `config/recurring.yml`) và xóa các token có `expires_at` hoặc `revoked_at` cũ hơn 7 ngày.

### Các file liên quan

| File | Vai trò |
|---|---|
| `app/models/jwt_denylist.rb` | Model lưu JTI đã thu hồi, cung cấp `jwt_revoked?` và `delete_expired!` |
| `app/models/user.rb` | `on_jwt_dispatch` — callback nhận token vừa được tạo |
| `app/controllers/users/sessions_controller.rb` | Sign out (ghi denylist), profile endpoint (đọc token metadata) |
| `app/controllers/application_controller.rb` | `decode_token` — decode thủ công khi cần đọc payload từ header |
| `config/routes.rb` | Định nghĩa `/user/profile` và các alias tương thích `/user/me`, `/user/whoami` |
| `config/initializers/devise.rb` | `jwt.secret`, `jwt.request_formats` |
| `config/initializers/devise_jwt.rb` | Patch `skip_trackable` cho JWT strategy |
| `app/models/refresh_token.rb` | Model cho refresh token — digest, rotation, phát hiện reuse, thu hồi cả family |
| `app/controllers/users/tokens_controller.rb` | `POST /users/tokens/refresh` — rotate refresh token và cấp access JWT mới |
| `app/jobs/clean_expired_refresh_tokens_job.rb` | Xóa refresh token hết hạn/đã revoke cũ hơn 7 ngày |
| `config/recurring.yml` | Lịch recurring trong production cho `CleanExpiredJwtDenylistsJob` và `CleanExpiredRefreshTokensJob` |
| `lib/tasks/jwt_denylist.rake` | Rake task `jwt_denylist:cleanup` |
