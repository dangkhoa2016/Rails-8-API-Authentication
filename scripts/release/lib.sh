#!/usr/bin/env bash

release_timestamp() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }

status_line() {
  local state="$1" label="$2" detail="${3:-}"
  printf '[release] %-7s %-28s %s\n' "${state}" "${label}" "${detail}"
}

die() {
  status_line FAIL "fatal" "$*" >&2
  return 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

normalize_base_url() {
  local url="$1"
  printf '%s' "${url%/}"
}

assert_revision_annotation() {
  local json="$1" expected_revision="$2"
  jq -e --arg rev "${expected_revision}" '
    .annotations["org.opencontainers.image.revision"] == $rev
  ' <<<"${json}" >/dev/null
}

assert_multiarch_index_json() {
  local json="$1" expected_revision="$2"
  assert_revision_annotation "${json}" "${expected_revision}" || return 1
  jq -e '
    [ .manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64") ] | length == 1
  ' <<<"${json}" >/dev/null || return 1
  jq -e '
    [ .manifests[] | select(.platform.os == "linux" and .platform.architecture == "arm64") ] | length == 1
  ' <<<"${json}" >/dev/null
}

assert_single_platform_index_json() {
  local json="$1" expected_os="$2" expected_arch="$3" expected_revision="$4"
  assert_revision_annotation "${json}" "${expected_revision}" || return 1
  jq -e --arg os "${expected_os}" --arg arch "${expected_arch}" '
    (.manifests | length) == 1 and
    .manifests[0].platform.os == $os and
    .manifests[0].platform.architecture == $arch
  ' <<<"${json}" >/dev/null
}
