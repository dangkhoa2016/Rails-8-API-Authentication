# Deploy lên Modal.com — Public Production-Style Demo

> 🌐 Language / Ngôn ngữ: [English](README.md) | **Tiếng Việt**

Recipe này deploy Rails API thành một **public production-style demo** trên Modal.com. Người khác chỉ cần URL HTTPS thông thường để test API; họ không cần Modal credential. Rails tiếp tục dùng header chuẩn `Authorization: Bearer <JWT>`.

Đây chủ ý là cấu hình demo, không phải dịch vụ HA/SLA và không phải cam kết chống DDoS hoàn toàn.

## Runtime profile

`app.py` trong repo khóa profile demo ở các giá trị sau:

- public `@modal.web_server(..., requires_proxy_auth=False)`;
- `min_containers=0`, `max_containers=1`;
- `buffer_containers=0`, `scaledown_window=60` giây;
- CPU-only, `cpu=1.0`, `memory=1024` MiB;
- thêm Python 3.12 vào Docker image của repo để Modal chạy Function runtime;
- Rails/Puma lắng nghe port `4000`, `RAILS_MAX_THREADS=3`;
- `RACK_ATTACK_CACHE_STORE=memory`.

Trần một container giới hạn việc serverless scale ngang. Nó **không** ngăn attacker gửi traffic đều đặn để giữ container duy nhất đó luôn chạy.

## 1. Cài và đăng nhập Modal

```bash
python3 -m pip install --upgrade modal
modal setup
```

Nếu dùng Modal environment riêng, truyền `--env NAME` cho deploy script của repo.

## 2. Chuẩn bị PostgreSQL

Production yêu cầu bốn PostgreSQL database **khác nhau**:

- database chính của ứng dụng;
- database cho Solid Cache;
- database cho Solid Queue;
- database cho Solid Cable.

Có thể dùng managed PostgreSQL hoặc một PostgreSQL service khác mà Modal truy cập được. Các URL phải vượt qua production database validation hiện có của ứng dụng.

## 3. Tạo Modal runtime secret

Tạo named secret một lần. Các giá trị bên dưới chỉ là placeholder; hãy lấy giá trị thật từ password manager hoặc deployment environment của bạn.

```bash
modal secret create rails-api-production \
  RAILS_MASTER_KEY='...' \
  DATABASE_URL='postgresql://...' \
  CACHE_DATABASE_URL='postgresql://...' \
  QUEUE_DATABASE_URL='postgresql://...' \
  CABLE_DATABASE_URL='postgresql://...'
```

Repository không đọc hoặc in các giá trị này trong lúc deploy. `app.py` yêu cầu năm key trên khi Modal resolve secret.

`DEVISE_JWT_SECRET_KEY` là optional. Nếu key đã nằm trong Rails encrypted credentials thì không cần tạo thêm Modal environment variable. Nếu muốn rotate JWT key độc lập qua Modal, có thể thêm nó vào cùng secret:

```bash
modal secret create --force rails-api-production \
  RAILS_MASTER_KEY='...' \
  DATABASE_URL='postgresql://...' \
  CACHE_DATABASE_URL='postgresql://...' \
  QUEUE_DATABASE_URL='postgresql://...' \
  CABLE_DATABASE_URL='postgresql://...' \
  DEVISE_JWT_SECRET_KEY='...'
```

Không ghi secret thật vào file trong repository.

## 4. Deploy

Từ một repository checkout sạch:

```bash
./deploy/modal/deploy.sh
```

Nếu dùng Modal environment có tên:

```bash
./deploy/modal/deploy.sh --env main
```

Script sẽ fail trước khi deploy nếu:

- Modal CLI không có;
- `deploy/modal` có file chưa commit/untracked;
- `app.py` không compile;
- không thể xác thực/lookup Modal environment;
- named secret `rails-api-production` chưa tồn tại.

Deploy script không nhận secret value qua positional/CLI argument.

## 5. Test public URL

Modal in ra public web endpoint sau khi deploy. Người test phải gọi được endpoint này mà không cần `Modal-Key` hoặc `Modal-Secret`.

Health check:

```bash
curl -i https://<your-modal-url>/up
```

Expected: HTTP `200`.

Chạy smoke test cơ bản không cần tài khoản:

```bash
./deploy/modal/smoke.sh https://<your-modal-url>
```

Lệnh này chứng minh `/up` là public; phần authentication/rate-limit sẽ báo `NOT RUN` nếu chưa cung cấp demo account.

Để chạy acceptance smoke đầy đủ, truyền một demo account đang tồn tại qua environment:

```bash
SMOKE_EMAIL='demo@example.com' \
SMOKE_PASSWORD='...' \
./deploy/modal/smoke.sh https://<your-modal-url>
```

Full smoke yêu cầu tất cả điều kiện sau PASS:

- public `/up` trả `200`;
- Rails sign-in hoạt động;
- sign-in response expose Rails access JWT qua `Authorization: Bearer ...`;
- JWT đó gọi được `/user/profile` bằng header `Authorization` chuẩn;
- thay đổi caller-supplied `X-Forwarded-For` không né được `sign_in/ip` throttle;
- `POST /users/tokens/refresh` trả `429` ở request thứ 21 trong throttle window.

Smoke script không in password, JWT, refresh token, cookie hoặc Modal secret value.

## 6. Rate-limit profile

Modal demo giữ các auth rule hiện tại và bổ sung hai abuse ceiling:

| Rule | Giới hạn |
|---|---:|
| Global API, trừ `/up` | 300 request / 60 giây / IP |
| Sign-in | 5 request / 60 giây / IP |
| Sign-in | 10 request / 60 giây / email |
| Registration | 10 request / giờ / IP |
| Password reset | 5 request / giờ / IP |
| Refresh-token endpoint | 20 request / 60 giây / IP |

Modal đặt `RACK_ATTACK_CACHE_STORE=memory` để counter của Rack::Attack không biến PostgreSQL/Solid Cache thành hot path khi gặp HTTP flood. Cấu hình này chỉ an toàn với recipe hiện tại khi `max_containers=1` vẫn là invariant.

Nếu tăng giới hạn container của Modal, hãy chuyển Rack::Attack trở lại shared cache (`RACK_ATTACK_CACHE_STORE=rails`) hoặc bổ sung một shared limiter store khác. Counter nằm trong memory của từng process không tạo ra global limit giữa nhiều container.

## 7. Acceptance cho client IP

Không cấu hình Rails/Rack tin tưởng tùy ý mọi giá trị `X-Forwarded-For`. Nếu attacker có thể tự chọn IP discriminator thì họ có thể né IP-based throttle.

Real deployment smoke cố ý gửi các giá trị `X-Forwarded-For` khác nhau do caller tự đặt. Deployment **không được coi là hardened** nếu các giá trị đó giúp né sign-in IP throttle.

Black-box check này chứng minh spoof resistance; riêng nó chưa chứng minh Modal luôn gán chính xác global public IP riêng biệt cho từng visitor. Nếu cần fairness giữa người dùng từ nhiều network khác nhau, hãy kiểm chứng thêm trước khi biến demo thành public service chạy dài hạn.

## 8. Logs và vận hành

Xem logs gần đây:

```bash
modal app logs rails-8-api-authentication
```

Theo dõi logs realtime:

```bash
modal app logs rails-8-api-authentication -f
```

Liệt kê app:

```bash
modal app list --json
```

Dừng public demo và terminate container đang chạy:

```bash
modal app stop rails-8-api-authentication -y
```

Khi cần chạy demo lại, deploy bằng `./deploy/modal/deploy.sh`.

## Public và private Modal mode

Repository cố ý mặc định **public** Modal endpoint để người ngoài có thể test demo bình thường.

Modal proxy authentication có thể hữu ích cho private demo. Khi đó Modal credential là một ingress gate bổ sung. Rails JWT vẫn nên độc lập và tiếp tục đi qua `Authorization: Bearer <JWT>`. Public recipe trong thư mục này không bật Modal proxy auth và không dùng `Modal-Key` hoặc `Modal-Secret`.

## Giới hạn bảo mật và chi phí

Defense-in-depth path là:

```text
Internet
  -> Modal managed ingress
  -> max_containers=1
  -> Rack::Attack
  -> Rails / Devise JWT
  -> PostgreSQL
```

Cấu hình này giúp giảm application-level abuse và ngăn autoscaling ngang không giới hạn, nhưng Rack::Attack không phải dịch vụ chống volumetric DDoS. Traffic đã tới Modal trước khi Rails có thể trả `429`, và attacker vẫn có thể giữ container duy nhất hoạt động liên tục. Nếu demo trở thành public service chạy thường trực, hãy thêm edge WAF/CDN/rate-limiter phù hợp và đánh giá lại các giả định single-container/demo.
