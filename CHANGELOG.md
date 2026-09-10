# Changelog

All notable public-release changes are recorded here. The project was developed
before its first semantic-versioned stable release, so the two database
baselines are recorded as pre-1.0 milestones rather than fabricated semantic
versions.

## [Unreleased]

No unreleased public changes are recorded at the first `v1.0.0` publication.

## [1.0.0] - 2026-09-10

### Authentication and authorization

- Rails 8 API authentication with Devise and JWT.
- Email-confirmed registration, profile access, and admin user management.
- JWT denylist revocation, sign-out revocation, refresh-token rotation, reuse
  detection, and token-family revocation.
- Configurable JWT transport header for provider-specific compatibility.

### Security and abuse controls

- Rack::Attack protection for sign-in, registration, password reset, refresh
  token rotation, and a global per-IP API ceiling.
- Fail-closed Rack::Attack cache-store selection.
- Bilingual rate-limiting guidance and integration coverage.

### Deployment

- Frozen PostgreSQL and SQLite pre-1.0 baseline images with verified
  multi-platform publication.
- Sanitized Beam.cloud PostgreSQL production-style demo.
- Hugging Face Spaces production-style demo aligned to the frozen PostgreSQL
  runtime; SQLite remains a compatibility and historical baseline.
- Bounded, scale-to-zero Modal.com production-style demo with explicit
  single-container and resource limits.
- Provider documentation states that demo deployments are not HA, SLA-backed,
  durable multi-tenant services, or complete DDoS protection.

### Release engineering and compatibility

- Mandatory CI on pushes to `main`.
- Brakeman, bundler-audit, RuboCop/repository-policy, schema-load, custom JWT
  header, and Ruby 3.2/3.3/4.0 qualification.
- Fail-closed repository, frozen-baseline, and release verification tooling.
- Exact verified-`main` annotated-tag publication policy.
- Rails 8.1.3.1 compatibility pin for `json < 3.0`.
- Public history excludes internal agent planning artifacts under
  `docs/superpowers/`.

## Pre-1.0 milestones

### 2026-08-12 — SQLite Baseline v1

- Branch: `baseline/sqlite-v1`
- Tag: `baseline-sqlite-v1`
- Commit: `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`
- Docker variant: `sqlite`

### 2026-08-12 — PostgreSQL Baseline v1

- Branch: `baseline/postgresql-v1`
- Tag: `baseline-postgresql-v1`
- Commit: `6897c773ec1321401e52c21c63870a72d01ca349`
- Docker variant: `postgresql`

### Authentication hardening before the baselines

- Refresh Token Rotation with reuse detection and token-family revocation.
- JWT denylist revocation and sign-out revocation.
- Configurable JWT transport header through `JWT_AUTH_HEADER`.
- Admin account-management controls and email confirmation support.
- Rack::Attack rate limiting on authentication endpoints.
- PostgreSQL 17 and SQLite deployment baselines with multi-architecture Docker
  publication.
