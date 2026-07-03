# GitLab Workflows

Step-by-step guides for common DevOps workflows using `glab` CLI.

## Pipeline Monitoring

### Watch Pipeline Progress

**Using helpers (recommended):**
```bash
# Auto-refresh every 10 seconds
gl-watch

# Custom interval (30 seconds)
gl-watch 30

# Watch specific pipeline
gl-watch-pipeline 123456 15
```

**Direct glab:**
```bash
# Interactive view
glab ci view

# Quick status
glab ci status

# List recent pipelines
glab ci list --per-page=10
```

### Watch Job Statuses

```bash
# Shows status symbols: ✓ success, ✗ failed, ● running, ○ pending
gl-watch-jobs 123456

# Direct API with formatting
watch -n 10 'glab api "projects/:id/pipelines/123456/jobs" \
    --jq ".[] | \"\(.status) \(.stage):\(.name)\""'
```

### Wait for Pipeline Completion

**Using helper:**
```bash
# Wait up to 30 minutes, returns exit code
gl-wait 30

# Chain with next action
if gl-wait 30; then
    echo "Pipeline passed!"
    glab release create v1.0.0
else
    echo "Pipeline failed or timed out"
fi
```

**Direct approach:**
```bash
while true; do
    STATUS=$(glab ci status --output json | jq -r '.status')
    echo "$(date '+%H:%M:%S') Status: $STATUS"
    case "$STATUS" in
        success|passed) echo "Done!"; break ;;
        failed|canceled) echo "Failed!"; exit 1 ;;
        *) sleep 15 ;;
    esac
done
```

## Pipeline Debugging

### Find Failed Jobs

```bash
# Using helper
gl-failed-jobs 123456

# Direct API
glab api "projects/:id/pipelines/123456/jobs?scope=failed" \
    | jq '.[] | {id, name, stage, failure_reason}'
```

### Get Job Logs

```bash
# Using alias
glcit  # traces current branch's latest failed job

# Specific job
glab ci trace 789012

# Via API (raw logs)
glab api "projects/:id/jobs/789012/trace"
```

### Trace First Failed Job

```bash
# Using helper
gl-trace-failed

# Manual approach
FAILED_JOB=$(glab api "projects/:id/pipelines/123456/jobs?scope=failed&per_page=1" \
    | jq -r '.[0].id')
glab ci trace "$FAILED_JOB"
```

### Check Multiple Jobs

```bash
# Using helper
gl-check-jobs 111 222 333

# Manual loop
for id in 111 222 333; do
    echo "=== Job $id ==="
    glab api "projects/:id/jobs/$id" \
        | jq '{name, stage, status, duration}'
done
```

### Retry Failed Pipeline

```bash
# Using aliases
glcir           # retry latest
glcir 123456    # retry specific

# Retry and watch
gl-retry-watch 123456
```

### Cancel Pipelines

```bash
# Cancel specific pipeline
glcic 123456

# Cancel all running pipelines
gl-cancel-all

# Manual approach
glab ci list --status running --output json \
    | jq -r '.[].id' \
    | xargs -I {} glab ci cancel {}
```

## Merge Request Workflow

### Create MR

**Using helpers:**
```bash
# Standard MR
gl-mr-create "TICKET-123: Add new feature" main

# Draft MR
gl-mr-draft "WIP: Experimental changes" develop
```

**Direct glab:**
```bash
glab mr create \
    --title "TICKET-123: Implement user authentication" \
    --target-branch main \
    --description "## Changes
- Added login endpoint
- Integrated OAuth provider
- Added session management

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass

Closes #456"
```

### View and Review MRs

```bash
# List MRs
glmr                           # all open MRs
glmrm                          # my MRs (assignee)
glmrr                          # MRs to review

# View specific MR
glmrv 78

# View in browser
glab mr view 78 --web

# Checkout MR locally
glab mr checkout 78
```

### Approve and Merge

```bash
# Approve MR
glab mr approve 78

# Merge (after pipeline passes)
glab mr merge 78

# Merge with options
glab mr merge 78 --squash --remove-source-branch
```

### MR Pipeline Status

```bash
# Get MR pipelines
glab api "projects/:id/merge_requests/78/pipelines" \
    | jq '.[] | {id, status, ref}'

# Wait for MR pipeline
MR_SHA=$(glab mr view 78 --output json | jq -r '.sha')
glab ci status --branch "$MR_SHA"
```

## Release Management

### Create Release After Pipeline

**Using helper:**
```bash
# Waits for pipeline, then creates release
gl-release v1.2.0 "Release notes here"

# With changelog file
gl-wait 30 && glab release create v1.2.0 --notes-file CHANGELOG.md
```

**Manual workflow:**
```bash
# 1. Check pipeline status
glab ci status

# 2. Wait if needed
gl-wait 30

# 3. Create release
glab release create v1.2.0 \
    --notes "## What's New
- Feature A
- Bug fix B

## Breaking Changes
None"
```

### Manage Releases

```bash
# List releases
glrel

# View specific release
glrelv v1.2.0

# Delete release (if needed)
glab release delete v1.2.0
```

### Release with Assets

```bash
glab release create v1.2.0 \
    --notes "Release v1.2.0" \
    --assets-links '[
        {"name": "Linux Binary", "url": "https://example.com/app-linux"},
        {"name": "Windows Binary", "url": "https://example.com/app-windows.exe"}
    ]'
```

## CI Configuration

### Lint Before Push

```bash
# Using alias
glcilint

# Lint specific file
glab ci lint .gitlab-ci.yml

# Lint with includes resolved
glab ci lint .gitlab-ci.yml --include-jobs
```

### Trigger Pipeline with Variables

```bash
# Trigger on specific branch
glab ci run --branch release/v1.2

# With variables
glab api "projects/:id/pipeline" -X POST \
    -f ref=main \
    -f "variables[DEPLOY_ENV]=production" \
    -f "variables[SKIP_TESTS]=false" \
    -f "variables[VERSION]=1.2.0"
```

### Run and Watch

```bash
# Using helper
gl-run-watch main

# Manual
glab ci run --branch main
sleep 3
gl-watch
```

## Repository Operations

```bash
# Clone repository
glab repo clone org/project

# View repo info
glrepo

# Search repositories
glab repo search "keyword"

# Work outside repository context
glab mr list -R org/project
glab ci status -R org/project
```

## Scripting Patterns

### Pipeline Success Gate

```bash
#!/bin/bash
# deploy.sh - Deploy only if pipeline passes

BRANCH=${1:-main}

echo "Waiting for pipeline on $BRANCH..."
if gl-wait 45; then
    echo "Pipeline passed, deploying..."
    ./deploy-to-production.sh
else
    echo "Pipeline failed, aborting deployment"
    exit 1
fi
```

### Batch Job Retry

```bash
#!/bin/bash
# retry-failed.sh - Retry all failed jobs in a pipeline

PIPELINE_ID=$1

if [ -z "$PIPELINE_ID" ]; then
    PIPELINE_ID=$(gl-pipeline-id)
fi

glab api "projects/:id/pipelines/${PIPELINE_ID}/jobs?scope=failed" \
    | jq -r '.[].id' \
    | while read job_id; do
        echo "Retrying job $job_id..."
        glab api "projects/:id/jobs/${job_id}/retry" -X POST
    done
```

### Daily Pipeline Report

```bash
#!/bin/bash
# daily-report.sh - Summary of today's pipelines

echo "=== Pipeline Report $(date '+%Y-%m-%d') ==="

echo -e "\nSuccessful:"
glab api "projects/:id/pipelines?status=success&per_page=20" \
    | jq -r '.[] | "  \(.id) | \(.ref) | \(.created_at)"'

echo -e "\nFailed:"
glab api "projects/:id/pipelines?status=failed&per_page=20" \
    | jq -r '.[] | "  \(.id) | \(.ref) | \(.created_at)"'

echo -e "\nRunning:"
glab api "projects/:id/pipelines?status=running" \
    | jq -r '.[] | "  \(.id) | \(.ref) | \(.created_at)"'
```
