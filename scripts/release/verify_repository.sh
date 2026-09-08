#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

required=(
  CHANGELOG.md
  docs/RELEASE_PROCESS.md
  docs/RELEASE_PROCESS.vi.md
  deploy/beam/Dockerfile
  deploy/beam/app.py
  deploy/beam/entrypoint.sh
  deploy/beam/README.md
  deploy/beam/README.vi.md
  deploy/huggingface/Dockerfile
  deploy/huggingface/README.md
  deploy/huggingface/README.vi.md
  scripts/release/lib.sh
  scripts/release/test_release_tools.sh
  scripts/release/verify_ghcr.sh
  scripts/release/smoke_deployment.sh
)

for path in "${required[@]}"; do
  [[ -s "${path}" ]] || { echo "FAIL missing/empty ${path}" >&2; exit 1; }
done

grep -Eq '^  push:$' .github/workflows/ci.yml
grep -Eq '^    branches: \[main\]$|^      - main$' .github/workflows/ci.yml

grep -Fq '6897c773ec1321401e52c21c63870a72d01ca349' docs/RELEASE_PROCESS.md
grep -Fq '1d842b18c1d1b07c027cbb7d49c19a52d16f98bc' docs/RELEASE_PROCESS.md

if grep -REn 'T[B]D|T[O]DO|implement later|fill in details' \
  CHANGELOG.md docs/RELEASE_PROCESS.md docs/RELEASE_PROCESS.vi.md deploy; then
  echo 'FAIL unresolved release marker found' >&2
  exit 1
fi

if git ls-files deploy | grep -E '(^|/)(production\.key|master\.key)$|(^|/)credentials/.*\.key$'; then
  echo 'FAIL tracked private key path under deploy/' >&2
  exit 1
fi

if grep -REn '(postgres(ql)?://[^[:space:]]+:[^[:space:]@]+@|RAILS_MASTER_KEY=.+|SECRET_KEY_BASE=.{16,}|DEVISE_JWT_SECRET_KEY=.{16,})' deploy; then
  echo 'FAIL likely committed secret value under deploy/' >&2
  exit 1
fi

bash -n scripts/release/lib.sh
bash -n scripts/release/test_release_tools.sh
bash -n scripts/release/verify_ghcr.sh
bash -n scripts/release/smoke_deployment.sh
bash -n deploy/beam/entrypoint.sh
ruby -c deploy/beam/beam_logging.rb >/dev/null
python -m py_compile deploy/beam/app.py

echo 'PASS repository release contract'
