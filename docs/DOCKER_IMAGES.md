# Docker Images

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](DOCKER_IMAGES.vi.md)

This guide explains how to build and publish **multi-architecture Linux container images**
for the application to the **GitHub Container Registry (GHCR)**.

The published images target:

- `linux/amd64` — Intel/AMD x86-64 Linux hosts, Intel Macs through Docker Desktop,
  and most Windows PCs through Docker Desktop/WSL2 using Linux containers.
- `linux/arm64` — ARM64 Linux servers, Apple Silicon Macs through Docker Desktop,
  and ARM64 Windows systems using Linux containers.

For modern Docker users, these two platforms cover the large majority of desktop,
server, cloud, macOS, and Windows Docker installations. These are **Linux container
images**, not native Windows-container images.

Once the GHCR package is made **public**, anyone can pull it anonymously without a
GitHub login or package token.

## Overview

Two publishable image variants exist, one per database backend:

| Image | Database | Built from tag | Commit |
| --- | --- | --- | --- |
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres` | PostgreSQL 17 | `postgresql-baseline-v1` | `e7565fd` |
| `ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite` | SQLite | `sqlite-baseline-v1` | `700edca` |

Both images share the same runtime behaviour:

- Expose port **80** — Thruster in front of Puma (`./bin/thrust ./bin/rails server`).
- The entrypoint runs `db:prepare`, so the database is created/migrated on first boot.
- Ship **no secrets**: only `RAILS_ENV=production` is baked in. Database URLs,
  `SECRET_KEY_BASE`, and admin credentials must be provided at run time through
  environment variables (the Docker build ignores `.env*` and `config/master.key`).
- Are built from immutable **Git baseline tags**, so the exact application source used
  for each published variant can be recovered. Note that this does not by itself make
  the complete Docker build bit-for-bit reproducible because upstream base-image tags
  and operating-system packages can change over time.

## Compatibility target

The recommended published manifest contains:

```text
linux/amd64
linux/arm64
```

This gives users one image tag to pull. Docker automatically selects the correct
platform from the multi-platform manifest for the host.

Examples:

| User machine | Selected image |
| --- | --- |
| Linux on Intel/AMD | `linux/amd64` |
| Linux ARM64 / AWS Graviton | `linux/arm64` |
| macOS Intel + Docker Desktop | `linux/amd64` |
| macOS Apple Silicon + Docker Desktop | `linux/arm64` |
| Windows x86-64 + Docker Desktop/WSL2 | `linux/amd64` |
| Windows ARM64 + Docker Desktop | `linux/arm64` |

32-bit ARM, 32-bit x86, PowerPC, s390x, RISC-V, and native Windows containers are
outside the supported target unless they are explicitly built and tested later.

## Recommended tag strategy

Publish a convenient moving tag plus immutable/version-specific tags.

PostgreSQL:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-v1
ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-e7565fd
```

SQLite:

```text
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1
ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-700edca
```

Users who want the current variant can use `:postgres` or `:sqlite`. Users who want a
stable deployment should pin a version or commit tag.

## Requirements for manual publishing

- Docker with Buildx enabled (`docker buildx version`).
- The baseline Git tags available locally: `git fetch --tags`.
- For command-line publishing to GHCR: a **GitHub Personal Access Token (classic)**
  with the `write:packages` scope, owned by `dangkhoa2016` or the target account.
- Docker Desktop normally provides the required emulation support automatically.
  On a Linux Docker Engine host, QEMU/binfmt may need to be installed when building
  an architecture different from the host architecture.

> GitHub Packages authentication for command-line publishing uses a Personal Access
> Token **(classic)**. Do not document a fine-grained `packages:write` token as a
> replacement for this GHCR login flow.

## Step 1 — Log in to GHCR for manual publishing

Store the classic PAT in an environment variable instead of placing it directly in
shell history:

```bash
echo "$PAT" | docker login ghcr.io -u dangkhoa2016 --password-stdin
```

Never commit or bake the PAT into the Docker image.

> If publishing with GitHub Actions from the repository itself, prefer the workflow's
> `GITHUB_TOKEN`; a personal PAT is normally unnecessary for that workflow.

## Step 2 — Create a multi-architecture builder

Create the builder once:

```bash
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

If `multiarch` already exists, reuse it:

```bash
docker buildx use multiarch
docker buildx inspect --bootstrap
```

### QEMU / emulation

On **Docker Desktop**, manual QEMU installation is normally not required.

On **Linux Docker Engine**, if the builder cannot build `linux/arm64` from an x86-64
host (or vice versa), install binfmt/QEMU and then bootstrap the builder again:

```bash
docker run --privileged --rm tonistiigi/binfmt --install arm64
docker buildx inspect --bootstrap
```

Check the builder's supported platforms:

```bash
docker buildx inspect
```

The platform list should include both `linux/amd64` and `linux/arm64`.

## Step 3 — Build and push the images

Build from the immutable baseline Git tags so each published variant uses the exact
application source associated with that baseline.

```bash
REPOSITORY="https://github.com/dangkhoa2016/rails-8-api-authentication"

TMP="$(mktemp -d)"
git archive postgresql-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=e7565fd" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres-e7565fd \
  --push "$TMP"

rm -rf "$TMP"

TMP="$(mktemp -d)"
git archive sqlite-baseline-v1 | tar -x -C "$TMP"

docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --label "org.opencontainers.image.source=$REPOSITORY" \
  --label "org.opencontainers.image.revision=700edca" \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-v1 \
  -t ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite-700edca \
  --push "$TMP"

rm -rf "$TMP"
```

Notes:

- `--push` publishes the multi-platform manifest directly; no separate `docker tag`
  or `docker push` is required.
- Docker will pull the correct architecture automatically when a user pulls one of
  these tags.
- The OCI `org.opencontainers.image.source` label associates the image metadata with
  the source repository and makes the published artifact easier to trace.
- The `ruby:3.3-slim` official image is multi-architecture. The application and all
  native dependencies must still build successfully for every platform you publish.
- To build from the current working tree instead, replace the temporary directory
  context with `.`. Do this only when you intentionally want to publish untagged source.
- Add `--provenance=false` only if downstream tooling specifically cannot handle build
  attestations. Otherwise leave the default provenance behaviour enabled.

## Step 4 — Verify the published multi-platform manifests

Do not assume a push produced both architectures. Inspect each published tag:

```bash
docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres

docker buildx imagetools inspect \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

Each result should contain both:

```text
linux/amd64
linux/arm64
```

You can also explicitly test pulls for each architecture on a machine with suitable
native support or emulation:

```bash
docker pull --platform linux/amd64 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite

docker pull --platform linux/arm64 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

## Step 5 — Make the GHCR package public

When a GHCR package is published for the first time, its default visibility is **private**.
Change it to **Public** before expecting anonymous users to pull it.

In GitHub:

1. Open the package page for `rails-8-api-authentication`.
2. Open **Package settings**.
3. Under **Danger Zone**, choose **Change visibility**.
4. Change the package to **Public**.
5. Confirm the visibility change.

A public GHCR container package can be pulled anonymously, so end users do not need a
GitHub account, PAT, or `docker login` just to run the image.

After making the package public, verify anonymously from a logged-out Docker client:

```bash
docker logout ghcr.io 2>/dev/null || true
docker pull ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
docker pull ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
```

## Step 6 — Run the images

For the widest cross-platform compatibility, prefer `--env-file` over shell-specific
inline environment-variable syntax. It works consistently with Docker CLI on Linux,
macOS, Windows PowerShell, WSL, and other common environments.

### Generate a production secret

This command uses the Ruby Docker image itself, so the host does not need OpenSSL:

```bash
docker run --rm ruby:3.3-slim \
  ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Copy the generated value into a local environment file that is **not committed**.

### PostgreSQL image

The application validates at boot that all four databases exist and are distinct
(`config/initializers/production_database_urls.rb`). Create the `_cache`, `_queue`,
and `_cable` databases beforehand on the PostgreSQL server; the primary database is
created by `db:prepare` according to the application's current startup flow.

Create `.env.production.local`:

```dotenv
SECRET_KEY_BASE=replace-with-a-random-secret
DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production
CACHE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_cache
QUEUE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_queue
CABLE_DATABASE_URL=postgres://user:password@dbhost:5432/rails_8_api_authentication_production_cable
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-me
```

Run:

```bash
docker run -d \
  --name rails-postgres \
  --env-file .env.production.local \
  -p 80:80 \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:postgres
```

If PostgreSQL runs directly on the Docker host rather than on another reachable
server/container, hostname handling differs by host OS. Docker Desktop commonly
provides `host.docker.internal`; Linux Engine users may need an explicit host-gateway
mapping or a Docker network.

### SQLite image

Create `.env.production.local`:

```dotenv
SECRET_KEY_BASE=replace-with-a-random-secret
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=change-me
```

Run:

```bash
docker run -d \
  --name rails-sqlite \
  --env-file .env.production.local \
  -p 80:80 \
  -v rails_storage:/rails/storage \
  ghcr.io/dangkhoa2016/rails-8-api-authentication:sqlite
```

The SQLite database files live in `/rails/storage` inside the container. The named
volume keeps them across container recreation.

### `SECRET_KEY_BASE` versus `RAILS_MASTER_KEY`

`RAILS_MASTER_KEY` is **not** the same secret as `SECRET_KEY_BASE`.

- `RAILS_MASTER_KEY` decrypts Rails encrypted credentials.
- `SECRET_KEY_BASE` is the Rails application secret used for cryptographic signing.
- You may omit the `SECRET_KEY_BASE` environment variable only when a valid
  `RAILS_MASTER_KEY` is supplied **and** the encrypted Rails credentials contain a
  usable `secret_key_base` value for the production application.

For a public example image that intentionally does not ship a private master key,
providing `SECRET_KEY_BASE` at runtime is the simpler deployment model.

### Verify

```bash
curl -s http://localhost/up
```

Expected result: HTTP `200 OK`.

Then sign in with the configured admin credentials.

## Recommended — Publish automatically with GitHub Actions

For a public GitHub repository, GitHub Actions is preferable to manually publishing
from a developer workstation. The workflow can use `GITHUB_TOKEN` with `packages: write`
instead of storing a personal PAT for ordinary repository-owned publishing.

A repository workflow can use a matrix to build each baseline as a multi-platform
image. Example:

```yaml
name: Publish Docker images

on:
  workflow_dispatch:
  push:
    tags:
      - "docker-*"

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - variant: postgres
            ref: postgresql-baseline-v1
            version: postgres-v1
            commit_tag: postgres-e7565fd
            source_commit: e7565fd
          - variant: sqlite
            ref: sqlite-baseline-v1
            version: sqlite-v1
            commit_tag: sqlite-700edca
            source_commit: 700edca

    steps:
      - name: Check out baseline
        uses: actions/checkout@v7
        with:
          ref: ${{ matrix.ref }}

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.variant }}
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.version }}
            ghcr.io/dangkhoa2016/rails-8-api-authentication:${{ matrix.commit_tag }}
          labels: |
            org.opencontainers.image.source=https://github.com/dangkhoa2016/rails-8-api-authentication
            org.opencontainers.image.revision=${{ matrix.source_commit }}
```

For long-lived production workflows, consider pinning third-party GitHub Actions to
full commit SHAs instead of moving version tags. GitHub explicitly recommends this for
supply-chain stability.

After the first workflow publish, still verify that the GHCR package visibility is
**Public** if anonymous pulls are required.

## Troubleshooting

- **`exec format error` on an ARM machine** — inspect the GHCR manifest. The tag may
  contain only `linux/amd64`; republish with both `linux/amd64` and `linux/arm64`.
- **401 Unauthorized on `docker pull`** — verify the GHCR package is actually Public.
  Public Container registry packages support anonymous pulls.
- **The public repository is visible but `docker pull` still requires authentication** —
  repository visibility and package visibility are separate concepts. Check the package's
  own settings.
- **`arm64` build is slow on an x86-64 builder** — QEMU emulation is slower than a
  native ARM64 builder. This is expected.
- **Build works on `amd64` but fails on `arm64`** — inspect native gems, OS packages,
  and any precompiled binaries. A multi-architecture base image alone does not guarantee
  every application dependency supports every architecture.
- **Builder does not list `linux/arm64`** — on Linux Engine, install binfmt/QEMU and
  rerun `docker buildx inspect --bootstrap`. Docker Desktop normally handles this
  automatically.
- **Windows user cannot run the image as a native Windows container** — this project
  publishes Linux containers. Windows users should run Docker Desktop/WSL2 in Linux
  container mode.

## Official references

- Docker multi-platform builds: https://docs.docker.com/build/building/multi-platform/
- Docker multi-platform GitHub Actions: https://docs.docker.com/build/ci/github-actions/multi-platform/
- GitHub Container registry: https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- GitHub package permissions and visibility: https://docs.github.com/packages/learn-github-packages/about-permissions-for-github-packages
- GitHub Actions Docker publishing: https://docs.github.com/actions/guides/publishing-docker-images
- Rails credentials/security: https://guides.rubyonrails.org/security.html
