# Xác thực API Rails 8 với JWT

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Dự án này là một dịch vụ xác thực API Rails 8 được xây dựng với Devise và JWT. Nó hỗ trợ đăng ký, xác nhận email, đăng nhập, đăng xuất, truy vấn hồ sơ, và các thao tác quản lý người dùng với kiểm soát truy cập chỉ dành cho admin.

## Tính năng

- Đăng ký người dùng với xác nhận email.
- Đăng nhập và đăng xuất dựa trên JWT với cơ chế thu hồi token thông qua denylist.
- Truy vấn hồ sơ kèm metadata của token.
- Cập nhật tài khoản và xóa tài khoản theo cơ chế self-service.
- Trạng thái hoạt động/không hoạt động của người dùng — tài khoản bị vô hiệu hóa sẽ tự động bị chặn đăng nhập.
- Các chức năng chỉ dành cho admin: danh sách người dùng, tạo người dùng, quản lý vai trò, xóa người dùng, bật/tắt trạng thái tài khoản (khóa/mở khóa), và xác nhận email từ admin.
- Giới hạn tần suất truy cập (rate limiting) cho các endpoint đăng nhập, đăng ký, và reset mật khẩu (rack-attack).
- Dọn dẹp denylist JWT bằng job/task.
- Triển khai với Docker + Kamal, có health check cho container.
- CI với Brakeman, RuboCop, toàn bộ test suite của Rails, và một job riêng cho regression test của auth.

## Công nghệ sử dụng

- **Rails 8** — Framework MVC đầy đủ tính năng
- **Devise** — Giải pháp xác thực linh hoạt
- **devise-jwt** — Xác thực JWT token cho Devise
- **Puma** — Web server
- **SQLite** — Cơ sở dữ liệu
- **Solid Cache**, **Solid Queue**, **Solid Cable** — Adapters mặc định của Rails 8
- **Rack::CORS** — Chia sẻ tài nguyên giữa các origin
- **Rack::Attack** — Giới hạn tốc độ truy cập
- **Docker + Kamal** — Triển khai containerized
- **Thruster** — Cache tài sản tĩnh và tăng tốc X-Sendfile
- **dotenv** — Quản lý biến môi trường
- **Brakeman** — Phân tích bảo mật tĩnh
- **RuboCop** — Kiểm tra coding convention
- **SimpleCov** — Đo lường code coverage

## Bắt đầu nhanh

1. Cài đặt dependencies và chuẩn bị database.

```bash
bin/setup
```

2. Khởi động ứng dụng.

```bash
bin/dev
```

3. Gọi API tại `http://localhost:4000` theo mặc định. Nếu bạn thiết lập `PORT` trong shell hoặc `.env`, hãy sử dụng giá trị đó.

4. Sử dụng các snippet trong thư mục `manual/` như tài liệu tham khảo copy/paste cho các request xác thực và quản lý người dùng:

- `manual/registration.sh`
- `manual/session.sh`
- `manual/password.sh`
- `manual/user.sh`

## Quick Start xác thực local

Luồng này dành cho môi trường local sạch và tương ứng với các route được cover bởi auth integration tests.

1. Chạy ứng dụng bằng `bin/dev` và giữ nó hoạt động tại `http://localhost:4000` (trừ khi bạn đã override `PORT`).

2. Đăng ký người dùng mới trong terminal khác.

```bash
curl -sS -X POST http://localhost:4000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password",
      "password_confirmation": "password"
    }
  }' | jq .
```

3. Lấy confirmation token từ database local.

```bash
bin/rails runner 'puts User.find_by!(email: "user@example.com").confirmation_token'
```

4. Xác nhận tài khoản.

```bash
curl -sS "http://localhost:4000/users/confirmation?confirmation_token=<token>" | jq .
```

5. Đăng nhập và lấy JWT từ header `Authorization` trong response.

```bash
TOKEN=$(curl -is -X POST http://localhost:4000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password"
    }
  }' | sed -n 's/^authorization: Bearer //p' | tr -d '\r')
```

6. Gọi endpoint profile với JWT.

```bash
curl -sS http://localhost:4000/user/profile \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

7. Đăng xuất và thu hồi token.

```bash
curl -sS -X DELETE http://localhost:4000/users/sign_out \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

8. (Tùy chọn) Tham khảo thêm các request trong `manual/session.sh`, `manual/registration.sh`, `manual/password.sh`, và `manual/user.sh` cho các trường hợp token không hợp lệ, token hết hạn, reset mật khẩu, và ví dụ quản lý user/admin.

## Môi trường

Sao chép `.env.sample` thành `.env` cho môi trường local:

```bash
cp .env.sample .env
```

Các cấu hình tối thiểu cần thiết:

```env
RAILS_ENV=development
RAILS_LOG_TO_STDOUT=true
PORT=4000
RAILS_MAX_THREADS=3
```

Nếu không thiết lập `PORT`, `bin/dev` sẽ chạy mặc định trên `4000`. Toàn bộ danh sách biến môi trường — bao gồm secret cho production, cấu hình Puma, mailer, admin seed, CORS, và JWT token cho manual scripts — được mô tả trong `.env.sample`.

## Code Coverage

Bạn có thể tạo báo cáo coverage local với SimpleCov bằng cách chạy test kèm biến `COVERAGE=1`:

```bash
COVERAGE=1 bin/rails test
```

Khi bật `COVERAGE=1`, test suite sẽ chạy không dùng Rails parallel workers để báo cáo SimpleCov không bị sai lệch.

Báo cáo sẽ được ghi vào `public/coverage`. Khi Rails server đang chạy trong môi trường development, bạn có thể mở `http://localhost:4000/coverage` để xem report mới nhất. Endpoint này chỉ bật ở development và chỉ redirect tới báo cáo HTML tĩnh.

Về bên trong, ứng dụng redirect `/coverage` sang `/coverage/` trước khi static file server xử lý request. Dấu `/` ở cuối là cần thiết vì HTML do SimpleCov sinh ra tham chiếu asset theo dạng đường dẫn tương đối như `./assets/...`.

## Contract Route hiện tại

Các route dưới đây phản ánh `config/routes.rb` và implementation hiện tại của controller.

### Route xác thực

| Method    | Path                  | Mục đích                                           |
| --------- | --------------------- | -------------------------------------------------- |
| POST      | `/users`              | Đăng ký tài khoản mới                              |
| POST      | `/users/sign_in`      | Đăng nhập và nhận JWT trong header `Authorization` |
| DELETE    | `/users/sign_out`     | Đăng xuất và thu hồi token hiện tại                |
| GET       | `/users/confirmation` | Xác nhận email qua flow confirmable của Devise     |
| POST      | `/users/password`     | Gửi email đặt lại mật khẩu                         |
| PUT/PATCH | `/users/password`     | Đặt lại mật khẩu với token                         |
| PUT/PATCH | `/users`              | Cập nhật tài khoản đang đăng nhập                  |
| DELETE    | `/users`              | Xóa tài khoản đang đăng nhập                       |

### Route hồ sơ

| Method | Path            | Mục đích             |
| ------ | --------------- | -------------------- |
| GET    | `/user/profile` | Endpoint hồ sơ chính |
| GET    | `/user/me`      | Alias tương thích    |
| GET    | `/user/whoami`  | Alias tương thích    |

### Route quản lý người dùng & admin

| Method | Path            | Mục đích                                    |
| ------ | --------------- | ------------------------------------------- |
| GET    | `/users`        | Lấy danh sách người dùng (chỉ admin)        |
| POST   | `/users/create` | Tạo người dùng (admin)                      |
| GET    | `/users/:id`    | Xem người dùng (admin hoặc chính mình)      |
| PUT    | `/users/:id`    | Cập nhật người dùng (admin hoặc chính mình) |
| DELETE | `/users/:id`    | Xóa người dùng (admin hoặc chính mình)      |

### Route tiện ích

| Method | Path    | Mục đích                                 |
| ------ | ------- | ---------------------------------------- |
| GET    | `/`     | Endpoint chào mừng ở root                |
| GET    | `/home` | Alias của endpoint chào mừng             |
| GET    | `/up`   | Health check cho uptime monitor/balancer |

## Ghi chú về format request

Các endpoint của Devise yêu cầu payload được lồng dưới key `user`.

Ví dụ request đăng ký:

```json
{
  "user": {
    "email": "user@example.com",
    "password": "password",
    "password_confirmation": "password"
  }
}
```

Ví dụ request đăng nhập:

```json
{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}
```

## Luồng ví dụ

### 1. Đăng ký

```bash
curl -X POST http://localhost:4000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password",
      "password_confirmation": "password"
    }
  }'
```

### 2. Xác nhận email

Sử dụng đường dẫn xác nhận do Devise tạo ra, ví dụ:

```bash
curl "http://localhost:4000/users/confirmation?confirmation_token=<token>"
```

### 3. Đăng nhập

```bash
curl -i -X POST http://localhost:4000/users/sign_in \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "password": "password"
    }
  }'
```

JWT được trả về trong header `Authorization`.

### 4. Xem hồ sơ

```bash
curl http://localhost:4000/user/profile \
  -H "Authorization: Bearer <jwt_token>"
```

### 5. Đăng xuất

```bash
curl -X DELETE http://localhost:4000/users/sign_out \
  -H "Authorization: Bearer <jwt_token>"
```

## Tài liệu tham khảo thủ công

Các file dưới đây phản ánh chính xác hơn việc triển khai thực tế so với các ví dụ trong README gốc, nhưng chúng có kèm các khối output mẫu và nên được xem như ghi chú tham khảo thay vì script shell để chạy nguyên văn:

- [manual/registration.sh](./manual/registration.sh)
- [manual/session.sh](./manual/session.sh)
- [manual/password.sh](./manual/password.sh)
- [manual/user.sh](./manual/user.sh)

## Kế hoạch cải tiến

Các file theo dõi cải tiến của dự án được liệt kê dưới đây:

- [manual/PROJECT_IMPROVEMENT_REPORT.md](./manual/PROJECT_IMPROVEMENT_REPORT.md)
- [manual/IMPLEMENTATION_TRACKER.md](./manual/IMPLEMENTATION_TRACKER.md)

## License

Dự án này được cấp phép theo MIT License.

Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

