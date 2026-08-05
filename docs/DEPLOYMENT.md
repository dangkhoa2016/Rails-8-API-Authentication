# Deployment Guide
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](DEPLOYMENT.vi.md)

This guide explains how to deploy the application to a production server using
**Kamal** (integrated by default in Rails 8).

## Requirements

- Ruby + Bundler on the deploy machine (not required on the server)
- Docker available or installable on the target server via `kamal setup`
- A Docker registry account (Docker Hub, ghcr.io, etc.)
- A Linux server with SSH access (user `root` or a user with sudo privileges)
- A domain/hostname pointing to the server’s IP (for Let's Encrypt SSL)

The production image bundles `libpq`, `curl`, and the small runtime packages
needed by the app, so no extra native dependency setup is required on the target
server beyond Docker itself. PostgreSQL 17 runs as a Kamal accessory (see
below).

---

## Step 1 — Prepare config/deploy.yml

Open `config/deploy.yml` and replace all placeholders `<...>`:

```yaml
# Image name on the registry
image: your-dockerhub-username/rails_8_api_authentication

# Server IP or hostname
servers:
  web:
    - 203.0.113.10          # replace with real IP

# Hostname for SSL (Let's Encrypt)
proxy:
  ssl: true
  host: api.your-domain.com  # replace with real domain

# Registry username
registry:
  username: your-dockerhub-username
```

> **SSL Note:** The domain must already point (DNS) to the server IP before the
> first deployment. Let's Encrypt requires HTTP verification.

---

## Step 2 — Prepare .kamal/secrets

The `.kamal/secrets` file reads secrets from the deploy machine’s environment,
**not** storing raw values. Ensure the following variables exist in your shell:

```bash
# Registry password (use access token, not real password)
export KAMAL_REGISTRY_PASSWORD=your-registry-access-token

# PostgreSQL accessory superuser password
export POSTGRES_PASSWORD=<random-long-password>

# Host (IP/hostname) that runs the PostgreSQL accessory — the same server
# where Kamal deploys. Required; `config/deploy.yml` reads it via ENV.fetch.
export POSTGRES_ACCESSORY_HOST=<server-ip-or-hostname>
```

The `.kamal/secrets` file is preconfigured to read `RAILS_MASTER_KEY` from
`config/master.key`:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
```

### Database URLs

Production requires **four distinct PostgreSQL URLs**; boot fails if any is
missing or duplicated (enforced by
`config/initializers/production_database_urls.rb`). Construct them in
`.kamal/secrets` from `POSTGRES_PASSWORD`, using the accessory host
`rails_8_api_authentication-db` on the Kamal network and the four exact database
names. Never commit rendered URLs:

```bash
DATABASE_URL=postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production
CACHE_DATABASE_URL=postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_cache
QUEUE_DATABASE_URL=postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_queue
CABLE_DATABASE_URL=postgresql://rails_auth:${POSTGRES_PASSWORD}@rails_8_api_authentication-db/rails_8_api_authentication_production_cable
```

Follow your provider's TLS policy for connections over non-trusted networks
(e.g. add `?sslmode=require` to each URL). The app sets a `statement_timeout`
from `POSTGRES_STATEMENT_TIMEOUT` (default `5000ms`) via `config/database.yml`.

### (Optional) Add DEVISE_JWT_SECRET_KEY

If you want to use an independent JWT secret (recommended for production),
uncomment the following line in `config/deploy.yml`:

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - DEVISE_JWT_SECRET_KEY   # ← uncomment
```

And add it to `.kamal/secrets`:

```bash
DEVISE_JWT_SECRET_KEY=$DEVISE_JWT_SECRET_KEY
```

Generate a random key:

```bash
bin/rails secret   # generates a 128-character hex string
```

---

## Step 3 — Prepare the server (first time)

```bash
# Install Docker on the server and configure SSH access
kamal setup
```

This command will:

* SSH into the server
* Install Docker if not present
* Pull the image from the registry
* Boot the PostgreSQL accessory and create the primary, cache, queue, and cable
  databases
* Create volume `rails_8_api_authentication_storage` for local Active Storage
  uploads
* Start the app container + Kamal proxy
* Obtain an SSL certificate from Let's Encrypt

The PostgreSQL accessory (`config/deploy.yml` → `accessories.db`) persists its
data in the `db` volume (`/var/lib/postgresql/data`). On a brand-new data
directory the official image runs `config/postgres/init-databases.sql` to create
`rails_8_api_authentication_production_cache`,
`rails_8_api_authentication_production_queue`, and
`rails_8_api_authentication_production_cable`. The primary database
(`rails_8_api_authentication_production`) is created by the image itself. If you
ever attach to an existing data directory, run the same script explicitly once
with `psql` — the image will not re-run it for you.

---

## Step 4 — Regular deployment

```bash
kamal deploy
```

Rolling deploy process:

1. Build a new image (`docker build`)
2. Push to the registry
3. Pull to the server
4. Run `bin/docker-entrypoint` (calls `bin/rails db:prepare` for the primary,
   cache, queue, and cable databases before starting the server)
5. Kamal proxy checks `/up` — traffic switches only after it returns 200
6. Old container is stopped

By default background jobs run inside the web process because
`SOLID_QUEUE_IN_PUMA=true` is set in `config/deploy.yml`. If you later move to a
dedicated job host, uncomment the `job` server block and update the related env
values.

---

## Common operational commands

```bash
# View realtime logs
kamal logs

# Open Rails console on the server
kamal console

# Open bash in the running container
kamal shell

# Open Rails dbconsole (PostgreSQL)
kamal dbc

# View container status
kamal app details

# Rollback to previous version
kamal rollback
```

> Aliases `console`, `shell`, `logs`, `dbc` are defined in `config/deploy.yml` →
> `aliases`.

---

## Environment variables

Refer to `.env.sample` for app-level defaults and to `config/deploy.yml` for
deploy-time/container runtime knobs. Key variables for production:

| Variable                | Required    | Default                         | Notes                                     |
| ----------------------- | ----------- | ------------------------------- | ----------------------------------------- |
| `RAILS_MASTER_KEY`      | ✅           | —                               | Decrypts `config/credentials.yml.enc`     |
| `DATABASE_URL`          | ✅           | —                               | Primary PostgreSQL connection URL         |
| `CACHE_DATABASE_URL`    | ✅           | —                               | Solid Cache database URL                  |
| `QUEUE_DATABASE_URL`    | ✅           | —                               | Solid Queue database URL                  |
| `CABLE_DATABASE_URL`    | ✅           | —                               | Solid Cable database URL                  |
| `POSTGRES_PASSWORD`     | ✅           | —                               | Accessory superuser password (`.kamal/secrets`) |
| `POSTGRES_STATEMENT_TIMEOUT` | Optional | `5000ms`                       | PostgreSQL `statement_timeout`            |
| `DEVISE_JWT_SECRET_KEY` | Recommended | falls back to `secret_key_base` | Rotate independently from master key      |
| `CORS_ALLOWED_ORIGINS`  | Recommended | `http://localhost:4000`         | Comma-separated browser origins allowed by Rack::Cors |
| `DEVISE_MAILER_SENDER`  | Recommended | `noreply@example.com`           | Change to a real sender domain/address    |
| `SOLID_QUEUE_IN_PUMA`   | Optional    | `true`                          | Set `false` if using separate job workers |
| `JOB_CONCURRENCY`       | Optional    | `1`                             | Number of Solid Queue worker threads      |
| `WEB_CONCURRENCY`       | Optional    | `1`                             | Increase if server has multiple CPUs      |
| `RAILS_LOG_LEVEL`       | Optional    | `info`                          | Set `debug` for troubleshooting           |

Production boot also logs warnings if `DEVISE_JWT_SECRET_KEY` is missing or if
`DEVISE_MAILER_SENDER` is still left at an example.com-style placeholder.

If a browser client runs on a different origin and needs to read the
`Authorization` response header from sign-in responses, update
`config/initializers/cors.rb` to expose that header explicitly. The current CORS
setup allows configured origins but does not expose custom response headers to
cross-origin browser JavaScript.

---

## PostgreSQL and persistence

Production data lives in PostgreSQL 17, which runs as a Kamal accessory
(`config/deploy.yml` → `accessories.db`). Its data directory is persisted in the
accessory volume `db` mounted at `/var/lib/postgresql/data`. The application
uses four databases:

| Database | Purpose | Notes |
|----------|---------|-------|
| `rails_8_api_authentication_production` | Primary Active Record database | Business-critical, back up first |
| `rails_8_api_authentication_production_cache` | Solid Cache | Rebuildable |
| `rails_8_api_authentication_production_queue` | Solid Queue | Retention policy needed |
| `rails_8_api_authentication_production_cable` | Solid Cable | Retention policy needed |

Local Active Storage uploads are a separate concern: they persist in volume
`rails_8_api_authentication_storage` mounted at `/rails/storage`, not in
PostgreSQL. Back up both.

**Backup and restore:**

Use `pg_dump` custom format for each database. The primary database is
business-critical; cache can be rebuilt; queue/cable retention must follow your
documented policy.

```bash
# Inside the accessory (or from a host with psql access)
pg_dump --format=custom --file=/backup/primary.dump \
  -h rails_8_api_authentication-db -U rails_auth \
  rails_8_api_authentication_production
# Repeat for cache, queue, and cable with their database names.

# Restore ONLY into a verified non-production target
pg_restore --clean --if-exists --dbname=rails_8_api_authentication_staging \
  /backup/primary.dump
```

For scripted restores, use a `.pgpass` file with mode `0600` or your provider's
secret mechanism; never place passwords in shell history.

**Connection budget:**

Keep total connections below the PostgreSQL `max_connections` (or your pooler
limit):

```text
maximum application connections = WEB_CONCURRENCY × RAILS_MAX_THREADS
                                + JOB_CONCURRENCY × Solid Queue threads
                                + deployment/console headroom
```

Each database URL in `config/database.yml` is a separate connection pool, so
multiply the primary budget across the four databases when sizing the server.

**Accessing the database:**

```bash
kamal accessory exec db -- psql -U rails_auth rails_8_api_authentication_production
```

---

## Non-goal: no live SQLite cutover

This branch replaces the SQLite baseline with PostgreSQL going forward; it does
**not** copy live SQLite rows. A real cutover requires row inventory,
foreign-key ordering, sequence resets, counts/checksums, a rehearsal, a freeze
window, and a rollback plan — all out of scope here. Treat the SQLite variant
(recoverable at the `sqlite-baseline-v1` tag) as the pre-migration recovery
point, and only restore PostgreSQL backups into verified non-production targets.

---

## Health Check

The container health is monitored in two layers:

1. **Docker HEALTHCHECK** (in Dockerfile): `curl -f http://localhost/up` — 30s
   interval, 5s timeout, starts after 60s
2. **Kamal proxy healthcheck** (in `config/deploy.yml`): `GET /up` — 10s
   interval, 5s timeout — used to decide traffic routing during rolling deploy

The `/up` endpoint returns `200` when Rails boots successfully, `500` if there
is an exception during startup.

---

## Pre-deployment checklist (first time)

* [ ] `config/deploy.yml` — all `<...>` placeholders replaced
* [ ] `config/master.key` — available on deploy machine, not committed to git
* [ ] DNS points domain to server IP
* [ ] `KAMAL_REGISTRY_PASSWORD` exists in shell
* [ ] `POSTGRES_PASSWORD` set and the four database URLs added to
  `.kamal/secrets`
* [ ] Docker registry created (Docker Hub, ghcr.io, etc.)
* [ ] Server ports 80 and 443 are open
* [ ] (Optional) `DEVISE_JWT_SECRET_KEY` created and added to `.kamal/secrets`
