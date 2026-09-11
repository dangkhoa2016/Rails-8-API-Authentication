# Deploy lên Modal.com — Public Production-Style Demo

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Recipe này deploy Rails API thành public production-style demo trên Modal.com. Rails tiếp tục dùng `Authorization: Bearer <JWT>` chuẩn.

## Runtime profile

- public `@modal.web_server(..., requires_proxy_auth=False)`;
- `min_containers=0`, `max_containers=1`;
- `buffer_containers=0`, `scaledown_window=60`;
- CPU-only, `cpu=1.0`, `memory=1024` MiB;
- Rails/Puma port `4000`, `RAILS_MAX_THREADS=3`;
- `RACK_ATTACK_CACHE_STORE=memory`;
- `SOLID_QUEUE_IN_PUMA=true`, `JOB_CONCURRENCY=1`;
- `RAILS_ENV=production`.

Solid Queue chạy bên trong Puma khi container đang thức. Vì vậy web demo và
queue supervisor cùng nằm trong runtime bị giới hạn, có thể scale-to-zero.

## Rails production credentials

Dùng đúng cặp environment-specific credentials chuẩn của Rails:

```text
config/credentials/production.yml.enc   # được commit
config/credentials/production.key       # tuyệt đối không commit
```

Tạo/sửa local:

```bash
unset RAILS_MASTER_KEY
export EDITOR=nano
bin/rails credentials:edit --environment production
```

Nội dung decrypted nên có tối thiểu:

```yaml
secret_key_base: <Rails secret dài và ngẫu nhiên>
admin_email: <admin email thật>
admin_password: <admin password thật>
devise_jwt_secret_key: <Rails secret dài và ngẫu nhiên>
```

Chỉ commit `config/credentials/production.yml.enc`. Xem [CREDENTIALS.vi.md](CREDENTIALS.vi.md) để biết quy trình đầy đủ.

## Modal runtime secret

Tạo named secret `rails-api-production` từ JSON file nằm ngoài repository, chỉ chứa:

- `RAILS_MASTER_KEY` — chính xác nội dung của `config/credentials/production.key`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`.

```bash
chmod 600 "$HOME/.config/rails-api-production.json"
modal secret create rails-api-production \
  --from-json "$HOME/.config/rails-api-production.json"
```

`DEVISE_JWT_SECRET_KEY`, `ADMIN_EMAIL`, `ADMIN_PASSWORD` không là Modal secret key riêng vì chúng nằm trong Rails production encrypted credentials.

## Deploy

```bash
./deploy/modal/deploy.sh
```

Preflight fail nếu `production.yml.enc` bị thiếu, rỗng, chưa Git-track hoặc dirty; nếu `production.key` bị Git-track; nếu Modal authentication/secret lookup thất bại; hoặc deployment files đang dirty.

Modal chạy `db:prepare` rồi `db:seed` trước Puma. Lần bootstrap đầu tạo admin
được cấu hình; các cold start lặp lại chỉ tìm admin hiện có và không ghi đè
credentials của nó.

## Ngữ nghĩa queue khi scale-to-zero

Vì `min_containers=0`, Modal có thể dừng web container sau khoảng thời gian
idle. Solid Queue chạy bên trong Puma khi container đang thức, nên hai cleanup
task `every hour` không phải cam kết chạy đúng mỗi giờ 24/7 cho demo profile
này. Nếu cần thực thi đúng theo wall clock, hãy dùng worker/task được schedule
riêng thay vì giữ public demo luôn warm.

## Public acceptance

```bash
curl -i https://<your-modal-url>/up
./deploy/modal/smoke.sh https://<your-modal-url>
```

Full smoke còn kiểm tra sign-in, bearer token chuẩn, profile access, khả năng chống bypass sign-in IP throttle bằng caller-controlled X-Forwarded-For và refresh-token throttling.

## Cost và abuse posture

`max_containers=1` giới hạn autoscaling ngang nhưng không ngăn attacker giữ container duy nhất luôn chạy. `RACK_ATTACK_CACHE_STORE=memory` chỉ phù hợp khi single-container vẫn là invariant. Đây là demo profile, không phải HA/SLA hay volumetric DDoS protection.
