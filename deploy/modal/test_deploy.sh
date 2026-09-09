#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SCRIPT="${SCRIPT_DIR}/app.py"

[[ -f "$APP_SCRIPT" ]] || { printf 'FAIL missing %s\n' "$APP_SCRIPT" >&2; exit 1; }

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
    def __init__(self, name):
        records["app_name"] = name

    def function(self, **kwargs):
        records["function"] = kwargs
        return lambda fn: fn

def web_server(port, **kwargs):
    records["web_server"] = (port, kwargs)
    return lambda fn: fn

fake_modal = types.ModuleType("modal")
fake_modal.Image = FakeImage
fake_modal.Secret = FakeSecret
fake_modal.App = FakeApp
fake_modal.web_server = web_server
sys.modules["modal"] = fake_modal

spec = importlib.util.spec_from_file_location("modal_app_under_test", app_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

assert records["app_name"] == "rails-8-api-authentication"
assert records["dockerfile"][1]["add_python"] == "3.12"
assert pathlib.Path(records["dockerfile"][0]).name == "Dockerfile"
assert pathlib.Path(records["dockerfile"][1]["context_dir"]) == app_path.parents[2]
assert records["entrypoint"] == []

secret_name, secret_kwargs = records["secret"]
assert secret_name == "rails-api-production"
assert secret_kwargs["required_keys"] == [
    "RAILS_MASTER_KEY",
    "DATABASE_URL",
    "CACHE_DATABASE_URL",
    "QUEUE_DATABASE_URL",
    "CABLE_DATABASE_URL",
]
assert "DEVISE_JWT_SECRET_KEY" not in secret_kwargs["required_keys"]

function = records["function"]
expected = {
    "cpu": 1.0,
    "memory": 1024,
    "min_containers": 0,
    "max_containers": 1,
    "buffer_containers": 0,
    "scaledown_window": 60,
}
for key, value in expected.items():
    assert function[key] == value, (key, function[key], value)

assert function["env"] == {
    "RAILS_ENV": "production",
    "PORT": "4000",
    "RAILS_MAX_THREADS": "3",
    "RACK_ATTACK_CACHE_STORE": "memory",
}
assert "JWT_AUTH_HEADER" not in function["env"]
assert records["web_server"] == (
    4000,
    {"startup_timeout": 120, "requires_proxy_auth": False},
)

print("PASS Modal app contract")
PY
