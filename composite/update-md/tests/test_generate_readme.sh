#!/usr/bin/env bash
set -euo pipefail
# Description: Exercises the composite's actual input wiring and Bash generator
# against its repository caller and unrelated repositories. Requires jq and yq.
# Uses RUNNER_TEMP or TMPDIR and never regenerates the checkout's README.md.

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
TEST_ROOT="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-.}}/update-md-tests.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
export GITHUB_ACTION_PATH="$SOURCE_ROOT/composite/update-md"
# shellcheck source=composite/update-md/scripts/common.sh
source "$GITHUB_ACTION_PATH/scripts/common.sh"
fail() { printf '%s\n' "$*" >&2; exit 1; }
yq -o=json '.inputs' "$GITHUB_ACTION_PATH/action.yml" > "$TEST_ROOT/inputs.json"
jq 'with_entries(.value = .value.default)' "$TEST_ROOT/inputs.json" > "$TEST_ROOT/defaults.json"
yq -r '.runs.steps[0].run' "$GITHUB_ACTION_PATH/action.yml" > "$TEST_ROOT/action-step.sh"
yq -o=json '.jobs.update-readme.steps[] | select(.uses == "./composite/update-md") | .with' \
  "$SOURCE_ROOT/.github/workflows/_update-readme.yml" > "$TEST_ROOT/caller.json"
cp "$SOURCE_ROOT/README.md" "$TEST_ROOT/original.md"

load_inputs() {
  local name key
  local -A values=()
  json_object values < "$1"
  for key in "${!values[@]}"; do name="${key^^}"; export "INPUT_${name//-/_}=${values[$key]}"; done
}

new_workspace() {
  export GITHUB_WORKSPACE="$TEST_ROOT/$1"
  mkdir -p "$GITHUB_WORKSPACE"
  load_inputs "$TEST_ROOT/defaults.json"
}

run_action() {
  bash -e -o pipefail "$TEST_ROOT/action-step.sh" > "$TEST_ROOT/log" 2>&1 || {
    cat "$TEST_ROOT/log" >&2
    return 1
  }
}

pass() { printf 'PASS: %s\n' "$1"; }

assert_readme() {
  local expected="$1"
  [[ "$expected" == /* ]] || expected="$GITHUB_ACTION_PATH/tests/fixtures/$expected.md"
  run_action </dev/null
  cmp "$expected" "$GITHUB_WORKSPACE/$INPUT_README_PATH"
  pass "$2"
}

new_workspace dogfood
cp -R "$SOURCE_ROOT/.github" "$SOURCE_ROOT/composite" "$GITHUB_WORKSPACE/"
load_inputs "$TEST_ROOT/caller.json"
assert_readme "$TEST_ROOT/original.md" 'repository caller reproduces README.md byte for byte'

new_workspace docs
mkdir -p "$GITHUB_WORKSPACE/docs/sub" "$GITHUB_WORKSPACE/docs/private"
printf '# Alpha [guide]\n\n## Summary\n\nFirst guide.\n\n## Other\nIgnored.\n' > "$GITHUB_WORKSPACE/docs/a.md"
printf '# Beta\n\n## Summary\n\nNested guide.\n' > "$GITHUB_WORKSPACE/docs/sub/b (v2)#.md"
printf '# Private\n' > "$GITHUB_WORKSPACE/docs/private/hidden.md"
printf '# Internal\n' > "$GITHUB_WORKSPACE/docs/_internal.md"
export INPUT_TITLE='Library' INPUT_DESCRIPTION='Documentation for the library.' INPUT_FOOTER='See the license.'
export INPUT_README_PATH='catalog//./README.md' INPUT_ENTRY_TEMPLATE='- [{escaped-title}]({link})'
export INPUT_DESCRIPTION_TEMPLATE='  {description}'
export INPUT_SECTIONS='[{"title":"Guides","path":"./docs/","include":["**/*.md"],"exclude":["private","_*.md"],"recursive":true,"title-pattern":"^# +(.+)$","description-heading":"Summary","show-directory":false}]'
assert_readme docs 'generic recursive documentation, filtering, and nested output links'

new_workspace root-index
mkdir -p "$GITHUB_WORKSPACE/guides"
printf '# Guide\n' > "$GITHUB_WORKSPACE/guides/intro.md"
printf '# Old index\n' > "$GITHUB_WORKSPACE/README.md"
export INPUT_SECTIONS='[{"title":"Documents","path":".","include":["**/*.md"],"recursive":true,"title-pattern":"^# +(.+)$","show-directory":false,"entry-template":"- [{title}]({link})"}]'
run_action
assert_readme root-index 'root scans exclude their output and temporary files on repeated runs'

new_workspace root-docs
printf 'name: Example\n' > "$GITHUB_WORKSPACE/foo.yml"
printf '# Example documentation\n' > "$GITHUB_WORKSPACE/foo.md"
printf 'name: Fallback\n' > "$GITHUB_WORKSPACE/bar.yml"
export INPUT_SECTIONS='[{"title":"Root","path":".","include":["*.yml"],"title-pattern":"^name: (.*)$","doc-extension":".md","show-directory":false,"entry-template":"- [{title}]({link})"}]'
assert_readme root-docs 'root-level doc-extension siblings and fallbacks'
export INPUT_README_PATH='catalog/README.md'
assert_readme root-docs-nested 'root-level doc-extension siblings with nested output'

new_workspace packages
mkdir -p "$GITHUB_WORKSPACE/packages/alpha" "$GITHUB_WORKSPACE/packages/beta" "$GITHUB_WORKSPACE/packages/no-doc"
printf '# Alpha\n\n## Summary\n\nFirst package.\n' > "$GITHUB_WORKSPACE/packages/alpha/ABOUT.md"
printf '# Beta\n\n## Summary\n\nSecond package.\n' > "$GITHUB_WORKSPACE/packages/beta/ABOUT.md"
export INPUT_SECTIONS='[{"title":"Packages","path":"packages","kind":"directories","metadata-file":"ABOUT.md","title-pattern":"^# +(.+)$","description-heading":"Summary","link-file":"ABOUT.md","show-directory":false,"entry-template":"- {title}: {description} ({link})","description-template":""}]'
assert_readme packages 'generic directory metadata and per-section presentation overrides'

new_workspace text
export INPUT_TITLE='Custom & literal {path}' INPUT_TITLE_TEMPLATE='<h1>{title}</h1>'
# Shell syntax in input text must be preserved rather than executed.
# shellcheck disable=SC2016
export INPUT_DESCRIPTION='Text with $(touch SHOULD_NOT_EXIST) and `touch ALSO_NOT_CREATED`.'
export INPUT_HEADER=$'## Installation\n\nRun the installer.'
export INPUT_FOOTER=$'## License\n\nMIT.\n' INPUT_SECTIONS='[]'
assert_readme text 'custom title, description, header, and footer stay literal'
[[ ! -e "$SOURCE_ROOT/SHOULD_NOT_EXIST" && ! -e "$SOURCE_ROOT/ALSO_NOT_CREATED" ]]

new_workspace defaults
mkdir -p "$GITHUB_WORKSPACE/automation & tools" "$GITHUB_WORKSPACE/modules/widget"
printf '# Description: Public workflow.\nname: '\''Quoted "workflow"'\''\non:\n  workflow_call:\n' > "$GITHUB_WORKSPACE/automation & tools/public.yml"
printf '# Public documentation\n' > "$GITHUB_WORKSPACE/automation & tools/public.md"
printf 'name: Rule\non:\n  pull_request:\n' > "$GITHUB_WORKSPACE/automation & tools/ruleset-example.yml"
printf 'name: Hidden\non:\n  workflow_call:\n' > "$GITHUB_WORKSPACE/automation & tools/_hidden.yml"
printf 'name: Ordinary\non:\n  push:\n' > "$GITHUB_WORKSPACE/automation & tools/ordinary.yml"
printf '# Widget\n\n## Description\n\nA widget.\n' > "$GITHUB_WORKSPACE/modules/widget/README.md"
export INPUT_WORKFLOW_DIR='automation & tools' INPUT_COMPOSITE_DIR='modules'
assert_readme defaults 'existing path inputs, workflow selection, and document fallbacks'

new_workspace empty
export INPUT_SECTIONS='[{"title":"Omitted","path":"missing"},{"title":"Kept","path":"also-missing","skip-empty":false,"section-template":"### {title}"}]'
assert_readme empty 'empty indexes can be omitted or retain a custom heading'
export INPUT_SECTIONS='[]'
run_action
[[ ! -s "$GITHUB_WORKSPACE/README.md" ]]

new_workspace formatting
mkdir -p "$GITHUB_WORKSPACE/items"
# shellcheck disable=SC2016
printf '# Item\n\n## Summary\n\nDescription with {title} & $(literal).\n' > "$GITHUB_WORKSPACE/items/a.md"
export INPUT_SECTIONS='[{"title":"Items","path":"items","include":["*.md"],"title-pattern":"^# +(.+)$","description-heading":"Summary"}]'
export INPUT_SECTION_TEMPLATE='### {title}' INPUT_DIRECTORY_TEMPLATE='Directory {icon}: [{path}]({link})'
export INPUT_ENTRY_TEMPLATE='{icon} {title}: {path} -> {link}' INPUT_DESCRIPTION_TEMPLATE='  {description}'
export INPUT_DIRECTORY_ICON='DIR' INPUT_FILE_ICON='FILE'
ln -s "$GITHUB_WORKSPACE/items/a.md" "$GITHUB_WORKSPACE/items/symlink.md"
assert_readme formatting 'all templates and icons are configurable; discovered symlinks are skipped'

new_workspace invalid
printf 'Existing README must survive.\n' > "$GITHUB_WORKSPACE/README.md"
cp "$GITHUB_WORKSPACE/README.md" "$TEST_ROOT/sentinel.md"
expect_rejection() {
  local message="$1"
  shift
  if env "$@" bash -e -o pipefail "$TEST_ROOT/action-step.sh" > "$TEST_ROOT/log" 2>&1; then
    printf 'Expected failure: %s\n' "$message" >&2
    exit 1
  fi
  grep -Fq -- "$message" "$TEST_ROOT/log" || { cat "$TEST_ROOT/log" >&2; exit 1; }
  cmp "$TEST_ROOT/sentinel.md" "$GITHUB_WORKSPACE/README.md"
}
expect_rejection 'sections must be a JSON array' INPUT_SECTIONS='not JSON'
expect_rejection 'sections must be a JSON array' INPUT_SECTIONS='{}'
expect_rejection 'sections must be a JSON array' INPUT_SECTIONS='[{"path":"items","recursive":"true"}]'
expect_rejection 'sections must be a JSON array' INPUT_SECTIONS='[{"path":"items","unknown-field":true}]'
expect_rejection 'sections must be a JSON array' INPUT_SECTIONS='[{"path":"items","title":"bad\u0000value"}]'
expect_rejection 'Invalid extraction pattern' INPUT_SECTIONS='[{"path":"items","title-pattern":"["}]'
expect_rejection 'Invalid contains pattern' INPUT_SECTIONS='[{"path":"items","contains":"["}]'
expect_rejection 'Unknown section kind' INPUT_SECTIONS='[{"path":"items","kind":"unsupported"}]'
expect_rejection 'doc-extension must be' INPUT_SECTIONS='[{"path":"items","doc-extension":"../bad"}]'
expect_rejection 'Unknown template placeholder' INPUT_TITLE='Example' INPUT_TITLE_TEMPLATE='{unknown}' INPUT_SECTIONS='[]'
pass 'invalid JSON, fields, types, patterns, and templates preserve existing output'

mkdir -p "$GITHUB_WORKSPACE/existing"
expect_rejection 'readme-path must name a file' INPUT_README_PATH='existing' INPUT_SECTIONS='[]'
expect_rejection 'readme-path must name a file' INPUT_README_PATH='.' INPUT_SECTIONS='[]'
[[ ! -e "$GITHUB_WORKSPACE/existing/generated.md" ]]
pass 'directory output targets are rejected without creating a nested file'

expect_rejection 'workspace-relative' INPUT_README_PATH='../outside.md'
expect_rejection 'workspace-relative' INPUT_README_PATH='/outside.md'
expect_rejection 'workspace-relative' INPUT_README_PATH='C:\\outside.md'
expect_rejection 'workspace-relative' INPUT_SECTIONS='[{"path":"../outside"}]'
mkdir -p "$TEST_ROOT/outside"
ln -s "$TEST_ROOT/outside" "$GITHUB_WORKSPACE/linked"
expect_rejection 'must not be symlinks' INPUT_README_PATH='linked/README.md'
[[ ! -e "$TEST_ROOT/outside/README.md" ]]
pass 'traversal, absolute paths, and symlink escapes are rejected'

mkdir -p "$GITHUB_WORKSPACE/packages/item"
expect_rejection 'Missing link-file' INPUT_SECTIONS='[{"path":"packages","kind":"directories","link-file":"MISSING.md"}]'
pass 'missing link targets preserve existing output'

yq -o=json '.runs.steps[0].env' "$GITHUB_ACTION_PATH/action.yml" > "$TEST_ROOT/wiring.json"
jq -e --slurpfile actual "$TEST_ROOT/wiring.json" '
  to_entries | map({key: ("INPUT_" + (.key | ascii_upcase | gsub("-"; "_"))),
    value: ("${{ inputs." + .key + " }}")}) | from_entries | . == $actual[0]
' "$TEST_ROOT/inputs.json" >/dev/null
cmp "$TEST_ROOT/original.md" "$SOURCE_ROOT/README.md"
pass 'every input is wired through env; checkout README.md remains unchanged'

new_workspace path-globs
mkdir -p "$GITHUB_WORKSPACE/sub/deep"
for path in sub/a.md sub/deep/b.md sub/deep/c.md; do printf '# Item\n' > "$GITHUB_WORKSPACE/$path"; done
export INPUT_ENTRY_TEMPLATE='- {path}'
export INPUT_SECTIONS='[{"title":"Direct","path":".","recursive":true,"include":["sub/*.md"],"show-directory":false},{"title":"Recursive","path":".","recursive":true,"include":["sub/**/*.md"],"show-directory":false},{"title":"Filtered","path":".","recursive":true,"include":["sub/**/*.md"],"exclude":["sub/[ad]*.md"],"show-directory":false}]'
assert_readme path-globs 'path globs match segments; recursive globbing and exclusions respect separators'

new_workspace title-forms
mkdir -p "$GITHUB_WORKSPACE/items"
printf '%s\n' '# Alpha [guide] \ path' > "$GITHUB_WORKSPACE/items/a.md"
export INPUT_SECTIONS='[{"title":"Links","path":"items","title-pattern":"^# +(.+)$","show-directory":false},{"title":"Plain","path":"items","title-pattern":"^# +(.+)$","show-directory":false,"entry-template":"- {title}"},{"title":"Escaped","path":"items","title-pattern":"^# +(.+)$","show-directory":false,"entry-template":"- {escaped-title}"}]'
assert_readme title-forms 'titles remain raw in custom templates; Markdown links use escaped-title'
