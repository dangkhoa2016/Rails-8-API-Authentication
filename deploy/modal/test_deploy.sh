#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SCRIPT="$SCRIPT_DIR/app.py"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"

pass=0
fail=0
ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

python3 - "$APP_SCRIPT" <<'PY'
import importlib.util
import pathlib
import sys
import types

app_path = pathlib.Path(sys.argv[1])
records = {}

class FakeImage:
    @classmethod
    def from_dockerfile(cls, path, **kwargs):
        records["dockerfile"] = (str(path), kwargs)
        return cls()
    def entrypoint(self, commands):
        records["entrypoint"] = commands
        return self

class FakeSecret:
    @classmethod
    def from_name(cls, name, **kwargs):
        records["secret"] = (name, kwargs)
        return ("secret", name)

class FakeApp:
    def __init__(self, name): records["app_name"] = name
    def function(self, **kwargs):
        records["function"] = kwargs
        return lambda fn: fn

def web_server(port, **kwargs):
    records["web_server"] = (port, kwargs)
    return lambda fn: fn

fake = types.ModuleType("modal")
fake.Image = FakeImage
fake.Secret = FakeSecret
fake.App = FakeApp
fake.web_server = web_server
sys.modules["modal"] = fake

spec = importlib.util.spec_from_file_location("modal_app_under_test", app_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert records["app_name"] == "rails-8-api-authentication"
assert records["dockerfile"][1]["add_python"] == "3.12"
assert records["entrypoint"] == []
name, secret = records["secret"]
assert name == "rails-api-production"
assert secret["required_keys"] == [
    "RAILS_MASTER_KEY", "DATABASE_URL", "CACHE_DATABASE_URL",
    "QUEUE_DATABASE_URL", "CABLE_DATABASE_URL",
]
assert "DEVISE_JWT_SECRET_KEY" not in secret["required_keys"]
fn = records["function"]
assert fn["cpu"] == 1.0
assert fn["memory"] == 1024
assert fn["min_containers"] == 0
assert fn["max_containers"] == 1
assert fn["buffer_containers"] == 0
assert fn["scaledown_window"] == 60
assert fn["env"] == {
    "RAILS_ENV": "production", "PORT": "4000",
    "RAILS_MAX_THREADS": "3", "RACK_ATTACK_CACHE_STORE": "memory",
}
assert "JWT_AUTH_HEADER" not in fn["env"]
assert records["web_server"] == (4000, {"startup_timeout": 120, "requires_proxy_auth": False})
PY
ok 'app.py contract matches public bounded Modal profile'

make_fixture() {
  local root="$1"
  mkdir -p "$root/deploy/modal" "$root/fakebin"
  cp "$APP_SCRIPT" "$root/deploy/modal/app.py"
  cp "$DEPLOY_SCRIPT" "$root/deploy/modal/deploy.sh"
  chmod +x "$root/deploy/modal/deploy.sh"
  cat > "$root/fakebin/modal" <<'MODAL'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$FAKE_MODAL_LOG"
if [[ "$1 $2" == "secret list" ]]; then
  cat "$FAKE_SECRET_JSON"
  exit 0
fi
if [[ "$1" == "deploy" ]]; then
  printf 'Deployed\n'
  exit 0
fi
exit 64
MODAL
  chmod +x "$root/fakebin/modal"
  git -C "$root" init -q
  git -C "$root" config user.email test@example.invalid
  git -C "$root" config user.name Test
  git -C "$root" add deploy fakebin
  git -C "$root" commit -qm fixture
}

run_deploy_case() {
  local mode="$1"
  local root secrets log output
  root="$(mktemp -d)"
  secrets="$(mktemp)"
  log="$(mktemp)"
  output="$(mktemp)"
  make_fixture "$root"
  case "$mode" in
    success) printf '[{"name":"rails-api-production"}]\n' > "$secrets" ;;
    missing) printf '[{"name":"other"}]\n' > "$secrets" ;;
  esac
  local rc=0
  set +e
  PATH="$root/fakebin:$PATH" FAKE_MODAL_LOG="$log" FAKE_SECRET_JSON="$secrets" \
    "$root/deploy/modal/deploy.sh" > "$output" 2>&1
  rc=$?
  set -e
  if [[ "$mode" == success ]]; then
    [[ $rc -eq 0 ]] && grep -Fq 'secret list --json' "$log" && \
      grep -Fq 'deploy deploy/modal/app.py --name rails-8-api-authentication' "$log"
  else
    [[ $rc -ne 0 ]] && grep -Fq 'missing required Modal secret: rails-api-production' "$output" && \
      ! grep -q '^deploy ' "$log"
  fi
  rm -rf "$root" "$secrets" "$log" "$output"
}

if run_deploy_case success; then ok 'deploys when named secret exists'; else bad 'deploys when named secret exists'; fi
if run_deploy_case missing; then ok 'fails before deploy when named secret is absent'; else bad 'fails before deploy when named secret is absent'; fi

if "$DEPLOY_SCRIPT" --unknown >/dev/null 2>&1; then
  bad 'rejects unknown CLI arguments'
else
  ok 'rejects unknown CLI arguments'
fi

printf '\nModal deploy tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
