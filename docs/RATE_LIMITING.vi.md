# Kiểm soát Tần suất Truy cập
> 🌐 Language / Ngôn ngữ: [English](RATE_LIMITING.md) | **Tiếng Việt**

Tài liệu này mô tả cơ chế rate limiting của ứng dụng, các ngưỡng giới hạn hiện tại, cách điều chỉnh, và những lưu ý khi deploy sau reverse proxy.

## Tổng quan

Rate limiting được xử lý bởi gem **rack-attack 6.8** — một Rack middleware chạy trước Rails, kiểm tra và quyết định có cho request đi tiếp hay không trước khi controller được gọi.

**Cache backend:**
- **Test:** `ActiveSupport::Cache::MemoryStore` riêng (không dùng `null_store` của test env vì sẽ không đếm được)
- **Development:** `:memory_store` (counter sẽ reset khi process app khởi động lại)
- **Production:** `:solid_cache_store` (SQLite-backed, không cần Redis)

---

## Các ngưỡng giới hạn hiện tại

| Rule | Endpoint | Method | Giới hạn | Cửa sổ | Key |
|---|---|---|---|---|---|
| `sign_in/ip` | `/users/sign_in` | POST | 5 request | 60 giây | IP address |
| `sign_in/email` | `/users/sign_in` | POST | 10 request | 60 giây | Email trong body |
| `registration/ip` | `/users` | POST | 10 request | 1 giờ | IP address |
| `password_reset/ip` | `/users/password` | POST | 5 request | 1 giờ | IP address |

Hành vi quan trọng:
- Rack::Attack chạy trước controller, nên những request sau đó trả `401` hoặc `422` vẫn làm tăng counter.
- Trong repo này chỉ các endpoint auth ở bảng trên bị throttle.
- Localhost (`127.0.0.1`, `::1`) và `/up` được safelist nên sẽ không kích hoạt các giới hạn này.

### Safelist (không bao giờ bị throttle)

| Rule | Điều kiện |
|---|---|
| `allow health check` | Path là `/up` |
| `allow localhost` | IP là `127.0.0.1` hoặc `::1` |

---

## Response khi bị throttle

HTTP **429 Too Many Requests**, header `Retry-After` chứa số giây còn lại của cửa sổ throttle:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 60

{"error":"Too many requests. Please try again later."}
```

Response này nhất quán với error contract của toàn ứng dụng: `{ "error": "..." }` (singular key).

---

## Lý do có 2 rule cho sign_in

| Rule | Phòng chống |
|---|---|
| `sign_in/ip` (5/60s) | Brute force từ một IP tấn công nhiều tài khoản khác nhau |
| `sign_in/email` (10/60s) | Credential stuffing nhắm vào một tài khoản cụ thể từ nhiều IP khác nhau |

Hai rule hoạt động độc lập. Một request có thể kích hoạt cả hai cùng lúc nếu cùng IP đã đạt 5 lần AND email đó đã bị thử 10 lần.

**Cách đọc email từ JSON body:**

```ruby
body = req.env["rack.input"].read
req.env["rack.input"].rewind      # rewind để body vẫn available cho Rails
email = JSON.parse(body).dig("user", "email").to_s.downcase.presence
```

---

## Điều chỉnh ngưỡng

Tất cả config nằm trong `config/initializers/rack_attack.rb`. Thay đổi `limit:` và `period:` trực tiếp:

```ruby
# Ví dụ: nới lỏng sign_in lên 10 lần / 60s
throttle("sign_in/ip", limit: 10, period: 60) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

# Ví dụ: thắt chặt registration xuống 3 lần / 1 giờ
throttle("registration/ip", limit: 3, period: 3600) do |req|
  req.ip if req.path == "/users" && req.post?
end
```

Sau khi thay đổi, chạy lại tests để xác nhận:

```bash
bin/rails test test/integration/rate_limit_test.rb
```

> Nếu thay đổi `limit:`, nhớ cập nhật test trong `test/integration/rate_limit_test.rb` cho khớp.

---

## Test thủ công

Nếu chỉ chạy vòng lặp `curl` vào `localhost` trong môi trường development mặc định, bạn **sẽ không trigger được throttle** vì localhost đã được safelist rõ ràng.

Các cách test phù hợp hơn:

1. Chạy `bin/rails test test/integration/rate_limit_test.rb`.
2. Gọi app qua hostname không phải loopback hoặc qua môi trường preview/deploy.
3. Tạm comment safelist `allow localhost` trong `config/initializers/rack_attack.rb` khi cần debug.

Ví dụ sau khi bỏ safelist localhost, hoặc khi gọi qua host không phải loopback:

```bash
BASE_URL=http://localhost:3000 # dùng port local thực tế của bạn, ví dụ 4000 nếu copy nguyên .env.sample

# Trigger sign_in/ip (6 lần, lần 6 phải nhận 429)
for i in $(seq 1 6); do
  echo "--- Request $i ---"
  curl -s -o /dev/null -w "%{http_code}" -X POST ${BASE_URL}/users/sign_in \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"test@example.com","password":"wrong"}}'
  echo
done
```

Expected output: `401 401 401 401 401 429`

---

## Lưu ý khi deploy sau reverse proxy / load balancer

**Vấn đề:** `req.ip` trong Rack::Attack mặc định đọc `REMOTE_ADDR`. Nếu ứng dụng đứng sau Nginx, Cloudflare, hay load balancer, `REMOTE_ADDR` sẽ là IP của proxy — **tất cả request sẽ dùng chung một counter** và legitimate users sẽ bị block oan.

**Giải pháp:** Cấu hình Rails nhận `X-Forwarded-For` từ trusted proxies:

```ruby
# config/application.rb
config.action_dispatch.trusted_proxies = [
  ActionDispatch::RemoteIp::TRUSTED_PROXIES,
  IPAddr.new("10.0.0.0/8"),     # IP range của load balancer nội bộ
  IPAddr.new("203.0.113.1/32")  # IP cụ thể của Nginx/Cloudflare
]
```

Sau đó trong `rack_attack.rb`, dùng `req.ip` sẽ tự động trả về IP thực của client (được extract từ `X-Forwarded-For`).

> **Cảnh báo bảo mật:** Chỉ tin tưởng `X-Forwarded-For` từ các proxy bạn kiểm soát. Nếu cấu hình sai, attacker có thể giả mạo IP bằng cách tự thêm `X-Forwarded-For` header.

---

## Disable tạm thời (chỉ dùng khi debug)

```ruby
# Trong Rails console trên server đang chạy
Rack::Attack.enabled = false

# Bật lại
Rack::Attack.enabled = true
```

Hoặc trong test:

```ruby
setup { Rack::Attack.enabled = false }
teardown { Rack::Attack.enabled = true }
```

---

## Các file liên quan

| File | Vai trò |
|---|---|
| `config/initializers/rack_attack.rb` | Toàn bộ config: safelists, throttles, throttled_responder |
| `config/application.rb` | `config.middleware.use Rack::Attack` — bắt buộc cho API-only app |
| `test/integration/rate_limit_test.rb` | 5 tests bao phủ tất cả throttle rules |
