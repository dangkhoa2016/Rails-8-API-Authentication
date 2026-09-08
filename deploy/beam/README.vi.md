# Recipe triển khai Beam.cloud

Thư mục này chứa recipe PostgreSQL production-style demo đã được sanitize cho Beam.cloud. Đây không phải triển khai HA, không cung cấp SLA và không biến demo thành dịch vụ production multi-tenant.

## Source image

Wrapper mặc định dùng immutable PostgreSQL baseline image:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
```

Baseline source commit là `6897c773ec1321401e52c21c63870a72d01ca349`.

## Beam SDK và deploy runner

`app.py` dùng mô hình Beam v2 SDK: `Image.from_dockerfile(...)` và named `Pod` với exposed port, runtime environment variables và Beam secret names.

Đối với release deployment, nên chạy fail-closed runner từ repository root:

```bash
./deploy/beam/deploy.sh
```

Script kiểm tra Beam secret inventory, repository cleanliness, syntax, exact Git SHA rồi mới chạy `beam deploy app.py:pod`.

Vẫn có thể deploy trực tiếp bằng Beam CLI cho trường hợp nâng cao:

```bash
cd deploy/beam
beam deploy app.py:pod
```

Nếu deploy trực tiếp và cần attach optional Beam secrets, phải tự đặt `BEAM_OPTIONAL_SECRETS`, ví dụ:

```bash
BEAM_OPTIONAL_SECRETS='DEVISE_JWT_SECRET_KEY,RAILS_MASTER_KEY' \
  beam deploy app.py:pod
```

## Runtime secret bắt buộc

Tạo các secret này trong Beam project. Chỉ commit tên, tuyệt đối không commit giá trị:

```text
DATABASE_URL
CACHE_DATABASE_URL
QUEUE_DATABASE_URL
CABLE_DATABASE_URL
SECRET_KEY_BASE
CORS_ALLOWED_ORIGINS
```

## Runtime secret tùy chọn

Hai secret sau là optional ở tầng Beam recipe:

```text
DEVISE_JWT_SECRET_KEY
RAILS_MASTER_KEY
```

Ứng dụng hiện resolve JWT signing secret theo đúng thứ tự:

1. `Rails.application.credentials.devise_jwt_secret_key`
2. `ENV["DEVISE_JWT_SECRET_KEY"]`
3. `Rails.application.secret_key_base`

Vì vậy `DEVISE_JWT_SECRET_KEY` không được xem là Beam secret bắt buộc. Nếu secret này tồn tại trong Beam, `deploy.sh` sẽ tự phát hiện và attach vào Pod; nếu không, Rails tiếp tục dùng fallback chain của ứng dụng.

`RAILS_MASTER_KEY` cũng là optional ở tầng Beam recipe, nhưng sẽ cần thiết khi Rails runtime phải giải mã `config/credentials.yml.enc`. Docker build cố ý không chứa `config/master.key`; do đó nếu deployment dựa vào encrypted Rails credentials thì hãy tạo `RAILS_MASTER_KEY` dưới dạng Beam secret. `deploy.sh` sẽ tự attach khi secret này tồn tại.

Tuyệt đối không commit `config/master.key`, production key, database password, token hoặc decrypted credential payload vào thư mục này.

## JWT transport trên Beam

Recipe đặt:

```text
JWT_AUTH_HEADER=X-Authorization
```

vì Beam Pod path đã thử nghiệm cho dự án này chặn header chuẩn `Authorization` trước khi request tới Rails. Thay đổi này chỉ tác động HTTP transport header. JWT signing, claims, expiration và application authorization semantics không thay đổi.

Ở provider forward `Authorization` bình thường, tiếp tục dùng header chuẩn.

## Startup

`entrypoint.sh` kiểm tra các database/application runtime secret bắt buộc, tùy chọn chạy `db:prepare` với retry có giới hạn, rồi chạy Rails tại `0.0.0.0:8080`. Script không bắt buộc `DEVISE_JWT_SECRET_KEY`, vì việc resolve JWT secret thuộc trách nhiệm của Rails application. Health endpoint là `/up`.

## Acceptance

Sau khi deploy, chạy full release smoke bằng credential chỉ tồn tại lúc runtime:

```bash
API_BASE_URL='https://<beam-pod-host>' \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER='X-Authorization' \
  ../../scripts/release/smoke_deployment.sh
```

Health-only check hữu ích cho chẩn đoán nhưng không đủ Gate 5. Full acceptance yêu cầu `/up`, `/users/sign_in` và `/user/profile` đều PASS.
