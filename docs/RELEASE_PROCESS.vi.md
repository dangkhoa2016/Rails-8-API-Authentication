# Quy trình phát hành

Tài liệu này là release-engineering contract chuẩn cho các lần phát hành semantic-version công khai của Rails 8 API Authentication.

## Mô hình phát hành

Lần phát hành semantic-version công khai đầu tiên đã được tạo trực tiếp dưới dạng stable `v1.0.0`. Không có prerelease tag công khai bắt buộc trước đó. Release-hardening chỉ được merge vào `main` sau khi mọi pre-merge gate bắt buộc PASS.

Các trạng thái release là `NOT RUN`, `BLOCKED`, `FAIL`, `PASS`. Chỉ `PASS` thỏa gate bắt buộc. Evidence thiếu hoặc chỉ một phần không bao giờ được suy diễn thành PASS.

## Frozen baseline contract

Hai source line database pre-1.0 tiếp tục là historical baseline bất biến:

- `baseline/postgresql-v1` -> `6897c773ec1321401e52c21c63870a72d01ca349`
- `baseline/sqlite-v1` -> `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`

Hai tag bất biến `baseline-postgresql-v1` và `baseline-sqlite-v1` không được di chuyển hoặc rewrite trong quá trình stable release.

## Gate 1 — Repository hardening

PASS yêu cầu:

- cú pháp GitHub Actions workflow hợp lệ;
- CI chạy trên pull request, manual dispatch và push vào `main`;
- Brakeman, bundler-audit, RuboCop, repository policy, Ruby/PostgreSQL 3.2/3.3/4.0, custom JWT-header, schema-load và coverage đều green;
- release hardening không thay đổi authentication feature semantics.

## Gate 2 — Release contract

PASS yêu cầu:

- `CHANGELOG.md` tồn tại và ghi đúng các pre-1.0 milestone;
- `docs/RELEASE_PROCESS.md` và `docs/RELEASE_PROCESS.vi.md` có yêu cầu tương đương;
- không còn mandatory release step chưa giải quyết;
- release tooling thuộc repository phải validate fail closed.

Offline validation:

```bash
bash scripts/release/test_release_tools.sh
bash scripts/release/verify_repository.sh
```

## Gate 3 — Published artifact verification

Chạy:

```bash
bash scripts/release/verify_ghcr.sh
```

Script phải PASS cho cả hai database variant và xác minh:

- frozen baseline branch SHA;
- canonical moving variant tag;
- tag `-v1`;
- immutable source-SHA tag;
- `linux/amd64` và `linux/arm64` trên canonical multi-platform indexes;
- architecture-specific aliases.

Thiếu tag, revision mismatch, thiếu hoặc trùng required platform, hoặc frozen baseline bị di chuyển đều là release blocker.

## Gate 4 — Deployment portability

Recipe Beam.cloud và Hugging Face Spaces không được chứa private credential material đã commit. Required runtime secrets và provider limitations phải được nêu rõ.

Beam dùng PostgreSQL và có thể đặt:

```text
JWT_AUTH_HEADER=X-Authorization
```

khi provider path chặn header chuẩn `Authorization`. Việc này chỉ đổi JWT transport; signing, claims, expiration và application authorization semantics không đổi.

Hugging Face Spaces dùng SQLite baseline cho self-contained demo. Hosting ephemeral/free không được mô tả là HA, có SLA hoặc durable database hosting.

## Gate 5 — Release readiness

Gate 5 được đánh giá trên một exact stable candidate commit và yêu cầu toàn bộ:

- full GitHub CI PASS trên exact candidate SHA;
- `scripts/release/verify_repository.sh` PASS;
- `scripts/release/verify_ghcr.sh` PASS;
- ít nhất một real full deployment smoke PASS bao gồm `/up`, `/users/sign_in`, `/user/profile`;
- GitHub báo repository controls đang active;
- version-specific acceptance record dưới `docs/releases/` chỉ ghi observed values;
- không còn known release-blocking issue.

Health-only validation không đủ. Output có `NOT RUN authentication smoke` không thỏa Gate 5.

Full deployment command:

```bash
API_BASE_URL="$DEPLOYMENT_URL" \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER="$JWT_AUTH_HEADER" \
  scripts/release/smoke_deployment.sh
```

Credential chỉ đến từ runtime secret store hoặc operator shell và không được commit.

## Runtime provenance

Stable source candidate và frozen runtime artifacts là hai chiều evidence riêng:

- CI và repository checks xác định exact stable source candidate SHA.
- `verify_ghcr.sh` xác minh immutable PostgreSQL/SQLite baseline artifacts.
- Provider deployment có thể cố ý derive từ frozen baseline image nếu recipe ghi như vậy.
- Acceptance phải ghi đúng running image/source provenance và tuyệt đối không tuyên bố provider container được build từ stable candidate SHA nếu điều đó chưa được quan sát.

## Ngoại lệ lịch sử `v1.0.0`

Annotated tag `v1.0.0` đã publish hiện trỏ tới accepted implementation commit `b73d8e1acbb1017fb4b384f254c1347645e801ba`. Final acceptance-evidence commit và merge của nó vào `main` xảy ra sau đó.

Tag đã publish này là historical và bất biến. Không di chuyển, xóa, tạo lại hoặc retarget `v1.0.0` để khớp policy hiện tại. Mọi correction sau publication phải dùng semantic version tiếp theo.

## Tạo stable release mới

Với mọi release sau `v1.0.0`, publication dùng trạng thái repository đã được integrate vào `main` và verify sau merge làm release identity.

Dùng annotated tag và không di chuyển tag sau khi publish. Nếu source thay đổi trước publication, chạy lại các gate bị ảnh hưởng. Nếu source thay đổi sau khi version đã publish, tạo semantic version tiếp theo thay vì di chuyển tag đã publish.

Release tag target phải thỏa toàn bộ:

- target là exact `main` commit được tạo bởi reviewed release integration;
- mandatory push-to-`main` CI đã hoàn tất với PASS trên exact SHA đó;
- exact SHA chứa final version-specific acceptance record;
- exact SHA vẫn là current verified `main` release state ngay trước khi tạo tag.

Tag exact post-merge `main` commit đã PASS mandatory post-merge CI.
Không tag candidate cũ hơn, evidence-only commit hoặc pre-merge branch head cho release mới.

## Thứ tự merge và publication cho release sau `v1.0.0`

1. Qualify exact release candidate trên reviewed release branch.
2. Ghi version-specific acceptance evidence mà không đổi application semantics, trừ khi chủ ý tạo candidate mới.
3. Re-verify final branch head và toàn bộ mandatory gate bị ảnh hưởng.
4. Merge reviewed release pull request vào `main`.
5. Chờ mandatory push-to-`main` CI và yêu cầu PASS trên exact merge/integration SHA.
6. Re-verify exact SHA đó là intended current release state và frozen artifacts cùng repository controls vẫn hợp lệ.
7. Tạo annotated semantic-version tag trên exact verified post-merge `main` SHA đó.
8. Publish GitHub release dạng non-prerelease cho immutable tag đó.
9. Chạy post-tag artifact verification và các publication-time deployment health check mà acceptance contract của version yêu cầu.

Candidate CI tiếp tục là evidence cho implementation lineage, nhưng release tag xác định fully integrated repository state mà người dùng nhận được khi checkout version đã publish.

## Rollback

Provider deployment thất bại rollback về image reference đã verify trước đó. Database rollback tuân theo backup/restore process của provider/database.

SQLite và PostgreSQL baselines là source/artifact recovery points; chúng không phải live-data backup có thể hoán đổi và không ngụ ý row-level migration tự động giữa hai database engine.

## GitHub repository controls

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

Các control này chỉ PASS sau khi GitHub báo active. Control không thể xác minh là BLOCKED, không phải PASS.
