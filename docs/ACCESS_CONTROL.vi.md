# Tra cứu về Kiểm soát truy cập
> 🌐 Language / Ngôn ngữ: [English](ACCESS_CONTROL.md) | **Tiếng Việt**

Tài liệu này mô tả sự khác biệt về quyền truy cập giữa ba loại người dùng trong hệ thống: **Khách (Guest)**, **User thường**, và **Admin**.

## Khái niệm cốt lõi

- **Role** được lưu trong cột `role` của bảng `users`, kiểu `string`, mặc định `"user"`.
- Hai giá trị hợp lệ: `"user"` và `"admin"` (khai báo qua `enum :role` trong `User` model).
- Xác thực dựa trên **JWT** (Devise + devise-jwt). Token được gửi trong header `Authorization: Bearer <token>`.
- Email phải **đã được confirm** trước khi đăng nhập thành công.

---

## Ma trận quyền truy cập

| Endpoint | Method | Khách | User thường | Admin |
|---|---|---|---|---|
| `/` | GET | ✅ | ✅ | ✅ |
| `/up` | GET | ✅ | ✅ | ✅ |
| `/users` | POST (đăng ký) | ✅ | ⚠️ Không phải flow hỗ trợ khi đã đăng nhập | ⚠️ Không phải flow hỗ trợ khi đã đăng nhập |
| `/users/sign_in` | POST | ✅ | ✅ | ✅ |
| `/users/confirmation` | GET | ✅ | ✅ | ✅ |
| `/users/password` | POST | ✅ | ✅ | ✅ |
| `/users/password` | PUT/PATCH | ✅ nếu có reset token hợp lệ | ✅ nếu có reset token hợp lệ | ✅ nếu có reset token hợp lệ |
| `/users/sign_out` | DELETE | ❌ 422 | ✅ | ✅ |
| `/user/profile` | GET | ❌ 422 + token info | ✅ (bản thân) | ✅ |
| `/users` | GET (danh sách) | ❌ 401 | ❌ 401 | ✅ |
| `/users/create` | POST | ❌ 401 | ❌ 401 | ✅ |
| `/users/:id` | GET | ❌ 401 | ✅ nếu `id` khớp | ✅ bất kỳ |
| `/users/:id` | PUT | ❌ 401 | ✅ nếu `id` khớp | ✅ bất kỳ |
| `/users/:id` | DELETE | ❌ 401 | ✅ nếu `id` khớp | ✅ bất kỳ |
| Thay đổi `role` của user | PUT `/users/:id` | ❌ | ❌ (field bị bỏ qua) | ✅ |

Với các endpoint do Devise quản lý, bảng trên giả định request đã có đầy đủ confirmation token hoặc reset token cần thiết. `POST /users` được thiết kế cho flow đăng ký của guest; gọi endpoint này khi đã đăng nhập không nằm trong flow được hỗ trợ.

---

## Mô tả từng loại người dùng

### Khách (Guest)

- Không có JWT hoặc JWT không hợp lệ/hết hạn.
- `current_user` trả về `nil`.
- Chỉ được truy cập các endpoint công khai: trang chủ, đăng ký, đăng nhập, xác nhận email, đặt lại mật khẩu.
- Gọi `GET /user/profile` với token lỗi vẫn nhận được `422` kèm **token metadata** (thông tin về trạng thái token, không có dữ liệu user).
- Gọi bất kỳ endpoint nào của `UsersController` sẽ nhận `401 Unauthorized`.

### User thường (`role = "user"`)

- Có JWT hợp lệ, email đã confirm.
- Có thể đăng xuất (`DELETE /users/sign_out`).
- Có thể xem, cập nhật, xóa **tài khoản của chính mình** (kiểm tra `current_user.id == params[:id]`).
- **Không thể** xem danh sách tất cả user, xem/sửa/xóa user khác, tạo user ngoài flow đăng ký Devise.
- Trường `role` trong request body bị **bỏ qua hoàn toàn** — không thể tự nâng quyền.

### Admin (`role = "admin"`)

- Mọi quyền của User thường, cộng thêm:
- Xem danh sách toàn bộ user (`GET /users`).
- Xem, cập nhật, xóa **bất kỳ user nào** không cần kiểm tra ID.
- Tạo user trực tiếp qua `POST /users/create` (ngoài flow Devise).
- **Thay đổi `role`** của user khác khi gọi `PUT /users/:id` với `{ "user": { "role": "admin" } }`.

---

## Luồng xử lý phân quyền

Tất cả request vào `UsersController` đều chạy qua `before_action :authorize_user_access` (định nghĩa trong `app/controllers/concerns/user_access_control.rb`). `current_user` được Devise/Warden suy ra từ JWT trước khi concern này chạy:

```
Request → Warden / Devise xác định current_user từ JWT
        → authorize_user_access
              ┌─ current_user nil?     → 401 "Unauthorized"
              ├─ current_user.admin?   → ✅ cho qua
              ├─ action là show/update/destroy
              │   └─ current_user.id == params[:id]? → ✅ cho qua
              └─ còn lại               → 401 "You must be an administrator..."
```

---

## Xử lý `GET /user/profile` với token lỗi

`SessionsController#show` **không** dùng `authorize_user_access`. Nó xử lý cả 2 trường hợp:

```
GET /user/profile
    ├─ Token hợp lệ, user tồn tại
    │   → 200 { user: { ... }, token_info: { token, jti, expired_at, ... } }
    └─ Token thiếu / lỗi / hết hạn / đã thu hồi
        → 422 { user: null, token_info: { token, jti, expired: true/false, expired_in: -N, ... } }
```

Hành vi này có chủ ý: cho phép client lấy thông tin trạng thái token ngay cả khi xác thực thất bại, để hiển thị thông báo phù hợp (token hết hạn vs. token bị thu hồi).

---

## Ghi chú cho lập trình viên

- **Nâng quyền user lên admin:** Chỉ admin mới làm được qua `PUT /users/:id` với body `{ "user": { "role": "admin" } }`. Không có endpoint tự phục vụ.
- **Tạo admin đầu tiên:** `bin/rails db:seed` sẽ tạo `admin@admin.admin` với mật khẩu ngẫu nhiên trong môi trường development. Ngoài development, seed đọc `ADMIN_EMAIL` / `ADMIN_PASSWORD` từ env hoặc credentials.
- **Confirm email bằng tay (phát triển):** `bin/rails console` → `User.find_by(email: "...").confirm`.
- **Token bị thu hồi** sau `DELETE /users/sign_out` — JTI được ghi vào bảng `jwt_denylists`. Trong production có thể dọn tự động hàng giờ qua `config/recurring.yml`, và `bin/rails jwt_denylist:cleanup` vẫn dùng được để dọn thủ công.
- **Rate limiting:** Áp dụng cho sign_in (5 req/60s per IP, 10 req/60s per email), registration (10 req/hr per IP), password reset (5 req/hr per IP). Localhost được safelist tự động.
