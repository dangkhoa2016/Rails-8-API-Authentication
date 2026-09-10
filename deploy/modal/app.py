from pathlib import Path
import os
import subprocess

import modal

APP_NAME = "rails-8-api-authentication"
SECRET_NAME = "rails-api-production"
PORT = 4000

if modal.is_local():
    REPO_ROOT = Path(__file__).resolve().parents[2]
    image = (
        modal.Image.from_dockerfile(
            REPO_ROOT / "Dockerfile",
            context_dir=REPO_ROOT,
            add_python="3.12",
        )
        .entrypoint([])
    )
else:
    image = modal.Image.debian_slim()

runtime_secret = modal.Secret.from_name(
    SECRET_NAME,
    required_keys=[
        "RAILS_MASTER_KEY",
        "DATABASE_URL",
        "CACHE_DATABASE_URL",
        "QUEUE_DATABASE_URL",
        "CABLE_DATABASE_URL",
        "CORS_ALLOWED_ORIGINS",
    ],
)

app = modal.App(APP_NAME)


@app.function(
    image=image,
    secrets=[runtime_secret],
    cpu=1.0,
    memory=1024,
    min_containers=0,
    max_containers=1,
    buffer_containers=0,
    scaledown_window=60,
    env={
        "RAILS_ENV": "production",
        "PORT": str(PORT),
        "RAILS_MAX_THREADS": "3",
        "RACK_ATTACK_CACHE_STORE": "memory",
    },
)
@modal.web_server(PORT, startup_timeout=120, requires_proxy_auth=False)
def rails_api():
    env = os.environ.copy()
    subprocess.run(["/rails/bin/rails", "db:prepare"], cwd="/rails", env=env, check=True)
    subprocess.run(["/rails/bin/rails", "db:seed"], cwd="/rails", env=env, check=True)
    subprocess.Popen(
        ["/rails/bin/rails", "server", "-b", "0.0.0.0", "-p", str(PORT)],
        cwd="/rails",
        env=env,
    )
