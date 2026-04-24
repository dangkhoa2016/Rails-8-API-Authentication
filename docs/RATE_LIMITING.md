# Rate Limiting
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](RATE_LIMITING.vi.md)

This document describes the application's rate limiting mechanism, current thresholds, how to adjust them, and important notes when deploying behind a reverse proxy.

## Overview

Rate limiting is handled by the **rack-attack 6.8** gem — a Rack middleware that runs before Rails, checking and deciding whether a request is allowed to proceed before reaching the controller.

**Cache backend:**
- **Test:** Dedicated `ActiveSupport::Cache::MemoryStore` (not using `null_store` in test env because it cannot count requests)
- **Development:** `:memory_store` (counters reset when the app process restarts)
- **Production:** `:solid_cache_store` (SQLite-backed, no Redis required)

---

## Current Rate Limits

| Rule | Endpoint | Method | Limit | Window | Key |
|---|---|---|---|---|---|
| `sign_in/ip` | `/users/sign_in` | POST | 5 requests | 60 seconds | IP address |
| `sign_in/email` | `/users/sign_in` | POST | 10 requests | 60 seconds | Email in request body |
| `registration/ip` | `/users` | POST | 10 requests | 1 hour | IP address |
| `password_reset/ip` | `/users/password` | POST | 5 requests | 1 hour | IP address |

### Safelist (never throttled)

| Rule | Condition |
|---|---|
| `allow health check` | Path is `/up` |
| `allow localhost` | IP is `127.0.0.1` or `::1` |

---

## Throttled Response

HTTP **429 Too Many Requests**, with a `Retry-After` header indicating the remaining seconds in the throttle window:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 60

{"error":"Too many requests. Please try again later."}
```

This response follows the application's global error contract: `{ "error": "..." }` (singular key).

---

## Why There Are Two Rules for sign_in

| Rule                     | Protects Against                                                 |
| ------------------------ | ---------------------------------------------------------------- |
| `sign_in/ip` (5/60s)     | Brute force attacks from a single IP targeting multiple accounts |
| `sign_in/email` (10/60s) | Credential stuffing targeting a single account from multiple IPs |

The two rules operate independently. A request can trigger both at the same time if the same IP has reached 5 attempts **and** the email has been attempted 10 times.

**Reading email from JSON body:**

```ruby
body = req.env["rack.input"].read
req.env["rack.input"].rewind      # rewind so body remains available for Rails
email = JSON.parse(body).dig("user", "email").to_s.downcase.presence
```

---

## Adjusting Limits

All configuration is located in `config/initializers/rack_attack.rb`. Modify `limit:` and `period:` directly:

```ruby
# Example: loosen sign_in to 10 attempts / 60s
throttle("sign_in/ip", limit: 10, period: 60) do |req|
  req.ip if req.path == "/users/sign_in" && req.post?
end

# Example: tighten registration to 3 attempts / 1 hour
throttle("registration/ip", limit: 3, period: 3600) do |req|
  req.ip if req.path == "/users" && req.post?
end
```

After making changes, run tests to verify:

```bash
bin/rails test test/integration/rate_limit_test.rb
```

> If you change `limit:`, remember to update tests in `test/integration/rate_limit_test.rb` accordingly.

---

## Manual Testing

With the server running locally, use a loop to trigger throttling:

```bash
# Trigger sign_in/ip (6 attempts, the 6th should return 429)
for i in $(seq 1 6); do
  echo "--- Request $i ---"
  curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/users/sign_in \
    -H "Content-Type: application/json" \
    -d '{"user":{"email":"test@example.com","password":"wrong"}}'
  echo
done
```

Expected output: `401 401 401 401 401 429`

---

## Notes When Deploying Behind Reverse Proxy / Load Balancer

**Problem:** `req.ip` in Rack::Attack defaults to reading `REMOTE_ADDR`. If the application is behind Nginx, Cloudflare, or a load balancer, `REMOTE_ADDR` will be the proxy’s IP — **all requests will share the same counter**, causing legitimate users to be incorrectly blocked.

**Solution:** Configure Rails to trust `X-Forwarded-For` from trusted proxies:

```ruby
# config/application.rb
config.action_dispatch.trusted_proxies = [
  ActionDispatch::RemoteIp::TRUSTED_PROXIES,
  IPAddr.new("10.0.0.0/8"),     # internal load balancer IP range
  IPAddr.new("203.0.113.1/32")  # specific IP of Nginx/Cloudflare
]
```

After that, using `req.ip` in `rack_attack.rb` will automatically return the real client IP (extracted from `X-Forwarded-For`).

> **Security warning:** Only trust `X-Forwarded-For` from proxies you control. Misconfiguration may allow attackers to spoof IPs by injecting this header.

---

## Temporary Disable (for debugging only)

```ruby
# In Rails console on a running server
Rack::Attack.enabled = false

# Re-enable
Rack::Attack.enabled = true
```

Or in tests:

```ruby
setup { Rack::Attack.enabled = false }
teardown { Rack::Attack.enabled = true }
```

---

## Related Files

| File                                  | Purpose                                                           |
| ------------------------------------- | ----------------------------------------------------------------- |
| `config/initializers/rack_attack.rb`  | All configuration: safelists, throttles, throttled_responder      |
| `config/application.rb`               | `config.middleware.use Rack::Attack` — required for API-only apps |
| `test/integration/rate_limit_test.rb` | 6 tests covering all throttle rules                               |
