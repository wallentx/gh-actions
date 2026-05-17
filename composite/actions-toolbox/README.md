# Actions Toolbox

## Description
🧰 Actions Toolbox is a composite GitHub Action designed to help with debugging, diagnostics, and tool management across various operating systems (Linux, macOS, Windows) in GitHub workflows. It performs tasks such as installing packages and tooling, identifying hardware specifications, identifying release/pre-release conditions, dumping contextual information, and setting or printing environment variables that can be used in subsequent steps, and providing rich environment and execution details for diagnostic purposes.

It aims to be a lightweight, flexible, and extensible tool that can be placed into any workflow without consuming more than a few seconds of execution time, and can provide a wealth of information if you ever need to debug, or supercharge the environment variables available to subsequent steps.

## Example

This is an example of how you can use this action in your workflow.
```yaml
on: [push]

# The GitHub CLI is used in this action to query the GitHub API for information that triggered the event
# It needs at _least_ the following permissions:
permissions:
  actions: read
  attestations: read
  checks: read
  contents: read
  deployments: read
  issues: read
  discussions: read
  packages: read
  pages: read
  pull-requests: read
  repository-projects: read
  statuses: read

jobs:
  build:
    runs-on: [self-hosted, linux]
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: 🧰 Actions Toolbox
        # This is required for the GitHub CLI
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        uses: wallentx/gh-actions/composite/actions-toolbox@main
        with:
          # Optional. Defaults to false. Set to true to enable verbose output of runner environment
          verbose: true
          # Optional. Defaults to false. Set to true only if this action should
          # perform its own checkout before collecting git metadata.
          checkout: false
          # Optional. Additional packages to install.
          # Supports multiple formats:
          #   - Simple package: foo
          #   - Package with version: foo=1.2.3
          #   - Command to package mapping: foo:bar
          #   - Command to package with version: foo:bar=1.2.3
          include-packages: |
            gcc
            cmake:build-essential
            make=4.3
            node:nodejs=18.19.1
            python3:python3-dev=3.8.10

      - name: Additional Example Step
        shell: bash
        run: |
          echo "example-build"
          bash example-build.sh
```

The expected result of this action running can be seen in the workflow outupt under the Actions Toolbox step. Here are a few samples of what data is provided from runs under different contexts:

<details>

<summary>Execution from a PR check</summary>

```bash
――――――――――――――――――――――
Set CPU_MODEL=AMD EPYC 7R13 Processor
Set CPU_CORES=8
Set CPU_THREADS=16
Set MEM_TOTAL=61.4214GB
――――――――――――――――――――――
CPU:
  Architecture: x86_64
  CPU op-mode(s): 32-bit, 64-bit
  Byte Order: Little Endian
  Address sizes: 48 bits physical, 48 bits virtual
  CPU(s): "16"
  On-line CPU(s) list: 0-15
  Thread(s) per core: "2"
  Core(s) per socket: "8"
  Socket(s): "1"
  NUMA node(s): "1"
  Vendor ID: AuthenticAMD
  CPU family: "25"
  Model: "1"
  Model name: AMD EPYC 7R13 Processor
  Stepping: "1"
  CPU MHz: "3588.906"
Flags:
  - 3dnowprefetch
  - abm
  - adx
  - aes
  - aperfmperf
  - apic
  - arat
  - avx
  - avx2
  - bmi1
  - bmi2
  - clflush
  - clflushopt
  - clwb
  - clzero
  - cmov
  - cmp_legacy
  - constant_tsc
  - cpuid
  - cr8_legacy
  - cx16
  - cx8
  - de
  - extd_apicid
  - f16c
  - fma
  - fpu
  - fsgsbase
  - fxsr
  - fxsr_opt
  - ht
  - hypervisor
  - ibpb
  - ibrs
  - invpcid
  - invpcid_single
  - lahf_lm
  - lm
  - mca
  - mce
  - misalignsse
  - mmx
  - mmxext
  - movbe
  - msr
  - mtrr
  - nonstop_tsc
  - nopl
  - npt
  - nrip_save
  - nx
  - pae
  - pat
  - pcid
  - pclmulqdq
  - pdpe1gb
  - pge
  - pni
  - popcnt
  - pse
  - pse36
  - rdpid
  - rdpru
  - rdrand
  - rdseed
  - rdtscp
  - rep_good
  - sep
  - sha_ni
  - smap
  - smep
  - ssbd
  - sse
  - sse2
  - sse4_1
  - sse4_2
  - sse4a
  - ssse3
  - stibp
  - syscall
  - topoext
  - tsc
  - tsc_known_freq
  - vaes
  - vme
  - vmmcall
  - vpclmulqdq
  - wbnoinvd
  - x2apic
  - xgetbv1
  - xsave
  - xsavec
  - xsaveerptr
  - xsaveopt
Virtualization features:
  Hypervisor vendor: KVM
  Virtualization type: full
Caches (sum of all):
  L1d: 256 KiB
  L1i: 256 KiB
  L2: 4 MiB
  L3: 32 MiB
NUMA:
  NUMA node(s): "1"
  NUMA node CPU(s): 0-15
Vulnerabilities:
  Vulnerability Gather data sampling:
    Status: Not Affected
  Vulnerability Itlb multihit:
    Status: Not Affected
  Vulnerability L1tf:
    Status: Not Affected
  Vulnerability Mds:
    Status: Not Affected
  Vulnerability Meltdown:
    Status: Not Affected
  Vulnerability Mmio stale data:
    Status: Not Affected
  Vulnerability Reg file data sampling:
    Status: Not Affected
  Vulnerability Retbleed:
    Status: Not Affected
  Vulnerability Spec rstack overflow:
    Status: Mitigated
    Mitigations:
      - safe RET
      - no microcode
  Vulnerability Spec store bypass:
    Status: Mitigated
    Mitigations:
      - Speculative Store Bypass disabled via prctl
  Vulnerability Spectre v1:
    Status: Mitigated
    Mitigations:
      - usercopy/swapgs barriers and __user pointer sanitization
  Vulnerability Spectre v2:
    Status: Mitigated
    Mitigations:
      - Retpolines
      - IBPB conditional
      - IBRS_FW
      - STIBP always-on
      - RSB filling
    Not Affected:
      - PBRSB-eIBRS
      - BHI
  Vulnerability Srbds:
    Status: Not Affected
  Vulnerability Tsx async abort:
    Status: Not Affected
――――――――――――――――――――――
Memory:
  MemTotal: 64404988 kB
  MemFree: 42322540 kB
  MemAvailable: 58773872 kB
  Buffers: 7100 kB
  Cached: 15858952 kB
  SwapCached: 0 kB
  Active: 4351136 kB
  Inactive: 15397460 kB
  Active(anon): 4240 kB
  Inactive(anon): 3885180 kB
  Active(file): 4346896 kB
  Inactive(file): 11512280 kB
  Unevictable: 36 kB
  Mlocked: 36 kB
  SwapTotal: 0 kB
  SwapFree: 0 kB
  Zswap: 0 kB
  Zswapped: 0 kB
  Dirty: 67944 kB
  Writeback: 0 kB
  AnonPages: 3882496 kB
  Mapped: 1847636 kB
  Shmem: 7140 kB
  KReclaimable: 1307324 kB
  Slab: 1861388 kB
  SReclaimable: 1307324 kB
  SUnreclaim: 554064 kB
  KernelStack: 28480 kB
  PageTables: 35932 kB
  SecPageTables: 0 kB
  NFS_Unstable: 0 kB
  Bounce: 0 kB
  WritebackTmp: 0 kB
  CommitLimit: 32202492 kB
  Committed_AS: 15630488 kB
  VmallocTotal: 34359738367 kB
  VmallocUsed: 60872 kB
  VmallocChunk: 0 kB
  Percpu: 37504 kB
  HardwareCorrupted: 0 kB
  AnonHugePages: 0 kB
  ShmemHugePages: 0 kB
  ShmemPmdMapped: 0 kB
  FileHugePages: 0 kB
  FilePmdMapped: 0 kB
  HugePages_Total: "0"
  HugePages_Free: "0"
  HugePages_Rsvd: "0"
  HugePages_Surp: "0"
  Hugepagesize: 2048 kB
  Hugetlb: 0 kB
  DirectMap4k: 1702320 kB
  DirectMap2M: 47194112 kB
  DirectMap1G: 16777216 kB
――――――――――――――――――――――
Run "${GITHUB_ACTION_PATH}/scripts/dump_contexts.sh"
――――――――――――――――――――――--
Dumping contexts:
――――――――――――――――――――――--
GITHUB:
  token: ***
  job: test
  ref: refs/heads/wallentx/trigger
  sha: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  repository: wallentx/sandbox
  repository_owner: wallentx
  repository_owner_id: "103681754"
  repositoryUrl: git://github.com/wallentx/sandbox.git
  run_id: "10820841667"
  run_number: "62"
  retention_days: "400"
  run_attempt: "7"
  artifact_cache_size_limit: "10"
  repository_visibility: internal
  repo-self-hosted-runners-disabled: false
  enterprise-managed-business-id: ""
  repository_id: "727383262"
  actor_id: "167472274"
  actor: wallentx
  triggering_actor: wallentx
  workflow: Testing context dump
  head_ref: ""
  base_ref: ""
  event_name: push
  event:
    after: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    base_ref: null
    before: 9ac284e0b2fdd36c14170e8d4fb1a938a7f2b022
    commits:
      - author:
          email: william.allen@wallentx.com
          name: William Allen
          username: wallentx
        committer:
          email: noreply@github.com
          name: GitHub
          username: web-flow
        distinct: true
        id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
        message: |-
          Update stats.yml

          Signed-off-by: William Allen <william.allen@wallentx.com>
        timestamp: "2024-09-11T17:48:22-05:00"
        tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
        url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    compare: https://github.com/wallentx/sandbox/compare/9ac284e0b2fd...b1c1a3051a00
    created: false
    deleted: false
    enterprise:
      avatar_url: https://avatars.githubusercontent.com/b/11660?v=4
      created_at: "2022-02-24T00:26:20Z"
      description: null
      html_url: https://github.com/enterprises/wallentx-emu
      id: 11660
      name: wallentx
      node_id: E_kgDNLYw
      slug: wallentx-emu
      updated_at: "2024-06-03T06:39:10Z"
      website_url: null
    forced: false
    head_commit:
      author:
        email: william.allen@wallentx.com
        name: William Allen
        username: wallentx
      committer:
        email: noreply@github.com
        name: GitHub
        username: web-flow
      distinct: true
      id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
      message: |-
        Update stats.yml

        Signed-off-by: William Allen <william.allen@wallentx.com>
      timestamp: "2024-09-11T17:48:22-05:00"
      tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
      url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    organization:
      avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
      description: Transform marketing with purchase intelligence through wallentx
      events_url: https://api.github.com/orgs/wallentx/events
      hooks_url: https://api.github.com/orgs/wallentx/hooks
      id: 103681754
      issues_url: https://api.github.com/orgs/wallentx/issues
      login: wallentx
      members_url: https://api.github.com/orgs/wallentx/members{/member}
      node_id: O_kgDOBi4O2g
      public_members_url: https://api.github.com/orgs/wallentx/public_members{/member}
      repos_url: https://api.github.com/orgs/wallentx/repos
      url: https://api.github.com/orgs/wallentx
    pusher:
      email: william.allen@wallentx.com
      name: wallentx
    ref: refs/heads/wallentx/trigger
    repository:
      allow_forking: true
      archive_url: https://api.github.com/repos/wallentx/sandbox/{archive_format}{/ref}
      archived: false
      assignees_url: https://api.github.com/repos/wallentx/sandbox/assignees{/user}
      blobs_url: https://api.github.com/repos/wallentx/sandbox/git/blobs{/sha}
      branches_url: https://api.github.com/repos/wallentx/sandbox/branches{/branch}
      clone_url: https://github.com/wallentx/sandbox.git
      collaborators_url: https://api.github.com/repos/wallentx/sandbox/collaborators{/collaborator}
      comments_url: https://api.github.com/repos/wallentx/sandbox/comments{/number}
      commits_url: https://api.github.com/repos/wallentx/sandbox/commits{/sha}
      compare_url: https://api.github.com/repos/wallentx/sandbox/compare/{base}...{head}
      contents_url: https://api.github.com/repos/wallentx/sandbox/contents/{+path}
      contributors_url: https://api.github.com/repos/wallentx/sandbox/contributors
      created_at: 1701716145
      custom_properties: {}
      default_branch: main
      deployments_url: https://api.github.com/repos/wallentx/sandbox/deployments
      description: Sandbox for platform to test with. Things like workflows, actions runners, terraform, whatever.
      disabled: false
      downloads_url: https://api.github.com/repos/wallentx/sandbox/downloads
      events_url: https://api.github.com/repos/wallentx/sandbox/events
      fork: false
      forks: 0
      forks_count: 0
      forks_url: https://api.github.com/repos/wallentx/sandbox/forks
      full_name: wallentx/sandbox
      git_commits_url: https://api.github.com/repos/wallentx/sandbox/git/commits{/sha}
      git_refs_url: https://api.github.com/repos/wallentx/sandbox/git/refs{/sha}
      git_tags_url: https://api.github.com/repos/wallentx/sandbox/git/tags{/sha}
      git_url: git://github.com/wallentx/sandbox.git
      has_discussions: false
      has_downloads: false
      has_issues: true
      has_pages: false
      has_projects: true
      has_wiki: true
      homepage: ""
      hooks_url: https://api.github.com/repos/wallentx/sandbox/hooks
      html_url: https://github.com/wallentx/sandbox
      id: 727383262
      is_template: false
      issue_comment_url: https://api.github.com/repos/wallentx/sandbox/issues/comments{/number}
      issue_events_url: https://api.github.com/repos/wallentx/sandbox/issues/events{/number}
      issues_url: https://api.github.com/repos/wallentx/sandbox/issues{/number}
      keys_url: https://api.github.com/repos/wallentx/sandbox/keys{/key_id}
      labels_url: https://api.github.com/repos/wallentx/sandbox/labels{/name}
      language: null
      languages_url: https://api.github.com/repos/wallentx/sandbox/languages
      license: null
      master_branch: main
      merges_url: https://api.github.com/repos/wallentx/sandbox/merges
      milestones_url: https://api.github.com/repos/wallentx/sandbox/milestones{/number}
      mirror_url: null
      name: sandbox
      node_id: R_kgDOK1r83g
      notifications_url: https://api.github.com/repos/wallentx/sandbox/notifications{?since,all,participating}
      open_issues: 2
      open_issues_count: 2
      organization: wallentx
      owner:
        avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
        email: null
        events_url: https://api.github.com/users/wallentx/events{/privacy}
        followers_url: https://api.github.com/users/wallentx/followers
        following_url: https://api.github.com/users/wallentx/following{/other_user}
        gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
        gravatar_id: ""
        html_url: https://github.com/wallentx
        id: 103681754
        login: wallentx
        name: wallentx
        node_id: O_kgDOBi4O2g
        organizations_url: https://api.github.com/users/wallentx/orgs
        received_events_url: https://api.github.com/users/wallentx/received_events
        repos_url: https://api.github.com/users/wallentx/repos
        site_admin: false
        starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
        subscriptions_url: https://api.github.com/users/wallentx/subscriptions
        type: Organization
        url: https://api.github.com/users/wallentx
      private: true
      pulls_url: https://api.github.com/repos/wallentx/sandbox/pulls{/number}
      pushed_at: 1726094902
      releases_url: https://api.github.com/repos/wallentx/sandbox/releases{/id}
      size: 150
      ssh_url: git@github.com:wallentx/sandbox.git
      stargazers: 0
      stargazers_count: 0
      stargazers_url: https://api.github.com/repos/wallentx/sandbox/stargazers
      statuses_url: https://api.github.com/repos/wallentx/sandbox/statuses/{sha}
      subscribers_url: https://api.github.com/repos/wallentx/sandbox/subscribers
      subscription_url: https://api.github.com/repos/wallentx/sandbox/subscription
      svn_url: https://github.com/wallentx/sandbox
      tags_url: https://api.github.com/repos/wallentx/sandbox/tags
      teams_url: https://api.github.com/repos/wallentx/sandbox/teams
      topics:
        - devops
        - platform
        - sre
      trees_url: https://api.github.com/repos/wallentx/sandbox/git/trees{/sha}
      updated_at: "2024-09-05T17:26:38Z"
      url: https://github.com/wallentx/sandbox
      visibility: internal
      watchers: 0
      watchers_count: 0
      web_commit_signoff_required: true
    sender:
      avatar_url: https://avatars.githubusercontent.com/u/167472274?v=4
      events_url: https://api.github.com/users/wallentx/events{/privacy}
      followers_url: https://api.github.com/users/wallentx/followers
      following_url: https://api.github.com/users/wallentx/following{/other_user}
      gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
      gravatar_id: ""
      html_url: https://github.com/wallentx
      id: 167472274
      login: wallentx
      node_id: U_kgDOCftskg
      organizations_url: https://api.github.com/users/wallentx/orgs
      received_events_url: https://api.github.com/users/wallentx/received_events
      repos_url: https://api.github.com/users/wallentx/repos
      site_admin: false
      starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
      subscriptions_url: https://api.github.com/users/wallentx/subscriptions
      type: User
      url: https://api.github.com/users/wallentx
  server_url: https://github.com
  api_url: https://api.github.com
  graphql_url: https://api.github.com/graphql
  ref_name: wallentx/trigger
  ref_protected: false
  ref_type: branch
  secret_source: Actions
  workflow_ref: wallentx/sandbox/.github/workflows/stats.yml@refs/heads/wallentx/trigger
  workflow_sha: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  workspace: /runner/_work/sandbox/sandbox
  event_path: /runner/_work/_temp/_github_workflow/event.json
  path: /runner/_work/_temp/_runner_file_commands/add_path_7cad6067-2a2a-4e01-971e-441a5156d89b
  env: /runner/_work/_temp/_runner_file_commands/set_env_7cad6067-2a2a-4e01-971e-441a5156d89b
  step_summary: /runner/_work/_temp/_runner_file_commands/step_summary_7cad6067-2a2a-4e01-971e-441a5156d89b
  state: /runner/_work/_temp/_runner_file_commands/save_state_7cad6067-2a2a-4e01-971e-441a5156d89b
  output: /runner/_work/_temp/_runner_file_commands/set_output_7cad6067-2a2a-4e01-971e-441a5156d89b
  action: __wallentx_github-workflows
  action_repository: wallentx/github-workflows
  action_ref: wallentx/gh-actions/composite/actions-toolbox
  action_path: /runner/_work/_actions/wallentx/github-workflows/wallentx/gh-actions/composite/actions-toolbox/actions/actions-toolbox
  action_status: success
ENV:
  INITIAL_RX_BYTES: "1319506"
  INITIAL_TX_BYTES: "179088"
  RUNNER_VERBOSE: "1"
  CPU_MODEL: AMD EPYC 7R13 Processor
  CPU_CORES: "8"
  CPU_THREADS: "16"
  MEM_TOTAL: 61.4214GB
  GH_TOKEN: ***
JOB:
  status: success
STEPS: {}
RUNNER:
  os: Linux
  arch: X64
  name: eks-ubuntu-prod-us-east-1-cl4dl-s7jxw
  environment: self-hosted
  tool_cache: /opt/hostedtoolcache
  temp: /runner/_work/_temp
  workspace: /runner/_work/sandbox
STRATEGY:
  fail-fast: true
  job-index: 0
  job-total: 1
  max-parallel: 1
MATRIX: null
INPUTS:
  verbose: "true"
――――――――――――――――――――――--
Run jq '.' "$GITHUB_EVENT_PATH" | yq -pj -oy -C -P
after: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
base_ref: null
before: 9ac284e0b2fdd36c14170e8d4fb1a938a7f2b022
commits:
  - author:
      email: william.allen@wallentx.com
      name: William Allen
      username: wallentx
    committer:
      email: noreply@github.com
      name: GitHub
      username: web-flow
    distinct: true
    id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    message: |-
      Update stats.yml

      Signed-off-by: William Allen <william.allen@wallentx.com>
    timestamp: "2024-09-11T17:48:22-05:00"
    tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
    url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
compare: https://github.com/wallentx/sandbox/compare/9ac284e0b2fd...b1c1a3051a00
created: false
deleted: false
enterprise:
  avatar_url: https://avatars.githubusercontent.com/b/11660?v=4
  created_at: "2022-02-24T00:26:20Z"
  description: null
  html_url: https://github.com/enterprises/wallentx-emu
  id: 11660
  name: wallentx
  node_id: E_kgDNLYw
  slug: wallentx-emu
  updated_at: "2024-06-03T06:39:10Z"
  website_url: null
forced: false
head_commit:
  author:
    email: william.allen@wallentx.com
    name: William Allen
    username: wallentx
  committer:
    email: noreply@github.com
    name: GitHub
    username: web-flow
  distinct: true
  id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  message: |-
    Update stats.yml

    Signed-off-by: William Allen <william.allen@wallentx.com>
  timestamp: "2024-09-11T17:48:22-05:00"
  tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
  url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
organization:
  avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
  description: Transform marketing with purchase intelligence through wallentx
  events_url: https://api.github.com/orgs/wallentx/events
  hooks_url: https://api.github.com/orgs/wallentx/hooks
  id: 103681754
  issues_url: https://api.github.com/orgs/wallentx/issues
  login: wallentx
  members_url: https://api.github.com/orgs/wallentx/members{/member}
  node_id: O_kgDOBi4O2g
  public_members_url: https://api.github.com/orgs/wallentx/public_members{/member}
  repos_url: https://api.github.com/orgs/wallentx/repos
  url: https://api.github.com/orgs/wallentx
pusher:
  email: william.allen@wallentx.com
  name: wallentx
ref: refs/heads/wallentx/trigger
repository:
  allow_forking: true
  archive_url: https://api.github.com/repos/wallentx/sandbox/{archive_format}{/ref}
  archived: false
  assignees_url: https://api.github.com/repos/wallentx/sandbox/assignees{/user}
  blobs_url: https://api.github.com/repos/wallentx/sandbox/git/blobs{/sha}
  branches_url: https://api.github.com/repos/wallentx/sandbox/branches{/branch}
  clone_url: https://github.com/wallentx/sandbox.git
  collaborators_url: https://api.github.com/repos/wallentx/sandbox/collaborators{/collaborator}
  comments_url: https://api.github.com/repos/wallentx/sandbox/comments{/number}
  commits_url: https://api.github.com/repos/wallentx/sandbox/commits{/sha}
  compare_url: https://api.github.com/repos/wallentx/sandbox/compare/{base}...{head}
  contents_url: https://api.github.com/repos/wallentx/sandbox/contents/{+path}
  contributors_url: https://api.github.com/repos/wallentx/sandbox/contributors
  created_at: 1701716145
  custom_properties: {}
  default_branch: main
  deployments_url: https://api.github.com/repos/wallentx/sandbox/deployments
  description: Sandbox for platform to test with. Things like workflows, actions runners, terraform, whatever.
  disabled: false
  downloads_url: https://api.github.com/repos/wallentx/sandbox/downloads
  events_url: https://api.github.com/repos/wallentx/sandbox/events
  fork: false
  forks: 0
  forks_count: 0
  forks_url: https://api.github.com/repos/wallentx/sandbox/forks
  full_name: wallentx/sandbox
  git_commits_url: https://api.github.com/repos/wallentx/sandbox/git/commits{/sha}
  git_refs_url: https://api.github.com/repos/wallentx/sandbox/git/refs{/sha}
  git_tags_url: https://api.github.com/repos/wallentx/sandbox/git/tags{/sha}
  git_url: git://github.com/wallentx/sandbox.git
  has_discussions: false
  has_downloads: false
  has_issues: true
  has_pages: false
  has_projects: true
  has_wiki: true
  homepage: ""
  hooks_url: https://api.github.com/repos/wallentx/sandbox/hooks
  html_url: https://github.com/wallentx/sandbox
  id: 727383262
  is_template: false
  issue_comment_url: https://api.github.com/repos/wallentx/sandbox/issues/comments{/number}
  issue_events_url: https://api.github.com/repos/wallentx/sandbox/issues/events{/number}
  issues_url: https://api.github.com/repos/wallentx/sandbox/issues{/number}
  keys_url: https://api.github.com/repos/wallentx/sandbox/keys{/key_id}
  labels_url: https://api.github.com/repos/wallentx/sandbox/labels{/name}
  language: null
  languages_url: https://api.github.com/repos/wallentx/sandbox/languages
  license: null
  master_branch: main
  merges_url: https://api.github.com/repos/wallentx/sandbox/merges
  milestones_url: https://api.github.com/repos/wallentx/sandbox/milestones{/number}
  mirror_url: null
  name: sandbox
  node_id: R_kgDOK1r83g
  notifications_url: https://api.github.com/repos/wallentx/sandbox/notifications{?since,all,participating}
  open_issues: 2
  open_issues_count: 2
  organization: wallentx
  owner:
    avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
    email: null
    events_url: https://api.github.com/users/wallentx/events{/privacy}
    followers_url: https://api.github.com/users/wallentx/followers
    following_url: https://api.github.com/users/wallentx/following{/other_user}
    gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
    gravatar_id: ""
    html_url: https://github.com/wallentx
    id: 103681754
    login: wallentx
    name: wallentx
    node_id: O_kgDOBi4O2g
    organizations_url: https://api.github.com/users/wallentx/orgs
    received_events_url: https://api.github.com/users/wallentx/received_events
    repos_url: https://api.github.com/users/wallentx/repos
    site_admin: false
    starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
    subscriptions_url: https://api.github.com/users/wallentx/subscriptions
    type: Organization
    url: https://api.github.com/users/wallentx
  private: true
  pulls_url: https://api.github.com/repos/wallentx/sandbox/pulls{/number}
  pushed_at: 1726094902
  releases_url: https://api.github.com/repos/wallentx/sandbox/releases{/id}
  size: 150
  ssh_url: git@github.com:wallentx/sandbox.git
  stargazers: 0
  stargazers_count: 0
  stargazers_url: https://api.github.com/repos/wallentx/sandbox/stargazers
  statuses_url: https://api.github.com/repos/wallentx/sandbox/statuses/{sha}
  subscribers_url: https://api.github.com/repos/wallentx/sandbox/subscribers
  subscription_url: https://api.github.com/repos/wallentx/sandbox/subscription
  svn_url: https://github.com/wallentx/sandbox
  tags_url: https://api.github.com/repos/wallentx/sandbox/tags
  teams_url: https://api.github.com/repos/wallentx/sandbox/teams
  topics:
    - devops
    - platform
    - sre
  trees_url: https://api.github.com/repos/wallentx/sandbox/git/trees{/sha}
  updated_at: "2024-09-05T17:26:38Z"
  url: https://github.com/wallentx/sandbox
  visibility: internal
  watchers: 0
  watchers_count: 0
  web_commit_signoff_required: true
sender:
  avatar_url: https://avatars.githubusercontent.com/u/167472274?v=4
  events_url: https://api.github.com/users/wallentx/events{/privacy}
  followers_url: https://api.github.com/users/wallentx/followers
  following_url: https://api.github.com/users/wallentx/following{/other_user}
  gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
  gravatar_id: ""
  html_url: https://github.com/wallentx
  id: 167472274
  login: wallentx
  node_id: U_kgDOCftskg
  organizations_url: https://api.github.com/users/wallentx/orgs
  received_events_url: https://api.github.com/users/wallentx/received_events
  repos_url: https://api.github.com/users/wallentx/repos
  site_admin: false
  starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
  subscriptions_url: https://api.github.com/users/wallentx/subscriptions
  type: User
  url: https://api.github.com/users/wallentx
Run echo "――――――――――――――――――――――"
――――――――――――――――――――――
Runner native job envs:
――――――――――――――――――――――
ACTIONS_RUNNER_HOOK_JOB_COMPLETED: /etc/arc/hooks/job-completed.sh
ACTIONS_RUNNER_HOOK_JOB_STARTED: /etc/arc/hooks/job-started.sh
CI: "true"
CPU_CORES: "8"
CPU_MODEL: AMD EPYC 7R13 Processor
CPU_THREADS: "16"
DD_AGENT_HOST: 10.160.172.183
DD_ENTITY_ID: d0896eee-3ce5-4673-9f4e-0768eb7506af
DD_INSTRUMENTATION_INSTALL_ID: df02ee17-508f-4917-8eb5-068644e1361c
DD_INSTRUMENTATION_INSTALL_TIME: "1723588024"
DEBIAN_FRONTEND: noninteractive
DOCKERD_IN_RUNNER: "true"
DOCKER_ENABLED: "true"
DOCKER_REGISTRY_MIRROR: https://mirror.gcr.io
GH_TOKEN: ***
GITHUB_ACTION: __wallentx_github-workflows
GITHUB_ACTIONS: "true"
GITHUB_ACTIONS_RUNNER_EXTRA_USER_AGENT: actions-runner-controller/v0.27.6
GITHUB_ACTION_PATH: /runner/_work/_actions/wallentx/github-workflows/wallentx/gh-actions/composite/actions-toolbox/actions/actions-toolbox
GITHUB_ACTION_REF: ""
GITHUB_ACTION_REPOSITORY: ""
GITHUB_ACTOR: wallentx
GITHUB_ACTOR_ID: "167472274"
GITHUB_API_URL: https://api.github.com
GITHUB_BASE_REF: ""
GITHUB_ENV: /runner/_work/_temp/_runner_file_commands/set_env_f950c258-1121-43f0-9bbe-8958af630441
GITHUB_EVENT_NAME: push
GITHUB_EVENT_PATH: /runner/_work/_temp/_github_workflow/event.json
GITHUB_GRAPHQL_URL: https://api.github.com/graphql
GITHUB_HEAD_REF: ""
GITHUB_JOB: test
GITHUB_OUTPUT: /runner/_work/_temp/_runner_file_commands/set_output_f950c258-1121-43f0-9bbe-8958af630441
GITHUB_PATH: /runner/_work/_temp/_runner_file_commands/add_path_f950c258-1121-43f0-9bbe-8958af630441
GITHUB_REF: refs/heads/wallentx/trigger
GITHUB_REF_NAME: wallentx/trigger
GITHUB_REF_PROTECTED: "false"
GITHUB_REF_TYPE: branch
GITHUB_REPOSITORY: wallentx/sandbox
GITHUB_REPOSITORY_ID: "727383262"
GITHUB_REPOSITORY_OWNER: wallentx
GITHUB_REPOSITORY_OWNER_ID: "103681754"
GITHUB_RETENTION_DAYS: "400"
GITHUB_RUN_ATTEMPT: "7"
GITHUB_RUN_ID: "10820841667"
GITHUB_RUN_NUMBER: "62"
GITHUB_SERVER_URL: https://github.com
GITHUB_SHA: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GITHUB_STATE: /runner/_work/_temp/_runner_file_commands/save_state_f950c258-1121-43f0-9bbe-8958af630441
GITHUB_STEP_SUMMARY: /runner/_work/_temp/_runner_file_commands/step_summary_f950c258-1121-43f0-9bbe-8958af630441
GITHUB_TRIGGERING_ACTOR: wallentx
GITHUB_URL: https://github.com/
GITHUB_WORKFLOW: Testing context dump
GITHUB_WORKFLOW_REF: wallentx/sandbox/.github/workflows/stats.yml@refs/heads/wallentx/trigger
GITHUB_WORKFLOW_SHA: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GITHUB_WORKSPACE: /runner/_work/sandbox/sandbox
HOME: /home/runner
HOSTNAME: eks-ubuntu-prod-us-east-1-cl4dl-s7jxw
INITIAL_RX_BYTES: "1319506"
INITIAL_TX_BYTES: "179088"
ImageOS: ubuntu20
KUBERNETES_PORT: tcp://172.20.0.1:443
KUBERNETES_PORT_443_TCP: tcp://172.20.0.1:443
KUBERNETES_PORT_443_TCP_ADDR: 172.20.0.1
KUBERNETES_PORT_443_TCP_PORT: "443"
KUBERNETES_PORT_443_TCP_PROTO: tcp
KUBERNETES_SERVICE_HOST: 172.20.0.1
KUBERNETES_SERVICE_PORT: "443"
KUBERNETES_SERVICE_PORT_HTTPS: "443"
MEM_TOTAL: 61.4214GB
OLDPWD: /
PATH: /opt/hostedtoolcache/gh-cli/v2.56.0/linux_amd64:/opt/hostedtoolcache/yq/v4.44.3/linux_amd64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/runner/.local/bin
PWD: /runner/_work/sandbox/sandbox
RUNNER_ARCH: X64
RUNNER_ASSETS_DIR: /runnertmp
RUNNER_ENTERPRISE: ""
RUNNER_ENVIRONMENT: self-hosted
RUNNER_EPHEMERAL: "true"
RUNNER_GRACEFUL_STOP_TIMEOUT: "14330"
RUNNER_GROUP: eks-prod-us-east-1
RUNNER_LABELS: k8s,code-scanning,dependabot,prod,us-east-1
RUNNER_NAME: eks-ubuntu-prod-us-east-1-cl4dl-s7jxw
RUNNER_ORG: wallentx
RUNNER_OS: Linux
RUNNER_STATUS_UPDATE_HOOK: "false"
RUNNER_TEMP: /runner/_work/_temp
RUNNER_TOOL_CACHE: /opt/hostedtoolcache
RUNNER_TRACKING_ID: github_b91081e5-eac4-4da0-90e6-aa57bf365e05
RUNNER_VERBOSE: "1"
RUNNER_WORKDIR: /runner/_work
RUNNER_WORKSPACE: /runner/_work/sandbox
SHLVL: "3"
_: /usr/bin/env
――――――――――――――――――――――
Setting env for steps:
――――――――――――――――――――――
GH_EVENT_ACTION: "null"
REPO: sandbox
RFC_REPO: sandbox
GIT_SHORT_HASH: b1c1a305
GH_WORKFLOW_URL: https://github.com/wallentx/sandbox/actions/runs/10820841667
GPR_PROJECT: ghcr.io/wallentx/sandbox
GH_DEFAULT_BRANCH: main
GH_PR: "22"
GH_PR_TITLE: "Add env diagnostics for pull request context"
GH_PR_BODY: "This PR updates the workflow diagnostics output."
GH_PR_AUTHOR: wallentx
GH_PR_MERGED: ""
GH_PR_COMMENTS: '[{"login":"wallentx","url":"https://github.com/wallentx/sandbox/pull/22#issuecomment-2344807031"},{"login":"linus_torvalds","url":"https://github.com/wallentx/sandbox/pull/22#issuecomment-2344839554"}]'
GH_PR_URL: https://github.com/wallentx/sandbox/pull/22
GH_PR_CREATED_AT: "2024-09-11T22:17:06Z"
GH_PR_FIRST_APPROVAL_AT: "2024-09-11T22:52:57Z"
GH_PR_LAST_APPROVAL_AT: ""
GH_PR_TIME_FIRST_APPROVAL: 35 minutes 51 seconds
GH_COMMIT_URL: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GH_REPO_URL: https://github.com/wallentx/sandbox
――――――――――――――――――――――
Complete
――――――――――――――――――――――
```

> Note: `GH_PR_BODY` is exported as a single-line JSON string (newlines are escaped). Decode with `jq -r '.'` if raw text is needed.

</details>


<details>

<summary>Executed from a merged PR</summary>

```bash
――――――――――――――――――――――
Set CPU_MODEL=AMD EPYC 7R13 Processor
Set CPU_CORES=16
Set CPU_THREADS=32
Set MEM_TOTAL=123.166GB
――――――――――――――――――――――
CPU:
  Architecture: x86_64
  CPU op-mode(s): 32-bit, 64-bit
  Byte Order: Little Endian
  Address sizes: 48 bits physical, 48 bits virtual
  CPU(s): "32"
  On-line CPU(s) list: 0-31
  Thread(s) per core: "2"
  Core(s) per socket: "16"
  Socket(s): "1"
  NUMA node(s): "2"
  Vendor ID: AuthenticAMD
  CPU family: "25"
  Model: "1"
  Model name: AMD EPYC 7R13 Processor
  Stepping: "1"
  CPU MHz: "3599.591"
Flags:
  - 3dnowprefetch
  - abm
  - adx
  - aes
  - aperfmperf
  - apic
  - arat
  - avx
  - avx2
  - bmi1
  - bmi2
  - clflush
  - clflushopt
  - clwb
  - clzero
  - cmov
  - cmp_legacy
  - constant_tsc
  - cpuid
  - cr8_legacy
  - cx16
  - cx8
  - de
  - extd_apicid
  - f16c
  - fma
  - fpu
  - fsgsbase
  - fxsr
  - fxsr_opt
  - ht
  - hypervisor
  - ibpb
  - ibrs
  - invpcid
  - invpcid_single
  - lahf_lm
  - lm
  - mca
  - mce
  - misalignsse
  - mmx
  - mmxext
  - movbe
  - msr
  - mtrr
  - nonstop_tsc
  - nopl
  - npt
  - nrip_save
  - nx
  - pae
  - pat
  - pcid
  - pclmulqdq
  - pdpe1gb
  - pge
  - pni
  - popcnt
  - pse
  - pse36
  - rdpid
  - rdpru
  - rdrand
  - rdseed
  - rdtscp
  - rep_good
  - sep
  - sha_ni
  - smap
  - smep
  - ssbd
  - sse
  - sse2
  - sse4_1
  - sse4_2
  - sse4a
  - ssse3
  - stibp
  - syscall
  - topoext
  - tsc
  - tsc_known_freq
  - vaes
  - vme
  - vmmcall
  - vpclmulqdq
  - wbnoinvd
  - x2apic
  - xgetbv1
  - xsave
  - xsavec
  - xsaveerptr
  - xsaveopt
Virtualization features:
  Hypervisor vendor: KVM
  Virtualization type: full
Caches (sum of all):
  L1d: 512 KiB
  L1i: 512 KiB
  L2: 8 MiB
  L3: 64 MiB
NUMA:
  NUMA node(s): "2"
  NUMA node CPU(s): 8-15,24-31
Vulnerabilities:
  Vulnerability Gather data sampling:
    Status: Not Affected
  Vulnerability Itlb multihit:
    Status: Not Affected
  Vulnerability L1tf:
    Status: Not Affected
  Vulnerability Mds:
    Status: Not Affected
  Vulnerability Meltdown:
    Status: Not Affected
  Vulnerability Mmio stale data:
    Status: Not Affected
  Vulnerability Reg file data sampling:
    Status: Not Affected
  Vulnerability Retbleed:
    Status: Not Affected
  Vulnerability Spec rstack overflow:
    Status: Mitigated
    Mitigations:
      - safe RET
      - no microcode
  Vulnerability Spec store bypass:
    Status: Mitigated
    Mitigations:
      - Speculative Store Bypass disabled via prctl
  Vulnerability Spectre v1:
    Status: Mitigated
    Mitigations:
      - usercopy/swapgs barriers and __user pointer sanitization
  Vulnerability Spectre v2:
    Status: Mitigated
    Mitigations:
      - Retpolines
      - IBPB conditional
      - IBRS_FW
      - STIBP always-on
      - RSB filling
    Not Affected:
      - PBRSB-eIBRS
      - BHI
  Vulnerability Srbds:
    Status: Not Affected
  Vulnerability Tsx async abort:
    Status: Not Affected
――――――――――――――――――――――
Memory:
  MemTotal: 129148436 kB
  MemFree: 79593876 kB
  MemAvailable: 115704144 kB
  Buffers: 8268 kB
  Cached: 35788416 kB
  SwapCached: 0 kB
  Active: 5113520 kB
  Inactive: 41276308 kB
  Active(anon): 2772 kB
  Inactive(anon): 10594076 kB
  Active(file): 5110748 kB
  Inactive(file): 30682232 kB
  Unevictable: 24 kB
  Mlocked: 24 kB
  SwapTotal: 0 kB
  SwapFree: 0 kB
  Zswap: 0 kB
  Zswapped: 0 kB
  Dirty: 73252 kB
  Writeback: 9656 kB
  AnonPages: 10592932 kB
  Mapped: 1448720 kB
  Shmem: 3980 kB
  KReclaimable: 1359688 kB
  Slab: 2267800 kB
  SReclaimable: 1359688 kB
  SUnreclaim: 908112 kB
  KernelStack: 42208 kB
  PageTables: 54204 kB
  SecPageTables: 0 kB
  NFS_Unstable: 0 kB
  Bounce: 0 kB
  WritebackTmp: 0 kB
  CommitLimit: 64574216 kB
  Committed_AS: 22786584 kB
  VmallocTotal: 34359738367 kB
  VmallocUsed: 195252 kB
  VmallocChunk: 0 kB
  Percpu: 56832 kB
  HardwareCorrupted: 0 kB
  AnonHugePages: 2048 kB
  ShmemHugePages: 0 kB
  ShmemPmdMapped: 0 kB
  FileHugePages: 0 kB
  FilePmdMapped: 0 kB
  HugePages_Total: "0"
  HugePages_Free: "0"
  HugePages_Rsvd: "0"
  HugePages_Surp: "0"
  Hugepagesize: 2048 kB
  Hugetlb: 0 kB
  DirectMap4k: 330160 kB
  DirectMap2M: 17774592 kB
  DirectMap1G: 113246208 kB
――――――――――――――――――――――
Run "${GITHUB_ACTION_PATH}/scripts/dump_contexts.sh"
――――――――――――――――――――――--
Dumping contexts:
――――――――――――――――――――――--
GITHUB:
  token: ***
  job: test
  ref: refs/heads/wallentx/trigger
  sha: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  repository: wallentx/sandbox
  repository_owner: wallentx
  repository_owner_id: "103681754"
  repositoryUrl: git://github.com/wallentx/sandbox.git
  run_id: "10820841667"
  run_number: "62"
  retention_days: "400"
  run_attempt: "8"
  artifact_cache_size_limit: "10"
  repository_visibility: internal
  repo-self-hosted-runners-disabled: false
  enterprise-managed-business-id: ""
  repository_id: "727383262"
  actor_id: "167472274"
  actor: wallentx
  triggering_actor: wallentx
  workflow: Testing context dump
  head_ref: ""
  base_ref: ""
  event_name: push
  event:
    after: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    base_ref: null
    before: 9ac284e0b2fdd36c14170e8d4fb1a938a7f2b022
    commits:
      - author:
          email: william.allen@wallentx.com
          name: William Allen
          username: wallentx
        committer:
          email: noreply@github.com
          name: GitHub
          username: web-flow
        distinct: true
        id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
        message: |-
          Update stats.yml

          Signed-off-by: William Allen <william.allen@wallentx.com>
        timestamp: "2024-09-11T17:48:22-05:00"
        tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
        url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    compare: https://github.com/wallentx/sandbox/compare/9ac284e0b2fd...b1c1a3051a00
    created: false
    deleted: false
    enterprise:
      avatar_url: https://avatars.githubusercontent.com/b/11660?v=4
      created_at: "2022-02-24T00:26:20Z"
      description: null
      html_url: https://github.com/enterprises/wallentx-emu
      id: 11660
      name: wallentx
      node_id: E_kgDNLYw
      slug: wallentx-emu
      updated_at: "2024-06-03T06:39:10Z"
      website_url: null
    forced: false
    head_commit:
      author:
        email: william.allen@wallentx.com
        name: William Allen
        username: wallentx
      committer:
        email: noreply@github.com
        name: GitHub
        username: web-flow
      distinct: true
      id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
      message: |-
        Update stats.yml

        Signed-off-by: William Allen <william.allen@wallentx.com>
      timestamp: "2024-09-11T17:48:22-05:00"
      tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
      url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    organization:
      avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
      description: Transform marketing with purchase intelligence through wallentx
      events_url: https://api.github.com/orgs/wallentx/events
      hooks_url: https://api.github.com/orgs/wallentx/hooks
      id: 103681754
      issues_url: https://api.github.com/orgs/wallentx/issues
      login: wallentx
      members_url: https://api.github.com/orgs/wallentx/members{/member}
      node_id: O_kgDOBi4O2g
      public_members_url: https://api.github.com/orgs/wallentx/public_members{/member}
      repos_url: https://api.github.com/orgs/wallentx/repos
      url: https://api.github.com/orgs/wallentx
    pusher:
      email: william.allen@wallentx.com
      name: wallentx
    ref: refs/heads/wallentx/trigger
    repository:
      allow_forking: true
      archive_url: https://api.github.com/repos/wallentx/sandbox/{archive_format}{/ref}
      archived: false
      assignees_url: https://api.github.com/repos/wallentx/sandbox/assignees{/user}
      blobs_url: https://api.github.com/repos/wallentx/sandbox/git/blobs{/sha}
      branches_url: https://api.github.com/repos/wallentx/sandbox/branches{/branch}
      clone_url: https://github.com/wallentx/sandbox.git
      collaborators_url: https://api.github.com/repos/wallentx/sandbox/collaborators{/collaborator}
      comments_url: https://api.github.com/repos/wallentx/sandbox/comments{/number}
      commits_url: https://api.github.com/repos/wallentx/sandbox/commits{/sha}
      compare_url: https://api.github.com/repos/wallentx/sandbox/compare/{base}...{head}
      contents_url: https://api.github.com/repos/wallentx/sandbox/contents/{+path}
      contributors_url: https://api.github.com/repos/wallentx/sandbox/contributors
      created_at: 1701716145
      custom_properties: {}
      default_branch: main
      deployments_url: https://api.github.com/repos/wallentx/sandbox/deployments
      description: Sandbox for platform to test with. Things like workflows, actions runners, terraform, whatever.
      disabled: false
      downloads_url: https://api.github.com/repos/wallentx/sandbox/downloads
      events_url: https://api.github.com/repos/wallentx/sandbox/events
      fork: false
      forks: 0
      forks_count: 0
      forks_url: https://api.github.com/repos/wallentx/sandbox/forks
      full_name: wallentx/sandbox
      git_commits_url: https://api.github.com/repos/wallentx/sandbox/git/commits{/sha}
      git_refs_url: https://api.github.com/repos/wallentx/sandbox/git/refs{/sha}
      git_tags_url: https://api.github.com/repos/wallentx/sandbox/git/tags{/sha}
      git_url: git://github.com/wallentx/sandbox.git
      has_discussions: false
      has_downloads: false
      has_issues: true
      has_pages: false
      has_projects: true
      has_wiki: true
      homepage: ""
      hooks_url: https://api.github.com/repos/wallentx/sandbox/hooks
      html_url: https://github.com/wallentx/sandbox
      id: 727383262
      is_template: false
      issue_comment_url: https://api.github.com/repos/wallentx/sandbox/issues/comments{/number}
      issue_events_url: https://api.github.com/repos/wallentx/sandbox/issues/events{/number}
      issues_url: https://api.github.com/repos/wallentx/sandbox/issues{/number}
      keys_url: https://api.github.com/repos/wallentx/sandbox/keys{/key_id}
      labels_url: https://api.github.com/repos/wallentx/sandbox/labels{/name}
      language: null
      languages_url: https://api.github.com/repos/wallentx/sandbox/languages
      license: null
      master_branch: main
      merges_url: https://api.github.com/repos/wallentx/sandbox/merges
      milestones_url: https://api.github.com/repos/wallentx/sandbox/milestones{/number}
      mirror_url: null
      name: sandbox
      node_id: R_kgDOK1r83g
      notifications_url: https://api.github.com/repos/wallentx/sandbox/notifications{?since,all,participating}
      open_issues: 2
      open_issues_count: 2
      organization: wallentx
      owner:
        avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
        email: null
        events_url: https://api.github.com/users/wallentx/events{/privacy}
        followers_url: https://api.github.com/users/wallentx/followers
        following_url: https://api.github.com/users/wallentx/following{/other_user}
        gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
        gravatar_id: ""
        html_url: https://github.com/wallentx
        id: 103681754
        login: wallentx
        name: wallentx
        node_id: O_kgDOBi4O2g
        organizations_url: https://api.github.com/users/wallentx/orgs
        received_events_url: https://api.github.com/users/wallentx/received_events
        repos_url: https://api.github.com/users/wallentx/repos
        site_admin: false
        starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
        subscriptions_url: https://api.github.com/users/wallentx/subscriptions
        type: Organization
        url: https://api.github.com/users/wallentx
      private: true
      pulls_url: https://api.github.com/repos/wallentx/sandbox/pulls{/number}
      pushed_at: 1726094902
      releases_url: https://api.github.com/repos/wallentx/sandbox/releases{/id}
      size: 150
      ssh_url: git@github.com:wallentx/sandbox.git
      stargazers: 0
      stargazers_count: 0
      stargazers_url: https://api.github.com/repos/wallentx/sandbox/stargazers
      statuses_url: https://api.github.com/repos/wallentx/sandbox/statuses/{sha}
      subscribers_url: https://api.github.com/repos/wallentx/sandbox/subscribers
      subscription_url: https://api.github.com/repos/wallentx/sandbox/subscription
      svn_url: https://github.com/wallentx/sandbox
      tags_url: https://api.github.com/repos/wallentx/sandbox/tags
      teams_url: https://api.github.com/repos/wallentx/sandbox/teams
      topics:
        - devops
        - platform
        - sre
      trees_url: https://api.github.com/repos/wallentx/sandbox/git/trees{/sha}
      updated_at: "2024-09-05T17:26:38Z"
      url: https://github.com/wallentx/sandbox
      visibility: internal
      watchers: 0
      watchers_count: 0
      web_commit_signoff_required: true
    sender:
      avatar_url: https://avatars.githubusercontent.com/u/167472274?v=4
      events_url: https://api.github.com/users/wallentx/events{/privacy}
      followers_url: https://api.github.com/users/wallentx/followers
      following_url: https://api.github.com/users/wallentx/following{/other_user}
      gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
      gravatar_id: ""
      html_url: https://github.com/wallentx
      id: 167472274
      login: wallentx
      node_id: U_kgDOCftskg
      organizations_url: https://api.github.com/users/wallentx/orgs
      received_events_url: https://api.github.com/users/wallentx/received_events
      repos_url: https://api.github.com/users/wallentx/repos
      site_admin: false
      starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
      subscriptions_url: https://api.github.com/users/wallentx/subscriptions
      type: User
      url: https://api.github.com/users/wallentx
  server_url: https://github.com
  api_url: https://api.github.com
  graphql_url: https://api.github.com/graphql
  ref_name: wallentx/trigger
  ref_protected: false
  ref_type: branch
  secret_source: Actions
  workflow_ref: wallentx/sandbox/.github/workflows/stats.yml@refs/heads/wallentx/trigger
  workflow_sha: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  workspace: /runner/_work/sandbox/sandbox
  event_path: /runner/_work/_temp/_github_workflow/event.json
  path: /runner/_work/_temp/_runner_file_commands/add_path_b1704e29-4d6b-4b99-9986-6e87c3cd1adc
  env: /runner/_work/_temp/_runner_file_commands/set_env_b1704e29-4d6b-4b99-9986-6e87c3cd1adc
  step_summary: /runner/_work/_temp/_runner_file_commands/step_summary_b1704e29-4d6b-4b99-9986-6e87c3cd1adc
  state: /runner/_work/_temp/_runner_file_commands/save_state_b1704e29-4d6b-4b99-9986-6e87c3cd1adc
  output: /runner/_work/_temp/_runner_file_commands/set_output_b1704e29-4d6b-4b99-9986-6e87c3cd1adc
  action: __wallentx_github-workflows
  action_repository: wallentx/github-workflows
  action_ref: wallentx/gh-actions/composite/actions-toolbox
  action_path: /runner/_work/_actions/wallentx/github-workflows/wallentx/gh-actions/composite/actions-toolbox/actions/actions-toolbox
  action_status: success
ENV:
  INITIAL_RX_BYTES: "1293305"
  INITIAL_TX_BYTES: "151272"
  RUNNER_VERBOSE: "1"
  CPU_MODEL: AMD EPYC 7R13 Processor
  CPU_CORES: "16"
  CPU_THREADS: "32"
  MEM_TOTAL: 123.166GB
  GH_TOKEN: ***
JOB:
  status: success
STEPS: {}
RUNNER:
  os: Linux
  arch: X64
  name: eks-ubuntu-prod-us-east-1-cl4dl-4sdb7
  environment: self-hosted
  tool_cache: /opt/hostedtoolcache
  temp: /runner/_work/_temp
  workspace: /runner/_work/sandbox
STRATEGY:
  fail-fast: true
  job-index: 0
  job-total: 1
  max-parallel: 1
MATRIX: null
INPUTS:
  verbose: "true"
――――――――――――――――――――――--
Run jq '.' "$GITHUB_EVENT_PATH" | yq -pj -oy -C -P
after: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
base_ref: null
before: 9ac284e0b2fdd36c14170e8d4fb1a938a7f2b022
commits:
  - author:
      email: william.allen@wallentx.com
      name: William Allen
      username: wallentx
    committer:
      email: noreply@github.com
      name: GitHub
      username: web-flow
    distinct: true
    id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
    message: |-
      Update stats.yml

      Signed-off-by: William Allen <william.allen@wallentx.com>
    timestamp: "2024-09-11T17:48:22-05:00"
    tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
    url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
compare: https://github.com/wallentx/sandbox/compare/9ac284e0b2fd...b1c1a3051a00
created: false
deleted: false
enterprise:
  avatar_url: https://avatars.githubusercontent.com/b/11660?v=4
  created_at: "2022-02-24T00:26:20Z"
  description: null
  html_url: https://github.com/enterprises/wallentx-emu
  id: 11660
  name: wallentx
  node_id: E_kgDNLYw
  slug: wallentx-emu
  updated_at: "2024-06-03T06:39:10Z"
  website_url: null
forced: false
head_commit:
  author:
    email: william.allen@wallentx.com
    name: William Allen
    username: wallentx
  committer:
    email: noreply@github.com
    name: GitHub
    username: web-flow
  distinct: true
  id: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
  message: |-
    Update stats.yml

    Signed-off-by: William Allen <william.allen@wallentx.com>
  timestamp: "2024-09-11T17:48:22-05:00"
  tree_id: 1123d9830c81ee7df3cef99a520d2f218a8502d3
  url: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
organization:
  avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
  description: Transform marketing with purchase intelligence through wallentx
  events_url: https://api.github.com/orgs/wallentx/events
  hooks_url: https://api.github.com/orgs/wallentx/hooks
  id: 103681754
  issues_url: https://api.github.com/orgs/wallentx/issues
  login: wallentx
  members_url: https://api.github.com/orgs/wallentx/members{/member}
  node_id: O_kgDOBi4O2g
  public_members_url: https://api.github.com/orgs/wallentx/public_members{/member}
  repos_url: https://api.github.com/orgs/wallentx/repos
  url: https://api.github.com/orgs/wallentx
pusher:
  email: william.allen@wallentx.com
  name: wallentx
ref: refs/heads/wallentx/trigger
repository:
  allow_forking: true
  archive_url: https://api.github.com/repos/wallentx/sandbox/{archive_format}{/ref}
  archived: false
  assignees_url: https://api.github.com/repos/wallentx/sandbox/assignees{/user}
  blobs_url: https://api.github.com/repos/wallentx/sandbox/git/blobs{/sha}
  branches_url: https://api.github.com/repos/wallentx/sandbox/branches{/branch}
  clone_url: https://github.com/wallentx/sandbox.git
  collaborators_url: https://api.github.com/repos/wallentx/sandbox/collaborators{/collaborator}
  comments_url: https://api.github.com/repos/wallentx/sandbox/comments{/number}
  commits_url: https://api.github.com/repos/wallentx/sandbox/commits{/sha}
  compare_url: https://api.github.com/repos/wallentx/sandbox/compare/{base}...{head}
  contents_url: https://api.github.com/repos/wallentx/sandbox/contents/{+path}
  contributors_url: https://api.github.com/repos/wallentx/sandbox/contributors
  created_at: 1701716145
  custom_properties: {}
  default_branch: main
  deployments_url: https://api.github.com/repos/wallentx/sandbox/deployments
  description: Sandbox for platform to test with. Things like workflows, actions runners, terraform, whatever.
  disabled: false
  downloads_url: https://api.github.com/repos/wallentx/sandbox/downloads
  events_url: https://api.github.com/repos/wallentx/sandbox/events
  fork: false
  forks: 0
  forks_count: 0
  forks_url: https://api.github.com/repos/wallentx/sandbox/forks
  full_name: wallentx/sandbox
  git_commits_url: https://api.github.com/repos/wallentx/sandbox/git/commits{/sha}
  git_refs_url: https://api.github.com/repos/wallentx/sandbox/git/refs{/sha}
  git_tags_url: https://api.github.com/repos/wallentx/sandbox/git/tags{/sha}
  git_url: git://github.com/wallentx/sandbox.git
  has_discussions: false
  has_downloads: false
  has_issues: true
  has_pages: false
  has_projects: true
  has_wiki: true
  homepage: ""
  hooks_url: https://api.github.com/repos/wallentx/sandbox/hooks
  html_url: https://github.com/wallentx/sandbox
  id: 727383262
  is_template: false
  issue_comment_url: https://api.github.com/repos/wallentx/sandbox/issues/comments{/number}
  issue_events_url: https://api.github.com/repos/wallentx/sandbox/issues/events{/number}
  issues_url: https://api.github.com/repos/wallentx/sandbox/issues{/number}
  keys_url: https://api.github.com/repos/wallentx/sandbox/keys{/key_id}
  labels_url: https://api.github.com/repos/wallentx/sandbox/labels{/name}
  language: null
  languages_url: https://api.github.com/repos/wallentx/sandbox/languages
  license: null
  master_branch: main
  merges_url: https://api.github.com/repos/wallentx/sandbox/merges
  milestones_url: https://api.github.com/repos/wallentx/sandbox/milestones{/number}
  mirror_url: null
  name: sandbox
  node_id: R_kgDOK1r83g
  notifications_url: https://api.github.com/repos/wallentx/sandbox/notifications{?since,all,participating}
  open_issues: 2
  open_issues_count: 2
  organization: wallentx
  owner:
    avatar_url: https://avatars.githubusercontent.com/u/103681754?v=4
    email: null
    events_url: https://api.github.com/users/wallentx/events{/privacy}
    followers_url: https://api.github.com/users/wallentx/followers
    following_url: https://api.github.com/users/wallentx/following{/other_user}
    gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
    gravatar_id: ""
    html_url: https://github.com/wallentx
    id: 103681754
    login: wallentx
    name: wallentx
    node_id: O_kgDOBi4O2g
    organizations_url: https://api.github.com/users/wallentx/orgs
    received_events_url: https://api.github.com/users/wallentx/received_events
    repos_url: https://api.github.com/users/wallentx/repos
    site_admin: false
    starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
    subscriptions_url: https://api.github.com/users/wallentx/subscriptions
    type: Organization
    url: https://api.github.com/users/wallentx
  private: true
  pulls_url: https://api.github.com/repos/wallentx/sandbox/pulls{/number}
  pushed_at: 1726094902
  releases_url: https://api.github.com/repos/wallentx/sandbox/releases{/id}
  size: 150
  ssh_url: git@github.com:wallentx/sandbox.git
  stargazers: 0
  stargazers_count: 0
  stargazers_url: https://api.github.com/repos/wallentx/sandbox/stargazers
  statuses_url: https://api.github.com/repos/wallentx/sandbox/statuses/{sha}
  subscribers_url: https://api.github.com/repos/wallentx/sandbox/subscribers
  subscription_url: https://api.github.com/repos/wallentx/sandbox/subscription
  svn_url: https://github.com/wallentx/sandbox
  tags_url: https://api.github.com/repos/wallentx/sandbox/tags
  teams_url: https://api.github.com/repos/wallentx/sandbox/teams
  topics:
    - devops
    - platform
    - sre
  trees_url: https://api.github.com/repos/wallentx/sandbox/git/trees{/sha}
  updated_at: "2024-09-05T17:26:38Z"
  url: https://github.com/wallentx/sandbox
  visibility: internal
  watchers: 0
  watchers_count: 0
  web_commit_signoff_required: true
sender:
  avatar_url: https://avatars.githubusercontent.com/u/167472274?v=4
  events_url: https://api.github.com/users/wallentx/events{/privacy}
  followers_url: https://api.github.com/users/wallentx/followers
  following_url: https://api.github.com/users/wallentx/following{/other_user}
  gists_url: https://api.github.com/users/wallentx/gists{/gist_id}
  gravatar_id: ""
  html_url: https://github.com/wallentx
  id: 167472274
  login: wallentx
  node_id: U_kgDOCftskg
  organizations_url: https://api.github.com/users/wallentx/orgs
  received_events_url: https://api.github.com/users/wallentx/received_events
  repos_url: https://api.github.com/users/wallentx/repos
  site_admin: false
  starred_url: https://api.github.com/users/wallentx/starred{/owner}{/repo}
  subscriptions_url: https://api.github.com/users/wallentx/subscriptions
  type: User
  url: https://api.github.com/users/wallentx
Run echo "――――――――――――――――――――――"
――――――――――――――――――――――
Runner native job envs:
――――――――――――――――――――――
ACTIONS_RUNNER_HOOK_JOB_COMPLETED: /etc/arc/hooks/job-completed.sh
ACTIONS_RUNNER_HOOK_JOB_STARTED: /etc/arc/hooks/job-started.sh
CI: "true"
CPU_CORES: "16"
CPU_MODEL: AMD EPYC 7R13 Processor
CPU_THREADS: "32"
DD_AGENT_HOST: 10.160.174.201
DD_ENTITY_ID: ecc5c08b-32d4-43d4-ad95-9e983d84eda9
DD_INSTRUMENTATION_INSTALL_ID: df02ee17-508f-4917-8eb5-068644e1361c
DD_INSTRUMENTATION_INSTALL_TIME: "1723588024"
DEBIAN_FRONTEND: noninteractive
DOCKERD_IN_RUNNER: "true"
DOCKER_ENABLED: "true"
DOCKER_REGISTRY_MIRROR: https://mirror.gcr.io
GH_TOKEN: ***
GITHUB_ACTION: __wallentx_github-workflows
GITHUB_ACTIONS: "true"
GITHUB_ACTIONS_RUNNER_EXTRA_USER_AGENT: actions-runner-controller/v0.27.6
GITHUB_ACTION_PATH: /runner/_work/_actions/wallentx/github-workflows/wallentx/gh-actions/composite/actions-toolbox/actions/actions-toolbox
GITHUB_ACTION_REF: ""
GITHUB_ACTION_REPOSITORY: ""
GITHUB_ACTOR: wallentx
GITHUB_ACTOR_ID: "167472274"
GITHUB_API_URL: https://api.github.com
GITHUB_BASE_REF: ""
GITHUB_ENV: /runner/_work/_temp/_runner_file_commands/set_env_184173df-cddd-4939-a1b5-5fc323c6f986
GITHUB_EVENT_NAME: push
GITHUB_EVENT_PATH: /runner/_work/_temp/_github_workflow/event.json
GITHUB_GRAPHQL_URL: https://api.github.com/graphql
GITHUB_HEAD_REF: ""
GITHUB_JOB: test
GITHUB_OUTPUT: /runner/_work/_temp/_runner_file_commands/set_output_184173df-cddd-4939-a1b5-5fc323c6f986
GITHUB_PATH: /runner/_work/_temp/_runner_file_commands/add_path_184173df-cddd-4939-a1b5-5fc323c6f986
GITHUB_REF: refs/heads/wallentx/trigger
GITHUB_REF_NAME: wallentx/trigger
GITHUB_REF_PROTECTED: "false"
GITHUB_REF_TYPE: branch
GITHUB_REPOSITORY: wallentx/sandbox
GITHUB_REPOSITORY_ID: "727383262"
GITHUB_REPOSITORY_OWNER: wallentx
GITHUB_REPOSITORY_OWNER_ID: "103681754"
GITHUB_RETENTION_DAYS: "400"
GITHUB_RUN_ATTEMPT: "8"
GITHUB_RUN_ID: "10820841667"
GITHUB_RUN_NUMBER: "62"
GITHUB_SERVER_URL: https://github.com
GITHUB_SHA: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GITHUB_STATE: /runner/_work/_temp/_runner_file_commands/save_state_184173df-cddd-4939-a1b5-5fc323c6f986
GITHUB_STEP_SUMMARY: /runner/_work/_temp/_runner_file_commands/step_summary_184173df-cddd-4939-a1b5-5fc323c6f986
GITHUB_TRIGGERING_ACTOR: wallentx
GITHUB_URL: https://github.com/
GITHUB_WORKFLOW: Testing context dump
GITHUB_WORKFLOW_REF: wallentx/sandbox/.github/workflows/stats.yml@refs/heads/wallentx/trigger
GITHUB_WORKFLOW_SHA: b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GITHUB_WORKSPACE: /runner/_work/sandbox/sandbox
HOME: /home/runner
HOSTNAME: eks-ubuntu-prod-us-east-1-cl4dl-4sdb7
INITIAL_RX_BYTES: "1293305"
INITIAL_TX_BYTES: "151272"
ImageOS: ubuntu20
KUBERNETES_PORT: tcp://172.20.0.1:443
KUBERNETES_PORT_443_TCP: tcp://172.20.0.1:443
KUBERNETES_PORT_443_TCP_ADDR: 172.20.0.1
KUBERNETES_PORT_443_TCP_PORT: "443"
KUBERNETES_PORT_443_TCP_PROTO: tcp
KUBERNETES_SERVICE_HOST: 172.20.0.1
KUBERNETES_SERVICE_PORT: "443"
KUBERNETES_SERVICE_PORT_HTTPS: "443"
MEM_TOTAL: 123.166GB
OLDPWD: /
PATH: /opt/hostedtoolcache/gh-cli/v2.56.0/linux_amd64:/opt/hostedtoolcache/yq/v4.44.3/linux_amd64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/runner/.local/bin
PWD: /runner/_work/sandbox/sandbox
RUNNER_ARCH: X64
RUNNER_ASSETS_DIR: /runnertmp
RUNNER_ENTERPRISE: ""
RUNNER_ENVIRONMENT: self-hosted
RUNNER_EPHEMERAL: "true"
RUNNER_GRACEFUL_STOP_TIMEOUT: "14330"
RUNNER_GROUP: eks-prod-us-east-1
RUNNER_LABELS: k8s,code-scanning,dependabot,prod,us-east-1
RUNNER_NAME: eks-ubuntu-prod-us-east-1-cl4dl-4sdb7
RUNNER_ORG: wallentx
RUNNER_OS: Linux
RUNNER_STATUS_UPDATE_HOOK: "false"
RUNNER_TEMP: /runner/_work/_temp
RUNNER_TOOL_CACHE: /opt/hostedtoolcache
RUNNER_TRACKING_ID: github_4e75d447-9435-42cf-9cfd-ad244477345c
RUNNER_VERBOSE: "1"
RUNNER_WORKDIR: /runner/_work
RUNNER_WORKSPACE: /runner/_work/sandbox
SHLVL: "3"
_: /usr/bin/env
――――――――――――――――――――――
Setting env for steps:
――――――――――――――――――――――
GH_EVENT_ACTION: "null"
REPO: sandbox
RFC_REPO: sandbox
GIT_SHORT_HASH: b1c1a305
GH_WORKFLOW_URL: https://github.com/wallentx/sandbox/actions/runs/10820841667
GPR_PROJECT: ghcr.io/wallentx/sandbox
GH_DEFAULT_BRANCH: main
GH_PR_MERGED: "22"
GH_PR: "22"
GH_PR_TITLE: "Add env diagnostics for pull request context"
GH_PR_BODY: "This PR updates the workflow diagnostics output."
GH_PR_AUTHOR: wallentx
GH_PR_COMMENTS: '[{"login":"wallentx","url":"https://github.com/wallentx/sandbox/pull/22#issuecomment-2344807031"},{"login":"linus_torvalds","url":"https://github.com/wallentx/sandbox/pull/22#issuecomment-2344839554"}]'
GH_PR_URL: https://github.com/wallentx/sandbox/pull/22
GH_PR_CREATED_AT: "2024-09-11T22:17:06Z"
GH_PR_FIRST_APPROVAL_AT: "2024-09-11T22:52:57Z"
GH_PR_LAST_APPROVAL_AT: ""
GH_PR_TIME_FIRST_APPROVAL: 35 minutes 51 seconds
GH_PR_MERGED_AT: "2024-09-12T00:52:54Z"
GH_PR_TIME_MERGED: 2 hours 35 minutes 48 seconds
GH_COMMIT_URL: https://github.com/wallentx/sandbox/commit/b1c1a3051a000efa835a5ff6120dd8d9cd6d8c56
GH_REPO_URL: https://github.com/wallentx/sandbox
GH_REPO_TOPICS: '["devops","platform","sre"]'
DOMAIN_TEAM: platform
――――――――――――――――――――――
Complete
――――――――――――――――――――――
```

</details>

With this amount of information, you are only limited by your imagination as to how this data may be used to serve downstream execution.
