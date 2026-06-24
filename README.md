# gh-actions

A centralized repository for reusable GitHub Actions workflows and composite actions. These actions and workflows can be referenced from any GitHub Actions workflow in any repository.

## Reusable Workflows Index
- 📂 __.github/workflows__
   - 📄 [Termux Run](./.github/workflows/termux-run.yml)
      - _Run arbitrary commands inside a Termux pacman Docker environment on GitHub's hosted ARM runner._

## Composite Actions Index
- 📂 __composite__
   - 📄 [Actions Toolbox](./composite/actions-toolbox/)
      - _🧰 Actions Toolbox is a composite GitHub Action designed to help with debugging, diagnostics, and tool management across various operating systems (Linux, macOS, Windows) in GitHub workflows. It performs tasks such as installing packages and tooling, identifying hardware specifications, identifying release/pre-release conditions, dumping contextual information, and setting or printing environment variables that can be used in subsequent steps, and providing rich environment and execution details for diagnostic purposes._
   - 📄 [Checkout and Cache](./composite/checkout-and-cache/)
      - _A composite action that combines repository checkout with intelligent dependency caching for common package managers._
   - 📄 [Update Markdown Index](./composite/update-md/)
      - _Automatically generates and updates README.md indexes for reusable workflows and composite actions._


## Termux Run Usage

`.github/workflows/termux-run.yml` runs arbitrary commands inside a Termux pacman Docker environment on GitHub's hosted ARM runner. It is intended for public repositories that need a free ARM64 Termux execution environment without maintaining their own Termux Docker wrapper script.

```yaml
jobs:
  termux:
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: |
        clang
      copy-paths: |
        README.md
      env: |
        TERMUX_RUN_MODE=ci
      commands: |
        set -Eeuo pipefail
        test "$TERMUX_RUN_MODE" = "ci"
        clang --version
```

### Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `packages` | Newline or whitespace separated pacman packages to install before running commands | No | `""` |
| `copy-paths` | Newline separated files or directories copied into the Termux workspace | No | `.` |
| `exclude-paths` | Newline separated tar exclude patterns omitted while staging files | No | `.git`, `./.git` |
| `env` | Newline separated `KEY=value` entries exported for host prep and inside Termux | No | `""` |
| `host-commands` | Bash commands run on the ARM Ubuntu host before staging files | No | `""` |
| `commands` | Bash commands run inside Termux | Yes | N/A |
| `sync-back-paths` | Newline separated files or directories copied back into the GitHub workspace | No | `""` |
| `upload-artifact-name` | Artifact name used to upload synced paths | No | `""` |
| `termux-image` | Docker image that provides the Termux pacman environment | No | `termux/termux-docker-pacman` |
| `runs-on` | GitHub-hosted runner label | No | `ubuntu-24.04-arm` |
| `checkout` | Whether to run `actions/checkout` for the caller repository | No | `true` |
| `default-packages` | Whether to install default packages such as `termux-exec` | No | `true` |
| `upgrade-system` | Whether to run a full `pacman -Syu` before installing packages | No | `false` |
| `pacman-timeout-minutes` | Timeout for each pacman transaction | No | `10` |

### Copy And Sync Model

The workflow stages only `copy-paths` into a clean Termux workspace under `${PREFIX:-/data/data/com.termux/files/usr}/tmp/ci-workspace`. Use `exclude-paths` to omit generated directories such as `target`, `bin`, or `staging` when copying a broad path like `.`.

Use `host-commands` for downloads or artifact preparation that should happen on the Ubuntu ARM host before staging. Values from the `env` input are exported before `host-commands` run and again inside Termux. Use `sync-back-paths` when commands produce files that later workflow jobs need. If `upload-artifact-name` is set, synced files are also uploaded with `actions/upload-artifact`.

The workflow refreshes pacman package databases before installing requested packages, but it does not run a full base-image upgrade by default. Set `upgrade-system: true` only when the caller explicitly needs `pacman -Syu` before package installation. Each pacman transaction is bounded by `pacman-timeout-minutes`, so post-transaction hook hangs fail the job instead of consuming the whole runner timeout.

Host preparation commands receive `GH_TOKEN` and `GITHUB_TOKEN` from the workflow token. To use a different token, pass the optional `github-token` secret.

Set caller job permissions for whatever `host-commands` need. For example, current-repository release downloads usually need `contents: read`; Actions artifact downloads usually need `actions: read`; uploading artifacts via `upload-artifact-name` usually needs `actions: write`.

### Artifact Smoke Example

```yaml
jobs:
  termux-artifact-smoke:
    permissions:
      contents: read
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: |
        ca-certificates
        libc++
        tar
        zstd
      env: |
        RELEASE_TAG=rust-v0.0.0-termux
      host-commands: |
        mkdir -p artifact
        gh release download "$RELEASE_TAG" --pattern '*aarch64-linux-android*.tar.gz' --dir artifact
      copy-paths: |
        artifact
      commands: |
        set -Eeuo pipefail
        archive="$(find artifact -type f -name '*aarch64-linux-android*.tar.gz' -print -quit)"
        test -n "$archive"
        mkdir -p smoke
        tar -xzf "$archive" -C smoke
        find smoke -maxdepth 3 -type f -print
```

### PR Check Matrix Example

```yaml
jobs:
  termux:
    strategy:
      matrix:
        include:
          - packages: clang
            commands: |
              clang --version
              clang-format --version
          - packages: cppcheck
            commands: |
              cppcheck --version
    uses: wallentx/gh-actions/.github/workflows/termux-run.yml@main
    with:
      packages: ${{ matrix.packages }}
      copy-paths: |
        lib
      commands: |
        set -Eeuo pipefail
        ${{ matrix.commands }}
```

## How to Use These Actions

### In Your Workflows

Reference any action in this repository using the following format:

```yaml
steps:
  - uses: wallentx/gh-actions/composite/<action-name>@<ref>
```

Where:
- `<action-name>` is the directory name of the action (e.g., `setup-environment`)
- `<ref>` is a git reference (branch, tag, or commit SHA)

### Recommended Versioning

For production workflows, it's recommended to pin to a specific version:

```yaml
# Pin to a specific commit (most secure)
- uses: wallentx/gh-actions/composite/setup-environment@<commit-sha>

# Pin to a version tag (recommended)
- uses: wallentx/gh-actions/composite/setup-environment@v1

# Use the latest from main branch (use with caution)
- uses: wallentx/gh-actions/composite/setup-environment@main
```

## Creating New Actions

To add a new composite action to this repository:

1. Create a new directory under `composite/` with a descriptive name (e.g., `my-action`)
2. Add an `action.yml` file in that directory with your action definition
3. Add a `README.md` file documenting the action's usage following the standard format:
   ```markdown
   # Action Name

   ## Description

   A brief, single-sentence description of what this action does

   ## Inputs
   ...
   ```
4. The README index will be automatically updated when changes are pushed

### Composite Action Structure

```
composite/my-action/
├── action.yml    # Action definition with inputs, outputs, and steps
└── README.md     # Documentation for the action
```

### Example action.yml

```yaml
name: 'My Action'
description: 'Description of what this action does'
inputs:
  my-input:
    description: 'Description of the input'
    required: false
    default: 'default-value'
outputs:
  my-output:
    description: 'Description of the output'
    value: ${{ steps.step-id.outputs.output-name }}
runs:
  using: 'composite'
  steps:
    - name: Run a command
      id: step-id
      shell: bash
      run: |
        echo "output-name=value" >> $GITHUB_OUTPUT
```

## Benefits of Centralized Actions

- **Consistency**: Standardize workflows across all repositories
- **Maintainability**: Update actions in one place, benefit everywhere
- **Reusability**: Share common functionality across projects
- **Version Control**: Track changes and pin to specific versions

## Contributing

When adding new actions, ensure they:
- Have clear, descriptive names
- Include comprehensive documentation with a `## Description` section
- Follow GitHub Actions best practices
- Are tested before committing

## License

This repository is available for use in any project.
