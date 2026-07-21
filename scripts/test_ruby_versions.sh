#!/usr/bin/env bash
# =============================================================================
# Rails Ruby-version matrix test runner using mise
#
# Default Ruby versions:
#   3.2.2 3.3.6 3.4.9 4.0.1 4.0.5
#
# Expected project layout:
#   .env
#   Gemfile
#   bin/setup
#   scripts/test_all.sh
#
# Usage:
#   chmod +x scripts/test_ruby_versions.sh
#   ./scripts/test_ruby_versions.sh
#
# Test only selected versions:
#   ./scripts/test_ruby_versions.sh 3.2.2 3.4.9
#
# Optional environment variables:
#   PROJECT_DIR=/path/to/app
#   API_BASE_URL=http://127.0.0.1:4000
#   SERVER_START_TIMEOUT=600
#   TEST_TIMEOUT=900
#   STOP_TIMEOUT=20
#   REPORT_BASE_DIR=/path/to/reports
# =============================================================================

set -uo pipefail

DEFAULT_RUBY_VERSIONS=(3.2.2 3.3.6 3.4.9 4.0.1 4.0.5)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
SERVER_START_TIMEOUT="${SERVER_START_TIMEOUT:-600}"
TEST_TIMEOUT="${TEST_TIMEOUT:-900}"
STOP_TIMEOUT="${STOP_TIMEOUT:-20}"
REPORT_BASE_DIR="${REPORT_BASE_DIR:-$PROJECT_DIR/test-reports}"
RUN_TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RUN_DIR="$REPORT_BASE_DIR/ruby-matrix-$RUN_TIMESTAMP"
LOG_DIR="$RUN_DIR/logs"
STATUS_TSV="$RUN_DIR/status.tsv"
DETAILS_MD="$RUN_DIR/details.md"
REPORT_MD="$RUN_DIR/report.md"

LOCK_FILE="/tmp/test_ruby_versions.lock"
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
  echo "ERROR: Another instance of test_ruby_versions.sh is already running." >&2
  exit 1
fi

if (($# > 0)); then
  RUBY_VERSIONS=("$@")
else
  RUBY_VERSIONS=("${DEFAULT_RUBY_VERSIONS[@]}")
fi

CURRENT_SERVER_PID=""
CURRENT_VERSION=""
RUN_INTERRUPTED=0
REPORT_GENERATED=0

mkdir -p "$LOG_DIR"
: >"$STATUS_TSV"
: >"$DETAILS_MD"

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

md_escape() {
  local text="$1"
  text=${text//$'\r'/}
  text=${text//$'\n'/<br>}
  text=${text//|/\\|}
  printf '%s' "$text"
}

format_duration() {
  local total="$1"
  printf '%dm %02ds' "$((total / 60))" "$((total % 60))"
}

stop_server_group() {
  local pid="${1:-}"
  local timeout_seconds="${2:-20}"
  local waited=0

  [[ -n "$pid" ]] || return 0

  if ! kill -0 -- "-$pid" 2>/dev/null && ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" 2>/dev/null || true
    return 0
  fi

  # bin/setup may start child processes. It is launched with setsid, so killing
  # the negative PID terminates the whole process group/session.
  kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null || true

  while { kill -0 -- "-$pid" 2>/dev/null || kill -0 "$pid" 2>/dev/null; } &&
        ((waited < timeout_seconds)); do
    sleep 1
    waited=$((waited + 1))
  done

  if kill -0 -- "-$pid" 2>/dev/null || kill -0 "$pid" 2>/dev/null; then
    kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null || true
  fi

  wait "$pid" 2>/dev/null || true
  ! kill -0 -- "-$pid" 2>/dev/null && ! kill -0 "$pid" 2>/dev/null
}

on_signal() {
  RUN_INTERRUPTED=1
  printf '\n' >&2
  log "Received stop signal; shutting down Rails for Ruby ${CURRENT_VERSION:-unknown}..." >&2
  stop_server_group "$CURRENT_SERVER_PID" "$STOP_TIMEOUT" || true
  CURRENT_SERVER_PID=""
}

validate_integer() {
  local name="$1" value="$2"
  if [[ ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: $name must be a positive integer, currently: $value" >&2
    exit 2
  fi
}

check_prerequisites() {
  local missing=0
  local command_name

  for command_name in mise curl timeout setsid date sed grep tail head mktemp; do
    if ! command_exists "$command_name"; then
      echo "ERROR: required command not found: $command_name" >&2
      missing=1
    fi
  done

  [[ -d "$PROJECT_DIR" ]] || {
    echo "ERROR: PROJECT_DIR does not exist: $PROJECT_DIR" >&2
    missing=1
  }
  [[ -f "$PROJECT_DIR/.env" ]] || {
    echo "ERROR: file not found: $PROJECT_DIR/.env" >&2
    missing=1
  }
  [[ -f "$PROJECT_DIR/Gemfile" ]] || {
    echo "ERROR: file not found: $PROJECT_DIR/Gemfile" >&2
    missing=1
  }
  [[ -f "$PROJECT_DIR/bin/setup" ]] || {
    echo "ERROR: file not found: $PROJECT_DIR/bin/setup" >&2
    missing=1
  }
  [[ -f "$PROJECT_DIR/scripts/test_all.sh" ]] || {
    echo "ERROR: file not found: $PROJECT_DIR/scripts/test_all.sh" >&2
    missing=1
  }

  ((missing == 0)) || exit 2
}

# Detect the ActiveRecord adapter declared in config/database.yml.
database_adapter() {
  grep -m1 -E '^\s*adapter:' "$PROJECT_DIR/config/database.yml" \
    | sed -E 's/^\s*adapter:[[:space:]]*([^#[:space:]]+).*/\1/'
}

# Reset the database so every Ruby version runs against a clean slate.
# SQLite: remove the database files; the next db:prepare recreates them.
# PostgreSQL: drop and re-prepare all databases, then seed the admin account.
# Requires that .env has already been sourced (production DATABASE_URLs).
reset_database() {
  local version="$1" setup_log="${2:-/dev/null}" adapter
  adapter=$(database_adapter)

  rm -f "$PROJECT_DIR"/Gemfile.lock

  if [[ "$adapter" == "sqlite3" ]]; then
    rm -f "$PROJECT_DIR"/storage/*.sqlite3
    return 0
  fi

  if [[ "$adapter" != "postgresql" ]]; then
    log "Ruby $version: adapter not supported: $adapter"
    return 1
  fi

  log "Ruby $version: reset PostgreSQL databases (bundle install + db:reset)"
  (
    cd "$PROJECT_DIR" || exit 1
    {
      printf '\n=== Ruby %s: Resetting database ===\n' "$version"
      mise exec "ruby@$version" -- bundle install &&
        mise exec "ruby@$version" -- env DISABLE_DATABASE_ENVIRONMENT_CHECK=1 \
          FORCE=true POSTGRES_STATEMENT_TIMEOUT=150s \
          bin/rails db:reset
    } >>"$setup_log" 2>&1
  )
}

generate_report() {
  local total=0 passed=0 failed=0
  local version overall ruby_info gem_info bundler_info rails_info cleanup_status env_status server_status test_status stop_status duration log_rel

  ((REPORT_GENERATED == 0)) || return 0
  REPORT_GENERATED=1

  while IFS=$'\t' read -r version overall ruby_info gem_info bundler_info rails_info cleanup_status env_status server_status test_status stop_status duration log_rel; do
    [[ -n "$version" ]] || continue
    total=$((total + 1))
    if [[ "$overall" == "PASS" ]]; then
      passed=$((passed + 1))
    else
      failed=$((failed + 1))
    fi
  done <"$STATUS_TSV"

  {
    echo "# Rails test report by Ruby version"
    echo
    echo "- **Started at:** $RUN_TIMESTAMP"
    echo "- **Project:** \`$(md_escape "$PROJECT_DIR")\`"
    echo "- **API base URL:** from \`.env\`, or default \`http://127.0.0.1:\${PORT:-4000}\`"
    echo "- **Requested Ruby:** \`${RUBY_VERSIONS[*]}\`"
    echo "- **Total:** $total"
    echo "- **PASS:** $passed"
    echo "- **FAIL:** $failed"
    if ((RUN_INTERRUPTED == 1)); then
      echo "- **Run status:** interrupted by signal"
    fi
    echo
    echo "## Summary"
    echo
    echo "| Ruby | Actual Ruby | Server | Test API | Stop | Result | Duration |"
    echo "|---|---|---|---|---|---|---:|"

    while IFS=$'\t' read -r version overall ruby_info gem_info bundler_info rails_info cleanup_status env_status server_status test_status stop_status duration log_rel; do
      [[ -n "$version" ]] || continue
      echo "| \`$(md_escape "$version")\` | \`$(md_escape "$ruby_info")\` | $(md_escape "$server_status") | $(md_escape "$test_status") | $(md_escape "$stop_status") | **$(md_escape "$overall")** | $(md_escape "$duration") |"
    done <"$STATUS_TSV"

    echo
    cat "$DETAILS_MD"
  } >"$REPORT_MD"
}

run_one_version() {
  local version="$1"
  local version_slug="${version//[^0-9A-Za-z._-]/_}"
  local version_log_dir="$LOG_DIR/ruby-$version_slug"
  local setup_log="$version_log_dir/setup-and-server.log"
  local test_log="$version_log_dir/test-all.log"
  local info_log="$version_log_dir/runtime-info.log"
  local start_epoch end_epoch elapsed duration
  local ruby_info="N/A" gem_info="N/A" bundler_info="N/A" rails_info="N/A"
  local cleanup_status="FAIL" env_status="FAIL" server_status="NOT RUN"
  local test_status="NOT RUN" stop_status="NOT RUN" overall="FAIL"
  local setup_exit_code="N/A" test_exit_code="N/A"
  local base_url readiness_url deadline
  local server_pid=""

  mkdir -p "$version_log_dir"
  : >"$setup_log"
  : >"$test_log"
  : >"$info_log"

  CURRENT_VERSION="$version"
  start_epoch=$(date +%s)

  log "============================================================"
  log "Ruby $version: starting"
  log "Logs: $version_log_dir"

  (
    cd "$PROJECT_DIR" || exit 1

    ruby_info=$(mise exec "ruby@$version" -- ruby -v 2>&1)
    ruby_rc=$?
    gem_info=$(mise exec "ruby@$version" -- gem -v 2>&1)
    gem_rc=$?
    bundler_info=$(mise exec "ruby@$version" -- bundle -v 2>&1)
    bundler_rc=$?

    {
      printf 'Requested Ruby: %s\n' "$version"
      printf 'ruby -v: %s\n' "$ruby_info"
      printf 'gem -v: %s\n' "$gem_info"
      printf 'bundle -v: %s\n' "$bundler_info"
    } >"$info_log"

    if ((ruby_rc != 0)); then
      printf 'ERROR: mise could not run ruby@%s.\n' "$version" >>"$info_log"
      exit 20
    fi
    if ((gem_rc != 0)); then
      printf 'ERROR: gem is not available with ruby@%s.\n' "$version" >>"$info_log"
      exit 21
    fi
    if ((bundler_rc != 0)); then
      printf 'ERROR: Bundler is not available with ruby@%s.\n' "$version" >>"$info_log"
      exit 22
    fi

    exit 0
  )
  local runtime_check_rc=$?

  if ((runtime_check_rc == 0)); then
    ruby_info=$(cd "$PROJECT_DIR" && mise exec "ruby@$version" -- ruby -v 2>&1 || true)
    gem_info=$(cd "$PROJECT_DIR" && mise exec "ruby@$version" -- gem -v 2>&1 || true)
    bundler_info=$(cd "$PROJECT_DIR" && mise exec "ruby@$version" -- bundle -v 2>&1 || true)
  else
    ruby_info=$(grep '^ruby -v:' "$info_log" 2>/dev/null | sed 's/^ruby -v: //' || true)
    gem_info=$(grep '^gem -v:' "$info_log" 2>/dev/null | sed 's/^gem -v: //' || true)
    bundler_info=$(grep '^bundle -v:' "$info_log" 2>/dev/null | sed 's/^bundle -v: //' || true)
    [[ -n "$ruby_info" ]] || ruby_info="mise exec failed (exit $runtime_check_rc)"
  fi

  if ((runtime_check_rc == 0)); then
    cd "$PROJECT_DIR" || return 1

    # 1. Export every variable loaded from .env, exactly as requested. This must
    # run before the database reset so PostgreSQL production URLs are available.
    set +u
    set -a
    # shellcheck disable=SC1091
    source .env
    local env_rc=$?
    set +a
    set -u

    if ((env_rc == 0)); then
      env_status="PASS"
    else
      env_status="FAIL (exit $env_rc)"
      log "Ruby $version: source .env failed (exit $env_rc)"
    fi

    # 2. Reset the database and remove the lock file so each Ruby version
    # starts from a clean database (PostgreSQL) or fresh SQLite files.
    if [[ "$env_status" == "PASS" ]] && reset_database "$version" "$setup_log"; then
      cleanup_status="PASS"
      log "Ruby $version: reset database and removed Gemfile.lock"
    else
      cleanup_status="FAIL"
      log "Ruby $version: cleanup failed"
    fi

    base_url="${API_BASE_URL:-http://127.0.0.1:${PORT:-4000}}"
    base_url="${base_url%/}"
    readiness_url="${RAILS_READINESS_URL:-$base_url/up}"

    if [[ "$cleanup_status" == "PASS" && "$env_status" == "PASS" ]]; then
      # 3. bin/setup starts the Rails server in the foreground in a standard
      # Rails app. setsid gives the run its own process group for reliable stop.
      log "Ruby $version: running RAILS_ENV=production bin/setup"
      # RACK_ATTACK_SAFELIST_LOCALHOST=true keeps Rack::Attack from throttling
      # the API test suites (5 sign-in/60s would otherwise 429 the admin suite).
      setsid mise exec "ruby@$version" -- env RAILS_ENV=production \
        RACK_ATTACK_SAFELIST_LOCALHOST=true bin/setup \
        >"$setup_log" 2>&1 < /dev/null &
      server_pid=$!
      CURRENT_SERVER_PID="$server_pid"

      deadline=$((SECONDS + SERVER_START_TIMEOUT))
      while ((SECONDS < deadline)); do
        if ((RUN_INTERRUPTED == 1)); then
          server_status="INTERRUPTED"
          break
        fi

        if curl --noproxy '*' -sS -o /dev/null \
          --connect-timeout 2 --max-time 4 "$readiness_url" 2>/dev/null; then
          server_status="READY"
          break
        fi

        if ! kill -0 "$server_pid" 2>/dev/null; then
          wait "$server_pid" 2>/dev/null
          setup_exit_code=$?
          server_status="EXITED (code $setup_exit_code)"
          break
        fi
        sleep 2
      done

      if [[ "$server_status" == "NOT RUN" ]]; then
        server_status="TIMEOUT (${SERVER_START_TIMEOUT}s)"
      fi

      if [[ "$server_status" == "READY" && "$RUN_INTERRUPTED" -eq 0 ]]; then
        rails_info=$(mise exec "ruby@$version" -- bundle exec rails --version 2>&1 || true)
        [[ -n "$rails_info" ]] || rails_info="N/A"
        printf 'rails: %s\n' "$rails_info" >>"$info_log"

        # 4. Run the uploaded test suite. API_BASE_URL is forced to the same URL
        # used by the readiness check, while all .env variables remain exported.
        log "Ruby $version: server ready at $readiness_url; running test_all.sh"
        API_BASE_URL="$base_url" timeout --signal=TERM --kill-after=15s \
          "$TEST_TIMEOUT" \
          mise exec "ruby@$version" -- bash ./scripts/test_all.sh \
          >"$test_log" 2>&1
        test_exit_code=$?

        case "$test_exit_code" in
          0)   test_status="PASS" ;;
          124) test_status="TIMEOUT (${TEST_TIMEOUT}s)" ;;
          *)   test_status="FAIL (exit $test_exit_code)" ;;
        esac
      else
        test_status="SKIPPED"
      fi
    else
      server_status="SKIPPED"
      test_status="SKIPPED"
    fi
  else
    cleanup_status="SKIPPED"
    env_status="SKIPPED"
    server_status="SKIPPED"
    test_status="SKIPPED"
  fi

  # 5. Always stop Rails after this Ruby version.
  if [[ -n "$server_pid" ]]; then
    if stop_server_group "$server_pid" "$STOP_TIMEOUT"; then
      stop_status="PASS"
    else
      stop_status="FAIL"
    fi
  else
    stop_status="NOT NEEDED"
  fi
  CURRENT_SERVER_PID=""

  if [[ "$cleanup_status" == "PASS" &&
        "$env_status" == "PASS" &&
        "$server_status" == "READY" &&
        "$test_status" == "PASS" &&
        "$stop_status" == "PASS" ]]; then
    overall="PASS"
  fi

  end_epoch=$(date +%s)
  elapsed=$((end_epoch - start_epoch))
  duration=$(format_duration "$elapsed")

  ruby_info=$(md_escape "$ruby_info")
  gem_info=$(md_escape "$gem_info")
  bundler_info=$(md_escape "$bundler_info")
  rails_info=$(md_escape "$rails_info")

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$version" "$overall" "$ruby_info" "$gem_info" "$bundler_info" "$rails_info" \
    "$cleanup_status" "$env_status" "$server_status" "$test_status" "$stop_status" \
    "$duration" "logs/ruby-$version_slug" >>"$STATUS_TSV"

  {
    echo "## Ruby $version — $overall"
    echo
    echo "| Item | Result |"
    echo "|---|---|"
    echo "| Requested Ruby | \`$(md_escape "$version")\` |"
    echo "| Actual Ruby | \`$ruby_info\` |"
    echo "| RubyGems | \`$gem_info\` |"
    echo "| Bundler | \`$bundler_info\` |"
    echo "| Rails | \`$rails_info\` |"
    echo "| Reset database/Gemfile.lock | $cleanup_status |"
    echo "| Load .env | $env_status |"
    echo "| Setup/server | $server_status |"
    echo "| Test API | $test_status |"
    echo "| Stop server | $stop_status |"
    echo "| Duration | $duration |"
    echo
    echo "- [Runtime info](logs/ruby-$version_slug/runtime-info.log)"
    echo "- [Setup and Rails server log](logs/ruby-$version_slug/setup-and-server.log)"
    echo "- [API test log](logs/ruby-$version_slug/test-all.log)"
    echo
  } >>"$DETAILS_MD"

  log "Ruby $version: $overall — server=$server_status, test=$test_status, stop=$stop_status, duration=$duration"

  [[ "$overall" == "PASS" ]]
}

finalize() {
  stop_server_group "$CURRENT_SERVER_PID" "$STOP_TIMEOUT" || true
  CURRENT_SERVER_PID=""
  generate_report
}

trap on_signal INT TERM
trap finalize EXIT

validate_integer SERVER_START_TIMEOUT "$SERVER_START_TIMEOUT"
validate_integer TEST_TIMEOUT "$TEST_TIMEOUT"
validate_integer STOP_TIMEOUT "$STOP_TIMEOUT"
check_prerequisites

log "Project: $PROJECT_DIR"
log "Ruby versions: ${RUBY_VERSIONS[*]}"
log "Report directory: $RUN_DIR"

TOTAL_FAILURES=0
for version in "${RUBY_VERSIONS[@]}"; do
  if ((RUN_INTERRUPTED == 1)); then
    break
  fi

  if ! run_one_version "$version"; then
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
  fi
done

generate_report

log "Done. Report: $REPORT_MD"

if ((RUN_INTERRUPTED == 1)); then
  exit 130
elif ((TOTAL_FAILURES > 0)); then
  exit 1
else
  exit 0
fi
