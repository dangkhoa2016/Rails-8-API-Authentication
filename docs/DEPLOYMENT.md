# Deployment Guide
> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](DEPLOYMENT.vi.md)

This guide explains how to deploy the application to a production server using **Kamal** (integrated by default in Rails 8).

## Requirements

- Ruby + Bundler on the deploy machine (not required on the server)
- Docker installed on the target server
- A Docker registry account (Docker Hub, ghcr.io, etc.)
- A Linux server with SSH access (user `root` or a user with sudo privileges)
- A domain/hostname pointing to the server’s IP (for Let's Encrypt SSL)

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

> **SSL Note:** The domain must already point (DNS) to the server IP before the first deployment. Let's Encrypt requires HTTP verification.

---

## Step 2 — Prepare .kamal/secrets

The `.kamal/secrets` file reads secrets from the deploy machine’s environment, **not** storing raw values. Ensure the following variables exist in your shell:

```bash
# Registry password (use access token, not real password)
export KAMAL_REGISTRY_PASSWORD=your-registry-access-token

# Option 1: read from file (most common)
# File config/master.key MUST NOT be committed to git
# Obtain it from the project maintainer or password manager
```

The `.kamal/secrets` file is preconfigured to read `RAILS_MASTER_KEY` from `config/master.key`:

```bash
RAILS_MASTER_KEY=$(cat config/master.key)
```

### (Optional) Add DEVISE_JWT_SECRET_KEY

If you want to use an independent JWT secret (recommended for production), uncomment the following line in `config/deploy.yml`:

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
* Create volume `rails_8_api_authentication_storage` for SQLite
* Start the container + Kamal proxy (Traefik)
* Obtain an SSL certificate from Let's Encrypt

---

## Step 4 — Regular deployment

```bash
kamal deploy
```

Rolling deploy process:

1. Build a new image (`docker build`)
2. Push to the registry
3. Pull to the server
4. Run `bin/docker-entrypoint` (calls `bin/rails db:prepare` before starting the server)
5. Kamal proxy checks `/up` — traffic switches only after it returns 200
6. Old container is stopped

---

## Common operational commands

```bash
# View realtime logs
kamal logs

# Open Rails console on the server
kamal console

# Open bash in the running container
kamal shell

# Open Rails dbconsole (SQLite)
kamal dbc

# View container status
kamal app details

# Rollback to previous version
kamal rollback
```

> Aliases `console`, `shell`, `logs`, `dbc` are defined in `config/deploy.yml` → `aliases`.

---

## Environment variables

Refer to `.env.sample` for the full list. Key variables for production:

| Variable                | Required    | Default                         | Notes                                     |
| ----------------------- | ----------- | ------------------------------- | ----------------------------------------- |
| `RAILS_MASTER_KEY`      | ✅           | —                               | Decrypts `config/credentials.yml.enc`     |
| `DEVISE_JWT_SECRET_KEY` | Recommended | falls back to `secret_key_base` | Rotate independently from master key      |
| `DEVISE_MAILER_SENDER`  | Recommended | `noreply@example.com`           | Change to a real sender domain/address    |
| `SOLID_QUEUE_IN_PUMA`   | Optional    | `true`                          | Set `false` if using separate job workers |
| `WEB_CONCURRENCY`       | Optional    | `1`                             | Increase if server has multiple CPUs      |
| `RAILS_LOG_LEVEL`       | Optional    | `info`                          | Set `debug` for troubleshooting           |

---

## SQLite and persistence

Production SQLite data is stored in Docker volume `rails_8_api_authentication_storage` → mounted at `/rails/storage` inside the container. The app uses multiple SQLite files there: `production.sqlite3`, `production_cache.sqlite3`, `production_queue.sqlite3`, and `production_cable.sqlite3`.

**Backup:**

```bash
# From local machine — copy the primary app DB file out
kamal shell
# inside container:
sqlite3 /rails/storage/production.sqlite3 ".backup '/tmp/backup.sqlite3'"
# then use docker cp or scp to retrieve the file
```

> If the project requires multi-server deployment or high availability (HA), switch to PostgreSQL/MySQL. SQLite is suitable only for single-server setups.

---

## Health Check

The container health is monitored in two layers:

1. **Docker HEALTHCHECK** (in Dockerfile): `curl -f http://localhost/up` — 30s interval, 5s timeout, starts after 60s
2. **Kamal proxy healthcheck** (in `config/deploy.yml`): `GET /up` — 10s interval, 5s timeout — used to decide traffic routing during rolling deploy

The `/up` endpoint returns `200` when Rails boots successfully, `500` if there is an exception during startup.

---

## Pre-deployment checklist (first time)

* [ ] `config/deploy.yml` — all `<...>` placeholders replaced
* [ ] `config/master.key` — available on deploy machine, not committed to git
* [ ] DNS points domain to server IP
* [ ] `KAMAL_REGISTRY_PASSWORD` exists in shell
* [ ] Docker registry created (Docker Hub, ghcr.io, etc.)
* [ ] Server ports 80 and 443 are open
* [ ] (Optional) `DEVISE_JWT_SECRET_KEY` created and added to `.kamal/secrets`
