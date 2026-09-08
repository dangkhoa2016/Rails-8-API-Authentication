# Beam.cloud deployment recipe

This directory contains a sanitized PostgreSQL production-style demo recipe for Beam.cloud. It is not an HA deployment, does not provide an SLA, and does not turn the demo into a multi-tenant production service.

## Source image

The wrapper defaults to the immutable PostgreSQL baseline image:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77
```

The baseline source commit is `6897c773ec1321401e52c21c63870a72d01ca349`.

## Beam SDK and deploy runner

`app.py` uses the Beam v2 SDK model: `Image.from_dockerfile(...)` and a named `Pod` with an exposed port, runtime environment variables, and Beam secret names.

For release-oriented deployment, prefer the fail-closed runner from the repository root:

```bash
./deploy/beam/deploy.sh
```

It verifies the Beam secret inventory, repository cleanliness, syntax, exact Git SHA, and then runs `beam deploy app.py:pod`.

Direct Beam CLI deployment remains available for advanced use:

```bash
cd deploy/beam
beam deploy app.py:pod
```

When using direct deployment, set `BEAM_OPTIONAL_SECRETS` yourself if optional Beam secrets must be attached, for example:

```bash
BEAM_OPTIONAL_SECRETS='DEVISE_JWT_SECRET_KEY,RAILS_MASTER_KEY' \
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
CORS_ALLOWED_ORIGINS
```

## Optional runtime secrets

These are optional at the Beam recipe layer:

```text
DEVISE_JWT_SECRET_KEY
RAILS_MASTER_KEY
```

The application currently resolves the JWT signing secret in this order:

1. `Rails.application.credentials.devise_jwt_secret_key`
2. `ENV["DEVISE_JWT_SECRET_KEY"]`
3. `Rails.application.secret_key_base`

Therefore `DEVISE_JWT_SECRET_KEY` must not be treated as a mandatory Beam secret. If it exists in Beam, `deploy.sh` detects it and attaches it to the Pod; otherwise the application uses its configured fallback chain.

`RAILS_MASTER_KEY` is also optional in the Beam recipe, but it is required whenever the running Rails application needs to decrypt `config/credentials.yml.enc`. The Docker build deliberately does not include `config/master.key`, so a deployment that relies on encrypted Rails credentials should create `RAILS_MASTER_KEY` as a Beam secret. `deploy.sh` will attach it automatically when present.

Never commit `config/master.key`, a production key, database password, token, or decrypted credential payload into this directory.

## JWT transport on Beam

This recipe sets:

```text
JWT_AUTH_HEADER=X-Authorization
```

because the Beam Pod path tested for this project intercepted the standard `Authorization` header before Rails received it. This changes only the HTTP transport header. JWT signing, claims, expiration, and application authorization semantics are unchanged.

Use the standard `Authorization` header on providers that forward it unchanged.

## Startup

`entrypoint.sh` validates the required database/application runtime secrets, optionally runs `db:prepare` with bounded retries, and then starts Rails on `0.0.0.0:8080`. It does not require `DEVISE_JWT_SECRET_KEY`, because the Rails application owns JWT-secret resolution. The app's health endpoint is `/up`.

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
