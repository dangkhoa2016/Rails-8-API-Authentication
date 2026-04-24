# Hướng dẫn Triển khai
> 🌐 Language / Ngôn ngữ: [English](DEPLOYMENT.md) | **Tiếng Việt**

Hướng dẫn deploy ứng dụng lên server production sử dụng **Kamal** (được tích hợp sẵn trong Rails 8).

## Yêu cầu

- Ruby + Bundler trên máy deploy (không cần cài trên server)
- Docker có sẵn hoặc để `kamal setup` tự cài trên server target
- Tài khoản Docker registry (Docker Hub, ghcr.io, v.v.)
- Server Linux với SSH access (user `root` hoặc user có sudo)
- Domain/hostname trỏ về IP của server (cho SSL Let's Encrypt)

Image production đã đóng gói sẵn `sqlite3`, `curl`, và các package runtime nhỏ
cần thiết cho app, nên ngoài Docker bạn không cần chuẩn bị thêm native
dependency nào trên server target.

---

## Bước 1 — Chuẩn bị config/deploy.yml

Mở `config/deploy.yml` và thay thế tất cả placeholder `<...>`:

```yaml
# Tên image trên registry
image: your-dockerhub-username/rails_8_api_authentication

# IP hoặc hostname của server
servers:
  web:
    - 203.0.113.10          # thay bằng IP thực

# Hostname cho SSL (Let's Encrypt)
proxy:
  ssl: true
  host: api.your-domain.com  # thay bằng domain thực

# Registry username
registry:
  username: your-dockerhub-username
```

> **Lưu ý SSL:** Domain phải đã trỏ DNS về IP server trước khi deploy đầu tiên. Let's Encrypt cần xác minh qua HTTP.

---

## Bước 2 — Chuẩn bị .kamal/secrets

File `.kamal/secrets` đọc secret từ environment của máy deploy, **không** lưu giá trị raw. Đảm bảo các biến sau tồn tại trong shell:

```bash
# Registry password (access token, không dùng real password)
export KAMAL_REGISTRY_PASSWORD=your-registry-access-token

# Cách 1: đọc từ file (phổ biến nhất)
# File config/master.key KHÔNG được commit vào git
# Lấy từ người quản lý dự án hoặc password manager
```

File `.kamal/secrets` đã được cấu hình sẵn để đọc `RAILS_MASTER_KEY` từ `config/master.key`:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
```

### (Tùy chọn) Thêm DEVISE_JWT_SECRET_KEY

Nếu muốn sử dụng khóa JWT độc lập (khuyến nghị cho production), uncomment dòng sau trong `config/deploy.yml`:

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - DEVISE_JWT_SECRET_KEY   # ← uncomment
```

Và thêm vào `.kamal/secrets`:

```bash
DEVISE_JWT_SECRET_KEY=$DEVISE_JWT_SECRET_KEY
```

Tạo khóa ngẫu nhiên:

```bash
bin/rails secret   # tạo 1 hex string 128 ký tự
```

---

## Bước 3 — Chuẩn bị server lần đầu

```bash
# Cài Docker trên server và cấu hình SSH access
kamal setup
```

Lệnh này sẽ:
- SSH vào server
- Cài Docker nếu chưa có
- Pull image từ registry
- Tạo volume `rails_8_api_authentication_storage` cho SQLite
- Khởi động app container + Kamal proxy
- Xin SSL certificate từ Let's Encrypt

---

## Bước 4 — Deploy thông thường

```bash
kamal deploy
```

Quy trình rolling deploy:
1. Build image mới (`docker build`)
2. Push lên registry
3. Pull xuống server
4. Chạy `bin/docker-entrypoint` (sẽ gọi `bin/rails db:prepare` trước khi khởi động server)
5. Kamal proxy kiểm tra `/up` — khi trả 200 mới chuyển traffic
6. Container cũ được stop

Mặc định background jobs chạy chung trong web process vì `SOLID_QUEUE_IN_PUMA=true` đã được đặt trong `config/deploy.yml`. Nếu sau này tách sang job host riêng, hãy uncomment block `job` server và chỉnh lại env liên quan.

---

## Lệnh vận hành thường dùng

```bash
# Xem logs realtime
kamal logs

# Mở Rails console trên server
kamal console

# Mở bash trong container đang chạy
kamal shell

# Mở Rails dbconsole (SQLite)
kamal dbc

# Xem trạng thái container
kamal app details

# Rollback về version trước
kamal rollback
```

> Các alias `console`, `shell`, `logs`, `dbc` đã được định nghĩa trong `config/deploy.yml` → `aliases`.

---

## Biến môi trường

Tham khảo `.env.sample` cho các biến mức ứng dụng và `config/deploy.yml` cho các biến runtime/deploy của container. Các biến quan trọng nhất cho production:

| Biến | Bắt buộc | Mặc định | Ghi chú |
|---|---|---|---|
| `RAILS_MASTER_KEY` | ✅ | — | Giải mã `config/credentials.yml.enc` |
| `DEVISE_JWT_SECRET_KEY` | Khuyến nghị | fallback về `secret_key_base` | Rotate độc lập với master key |
| `CORS_ALLOWED_ORIGINS` | Khuyến nghị | `http://localhost:3000` | Danh sách origin browser được Rack::Cors cho phép, phân tách bằng dấu phẩy |
| `DEVISE_MAILER_SENDER` | Khuyến nghị | `noreply@example.com` | Đổi sang địa chỉ/domain gửi mail thật |
| `SOLID_QUEUE_IN_PUMA` | Tùy chọn | `true` | Đặt `false` nếu chạy job worker riêng |
| `JOB_CONCURRENCY` | Tùy chọn | `1` | Số worker thread của Solid Queue |
| `WEB_CONCURRENCY` | Tùy chọn | `1` | Tăng nếu server có nhiều CPU |
| `RAILS_LOG_LEVEL` | Tùy chọn | `info` | Đặt `debug` khi cần trace issue |

Trong lúc boot production, app cũng log warning nếu không có khóa JWT độc lập
qua environment hoặc Rails credentials, hoặc nếu `DEVISE_MAILER_SENDER` vẫn
còn là địa chỉ kiểu placeholder `example.com`.

Nếu browser client chạy khác origin và cần đọc response header `Authorization` từ response đăng nhập, hãy cập nhật `config/initializers/cors.rb` để expose header đó rõ ràng. Cấu hình CORS hiện tại cho phép origin đã khai báo nhưng chưa expose custom response header cho JavaScript cross-origin.

---

## SQLite và persistence

Dữ liệu SQLite production được lưu trong Docker volume `rails_8_api_authentication_storage` → mount vào `/rails/storage` bên trong container. Ứng dụng dùng nhiều file SQLite ở đây: `production.sqlite3`, `production_cache.sqlite3`, `production_queue.sqlite3`, và `production_cable.sqlite3`.

**Sao lưu:**

```bash
# Từ máy local — copy file DB chính ra ngoài
kamal shell
# trong container:
sqlite3 /rails/storage/production.sqlite3 ".backup '/tmp/backup.sqlite3'"
# sau đó dùng docker cp hoặc scp để lấy file ra
```

> Nếu dự án cần chạy nhiều server song song hoặc yêu cầu HA, cần chuyển sang PostgreSQL/MySQL. SQLite chỉ phù hợp cho single-server deployment.

---

## Health Check

Container được kiểm tra sức khỏe qua 2 lớp:

1. **Docker HEALTHCHECK** (trong Dockerfile): `curl -f http://localhost/up` — 30s interval, 5s timeout, bắt đầu sau 60s
2. **Kamal proxy healthcheck** (trong `config/deploy.yml`): `GET /up` — 10s interval, 5s timeout — dùng để quyết định route traffic đến container mới trong rolling deploy

Endpoint `/up` trả `200` khi Rails boot bình thường, `500` nếu có exception khi khởi động.

---

## Checklist trước deploy lần đầu

- [ ] `config/deploy.yml` — đã thay hết placeholder `<...>`
- [ ] `config/master.key` — có trên máy deploy, không commit vào git
- [ ] DNS đã trỏ domain về IP server
- [ ] `KAMAL_REGISTRY_PASSWORD` có trong shell
- [ ] Docker registry đã tạo (Docker Hub, ghcr.io, v.v.)
- [ ] Server đã mở port 80 và 443
- [ ] (Tùy chọn) `DEVISE_JWT_SECRET_KEY` đã tạo và thêm vào `.kamal/secrets`
