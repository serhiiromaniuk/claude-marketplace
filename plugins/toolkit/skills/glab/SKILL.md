---
name: glab
description: GitLab CLI (glab) expert for CI/CD pipelines, jobs, merge requests, and releases on gitlab.com or any self-hosted / self-managed GitLab instance. Use when the user shares a GitLab URL (gitlab.com or their own GitLab host, e.g. .../-/pipelines/123, /-/jobs/456, /-/merge_requests/78), mentions GitLab pipelines, jobs, runners, MRs, merge requests, releases, CI/CD debugging, failed jobs, job logs, .gitlab-ci.yml, or glab commands.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash(glab --version)
  - Bash(glab auth status)
  - Bash(glab ci status *)
  - Bash(glab ci get --output json)
  - Bash(glab ci list *)
  - Bash(glab ci trace *)
  - Bash(glab ci lint *)
  - Bash(glab mr list *)
  - Bash(glab mr view *)
  - Bash(glab release list *)
  - Bash(glab release view *)
  - Bash(glab repo view *)
  - Bash(git remote -v)
  - Bash(git branch --show-current)
  - Bash(git rev-parse *)
  - Bash(source "${CLAUDE_PLUGIN_ROOT}/skills/glab/scripts/glab-helpers.sh")
  - Bash(gl-help)
  - Bash(gl-pipeline-id)
  - Bash(gl-failed-jobs *)
  - Bash(gl-check-jobs *)
  - Bash(gl-trace-failed)
---

# GitLab CLI (glab) Skill

Practical DevOps guidance for `glab` operations: pipelines, MRs, releases, and GitLab API automation.

## When This Skill Activates

| Trigger | Examples |
|---------|----------|
| Any GitLab URL (gitlab.com or self-hosted) | `https://gitlab.com/org/project/-/pipelines/123`, `https://gitlab.example.com/org/project/-/jobs/456` |
| GitLab keywords | pipeline, job, runner, MR, merge request, CI/CD, `.gitlab-ci.yml`, glab |
| Action verbs + context | view, check, debug, monitor, retry, cancel, trace |

## Quick Start with $ARGUMENTS

If invoked with a URL argument, parse and query immediately:

```
/toolkit:glab https://gitlab.com/org/project/-/pipelines/123456
```

Extracts: project=`org/project`, resource=`pipelines`, id=`123456`

## URL Parsing (Essential)

**All information is in the URL.** Extract and encode the project path.

```
https://gitlab.com/GROUP/SUBGROUP/PROJECT/-/pipelines/PIPELINE_ID
                  └──────────┬──────────┘             └────┬────┘
                        project path                   resource ID
```

**Encoding:** Replace `/` with `%2F` in project path.

| URL Type | Project Path | Encoded | ID |
|----------|--------------|---------|-----|
| `gitlab.com/org/app/-/pipelines/123` | `org/app` | `org%2Fapp` | `123` |
| `gitlab.com/org/team/app/-/jobs/456` | `org/team/app` | `org%2Fteam%2Fapp` | `456` |

**Quick API pattern:**
```bash
# Pipeline status
glab api "projects/org%2Fapp/pipelines/123"

# Pipeline jobs
glab api "projects/org%2Fapp/pipelines/123/jobs"

# Job logs
glab api "projects/org%2Fapp/jobs/456/trace"
```

**Self-hosted URL** (`https://gitlab.example.com/org/app/-/pipelines/123`): outside a repo whose remote
is that host, `glab api` defaults to gitlab.com, so pass the host:
```bash
glab api --hostname gitlab.example.com "projects/org%2Fapp/pipelines/123"
```

For complete API reference, see [api-reference.md](api-reference.md).

## Aliases Quick Reference

> Source: `scripts/glab-helpers.sh`

| Alias | Command | Description |
|-------|---------|-------------|
| `glcis` | `glab ci status` | Quick status check |
| `glcit` | `glab ci trace` | Trace job logs (job ID or name) |
| `glcir` | `glab ci retry` | Retry a **job** (job ID or name) |
| `glcic` | `glab ci cancel pipeline` | Cancel pipeline(s) by ID |
| `glmrv` | `glab mr view` | View MR |
| `glmrc` | `glab mr create` | Create MR |

`glab ci retry` retries one job. To retry a whole pipeline (all its failed and canceled jobs):
```bash
glab api --method POST "projects/:id/pipelines/123456/retry"
```

**Watch & Wait:**
| Function | Usage | Description |
|----------|-------|-------------|
| `gl-watch` | `gl-watch [INTERVAL]` | Auto-refresh pipeline status (until Ctrl+C) |
| `gl-wait` | `gl-wait [TIMEOUT_MIN]` | Wait for completion (0 ok, 1 failed, 2 timeout, 3 fetch error) |
| `gl-failed-jobs` | `gl-failed-jobs [ID]` | List failed jobs |
| `gl-retry-watch` | `gl-retry-watch [PIPELINE_ID]` | Retry a pipeline via the API, then watch it |
| `gl-cancel-all` | `gl-cancel-all [--yes]` | Cancel running pipelines on the current branch (dry run unless `--yes`) |

Run `gl-help` for all commands. See [workflows.md](workflows.md) for detailed examples.

## Execution Priority

Always follow this order:

1. **Parse URL** - Extract project path + resource ID
2. **Encode path** - Replace `/` with `%2F`
3. **Call API** - Use `glab api` with encoded path
4. **Format output** - Use `jq` for readability

## Prerequisites

Requires **glab 1.54 or newer** (`glab ci cancel pipeline`, `glab ci get --pipeline-id` without a
branch) and `jq`.

```bash
# Verify installation
glab --version
jq --version
glab auth status

# For self-hosted GitLab
export GITLAB_HOST=gitlab.example.com
glab auth login --hostname gitlab.example.com
```

### Use the Helper Functions

Each Bash tool call starts a fresh shell, so source the helpers **in the same call** that uses them.
Do not add anything to the user's `~/.bashrc` / `~/.zshrc`.

```bash
source "${CLAUDE_PLUGIN_ROOT}/skills/glab/scripts/glab-helpers.sh" && gl-failed-jobs 123456
source "${CLAUDE_PLUGIN_ROOT}/skills/glab/scripts/glab-helpers.sh" && gl-help
```

- `gl-watch`, `gl-watch-pipeline`, `gl-watch-jobs`, `gl-run-watch` and `gl-retry-watch` loop until
  Ctrl+C — they are for a human terminal. From the Bash tool use one-shot commands
  (`glab ci get --pipeline-id <ID>`, `glab ci status`) or `gl-wait <MINUTES>`, keeping the timeout
  under the Bash tool limit or running it in the background.
- Always pass explicit IDs: `glab ci trace` / `glab ci retry` without an ID open an interactive picker,
  and `glab ci view` is an interactive TUI.

Humans setting the helpers up in their own shell: see [setup.md](setup.md).

## Additional Resources

| Resource | Description |
|----------|-------------|
| [setup.md](setup.md) | Installation and shell configuration |
| [api-reference.md](api-reference.md) | API endpoints, pagination, JSON output |
| [workflows.md](workflows.md) | Pipeline monitoring, MR workflow, releases |
| [troubleshooting.md](troubleshooting.md) | Common errors and debug commands |
| [scripts/glab-helpers.sh](scripts/glab-helpers.sh) | Shell aliases and functions |

## Common Tasks

**Check pipeline from URL:**
```bash
# URL: https://gitlab.com/myorg/myapp/-/pipelines/789
glab api "projects/myorg%2Fmyapp/pipelines/789" | jq '{status, ref, created_at}'
```

**Get failed jobs:**
```bash
gl-failed-jobs 789
# or directly:
glab api "projects/myorg%2Fmyapp/pipelines/789/jobs?scope=failed" \
    | jq '.[] | {id, name, stage, failure_reason}'
```

**Wait for pipeline, then release:**
```bash
gl-wait 30 && glab release create v1.2.0 --notes "Release notes"
```

**Debug job logs:**
```bash
glab api "projects/myorg%2Fmyapp/jobs/456/trace"
```

For comprehensive workflows, see [workflows.md](workflows.md).
