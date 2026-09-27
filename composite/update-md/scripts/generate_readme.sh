#!/usr/bin/env bash
set -euo pipefail
# Description: Generates Markdown from INPUT_* and GITHUB_WORKSPACE. Requires
# Bash 4.4+, jq, GNU coreutils, and standard Unix text tools.
# shellcheck source=composite/update-md/scripts/common.sh
source "${GITHUB_ACTION_PATH}/scripts/common.sh"

fail() { printf 'update-md: %s\n' "$*" >&2; exit 1; }
for tool in jq realpath; do command -v "$tool" >/dev/null || fail "$tool is required."; done
PROJECT_ROOT="$(cd "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}" && pwd -P)"

validate_path() {
  case "$1" in
    ''|/*|..|../*|*/..|*/../*|*\\*|[a-zA-Z]:*|*$'\n'*|*$'\r'*)
      fail "path must be workspace-relative without '..' segments or backslashes: $1" ;;
  esac
}

workspace_path() {
  local value="$1" absolute existing resolved
  validate_path "$value"
  absolute="$(realpath -ms -- "$PROJECT_ROOT/$value")" existing="$absolute"
  while [[ ! -e "$existing" && ! -L "$existing" ]]; do existing="${existing%/*}"; done
  [[ ! -L "$existing" ]] || fail "Explicit paths must not be symlinks: $value"
  resolved="$(realpath -m -- "$absolute")"
  case "$resolved" in "$PROJECT_ROOT"|"$PROJECT_ROOT"/*) ;; *) fail "Path escapes the workspace through a symlink: $value" ;; esac
  printf '%s' "$absolute"
}

README_PATH="$(workspace_path "$INPUT_README_PATH")"
[[ ! -d "$README_PATH" ]] || fail 'readme-path must name a file, not a directory.'
# Infer allowed fields and their types from one defaults object; reject NULs
# before decoding JSON into Bash's NUL-delimited records.
sections="$(jq -ce '
  def text: type == "string" and (contains("\u0000") | not);
  {title: "", path: "", kind: "files", recursive: false, contains: "", "metadata-file": "",
   "title-pattern": "", "description-pattern": "", "description-heading": "", "doc-extension": "",
   "link-file": "", "strip-title-quotes": false, "skip-empty": true, "show-directory": true,
   include: ["*"], exclude: [], "include-without-content": [],
   "directory-icon": env.INPUT_DIRECTORY_ICON, "file-icon": env.INPUT_FILE_ICON,
   "section-template": env.INPUT_SECTION_TEMPLATE, "directory-template": env.INPUT_DIRECTORY_TEMPLATE,
   "entry-template": env.INPUT_ENTRY_TEMPLATE, "description-template": env.INPUT_DESCRIPTION_TEMPLATE} as $defaults |
  if type == "array" and all(.[];
    type == "object" and (.path | text and length > 0) and all(to_entries[]; .key as $key |
      ($defaults | has($key)) and (.value | type) == ($defaults[$key] | type) and
      (.value | if type == "string" then text elif type == "array" then all(.[]; text and length > 0) else true end)))
  then map($defaults + .) else error("invalid sections") end
' <<< "$INPUT_SECTIONS")" || fail 'sections must be a JSON array of sections with valid fields and types.'
mkdir -p "${README_PATH%/*}"
TEMP_DIR="$(mktemp -d "${README_PATH%/*}/.update-md.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
GENERATED="$TEMP_DIR/generated.md"
: > "$GENERATED"
has_content=false

append_block() {
  local text="$1"
  while [[ "$text" == *$'\n' ]]; do text="${text%$'\n'}"; done
  [[ -n "$text" ]] || return 0
  [[ "$has_content" == false ]] || printf '\n' >> "$GENERATED"
  printf '%s\n' "$text" >> "$GENERATED"
  has_content=true
}

# Match each path component separately; only a complete ** component recurses.
# shellcheck disable=SC2053
path_glob() {
  local file="$1" pattern="$2" head="${2%%/*}"
  [[ "$pattern" != '**' ]] || return 0
  if [[ "$head" == '**' && "$pattern" == */* ]]; then
    path_glob "$file" "${pattern#*/}" && return 0
    [[ "$file" == */* ]] && path_glob "${file#*/}" "$pattern"
  elif [[ "$file" == */* && "$pattern" == */* ]]; then
    [[ "${file%%/*}" == $head ]] && path_glob "${file#*/}" "${pattern#*/}"
  else
    [[ "$file" != */* && "$pattern" != */* && "$file" == $pattern ]]
  fi
}

matches() {
  local file="$1" pattern candidate
  shift
  for pattern in "$@"; do
    candidate="$file"; [[ "$pattern" == */* ]] || candidate="${file##*/}"
    if path_glob "$candidate" "$pattern"; then return 0; fi
  done
  return 1
}

excluded() {
  local candidate="$1"
  while :; do
    if matches "$candidate" "${glob_exclude[@]}"; then return 0; fi
    [[ "$candidate" == */* ]] || return 1
    candidate="${candidate%/*}"
  done
}

extract() {
  [[ -n "$1" ]] || return 0
  jq -Rsr --arg expression "$1" '
    (first(split("\n")[] | match($expression) | (.captures[0].string // .string)) // "") |
    gsub("^[[:space:]]+|[[:space:]]+$"; "")' "$2"
}

heading_description() {
  MD_HEADING="$2" awk '
    { sub(/\r$/, "") }
    !found && $0 == "## " ENVIRON["MD_HEADING"] { found=1; next }
    found && /^#{1,6}[[:space:]]/ { exit }
    found && /[^[:space:]]/ { print; exit }' "$1"
}

relative_link() {
  local relative
  relative="$(realpath -ms --relative-to="${README_PATH%/*}" -- "$1")"
  [[ "$relative" == ../* ]] || relative="./$relative"
  [[ "$2" != true || "$relative" == */ ]] || relative+='/'
  jq -nr --arg value "$relative" '$value | split("/") | map(@uri) | join("/")'
}

emit_rows() {
  local -n config="$1"
  local record_name="$2" field
  shift 2
  for field; do render_template "${config[$field-template]}" "$record_name"; done
}

render_entry() {
  local file="$1" relative="${1#"$PROJECT_ROOT"/}" metadata="$1" target="$1" value sibling directory=false
  local -A row=([title]="${1##*/}" [path]="$relative" [description]='' [icon]="${section[file-icon]}")
  if [[ ${section[kind]} == directories ]]; then
    metadata=''; [[ -z ${section[metadata-file]} ]] || metadata="$file/${section[metadata-file]}"
  fi
  if [[ -n "$metadata" ]]; then
    [[ -f "$metadata" ]] || return 0
    metadata="$(workspace_path "${metadata#"$PROJECT_ROOT"/}")"
    [[ "$metadata" != "$README_PATH" ]] || return 0
  fi
  if [[ -n ${section[contains]} ]] && ! matches "$2" "${glob_extra[@]}"; then
    [[ -n "$metadata" ]] || return 0
    grep -Eq -- "${section[contains]}" "$metadata" || return 0
  fi
  if [[ -n "$metadata" ]]; then
    value="$(extract "${section[title-pattern]}" "$metadata")"
    [[ -z "$value" ]] || row[title]="$value"
    value="${row[title]}"
    if [[ ${section[strip-title-quotes]} == true && ${#value} -ge 2 ]]; then
      case "$value" in \"*\"|\'*\') row[title]="${value:1:${#value}-2}" ;; esac
    fi
    row[description]="$(extract "${section[description-pattern]}" "$metadata")"
    if [[ -z ${row[description]} && -n ${section[description-heading]} ]]; then
      row[description]="$(heading_description "$metadata" "${section[description-heading]}")"
    fi
  fi
  if [[ ${section[kind]} == directories ]]; then
    directory=true
    if [[ -n ${section[link-file]} ]]; then
      target="$(workspace_path "$relative/${section[link-file]}")"; directory=false
      [[ -f "$target" ]] || fail "Missing link-file: $relative/${section[link-file]}"
    fi
  elif [[ -n ${section[doc-extension]} ]]; then
    value="${file##*/}"
    sibling="$(workspace_path "${relative%"${file##*/}"}${value%.*}${section[doc-extension]}")"
    [[ ! -f "$sibling" ]] || target="$sibling"
  fi
  row[link]="$(relative_link "$target" "$directory")"
  emit_rows section row entry
  [[ -z ${row[description]} ]] || emit_rows section row description
}

render_section() {
  local directory value type file entry block
  local -A section=() row=()
  local -a glob_include=() glob_exclude=() glob_extra=() depth=()
  json_object section <<< "$1"
  case "${section[path]}" in
    '{workflow-dir}') section[path]="$INPUT_WORKFLOW_DIR" ;;
    '{composite-dir}') section[path]="$INPUT_COMPOSITE_DIR" ;;
  esac
  directory="$(workspace_path "${section[path]}")"
  section[path]="${directory#"$PROJECT_ROOT"/}"; [[ "$directory" != "$PROJECT_ROOT" ]] || section[path]='.'
  case "${section[kind]}" in files) type=f ;; directories) type=d ;; *) fail "Unknown section kind: ${section[kind]}" ;; esac
  for value in metadata-file link-file; do
    [[ -z ${section[$value]} ]] || validate_path "${section[$value]}"
    [[ -z ${section[$value]} || ${section[kind]} == directories ]] || fail 'metadata-file and link-file require kind directories.'
  done
  [[ -z ${section[doc-extension]} || ${section[doc-extension]} =~ ^\.[^/\\[:space:]]+$ ]] || fail 'doc-extension must be a filename extension beginning with a dot.'
  for value in title-pattern description-pattern; do
    [[ -z ${section[$value]} ]] || jq -n --arg expression "${section[$value]}" '"" | match($expression)' >/dev/null || fail "Invalid extraction pattern: ${section[$value]}"
  done
  if [[ -n ${section[contains]} ]]; then
    if grep -Eq -- "${section[contains]}" /dev/null; then :; else [[ $? -eq 1 ]] || fail "Invalid contains pattern: ${section[contains]}"; fi
  fi
  mapfile -d '' -t glob_include < <(jq -j '.[] + "\u0000"' <<< "${section[include]}")
  mapfile -d '' -t glob_exclude < <(jq -j '.[] + "\u0000"' <<< "${section[exclude]}")
  mapfile -d '' -t glob_extra < <(jq -j '.[] + "\u0000"' <<< "${section[include-without-content]}")
  : > "$TEMP_DIR/entries"
  if [[ -e "$directory" ]]; then
    [[ -d "$directory" ]] || fail "Section path is not a directory: ${section[path]}"
    [[ ${section[recursive]} == true ]] || depth=(-maxdepth 1)
    find "$directory" -mindepth 1 "${depth[@]}" -type "$type" -print0 | sort -z > "$TEMP_DIR/paths"
    while IFS= read -r -d '' file; do
      case "$file" in "$TEMP_DIR"|"$TEMP_DIR"/*) continue ;; esac
      entry="${file#"$directory"/}"
      matches "$entry" "${glob_include[@]}" || continue
      if ! excluded "$entry"; then render_entry "$file" "$entry" >> "$TEMP_DIR/entries"; fi
    done < "$TEMP_DIR/paths"
  fi
  [[ -s "$TEMP_DIR/entries" || ${section[skip-empty]} == false ]] || return 0
  row=([title]="${section[title]}" [path]="${section[path]}" [link]="$(relative_link "$directory" true)" [description]='' [icon]="${section[directory-icon]}")
  emit_rows section row section > "$TEMP_DIR/section"
  if [[ -d "$directory" && ${section[show-directory]} == true ]]; then emit_rows section row directory >> "$TEMP_DIR/section"; fi
  cat "$TEMP_DIR/entries" >> "$TEMP_DIR/section"
  block="$(cat "$TEMP_DIR/section")"; append_block "$block"
}

# Passed by name to the template renderer.
# shellcheck disable=SC2034
declare -A title_record=([title]="$INPUT_TITLE" [path]='' [link]='' [description]='' [icon]='')
if [[ -n "$INPUT_TITLE" ]]; then
  title_block="$(render_template "$INPUT_TITLE_TEMPLATE" title_record)"; append_block "$title_block"
fi
for text_input in INPUT_DESCRIPTION INPUT_HEADER; do append_block "${!text_input}"; done
while IFS= read -r section_json; do render_section "$section_json"; done < <(jq -c '.[]' <<< "$sections")
append_block "$INPUT_FOOTER"
mv -T -- "$GENERATED" "$README_PATH"
printf '%s has been updated successfully!\n' "$INPUT_README_PATH"
