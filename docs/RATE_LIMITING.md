# Rate Limiting
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](RATE_LIMITING.vi.md)

This document describes the application's Rack::Attack policy, cache-store choices, current thresholds, and proxy/IP requirements.

## Overview

Rate limiting is handled by **rack-attack 6.8**, mounted explicitly in this API-only Rails application. A matching request is rejected before controller logic with HTTP `429 Too Many Requests`.

### Counter store

`config/initializers/rack_attack.rb` resolves its store through `RackAttackCacheStore`:

| `RACK_ATTACK_CACHE_STORE` | Behavior |
|---|---|
| unset / blank | use `Rails.cache` |
| `rails` | use `Rails.cache` |
| `memory` | use a process-local `ActiveSupport::Cache::MemoryStore` |
| any other nonblank value | boot fails closed with `ArgumentError` |

Tests always use MemoryStore so counters actually increment.

Ordinary production uses `Rails.cache`, which is `:solid_cache_store` in this repository and therefore shared through the dedicated PostgreSQL cache database. The Modal public-demo recipe intentionally sets `RACK_ATTACK_CACHE_STORE=memory` because that profile freezes `max_containers=1`; this keeps rate-limit counter writes off PostgreSQL during an HTTP flood.

**Do not use the memory mode for a multi-container deployment.** If the Modal container cap is raised, switch back to `RACK_ATTACK_CACHE_STORE=rails` or introduce another shared limiter store.

---

## Current Rate Limits

| Rule | Endpoint / scope | Method | Limit | Window | Key |
|---|---|---|---:|---:|---|
| `api/ip` | all application paths except `/up` | all | 300 | 60 seconds | IP address |
| `sign_in/ip` | `/users/sign_in` | POST | 5 | 60 seconds | IP address |
| `sign_in/email` | `/users/sign_in` | POST | 10 | 60 seconds | email in JSON body |
| `registration/ip` | `/users` | POST | 10 | 1 hour | IP address |
| `password_reset/ip` | `/users/password` | POST | 5 | 1 hour | IP address |
| `refresh_token/ip` | `/users/tokens/refresh` | POST | 20 | 60 seconds | IP address |

Important behavior:

- Rack::Attack runs before controller logic, so requests that later return `401` or `422` still increment matching counters.
- The global `api/ip` ceiling prevents an attacker from avoiding endpoint-specific rules simply by spreading requests over many paths.
- Refresh-token rotation is explicitly throttled because it is an unauthenticated path that performs token lookup/validation and may write rotation state.
- `/up` is safelisted and excluded from the global ceiling.
- Localhost (`127.0.0.1`, `::1`) is safelisted in development/test and only in production when `RACK_ATTACK_SAFELIST_LOCALHOST=true` is explicitly set.

### Safelist

| Rule | Condition |
|---|---|
| `allow health check` | path is `/up` |
| `allow localhost` | local IP in development/test, or explicit production opt-in |

---

## Throttled Response

A throttled request returns the application's normal JSON error contract:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 60

{"error":"Too many requests. Please try again later."}
```

`Retry-After` comes from the matched Rack::Attack window.

---

## Why Sign-In Has Two Rules

| Rule | Protects against |
|---|---|
| `sign_in/ip` (5/60s) | brute-force attempts from one IP across accounts |
| `sign_in/email` (10/60s) | credential stuffing aimed at one account from multiple IPs |

The email discriminator is read from the JSON body and the Rack input is rewound so Rails can still parse it:

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

The integration suite verifies existing auth thresholds, the global ceiling, the refresh-token ceiling, JSON `429` behavior, `Retry-After`, and that `/up` remains exempt beyond the global threshold.

For the Modal public demo, offline configuration tests are separate:

```bash
bash deploy/modal/test_deploy.sh
```

A real Modal deployment also requires the black-box smoke:

```bash
SMOKE_EMAIL='demo@example.com' \
SMOKE_PASSWORD='...' \
./deploy/modal/smoke.sh https://<modal-public-url>
```

That smoke deliberately varies caller-supplied `X-Forwarded-For` values. If those values let the caller bypass `sign_in/ip`, Modal acceptance fails.

---

## Reverse Proxies and Client IPs

IP throttling is only useful when the caller cannot choose the discriminator.

Do **not** blindly trust `X-Forwarded-For`, and do not add broad proxy CIDRs by guesswork. Trust forwarding headers only when the ingress provider documents a trustworthy proxy boundary that you can configure precisely.

A bad proxy configuration can fail in two opposite ways:

1. every visitor appears to come from the same proxy address, causing legitimate users to share one counter;
2. caller-controlled forwarding headers are trusted, allowing attackers to rotate fake IPs and evade limits.

For Modal, this repository does not assume an undocumented client-IP header contract. The deployment smoke instead uses a black-box spoof-resistance check. Passing that check proves that caller-controlled changing `X-Forwarded-For` does not reset the sign-in/IP counter; it does **not** by itself prove perfect per-visitor IP attribution across different networks.

For infrastructure you control (for example, your own reverse proxy or a documented CDN), configure Rails trusted proxies only from verified provider ranges/signals and test the resulting `request.remote_ip` / Rack discriminator behavior before production use.

---

## Adjusting Limits

All thresholds are defined in `config/initializers/rack_attack.rb`. If a limit or period changes, update `test/integration/rate_limit_test.rb` in the same change and re-run the focused suite.

The current values are intentionally conservative for an authentication API and a human-tested public demo. Tune them from observed legitimate traffic; do not loosen them merely to hide a proxy/IP configuration problem.

---

## Temporary Disable (debugging only)

```ruby
Rack::Attack.enabled = false
# ...debug...
Rack::Attack.enabled = true
```

Do not ship a public deployment with Rack::Attack disabled.

---

## Related Files

| File | Purpose |
|---|---|
| `lib/rack_attack_cache_store.rb` | fail-closed Rack::Attack store selection |
| `config/initializers/rack_attack.rb` | safelists, throttles, responder |
| `config/application.rb` | mounts Rack::Attack in API-only middleware |
| `test/lib/rack_attack_cache_store_test.rb` | cache-store policy tests |
| `test/integration/rate_limit_test.rb` | throttle integration tests |
| `deploy/modal/app.py` | one-container Modal memory-store invariant |
| `deploy/modal/smoke.sh` | deployed spoof-resistance and throttle acceptance |
