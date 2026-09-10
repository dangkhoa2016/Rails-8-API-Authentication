# Kiểm soát Tần suất Truy cập
> 🌐 Language / Ngôn ngữ: [English](RATE_LIMITING.md) | **Tiếng Việt**

Tài liệu này mô tả policy Rack::Attack của ứng dụng, cách chọn cache store cho counter, các ngưỡng hiện tại và yêu cầu liên quan đến proxy/client IP.

## Tổng quan

Rate limiting được xử lý bởi **rack-attack 6.8**, được mount rõ ràng trong Rails API-only middleware. Request khớp throttle sẽ bị chặn trước controller với HTTP `429 Too Many Requests`.

### Store cho counter

`config/initializers/rack_attack.rb` resolve store thông qua `RackAttackCacheStore`:

| `RACK_ATTACK_CACHE_STORE` | Hành vi |
|---|---|
| unset / blank | dùng `Rails.cache` |
| `rails` | dùng `Rails.cache` |
| `memory` | dùng `ActiveSupport::Cache::MemoryStore` trong process |
| giá trị nonblank khác | boot fail-closed với `ArgumentError` |

Môi trường test luôn dùng MemoryStore để counter thật sự tăng.

Production thông thường dùng `Rails.cache`; trong repo này đó là `:solid_cache_store`, chia sẻ qua PostgreSQL cache database riêng. Modal public-demo chủ ý đặt `RACK_ATTACK_CACHE_STORE=memory` vì profile đó khóa `max_containers=1`; nhờ vậy request flood không biến việc ghi counter thành hot path trên PostgreSQL.

**Không dùng memory mode cho deployment nhiều container.** Nếu tăng container cap của Modal, hãy chuyển lại `RACK_ATTACK_CACHE_STORE=rails` hoặc thêm một shared limiter store khác.

---

## Các ngưỡng hiện tại

| Rule | Endpoint / phạm vi | Method | Giới hạn | Cửa sổ | Key |
|---|---|---|---:|---:|---|
| `api/ip` | mọi application path trừ `/up` | tất cả | 300 | 60 giây | IP address |
| `sign_in/ip` | `/users/sign_in` | POST | 5 | 60 giây | IP address |
| `sign_in/email` | `/users/sign_in` | POST | 10 | 60 giây | email trong JSON body |
| `registration/ip` | `/users` | POST | 10 | 1 giờ | IP address |
| `password_reset/ip` | `/users/password` | POST | 5 | 1 giờ | IP address |
| `refresh_token/ip` | `/users/tokens/refresh` | POST | 20 | 60 giây | IP address |

Hành vi quan trọng:

- Rack::Attack chạy trước controller, nên request sau đó trả `401` hoặc `422` vẫn tăng counter của rule phù hợp.
- Global `api/ip` ceiling ngăn attacker né endpoint-specific rule chỉ bằng cách rải traffic qua nhiều path.
- Refresh-token rotation bị throttle riêng vì đây là unauthenticated path có token lookup/validation và có thể ghi trạng thái rotation.
- `/up` được safelist và loại khỏi global ceiling.
- Localhost (`127.0.0.1`, `::1`) được safelist trong development/test; production chỉ safelist localhost khi chủ động đặt `RACK_ATTACK_SAFELIST_LOCALHOST=true`.

### Safelist

| Rule | Điều kiện |
|---|---|
| `allow health check` | path là `/up` |
| `allow localhost` | local IP trong development/test, hoặc production opt-in rõ ràng |

---

## Response khi bị throttle

Request bị throttle trả error contract JSON hiện có của ứng dụng:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 60

{"error":"Too many requests. Please try again later."}
```

`Retry-After` lấy từ Rack::Attack window của rule được match.

---

## Vì sao Sign-In có hai rule

| Rule | Phòng chống |
|---|---|
| `sign_in/ip` (5/60s) | brute force từ một IP nhắm vào nhiều account |
| `sign_in/email` (10/60s) | credential stuffing nhắm vào một account từ nhiều IP |

Email discriminator được đọc từ JSON body rồi Rack input được rewind để Rails vẫn parse request bình thường:

```ruby
body = req.env["rack.input"].read(4096) || ""
req.env["rack.input"].rewind
email = JSON.parse(body).dig("user", "email").to_s.downcase.presence
```

---

## Tests

Focused automated coverage:

```bash
bin/rails test test/lib/rack_attack_cache_store_test.rb \
  test/integration/rate_limit_test.rb
```

Integration suite kiểm tra các auth threshold cũ, global ceiling, refresh-token ceiling, JSON `429`, `Retry-After`, và chứng minh `/up` vẫn exempt kể cả vượt global threshold.

Offline Modal configuration tests:

```bash
bash deploy/modal/test_deploy.sh
```

Real Modal deployment còn phải chạy black-box smoke:

```bash
SMOKE_EMAIL='demo@example.com' \
SMOKE_PASSWORD='...' \
./deploy/modal/smoke.sh https://<modal-public-url>
```

Smoke này cố ý thay đổi caller-supplied `X-Forwarded-For`. Nếu các giá trị đó giúp né `sign_in/ip`, Modal acceptance phải FAIL.

---

## Reverse Proxy và Client IP

IP throttling chỉ hữu ích khi caller không thể tự chọn discriminator.

**Không** tin tưởng mù quáng `X-Forwarded-For`, và không tự đoán rồi thêm các proxy CIDR quá rộng. Chỉ trust forwarding header khi ingress provider có contract rõ ràng về proxy boundary và bạn có thể cấu hình chính xác.

Proxy config sai có thể hỏng theo hai hướng trái ngược:

1. mọi visitor đều hiện thành cùng IP của proxy, khiến legitimate users chia sẻ một counter;
2. caller-controlled forwarding header lại được trust, cho phép attacker đổi fake IP để né limit.

Đối với Modal, repository không giả định một undocumented client-IP header contract. Deployment smoke dùng black-box spoof-resistance check. PASS chứng minh caller thay đổi `X-Forwarded-For` không reset được sign-in/IP counter; riêng điều đó **chưa** chứng minh Modal luôn gán public IP riêng biệt hoàn hảo cho từng visitor trên các network khác nhau.

Với infrastructure do bạn kiểm soát (ví dụ reverse proxy riêng hoặc CDN có tài liệu rõ ràng), chỉ cấu hình Rails trusted proxies từ provider range/signal đã xác minh và test hành vi `request.remote_ip` / Rack discriminator trước production.

---

## Điều chỉnh ngưỡng

Tất cả threshold nằm trong `config/initializers/rack_attack.rb`. Nếu thay `limit` hoặc `period`, cập nhật `test/integration/rate_limit_test.rb` trong cùng change và chạy lại focused suite.

Các giá trị hiện tại cố ý tương đối bảo thủ cho authentication API và human-tested public demo. Hãy tune dựa trên legitimate traffic quan sát được; không nới limit chỉ để che một lỗi proxy/IP configuration.

---

## Disable tạm thời (chỉ debug)

```ruby
Rack::Attack.enabled = false
# ...debug...
Rack::Attack.enabled = true
```

Không ship public deployment với Rack::Attack bị disable.

---

## Các file liên quan

| File | Vai trò |
|---|---|
| `lib/rack_attack_cache_store.rb` | fail-closed Rack::Attack store selection |
| `config/initializers/rack_attack.rb` | safelist, throttle, responder |
| `config/application.rb` | mount Rack::Attack trong API-only middleware |
| `test/lib/rack_attack_cache_store_test.rb` | test cache-store policy |
| `test/integration/rate_limit_test.rb` | throttle integration tests |
| `deploy/modal/app.py` | invariant one-container + memory store của Modal |
| `deploy/modal/smoke.sh` | deployed spoof-resistance và throttle acceptance |
