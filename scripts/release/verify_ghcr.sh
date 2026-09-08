#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

require_command git
require_command docker
require_command jq

REPO_URL="https://github.com/dangkhoa2016/Rails-8-API-Authentication.git"
IMAGE="ghcr.io/dangkhoa2016/rails-8-api-authentication"

verify_remote_branch() {
  local branch="$1" expected_sha="$2"
  local actual
  actual="$(git ls-remote "${REPO_URL}" "refs/heads/${branch}" | awk '{print $1}')"
  [[ "${actual}" == "${expected_sha}" ]] || die "${branch} expected ${expected_sha}, got ${actual:-missing}"
  status_line PASS "branch ${branch}" "${actual}"
}

inspect_raw() {
  local ref="$1" attempt output
  for attempt in 1 2 3 4 5; do
    if output="$(docker buildx imagetools inspect "${ref}" --raw 2>/dev/null)"; then
      printf '%s' "${output}"
      return 0
    fi
    sleep 2
  done
  return 1
}

verify_multiarch_tag() {
  local tag="$1" revision="$2" json
  json="$(inspect_raw "${IMAGE}:${tag}")" || die "cannot inspect ${IMAGE}:${tag}"
  assert_multiarch_index_json "${json}" "${revision}" || die "invalid multiarch contract for ${tag}"
  status_line PASS "GHCR ${tag}" "linux/amd64 + linux/arm64 @ ${revision}"
}

verify_arch_alias() {
  local tag="$1" arch="$2" revision="$3" json
  json="$(inspect_raw "${IMAGE}:${tag}")" || die "cannot inspect ${IMAGE}:${tag}"
  assert_single_platform_index_json "${json}" linux "${arch}" "${revision}" || die "invalid ${arch} alias contract for ${tag}"
  status_line PASS "GHCR ${tag}" "linux/${arch} @ ${revision}"
}

verify_variant() {
  local variant="$1" branch="$2" revision="$3"
  local short_sha="${revision:0:7}"
  verify_remote_branch "${branch}" "${revision}"
  verify_multiarch_tag "${variant}" "${revision}"
  verify_multiarch_tag "${variant}-v1" "${revision}"
  verify_multiarch_tag "${variant}-${short_sha}" "${revision}"
  verify_arch_alias "${variant}-amd64" amd64 "${revision}"
  verify_arch_alias "${variant}-arm64" arm64 "${revision}"
}

verify_variant postgresql baseline/postgresql-v1 6897c773ec1321401e52c21c63870a72d01ca349
verify_variant sqlite baseline/sqlite-v1 1d842b18c1d1b07c027cbb7d49c19a52d16f98bc

status_line PASS "GHCR release contract" "all required tags verified"
