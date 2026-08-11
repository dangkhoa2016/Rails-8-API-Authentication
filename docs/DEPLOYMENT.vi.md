# Hướng dẫn Triển khai
> 🌐 Language / Ngôn ngữ: [English](DEPLOYMENT.md) | **Tiếng Việt**

Hướng dẫn deploy ứng dụng lên server production sử dụng **Kamal** (được tích hợp
sẵn trong Rails 8).

## Yêu cầu

- Ruby + Bundler trên máy deploy (không cần cài trên server)
- Docker có sẵn hoặc để `kamal setup` tự cài trên server target
- Tài khoản Docker registry (Docker Hub, ghcr.io, v.v.)
- Server Linux với SSH access (user `root` hoặc user có sudo)
- Domain/hostname trỏ về IP của server (cho SSL Let's Encrypt)

Image production đã đóng gói sẵn `libpq`, `curl`, và các package runtime nhỏ cần
thiết cho app, nên ngoài Docker bạn không cần chuẩn bị thêm native dependency
nào trên server target. PostgreSQL 17 chạy như một Kamal accessory (xem bên
dưới).

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

> **Lưu ý SSL:** Domain phải đã trỏ DNS về IP server trước khi deploy đầu tiên.
> Let's Encrypt cần xác minh qua HTTP.

---

## Bước 2 — Chuẩn bị .kamal/secrets

File `.kamal/secrets` đọc secret từ environment của máy deploy, **không** lưu
giá trị raw. Đảm bảo các biến sau tồn tại trong shell:

```bash
# Registry password (access token, không dùng real password)
export KAMAL_REGISTRY_PASSWORD=your-registry-access-token

# Provision PostgreSQL CHỈ MỘT LẦN. Chạy lệnh này đúng một lần rồi lưu output
# vào password manager. Không chạy lại ở mỗi lần deploy — generate lại sẽ
# rotate password trong khi cluster persistent giữ password cũ.
openssl rand -hex 32

# Mọi deploy sau khi provision đều load CÙNG GIÁ TRỊ đã lưu:
# Nạp password PostgreSQL đã lưu từ password manager của bạn.
: "${POSTGRES_PASSWORD:?Load the persisted PostgreSQL password}"
export POSTGRES_PASSWORD

# Nạp SSH host thật từ environment/password manager của máy deploy.
: "${POSTGRES_ACCESSORY_HOST:?Set the PostgreSQL accessory SSH host}"
export POSTGRES_ACCESSORY_HOST
```

File `.kamal/secrets` đã được cấu hình sẵn để đọc `RAILS_MASTER_KEY` từ
`config/master.key`. Nó cũng tham chiếu các giá trị PostgreSQL từ environment.
Ký tự hex (`0-9a-f`) không chứa ký tự URI-reserved, nên password có thể nhúng
trực tiếp vào các database URL bên dưới mà không cần percent-encoding. File
`.kamal/secrets` được track chỉ chứa các tham chiếu này; giá trị thật nằm trong
environment/password manager của máy deploy:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
DATABASE_URL=$DATABASE_URL
CACHE_DATABASE_URL=$CACHE_DATABASE_URL
QUEUE_DATABASE_URL=$QUEUE_DATABASE_URL
CABLE_DATABASE_URL=$CABLE_DATABASE_URL
```

### Database URLs

Production yêu cầu **bốn URL PostgreSQL riêng biệt**; boot sẽ fail nếu thiếu
hoặc trùng bất kỳ URL nào (được enforce bởi
`config/initializers/production_database_urls.rb`). Tạo và export chúng trong
**environment của máy deploy (workstation)**, dùng host accessory
`rails_8_api_authentication-db` trên mạng Kamal và bốn tên database chính xác.
File `.kamal/secrets` được track chỉ chứa tham chiếu (`DATABASE_URL=$DATABASE_URL`);
không bao giờ để giá trị đã render vào đó:

```bash
export DATABASE_URL="postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production"
export CACHE_DATABASE_URL="postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_cache"
export QUEUE_DATABASE_URL="postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_queue"
export CABLE_DATABASE_URL="postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_cable"
```

Trước `kamal setup` hoặc `kamal deploy`, chạy preflight để fail nhanh nếu thiếu
bất kỳ secret nào trong environment của workstation:

```bash
: "${POSTGRES_ACCESSORY_HOST:?Missing POSTGRES_ACCESSORY_HOST}"
: "${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}"
: "${DATABASE_URL:?Missing DATABASE_URL}"
: "${CACHE_DATABASE_URL:?Missing CACHE_DATABASE_URL}"
: "${QUEUE_DATABASE_URL:?Missing QUEUE_DATABASE_URL}"
: "${CABLE_DATABASE_URL:?Missing CABLE_DATABASE_URL}"
```

Tuân theo chính sách TLS của nhà cung cấp cho kết nối qua mạng không tin cậy (ví
dụ thêm `?sslmode=require` vào mỗi URL). Ứng dụng đặt `statement_timeout` từ
`POSTGRES_STATEMENT_TIMEOUT` (mặc định `5000ms`) qua `config/database.yml`.

### (Phương án thay thế) Component mode

Thay vì export bốn URL, initializer có thể tự synthesize chúng từ các biến
`POSTGRES_*` (`POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_USER`,
`POSTGRES_PASSWORD`, và tùy chọn `POSTGRES_DB`, mặc định là
`rails_8_api_authentication_production`). Tiện dùng khi chạy production local.
Trên Kamal chỉ áp dụng nếu bạn cũng inject các biến `POSTGRES_*` — mặc định
`config/deploy.yml` chỉ truyền bốn secret `*_DATABASE_URL`. Validation lúc boot
giống nhau ở cả hai chế độ: thiếu thành phần bắt buộc, URL không hợp lệ, hoặc
database không riêng biệt vẫn khiến boot fail.

### (Tùy chọn) Thêm DEVISE_JWT_SECRET_KEY

Nếu muốn sử dụng khóa JWT độc lập (khuyến nghị cho production), uncomment dòng
sau trong `config/deploy.yml`:

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
- Boot PostgreSQL accessory và tạo các database primary, cache, queue, và
  cable
- Tạo volume `rails_8_api_authentication_storage` cho Active Storage uploads
  local
- Khởi động app container + Kamal proxy
- Xin SSL certificate từ Let's Encrypt

PostgreSQL accessory (`config/deploy.yml` → `accessories.db`) lưu dữ liệu trong
directory `data` của accessory, mount tại `/var/lib/postgresql/data`. Với data
directory mới, image chính
thức chạy `config/postgres/init-databases.sql` để tạo
`rails_8_api_authentication_production_cache`,
`rails_8_api_authentication_production_queue`, và
`rails_8_api_authentication_production_cable`. Database primary
(`rails_8_api_authentication_production`) do chính image tạo. Nếu bạn gắn vào
một data directory đã có sẵn, hãy chạy lại script tương tự một lần bằng `psql` —
image sẽ không tự chạy lại cho bạn.

---

## Bước 4 — Deploy thông thường

```bash
kamal deploy
```

Quy trình rolling deploy:

1. Build image mới (`docker build`)
2. Push lên registry
3. Pull xuống server
4. Chạy `bin/docker-entrypoint` (sẽ gọi `bin/rails db:prepare` cho các database
   primary, cache, queue, cable trước khi khởi động server)
5. Kamal proxy kiểm tra `/up` — khi trả 200 mới chuyển traffic
6. Container cũ được stop

Mặc định background jobs chạy chung trong web process vì
`SOLID_QUEUE_IN_PUMA=true` đã được đặt trong `config/deploy.yml`. Nếu sau này
tách sang job host riêng, hãy uncomment block `job` server và chỉnh lại env liên
quan.

---

## Lệnh vận hành thường dùng

```bash
# Xem logs realtime
kamal logs

# Mở Rails console trên server
kamal console

# Mở bash trong container đang chạy
kamal shell

# Mở Rails dbconsole (PostgreSQL)
kamal dbc

# Xem trạng thái container
kamal app details

# Rollback về version trước
kamal rollback
```

> Các alias `console`, `shell`, `logs`, `dbc` đã được định nghĩa trong
> `config/deploy.yml` → `aliases`.

---

## Biến môi trường

Tham khảo `.env.sample` cho các biến mức ứng dụng và `config/deploy.yml` cho các
biến runtime/deploy của container. Các biến quan trọng nhất cho production:

| Biến | Bắt buộc | Mặc định | Ghi chú |
|---|---|---|---|
| `RAILS_MASTER_KEY` | ✅ | — | Giải mã `config/credentials.yml.enc` |
| `DATABASE_URL` | ✅ | — | URL kết nối PostgreSQL primary |
| `CACHE_DATABASE_URL` | ✅ | — | URL database Solid Cache |
| `QUEUE_DATABASE_URL` | ✅ | — | URL database Solid Queue |
| `CABLE_DATABASE_URL` | ✅ | — | URL database Solid Cable |
| `POSTGRES_PASSWORD` | ✅ | — | Password superuser accessory (`.kamal/secrets`) |
| `POSTGRES_STATEMENT_TIMEOUT` | Tùy chọn | `5000ms` | `statement_timeout` của PostgreSQL |
| `DEVISE_JWT_SECRET_KEY` | Khuyến nghị | fallback về `secret_key_base` | Rotate độc lập với master key |
| `JWT_AUTH_HEADER` | Tùy chọn | `Authorization` | HTTP header vận chuyển access JWT (ví dụ `X-Authorization` khi chạy sau gateway như Beam.cloud) |
| `CORS_ALLOWED_ORIGINS` | Khuyến nghị | `http://localhost:4000` | Danh sách origin browser được Rack::Cors cho phép, phân tách bằng dấu phẩy |
| `DEVISE_MAILER_SENDER` | Khuyến nghị | `noreply@example.com` | Đổi sang địa chỉ/domain gửi mail thật |
| `SOLID_QUEUE_IN_PUMA` | Tùy chọn | `true` | Đặt `false` nếu chạy job worker riêng |
| `JOB_CONCURRENCY` | Tùy chọn | `1` | Số worker thread của Solid Queue |
| `WEB_CONCURRENCY` | Tùy chọn | `1` | Tăng nếu server có nhiều CPU |
| `RAILS_LOG_LEVEL` | Tùy chọn | `info` | Đặt `debug` khi cần trace issue |

Trong lúc boot production, app cũng log warning nếu không có khóa JWT độc lập
qua environment hoặc Rails credentials, hoặc nếu `DEVISE_MAILER_SENDER` vẫn còn
là địa chỉ kiểu placeholder `example.com`.

Browser client chạy khác origin có thể đọc header vận chuyển JWT đã cấu hình
(`JWT_AUTH_HEADER`, mặc định `Authorization`) từ response đăng nhập:
`config/initializers/cors.rb` expose header đó qua `expose: [JWT_AUTH_HEADER]`
và cho phép các request header chuẩn, Beam cũ, và giá trị đã cấu hình.

---

## PostgreSQL và persistence

Dữ liệu production nằm trong PostgreSQL 17, chạy như một Kamal accessory
(`config/deploy.yml` → `accessories.db`). Data directory được lưu qua directory
`data` của accessory, mount tại `/var/lib/postgresql/data`. Ứng dụng dùng bốn
database:

| Database | Mục đích | Ghi chú |
|----------|----------|---------|
| `rails_8_api_authentication_production` | Database Active Record chính | Quan trọng nhất, sao lưu trước tiên |
| `rails_8_api_authentication_production_cache` | Solid Cache | Có thể rebuild |
| `rails_8_api_authentication_production_queue` | Solid Queue | Cần chính sách retention |
| `rails_8_api_authentication_production_cable` | Solid Cable | Cần chính sách retention |

Upload Active Storage local là một vấn đề riêng: chúng được lưu trong volume
`rails_8_api_authentication_storage` mount tại `/rails/storage`, không nằm trong
PostgreSQL. Hãy sao lưu cả hai.

**Sao lưu và phục hồi:**

Dùng `pg_dump` định dạng custom cho từng database. Database primary quan trọng
nhất; cache có thể rebuild; retention của queue/cable phải tuân theo chính sách
đã ghi chép. Tất cả lệnh dưới đây chạy trên **máy deploy**; container accessory
PostgreSQL không chạy SSH, nên bạn điều khiển nó qua Kamal rồi kéo archive ra
khỏi host bằng SSH.

```bash
# Trên máy deploy
mkdir -p backups
backup_file="primary-$(date -u +%Y%m%dT%H%M%SZ).dump"

# 1. Chạy pg_dump bên trong accessory PostgreSQL qua Kamal, lưu vào volume bền vững
bin/kamal accessory exec db --reuse \
  "pg_dump --format=custom --file=/var/lib/postgresql/backups/$backup_file -U rails_auth rails_8_api_authentication_production"
# Lặp lại cho cache, queue, cable với tên database tương ứng.

# 2. Xác nhận tên container đang chạy, rồi kéo archive về máy deploy qua SSH từ
#    $POSTGRES_ACCESSORY_HOST (SSH host thật, không phải Docker hostname)
bin/kamal accessory details db
# Thay nếu lệnh trên báo tên runtime khác
accessory_container=rails_8_api_authentication-db
ssh "$POSTGRES_ACCESSORY_HOST" \
  "docker exec '$accessory_container' cat '/var/lib/postgresql/backups/$backup_file'" \
  > "backups/$backup_file"

# 3. Xác minh archive cục bộ trước khi tin dùng
pg_restore --list "backups/$backup_file" >/dev/null
sha256sum "backups/$backup_file" > "backups/$backup_file.sha256"

# 4. Upload cả dump và checksum sang off-site/object storage (bản sao trên cùng
#    server không phải backup disaster-recovery)
# 5. Xóa/rotate các archive cũ trên accessory theo chính sách retention
```

- `$POSTGRES_ACCESSORY_HOST` là SSH host thật, không phải Docker hostname.
- Xác nhận tên container đang chạy bằng `bin/kamal accessory details db`.
- Upload cả dump và checksum sang off-site/object storage.
- Xóa/rotate archive trên accessory theo chính sách retention.
- Restore drill chỉ được dùng database non-production đã được xác minh.

```bash
# Chỉ phục hồi VÀO target non-production đã được xác minh
# Chỉ dùng trên máy deploy: nạp giá trị này từ password manager trước.
# Không bao giờ thêm STAGING_DATABASE_URL vào secrets production.
: "${STAGING_DATABASE_URL:?Set a verified non-production PostgreSQL URL}"

pg_restore --clean --if-exists \
  --dbname="$STAGING_DATABASE_URL" \
  "backups/$backup_file"
# Định kỳ chạy restore drill vào staging và xác minh dữ liệu trước khi
# phụ thuộc vào archive trong sự cố thật.
```

- `$backup_file` chỉ tồn tại trong shell hiện tại: chọn lại (xem bước 1) nếu mở shell mới.
- Nạp `STAGING_DATABASE_URL` từ password manager/environment; phải là target
  non-production đã được xác minh. Password của nó phải được encode (URL-safe),
  không để raw.

Với restore chạy bằng script, dùng file `.pgpass` mode `0600` hoặc cơ chế secret
của nhà cung cấp; không bao giờ đưa password vào shell history.

**Ngân sách kết nối:**

Giữ tổng số kết nối dưới `max_connections` của PostgreSQL (hoặc giới hạn
pooler):

```text
số kết nối tối đa = WEB_CONCURRENCY × RAILS_MAX_THREADS
                  + JOB_CONCURRENCY × số thread Solid Queue
                  + headroom cho deployment/console
```

Mỗi URL database trong `config/database.yml` là một connection pool riêng, vì
vậy hãy nhân ngân sách primary lên bốn database khi định cỡ server.

**Truy cập database:**

```bash
kamal accessory exec db -- psql -U rails_auth rails_8_api_authentication_production
```

---

## Non-goal: không cutover dữ liệu SQLite trực tiếp

Branch này thay SQLite baseline bằng PostgreSQL cho các thay đổi tương lai; nó
**không** copy các row SQLite đang hoạt động. Một cutover thực sự cần kiểm kê
row, thứ tự foreign key, reset sequence, count/checksum, diễn tập, cửa sổ
freeze, và kế hoạch rollback — tất cả nằm ngoài phạm vi. Coi variant SQLite
(khôi phục được tại tag `baseline-sqlite-v1`) là điểm khôi phục trước migration,
và chỉ phục hồi bản sao PostgreSQL vào target non-production đã xác minh.

---

## Health Check

Container được kiểm tra sức khỏe qua 2 lớp:

1. **Docker HEALTHCHECK** (trong Dockerfile): `curl -f http://localhost/up` —
   30s interval, 5s timeout, bắt đầu sau 60s
2. **Kamal proxy healthcheck** (trong `config/deploy.yml`): `GET /up` — 10s
   interval, 5s timeout — dùng để quyết định route traffic đến container mới trong rolling deploy

Endpoint `/up` trả `200` khi Rails boot bình thường, `500` nếu có exception khi
khởi động.

---

## Checklist trước deploy lần đầu

- [ ] `config/deploy.yml` — đã thay hết placeholder `<...>`
- [ ] `config/master.key` — có trên máy deploy, không commit vào git
- [ ] DNS đã trỏ domain về IP server
- [ ] `KAMAL_REGISTRY_PASSWORD` có trong shell
- [ ] `POSTGRES_PASSWORD` đã đặt và bốn database URL đã thêm vào
  `.kamal/secrets`
- [ ] Docker registry đã tạo (Docker Hub, ghcr.io, v.v.)
- [ ] Server đã mở port 80 và 443
- [ ] (Tùy chọn) `DEVISE_JWT_SECRET_KEY` đã tạo và thêm vào `.kamal/secrets`
