#!/usr/bin/env bash
# =============================================================================
# Build and test the Rails 8 API Docker image against a real database.
#
#  Usage:
#    bash scripts/test-docker.sh --database postgres    (default)
#    bash scripts/test-docker.sh --database sqlite
#
#  postgres mode (default):
#    - Builds `rails-8-api-authentication:postgres` from the immutable tag
#      `postgresql-baseline-v1` (64d8f32..., tip of origin/feat/postgresql).
#    - Starts a dedicated `postgres:17` container on a bridge network and
#      creates the production / cache / queue / cable databases.
#    - Runs the app on the host network (Rails/Puma on :4000) with the
#      environment from `.env.postgres` (fallback `.env`) plus the four
#      generated `*_DATABASE_URL` variables pointing at the PostgreSQL
#      container.
#
#  sqlite mode:
#    - Builds `rails-8-api-authentication:sqlite` from the immutable tag
#      `sqlite-baseline-v1` (34ae7e6..., tip of origin/main). SQLite databases
#      live in storage/ inside the image, so no database container is needed.
#    - Runs the app on the host network with the environment from `.env.sqlite`
#      (fallback `.env`) plus a generated SECRET_KEY_BASE.
#
#  Both modes build the image from a clean `git archive` snapshot of the
#  baseline tag (the working tree cannot leak in), wait for readiness on
#  /up, run scripts/test_all.sh against the container, and always tear down
#  containers and the network on exit.
#
#  Optional environment variables:
#    PROJECT_DIR=/path/to/app
#    API_BASE_URL=http://127.0.0.1:4000
#    SERVER_START_TIMEOUT=240
#    TEST_TIMEOUT=900
#    DB_CONTAINER_NAME=pg-rails-8-api-auth
#    APP_CONTAINER_NAME=app-rails-8-api-auth
#    DOCKER_NETWORK_NAME=rails-8-api-auth-net
#    PG_PUBLISHED_PORT=5433
#    SECRET_KEY_BASE=<hex>    (sqlite mode only; generated if unset)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
API_BASE_URL="${API_BASE_URL:-http://127.0.0.1:4000}"
SERVER_START_TIMEOUT="${SERVER_START_TIMEOUT:-240}"
TEST_TIMEOUT="${TEST_TIMEOUT:-900}"
DB_CONTAINER_NAME="${DB_CONTAINER_NAME:-pg-rails-8-api-auth}"
APP_CONTAINER_NAME="${APP_CONTAINER_NAME:-app-rails-8-api-auth}"
DOCKER_NETWORK_NAME="${DOCKER_NETWORK_NAME:-rails-8-api-auth-net}"
PG_PUBLISHED_PORT="${PG_PUBLISHED_PORT:-5433}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BUILD_DIR=""
APP_CONTAINER_STARTED=0
DB_CONTAINER_STARTED=0
NETWORK_CREATED=0

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

fail() {
  echo -e "${RED}ERROR: $*${NC}" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: bash scripts/test-docker.sh [--database postgres|sqlite]

Build and test the Rails 8 API Docker image against a real database.

  --database postgres    PostgreSQL mode (default): postgresql-baseline-v1
                         + a dedicated postgres:17 container.
  --database sqlite      SQLite mode: sqlite-baseline-v1 (main); no DB
                         container needed, databases live in storage/.
  -h, --help             Show this help and exit.

Both modes build from the immutable baseline tag via git archive, run the app
on the host network, wait for /up, run scripts/test_all.sh, and tear down.

Optional env vars: PROJECT_DIR, API_BASE_URL, SERVER_START_TIMEOUT,
TEST_TIMEOUT, DB_CONTAINER_NAME, APP_CONTAINER_NAME, DOCKER_NETWORK_NAME,
PG_PUBLISHED_PORT, SECRET_KEY_BASE (sqlite mode only).
EOF
  exit 0
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || fail "Required command not found: $command_name"
}

# --- Parse arguments -----------------------------------------------------------
DATABASE=""
while (($# > 0)); do
  case "$1" in
    --database)
      [[ -n "${2:-}" ]] || fail "Missing value for --database"
      DATABASE="$2"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      fail "Unknown argument: $1 (expected --database postgres|sqlite)"
      ;;
  esac
done
DATABASE="${DATABASE:-postgres}"
case "$DATABASE" in
  postgres | sqlite) ;;
  *)
    fail "Unsupported database '$DATABASE' (expected: postgres|sqlite)"
    ;;
esac

# --- Backend-specific configuration --------------------------------------------
case "$DATABASE" in
  postgres)
    IMAGE_NAME="rails-8-api-authentication:postgres"
    BASELINE_TAG="postgresql-baseline-v1"
    ENV_FILE_BASE=".env.postgres"
    PG_IMAGE="postgres:17"
    PG_USER="postgres"
    PG_PASSWORD="postgres"
    DB_BASE="rails_8_api_authentication_production"
    ;;
  sqlite)
    IMAGE_NAME="rails-8-api-authentication:sqlite"
    BASELINE_TAG="sqlite-baseline-v1"
    ENV_FILE_BASE=".env.sqlite"
    ;;
esac

cleanup() {
  local rc=$?
  trap - EXIT INT TERM
  log "Cleaning up..."
  if ((APP_CONTAINER_STARTED == 1)); then
    docker rm -f "$APP_CONTAINER_NAME" >/dev/null 2>&1 || true
    log "Removed app container: $APP_CONTAINER_NAME"
  fi
  if ((DB_CONTAINER_STARTED == 1)); then
    docker rm -f "$DB_CONTAINER_NAME" >/dev/null 2>&1 || true
    log "Removed PostgreSQL container: $DB_CONTAINER_NAME"
  fi
  if ((NETWORK_CREATED == 1)); then
    docker network rm "$DOCKER_NETWORK_NAME" >/dev/null 2>&1 || true
    log "Removed docker network: $DOCKER_NETWORK_NAME"
  fi
  if [[ -n "$BUILD_DIR" && -d "$BUILD_DIR" ]]; then
    rm -rf "$BUILD_DIR"
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

for cmd in docker git tar curl timeout mktemp jq openssl; do
  require_command "$cmd"
done

docker info >/dev/null 2>&1 || fail "docker daemon is not reachable (is dockerd running?)"

# --- Verify the immutable baseline tag ------------------------------------------
if [[ ! -d "$PROJECT_DIR/.git" ]]; then
  fail "Not a git repository: $PROJECT_DIR"
fi
TAG_COMMIT="$(git -C "$PROJECT_DIR" rev-parse --verify "refs/tags/$BASELINE_TAG^{commit}" 2>/dev/null || true)"
if [[ -z "$TAG_COMMIT" ]]; then
  fail "Tag '$BASELINE_TAG' not found in $PROJECT_DIR"
fi
log "Using $DATABASE baseline: tag $BASELINE_TAG ($TAG_COMMIT)"

# --- Pick the environment file: backend-specific, then .env fallback -------------
if [[ -f "$PROJECT_DIR/$ENV_FILE_BASE" ]]; then
  ENV_FILE="$PROJECT_DIR/$ENV_FILE_BASE"
elif [[ -f "$PROJECT_DIR/.env" ]]; then
  ENV_FILE="$PROJECT_DIR/.env"
else
  fail "Neither '$PROJECT_DIR/$ENV_FILE_BASE' nor '$PROJECT_DIR/.env' exists (database=$DATABASE)"
fi
log "Using environment file: $ENV_FILE"

# --- Build the image from a clean snapshot of the baseline tag -------------------
log "Building $IMAGE_NAME from tag $BASELINE_TAG ($TAG_COMMIT)..."
# The docker daemon may run on a different host than this workspace (e.g. a
# devcontainer), so BUILD_DIR must live under a path the daemon can see for the
# postgres init-script bind mount below to work (a missing host path would be
# silently created as an empty directory and break the init step).
mkdir -p "$PROJECT_DIR/tmp"
BUILD_DIR="$(mktemp -d "$PROJECT_DIR/tmp/docker-build.XXXXXX")"
git -C "$PROJECT_DIR" archive "$BASELINE_TAG" | tar -x -C "$BUILD_DIR"
if [[ ! -f "$BUILD_DIR/Dockerfile" ]]; then
  fail "Dockerfile not found in tag $BASELINE_TAG"
fi
if [[ "$DATABASE" == "postgres" && ! -f "$BUILD_DIR/config/postgres/init-databases.sql" ]]; then
  fail "config/postgres/init-databases.sql not found in tag $BASELINE_TAG"
fi
docker build -t "$IMAGE_NAME" "$BUILD_DIR"

# --- Provision the database (postgres mode only) ---------------------------------
if [[ "$DATABASE" == "postgres" ]]; then
  if docker network inspect "$DOCKER_NETWORK_NAME" >/dev/null 2>&1; then
    log "Reusing existing docker network: $DOCKER_NETWORK_NAME"
  else
    docker network create "$DOCKER_NETWORK_NAME" >/dev/null
    NETWORK_CREATED=1
    log "Created docker network: $DOCKER_NETWORK_NAME"
  fi

  docker rm -f "$DB_CONTAINER_NAME" >/dev/null 2>&1 || true
  log "Starting $PG_IMAGE container ($DB_CONTAINER_NAME) on 127.0.0.1:$PG_PUBLISHED_PORT..."
  docker run -d \
    --name "$DB_CONTAINER_NAME" \
    --network "$DOCKER_NETWORK_NAME" \
    -p "127.0.0.1:${PG_PUBLISHED_PORT}:5432" \
    -e "POSTGRES_USER=$PG_USER" \
    -e "POSTGRES_PASSWORD=$PG_PASSWORD" \
    -v "$BUILD_DIR/config/postgres/init-databases.sql:/docker-entrypoint-initdb.d/init-databases.sql:ro" \
    "$PG_IMAGE" >/dev/null
  DB_CONTAINER_STARTED=1

  wait_until() {
    local description="$1" deadline=$((SECONDS + 120))
    shift
    while true; do
      if ! docker ps --format '{{.Names}}' | grep -qx "$DB_CONTAINER_NAME"; then
        echo -e "${YELLOW}--- postgres container exited; last 40 log lines ---${NC}"
        docker logs "$DB_CONTAINER_NAME" 2>&1 | tail -n 40 || true
        fail "PostgreSQL container exited unexpectedly"
      fi
      ((SECONDS < deadline)) || {
        echo -e "${YELLOW}--- postgres did not become ready ($description); last 40 log lines ---${NC}"
        docker logs "$DB_CONTAINER_NAME" 2>&1 | tail -n 40 || true
        fail "PostgreSQL did not become ready within 120s"
      }
      if eval "$*"; then return 0; fi
      sleep 2
    done
  }
  # pg_isready answers "accepting connections" while the postgres entrypoint's
  # temporary bootstrap server is still running (same 5432 port); that server is
  # stopped right before the real one starts, so an early "ready" lets the app
  # connect into a dead window ("server closed the connection unexpectedly").
  # Wait for the init-complete marker first, then poll for the real server.
  log "Waiting for PostgreSQL init to complete (initdb + init scripts)..."
  wait_until "init complete" "docker logs \"$DB_CONTAINER_NAME\" 2>&1 | grep -q 'PostgreSQL init process complete; ready for start up.'"
  log "PostgreSQL init complete; waiting for the server to accept connections..."
  wait_until "accepting connections" "docker exec \"$DB_CONTAINER_NAME\" pg_isready -U \"$PG_USER\" -h 127.0.0.1 -p 5432 >/dev/null 2>&1"
  log "PostgreSQL ready."
fi

# --- Start the app container on the host network ----------------------------------
APP_ENV_ARGS=()
if [[ "$DATABASE" == "postgres" ]]; then
  DB_URL_BASE="postgres://${PG_USER}:${PG_PASSWORD}@127.0.0.1:${PG_PUBLISHED_PORT}"
  APP_ENV_ARGS+=(-e "DATABASE_URL=${DB_URL_BASE}/${DB_BASE}")
  APP_ENV_ARGS+=(-e "CACHE_DATABASE_URL=${DB_URL_BASE}/${DB_BASE}_cache")
  APP_ENV_ARGS+=(-e "QUEUE_DATABASE_URL=${DB_URL_BASE}/${DB_BASE}_queue")
  APP_ENV_ARGS+=(-e "CABLE_DATABASE_URL=${DB_URL_BASE}/${DB_BASE}_cable")
else
  SECRET_KEY_BASE="${SECRET_KEY_BASE:-$(openssl rand -hex 64)}"
  APP_ENV_ARGS+=(-e "SECRET_KEY_BASE=$SECRET_KEY_BASE")
  APP_ENV_ARGS+=(-e "RAILS_LOG_TO_STDOUT=true")
  APP_ENV_ARGS+=(-e "PORT=4000")
fi
APP_ENV_ARGS+=(-e RACK_ATTACK_SAFELIST_LOCALHOST=true)

docker rm -f "$APP_CONTAINER_NAME" >/dev/null 2>&1 || true
log "Starting app container ($APP_CONTAINER_NAME) on $API_BASE_URL..."
docker run -d \
  --name "$APP_CONTAINER_NAME" \
  --network host \
  --no-healthcheck \
  --env-file "$ENV_FILE" \
  "${APP_ENV_ARGS[@]}" \
  "$IMAGE_NAME" \
  ./bin/rails server >/dev/null
APP_CONTAINER_STARTED=1

# --- Wait for the app to boot (db:prepare + migrations + seed + server) -----------
readiness_url="${API_BASE_URL%/}/up"
log "Waiting for app readiness at $readiness_url..."
DEADLINE=$((SECONDS + SERVER_START_TIMEOUT))
until curl --noproxy '*' -sS -o /dev/null --connect-timeout 2 --max-time 4 "$readiness_url" 2>/dev/null; do
  if ! docker ps --format '{{.Names}}' | grep -qx "$APP_CONTAINER_NAME"; then
    echo -e "${YELLOW}--- app container exited; last 80 log lines ---${NC}"
    docker logs "$APP_CONTAINER_NAME" 2>&1 | tail -n 80 || true
    fail "App container exited unexpectedly"
  fi
  ((SECONDS < DEADLINE)) || {
    echo -e "${YELLOW}--- app container did not become ready; last 80 log lines ---${NC}"
    docker logs "$APP_CONTAINER_NAME" 2>&1 | tail -n 80 || true
    fail "App did not become ready within ${SERVER_START_TIMEOUT}s"
  }
  sleep 2
done
log "App ready at $readiness_url."

# --- Run the full API test suite against the container -----------------------------
log "Running scripts/test_all.sh against $API_BASE_URL ..."
set +e
API_BASE_URL="$API_BASE_URL" timeout --signal=TERM --kill-after=15s \
  "$TEST_TIMEOUT" bash "$PROJECT_DIR/scripts/test_all.sh"
TEST_RC=$?
set -e

if ((TEST_RC == 0)); then
  echo -e "${GREEN}✓ All API tests PASSED against the Docker image ($IMAGE_NAME).${NC}"
else
  echo -e "${RED}✗ API tests FAILED (exit $TEST_RC). See output above.${NC}"
fi
exit "$TEST_RC"
