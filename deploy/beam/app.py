from beam import Image, Pod

image = Image.from_dockerfile("./Dockerfile")

pod = Pod(
    name="rails-8-api-authentication-postgresql",
    image=image,
    cpu=1,
    memory="1Gi",
    ports=[8080],
    entrypoint=["/bin/bash", "/usr/local/bin/beam-entrypoint"],
    env={
        "RAILS_ENV": "production",
        "RAILS_LOG_TO_STDOUT": "true",
        "RAILS_LOG_LEVEL": "info",
        "BEAM_RAILS_LOG_PROBE": "true",
        "JWT_AUTH_HEADER": "X-Authorization",
        "WEB_PORT": "8080",
        "RAILS_MAX_THREADS": "3",
        "SOLID_QUEUE_IN_PUMA": "true",
        "JOB_CONCURRENCY": "1",
        "RUN_DB_PREPARE": "true",
        "DB_PREPARE_MAX_ATTEMPTS": "3",
        "DB_PREPARE_RETRY_DELAY": "2",
    },
    secrets=[
        "DATABASE_URL",
        "CACHE_DATABASE_URL",
        "QUEUE_DATABASE_URL",
        "CABLE_DATABASE_URL",
        "SECRET_KEY_BASE",
        "DEVISE_JWT_SECRET_KEY",
        "CORS_ALLOWED_ORIGINS",
    ],
    keep_warm_seconds=300,
)
