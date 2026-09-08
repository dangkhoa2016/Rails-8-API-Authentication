#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
not_run() { printf '[NOT RUN] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: deploy/beam/deploy.sh [--context NAME] [--smoke URL]

Deploy the Beam.cloud PostgreSQL recipe from deploy/beam/app.py:pod.

Options:
  --context NAME  Use a specific Beam CLI context.
  --smoke URL     After deploy, run the release smoke verifier against URL.
  -h, --help      Show this help.

Environment:
  BEAM_CONTEXT    Default Beam context when --context is not supplied.
  SMOKE_EMAIL     Optional smoke-test account email. Must be paired with SMOKE_PASSWORD.
  SMOKE_PASSWORD  Optional smoke-test account password. Must be paired with SMOKE_EMAIL.

Beam credentials and runtime secrets must already be configured in Beam.
This script never accepts, creates, prints, or persists secret values.
USAGE
}

require_command() {
  local command_name="$1"
  local hint="${2:-}"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    [[ -n "$hint" ]] && die "$command_name is required ($hint)"
    die "$command_name is required"
  fi
}

BEAM_CONTEXT="${BEAM_CONTEXT:-}"
SMOKE_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --context)
      [[ $# -ge 2 && -n "${2:-}" ]] || die '--context requires a value'
      BEAM_CONTEXT="$2"
      shift 2
      ;;
    --smoke)
      [[ $# -ge 2 && -n "${2:-}" ]] || die '--smoke requires a URL'
      SMOKE_URL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
done

require_command git
require_command python3
require_command beam 'install with: uv tool install beam-client'

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || die 'deploy script must run from a Git repository checkout'
[[ "$SCRIPT_DIR" == "$REPO_ROOT/deploy/beam" ]] || die 'expected script at deploy/beam/deploy.sh inside the repository'

for required_file in app.py Dockerfile entrypoint.sh beam_logging.rb; do
  [[ -f "$SCRIPT_DIR/$required_file" ]] || die "missing Beam deployment file: deploy/beam/$required_file"
done

[[ -x "$SCRIPT_DIR/entrypoint.sh" ]] || die 'deploy/beam/entrypoint.sh must be executable'

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all -- deploy/beam)" ]]; then
  die 'deploy/beam has uncommitted or untracked changes; commit or clean them before release deployment'
fi

python3 - "$SCRIPT_DIR/app.py" <<'PY'
import ast
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
PY
bash -n "$SCRIPT_DIR/entrypoint.sh"

SOURCE_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')"
RAILS_IMAGE="$(sed -n 's/^ARG RAILS_IMAGE=//p' "$SCRIPT_DIR/Dockerfile" | head -n 1)"
[[ -n "$RAILS_IMAGE" ]] || RAILS_IMAGE='(not declared as ARG RAILS_IMAGE)'

context_args=()
if [[ -n "$BEAM_CONTEXT" ]]; then
  context_args=(--context "$BEAM_CONTEXT")
fi

secret_output="$(mktemp)"
trap 'rm -f "$secret_output"' EXIT

if ! (cd "$SCRIPT_DIR" && beam secret list "${context_args[@]}" >"$secret_output" 2>/dev/null); then
  if [[ -n "$BEAM_CONTEXT" ]]; then
    die "cannot list Beam secrets with context '$BEAM_CONTEXT'; verify 'beam config list' and authentication"
  fi
  die "cannot list Beam secrets; configure Beam credentials with 'beam config create <name>' and select a context"
fi

secret_names="$(sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g' "$secret_output" | awk 'NF {print $1}')"
required_secrets=(
  DATABASE_URL
  CACHE_DATABASE_URL
  QUEUE_DATABASE_URL
  CABLE_DATABASE_URL
  SECRET_KEY_BASE
  DEVISE_JWT_SECRET_KEY
  CORS_ALLOWED_ORIGINS
)

for secret_name in "${required_secrets[@]}"; do
  if ! grep -Fxq "$secret_name" <<<"$secret_names"; then
    die "missing required Beam secret: $secret_name"
  fi
done

if [[ -n "${SMOKE_EMAIL:-}" || -n "${SMOKE_PASSWORD:-}" ]]; then
  [[ -n "${SMOKE_EMAIL:-}" && -n "${SMOKE_PASSWORD:-}" ]] || die 'SMOKE_EMAIL and SMOKE_PASSWORD must be supplied together'
fi

if [[ -n "$SMOKE_URL" ]]; then
  [[ "$SMOKE_URL" =~ ^https?://[^[:space:]]+$ ]] || die '--smoke must be an http:// or https:// URL'
  while [[ "$SMOKE_URL" == */ ]]; do SMOKE_URL="${SMOKE_URL%/}"; done
  require_command curl
  require_command jq
  [[ -x "$REPO_ROOT/scripts/release/smoke_deployment.sh" ]] || die 'scripts/release/smoke_deployment.sh is missing or not executable'
fi

info "repository branch: $SOURCE_BRANCH"
info "repository commit: $SOURCE_SHA"
info "Rails source image: $RAILS_IMAGE"
if [[ -n "$BEAM_CONTEXT" ]]; then
  info "Beam context: $BEAM_CONTEXT"
else
  info 'Beam context: current default'
fi
pass 'Beam preflight checks completed'

(
  cd "$SCRIPT_DIR"
  beam deploy app.py:pod "${context_args[@]}"
)
pass 'Beam deploy command completed for app.py:pod'

if [[ -z "$SMOKE_URL" ]]; then
  not_run 'deployment smoke: --smoke URL not supplied'
  exit 0
fi

API_BASE_URL="$SMOKE_URL" \
JWT_AUTH_HEADER='X-Authorization' \
SMOKE_EMAIL="${SMOKE_EMAIL:-}" \
SMOKE_PASSWORD="${SMOKE_PASSWORD:-}" \
  "$REPO_ROOT/scripts/release/smoke_deployment.sh"

if [[ -n "${SMOKE_EMAIL:-}" ]]; then
  pass 'Beam deployment smoke completed with health + authentication'
else
  not_run 'authentication smoke: SMOKE_EMAIL/SMOKE_PASSWORD not supplied'
fi
