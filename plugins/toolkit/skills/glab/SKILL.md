---
name: glab
description: GitLab CLI (glab) expert for CI/CD pipelines, merge requests, and releases. Use when user shares gitlab.com URLs, mentions pipelines, jobs, MRs, CI/CD debugging, or glab commands.
allowed-tools: Bash, Read, Grep, Glob
---

# GitLab CLI (glab) Skill

Practical DevOps guidance for `glab` operations: pipelines, MRs, releases, and GitLab API automation.

## When This Skill Activates

| Trigger | Examples |
|---------|----------|
| Any `gitlab.com` URL | `https://gitlab.com/org/project/-/pipelines/123` |
| GitLab keywords | pipeline, job, MR, merge request, CI/CD, glab |
| Action verbs + context | view, check, debug, monitor, retry, cancel, trace |

## Quick Start with $ARGUMENTS

If invoked with a URL argument, parse and query immediately:

```
/glab https://gitlab.com/org/project/-/pipelines/123456
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

For complete API reference, see [api-reference.md](api-reference.md).

## Aliases Quick Reference

> Source: `scripts/glab-helpers.sh`

| Alias | Command | Description |
|-------|---------|-------------|
| `glcis` | `glab ci status` | Quick status check |
| `glcit` | `glab ci trace` | Trace job logs |
| `glcir` | `glab ci retry` | Retry failed pipeline |
| `glcic` | `glab ci cancel` | Cancel pipeline |
| `glmrv` | `glab mr view` | View MR |
| `glmrc` | `glab mr create` | Create MR |

**Watch & Wait:**
| Function | Usage | Description |
|----------|-------|-------------|
| `gl-watch` | `gl-watch [INTERVAL]` | Auto-refresh pipeline status |
| `gl-wait` | `gl-wait [TIMEOUT_MIN]` | Wait for completion (returns exit code) |
| `gl-failed-jobs` | `gl-failed-jobs [ID]` | List failed jobs |

Run `gl-help` for all commands. See [workflows.md](workflows.md) for detailed examples.

## Execution Priority

Always follow this order:

1. **Parse URL** - Extract project path + resource ID
2. **Encode path** - Replace `/` with `%2F`
3. **Call API** - Use `glab api` with encoded path
4. **Format output** - Use `jq` for readability

## Prerequisites

```bash
# Verify installation
glab --version
glab auth status

# For self-hosted GitLab
export GITLAB_HOST=gitlab.example.com
glab auth login --hostname gitlab.example.com
```

### Enable Helper Functions

To use aliases (`glcis`, `glmrv`) and functions (`gl-watch`, `gl-wait`):

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'source ~/.claude/skills/glab/scripts/glab-helpers.sh' >> ~/.bashrc
source ~/.bashrc

# Verify
gl-help
```

See [setup.md](setup.md) for complete installation guide.

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
