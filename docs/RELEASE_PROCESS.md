# Release Process

This document is the canonical release-engineering contract for semantic-versioned public releases of Rails 8 API Authentication.

## Release model

The first semantic-versioned public release was created directly as stable `v1.0.0`. There was no prerequisite public prerelease tag. Release-hardening work is merged into `main` only after every mandatory pre-merge gate passes.

Release states are `NOT RUN`, `BLOCKED`, `FAIL`, and `PASS`. Only `PASS` satisfies a mandatory release gate. Missing or partial evidence is never promoted to PASS.

## Frozen baseline contract

The two pre-1.0 database source lines remain immutable historical baselines:

- `baseline/postgresql-v1` -> `6897c773ec1321401e52c21c63870a72d01ca349`
- `baseline/sqlite-v1` -> `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`

The immutable tags `baseline-postgresql-v1` and `baseline-sqlite-v1` are never moved or rewritten by stable-release work.

## Gate 1 — Repository hardening

PASS requires:

- GitHub Actions workflow syntax is valid;
- CI runs on pull requests, manual dispatch, and pushes to `main`;
- Brakeman, bundler-audit, RuboCop, repository policy, Ruby/PostgreSQL 3.2/3.3/4.0, custom JWT-header, schema-load, and coverage behavior remain green;
- no authentication feature semantics change as part of release hardening.

## Gate 2 — Release contract

PASS requires:

- `CHANGELOG.md` exists and accurately records the pre-1.0 milestones;
- `docs/RELEASE_PROCESS.md` and `docs/RELEASE_PROCESS.vi.md` carry equivalent requirements;
- no unresolved mandatory release step remains;
- repository-owned release tooling validates fail closed.

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
- architecture-specific aliases.

A missing tag, revision mismatch, missing or duplicate required platform, or moved frozen baseline is a release blocker.

## Gate 4 — Deployment portability

Beam.cloud and Hugging Face Spaces recipes must contain no committed private credential material. Required runtime secrets and provider limitations must be explicit.

Beam uses PostgreSQL and may set:

```text
JWT_AUTH_HEADER=X-Authorization
```

when the provider path intercepts the standard `Authorization` header. This changes JWT transport only; signing, claims, expiration, and application authorization semantics remain unchanged.

Hugging Face Spaces uses the SQLite baseline for a self-contained demo recipe. Ephemeral or free hosting must not be described as HA, SLA-backed, or durable database hosting.

## Gate 5 — Release readiness

Gate 5 is evaluated on one exact stable candidate commit and requires all of the following:

- full GitHub CI PASS on the exact candidate SHA;
- `scripts/release/verify_repository.sh` PASS;
- `scripts/release/verify_ghcr.sh` PASS;
- at least one real full deployment smoke PASS covering `/up`, `/users/sign_in`, and `/user/profile`;
- repository controls reported active by GitHub;
- the version-specific acceptance record under `docs/releases/` records observed values only;
- no known release-blocking issue remains.

Health-only validation is insufficient. Output that contains `NOT RUN authentication smoke` does not satisfy Gate 5.

Full deployment command:

```bash
API_BASE_URL="$DEPLOYMENT_URL" \
SMOKE_EMAIL="$SMOKE_EMAIL" \
SMOKE_PASSWORD="$SMOKE_PASSWORD" \
JWT_AUTH_HEADER="$JWT_AUTH_HEADER" \
  scripts/release/smoke_deployment.sh
```

Credentials come from a runtime secret store or operator shell and are never committed.

## Runtime provenance

The stable source candidate and the frozen runtime artifacts are separate evidence dimensions.

- CI and repository checks identify the exact stable source candidate SHA.
- `verify_ghcr.sh` verifies the immutable PostgreSQL and SQLite baseline artifacts.
- A provider deployment may intentionally derive from a frozen baseline image when the documented recipe says so.
- Acceptance must state the actual running image/source provenance and must never claim the provider container was built from the stable candidate SHA unless that was actually observed.

## Historical `v1.0.0` exception

The already-published `v1.0.0` annotated tag points to accepted implementation commit `b73d8e1acbb1017fb4b384f254c1347645e801ba`. The final acceptance-evidence commit and its merge into `main` occurred afterward.

That published tag is historical and immutable. Do not move, delete, recreate, or retarget `v1.0.0` to match current policy. Any correction after publication requires a subsequent semantic version.

## Creating new stable releases

For every release after `v1.0.0`, publication uses the integrated, post-merge verified repository state as the release identity.

Use an annotated tag and never move it after publication. If source changes are required before publication, re-run the affected gates. If source changes are required after a version is published, create a subsequent semantic version instead of moving the published tag.

The release tag target must satisfy all of these conditions:

- the target is the exact `main` commit produced by the reviewed release integration;
- mandatory push-to-`main` CI has completed with PASS on that exact SHA;
- the exact SHA contains the final version-specific acceptance record;
- the exact SHA is still the current verified `main` release state immediately before tag creation.

Tag the exact post-merge `main` commit that passed mandatory post-merge CI.
Never tag an earlier candidate, evidence-only commit, or pre-merge branch head for a new release.

## Merge and publication order for releases after `v1.0.0`

1. Qualify the exact release candidate on its reviewed release branch.
2. Record version-specific acceptance evidence without changing application semantics unless a new candidate is intentionally created.
3. Re-verify the final branch head and all affected mandatory gates.
4. Merge the reviewed release pull request into `main`.
5. Wait for mandatory push-to-`main` CI and require PASS on the exact merge/integration SHA.
6. Re-verify that this exact SHA is the intended current release state and that frozen artifacts and repository controls remain valid.
7. Create the annotated semantic-version tag on that exact verified post-merge `main` SHA.
8. Publish a non-prerelease GitHub release for that immutable tag.
9. Run post-tag artifact verification and any publication-time deployment health checks required by the version's acceptance contract.

Candidate CI remains evidence for the implementation lineage, but the release tag identifies the fully integrated repository state that users obtain when checking out the published version.

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

These controls are PASS only after GitHub reports them active. An unavailable or unverifiable control is BLOCKED, not PASS.
