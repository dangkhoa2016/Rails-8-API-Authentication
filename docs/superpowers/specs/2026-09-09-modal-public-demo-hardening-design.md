# Rails 8 API Authentication — Modal Public Demo Hardening Design

Date: 2026-09-09
Status: Approved architecture, written-spec review pending
Target branch: `feat/modal-public-demo-hardening`
Base: `main`

## 1. Purpose

Add a reproducible, public Modal.com deployment path for `dangkhoa2016/Rails-8-API-Authentication` that remains easy for external users to test while bounding abuse, database pressure, and serverless cost amplification.

The deployment is a **production-style public demo**, not an HA/SLA service and not a claim of complete DDoS immunity.

## 2. Existing security baseline

The current application already has:

- Devise + devise-jwt authentication;
- `Authorization: Bearer <JWT>` as the normal Rails access-token transport;
- `rack-attack` mounted in API-only middleware;
- sign-in throttling by IP and by email;
- registration throttling by IP;
- password-reset throttling by IP;
- JSON `429 Too Many Requests` responses;
- Puma concurrency controlled by `RAILS_MAX_THREADS`;
- bounded Active Record pools and PostgreSQL connect/checkout/statement timeouts;
- production Solid Cache, Solid Queue, and distinct PostgreSQL database URLs.

This work hardens and adapts that baseline for Modal rather than replacing the authentication design.

## 3. Goals

The Modal deployment must:

1. expose a normal public HTTPS URL that testers can call without Modal credentials;
2. preserve Rails JWT in the standard `Authorization` header;
3. cap runtime scale at one container for the demo profile;
4. scale to zero when idle;
5. add a global per-client abuse ceiling plus protection for refresh-token rotation;
6. avoid turning PostgreSQL into the rate-limit counter hot path for the single-container Modal profile;
7. fail acceptance if client-IP throttling can be bypassed by spoofing forwarding headers;
8. keep secrets outside source control;
9. provide deterministic deploy and smoke-test scripts plus EN/VI documentation.

## 4. Non-goals

This work does not:

- promise volumetric DDoS protection equivalent to a dedicated WAF/CDN product;
- add Cloudflare or another external edge service;
- redesign Devise, JWT, refresh-token rotation, or authorization semantics;
- make the demo horizontally scalable;
- add Redis solely for rate limiting;
- publish Modal proxy credentials to testers;
- replace existing Beam or Hugging Face deployment recipes.

## 5. Public Modal architecture

```text
Internet
   |
   v
Modal public Web Function
requires_proxy_auth = false
max_containers = 1
min_containers = 0
   |
   v
Rack::Attack
   |- health-check safelist
   |- global per-client ceiling
   |- sign-in/IP
   |- sign-in/email
   |- registration/IP
   |- password-reset/IP
   `- refresh-token/IP
   |
   v
Rails 8 / Puma
Authorization: Bearer <Rails JWT>
   |
   v
PostgreSQL
```

The public endpoint intentionally does **not** use Modal proxy authentication because the use case is an externally testable demo. Modal proxy auth remains a documented optional private-demo mode, but it is not the default recipe.

## 6. Modal runtime contract

### 6.1 Deployment primitive

Use `@modal.web_server(...)` on a Modal Function. Current Modal documentation states that `web_server` exposes a full HTTP server and that `requires_proxy_auth=False` makes it public.

Freeze these demo-profile values in the initial recipe:

- `min_containers=0`;
- `max_containers=1`;
- `buffer_containers=0`;
- `scaledown_window=60` seconds;
- `cpu=1.0`;
- `memory=1024` MiB;
- `RAILS_MAX_THREADS=3`;
- one Puma process (`WEB_CONCURRENCY` unset or `1`);
- CPU-only runtime;
- no GPU;
- `@modal.web_server(4000, startup_timeout=120, requires_proxy_auth=False)`.

`max_containers=1` is a cost and database-pressure guardrail, not a DDoS guarantee. If the real smoke shows that 1024 MiB is insufficient, memory may be raised in a measured corrective change; it must not be silently changed without updating the documentation and evidence.

### 6.2 Image build

Build the Modal image from the repository Dockerfile with `modal.Image.from_dockerfile(...)` so the deployed runtime corresponds to the exact source candidate being reviewed.

Inject Python 3.12 with `add_python="3.12"` because Modal Functions require Python in the image. Do not maintain a second Rails Dockerfile solely for Modal.

Clear the Docker image's normal ENTRYPOINT for the Modal Function runtime and explicitly launch Rails from the Python wrapper.

### 6.3 Server startup

The Modal wrapper must:

1. run from `/rails`;
2. execute `bin/rails db:prepare` before accepting traffic;
3. launch Puma/Rails on `0.0.0.0:4000`;
4. use `RAILS_ENV=production`;
5. set `RAILS_MAX_THREADS=3` for the demo profile;
6. preserve stdout/stderr for Modal logs;
7. avoid a second reverse proxy inside the container unless later evidence shows it is necessary.

Modal already provides the external HTTPS ingress, so the initial recipe runs Puma directly instead of adding Thruster in front of Puma.

## 7. Secret contract

The repository contains only secret names and setup instructions, never secret values.

The Modal deployment uses one named Modal secret, documented as `rails-api-production`, containing the application's required production configuration.

The initial runtime requires:

- `RAILS_MASTER_KEY`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`.

The four PostgreSQL URLs must continue to satisfy the repository's existing distinct-database production contract.

`DEVISE_JWT_SECRET_KEY` remains optional because the application can read it from Rails credentials and can safely fall back to `secret_key_base` with an existing warning.

SMTP values remain optional for a demo that does not need outbound mail, but the existing warning behavior remains visible.

## 8. Rack::Attack hardening

### 8.1 Existing rules preserved

Keep the established auth rules unless tests or deployment evidence require adjustment:

- sign-in: 5 requests / 60 seconds / IP;
- sign-in: 10 requests / 60 seconds / email;
- registration: 10 requests / hour / IP;
- password reset: 5 requests / hour / IP.

### 8.2 New global ceiling

Add a coarse emergency ceiling for ordinary API traffic, initially:

- 300 requests / 60 seconds / client IP;
- `/up` excluded.

This rule exists to prevent an attacker from bypassing endpoint-specific throttles by distributing traffic across many application paths.

The value is intentionally generous for a human-tested demo and may be tuned from observed telemetry later.

### 8.3 Refresh-token throttle

Add a throttle for:

- `POST /users/tokens/refresh`;
- initially 20 requests / 60 seconds / client IP.

Refresh performs token lookup, validation, rotation, writes, and JWT issuance, so it must not remain an unbounded unauthenticated database path.

### 8.4 Rate-limit cache store

The current production app uses Solid Cache/PostgreSQL. Using that same store for every Rack::Attack counter can make PostgreSQL part of the request-flood hot path.

Add an explicit environment-controlled Rack::Attack store selection:

- default behavior remains the existing shared production cache for ordinary multi-process/multi-host deployments;
- `RACK_ATTACK_CACHE_STORE=memory` selects a process-local `ActiveSupport::Cache::MemoryStore`;
- the Modal public-demo recipe sets `RACK_ATTACK_CACHE_STORE=memory` because `max_containers=1` is a frozen invariant for that profile.

This intentionally trades cross-container counter sharing for lower database pressure. The memory-store mode must be documented as unsuitable for a multi-container deployment unless an external/shared rate-limit store is introduced.

## 9. Client-IP trust and spoof-resistance

IP-based throttling is only meaningful if the discriminator cannot be selected by the caller.

Modal's public documentation confirms the HTTP proxying model but does not provide a sufficiently explicit, stable contract for how a Rails Rack application should trust client-IP forwarding headers. Therefore the implementation must **not** blindly trust arbitrary `X-Forwarded-For` values or add broad proxy CIDRs by guesswork.

Acceptance uses a black-box deployed test:

1. send repeated sign-in requests from one real test client;
2. vary caller-supplied `X-Forwarded-For` values on each request;
3. verify that the configured IP throttle still reaches HTTP 429 at the expected request count;
4. if varying the spoofed header bypasses the throttle, Modal public-demo acceptance is FAIL.

A FAIL here blocks the claim that IP-based Rack::Attack protection is effective on Modal. The corrective path would require either a documented trustworthy Modal client-IP signal, a non-IP discriminator strategy, or an external edge/WAF layer.

## 10. JWT header compatibility

The public Modal recipe keeps:

```http
Authorization: Bearer <Rails JWT>
```

unchanged.

No `JWT_AUTH_HEADER` override is required for the default Modal deployment because Modal public `web_server` does not consume the header for proxy authentication.

An optional private Modal deployment may use `Modal-Key` + `Modal-Secret`; if documented, it must not replace or rewrite the Rails JWT `Authorization` header.

## 11. Files expected to change

Application hardening:

- `config/initializers/rack_attack.rb`
- `test/integration/rate_limit_test.rb`

Modal deployment:

- `deploy/modal/app.py`
- `deploy/modal/deploy.sh`
- `deploy/modal/test_deploy.sh`
- `deploy/modal/README.md`
- `deploy/modal/README.vi.md`

Documentation:

- `docs/RATE_LIMITING.md`
- `docs/RATE_LIMITING.vi.md`
- `docs/DEPLOYMENT.md`
- `docs/DEPLOYMENT.vi.md`

Additional small test/helper files may be added only when required to keep responsibilities isolated.

## 12. Test strategy

### 12.1 Local automated tests

Add/extend tests proving:

- existing throttle thresholds remain unchanged;
- global limit returns 429 after the configured ceiling;
- `/up` is still exempt;
- refresh-token endpoint is throttled;
- throttle responses keep the existing JSON error contract and `Retry-After` header;
- memory-store mode can be selected without changing normal default behavior;
- Rails JWT authentication still reads the standard `Authorization` header.

Run the full existing Rails test suite after the focused tests.

### 12.2 Modal recipe validation

Before real deployment acceptance:

- Python syntax/compile validation for `deploy/modal/app.py`;
- shell syntax checks for deploy/test scripts;
- repository policy/CI checks already owned by the project remain green.

### 12.3 Real deployed smoke

A successful real Modal smoke must prove at least:

- `/up` returns 200;
- public access requires no Modal credentials;
- sign-in works normally;
- returned Rails JWT can access `/user/profile` or `/user/me` via standard `Authorization`;
- sign-in rate limiting returns 429;
- spoofed `X-Forwarded-For` values do not bypass the IP throttle;
- refresh-token throttling returns 429 at the documented threshold;
- the deployment reports one-container maximum configuration.

`NOT RUN`, `BLOCKED`, or a partially successful smoke is not PASS.

## 13. Cost-safety model

The deployment bounds serverless expansion with `max_containers=1` and allows scale-to-zero with `min_containers=0`.

This prevents an HTTP flood from causing unbounded horizontal container creation, but it does not prevent an attacker from keeping the single container active continuously. Documentation must state this residual economic-DoS risk clearly.

A future external WAF/CDN is the appropriate next layer if the demo becomes a long-lived public service rather than an occasional portfolio/demo endpoint.

## 14. Documentation contract

The Modal README pair must explain:

- installing/authenticating the Modal CLI;
- creating the named runtime secret;
- deploying;
- retrieving the public URL;
- testing registration, sign-in, JWT-authenticated endpoints, and rate limits;
- viewing logs;
- stopping the app to stop compute usage;
- the one-container and memory-store invariants;
- DDoS/economic-DoS limitations;
- how private Modal proxy auth differs from the default public-demo mode.

English and Vietnamese documents must remain semantically aligned.

## 15. Success definition

The feature is complete only when one exact source candidate has:

1. focused rate-limit tests PASS;
2. full Rails test suite PASS;
3. Modal deployment scripts validated;
4. a real public Modal deployment smoke PASS;
5. JWT header compatibility proven;
6. spoof-resistance of the IP throttle proven black-box;
7. `max_containers=1` documented and observed;
8. no committed secrets;
9. EN/VI documentation complete;
10. no claim of HA, SLA, or complete DDoS immunity.

Until the real Modal smoke and spoof-resistance checks pass, this work is implementation-ready but not accepted as a hardened production-style demo.
