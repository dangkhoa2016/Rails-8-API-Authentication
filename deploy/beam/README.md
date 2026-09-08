# Beam.cloud deployment recipe

This directory contains a sanitized PostgreSQL production-style demo recipe for Beam.cloud. It is not an HA deployment, does not provide an SLA, and does not turn the demo into a multi-tenant production service.

## Source image

The wrapper defaults to the immutable PostgreSQL baseline image:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
```

The baseline source commit is `6897c773ec1321401e52c21c63870a72d01ca349`.

## Beam SDK

`app.py` uses the current Beam v2 SDK model: `Image.from_dockerfile(...)` and a named `Pod` with an exposed port, runtime environment variables, and secret names. Deploy with the Beam CLI from this directory, for example:

```bash
beam deploy app.py:pod
```

## Required runtime secrets

Create these secrets in the Beam project. Commit the names only, never their values:

```text
DATABASE_URL
CACHE_DATABASE_URL
QUEUE_DATABASE_URL
CABLE_DATABASE_URL
SECRET_KEY_BASE
DEVISE_JWT_SECRET_KEY
CORS_ALLOWED_ORIGINS
```

No `production.key`, Rails master key, database password, token, or private encrypted credential payload belongs in this directory.

## JWT transport on Beam

This recipe sets:

```text
JWT_AUTH_HEADER=X-Authorization
```

because the Beam Pod path tested for this project intercepted the standard `Authorization` header before Rails received it. This changes only the HTTP transport header. JWT signing, claims, expiration, and application authorization semantics are unchanged.

Use the standard `Authorization` header on providers that forward it unchanged.

## Startup

`entrypoint.sh` validates all required runtime secrets, optionally runs `db:prepare` with bounded retries, and then starts Rails on `0.0.0.0:8080`. The app's health endpoint is `/up`.

## Acceptance

After deployment, run a full release smoke with runtime-only credentials:

```bash
API_BASE_URL='https://<beam-pod-host>' \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER='X-Authorization' \
  ../../scripts/release/smoke_deployment.sh
```

A health-only check is useful for diagnostics but does not satisfy Gate 5. Full acceptance requires `/up`, `/users/sign_in`, and `/user/profile` to PASS.
