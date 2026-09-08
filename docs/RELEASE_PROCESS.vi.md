# Quy trình phát hành

Tài liệu này là hợp đồng release-engineering chính thức cho bản phát hành semantic-versioning đầu tiên của Rails 8 API Authentication.

## Trạng thái phát hành

`NOT RUN`, `BLOCKED`, `FAIL` và `PASS` là bốn trạng thái khác nhau. Chỉ `PASS` mới thỏa một release gate bắt buộc. `NOT RUN` và `BLOCKED` không bao giờ được xem như xác minh thành công.

## Hợp đồng baseline đã khóa

Hai source line database trước v1.0 là baseline lịch sử đã khóa:

- `baseline/postgresql-v1` -> `6897c773ec1321401e52c21c63870a72d01ca349`
- `baseline/sqlite-v1` -> `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`

Hai immutable tag `baseline-postgresql-v1` và `baseline-sqlite-v1` không được di chuyển hoặc rewrite trong quá trình RC/stable.

## Gate 1 — Repository hardening

Bắt buộc:

- cú pháp GitHub Actions workflow hợp lệ;
- CI chạy cho pull request, manual dispatch và push vào `main`;
- các job Brakeman, bundler-audit, RuboCop, repository-policy, Ruby/PostgreSQL matrix, custom JWT-header, schema-load và coverage hiện có vẫn xanh;
- release hardening không thay đổi semantics của tính năng authentication.

## Gate 2 — Release contract

Bắt buộc:

- `CHANGELOG.md` tồn tại và ghi đúng hai baseline milestone;
- `docs/RELEASE_PROCESS.md` và `docs/RELEASE_PROCESS.vi.md` có yêu cầu tương đương;
- không còn bước phát hành bắt buộc nào chưa được xác định.

Kiểm tra offline:

```bash
bash scripts/release/test_release_tools.sh
bash scripts/release/verify_repository.sh
```

## Gate 3 — Xác minh artifact đã publish

Chạy:

```bash
bash scripts/release/verify_ghcr.sh
```

Script phải PASS cho cả hai database variant và xác minh:

- frozen baseline branch SHA;
- canonical moving variant tag;
- tag `-v1`;
- immutable source-SHA tag;
- `linux/amd64` và `linux/arm64` trên canonical multi-platform index;
- architecture-specific aliases.

Thiếu tag, revision không khớp, thiếu required platform, duplicate required platform hoặc baseline branch bị di chuyển đều là release blocker.

## Gate 4 — Deployment portability

Recipe cho Beam.cloud và Hugging Face Spaces không được chứa private credential đã commit. Runtime secret bắt buộc và giới hạn của provider phải được mô tả rõ.

Beam dùng PostgreSQL và có thể đặt:

```text
JWT_AUTH_HEADER=X-Authorization
```

khi provider path chặn header chuẩn `Authorization`. Thuật toán ký JWT, secret, claims và semantics authorization của ứng dụng không thay đổi.

Hugging Face Spaces dùng SQLite baseline cho demo tự chứa. Hosting ephemeral/free không được mô tả như HA, dịch vụ có SLA hoặc nơi lưu database bền vững.

## Gate 5 — RC readiness

Gate 5 được đánh giá trên đúng một candidate commit và yêu cầu tất cả điều kiện sau:

- toàn bộ GitHub CI PASS trên exact candidate SHA;
- `scripts/release/verify_repository.sh` PASS;
- `scripts/release/verify_ghcr.sh` PASS;
- ít nhất một deployment smoke thực tế PASS đầy đủ cho `/up`, `/users/sign_in` và `/user/profile`;
- release acceptance evidence chỉ chứa giá trị quan sát thực tế;
- không còn release-blocking issue đã biết.

Health-only validation không đủ cho Gate 5. Output có `NOT RUN authentication smoke` không thỏa gate này.

Lệnh deployment đầy đủ:

```bash
API_BASE_URL="$DEPLOYMENT_URL" \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER="$JWT_AUTH_HEADER" \
  scripts/release/smoke_deployment.sh
```

Credential phải đến từ runtime secret store hoặc shell của operator và không được commit.

## Tạo `v1.0.0-rc.1`

Chỉ tạo RC sau khi Gate 5 PASS. Ghi accepted implementation SHA và evidence vào `docs/releases/v1.0.0-rc.1-acceptance.md`.

Dùng annotated tag và không di chuyển tag sau khi publish. Nếu source cần thay đổi sau khi RC đã tag, tạo RC identifier tiếp theo thay vì retag `v1.0.0-rc.1`.

## Promote `v1.0.0`

Chỉ promote lên `v1.0.0` sau khi accepted RC lineage hoàn tất acceptance period mà không xuất hiện release-blocking regression, stable release notes đã hoàn thiện, repository controls đã xác minh, Docker baseline verification vẫn PASS và ít nhất một deployment acceptance path vẫn PASS.

Stable tag là annotated tag mới. Stable promotion không rewrite RC tag.

## Rollback

Provider deployment thất bại thì rollback về image reference đã được xác minh trước đó cho provider đó. Database rollback tuân theo quy trình backup/restore của provider hoặc database.

SQLite và PostgreSQL baselines là source/artifact recovery points; chúng không phải live-data backup có thể thay thế lẫn nhau và không hàm ý migration row tự động giữa hai database engine.

## GitHub repository controls

Policy mục tiêu:

### `main`

- require pull request before merge;
- require mandatory CI status checks;
- block force pushes;
- block deletion.

### `baseline/postgresql-v1`

- block force pushes;
- block deletion.

### `baseline/sqlite-v1`

- block force pushes;
- block deletion.

Các control này chỉ là `PASS` khi GitHub báo chúng đã được bật. Nếu integration hiện tại không có quyền admin hoặc không đọc được protection endpoint cần thiết thì trạng thái là `BLOCKED`, không phải `PASS`.
