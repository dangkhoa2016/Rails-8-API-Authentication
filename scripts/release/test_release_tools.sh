#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

pass=0
fail=0

ok() { printf 'PASS %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=$((fail + 1)); }

expect_success() {
  local label="$1"
  shift
  if "$@"; then ok "$label"; else bad "$label"; fi
}

expect_failure() {
  local label="$1"
  shift
  if "$@"; then bad "$label"; else ok "$label"; fi
}

REV="6897c773ec1321401e52c21c63870a72d01ca349"

MULTIARCH_OK="$(cat <<JSON
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "annotations": {"org.opencontainers.image.revision": "${REV}"},
  "manifests": [
    {"digest":"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","platform":{"os":"linux","architecture":"amd64"}},
    {"digest":"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","platform":{"os":"linux","architecture":"arm64"}}
  ]
}
JSON
)"

MULTIARCH_MISSING_ARM="$(jq ' .manifests |= map(select(.platform.architecture != "arm64")) ' <<<"${MULTIARCH_OK}")"
MULTIARCH_WRONG_REV="$(jq '.annotations["org.opencontainers.image.revision"] = "deadbeef"' <<<"${MULTIARCH_OK}")"
MULTIARCH_DUP_AMD64="$(jq '.manifests += [.manifests[0]]' <<<"${MULTIARCH_OK}")"

AMD64_OK="$(cat <<JSON
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "annotations": {"org.opencontainers.image.revision": "${REV}"},
  "manifests": [
    {"digest":"sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","platform":{"os":"linux","architecture":"amd64"}}
  ]
}
JSON
)"

expect_success "multiarch index accepts amd64+arm64" assert_multiarch_index_json "${MULTIARCH_OK}" "${REV}"
expect_failure "multiarch index rejects missing arm64" assert_multiarch_index_json "${MULTIARCH_MISSING_ARM}" "${REV}"
expect_failure "multiarch index rejects revision mismatch" assert_multiarch_index_json "${MULTIARCH_WRONG_REV}" "${REV}"
expect_failure "multiarch index rejects duplicate amd64" assert_multiarch_index_json "${MULTIARCH_DUP_AMD64}" "${REV}"
expect_success "single-platform alias accepts linux/amd64" assert_single_platform_index_json "${AMD64_OK}" linux amd64 "${REV}"
expect_failure "single-platform alias rejects wrong requested arch" assert_single_platform_index_json "${AMD64_OK}" linux arm64 "${REV}"

[[ "$(normalize_base_url 'https://example.test/')" == "https://example.test" ]] && ok "base URL strips trailing slash" || bad "base URL strips trailing slash"

CI_FILE="${SCRIPT_DIR}/../../.github/workflows/ci.yml"
if grep -Eq '^  push:$' "${CI_FILE}" &&
   grep -Eq '^    branches: \[main\]$|^      - main$' "${CI_FILE}"; then
  ok "CI runs on push to main"
else
  bad "CI runs on push to main"
fi

SMOKE_SCRIPT="${SCRIPT_DIR}/smoke_deployment.sh"
if [[ -x "${SMOKE_SCRIPT}" ]]; then
  if API_BASE_URL=https://example.test SMOKE_EMAIL=user@example.test "${SMOKE_SCRIPT}" --validate-only >/dev/null 2>&1; then
    bad "smoke verifier rejects incomplete credentials"
  else
    ok "smoke verifier rejects incomplete credentials"
  fi
fi

printf '\nRelease helper tests: %s passed, %s failed\n' "${pass}" "${fail}"
[[ "${fail}" -eq 0 ]]
