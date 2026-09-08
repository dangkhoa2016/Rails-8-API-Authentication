# Hugging Face Spaces SQLite deployment recipe

This directory contains a sanitized Docker Space recipe for the immutable SQLite baseline:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-1d842b1
```

The baseline source commit is `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`.

This target is a demo deployment. It is not HA, does not provide an SLA, and must not be presented as durable database hosting unless a storage volume has been explicitly attached and verified.

## Docker Space configuration

Create a Docker Space and configure its Space README front matter with:

```yaml
---
title: Rails 8 API Authentication
sdk: docker
app_port: 7860
---
```

Hugging Face currently documents port `7860` as the default Docker Space application port. Docker Space availability depends on the account/plan currently eligible for Docker Spaces.

Copy this directory's `Dockerfile` to the Docker Space repository root.

## Required runtime secrets

Configure these as Space secrets, never as committed values:

```text
SECRET_KEY_BASE
DEVISE_JWT_SECRET_KEY
```

Recommended Space variables:

```text
CORS_ALLOWED_ORIGINS=<actual Space origin>
DEVISE_MAILER_SENDER=noreply@example.invalid
RAILS_LOG_TO_STDOUT=true
JWT_AUTH_HEADER=Authorization
```

No Rails master key, `production.key`, database password, token, or other private credential belongs in the Space source repository.

## SQLite storage behavior

The SQLite baseline stores its production databases at:

```text
/rails/storage/production.sqlite3
/rails/storage/production_cache.sqlite3
/rails/storage/production_queue.sqlite3
/rails/storage/production_cable.sqlite3
```

### Ephemeral demo

Without an attached writable volume, files written by the Docker Space are ephemeral and can be lost when the Space restarts, stops, or is rebuilt. This mode is appropriate only for disposable demo data.

### Persistent demo with a Storage Bucket

If persistence is required, attach a Hugging Face Storage Bucket as a **read-write volume mounted at `/rails/storage`**. This keeps the Rails baseline database paths unchanged. Verify the mounted volume in the Space runtime before treating the data as persistent.

A representative CLI shape is:

```bash
hf spaces volumes set <owner>/<space> \
  -v hf://buckets/<owner>/<bucket>:/rails/storage
```

Volume configuration is provider/account state and is not encoded in this repository. Storage Buckets may have separate billing/plan requirements.

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
