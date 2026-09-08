# Changelog

All notable public-release changes are recorded here. The project was developed before its first semantic-versioned stable release, so the two database baseline releases are recorded as pre-1.0 milestones rather than fabricated semantic versions.

## [Unreleased]

### Release engineering
- Run the main CI workflow on pushes to `main` in addition to pull requests and manual dispatches.
- Add fail-closed GHCR baseline, source-revision, and architecture verification.
- Add deployment health and authentication smoke verification.
- Add sanitized Beam.cloud and Hugging Face Spaces deployment recipes.
- Add an explicit release-candidate-to-stable promotion process.

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
- PostgreSQL 17 and SQLite deployment baselines with multi-architecture Docker publication.
