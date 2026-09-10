#!/usr/bin/env bash
set -euo pipefail

# Description: Test release selection, extraction, yq downloads, and setup order
# using temporary tool caches and mocked GitHub CLI responses.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

export RUNNER_OS='Linux'
export RUNNER_ARCH='X64'
export RUNNER_TEMP="${TEST_ROOT}/tmp"
export RUNNER_TOOL_CACHE="${TEST_ROOT}/tool-cache"
export GITHUB_ENV="${TEST_ROOT}/github-env"
export GITHUB_PATH="${TEST_ROOT}/github-path"
mkdir -p "$RUNNER_TEMP" "$RUNNER_TOOL_CACHE"
touch "$GITHUB_ENV" "$GITHUB_PATH"

# shellcheck source=./composite/actions-toolbox/scripts/check_dependencies_unix.sh
source "${ACTION_DIR}/scripts/check_dependencies_unix.sh"

tests=0

pass() {
  tests=$((tests + 1))
  echo "ok ${tests} - $1"
}

fail() {
  echo "not ok - $1" >&2
  exit 1
}

assert_eq() {
  local expected="$1" actual="$2" message="$3"
  [[ "$actual" == "$expected" ]] || fail "${message}: expected '${expected}', got '${actual}'"
}

make_executable() {
  local path="$1" label="$2"
  mkdir -p "$(dirname "$path")"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$label" >"$path"
  chmod +x "$path"
}

# Asset ranking prefers the current platform, rejects checksums and foreign
# platforms, and does not require a GoReleaser filename.
metadata='{
  "tag_name": "v9.8.7",
  "assets": [
    {"id":101,"name":"checksums.txt"},
    {"id":102,"name":"bundle-windows-amd64.zip"},
    {"id":103,"name":"bundle-darwin-arm64.tar.gz"},
    {"id":104,"name":"unusually-named-linux-x86_64.zip"}
  ]
}'
selected="$(select_release_asset "$metadata" desired-command owner/project linux amd64)"
assert_eq $'unusually-named-linux-x86_64.zip\t104' "$selected" \
  'asset ranking should select the compatible generic bundle'
pass 'ranks release assets by platform without assuming a filename convention'

# A raw executable may have a different name than the installed command.
raw_asset="${TEST_ROOT}/raw-upstream-tool"
make_executable "$raw_asset" 'raw'
raw_root="${TEST_ROOT}/raw-root"
extract_release_asset "$raw_asset" 'surprising-upstream-name' "$raw_root"
candidate="$(select_executable_candidate "$raw_root" wanted-command owner/project linux amd64)"
assert_eq "${raw_root}/surprising-upstream-name" "$candidate" \
  'raw differently named executable should be selected'
pass 'selects a differently named raw executable'

# Deeply nested tarballs are searched recursively and documentation is ignored.
tar_source="${TEST_ROOT}/tar-source"
make_executable "${tar_source}/release/share/tools/deep/bin/upstream-cli" 'tar'
printf 'documentation\n' >"${tar_source}/release/README.md"
tar_asset="${TEST_ROOT}/generic-linux-amd64.tar.gz"
tar -czf "$tar_asset" -C "$tar_source" .
tar_root="${TEST_ROOT}/tar-root"
extract_release_asset "$tar_asset" 'generic-linux-amd64.tar.gz' "$tar_root"
candidate="$(select_executable_candidate "$tar_root" wanted-command owner/project linux amd64)"
assert_eq "${tar_root}/release/share/tools/deep/bin/upstream-cli" "$candidate" \
  'nested tar executable should be selected'
pass 'recursively finds an executable in a nested tar.gz archive'

# A cross-platform zip can contain several identically named executables; path
# platform hints disambiguate the runner-compatible one.
zip_source="${TEST_ROOT}/zip-source"
make_executable "${zip_source}/bundle/windows/amd64/renamed-tool" 'windows'
make_executable "${zip_source}/bundle/linux/amd64/renamed-tool" 'linux'
zip_asset="${TEST_ROOT}/all-platforms.zip"
git -C "$zip_source" init -q
git -C "$zip_source" add .
git -C "$zip_source" \
  -c user.name='Fixture Test' -c user.email='fixture@example.invalid' \
  commit -qm 'build zip fixture'
git -C "$zip_source" archive --format=zip --output="$zip_asset" HEAD
zip_root="${TEST_ROOT}/zip-root"
extract_release_asset "$zip_asset" 'all-platforms.zip' "$zip_root"
candidate="$(select_executable_candidate "$zip_root" renamed-tool owner/project linux amd64)"
assert_eq "${zip_root}/bundle/linux/amd64/renamed-tool" "$candidate" \
  'platform path should disambiguate zip candidates'
pass 'uses nested platform hints inside a zip archive'

# Single-file compression is treated like a raw binary after decompression.
gzip_source="${TEST_ROOT}/compressed-tool"
make_executable "$gzip_source" 'gzip'
gzip -c "$gzip_source" >"${TEST_ROOT}/compressed-tool.gz"
gzip_root="${TEST_ROOT}/gzip-root"
extract_release_asset "${TEST_ROOT}/compressed-tool.gz" 'renamed-binary.gz' "$gzip_root"
candidate="$(select_executable_candidate "$gzip_root" wanted-command owner/project linux amd64)"
assert_eq "${gzip_root}/renamed-binary" "$candidate" \
  'gzip-compressed executable should be selected'
pass 'handles a single compressed binary'

# Equally plausible executables should produce diagnostics rather than an
# arbitrary installation.
ambiguous_root="${TEST_ROOT}/ambiguous"
make_executable "${ambiguous_root}/one" 'one'
make_executable "${ambiguous_root}/two" 'two'
if select_executable_candidate "$ambiguous_root" wanted-command owner/project linux amd64 \
  >"${TEST_ROOT}/ambiguous.out" 2>"${TEST_ROOT}/ambiguous.err"; then
  fail 'ambiguous executable candidates should fail'
fi
grep -q 'Could not choose an unambiguous executable' "${TEST_ROOT}/ambiguous.err" \
  || fail 'ambiguity failure should explain the problem'
pass 'fails safely when executable candidates are genuinely ambiguous'

TOOLPATH='/tools/one:/tools/two'
: >"$GITHUB_PATH"
update_path
path_entries="$(paste -sd '|' "$GITHUB_PATH")"
assert_eq '/tools/one|/tools/two' "$path_entries" \
  'tool paths should be written as separate GITHUB_PATH entries'
pass 'publishes each cached tool directory to later workflow steps'
TOOLPATH=''

# Exercise yq's download command, platform naming, executable mode, and cache.
(
  gh() {
    assert_eq 'release download v4.99.0 --repo mikefarah/yq --pattern' "${*:1:6}" \
      'yq should use GitHub CLI release downloads'
    assert_eq "$expected_asset" "$7" 'yq release asset platform'
    assert_eq '--dir' "$8" 'yq download directory option'
    printf '#!/usr/bin/env bash\necho fixture-yq\n' >"${9}/${7}"
  }
  for platform in linux macos; do
    expected_asset='yq_linux_amd64'
    [[ "$platform" != macos ]] || expected_asset='yq_darwin_amd64'
    install_yq v4.99.0 "$platform" amd64
    installed="${RUNNER_TOOL_CACHE}/yq/v4.99.0/${platform}_amd64/yq"
    [[ -x "$installed" ]] || fail 'downloaded yq should be executable'
    assert_eq 'fixture-yq' "$("$installed")" 'downloaded yq should run'
  done
  gh() { fail 'cached yq should not be downloaded again'; }
  install_yq v4.99.0 linux amd64
)
pass 'downloads Linux and macOS yq assets through gh and reuses the cache'

(
  gh() { return 1; }
  if install_yq v4.99.1 linux amd64; then
    fail 'failed yq downloads should return failure'
  fi
  [[ ! -e "${RUNNER_TOOL_CACHE}/yq/v4.99.1/linux_amd64/yq" ]] \
    || fail 'failed yq download should not populate the cache'
  leftovers="$(find "$RUNNER_TEMP" -name 'yq-release.*' -print)"
  assert_eq '' "$leftovers" 'failed yq download should remove its temporary directory'
)
pass 'fails yq downloads without caching a broken executable'

order="$({
  gh_ready=0
  yq_ready=0
  events=''
  check_and_install_dependencies() {
    events+='system>'
  }
  command_exists() {
    case "$1" in
      gh) [[ "$gh_ready" -eq 1 ]] ;;
      yq) [[ "$yq_ready" -eq 1 ]] ;;
      *) return 0 ;;
    esac
  }
  fetch_bootstrap_gh_version() { echo 'v2.99.0'; }
  install_gh_cli() {
    events+='gh>'
    gh_ready=1
    append_toolpath '/mock/gh'
  }
  fetch_latest_version() {
    [[ "$gh_ready" -eq 1 ]] || fail 'release metadata was requested before gh was active'
    echo 'v4.99.0'
  }
  install_yq() {
    [[ "$gh_ready" -eq 1 ]] || fail 'yq was installed before gh was active'
    events+='yq>'
    yq_ready=1
    append_toolpath '/mock/yq'
  }
  install_github_release_dependencies() {
    [[ "$yq_ready" -eq 1 ]] || fail 'release tools were installed before yq was active'
    events+='release'
  }
  update_path() { :; }
  main >/dev/null
  printf '%s' "$events"
})"
assert_eq 'system>gh>yq>release' "$order" 'dependency setup order'
pass 'installs gh and yq before release tools'

captured_install=''
command_exists() { return 1; }
install_packages() { fail "unexpected system package install: $*"; }
install_github_release_tool() { captured_install="$1|$2|${3:-}"; }
check_and_install_dependencies 'actionlint=1.7.7'
assert_eq '' "$captured_install" 'release installation should not run during system package setup'
install_github_release_dependencies
assert_eq 'actionlint|rhysd/actionlint|1.7.7' "$captured_install" \
  'bare actionlint alias should use the release installer'
pass 'supports the bare actionlint release alias'

echo "1..${tests}"
