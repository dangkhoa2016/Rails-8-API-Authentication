# Release Process

This document is the canonical release-engineering contract for the first semantic-versioned release of Rails 8 API Authentication.

## Release states

`NOT RUN`, `BLOCKED`, `FAIL`, and `PASS` are distinct states. Only `PASS` satisfies a mandatory release gate. `NOT RUN` and `BLOCKED` must never be interpreted as successful verification.

## Frozen baseline contract

The two pre-1.0 database source lines are frozen historical baselines:

- `baseline/postgresql-v1` -> `6897c773ec1321401e52c21c63870a72d01ca349`
- `baseline/sqlite-v1` -> `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`

The immutable tags `baseline-postgresql-v1` and `baseline-sqlite-v1` are not moved or rewritten during RC/stable work.

## Gate 1 — Repository hardening

Required:

- GitHub Actions workflow syntax is valid.
- CI runs on pull requests, manual dispatch, and pushes to `main`.
- Existing Brakeman, bundler-audit, RuboCop, repository-policy, Ruby/PostgreSQL matrix, custom JWT-header, schema-load, and coverage behavior remains green.
- No authentication feature semantics change as part of release hardening.

## Gate 2 — Release contract

Required:

- `CHANGELOG.md` exists and accurately records the two baseline milestones.
- `docs/RELEASE_PROCESS.md` and `docs/RELEASE_PROCESS.vi.md` carry equivalent requirements.
- No unresolved mandatory release step remains.

Offline validation:

```bash
bash scripts/release/test_release_tools.sh
bash scripts/release/verify_repository.sh
```

## Gate 3 — Published artifact verification

Run:

```bash
bash scripts/release/verify_ghcr.sh
```

The script must PASS for both database variants and verify:

- the frozen baseline branch SHA;
- the canonical moving variant tag;
- the `-v1` tag;
- the immutable source-SHA tag;
- `linux/amd64` and `linux/arm64` on the canonical multi-platform indexes;
- the architecture-specific aliases.

Any missing tag, revision mismatch, missing required platform, duplicate required platform, or moved baseline branch is a release blocker.

## Gate 4 — Deployment portability

Beam.cloud and Hugging Face Spaces recipes must contain no committed private credential material. Required runtime secrets and provider limitations must be explicit.

Beam uses PostgreSQL and may set:

```text
JWT_AUTH_HEADER=X-Authorization
```

when the provider path intercepts the standard `Authorization` header. The JWT signing algorithm, secret, claims, and application authorization semantics do not change.

Hugging Face Spaces uses the SQLite baseline for a self-contained demo recipe. Ephemeral/free hosting must not be described as HA, SLA-backed, or durable database hosting.

## Gate 5 — RC readiness

Gate 5 is evaluated on one exact candidate commit and requires all of the following:

- full GitHub CI PASS on the exact candidate SHA;
- `scripts/release/verify_repository.sh` PASS;
- `scripts/release/verify_ghcr.sh` PASS;
- at least one real full deployment smoke PASS covering `/up`, `/users/sign_in`, and `/user/profile`;
- release acceptance evidence recorded with observed values only;
- no known release-blocking issue remains.

Health-only validation is insufficient for Gate 5. Output that contains `NOT RUN authentication smoke` does not satisfy the gate.

Full deployment command:

```bash
API_BASE_URL="$DEPLOYMENT_URL" \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER="$JWT_AUTH_HEADER" \
  scripts/release/smoke_deployment.sh
```

Credentials must come from a runtime secret store or the operator shell. They are never committed.

## Creating `v1.0.0-rc.1`

Create the RC only after Gate 5 PASS. Record the accepted implementation SHA and evidence in `docs/releases/v1.0.0-rc.1-acceptance.md`.

Use an annotated tag and never move it after publication. If source changes are required after the RC is tagged, create a subsequent RC identifier instead of retagging `v1.0.0-rc.1`.

## Promoting `v1.0.0`

Promote to `v1.0.0` only after the accepted RC lineage completes the documented acceptance period without a release-blocking regression, stable release notes are finalized, repository controls are verified, Docker baseline verification remains PASS, and at least one deployment acceptance path remains PASS.

The stable tag is a new annotated tag. Stable promotion never rewrites the RC tag.

## Rollback

A failed provider deployment rolls back to the previously verified image reference for that provider. Database rollback follows the provider/database backup and restore process.

The SQLite and PostgreSQL baselines are source/artifact recovery points; they are not interchangeable live-data backups and do not imply automatic row-level migration between database engines.

## GitHub repository controls

Target repository policy:

### `main`

- require pull request before merge;
- require mandatory CI status checks;
- block force pushes;
- block deletion.

### `baseline/postgresql-v1`

- block force pushes;
- block deletion.

### `baseline/sqlite-v1`

- block force pushes;
- block deletion.

These controls are `PASS` only after GitHub reports them enabled. If the active integration cannot administer or read the required protection endpoint, the state is `BLOCKED`, not `PASS`.
