# Modal Public Demo Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public, scale-to-zero Modal.com deployment path for the Rails 8 API while bounding serverless scale, hardening application-level abuse controls, preserving standard Rails JWT transport, and proving client-IP throttle behavior with deployed black-box tests.

**Architecture:** Modal exposes one public `web_server` Function built from the repository Dockerfile, with `min_containers=0`, `max_containers=1`, CPU-only resources, and no Modal proxy authentication. Rails keeps `Authorization: Bearer <JWT>` unchanged. Rack::Attack gains a global per-IP ceiling and refresh-token throttle; the single-container Modal profile uses an in-process MemoryStore so abusive traffic does not turn PostgreSQL/Solid Cache into the rate-limit counter hot path.

**Tech Stack:** Rails 8.1, Ruby, Rack::Attack, Devise/devise-jwt, PostgreSQL/Solid Cache, Puma, Bash, Python 3.12, Modal Python SDK/CLI.

**Spec:** `docs/superpowers/specs/2026-09-09-modal-public-demo-hardening-design.md`

## Global Constraints

- Default Modal demo endpoint is public: `requires_proxy_auth=False`.
- Modal demo autoscaling is frozen at `min_containers=0`, `max_containers=1`, `buffer_containers=0`, `scaledown_window=60` seconds.
- Modal runtime is CPU-only with `cpu=1.0`, `memory=1024` MiB and no GPU.
- Modal `web_server` listens on port `4000` with `startup_timeout=120` seconds.
- Modal image is built from the repository `Dockerfile` with `add_python="3.12"` and the inherited Docker ENTRYPOINT cleared.
- Rails production runtime uses one Puma process and `RAILS_MAX_THREADS=3`.
- Rails JWT continues to use the standard `Authorization` header; no Modal-specific `JWT_AUTH_HEADER` override is allowed in the default public recipe.
- Existing auth throttles remain unchanged: sign-in 5/60s/IP, sign-in 10/60s/email, registration 10/hour/IP, password reset 5/hour/IP.
- Add global 300/60s/IP, excluding `/up`.
- Add refresh-token 20/60s/IP for `POST /users/tokens/refresh`.
- `RACK_ATTACK_CACHE_STORE=memory` is valid only for the frozen one-container Modal profile; ordinary production continues to use the shared Rails cache.
- Unknown nonblank `RACK_ATTACK_CACHE_STORE` values must fail closed at boot.
- Required Modal secret name is `rails-api-production`; required keys are `RAILS_MASTER_KEY`, `DATABASE_URL`, `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, and `CABLE_DATABASE_URL`.
- `DEVISE_JWT_SECRET_KEY` remains optional because the application already supports credentials / `secret_key_base` fallback semantics.
- No secret values are committed, accepted as CLI positional arguments, or printed by repository scripts.
- A real deployed spoof-resistance test is mandatory: caller-controlled changing `X-Forwarded-For` values must not bypass the sign-in IP throttle.
- `NOT RUN` or `BLOCKED` is never equivalent to acceptance PASS.
- This remains a production-style demo, not HA/SLA and not a claim of complete DDoS immunity.

---

## File Structure

### Application abuse-control unit

- Create `lib/rack_attack_cache_store.rb` — pure resolver for the Rack::Attack cache-store policy; fail closed on unsupported modes.
- Create `test/lib/rack_attack_cache_store_test.rb` — unit tests for default/shared, Modal memory, test memory, and invalid-mode behavior.
- Modify `config/initializers/rack_attack.rb` — consume the resolver and define global + refresh throttles without changing existing thresholds.
- Modify `test/integration/rate_limit_test.rb` — black-box Rails integration tests for the new throttles and preserved `/up` exemption.

### Modal deployment unit

- Create `deploy/modal/app.py` — Modal App/Image/Secret/Function declaration and Rails startup wrapper only.
- Create `deploy/modal/deploy.sh` — fail-closed local preflight and `modal deploy` orchestration; never owns secret values.
- Create `deploy/modal/test_deploy.sh` — deterministic local tests using a fake Modal CLI/module; no real cloud access.
- Create `deploy/modal/smoke.sh` — real public-endpoint acceptance checks, including JWT transport, rate limits, refresh throttling and X-Forwarded-For spoof test.

### Documentation unit

- Create `deploy/modal/README.md` and `deploy/modal/README.vi.md` — complete provider-specific operating guide.
- Modify `docs/RATE_LIMITING.md` and `.vi.md` — new throttle rules, cache-store modes, single-container invariant and proxy warning.
- Modify `docs/DEPLOYMENT.md` and `.vi.md` — add Modal public-demo deployment option and truthful limitations.

---

### Task 1: Isolate and test Rack::Attack cache-store policy

**Files:**
- Create: `lib/rack_attack_cache_store.rb`
- Create: `test/lib/rack_attack_cache_store_test.rb`
- Modify later in this task: `config/initializers/rack_attack.rb`

**Interfaces:**
- Consumes: Rails environment name, `ENV["RACK_ATTACK_CACHE_STORE"]`, and `Rails.cache`.
- Produces: `RackAttackCacheStore.resolve(environment:, requested:, default_store:) -> ActiveSupport::Cache::Store`.
- Accepted modes: blank / `"rails"` => shared/default Rails cache; `"memory"` => a new `ActiveSupport::Cache::MemoryStore`; test environment => MemoryStore regardless of blank default.
- Unsupported nonblank modes raise `ArgumentError` before the app serves requests.

- [ ] **Step 1: Write the resolver unit tests first**

```ruby
# test/lib/rack_attack_cache_store_test.rb
require "test_helper"
require Rails.root.join("lib/rack_attack_cache_store")

class RackAttackCacheStoreTest < ActiveSupport::TestCase
  test "test environment uses memory store" do
    store = RackAttackCacheStore.resolve(
      environment: "test",
      requested: nil,
      default_store: Object.new
    )
    assert_instance_of ActiveSupport::Cache::MemoryStore, store
  end

  test "memory mode uses memory store" do
    store = RackAttackCacheStore.resolve(
      environment: "production",
      requested: "memory",
      default_store: Object.new
    )
    assert_instance_of ActiveSupport::Cache::MemoryStore, store
  end

  test "blank and rails modes preserve shared Rails cache" do
    default_store = Object.new
    assert_same default_store, RackAttackCacheStore.resolve(
      environment: "production", requested: nil, default_store: default_store
    )
    assert_same default_store, RackAttackCacheStore.resolve(
      environment: "production", requested: "rails", default_store: default_store
    )
  end

  test "unknown mode fails closed" do
    error = assert_raises(ArgumentError) do
      RackAttackCacheStore.resolve(
        environment: "production",
        requested: "redis-ish",
        default_store: Object.new
      )
    end
    assert_match(/RACK_ATTACK_CACHE_STORE/, error.message)
  end
end
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
bin/rails test test/lib/rack_attack_cache_store_test.rb
```

Expected: FAIL because `lib/rack_attack_cache_store.rb` does not exist.

- [ ] **Step 3: Implement the smallest resolver**

```ruby
# lib/rack_attack_cache_store.rb
# frozen_string_literal: true

module RackAttackCacheStore
  module_function

  def resolve(environment:, requested:, default_store:)
    mode = requested.to_s.strip
    return ActiveSupport::Cache::MemoryStore.new if environment == "test" || mode == "memory"
    return default_store if mode.empty? || mode == "rails"

    raise ArgumentError,
      "Unsupported RACK_ATTACK_CACHE_STORE=#{mode.inspect}; expected rails or memory"
  end
end
```

- [ ] **Step 4: Wire the resolver into Rack::Attack initialization**

At the top of `config/initializers/rack_attack.rb`, require the helper and replace the test-only store assignment with:

```ruby
require Rails.root.join("lib/rack_attack_cache_store")

Rack::Attack.cache.store = RackAttackCacheStore.resolve(
  environment: Rails.env.to_s,
  requested: ENV["RACK_ATTACK_CACHE_STORE"],
  default_store: Rails.cache
)
```

Do not alter throttle definitions yet.

- [ ] **Step 5: Verify focused tests and existing rate-limit tests GREEN**

```bash
bin/rails test test/lib/rack_attack_cache_store_test.rb test/integration/rate_limit_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit the isolated store policy**

```bash
git add lib/rack_attack_cache_store.rb \
  test/lib/rack_attack_cache_store_test.rb \
  config/initializers/rack_attack.rb
git commit -m "harden rack attack cache store selection"
```

---

### Task 2: Add global and refresh-token throttles with integration coverage

**Files:**
- Modify: `config/initializers/rack_attack.rb`
- Modify: `test/integration/rate_limit_test.rb`

**Interfaces:**
- Produces throttle `api/ip`: 300 requests / 60 seconds / `req.ip`, excluding `/up`.
- Produces throttle `refresh_token/ip`: 20 POST requests / 60 seconds / `req.ip` for `/users/tokens/refresh`.
- Existing JSON 429 responder and `Retry-After` behavior remain unchanged.

- [ ] **Step 1: Add failing refresh-token throttle integration test**

Use invalid `X-Refresh-Token` values so the controller performs the real unauthenticated token lookup path without needing to rotate a valid token:

```ruby
REFRESH_PATH = "/users/tokens/refresh"

 test "refresh token allows 20 requests per IP per 60s then throttles" do
   with_stable_throttle_window do
     ip = "7.7.7.#{(rand * 200).to_i + 1}"
     20.times do |i|
       post REFRESH_PATH,
         headers: JSON_HEADERS.merge("HTTP_X_REFRESH_TOKEN" => "invalid-#{i}"),
         env: { "REMOTE_ADDR" => ip }
       assert_not_equal 429, response.status
     end

     post REFRESH_PATH,
       headers: JSON_HEADERS.merge("HTTP_X_REFRESH_TOKEN" => "overflow"),
       env: { "REMOTE_ADDR" => ip }
     assert_response 429
     assert response.headers.key?("Retry-After")
   end
 end
```

- [ ] **Step 2: Add failing global-ceiling test**

Use a cheap route such as `/` and a unique synthetic remote address. The first 300 requests must not be 429; request 301 must be 429. Keep the stable time window so the test does not cross a minute boundary.

```ruby
 test "global API ceiling throttles request 301 per IP per 60s" do
   with_stable_throttle_window do
     ip = "8.8.8.#{(rand * 200).to_i + 1}"
     300.times do
       get "/", env: { "REMOTE_ADDR" => ip }
       assert_not_equal 429, response.status
     end
     get "/", env: { "REMOTE_ADDR" => ip }
     assert_response 429
   end
 end
```

- [ ] **Step 3: Extend `/up` exemption test beyond the global ceiling**

Change the health test from 20 requests to 305 requests so it proves `/up` bypasses both endpoint-specific and global throttles.

- [ ] **Step 4: Run tests and verify RED**

```bash
bin/rails test test/integration/rate_limit_test.rb
```

Expected: refresh request 21 and global request 301 are not yet throttled, so new assertions fail.

- [ ] **Step 5: Add only the two new throttle rules**

Add before the existing sign-in rules:

```ruby
throttle("api/ip", limit: 300, period: 60) do |req|
  req.ip unless req.path == "/up"
end

throttle("refresh_token/ip", limit: 20, period: 60) do |req|
  req.ip if req.path == "/users/tokens/refresh" && req.post?
end
```

Do not loosen or rename existing auth throttles.

- [ ] **Step 6: Run focused tests GREEN**

```bash
bin/rails test test/integration/rate_limit_test.rb test/lib/rack_attack_cache_store_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit application hardening**

```bash
git add config/initializers/rack_attack.rb test/integration/rate_limit_test.rb
git commit -m "harden public API abuse ceilings"
```

---

### Task 3: Define the Modal runtime as a testable Python deployment unit

**Files:**
- Create: `deploy/modal/app.py`
- Create initially: `deploy/modal/test_deploy.sh`

**Interfaces:**
- Produces Modal app name `rails-8-api-authentication`.
- Produces Function `rails_api` built from repository `Dockerfile`.
- Uses `modal.Secret.from_name("rails-api-production", required_keys=[...])`.
- Starts Rails by running `bin/rails db:prepare`, then `bin/rails server -b 0.0.0.0 -p 4000` from `/rails`.
- Static Function environment includes `RAILS_ENV=production`, `PORT=4000`, `RAILS_MAX_THREADS=3`, `RACK_ATTACK_CACHE_STORE=memory`.

- [ ] **Step 1: Create a contract test harness before `app.py`**

`deploy/modal/test_deploy.sh` must load `app.py` under a fake `modal` Python module and assert captured configuration rather than contacting Modal. The fake module must record:

```text
Image.from_dockerfile path/context/add_python
Image.entrypoint([])
Secret.from_name name/required_keys
App name
@app.function keyword arguments
@modal.web_server port/startup_timeout/requires_proxy_auth
```

The test must require these exact values:

```python
APP_NAME = "rails-8-api-authentication"
SECRET_NAME = "rails-api-production"
ADD_PYTHON = "3.12"
CPU = 1.0
MEMORY = 1024
MIN_CONTAINERS = 0
MAX_CONTAINERS = 1
BUFFER_CONTAINERS = 0
SCALEDOWN_WINDOW = 60
PORT = 4000
STARTUP_TIMEOUT = 120
REQUIRES_PROXY_AUTH = False
```

and required secret keys:

```python
[
    "RAILS_MASTER_KEY",
    "DATABASE_URL",
    "CACHE_DATABASE_URL",
    "QUEUE_DATABASE_URL",
    "CABLE_DATABASE_URL",
]
```

The harness must also assert `DEVISE_JWT_SECRET_KEY` is not in `required_keys` and `JWT_AUTH_HEADER` is not set in the Function environment.

- [ ] **Step 2: Run the contract test and verify RED**

```bash
bash deploy/modal/test_deploy.sh
```

Expected: FAIL because `deploy/modal/app.py` does not exist.

- [ ] **Step 3: Implement `deploy/modal/app.py`**

The implementation shape is:

```python
from pathlib import Path
import os
import subprocess
import modal

APP_NAME = "rails-8-api-authentication"
SECRET_NAME = "rails-api-production"
PORT = 4000

REPO_ROOT = Path(__file__).resolve().parents[2]

image = (
    modal.Image.from_dockerfile(
        REPO_ROOT / "Dockerfile",
        context_dir=REPO_ROOT,
        add_python="3.12",
    )
    .entrypoint([])
)

runtime_secret = modal.Secret.from_name(
    SECRET_NAME,
    required_keys=[
        "RAILS_MASTER_KEY",
        "DATABASE_URL",
        "CACHE_DATABASE_URL",
        "QUEUE_DATABASE_URL",
        "CABLE_DATABASE_URL",
    ],
)

app = modal.App(APP_NAME)

@app.function(
    image=image,
    secrets=[runtime_secret],
    cpu=1.0,
    memory=1024,
    min_containers=0,
    max_containers=1,
    buffer_containers=0,
    scaledown_window=60,
    env={
        "RAILS_ENV": "production",
        "PORT": str(PORT),
        "RAILS_MAX_THREADS": "3",
        "RACK_ATTACK_CACHE_STORE": "memory",
    },
)
@modal.web_server(PORT, startup_timeout=120, requires_proxy_auth=False)
def rails_api():
    env = os.environ.copy()
    subprocess.run(["/rails/bin/rails", "db:prepare"], cwd="/rails", env=env, check=True)
    subprocess.Popen(
        ["/rails/bin/rails", "server", "-b", "0.0.0.0", "-p", str(PORT)],
        cwd="/rails",
        env=env,
    )
```

Do not use shell interpolation for Rails startup and do not log environment contents.

- [ ] **Step 4: Run Python syntax + fake-module contract tests GREEN**

```bash
python3 -m py_compile deploy/modal/app.py
bash deploy/modal/test_deploy.sh
```

Expected: PASS with no network access.

- [ ] **Step 5: Commit the Modal runtime definition**

```bash
git add deploy/modal/app.py deploy/modal/test_deploy.sh
git commit -m "add bounded Modal Rails runtime"
```

---

### Task 4: Add fail-closed Modal deployment orchestration

**Files:**
- Create: `deploy/modal/deploy.sh`
- Modify: `deploy/modal/test_deploy.sh`

**Interfaces:**
- `deploy.sh [--env NAME] [--smoke URL]`.
- Reads only Modal authentication already configured in the local CLI.
- Checks named secret existence with `modal secret list --json`; key presence remains enforced server-side by `Secret.from_name(..., required_keys=...)`.
- Deploy command: `modal deploy deploy/modal/app.py --name rails-8-api-authentication` plus `--env NAME` when supplied.
- Optional `--smoke URL` invokes `deploy/modal/smoke.sh` after deploy.

- [ ] **Step 1: Extend `test_deploy.sh` with fake CLI cases first**

Create a fake `modal` executable that logs arguments and returns fixture JSON for `modal secret list --json`. Add tests proving:

1. deployment succeeds when `rails-api-production` exists;
2. deploy fails before `modal deploy` when the named secret is absent;
3. `--env staging` is passed to both secret listing and deploy;
4. unknown CLI arguments fail closed;
5. a dirty repository tree fails before contacting Modal;
6. `--smoke` validates an `http://` or `https://` URL and invokes `smoke.sh` only after successful deploy;
7. secret values never appear in expected logs/output.

- [ ] **Step 2: Verify RED**

```bash
bash deploy/modal/test_deploy.sh
```

Expected: new deploy-orchestration cases fail because `deploy.sh` does not exist.

- [ ] **Step 3: Implement `deploy.sh` following the repository Beam script style**

Start with:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
```

Required preflight sequence:

```text
require git, python3, modal
resolve repository root
assert deploy/modal/app.py and smoke.sh/test_deploy.sh exist
assert repository has no uncommitted/untracked changes
python3 -m py_compile deploy/modal/app.py
bash -n deploy/modal/smoke.sh
modal secret list --json [--env NAME]
verify exact secret name rails-api-production exists
print branch + exact HEAD SHA, never secret values
modal deploy deploy/modal/app.py --name rails-8-api-authentication [--env NAME]
optional smoke URL
```

Use Python or `jq` to parse JSON; do not grep JSON text for secret-name detection.

- [ ] **Step 4: Run local deployment tests GREEN**

```bash
bash deploy/modal/test_deploy.sh
bash -n deploy/modal/deploy.sh
```

Expected: PASS.

- [ ] **Step 5: Commit deployment orchestration**

```bash
git add deploy/modal/deploy.sh deploy/modal/test_deploy.sh
git commit -m "add fail closed Modal deployment preflight"
```

---

### Task 5: Build the real Modal acceptance smoke, including spoof resistance

**Files:**
- Create: `deploy/modal/smoke.sh`
- Modify: `deploy/modal/test_deploy.sh` with local parser/input tests where practical.

**Interfaces:**
- Inputs: `API_BASE_URL` or first positional URL; optional `SMOKE_EMAIL` + `SMOKE_PASSWORD` as a pair.
- Never prints password, access JWT, refresh token, cookies, or secret values.
- Returns zero only if every requested mandatory check passes.
- Public-health and unauthenticated checks can run without a demo account; full auth acceptance requires credentials.

- [ ] **Step 1: Add local shell-contract tests before implementing smoke logic**

Test that `smoke.sh`:

- rejects a malformed URL;
- rejects only-one-of `SMOKE_EMAIL` / `SMOKE_PASSWORD`;
- does not echo a sentinel password/token placed in environment variables;
- uses standard `Authorization: Bearer` for the authenticated profile call;
- never adds `Modal-Key`, `Modal-Secret`, or `JWT_AUTH_HEADER` in public mode.

- [ ] **Step 2: Implement health + public-access checks**

The script must call:

```bash
GET ${BASE_URL}/up
```

and require HTTP 200 without Modal credentials.

- [ ] **Step 3: Implement one successful Rails JWT login/profile sequence**

When smoke credentials are present:

```text
POST /users/sign_in with JSON user/email/password
capture response Authorization header as access JWT
GET /user/profile with Authorization: Bearer <JWT>
require successful profile response
```

Never print the captured JWT.

- [ ] **Step 4: Implement spoof-resistance test with exact counter accounting**

Run this after the single successful sign-in above so the real client-IP sign-in counter has exactly one known request in the current 60-second window.

Send four invalid login requests using the same nonexistent email but four distinct caller-supplied forwarding values:

```bash
-H 'X-Forwarded-For: 198.51.100.11'
-H 'X-Forwarded-For: 198.51.100.12'
-H 'X-Forwarded-For: 198.51.100.13'
-H 'X-Forwarded-For: 198.51.100.14'
```

These four must not return 429. Send the fifth invalid request with `X-Forwarded-For: 198.51.100.15`; it **must** return 429. Because the email throttle is 10/minute and only five invalid attempts are made, a 429 here demonstrates that changing caller-supplied XFF did not reset the 5/minute IP discriminator.

If the fifth request is not 429, print a concise FAIL explaining that caller-controlled forwarded headers appear able to bypass the Modal IP throttle and exit non-zero.

- [ ] **Step 5: Implement refresh-token throttle test independently of valid token rotation**

Send 20 requests to:

```text
POST /users/tokens/refresh
X-Refresh-Token: invalid-<unique-suffix>
```

The first 20 must not return 429; request 21 must return 429. Invalid tokens are intentional: they exercise the unauthenticated DB lookup path without destroying/rotating a valid demo user's token state.

- [ ] **Step 6: Protect against throttle-window ambiguity**

Before the rate-limit portion, read the system epoch seconds. If fewer than 10 seconds remain in the current minute, sleep until the next minute plus one second. Keep all rate-limit loops compact so they complete within the same 60-second window. If the server's Rack::Attack window behavior differs from wall-clock minute boundaries during deployed evidence, record observed `Retry-After` and adjust only the smoke synchronization, never the throttle thresholds.

- [ ] **Step 7: Verify shell syntax and deterministic local tests**

```bash
bash -n deploy/modal/smoke.sh
bash deploy/modal/test_deploy.sh
```

Expected: PASS.

- [ ] **Step 8: Commit acceptance tooling**

```bash
git add deploy/modal/smoke.sh deploy/modal/test_deploy.sh
git commit -m "add Modal public endpoint acceptance smoke"
```

---

### Task 6: Document Modal operation and rate-limit semantics in English and Vietnamese

**Files:**
- Create: `deploy/modal/README.md`
- Create: `deploy/modal/README.vi.md`
- Modify: `docs/RATE_LIMITING.md`
- Modify: `docs/RATE_LIMITING.vi.md`
- Modify: `docs/DEPLOYMENT.md`
- Modify: `docs/DEPLOYMENT.vi.md`

**Interfaces:**
- Documentation must match executable defaults exactly.
- EN/VI pairs must be semantically aligned, not merely similar.

- [ ] **Step 1: Update the rate-limit tables in both languages**

Add:

```text
api/ip                 all paths except /up       300 / 60s / IP
refresh_token/ip       POST /users/tokens/refresh 20 / 60s / IP
```

Explain `RACK_ATTACK_CACHE_STORE` accepted values:

```text
unset or rails -> Rails.cache / shared production cache
memory         -> in-process MemoryStore
```

State explicitly that Modal sets `memory` only because `max_containers=1`; increasing the Modal container cap requires reverting to a shared store or adding a dedicated shared rate-limit backend.

Correct proxy wording so documentation does not claim that arbitrary `X-Forwarded-For` should simply be trusted. State that deployed spoof-resistance evidence is required for Modal.

- [ ] **Step 2: Create complete Modal README pair**

Both files must document exact commands:

```bash
python3 -m pip install --upgrade modal
modal setup
modal secret create rails-api-production \
  RAILS_MASTER_KEY='...' \
  DATABASE_URL='...' \
  CACHE_DATABASE_URL='...' \
  QUEUE_DATABASE_URL='...' \
  CABLE_DATABASE_URL='...'
./deploy/modal/deploy.sh
```

Use placeholders only in user-entered command examples; never commit real values. Explain that `DEVISE_JWT_SECRET_KEY` may additionally live in the named secret but is not required by the deployment contract.

Document:

- public URL needs no Modal credentials;
- Rails JWT remains `Authorization: Bearer`;
- `./deploy/modal/smoke.sh https://...`;
- full auth smoke with environment variables;
- logs via `modal app logs rails-8-api-authentication`;
- shutdown via `modal app stop rails-8-api-authentication`;
- `max_containers=1` bounds horizontal cost but one container can still be kept awake by abusive traffic;
- not HA/SLA and not complete DDoS protection;
- optional private Modal proxy-auth mode is conceptually separate and not enabled by this recipe.

- [ ] **Step 3: Add Modal to general deployment docs in both languages**

Keep Beam and Hugging Face guidance intact. Add Modal as the recommended public production-style demo recipe when standard `Authorization` JWT transport and public tester access are desired.

- [ ] **Step 4: Run documentation consistency searches**

```bash
grep -R "max_containers" deploy/modal docs/DEPLOYMENT* docs/RATE_LIMITING*
grep -R "RACK_ATTACK_CACHE_STORE" deploy/modal docs/RATE_LIMITING*
grep -R "DEVISE_JWT_SECRET_KEY" deploy/modal
```

Expected: values and required/optional semantics match the spec and `app.py`.

- [ ] **Step 5: Commit documentation**

```bash
git add deploy/modal/README.md deploy/modal/README.vi.md \
  docs/RATE_LIMITING.md docs/RATE_LIMITING.vi.md \
  docs/DEPLOYMENT.md docs/DEPLOYMENT.vi.md
git commit -m "document Modal public demo operations"
```

---

### Task 7: Run complete local verification before any real cloud deployment

**Files:**
- No new feature files expected; only corrective edits if a test exposes a defect.

**Interfaces:**
- Produces one exact candidate SHA eligible for real Modal deployment testing.

- [ ] **Step 1: Run focused abuse-control tests**

```bash
bin/rails test test/lib/rack_attack_cache_store_test.rb test/integration/rate_limit_test.rb
```

Expected: PASS.

- [ ] **Step 2: Run Modal offline tests**

```bash
python3 -m py_compile deploy/modal/app.py
bash -n deploy/modal/deploy.sh
bash -n deploy/modal/smoke.sh
bash deploy/modal/test_deploy.sh
```

Expected: PASS.

- [ ] **Step 3: Run standard project verification**

```bash
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

Also run repository-owned verification if executable in the checkout:

```bash
scripts/release/verify_repository.sh
```

Expected: all mandatory checks PASS.

- [ ] **Step 4: Verify no secret material or accidental Modal auth conflict**

```bash
git grep -nE 'Modal-Key:|Modal-Secret:' -- ':!docs/superpowers/*' ':!deploy/modal/README*' || true
git grep -n 'JWT_AUTH_HEADER' -- deploy/modal
```

Expected: no runtime public recipe uses Modal proxy credentials and no Modal runtime sets `JWT_AUTH_HEADER`.

- [ ] **Step 5: Record exact implementation candidate**

```bash
git status --short
git rev-parse HEAD
git log -1 --format=fuller
```

Expected: clean tree and one exact SHA. Do not describe the feature as accepted yet.

---

### Task 8: Perform real Modal deployment acceptance and record only observed evidence

**Files:**
- Modify only if desired by the existing release/evidence process: a dedicated evidence document under `docs/` after runtime checks PASS. Do not rewrite the design/spec to manufacture PASS.

**Interfaces:**
- Consumes exact clean candidate SHA from Task 7 and a preconfigured Modal account/environment.
- Produces observed PASS/FAIL evidence for public ingress, JWT transport, autoscaling contract, rate limiting and spoof resistance.

- [ ] **Step 1: Confirm Modal authentication and named secret without exposing values**

```bash
modal config show --redact
modal secret list --json
```

Expected: authenticated client and named secret `rails-api-production` visible.

- [ ] **Step 2: Deploy the exact clean candidate**

```bash
./deploy/modal/deploy.sh
```

Or with an explicit Modal environment:

```bash
./deploy/modal/deploy.sh --env main
```

Expected: successful deployment and public web URL emitted by Modal.

- [ ] **Step 3: Run health/public smoke immediately**

```bash
./deploy/modal/smoke.sh https://<actual-modal-url>
```

Expected: `/up` 200 without Modal credentials. Without smoke account credentials, authentication/rate-limit acceptance remains NOT RUN.

- [ ] **Step 4: Run full authenticated acceptance**

```bash
SMOKE_EMAIL='existing-demo-account@example.invalid' \
SMOKE_PASSWORD='<supplied-out-of-band>' \
./deploy/modal/smoke.sh https://<actual-modal-url>
```

Expected all of:

```text
PASS public /up
PASS Rails sign-in
PASS Authorization Bearer profile
PASS caller X-Forwarded-For does not bypass sign-in/IP throttle
PASS refresh-token/IP throttle
```

The script must never echo `SMOKE_PASSWORD`, access JWT, refresh token or cookies.

- [ ] **Step 5: Inspect Modal runtime state/logs**

```bash
modal app list --json
modal app logs rails-8-api-authentication
```

Verify the deployed app/function name is correct and logs show successful Rails boot/db preparation without secret leakage. The static source contract for `max_containers=1` is already tested offline; if Modal exposes current autoscaler settings through the SDK/dashboard, capture that observation as additional evidence rather than inventing it from logs.

- [ ] **Step 6: Apply fail-closed verdict**

Acceptance is FAIL if any of these occur:

```text
public URL requires Modal credentials
Rails Authorization bearer transport fails
request 5 of the spoof-XFF sequence is not 429
refresh request 21 is not 429
runtime starts more than one container under the frozen config
secret material appears in logs/output
```

`NOT RUN` or inability to authenticate to Modal is BLOCKED/NOT RUN, never PASS.

- [ ] **Step 7: Stop the demo when evidence collection is complete unless continued public availability is intentional**

```bash
modal app stop rails-8-api-authentication -y
```

This terminates the deployed App; redeploy later with `./deploy/modal/deploy.sh` when the demo is needed again.

- [ ] **Step 8: Commit evidence only after observed PASS**

If the project wants a retained acceptance record, create an evidence-only document that records:

```text
exact source SHA
deployment environment name
sanitized public URL or URL if intentionally public
UTC timestamp
commands run
observed status codes/verdicts
Modal app identity
known residual economic-DoS limitation
```

Do not include passwords, JWTs, refresh tokens, cookies, API tokens, database URLs with credentials, or Modal secret values.
