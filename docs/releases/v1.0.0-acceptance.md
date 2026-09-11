# v1.0.0 Final Acceptance Record

This document is the canonical public acceptance record for the first stable
semantic-versioned release of Rails 8 API Authentication.

`v1.0.0` represents the project as a whole. It is not identified by one late
corrective, one endpoint, or one deployment provider. Release metadata must
summarize the complete authentication, security, operational, validation, and
deployment scope that was accepted for the first community-facing stable
release.

## Release identity

- Version: `v1.0.0`
- Channel: stable
- Public prerelease: none
- Initial community-publication closeout date: 2026-09-12
- Tag form: annotated
- Authoritative source: the peeled target of `v1.0.0`
- Publication rule: the tag target must equal the exact `main` SHA that
  completes the mandatory post-rewrite CI gates successfully immediately
  before final publication.
- Publication artifacts: the annotated tag, GitHub Release notes, provenance,
  checksums, and coverage artifacts must all describe that same final source
  and CI-qualified publication event.

This file intentionally does not hard-code the SHA of the commit that contains
it. Embedding that SHA would be self-referential and would change the commit
being identified. The annotated tag message, GitHub Release notes, and release
provenance record the exact final SHA, tree, CI run, and publication metadata
after the final CI gate passes.

## Stable release scope

### Authentication and account lifecycle

The stable release includes the complete public authentication and account
management contract documented by the repository:

- registration with required `username`;
- email confirmation;
- sign-in and sign-out;
- Devise/JWT access tokens with denylist-backed revocation;
- refresh-token rotation, reuse detection, and token-family revocation;
- signed HttpOnly refresh-token transport for browser clients and raw
  refresh-token transport for native, mobile, and CLI clients;
- authenticated profile access through `/user/profile` with compatibility
  aliases `/user/me` and `/user/whoami`;
- self-service account update and deletion;
- active/inactive account enforcement;
- admin user listing, creation, role updates, deletion, status changes, and
  force-confirmation;
- API-native password reset.

Password reset is one feature of the stable authentication stack, not the
identity of the release.

### Security and operational controls

The release includes:

- Rack::Attack limits for general API traffic and authentication-sensitive
  endpoints;
- Brakeman static analysis;
- RuboCop policy checks;
- repository-policy validation;
- JWT denylist and refresh-token cleanup through Active Job, Solid Queue, and
  the documented Rake task;
- explicit secret-handling and production deployment contracts;
- PostgreSQL 17 with Solid Cache, Solid Queue, and Solid Cable.

### Runtime and deployment scope

The project remains portable across Rails/PostgreSQL hosting environments.

Accepted and documented deployment paths include:

- the production-style public Modal.com demonstration;
- PostgreSQL on Neon for the accepted public demo;
- Docker and Kamal deployment guidance;
- the verified Beam.cloud deployment path;
- the documented Hugging Face Spaces deployment path.

The public demo is intentionally bounded. It does not claim high availability,
an SLA, multi-tenant operation, or volumetric-DDoS immunity.

### Runtime compatibility and CI qualification

The release supports and tests:

- Ruby 3.2;
- Ruby 3.3;
- Ruby 4.0.

The mandatory GitHub Actions qualification contains nine required jobs:

- `audit_gems`;
- `scan_ruby`;
- `release_contract`;
- `lint`;
- `schema_load`;
- `test_custom_header`;
- `test (3.2)`;
- `test (3.3)`;
- `test (4.0)`.

Final publication additionally requires the four established CircleCI
contexts to report success for the exact final source SHA.

## Release presentation contract

The public presentation of `v1.0.0` must describe the complete stable release
without making internal publication-corrective chronology part of the release
identity.

The annotated tag and GitHub Release serve different public purposes:

- the annotated tag is concise authority: stable release identity, exact source
  and tree, CI qualification, and the canonical acceptance record;
- the GitHub Release explains the project-wide feature, security, deployment,
  validation, and release-integrity scope in user-facing language;
- detailed rewrite mappings, superseded publication SHAs, and documentation-only
  corrective mechanics remain in provenance/acceptance evidence rather than the
  public tag summary.

Password reset is one capability within the stable project and must not replace
the project-wide release identity.

## Mandatory publication gates

| Gate | PASS requirement |
| --- | --- |
| Repository hardening | Mandatory GitHub CI completes successfully on the exact final `main` SHA. |
| Secondary CI | All four established CircleCI contexts complete successfully on that same final source SHA. |
| Release contract | Repository-owned release tooling validates fail closed and the release documentation is internally consistent. |
| Published baselines | Frozen PostgreSQL and SQLite GHCR baselines pass revision and multi-platform verification. |
| Deployment portability | Public demo recipes contain no committed private credentials and retain truthful provider-specific limitations. |
| Production acceptance | The accepted public runtime flow has completed functional acceptance, with any publication-only rewrite proven not to change runtime files. |
| Final readiness | Repository controls are active, no known release blocker remains, and `v1.0.0` is finalized only after the exact-main CI gates pass. |

A missing, skipped, cancelled, queued, or failing required context is not PASS.

## Frozen baseline provenance

The pre-1.0 database source lines remain immutable historical baselines:

- PostgreSQL: `6897c773ec1321401e52c21c63870a72d01ca349`
- SQLite: `1d842b18c1d1b07c027cbb7d49c19a52d16f98bc`

Their immutable tags remain:

- `baseline-postgresql-v1`
- `baseline-sqlite-v1`

Stable-release finalization must not move or rewrite either baseline.

## Deployment evidence and provider scope

### Beam.cloud

A real full smoke was observed against the frozen PostgreSQL runtime path:

- `/up`: HTTP 200
- `/users/sign_in`: authentication PASS
- `/user/profile`: authenticated profile PASS
- JWT transport on the tested Beam path: `X-Authorization`

The Beam recipe derives from:

`ghcr.io/dangkhoa2016/rails-8-api-authentication:postgresql-6897c77`

whose frozen source baseline is
`6897c773ec1321401e52c21c63870a72d01ca349`.

This evidence proves the documented Beam deployment and authentication path
against that frozen PostgreSQL runtime. It does not claim that the Beam
container itself was built from the final `v1.0.0` tag target.

### Hugging Face Spaces

The canonical production-style guidance uses the frozen PostgreSQL runtime and
documents the required PostgreSQL connection contract. The SQLite baseline is
retained only as an immutable compatibility and historical reference.

### Modal.com

The final source includes a bounded public production-style Modal demo:

- standard `Authorization: Bearer <JWT>` transport;
- CPU-only runtime;
- `min_containers=0`, `max_containers=1`;
- fail-closed deployment preflight;
- public smoke checks for health, authentication, rate-limit behavior, and
  transactional-email delivery acceptance;
- Resend-backed production email configuration with secrets kept outside Git.

This is a production-style demo, not an HA deployment, SLA-backed service,
multi-tenant platform, or claim of volumetric DDoS immunity.

## Runtime provenance

Source qualification and runtime/deployment evidence are separate dimensions:

- mandatory push CI qualifies the exact source commit used for the stable tag;
- `verify_ghcr.sh` verifies the immutable database baseline artifacts;
- provider recipes may intentionally derive from a frozen baseline image;
- provider acceptance must state the actual runtime provenance and must not
  imply a build provenance that was not observed;
- if an explicitly authorized pre-publication history rewrite changes only
  release documentation, the publication process must prove that no runtime,
  deployment, application, test, or security-policy file changed relative to
  the already accepted runtime source, and the rewritten final SHA must still
  pass the complete CI gates before retagging.

## Password-reset API contract

Password reset is API-native. `POST /users/password` sends an email with the
reset token, the canonical JSON payload, and a `curl` example for
`PUT /users/password`.

The API does not bundle a browser reset form or advertise a conventional
browser reset link. `GET /users/password/edit` exists only as an instruction
compatibility route: with a token it returns no-store, no-referrer plain-text
API instructions and does not mutate or consume the token.

`PUT /users/password` is the sole password-reset mutation authority.

## Repository controls

The stable publication contract requires repository rules to be restored after
any explicitly authorized pre-publication history rewrite.

Protected refs include:

- `main`;
- `baseline/postgresql-v1`;
- `baseline/sqlite-v1`.

For `main`, the intended steady-state controls are:

- require pull request before merge;
- require all mandatory status checks;
- block force pushes;
- block deletion.

The frozen baseline refs remain protected from force pushes and deletion.

## Publication decision

`v1.0.0` is accepted for first community publication only when all of the
following are simultaneously true:

1. the final rewritten `main` contains this acceptance record;
2. `docs/superpowers/` is absent from the public source tree and rewritten
   release history;
3. mandatory GitHub Actions CI is `completed / success` on the exact final
   `main` SHA;
4. all four established CircleCI contexts report success for that same SHA;
5. the annotated `v1.0.0` tag points to that same SHA;
6. the annotated tag message describes the project-wide release rather than a
   single corrective;
7. GitHub Release notes identify the same SHA, tree, CI qualification, runtime
   acceptance, and project-wide feature scope;
8. release coverage artifacts, provenance, and checksums are regenerated from
   the final CI-qualified publication state and replace any pre-closeout
   versions;
9. repository rules are active again after the authorized rewrite;
10. no known release-blocking issue remains.

During first community-publication preparation, an explicitly authorized
in-place corrective may replace release documentation, tag metadata, release
notes, and release artifacts without adding a semantic version, provided
commit count/topology are preserved, runtime behavior is not changed by the
presentation-only corrective, repository protections are restored before CI,
and the exact rewritten `main` is requalified by the complete CI gates before
the tag moves.

The final public-review closeout occurs only after the intended public tag,
Release notes, provenance, checksums, and coverage artifacts have all been
verified against that CI-qualified source. Once that final public-review
closeout is declared complete, `v1.0.0` becomes immutable; later source changes
require a subsequent semantic version.
