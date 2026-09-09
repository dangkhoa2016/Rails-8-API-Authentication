#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="rails-8-api-authentication"
SECRET_NAME="rails-api-production"
MODAL_ENV=""
SMOKE_URL=""

info() { printf '[INFO] %s\n' "$*"; }
pass() { printf '[PASS] %s\n' "$*"; }
die() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: deploy/modal/deploy.sh [--env NAME] [--smoke URL]

Deploy the public Modal Rails demo from deploy/modal/app.py.

Options:
  --env NAME    Use a specific Modal environment.
  --smoke URL   Run deploy/modal/smoke.sh against URL after deploy.
  -h, --help    Show this help.

Modal authentication and the rails-api-production secret must already exist.
This script never accepts, creates, prints, or persists secret values.
USAGE
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 && -n "${2:-}" ]] || die '--env requires a value'
      MODAL_ENV="$2"
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
require_command modal

REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)" || die 'deploy script must run from a Git repository checkout'
[[ "$SCRIPT_DIR" == "$REPO_ROOT/deploy/modal" ]] || die 'expected script at deploy/modal/deploy.sh inside the repository'
[[ -f "$SCRIPT_DIR/app.py" ]] || die 'missing Modal deployment file: deploy/modal/app.py'

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all -- deploy/modal)" ]]; then
  die 'deploy/modal has uncommitted or untracked changes; commit or clean them before deployment'
fi

python3 -m py_compile "$SCRIPT_DIR/app.py"

if [[ -n "$SMOKE_URL" ]]; then
  [[ "$SMOKE_URL" =~ ^https?://[^[:space:]]+$ ]] || die '--smoke must be an http:// or https:// URL'
  while [[ "$SMOKE_URL" == */ ]]; do SMOKE_URL="${SMOKE_URL%/}"; done
  [[ -x "$SCRIPT_DIR/smoke.sh" ]] || die 'deploy/modal/smoke.sh is missing or not executable'
fi

env_args=()
if [[ -n "$MODAL_ENV" ]]; then
  env_args=(--env "$MODAL_ENV")
fi

secret_json="$(mktemp)"
trap 'rm -f "$secret_json"' EXIT
modal secret list --json "${env_args[@]}" > "$secret_json" || die 'cannot list Modal secrets; verify Modal authentication/environment'

python3 - "$secret_json" "$SECRET_NAME" <<'PY' || exit 1
import json
import sys

path, required = sys.argv[1:3]
try:
    payload = json.load(open(path, encoding="utf-8"))
except (OSError, json.JSONDecodeError) as exc:
    print(f"[FAIL] cannot parse 'modal secret list --json': {exc}", file=sys.stderr)
    raise SystemExit(1)

items = payload if isinstance(payload, list) else payload.get("secrets", []) if isinstance(payload, dict) else []
found = False
for item in items:
    if not isinstance(item, dict):
        continue
    name = item.get("name") or item.get("Name")
    if name == required:
        found = True
        break
if not found:
    print(f"[FAIL] missing required Modal secret: {required}", file=sys.stderr)
    raise SystemExit(1)
PY

SOURCE_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
SOURCE_BRANCH="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED')"
info "repository branch: $SOURCE_BRANCH"
info "repository commit: $SOURCE_SHA"
info "Modal app: $APP_NAME"
info "Modal environment: ${MODAL_ENV:-current/default}"
pass 'Modal preflight checks completed'

(
  cd "$REPO_ROOT"
  modal deploy deploy/modal/app.py --name "$APP_NAME" "${env_args[@]}"
)
pass 'Modal deploy command completed'

if [[ -n "$SMOKE_URL" ]]; then
  "$SCRIPT_DIR/smoke.sh" "$SMOKE_URL"
fi
