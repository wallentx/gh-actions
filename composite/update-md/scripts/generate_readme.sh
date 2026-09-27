#!/usr/bin/env bash
set -euo pipefail
# Description: Generates a Markdown index using the action's INPUT_* environment
# variables and GITHUB_WORKSPACE. Requires Bash, jq, and standard Unix tools.

fail() {
  printf 'update-md: %s\n' "$*" >&2
  exit 1
}

command -v jq >/dev/null || fail 'jq is required; install it before using this action.'
PROJECT_ROOT="$(cd "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE must be set}" && pwd -P)"

validate_relative_path() {
  local name="$1" value="$2"
  [[ -n "$value" ]] || fail "$name must not be empty."
  case "$value" in
    /*|..|../*|*/..|*/../*|*\\*|[a-zA-Z]:*|*$'\n'*|*$'\r'*)
      fail "$name must be workspace-relative without '..' segments or backslashes: $value" ;;
  esac
}

workspace_path() {
  local relative="$1" existing resolved absolute
  validate_relative_path 'path' "$relative"
  relative="$(normalize_path "$relative")"
  absolute="$PROJECT_ROOT"
  [[ "$relative" == '.' ]] || absolute+="/$relative"
  existing="$absolute"
  while [[ ! -e "$existing" && ! -L "$existing" ]]; do existing="${existing%/*}"; done
  [[ ! -L "$existing" ]] || fail "Explicit paths must not be symlinks: $relative"
  if [[ -d "$existing" ]]; then
    resolved="$(cd "$existing" && pwd -P)"
  else
    resolved="$(cd "$(dirname "$existing")" && pwd -P)/$(basename "$existing")"
  fi
  case "$resolved" in
    "$PROJECT_ROOT"|"$PROJECT_ROOT"/*) ;;
    *) fail "Path escapes the workspace through a symlink: $relative" ;;
  esac
  printf '%s' "$absolute"
}

normalize_path() {
  local component result=''
  local -a components=()
  IFS=/ read -r -a components <<< "$1"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != '.' ]] || continue
    [[ -z "$result" ]] || result+='/'
    result+="$component"
  done
  printf '%s' "${result:-.}"
}

validate_relative_path 'readme-path' "$INPUT_README_PATH"
README_REL="$(normalize_path "$INPUT_README_PATH")"
README_PATH="$(workspace_path "$README_REL")"
[[ ! -d "$README_PATH" ]] || fail 'readme-path must name a file, not a directory.'
OUTPUT_DIR="$(dirname "$README_REL")"

# Reject malformed configuration before opening any output. Section keys and
# types are checked before they are used to populate section_* shell variables.
jq -e '
  def text: type == "string" and (contains("\u0000") | not);
  def strings: type == "array" and all(.[]; text and length > 0);
  ["title", "path", "kind", "contains", "metadata-file", "title-pattern",
   "description-pattern", "description-heading", "doc-extension", "link-file",
   "directory-icon", "file-icon", "section-template", "directory-template",
   "entry-template", "description-template"] as $text |
  ["recursive", "strip-title-quotes", "skip-empty", "show-directory"] as $booleans |
  ["include", "exclude", "include-without-content"] as $arrays |
  type == "array" and all(.[];
    type == "object" and (.path | text and length > 0) and
    all(to_entries[]; .key as $key |
      if $text | index($key) then .value | text
      elif $booleans | index($key) then .value | type == "boolean"
      elif $arrays | index($key) then .value | strings
      else false end
    )
  )
' <<< "$INPUT_SECTIONS" >/dev/null || fail 'sections must be a JSON array of sections with valid fields and types.'

mkdir -p "$(dirname "$README_PATH")"
TEMP_DIR="$(mktemp -d "$(dirname "$README_PATH")/.update-md.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
GENERATED="$TEMP_DIR/generated.md"
: > "$GENERATED"
has_content=false

append_block() {
  local text="$1"
  while [[ "$text" == *$'\n' ]]; do text="${text%$'\n'}"; done
  [[ -n "$text" ]] || return 0
  if [[ "$has_content" == true ]]; then printf '\n' >> "$GENERATED"; fi
  printf '%s\n' "$text" >> "$GENERATED"
  has_content=true
}

render_template() {
  local remaining="$1" title="$2" directory="$3" link="$4" description="$5" icon="$6"
  local result='' token name
  while [[ "$remaining" =~ \{([a-z][a-z-]*)\} ]]; do
    token="${BASH_REMATCH[0]}" name="${BASH_REMATCH[1]}"
    result+="${remaining%%"$token"*}"
    remaining="${remaining#*"$token"}"
    case "$name" in
      title) result+="$title" ;;
      path) result+="$directory" ;;
      link) result+="$link" ;;
      description) result+="$description" ;;
      icon) result+="$icon" ;;
      *) fail "Unknown template placeholder: $token" ;;
    esac
  done
  printf '%s' "$result$remaining"
}

matches() {
  local file="$1" candidate pattern
  shift
  for pattern in "$@"; do
    candidate="$file"
    [[ "$pattern" == */* ]] || candidate="${file##*/}"
    # Bash globs with **/ also match files directly in the section directory.
    # shellcheck disable=SC2053
    if [[ "$candidate" == $pattern ]]; then return 0; fi
    # shellcheck disable=SC2053
    if [[ "$pattern" == '**/'* && "$candidate" == ${pattern#\*\*/} ]]; then return 0; fi
  done
  return 1
}

excluded() {
  local candidate="$1"
  shift
  while :; do
    if matches "$candidate" "$@"; then return 0; fi
    [[ "$candidate" == */* ]] || break
    candidate="${candidate%/*}"
  done
  return 1
}

extract() {
  local expression="$1" file="$2"
  [[ -n "$expression" ]] || return 0
  # Pass the pattern as data, so it cannot add commands to a sed program.
  jq -Rr --arg expression "$expression" 'match($expression) | (.captures[0].string // .string)' "$file" |
    sed -n '1{s/^[[:space:]]*//;s/[[:space:]]*$//;p;}'
}

heading_description() {
  local file="$1" heading="$2" line found=false
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    if [[ "$found" == false ]]; then
      [[ "$line" != "## $heading" ]] || found=true
    elif [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
      break
    elif [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
      printf '%s' "$line"
      break
    fi
  done < "$file"
}

relative_link() {
  local target="${1#./}" is_directory="$2" from="$OUTPUT_DIR" result='' i
  local -a from_parts=() target_parts=()
  if [[ "$from" != '.' ]]; then IFS=/ read -r -a from_parts <<< "$from"; fi
  IFS=/ read -r -a target_parts <<< "$target"
  while [[ ${#from_parts[@]} -gt 0 && ${#target_parts[@]} -gt 0 && "${from_parts[0]}" == "${target_parts[0]}" ]]; do
    from_parts=("${from_parts[@]:1}") target_parts=("${target_parts[@]:1}")
  done
  for ((i=0; i<${#from_parts[@]}; i++)); do result+='../'; done
  if [[ -z "$result" ]]; then result='./'; fi
  for ((i=0; i<${#target_parts[@]}; i++)); do
    result+="${target_parts[$i]}"
    [[ $i -eq $((${#target_parts[@]} - 1)) ]] || result+='/'
  done
  [[ "$is_directory" != true || "$result" == */ ]] || result+='/'
  jq -nr --arg value "$result" '$value | split("/") | map(@uri) | join("/")'
}

render_section() {
  local json="$1" key value section_dir type file relative metadata title description link target sibling
  local section_title section_path section_kind section_recursive section_contains section_metadata_file
  local section_title_pattern section_description_pattern section_description_heading section_doc_extension
  local section_link_file section_strip_title_quotes section_skip_empty section_show_directory
  local section_directory_icon section_file_icon section_section_template section_directory_template
  local section_entry_template section_description_template section_include section_exclude section_include_without_content
  local -a include_patterns=() exclude_patterns=() extra_patterns=() depth=()

  while IFS= read -r -d '' key && IFS= read -r -d '' value; do
    printf -v "section_${key//-/_}" '%s' "$value"
  done < <(jq -j '
    {title: "", kind: "files", recursive: false, contains: "", "metadata-file": "",
     "title-pattern": "", "description-pattern": "", "description-heading": "",
     "doc-extension": "", "link-file": "", "strip-title-quotes": false,
     "skip-empty": true, "show-directory": true, include: ["*"], exclude: [],
     "include-without-content": [], "directory-icon": env.INPUT_DIRECTORY_ICON,
     "file-icon": env.INPUT_FILE_ICON, "section-template": env.INPUT_SECTION_TEMPLATE,
     "directory-template": env.INPUT_DIRECTORY_TEMPLATE, "entry-template": env.INPUT_ENTRY_TEMPLATE,
     "description-template": env.INPUT_DESCRIPTION_TEMPLATE} + . |
    to_entries[] | .key, "\u0000", (.value | if type == "array" then tojson else tostring end), "\u0000"
  ' <<< "$json")

  case "$section_path" in
    '{workflow-dir}') section_path="$INPUT_WORKFLOW_DIR" ;;
    '{composite-dir}') section_path="$INPUT_COMPOSITE_DIR" ;;
  esac
  validate_relative_path 'section.path' "$section_path"
  section_path="$(normalize_path "$section_path")"
  section_dir="$(workspace_path "$section_path")"
  case "$section_kind" in files) type=f ;; directories) type=d ;; *) fail "Unknown section kind: $section_kind" ;; esac
  for value in "$section_metadata_file" "$section_link_file"; do
    [[ -z "$value" ]] || validate_relative_path 'metadata-file/link-file' "$value"
    [[ -z "$value" || "$section_kind" == directories ]] || fail 'metadata-file and link-file require kind directories.'
  done
  if [[ -n "$section_doc_extension" ]]; then
    [[ "$section_doc_extension" =~ ^\.[^/\\[:space:]]+$ ]] || fail 'doc-extension must be a filename extension beginning with a dot.'
  fi
  for value in "$section_title_pattern" "$section_description_pattern"; do
    [[ -z "$value" ]] || jq -n --arg expression "$value" '"" | match($expression)' >/dev/null || fail "Invalid extraction pattern: $value"
  done
  if [[ -n "$section_contains" ]]; then
    if grep -Eq -- "$section_contains" /dev/null; then :; else
      [[ $? -eq 1 ]] || fail "Invalid contains pattern: $section_contains"
    fi
  fi
  while IFS= read -r -d '' value; do include_patterns+=("$value"); done < <(jq -j '.[] + "\u0000"' <<< "$section_include")
  while IFS= read -r -d '' value; do exclude_patterns+=("$value"); done < <(jq -j '.[] + "\u0000"' <<< "$section_exclude")
  while IFS= read -r -d '' value; do extra_patterns+=("$value"); done < <(jq -j '.[] + "\u0000"' <<< "$section_include_without_content")

  : > "$TEMP_DIR/entries"
  if [[ -e "$section_dir" ]]; then
    [[ -d "$section_dir" ]] || fail "Section path is not a directory: $section_path"
    [[ "$section_recursive" == true ]] || depth=(-maxdepth 1)
    find "$section_dir" -mindepth 1 "${depth[@]}" -type "$type" -print0 | sort -z > "$TEMP_DIR/paths"
    while IFS= read -r -d '' file; do
      case "$file" in "$TEMP_DIR"|"$TEMP_DIR"/*) continue ;; esac
      relative="${file#"$section_dir"/}"
      matches "$relative" "${include_patterns[@]}" || continue
      if excluded "$relative" "${exclude_patterns[@]}"; then continue; fi
      metadata="$file"
      if [[ "$section_kind" == directories ]]; then
        metadata=''
        [[ -z "$section_metadata_file" ]] || metadata="$file/$section_metadata_file"
      fi
      title="${file##*/}" description=''
      if [[ -n "$metadata" ]]; then
        [[ -f "$metadata" ]] || continue
        metadata="$(workspace_path "${metadata#"$PROJECT_ROOT"/}")"
        [[ "$metadata" != "$README_PATH" ]] || continue
      fi
      if [[ -n "$section_contains" ]] && ! matches "$relative" "${extra_patterns[@]}"; then
        [[ -n "$metadata" ]] || continue
        grep -Eq -- "$section_contains" "$metadata" || continue
      fi
      if [[ -n "$metadata" ]]; then
        value="$(extract "$section_title_pattern" "$metadata")"
        [[ -z "$value" ]] || title="$value"
        if [[ "$section_strip_title_quotes" == true && ${#title} -ge 2 ]]; then
          case "$title" in \"*\"|\'*\') title="${title:1:${#title}-2}" ;; esac
        fi
        description="$(extract "$section_description_pattern" "$metadata")"
        if [[ -z "$description" && -n "$section_description_heading" ]]; then
          description="$(heading_description "$metadata" "$section_description_heading")"
        fi
      fi
      relative="${file#"$PROJECT_ROOT"/}"
      target="$relative" value=false
      if [[ "$section_kind" == directories ]]; then
        value=true
        if [[ -n "$section_link_file" ]]; then
          target="$relative/$section_link_file" value=false
          sibling="$(workspace_path "$target")"
          [[ -f "$sibling" ]] || fail "Missing link-file: $target"
        fi
      elif [[ -n "$section_doc_extension" ]]; then
        sibling="${file##*/}"
        [[ "$sibling" != *.* ]] || sibling="${sibling%.*}"
        sibling="$(dirname "$relative")/$sibling$section_doc_extension"
        link="$(workspace_path "$sibling")"
        [[ ! -f "$link" ]] || target="$sibling"
      fi
      link="$(relative_link "$target" "$value")"
      title="$(printf '%s' "$title" | sed 's/[][\\]/\\&/g')"
      if [[ -n "$section_entry_template" ]]; then
        render_template "$section_entry_template" "$title" "$relative" "$link" "$description" "$section_file_icon" >> "$TEMP_DIR/entries"
        printf '\n' >> "$TEMP_DIR/entries"
      fi
      if [[ -n "$description" && -n "$section_description_template" ]]; then
        render_template "$section_description_template" "$title" "$relative" "$link" "$description" "$section_file_icon" >> "$TEMP_DIR/entries"
        printf '\n' >> "$TEMP_DIR/entries"
      fi
    done < "$TEMP_DIR/paths"
  fi
  [[ -s "$TEMP_DIR/entries" || "$section_skip_empty" == false ]] || return 0
  : > "$TEMP_DIR/section"
  link="$(relative_link "$section_path" true)"
  if [[ -n "$section_section_template" ]]; then
    render_template "$section_section_template" "$section_title" "$section_path" "$link" '' "$section_directory_icon" >> "$TEMP_DIR/section"
    printf '\n' >> "$TEMP_DIR/section"
  fi
  if [[ -d "$section_dir" && "$section_show_directory" == true && -n "$section_directory_template" ]]; then
    render_template "$section_directory_template" "$section_title" "$section_path" "$link" '' "$section_directory_icon" >> "$TEMP_DIR/section"
    printf '\n' >> "$TEMP_DIR/section"
  fi
  cat "$TEMP_DIR/entries" >> "$TEMP_DIR/section"
  append_block "$(cat "$TEMP_DIR/section")"
}

if [[ -n "$INPUT_TITLE" && -n "$INPUT_TITLE_TEMPLATE" ]]; then
  title_block="$(render_template "$INPUT_TITLE_TEMPLATE" "$INPUT_TITLE" '' '' '' '')"
  append_block "$title_block"
fi
append_block "$INPUT_DESCRIPTION"
append_block "$INPUT_HEADER"
while IFS= read -r -d '' section; do render_section "$section"; done < <(jq -j '.[] | tojson + "\u0000"' <<< "$INPUT_SECTIONS")
append_block "$INPUT_FOOTER"
mv -T -- "$GENERATED" "$README_PATH"
printf '%s has been updated successfully!\n' "$INPUT_README_PATH"
