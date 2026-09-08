# Recipe triển khai Beam.cloud

Thư mục này chứa recipe PostgreSQL production-style demo đã được sanitize cho Beam.cloud. Đây không phải triển khai HA, không cung cấp SLA và không biến demo thành dịch vụ production multi-tenant.

## Source image

Wrapper mặc định dùng immutable PostgreSQL baseline image:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
```

Baseline source commit là `6897c773ec1321401e52c21c63870a72d01ca349`.

## Beam SDK

`app.py` dùng mô hình Beam v2 SDK hiện tại: `Image.from_dockerfile(...)` và named `Pod` với exposed port, runtime environment variables và secret names. Có thể deploy từ thư mục này bằng:

```bash
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
DEVISE_JWT_SECRET_KEY
CORS_ALLOWED_ORIGINS
```

Không đưa `production.key`, Rails master key, database password, token hoặc private encrypted credential payload vào thư mục này.

## JWT transport trên Beam

Recipe đặt:

```text
JWT_AUTH_HEADER=X-Authorization
```

vì Beam Pod path đã thử nghiệm cho dự án này chặn header chuẩn `Authorization` trước khi request tới Rails. Thay đổi này chỉ tác động HTTP transport header. JWT signing, claims, expiration và application authorization semantics không thay đổi.

Ở provider forward `Authorization` bình thường, tiếp tục dùng header chuẩn.

## Startup

`entrypoint.sh` kiểm tra runtime secret bắt buộc, tùy chọn chạy `db:prepare` với retry có giới hạn, rồi chạy Rails tại `0.0.0.0:8080`. Health endpoint là `/up`.

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
