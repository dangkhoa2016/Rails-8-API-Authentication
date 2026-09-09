# Hugging Face Spaces PostgreSQL deployment recipe

This directory contains a sanitized PostgreSQL production-style demo recipe for Hugging Face Docker Spaces. It uses the same immutable PostgreSQL runtime baseline as the Beam.cloud production-style demo:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
```

The baseline source commit is `6897c773ec1321401e52c21c63870a72d01ca349`.

This target is a production-style demo. It is not HA, does not provide an SLA, and is not a multi-tenant production service.

The frozen SQLite baseline `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc` remains immutable for compatibility, historical reference, and lightweight/disposable demo use. It is not the canonical Hugging Face production-demo runtime.

## Docker Space configuration

Create a Docker Space and configure its Space README front matter with:

```yaml
---
title: Rails 8 API Authentication
sdk: docker
app_port: 7860
---
```

The wrapper exposes Rails through port `7860` and keeps the provider-neutral `Authorization` JWT transport header.

Copy this directory's `Dockerfile` to the Docker Space repository root.

## Required runtime secrets

Configure these as Space secrets, never as committed values:

```text
DATABASE_URL
CACHE_DATABASE_URL
QUEUE_DATABASE_URL
CABLE_DATABASE_URL
SECRET_KEY_BASE
CORS_ALLOWED_ORIGINS
```

The four database URLs must point to PostgreSQL databases appropriate for the primary application, Solid Cache, Solid Queue, and Solid Cable roles expected by the frozen PostgreSQL runtime.

## Optional runtime secrets

These are optional at the Hugging Face recipe layer:

```text
DEVISE_JWT_SECRET_KEY
RAILS_MASTER_KEY
```

The application resolves the JWT signing secret through its configured credential/environment fallback chain, so `DEVISE_JWT_SECRET_KEY` must not be treated as mandatory by the Space recipe.

`RAILS_MASTER_KEY` is required whenever the running Rails application needs to decrypt `config/credentials.yml.enc`. Never commit a Rails master key, database password, token, or decrypted credential payload to the Space repository.

Recommended Space variables:

```text
DEVISE_MAILER_SENDER=noreply@example.invalid
RAILS_LOG_TO_STDOUT=true
JWT_AUTH_HEADER=Authorization
```

Set `CORS_ALLOWED_ORIGINS` to the actual Space origin through the required secret/environment configuration used for the deployment.

## Startup contract

The PostgreSQL baseline image provides `/rails/bin/docker-entrypoint`. The Hugging Face wrapper deliberately keeps the baseline server command shape:

```text
./bin/thrust ./bin/rails server
```

with `PORT=7860`.

That command shape allows the inherited entrypoint to run `./bin/rails db:prepare` before starting the server. Do not append custom Rails server arguments that would bypass the entrypoint's server-command detection unless the startup contract is re-verified.

## Health and acceptance

Rails listens on `0.0.0.0:7860`; the built-in health endpoint is `/up`.

After the Space is running, perform the full release smoke with runtime-only test credentials:

```bash
API_BASE_URL='https://<space-host>' \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER='Authorization' \
  ../../scripts/release/smoke_deployment.sh
```

A health-only PASS is diagnostic evidence but does not satisfy release Gate 5. Full acceptance requires `/up`, `/users/sign_in`, and `/user/profile` to PASS.
