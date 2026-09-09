# Deploy to Modal.com — Public Production-Style Demo

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

This recipe deploys the Rails API as a **public, production-style demo** on Modal.com. Visitors can call the API with an ordinary HTTPS URL; they do not need Modal credentials. Rails continues to use the standard `Authorization: Bearer <JWT>` header.

This is intentionally a demo profile, not an HA/SLA service and not a claim of complete DDoS protection.

## Runtime profile

The checked-in `app.py` freezes the demo profile at:

- public `@modal.web_server(..., requires_proxy_auth=False)`;
- `min_containers=0` and `max_containers=1`;
- `buffer_containers=0` and `scaledown_window=60` seconds;
- CPU-only, `cpu=1.0`, `memory=1024` MiB;
- Python 3.12 added to the repository Docker image for the Modal runtime;
- Rails/Puma on port `4000` with `RAILS_MAX_THREADS=3`;
- `RACK_ATTACK_CACHE_STORE=memory`.

The one-container ceiling bounds horizontal serverless expansion. It does **not** prevent abusive traffic from keeping that one container awake.

## 1. Install and authenticate Modal

```bash
python3 -m pip install --upgrade modal
modal setup
```

If you use Modal environments, pass `--env NAME` to the repository deploy script.

## 2. Prepare PostgreSQL

Production requires four **distinct** PostgreSQL databases:

- primary application database;
- Solid Cache database;
- Solid Queue database;
- Solid Cable database.

Use a managed PostgreSQL provider or another reachable PostgreSQL service. The URLs must satisfy the application's existing production database validation.

## 3. Create the Modal runtime secret

Prepare a JSON file **outside the repository** (for example in a password-manager-backed deployment directory), mode `0600`, containing these five keys with their real values:

- `RAILS_MASTER_KEY`
- `DATABASE_URL`
- `CACHE_DATABASE_URL`
- `QUEUE_DATABASE_URL`
- `CABLE_DATABASE_URL`

Then create the named Modal secret without putting secret-shaped assignments in tracked files or shell history:

```bash
chmod 600 "$HOME/.config/rails-api-production.json"
modal secret create rails-api-production \
  --from-json "$HOME/.config/rails-api-production.json"
```

The repository never reads or prints those values during deployment. `app.py` requires the five keys above when Modal resolves the secret.

`DEVISE_JWT_SECRET_KEY` is optional. If it is already stored in Rails encrypted credentials, no Modal environment variable is required. If you prefer independent JWT-key rotation through Modal, add that key to the same out-of-band JSON file and recreate the secret:

```bash
modal secret create --force rails-api-production \
  --from-json "$HOME/.config/rails-api-production.json"
```

Do not copy the JSON file into the repository.

## 4. Deploy

From a clean repository checkout:

```bash
./deploy/modal/deploy.sh
```

For a named Modal environment:

```bash
./deploy/modal/deploy.sh --env main
```

The script fails before deployment when:

- the Modal CLI is unavailable;
- `deploy/modal` has uncommitted/untracked changes;
- `app.py` does not compile;
- Modal authentication/environment lookup fails;
- the named `rails-api-production` secret does not exist.

The deploy script never accepts secret values as command-line arguments.

## 5. Test the public URL

Modal prints the public web endpoint after deployment. A visitor should be able to call it without `Modal-Key` or `Modal-Secret`.

Health check:

```bash
curl -i https://<your-modal-url>/up
```

Expected: HTTP `200`.

Run the repository smoke without account credentials:

```bash
./deploy/modal/smoke.sh https://<your-modal-url>
```

This proves public `/up`; authentication/rate-limit checks are reported as `NOT RUN` unless a demo account is supplied.

For the complete acceptance smoke, provide an existing demo account through environment variables loaded from your local secure environment, then run:

```bash
./deploy/modal/smoke.sh https://<your-modal-url>
```

The complete smoke requires all of the following:

- public `/up` returns `200`;
- Rails sign-in succeeds;
- the sign-in response exposes the Rails access JWT in `Authorization: Bearer ...`;
- that JWT reaches `/user/profile` using the standard `Authorization` header;
- changing caller-supplied `X-Forwarded-For` values does not bypass the `sign_in/ip` throttle;
- `POST /users/tokens/refresh` returns `429` on request 21 within the throttle window.

The smoke script does not print passwords, JWTs, refresh tokens, cookies, or Modal secret values.

## 6. Rate-limit profile

| Rule | Limit |
|---|---:|
| Global API, except `/up` | 300 requests / 60 seconds / IP |
| Sign-in | 5 requests / 60 seconds / IP |
| Sign-in | 10 requests / 60 seconds / email |
| Registration | 10 requests / hour / IP |
| Password reset | 5 requests / hour / IP |
| Refresh-token endpoint | 20 requests / 60 seconds / IP |

Modal sets `RACK_ATTACK_CACHE_STORE=memory` so rate-limit counters do not turn the Solid Cache PostgreSQL database into the hot path during an HTTP flood. This is safe for this recipe only while `max_containers=1` remains an invariant.

If you raise the Modal container cap, switch Rack::Attack back to a shared cache (`RACK_ATTACK_CACHE_STORE=rails`) or introduce another shared limiter store. Per-process memory counters do not provide a global limit across multiple containers.

## 7. Client-IP acceptance

Do not blindly configure Rails/Rack to trust arbitrary `X-Forwarded-For` values. An attacker who can select the IP discriminator can evade IP-based throttles.

The real deployment smoke deliberately sends changing caller-controlled `X-Forwarded-For` values. The deployment is **not accepted as hardened** if those values allow the sign-in IP throttle to be bypassed.

That black-box check proves spoof resistance; it does not by itself prove that every Modal request is attributed to the visitor's globally unique public IP. If per-client fairness across different networks matters, validate that separately before treating the demo as a long-lived public service.

## 8. Logs and operations

```bash
modal app logs rails-8-api-authentication
modal app logs rails-8-api-authentication -f
modal app list --json
modal app stop rails-8-api-authentication -y
```

Redeploy later with `./deploy/modal/deploy.sh`.

## Public vs. private Modal mode

This repository intentionally defaults to a **public** Modal endpoint so external users can test the demo normally.

Modal proxy authentication can be useful for a private demo. In that mode, Modal credentials are an additional ingress gate. Keep Rails JWT transport separate: Rails should still receive its access token through `Authorization: Bearer <JWT>`. The public recipe in this directory does not enable Modal proxy auth and does not use `Modal-Key` or `Modal-Secret`.

## Security and cost limits

```text
Internet
  -> Modal managed ingress
  -> max_containers=1
  -> Rack::Attack
  -> Rails / Devise JWT
  -> PostgreSQL
```

This helps with application-level abuse and prevents unbounded horizontal autoscaling, but Rack::Attack is not a volumetric DDoS service. Traffic has already reached Modal before Rails can return `429`, and an attacker may keep the single allowed container active. If this becomes a persistent public service, add an appropriate edge WAF/CDN/rate-limiter and revisit the single-container/demo assumptions.
