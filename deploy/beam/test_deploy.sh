#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"

pass=0
fail=0
ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

if [[ ! -x "${DEPLOY_SCRIPT}" ]]; then
  printf 'FAIL deploy script exists and is executable\n' >&2
  exit 1
fi

make_fixture() {
  local root="$1"
  mkdir -p "$root/deploy/beam" "$root/scripts/release" "$root/fakebin"
  cp "$DEPLOY_SCRIPT" "$root/deploy/beam/deploy.sh"
  chmod +x "$root/deploy/beam/deploy.sh"
  printf 'from beam import Pod\npod = object()\n' > "$root/deploy/beam/app.py"
  printf 'FROM scratch\n' > "$root/deploy/beam/Dockerfile"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$root/deploy/beam/entrypoint.sh"
  chmod +x "$root/deploy/beam/entrypoint.sh"
  printf '# frozen_string_literal: true\n' > "$root/deploy/beam/beam_logging.rb"
  cat > "$root/scripts/release/smoke_deployment.sh" <<'SMOKE'
#!/usr/bin/env bash
set -Eeuo pipefail
printf 'SMOKE API_BASE_URL=%s JWT_AUTH_HEADER=%s EMAIL=%s PASSWORD_SET=%s\n' \
  "${API_BASE_URL:-}" "${JWT_AUTH_HEADER:-}" "${SMOKE_EMAIL:-}" "$([[ -n "${SMOKE_PASSWORD:-}" ]] && printf yes || printf no)" >> "${FAKE_SMOKE_LOG}"
if [[ -n "${SMOKE_EMAIL:-}" && -n "${SMOKE_PASSWORD:-}" ]]; then
  printf '[PASS] deployment smoke health + authentication\n'
else
  printf '[NOT RUN] authentication smoke credentials not supplied\n'
fi
SMOKE
  chmod +x "$root/scripts/release/smoke_deployment.sh"
  cat > "$root/fakebin/beam" <<'BEAM'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "${FAKE_BEAM_LOG}"
if [[ "${1:-} ${2:-}" == "secret list" ]]; then
  cat "${FAKE_SECRET_LIST}"
  exit "${FAKE_SECRET_RC:-0}"
fi
if [[ "${1:-} ${2:-}" == "deploy app.py:pod" ]]; then
  printf '=> Deployed\n'
  exit 0
fi
printf 'unexpected fake beam invocation: %s\n' "$*" >&2
exit 64
BEAM
  chmod +x "$root/fakebin/beam"
  git -C "$root" init -q
  git -C "$root" config user.email test@example.invalid
  git -C "$root" config user.name Test
  git -C "$root" add .
  git -C "$root" commit -qm fixture
}

write_secrets() {
  local file="$1"
  shift || true
  {
    printf 'Name Last Updated Created\n'
    local item
    for item in \
      DATABASE_URL CACHE_DATABASE_URL QUEUE_DATABASE_URL CABLE_DATABASE_URL \
      SECRET_KEY_BASE DEVISE_JWT_SECRET_KEY CORS_ALLOWED_ORIGINS; do
      [[ " $* " == *" ${item} "* ]] && continue
      printf '%s now now\n' "$item"
    done
  } > "$file"
}

run_case() {
  local label="$1"
  local mode="$2"
  shift 2
  local root
  root="$(mktemp -d)"
  trap 'rm -rf "${root}"' RETURN
  make_fixture "$root"
  write_secrets "$root/secrets.txt" "$@"
  : > "$root/beam.log"
  : > "$root/smoke.log"
  if [[ "$mode" == dirty ]]; then
    printf '# local change\n' >> "$root/deploy/beam/app.py"
  fi
  local output rc=0
  set +e
  output="$(
    cd "$root"
    PATH="$root/fakebin:$PATH" \
    FAKE_BEAM_LOG="$root/beam.log" \
    FAKE_SECRET_LIST="$root/secrets.txt" \
    FAKE_SMOKE_LOG="$root/smoke.log" \
      "$root/deploy/beam/deploy.sh" ${CASE_ARGS:-} 2>&1
  )" || rc=$?
  set -e

  case "$mode" in
    success)
      if [[ $rc -eq 0 ]] && grep -Fq 'deploy app.py:pod' "$root/beam.log"; then ok "$label"; else printf '%s\n' "$output" >&2; bad "$label"; fi
      ;;
    failure)
      if [[ $rc -ne 0 ]] && [[ "$output" == *"${EXPECTED_TEXT}"* ]] && ! grep -Fq 'deploy app.py:pod' "$root/beam.log"; then ok "$label"; else printf '%s\n' "$output" >&2; bad "$label"; fi
      ;;
    context)
      if [[ $rc -eq 0 ]] && grep -Fq 'secret list --context staging' "$root/beam.log" && grep -Fq 'deploy app.py:pod --context staging' "$root/beam.log"; then ok "$label"; else cat "$root/beam.log" >&2; printf '%s\n' "$output" >&2; bad "$label"; fi
      ;;
    smoke)
      if [[ $rc -eq 0 ]] && grep -Fq 'API_BASE_URL=https://beam.example JWT_AUTH_HEADER=X-Authorization' "$root/smoke.log"; then ok "$label"; else cat "$root/smoke.log" >&2; printf '%s\n' "$output" >&2; bad "$label"; fi
      ;;
    dirty)
      if [[ $rc -ne 0 ]] && [[ "$output" == *"deploy/beam has uncommitted or untracked changes"* ]] && ! grep -Fq 'deploy app.py:pod' "$root/beam.log"; then ok "$label"; else printf '%s\n' "$output" >&2; bad "$label"; fi
      ;;
  esac
}

CASE_ARGS=''
run_case 'deploys app.py:pod when preflight passes' success

EXPECTED_TEXT='missing required Beam secret: CABLE_DATABASE_URL'
CASE_ARGS=''
run_case 'fails before deploy when a required secret is missing' failure CABLE_DATABASE_URL

CASE_ARGS='--context staging'
run_case 'passes an explicit Beam context to secret check and deploy' context

CASE_ARGS='--smoke https://beam.example/'
run_case 'passes Beam URL and X-Authorization to smoke verifier' smoke

CASE_ARGS=''
run_case 'rejects a dirty deploy/beam tree before contacting Beam' dirty

printf '\nBeam deploy tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
