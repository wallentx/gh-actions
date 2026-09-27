# Update Markdown Index

## Description

Automatically generates and updates README.md indexes for reusable workflows and composite actions.

The same generator can index documentation, packages, examples, or other files and directories. All repository text comes from inputs; the default sections provide an optional GitHub Actions layout.

## Inputs

All inputs are optional. Text inputs accept literal Markdown, including multiline YAML blocks. Empty text inputs omit that block.

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `title` | README title, without a heading prefix | No | Empty |
| `title-template` | Title formatting with `{title}` | No | `# {title}` |
| `description` | Markdown below the title | No | Empty |
| `header` | Additional Markdown before the indexes | No | Empty |
| `footer` | Additional Markdown after the indexes | No | Empty |
| `sections` | JSON array of ordered index sections; `[]` disables indexes | No | Workflow and composite indexes, defined in `action.yml` |
| `section-template` | Section heading template | No | `## {title}` |
| `directory-template` | Directory row template; empty omits the row | No | `- {icon} __{path}__` |
| `entry-template` | Entry row template | No | `   - {icon} [{title}]({link})` |
| `description-template` | Description row template; empty omits the row | No | `      - _{description}_` |
| `directory-icon` | Directory icon or text; may be empty | No | `📂` |
| `file-icon` | Entry icon or text; may be empty | No | `📄` |
| `workflow-dir` | Path used by the default workflow section | No | `.github/workflows` |
| `composite-dir` | Path used by the default composite section | No | `composite` |
| `readme-path` | Workspace-relative Markdown output path | No | `README.md` |

The document order is title, description, header, sections, footer, with a blank line between nonempty blocks. The title and introduction are no longer supplied implicitly; pass them explicitly to retain existing text. The existing directory inputs still configure the default indexes.

## Outputs

This action has no step outputs. It replaces the file at `readme-path` after generation succeeds. It does not commit or push the result.

## Usage

### Index workflows and composite actions

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: wallentx/gh-actions/composite/update-md@main
    with:
      title: 'Example Automation'
      description: 'Reusable automation for our projects.'
      header: |
        ## Getting started

        Read each workflow or action document before using it.
      footer: |
        ## Contributing

        See [CONTRIBUTING.md](./CONTRIBUTING.md).
      workflow-dir: '.github/workflows'
      composite-dir: 'composite'
```

The default workflow section includes `*.yml` files containing `workflow_call:` and files named `ruleset-*.yml`, excludes `_*.yml`, and prefers sibling `.md` documents. The default composite section extracts titles and descriptions from each child directory's `README.md`. These conventions are configuration in `action.yml`, rather than named cases in the generator.

### Index documentation in any repository

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: wallentx/gh-actions/composite/update-md@main
    with:
      title: 'Example Library'
      description: 'Guides and reference material for the library.'
      readme-path: 'catalog/README.md'
      entry-template: '- [{title}]({link})'
      description-template: '  {description}'
      sections: |
        [
          {
            "title": "Guides",
            "path": "docs",
            "kind": "files",
            "include": ["**/*.md"],
            "exclude": ["drafts", "_*.md"],
            "recursive": true,
            "title-pattern": "^# +(.+)$",
            "description-heading": "Summary",
            "show-directory": false
          }
        ]
      footer: 'See [LICENSE](../LICENSE) for terms.'
```

Generated entry links are relative to the output file, including nested `readme-path` values. Links written directly in header, description, footer, or templates are kept verbatim.

### Index packages or examples

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: wallentx/gh-actions/composite/update-md@main
    with:
      title: 'Example Packages'
      sections: |
        [
          {
            "title": "Packages",
            "path": "packages",
            "kind": "directories",
            "metadata-file": "ABOUT.md",
            "title-pattern": "^# +(.+)$",
            "description-heading": "Summary",
            "link-file": "ABOUT.md",
            "exclude": [".*"],
            "entry-template": "- [{title}]({link}): {description}",
            "description-template": "",
            "show-directory": false
          }
        ]
```

Use `sections: '[]'` to generate a document consisting only of your title, description, header, and footer.

## Section options

Each section is an object in the `sections` JSON array. Sections appear in array order; entries sort by path. Unknown fields and invalid types fail generation.

| Field | Description | Default |
|-------|-------------|---------|
| `path` | Required workspace-relative directory; the exact values `{workflow-dir}` and `{composite-dir}` use those inputs | Required |
| `title` | Section heading text | Empty |
| `kind` | `files` or `directories` | `files` |
| `include` | Array of shell globs selecting entries | `["*"]` |
| `exclude` | Array of shell globs excluding entries or their parent directories | `[]` |
| `recursive` | Include descendants rather than just direct children | `false` |
| `contains` | Extended regular expression required in entry metadata | Empty, no content filter |
| `include-without-content` | Globs that bypass `contains`, while still respecting `include` and `exclude` | `[]` |
| `metadata-file` | File to read inside each directory; directories missing it are skipped | Empty, use directory names |
| `title-pattern` | Extended regular expression whose first capture group provides the title | Empty, use the entry basename |
| `strip-title-quotes` | Remove matching outer single or double quotes from extracted titles | `false` |
| `description-pattern` | Extended regular expression whose first capture group provides the description | Empty |
| `description-heading` | Markdown H2 heading whose first nonblank content line supplies the description if the pattern did not | Empty |
| `doc-extension` | For files, prefer an existing sibling with this extension, such as `.md` | Empty, link to the file |
| `link-file` | For directories, link to this child file instead of the directory; a missing target fails generation | Empty, link to the directory |
| `skip-empty` | Omit the section when there are no rendered entries | `true` |
| `show-directory` | Include the directory row when the directory exists | `true` |
| `section-template`, `directory-template`, `entry-template`, `description-template` | Override the corresponding template for this section | Corresponding action input |
| `directory-icon`, `file-icon` | Override the corresponding icon for this section | Corresponding action input |

Globs without `/` match basenames, including in recursive sections. Globs with `/` match paths relative to the section directory; `**/` also matches zero directories. Shell glob syntax supports `*`, `?`, and character classes. Exclusions also apply to ancestor directories. Discovered symlinks, the output document, and generation temporary files are skipped.

Extraction patterns use jq regular expression syntax and select the first capture group of the first matching physical line, or the full match when there is no capture group. `contains` uses `grep -E` syntax. For example, `"title-pattern": "^name:[[:blank:]]*(.*)$"` reads a one-line `name:` field. These selectors do not parse YAML block scalars or structured metadata. Write JSON backslashes as `\\`.

Templates substitute `{title}`, `{path}`, `{link}`, `{description}`, and `{icon}` once. In entry rows, `path` is workspace-relative, `link` is output-relative, and `icon` uses `file-icon`. For section and directory rows, they refer to the section directory and `directory-icon`; `description` is empty. Input text is kept literal, including shell syntax and placeholder-like text inside extracted values. The default Markdown links escape brackets in entry titles and encode special characters in link paths. Empty templates omit their rows.

## Requirements and validation

Use a runner with Bash 4.4+, `jq`, GNU coreutils (`realpath` with `-m`, `-s`, and `--relative-to`, plus `mv -T`), and Unix text tools including `awk`, `sed`, and `find -print0`. Ubuntu hosted runners provide these tools. If your runner needs dependencies, install them first using [Actions Toolbox](../actions-toolbox/).

All paths must stay within `GITHUB_WORKSPACE` and cannot contain parent traversal segments or backslashes. Explicit symlink paths and paths resolving outside the workspace fail. Missing source directories are treated as empty sections; `skip-empty: false` can keep their headings. `readme-path` must name a file; directory targets are rejected. Generation uses a temporary file and replaces the output only on success, so invalid configuration leaves an existing output intact.

This repository supplies its title, introduction, and section definitions explicitly in [the update workflow](../../.github/workflows/_update-readme.yml). Its existing README is the exact-output fixture; generic output snapshots live in `tests/fixtures/`. Run the Bash tests locally with `bash composite/update-md/tests/test_generate_readme.sh` (requires `jq` and `yq`); [_test-update-md.yml](../../.github/workflows/_test-update-md.yml) also exercises the composite through `with:`.
