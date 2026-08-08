# Xác thực API Rails 8 với JWT

[![Ruby 3.x](https://img.shields.io/badge/Ruby-3.x-red?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Ruby 4.x](https://img.shields.io/badge/Ruby-4.x-red?style=flat&logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![Rails 8.1.3](https://img.shields.io/badge/Rails-8.1.3-CC0000?logo=rubyonrails&logoColor=white)](https://rubyonrails.org/)
[![CI](https://github.com/dangkhoa2016/Rails-8-API-Authentication/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-API-Authentication/actions/workflows/ci.yml)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/dangkhoa2016/Rails-8-API-Authentication/tree/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Dự án này là một dịch vụ xác thực API Rails 8 được xây dựng với Devise và JWT. Nó hỗ trợ đăng ký, xác nhận email, đăng nhập, đăng xuất, truy vấn hồ sơ, và các thao tác quản lý người dùng với kiểm soát truy cập chỉ dành cho admin.

## Tính năng

- Đăng ký người dùng với `username` bắt buộc và xác nhận email.
- Đăng nhập, đăng xuất và làm mới token (Refresh Token Rotation - RTR) dựa trên JWT với cơ chế thu hồi token thông qua denylist.
- Truy vấn hồ sơ kèm metadata của token qua `/user/profile` và các alias tương thích `/user/me`, `/user/whoami`.
- Cập nhật tài khoản và xóa tài khoản theo cơ chế self-service.
- Trạng thái hoạt động/không hoạt động của người dùng — tài khoản bị vô hiệu hóa sẽ tự động bị chặn đăng nhập.
- Các chức năng chỉ dành cho admin: danh sách người dùng, tạo người dùng, quản lý vai trò, xóa người dùng, bật/tắt trạng thái tài khoản (khóa/mở khóa), và xác nhận email từ admin.
- Giới hạn tần suất truy cập (rate limiting) cho các endpoint đăng nhập, đăng ký, và reset mật khẩu (rack-attack).
- Dọn dẹp denylist JWT và Refresh Token hết hạn tự động bằng Active Job (Solid Queue) và Rake task.
- Triển khai với Docker + Kamal, có health check cho container.
- CI với Brakeman, RuboCop, toàn bộ test suite của Rails, và một job riêng cho regression test của auth.

## Công nghệ sử dụng

- **Rails 8** — Framework MVC đầy đủ tính năng
- **Devise** — Giải pháp xác thực linh hoạt
- **devise-jwt** — Xác thực JWT token cho Devise
- **Puma** — Web server
- **PostgreSQL 17** — Cơ sở dữ liệu
- **Solid Cache**, **Solid Queue**, **Solid Cable** — Adapters mặc định của Rails 8
- **Rack::CORS** — Chia sẻ tài nguyên giữa các origin
- **Rack::Attack** — Giới hạn tốc độ truy cập
- **Docker + Kamal** — Triển khai containerized
- **Thruster** — Cache tài sản tĩnh và tăng tốc X-Sendfile
- **dotenv** — Quản lý biến môi trường
- **Brakeman** — Phân tích bảo mật tĩnh
- **RuboCop** — Kiểm tra coding convention
- **SimpleCov** — Đo lường code coverage

## Ma trận phiên bản Ruby

Repository hỗ trợ ba phiên bản Ruby:

| Runtime | Vai trò |
|---------|---------|
| **3.3** | Mặc định cho phát triển local và image container |
| **3.2.2** | Phiên bản tối thiểu được hỗ trợ |
| **4.0** | Phiên bản bổ sung được kiểm thử (chỉ CI) |

CI chạy toàn bộ test suite trên `3.2`, `3.3`, và `4.0`; container mặc định dùng
`3.3` và có thể override qua build arg `RUBY_VERSION`.

Repository cố ý **không commit** `Gemfile.lock`. Mỗi phiên bản Ruby tự resolve
bộ dependency riêng, nên lockfile được sinh bởi bundler local, bởi Docker build,
hoặc bởi CI — và không bao giờ chia sẻ giữa các runtime. Điều này giữ dự án
portable trên toàn bộ ma trận hỗ trợ mà không cố định một resolution duy nhất.

## Bảo mật dependency

`bundle-audit` hiện báo **CVE-2026-54659** trong `pagy` (path traversal qua tùy
chọn `locale`). Các bản vá (`>= 43.5.6`) yêu cầu **Ruby >= 3.3** và không chạy
được trên phiên bản tối thiểu **3.2.2**, nên không thể backport fix trong ma
trận hỗ trợ hiện tại.

Đường code bị lỗi **không thể truy cập** trong ứng dụng này: phân trang trong
`UsersController#index` chỉ gọi `pagy(..., limit:, max_limit:)` và không bao giờ
truyền `locale:` do người dùng kiểm soát. CI resolve bộ dependency mới cho từng
runtime, nên job `audit_gems` (Ruby 3.3) tự chọn `pagy` đã vá. Rủi ro này được
**chấp nhận và theo dõi**; cân nhắc lại khi bỏ hỗ trợ Ruby 3.2.

## Vận chuyển Refresh Token

Refresh token được vận chuyển qua hai transport:

- **Browser client** dùng **HttpOnly, Secure, SameSite=Lax cookie** `refresh_token`.
  Không đưa token thô vào `localStorage` hoặc `sessionStorage`.
- **Native / mobile / CLI client** đọc token thô từ JSON body
  (`refresh_token`) và gửi lại qua param `refresh_token` hoặc
  header `X-Refresh-Token`.

Mọi luồng refresh token phải dùng **TLS trong production**; token thô không bao
giờ được lưu hoặc log — chỉ SHA-256 digest được lưu. Xem
[`docs/JWT_LIFECYCLE.vi.md`](./docs/JWT_LIFECYCLE.vi.md) cho chính sách đầy đủ.

## Bắt đầu nhanh

Ứng dụng yêu cầu **PostgreSQL 17** (local development dùng adapter `pg`).

1. Cài đặt và khởi động PostgreSQL 17, rồi tạo role và database local. Trên
   Debian/Ubuntu, `apt-get install postgresql-17` là một lựa chọn; Docker cũng được:

```bash
docker run -d --name rails-auth-pg \
  -e POSTGRES_PASSWORD=postgres -e POSTGRES_USER=postgres \
  -p 127.0.0.1:5432:5432 postgres:17
```

2. Sao chép sample environment local và chuẩn bị database.

```bash
cp .env.sample .env
bin/setup
```

3. Khởi động ứng dụng.

```bash
bin/dev
```

4. Gọi API tại `http://localhost:4000` theo mặc định. Nếu bạn thiết lập `PORT` trong shell hoặc `.env`, hãy sử dụng giá trị đó.

5. Sử dụng các snippet trong thư mục `manual/` như tài liệu tham khảo copy/paste cho các request xác thực và quản lý người dùng:

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
      "username": "user1",
      "password": "Password1!",
      "password_confirmation": "Password1!"
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
      "password": "Password1!"
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

Sao chép `.env.sample` thành `.env` cho môi trường local với PostgreSQL:

```bash
cp .env.sample .env
```

Các cấu hình đề xuất cho môi trường local:

```env
RAILS_ENV=development
RAILS_LOG_TO_STDOUT=true
PORT=4000
RAILS_MAX_THREADS=3
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=rails_8_api_authentication_development
POSTGRES_TEST_DB=rails_8_api_authentication_test
```

Các giá trị mặc định kết nối (`POSTGRES_HOST=127.0.0.1`, `POSTGRES_PORT=5432`,
`POSTGRES_USER=postgres`) khớp với PostgreSQL 17 local hoặc container Docker ở
trên; `.env.sample` chỉ chứa giá trị cho local development và không bao giờ
được dùng lại cho production. Thời gian chờ statement được kiểm soát bằng
`POSTGRES_STATEMENT_TIMEOUT` (mặc định `5000ms`).

Nếu không thiết lập `PORT`, `bin/dev` sẽ chạy mặc định trên `4000`. File `.env.sample` hiện đặt sẵn `PORT=4000`, nên nếu bạn copy nguyên file này thì local sẽ chạy tại `http://localhost:4000`. Toàn bộ danh sách biến môi trường — bao gồm secret cho production, cấu hình Puma, mailer, admin seed, CORS, và JWT token cho manual scripts — được mô tả trong `.env.sample`.

Với browser client chạy khác origin, cấu hình CORS mặc định cho phép request từ `CORS_ALLOWED_ORIGINS` nhưng **không** expose response header `Authorization`. Nếu frontend cần đọc JWT từ response đăng nhập, hãy cập nhật `config/initializers/cors.rb` để expose header này một cách rõ ràng.

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

| Method    | Path                   | Mục đích                                           |
| --------- | ---------------------- | -------------------------------------------------- |
| POST      | `/users`               | Đăng ký tài khoản mới                              |
| POST      | `/users/sign_in`       | Đăng nhập và nhận JWT trong header `Authorization` |
| POST      | `/users/tokens/refresh`| Làm mới Access JWT bằng Refresh Token              |
| DELETE    | `/users/sign_out`      | Đăng xuất và thu hồi Access JWT & Refresh Token    |
| GET       | `/users/confirmation`  | Xác nhận email qua flow confirmable của Devise     |
| POST      | `/users/password`      | Gửi email đặt lại mật khẩu                         |
| PUT/PATCH | `/users/password`      | Đặt lại mật khẩu với token                         |
| PUT/PATCH | `/users`               | Cập nhật tài khoản đang đăng nhập                  |
| DELETE    | `/users`               | Xóa tài khoản đang đăng nhập                       |

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
    "password": "Password1!",
    "password_confirmation": "Password1!"
  }
}
```

Ví dụ request đăng nhập:

```json
{
  "user": {
    "email": "user@example.com",
    "password": "Password1!"
  }
}
```

Request self-service cập nhật tài khoản trên `PUT /users` hoặc `PATCH /users` bắt buộc phải có `current_password`. Các request admin-managed trên `PUT /users/:id` đi qua `UsersController` nên không yêu cầu `current_password`.

Endpoint profile cũng có 2 kiểu lỗi xác thực khác nhau:

- Token thiếu, hết hạn, hoặc đã bị thu hồi: `422` với `user: null` và `token_info`
- Token bị lỗi format/malformed: `401` với `{ "error": "Invalid token" }`

## Luồng ví dụ

### 1. Đăng ký

```bash
curl -X POST http://localhost:4000/users \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "user@example.com",
      "username": "user1",
      "password": "Password1!",
      "password_confirmation": "Password1!"
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
      "password": "Password1!"
    }
  }'
```

JWT được trả về trong header `Authorization`.

### 4. Xem hồ sơ

```bash
curl http://localhost:4000/user/profile \
  -H "Authorization: Bearer <jwt_token>"
```

`/user/me` và `/user/whoami` là các alias tương thích cho cùng một response.

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

## Tài liệu chuyên sâu

Thư mục `docs/` chứa các ghi chú chi tiết hơn về implementation và vận hành của hệ thống xác thực hiện tại:

- [docs/ACCESS_CONTROL.vi.md](./docs/ACCESS_CONTROL.vi.md) - Quy tắc phân quyền cho guest, self-service, và admin
- [docs/JWT_LIFECYCLE.vi.md](./docs/JWT_LIFECYCLE.vi.md) - Vòng đời JWT, metadata ở endpoint profile, thu hồi, và dọn dẹp denylist
- [docs/RATE_LIMITING.vi.md](./docs/RATE_LIMITING.vi.md) - Các ngưỡng Rack::Attack hiện tại, response khi throttle, và lưu ý sau reverse proxy
- [docs/DEPLOYMENT.vi.md](./docs/DEPLOYMENT.vi.md) - Triển khai với Kamal, Docker, biến môi trường, health check, và persistence của PostgreSQL

## Kế hoạch cải tiến

Các file theo dõi cải tiến của dự án được liệt kê dưới đây:

- [manual/PROJECT_IMPROVEMENT_REPORT.md](./manual/PROJECT_IMPROVEMENT_REPORT.md)
- [manual/IMPLEMENTATION_TRACKER.md](./manual/IMPLEMENTATION_TRACKER.md)

## Dự án liên quan

Dự án này có một phiên bản Node.js triển khai các khái niệm xác thực tương tự (JWT, kiểm soát truy cập theo vai trò, thu hồi token) trên một stack khác:

- **[dangkhoa2016/Nodejs-API-Authentication](https://github.com/dangkhoa2016/Nodejs-API-Authentication)** — Một REST API sẵn sàng cho production dành cho xác thực và quản lý người dùng, được xây dựng bằng **Hono**, **Sequelize**, **bcryptjs**, **JWT**, và **SQLite** (dev) / **Postgres** (prod).

## Favicon

Các file favicon được phục vụ từ thư mục `public/`:

- `favicon.ico`
- `favicon.png`
- `favicon.svg`
- `android-chrome-192x192.png`
- `android-chrome-512x512.png`
- `apple-touch-icon.png`
- `apple-touch-icon-precomposed.png`

Các file này được tạo dựa trên một sticker từ Flaticon. Xem [public/license.md](./public/license.md) để biết nguồn, ghi công và chi tiết giấy phép.

## License

Dự án này được cấp phép theo MIT License.

Xem file [LICENSE](LICENSE) để biết thêm chi tiết.

