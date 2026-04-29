# Xác thực API Rails 8 với JWT

[![Ruby 3.4.7](https://img.shields.io/badge/Ruby-3.4.7-red?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails 8.1.3](https://img.shields.io/badge/Rails-8.1.3-CC0000?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Dự án này là một dịch vụ xác thực API Rails 8 được xây dựng với Devise và JWT. Nó hỗ trợ đăng ký, xác nhận email, đăng nhập, đăng xuất, truy vấn hồ sơ, và các thao tác quản lý người dùng với kiểm soát truy cập chỉ dành cho admin.

## Tính năng

- Đăng ký người dùng với `username` bắt buộc và xác nhận email.
- Đăng nhập và đăng xuất dựa trên JWT với cơ chế thu hồi token thông qua denylist.
- Truy vấn hồ sơ kèm metadata của token qua `/user/profile` và các alias tương thích `/user/me`, `/user/whoami`.
- Cập nhật tài khoản và xóa tài khoản theo cơ chế self-service.
- Các chức năng chỉ dành cho admin: danh sách người dùng, tạo người dùng, quản lý vai trò, và xóa người dùng.
- Giới hạn tần suất truy cập (rate limiting) cho các endpoint đăng nhập, đăng ký, và reset mật khẩu (rack-attack).
- Dọn dẹp denylist JWT bằng Rake task.
- Triển khai với Docker + Kamal, có health check cho container.
- CI với Brakeman, RuboCop, toàn bộ test suite của Rails, và một job riêng cho regression test của auth.
- Bảo vệ chống SSRF: chặn các địa chỉ loopback, địa chỉ nội bộ (private) và link-local, bao gồm cả IPv6 fe80::/10.

## Công nghệ sử dụng

- Rails 8
- Devise
- devise-jwt
- SQLite
- Docker + Kamal (scaffolding cho deployment)

## Bắt đầu nhanh

1. Cài đặt dependencies và chuẩn bị database.

```bash
bin/setup
```

2. Khởi động ứng dụng.

```bash
bin/dev
```

3. Gọi API tại `http://localhost:3000` theo mặc định. Nếu bạn thiết lập `PORT` trong shell hoặc `.env`, hãy sử dụng giá trị đó.

4. Sử dụng các snippet trong thư mục `manual/` như tài liệu tham khảo copy/paste cho các request xác thực và quản lý người dùng:

* `manual/registration.sh`
* `manual/session.sh`
* `manual/password.sh`
* `manual/user.sh`

## Quick Start xác thực local

Luồng này dành cho môi trường local sạch và tương ứng với các route được cover bởi auth integration tests.

1. Chạy ứng dụng bằng `bin/dev` và giữ nó hoạt động tại `http://localhost:3000` (trừ khi bạn đã override `PORT`).

2. Đăng ký người dùng mới trong terminal khác.

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

3. Lấy confirmation token từ database local.

```bash
bin/rails runner 'puts User.find_by!(email: "user@example.com").confirmation_token'
```

4. Xác nhận tài khoản.

```bash
curl -sS "http://localhost:3000/users/confirmation?confirmation_token=<token>" | jq .
```

5. Đăng nhập và lấy JWT từ header `Authorization` trong response.

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

6. Gọi endpoint profile với JWT.

```bash
curl -sS http://localhost:3000/user/profile \
  -H "Authorization: Bearer ${TOKEN}" | jq .
```

7. Đăng xuất và thu hồi token.

```bash
curl -sS -X DELETE http://localhost:3000/users/sign_out \
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

Nếu không thiết lập `PORT`, `bin/dev` sẽ chạy mặc định trên `3000`. File `.env.sample` hiện đặt sẵn `PORT=4000`, nên nếu bạn copy nguyên file này thì local sẽ chạy tại `http://localhost:4000`. Toàn bộ danh sách biến môi trường — bao gồm secret cho production, cấu hình Puma, mailer, admin seed, CORS, và JWT token cho manual scripts — được mô tả trong `.env.sample`.

Với browser client chạy khác origin, cấu hình CORS mặc định cho phép request từ `CORS_ALLOWED_ORIGINS` nhưng **không** expose response header `Authorization`. Nếu frontend cần đọc JWT từ response đăng nhập, hãy cập nhật `config/initializers/cors.rb` để expose header này một cách rõ ràng.

## Code Coverage

Bạn có thể tạo báo cáo coverage local với SimpleCov bằng cách chạy test kèm biến `COVERAGE=1`:

```bash
COVERAGE=1 bin/rails test
```

Khi bật `COVERAGE=1`, test suite sẽ chạy không dùng Rails parallel workers để báo cáo SimpleCov không bị sai lệch.

Báo cáo sẽ được ghi vào `public/coverage`. Khi Rails server đang chạy trong môi trường development, bạn có thể mở `http://localhost:3000/coverage` để xem report mới nhất. Endpoint này chỉ bật ở development và chỉ redirect tới báo cáo HTML tĩnh.

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

Cả ba route hồ sơ này cùng trỏ vào một action controller và trả về cùng một cấu trúc response.

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

Các endpoint của Devise yêu cầu payload được lồng dưới key `user`. Với endpoint đăng ký `POST /users`, trường `username` là bắt buộc.

Ví dụ request đăng ký:

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

Ví dụ request đăng nhập:

```json
{
  "user": {
    "email": "user@example.com",
    "password": "password"
  }
}
```

Request self-service cập nhật tài khoản trên `PUT /users` hoặc `PATCH /users` bắt buộc phải có `current_password`. Các request admin-managed trên `PUT /users/:id` đi qua `UsersController` nên không yêu cầu `current_password`.

Endpoint profile cũng có 2 kiểu lỗi xác thực khác nhau:

- Token thiếu, hết hạn, hoặc đã bị thu hồi: `422` với `user: null` và `token_info`
- Token bị lỗi format/malformed: `422` với `{ "error": "Invalid token" }`

## Luồng ví dụ

### 1. Đăng ký

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

### 2. Xác nhận email

```bash
curl "http://localhost:3000/users/confirmation?confirmation_token=<token>"
```

### 3. Đăng nhập

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

JWT được trả về trong header `Authorization`.

### 4. Xem hồ sơ

```bash
curl http://localhost:3000/user/profile \
  -H "Authorization: Bearer <jwt_token>"
```

`/user/me` và `/user/whoami` là các alias tương thích cho cùng một response.

### 5. Đăng xuất

```bash
curl -X DELETE http://localhost:3000/users/sign_out \
  -H "Authorization: Bearer <jwt_token>"
```

## Kế hoạch cải tiến

Các tài liệu theo dõi cải tiến hiện có nằm trong thư mục `manual/`:

* [manual/PROJECT_IMPROVEMENT_REPORT.md](./manual/PROJECT_IMPROVEMENT_REPORT.md)
* [manual/IMPLEMENTATION_TRACKER.md](./manual/IMPLEMENTATION_TRACKER.md)

## Tài liệu tham khảo thủ công

Các file dưới đây chứa ví dụ curl để copy/paste, dùng làm tài liệu tham khảo:

* [manual/registration.sh](./manual/registration.sh)
* [manual/session.sh](./manual/session.sh)
* [manual/password.sh](./manual/password.sh)
* [manual/user.sh](./manual/user.sh)

## Tài liệu chuyên sâu

Thư mục `docs/` chứa các ghi chú chi tiết hơn về implementation và vận hành của hệ thống xác thực hiện tại:

* [docs/ACCESS_CONTROL.vi.md](./docs/ACCESS_CONTROL.vi.md) - Quy tắc phân quyền cho guest, self-service, và admin
* [docs/JWT_LIFECYCLE.vi.md](./docs/JWT_LIFECYCLE.vi.md) - Vòng đời JWT, metadata ở endpoint profile, thu hồi, và dọn dẹp denylist
* [docs/RATE_LIMITING.vi.md](./docs/RATE_LIMITING.vi.md) - Các ngưỡng Rack::Attack hiện tại, response khi throttle, và lưu ý sau reverse proxy
* [docs/DEPLOYMENT.vi.md](./docs/DEPLOYMENT.vi.md) - Triển khai với Kamal, Docker, biến môi trường, health check, và persistence của SQLite

## Dự án liên quan

Dự án này có một phiên bản Node.js triển khai các khái niệm xác thực tương tự (JWT, kiểm soát truy cập theo vai trò, thu hồi token) trên một stack khác:

- **[dangkhoa2016/Nodejs-API-Authentication](https://github.com/dangkhoa2016/Nodejs-API-Authentication)** — Một REST API sẵn sàng cho production dành cho xác thực và quản lý người dùng, được xây dựng bằng **Hono**, **Sequelize**, **bcryptjs**, **JWT**, và **SQLite** (dev) / **Postgres** (prod).

## License

Dự án này được cấp phép theo MIT License.
