# Deploy to Modal.com — Public Production-Style Demo

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

This recipe deploys the Rails API as a public production-style demo on Modal.com. Rails continues to use the standard `Authorization: Bearer <JWT>` header.

## Runtime profile

- public `@modal.web_server(..., requires_proxy_auth=False)`;
- `min_containers=0`, `max_containers=1`;
- `buffer_containers=0`, `scaledown_window=60`;
- CPU-only, `cpu=1.0`, `memory=1024` MiB;
- Rails/Puma on port `4000`, `RAILS_MAX_THREADS=3`;
- `SOLID_QUEUE_IN_PUMA=true`, `JOB_CONCURRENCY=1` so the Solid Queue supervisor runs inside Puma while the demo container is awake;
- `RACK_ATTACK_CACHE_STORE=memory`;
- `RAILS_ENV=production`.

## Rails production credentials

Use the standard Rails environment-specific files:

```text
config/credentials/production.yml.enc   # commit
config/credentials/production.key       # never commit
```

Create/edit them locally:

```bash
unset RAILS_MASTER_KEY
export EDITOR=nano
bin/rails credentials:edit --environment production
```

The decrypted production credentials should include at least:

```yaml
secret_key_base: <long random Rails secret>
admin_email: <real admin email>
admin_password: <real admin password>
devise_jwt_secret_key: <long random Rails secret>
```

Commit only `config/credentials/production.yml.enc`. See [CREDENTIALS.md](CREDENTIALS.md) for the full workflow.

## Modal runtime secret

Create the named secret `rails-api-production` from an out-of-repository JSON file containing only:

- `RAILS_MASTER_KEY` — exact contents of `config/credentials/production.key`;
- `DATABASE_URL`;
- `CACHE_DATABASE_URL`;
- `QUEUE_DATABASE_URL`;
- `CABLE_DATABASE_URL`.

```bash
chmod 600 "$HOME/.config/rails-api-production.json"
modal secret create rails-api-production \
  --from-json "$HOME/.config/rails-api-production.json"
```

`DEVISE_JWT_SECRET_KEY`, `ADMIN_EMAIL`, and `ADMIN_PASSWORD` are not separate Modal secret keys because they live inside Rails production encrypted credentials.

## Deploy

```bash
./deploy/modal/deploy.sh
```

The preflight fails when `production.yml.enc` is missing, empty, untracked, or dirty; when `production.key` is tracked; when Modal authentication/secret lookup fails; or when the deployment files are dirty.

Modal runs `db:prepare` and then the idempotent `db:seed` before Puma starts. The seed creates the configured admin only when it is missing; repeated cold starts leave an existing admin password and credentials unchanged.

## Public acceptance

```bash
curl -i https://<your-modal-url>/up
./deploy/modal/smoke.sh https://<your-modal-url>
```

Full smoke additionally checks Rails sign-in, standard bearer-token transport, profile access, X-Forwarded-For spoof resistance for the sign-in IP throttle, and refresh-token throttling.

## Scale-to-zero queue semantics

Because `min_containers=0`, Modal may stop the web container after the idle window. Solid Queue runs inside Puma while the container is awake, so the recurring `every hour` cleanup tasks are not a 24/7 scheduling guarantee for this demo profile. A deployment that requires strict wall-clock execution should use a separately scheduled worker/task rather than keeping this public demo warm.

## Cost and abuse posture

`max_containers=1` bounds horizontal autoscaling but does not stop an attacker from keeping the one container awake. `RACK_ATTACK_CACHE_STORE=memory` is valid only while that single-container invariant remains true. This is a demo profile, not HA/SLA service or volumetric DDoS protection.
