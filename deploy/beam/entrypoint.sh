#!/usr/bin/env bash
set -Eeuo pipefail

WEB_PORT="${WEB_PORT:-8080}"
RUN_DB_PREPARE="${RUN_DB_PREPARE:-true}"
DB_PREPARE_MAX_ATTEMPTS="${DB_PREPARE_MAX_ATTEMPTS:-3}"
DB_PREPARE_RETRY_DELAY="${DB_PREPARE_RETRY_DELAY:-2}"

log() { printf '[beam-entrypoint] %s\n' "$*"; }
die() { printf '[beam-entrypoint] ERROR: %s\n' "$*" >&2; exit 1; }
require_env() { [[ -n "${!1:-}" ]] || die "$1 is required"; }

require_env DATABASE_URL
require_env CACHE_DATABASE_URL
require_env QUEUE_DATABASE_URL
require_env CABLE_DATABASE_URL
require_env SECRET_KEY_BASE
require_env DEVISE_JWT_SECRET_KEY
require_env CORS_ALLOWED_ORIGINS

cd /rails

if [[ "${RUN_DB_PREPARE,,}" == "true" ]]; then
  attempt=1
  until RAILS_ENV=production ./bin/rails db:prepare; do
    (( attempt < DB_PREPARE_MAX_ATTEMPTS )) || die "db:prepare failed after ${attempt} attempts"
    sleep "${DB_PREPARE_RETRY_DELAY}"
    attempt=$((attempt + 1))
  done
fi

log "starting Puma on 0.0.0.0:${WEB_PORT}"
exec ./bin/rails server -e production -b 0.0.0.0 -p "${WEB_PORT}"
