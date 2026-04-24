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
  JWT trả về trong response header:  Authorization: Bearer <token>
        │
        ▼
  Client lưu token, gửi kèm mọi request tiếp theo:
  Authorization: Bearer <token>
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

Thời hạn token hiện tại là **3600 giây (1 giờ)**. Có thể thay đổi trong `config/initializers/devise.rb` qua `jwt.expiration_time`.

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

## `GET /user/profile` với token lỗi

Endpoint này trả về **token metadata ngay cả khi xác thực thất bại**. Hành vi này có chủ ý để client phân biệt được các trường hợp lỗi:

| Tình huống | Status | `user` | `token_info.expired` | `token_info.expired_in` |
|---|---|---|---|---|
| Token hợp lệ | 200 | object | `false` | số dương |
| Token hết hạn | 422 | `null` | `true` | số âm |
| Token bị thu hồi | 422 | `null` | `false` | số dương |
| Token không hợp lệ (bad format) | 422 | — | — | — |

> Token bị **thu hồi** (revoked) khác với token **hết hạn** (expired): revoked token vẫn còn trong thời hạn `exp` nhưng JTI đã nằm trong `jwt_denylists`. `expired: false` + `expired_in > 0` mà vẫn nhận 422 → chắc chắn là token bị thu hồi.

---

## Các file liên quan

| File | Vai trò |
|---|---|
| `app/models/jwt_denylist.rb` | Model lưu JTI đã thu hồi, cung cấp `jwt_revoked?` và `delete_expired!` |
| `app/models/user.rb` | `on_jwt_dispatch` — callback nhận token vừa được tạo |
| `app/controllers/users/sessions_controller.rb` | Sign out (ghi denylist), profile endpoint (đọc token metadata) |
| `app/controllers/application_controller.rb` | `decode_token` — decode thủ công khi cần đọc payload từ header |
| `config/initializers/devise.rb` | `jwt.secret`, `jwt.request_formats` |
| `config/initializers/devise_jwt.rb` | Patch `skip_trackable` cho JWT strategy |
| `config/recurring.yml` | Lịch recurring trong production cho `CleanExpiredJwtDenylistsJob` |
| `lib/tasks/jwt_denylist.rake` | Rake task `jwt_denylist:cleanup` |
