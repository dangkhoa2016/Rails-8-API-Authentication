# Recipe triển khai SQLite trên Hugging Face Spaces

Thư mục này chứa Docker Space recipe đã sanitize cho immutable SQLite baseline:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-1d842b1
```

Baseline source commit là `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`.

Target này là demo deployment. Đây không phải HA, không cung cấp SLA và không được mô tả như database hosting bền vững trừ khi đã gắn storage volume rõ ràng và xác minh thành công.

## Cấu hình Docker Space

Tạo Docker Space và cấu hình YAML front matter trong README của Space:

```yaml
---
title: Rails 8 API Authentication
sdk: docker
app_port: 7860
---
```

Hugging Face hiện tài liệu hóa `7860` là application port mặc định cho Docker Space. Khả năng sử dụng Docker Spaces phụ thuộc plan/account hiện tại đủ điều kiện của Hugging Face.

Copy `Dockerfile` trong thư mục này vào root của Docker Space repository.

## Runtime secret bắt buộc

Cấu hình dưới dạng Space secrets, tuyệt đối không commit giá trị:

```text
SECRET_KEY_BASE
DEVISE_JWT_SECRET_KEY
```

Space variables khuyến nghị:

```text
CORS_ALLOWED_ORIGINS=<actual Space origin>
DEVISE_MAILER_SENDER=noreply@example.invalid
RAILS_LOG_TO_STDOUT=true
JWT_AUTH_HEADER=Authorization
```

Không đưa Rails master key, `production.key`, database password, token hoặc credential riêng tư khác vào source repository của Space.

## Hành vi lưu SQLite

SQLite baseline lưu các production database tại:

```text
/rails/storage/production.sqlite3
/rails/storage/production_cache.sqlite3
/rails/storage/production_queue.sqlite3
/rails/storage/production_cable.sqlite3
```

### Ephemeral demo

Nếu không gắn writable volume, file được ghi trong Docker Space là ephemeral và có thể mất khi Space restart, stop hoặc rebuild. Mode này chỉ phù hợp dữ liệu demo có thể bỏ.

### Persistent demo với Storage Bucket

Nếu cần persistence, gắn Hugging Face Storage Bucket dưới dạng **read-write volume tại `/rails/storage`**. Cách này giữ nguyên database path của Rails baseline. Phải xác minh volume thực tế trong Space runtime trước khi xem dữ liệu là persistent.

Ví dụ dạng lệnh CLI:

```bash
hf spaces volumes set <owner>/<space> \
  -v hf://buckets/<owner>/<bucket>:/rails/storage
```

Volume configuration là trạng thái của provider/account và không được hard-code trong repository này. Storage Buckets có thể có yêu cầu billing/plan riêng.

## Health và acceptance

Rails lắng nghe tại `0.0.0.0:7860`; built-in health endpoint là `/up`.

Sau khi Space chạy, thực hiện full release smoke bằng test credential chỉ tồn tại lúc runtime:

```bash
API_BASE_URL='https://<space-host>' \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER='Authorization' \
  ../../scripts/release/smoke_deployment.sh
```

Health-only PASS chỉ là diagnostic evidence, không đủ release Gate 5. Full acceptance yêu cầu `/up`, `/users/sign_in` và `/user/profile` đều PASS.
