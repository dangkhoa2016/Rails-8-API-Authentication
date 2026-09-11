#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SCRIPT="$SCRIPT_DIR/app.py"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"
DOCKERFILE="$SCRIPT_DIR/../../Dockerfile"

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
fake.is_local = lambda: True
sys.modules["modal"] = fake

spec = importlib.util.spec_from_file_location("modal_app_under_test", app_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert records["app_name"] == "rails-8-api-authentication"
assert records["dockerfile"][1]["add_python"] == "3.12"
expected_repo = app_path.parents[2]
assert pathlib.Path(records["dockerfile"][0]) == expected_repo / "Dockerfile"
assert pathlib.Path(records["dockerfile"][1]["context_dir"]) == expected_repo
assert records["entrypoint"] == []
name, secret = records["secret"]
assert name == "rails-api-production"
assert secret["required_keys"] == [
    "RAILS_MASTER_KEY", "DATABASE_URL", "CACHE_DATABASE_URL",
    "QUEUE_DATABASE_URL", "CABLE_DATABASE_URL", "CORS_ALLOWED_ORIGINS",
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
    "SOLID_QUEUE_IN_PUMA": "true", "JOB_CONCURRENCY": "1",
}
assert "MODAL_DEPLOYMENT" not in fn["env"]
assert "JWT_AUTH_HEADER" not in fn["env"]
assert records["web_server"] == (4000, {"startup_timeout": 120, "requires_proxy_auth": False})
PY
ok 'app.py contract uses Rails production environment credentials'

python3 - "$APP_SCRIPT" <<'PY'
import importlib.util
import pathlib
import sys
import types

app_path = pathlib.Path(sys.argv[1])
records = {"dockerfile_calls": [], "debian_slim_calls": 0}


class FakeImage:
    @classmethod
    def from_dockerfile(cls, path, **kwargs):
        records["dockerfile_calls"].append((str(path), kwargs))
        return cls()

    @classmethod
    def debian_slim(cls):
        records["debian_slim_calls"] += 1
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
    def __init__(self, name):
        records["app_name"] = name

    def function(self, **kwargs):
        records["function"] = kwargs
        return lambda fn: fn


def web_server(port, **kwargs):
    records["web_server"] = (port, kwargs)
    return lambda fn: fn


class RemotePathForbidden:
    def __init__(self, *_args, **_kwargs):
        raise AssertionError("remote import must not derive client-local REPO_ROOT")


fake_modal = types.ModuleType("modal")
fake_modal.Image = FakeImage
fake_modal.Secret = FakeSecret
fake_modal.App = FakeApp
fake_modal.web_server = web_server
fake_modal.is_local = lambda: False
fake_pathlib = types.ModuleType("pathlib")
fake_pathlib.Path = RemotePathForbidden

saved_modal = sys.modules.get("modal")
saved_pathlib = sys.modules.get("pathlib")
try:
    sys.modules["modal"] = fake_modal
    sys.modules["pathlib"] = fake_pathlib
    spec = importlib.util.spec_from_file_location("modal_app_remote_context", app_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
finally:
    if saved_modal is None:
        sys.modules.pop("modal", None)
    else:
        sys.modules["modal"] = saved_modal
    if saved_pathlib is None:
        sys.modules.pop("pathlib", None)
    else:
        sys.modules["pathlib"] = saved_pathlib

assert records["dockerfile_calls"] == []
assert records["debian_slim_calls"] == 1
assert records["app_name"] == "rails-8-api-authentication"
assert "function" in records
assert records["web_server"] == (4000, {"startup_timeout": 120, "requires_proxy_auth": False})
PY
ok 'app.py remote import bypasses client-local image recipe'

python3 - "$DOCKERFILE" <<'PY'
from pathlib import Path
import re
import shlex
import sys

dockerfile = Path(sys.argv[1])
text = dockerfile.read_text(encoding="utf-8")

# Collapse Dockerfile shell line continuations so the RUN block can be
# inspected independently of formatting.
logical = re.sub(r"\\\s*\n\s*", " ", text)

match = re.search(
    r"RUN\s+groupadd\b(?P<body>.*?chown\s+-R\s+rails:rails\s+db\s+log\s+storage\s+tmp)",
    logical,
    flags=re.S,
)
assert match, "runtime ownership RUN block not found"

body = match.group("body")
chown_marker = "chown -R rails:rails db log storage tmp"
prefix = body.split(chown_marker, 1)[0]

created = set()
for mkdir in re.finditer(r"\bmkdir\s+-p\s+([^&;]+)", prefix):
    created.update(shlex.split(mkdir.group(1).strip()))

missing = {"log", "storage"} - created
assert not missing, (
    "Dockerfile must create runtime directories before chown; missing: "
    + ", ".join(sorted(missing))
)
PY
ok 'Dockerfile creates log/storage before runtime chown'

make_fixture() {
  local root="$1"
  mkdir -p "$root/deploy/modal" "$root/fakebin" "$root/config/credentials"
  cp "$APP_SCRIPT" "$root/deploy/modal/app.py"
  cp "$DEPLOY_SCRIPT" "$root/deploy/modal/deploy.sh"
  printf 'encrypted-production-fixture\n' > "$root/config/credentials/production.yml.enc"
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
  git -C "$root" add deploy fakebin config/credentials/production.yml.enc
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
    missing_secret) printf '[{"name":"other"}]\n' > "$secrets" ;;
    missing_credentials)
      git -C "$root" rm -q config/credentials/production.yml.enc
      git -C "$root" commit -qm 'remove credentials fixture'
      printf '[{"name":"rails-api-production"}]\n' > "$secrets"
      ;;
    tracked_key)
      printf 'do-not-commit\n' > "$root/config/credentials/production.key"
      git -C "$root" add config/credentials/production.key
      git -C "$root" commit -qm 'track forbidden key fixture'
      printf '[{"name":"rails-api-production"}]\n' > "$secrets"
      ;;
  esac

  local rc=0
  set +e
  PATH="$root/fakebin:$PATH" FAKE_MODAL_LOG="$log" FAKE_SECRET_JSON="$secrets" \
    "$root/deploy/modal/deploy.sh" > "$output" 2>&1
  rc=$?
  set -e

  case "$mode" in
    success)
      [[ $rc -eq 0 ]] && grep -Fq 'secret list --json' "$log" && \
        grep -Fq 'deploy deploy/modal/app.py --name rails-8-api-authentication' "$log"
      ;;
    missing_secret)
      [[ $rc -ne 0 ]] && grep -Fq 'missing required Modal secret: rails-api-production' "$output" && \
        ! grep -q '^deploy ' "$log"
      ;;
    missing_credentials)
      [[ $rc -ne 0 ]] && grep -Fq 'missing/empty production credentials: config/credentials/production.yml.enc' "$output" && \
        ! grep -q '^deploy ' "$log"
      ;;
    tracked_key)
      [[ $rc -ne 0 ]] && grep -Fq 'production credentials key must never be committed: config/credentials/production.key' "$output" && \
        ! grep -q '^deploy ' "$log"
      ;;
  esac

  rm -rf "$root" "$secrets" "$log" "$output"
}

if run_deploy_case success; then ok 'deploys when production credentials and named secret exist'; else bad 'deploys when production credentials and named secret exist'; fi
if run_deploy_case missing_secret; then ok 'fails before deploy when named secret is absent'; else bad 'fails before deploy when named secret is absent'; fi
if run_deploy_case missing_credentials; then ok 'fails before deploy when production credentials are absent'; else bad 'fails before deploy when production credentials are absent'; fi
if run_deploy_case tracked_key; then ok 'fails before deploy when production.key is tracked'; else bad 'fails before deploy when production.key is tracked'; fi

if "$DEPLOY_SCRIPT" --unknown >/dev/null 2>&1; then
  bad 'rejects unknown CLI arguments'
else
  ok 'rejects unknown CLI arguments'
fi

printf '\nModal deploy tests: %s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
