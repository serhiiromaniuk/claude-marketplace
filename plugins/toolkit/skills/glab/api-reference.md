# GitLab API Reference

Complete reference for `glab api` commands and GitLab REST API endpoints.

## URL to API Conversion

### Step-by-Step

1. Extract project path (everything between `gitlab.com/` and `/-/`)
2. URL-encode the path: replace `/` with `%2F`
3. Build API endpoint with resource type and ID

### Examples

| GitLab URL | Project Path | Encoded Path | API Endpoint |
|------------|--------------|--------------|--------------|
| `gitlab.com/org/app/-/pipelines/123` | `org/app` | `org%2Fapp` | `projects/org%2Fapp/pipelines/123` |
| `gitlab.com/org/team/app/-/jobs/456` | `org/team/app` | `org%2Fteam%2Fapp` | `projects/org%2Fteam%2Fapp/jobs/456` |
| `gitlab.com/org/app/-/merge_requests/78` | `org/app` | `org%2Fapp` | `projects/org%2Fapp/merge_requests/78` |

## API Endpoints

### Pipeline Endpoints

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Get pipeline | `projects/<path>/pipelines/<id>` | GET |
| List pipelines | `projects/<path>/pipelines` | GET |
| Get pipeline jobs | `projects/<path>/pipelines/<id>/jobs` | GET |
| Get failed jobs | `projects/<path>/pipelines/<id>/jobs?scope=failed` | GET |
| Get pipeline variables | `projects/<path>/pipelines/<id>/variables` | GET |
| Trigger pipeline | `projects/<path>/pipeline` | POST |
| Cancel pipeline | `projects/<path>/pipelines/<id>/cancel` | POST |
| Retry pipeline | `projects/<path>/pipelines/<id>/retry` | POST |

### Job Endpoints

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Get job details | `projects/<path>/jobs/<id>` | GET |
| Get job logs | `projects/<path>/jobs/<id>/trace` | GET |
| Retry job | `projects/<path>/jobs/<id>/retry` | POST |
| Cancel job | `projects/<path>/jobs/<id>/cancel` | POST |
| Play manual job | `projects/<path>/jobs/<id>/play` | POST |

### Merge Request Endpoints

| Operation | Endpoint | Method |
|-----------|----------|--------|
| Get MR | `projects/<path>/merge_requests/<id>` | GET |
| List MRs | `projects/<path>/merge_requests` | GET |
| Get MR pipelines | `projects/<path>/merge_requests/<id>/pipelines` | GET |
| Get MR changes | `projects/<path>/merge_requests/<id>/changes` | GET |
| Approve MR | `projects/<path>/merge_requests/<id>/approve` | POST |
| Merge MR | `projects/<path>/merge_requests/<id>/merge` | PUT |

### Release Endpoints

| Operation | Endpoint | Method |
|-----------|----------|--------|
| List releases | `projects/<path>/releases` | GET |
| Get release | `projects/<path>/releases/<tag>` | GET |
| Create release | `projects/<path>/releases` | POST |
| Delete release | `projects/<path>/releases/<tag>` | DELETE |

## API Examples

### Pipeline Operations

```bash
# Get pipeline status
glab api "projects/org%2Fapp/pipelines/123" | jq '{status, ref, created_at, web_url}'

# List recent pipelines
glab api "projects/org%2Fapp/pipelines?per_page=10" | jq '.[] | {id, status, ref}'

# Get all jobs in pipeline (formatted)
glab api "projects/org%2Fapp/pipelines/123/jobs" \
    | jq -r '.[] | "\(.name) | \(.stage) | \(.status)"'

# Get only failed jobs
glab api "projects/org%2Fapp/pipelines/123/jobs?scope=failed" \
    | jq '.[] | {id, name, stage, failure_reason}'

# Trigger pipeline with variables
glab api "projects/org%2Fapp/pipeline" -X POST \
    -f ref=main \
    -f "variables[DEPLOY_ENV]=staging" \
    -f "variables[SKIP_TESTS]=false"
```

### Job Operations

```bash
# Get job details
glab api "projects/org%2Fapp/jobs/456" | jq '{name, stage, status, duration, web_url}'

# Get job logs (raw output)
glab api "projects/org%2Fapp/jobs/456/trace"

# Retry a specific job
glab api "projects/org%2Fapp/jobs/456/retry" -X POST

# Play a manual job
glab api "projects/org%2Fapp/jobs/456/play" -X POST
```

### Merge Request Operations

```bash
# Get MR details
glab api "projects/org%2Fapp/merge_requests/78" | jq '{title, state, author: .author.name}'

# List open MRs
glab api "projects/org%2Fapp/merge_requests?state=opened" | jq '.[] | {iid, title}'

# Get MR pipelines
glab api "projects/org%2Fapp/merge_requests/78/pipelines" | jq '.[] | {id, status}'
```

## Query Parameters

### Filtering

| Parameter | Values | Example |
|-----------|--------|---------|
| `state` | `opened`, `closed`, `merged`, `all` | `?state=opened` |
| `scope` | `created_by_me`, `assigned_to_me`, `all` | `?scope=assigned_to_me` |
| `status` | `running`, `pending`, `success`, `failed`, `canceled` | `?status=running` |

### Pagination

| Parameter | Description | Default |
|-----------|-------------|---------|
| `per_page` | Results per page | 20 |
| `page` | Page number | 1 |

```bash
# Get 100 results per page
glab api "projects/org%2Fapp/pipelines?per_page=100"

# Auto-paginate all results
glab api --paginate "projects/org%2Fapp/jobs?per_page=100" \
    | jq '.[] | select(.status == "failed")'
```

### Sorting

| Parameter | Values |
|-----------|--------|
| `order_by` | `created_at`, `updated_at`, `id` |
| `sort` | `asc`, `desc` |

```bash
glab api "projects/org%2Fapp/pipelines?order_by=created_at&sort=desc&per_page=5"
```

## JSON Output with jq

### Common jq Patterns

```bash
# Extract specific fields
| jq '{id, status, name}'

# Filter array
| jq '.[] | select(.status == "failed")'

# Format as table
| jq -r '.[] | "\(.id)\t\(.name)\t\(.status)"'

# Count items
| jq 'length'

# Get first item
| jq '.[0]'
```

### Useful jq Recipes

```bash
# Pipeline summary
glab api "projects/org%2Fapp/pipelines/123" \
    | jq '{
        id,
        status,
        ref,
        duration: (.duration | if . then "\(. / 60 | floor)m \(. % 60)s" else "running" end),
        created: .created_at
    }'

# Job status with symbols
glab api "projects/org%2Fapp/pipelines/123/jobs" \
    | jq -r '.[] | "\(if .status == "success" then "✓" elif .status == "failed" then "✗" elif .status == "running" then "●" else "○" end) \(.stage):\(.name)"'

# Failed jobs with reasons
glab api "projects/org%2Fapp/pipelines/123/jobs?scope=failed" \
    | jq -r '.[] | "[\(.id)] \(.stage):\(.name) - \(.failure_reason // "unknown")"'
```

## Using `:id` Shorthand

When inside a git repository with GitLab remote, use `:id` instead of encoded path:

```bash
# These are equivalent when in repo directory:
glab api "projects/:id/pipelines/123"
glab api "projects/org%2Fapp/pipelines/123"
```

## Self-Hosted GitLab

For self-hosted instances:

```bash
# Set environment variable
export GITLAB_HOST=gitlab.example.com

# Or use --hostname flag
glab api --hostname gitlab.example.com "projects/org%2Fapp/pipelines"
```

## Rate Limiting

GitLab API has rate limits. Check headers:

```bash
glab api "projects/org%2Fapp/pipelines" --include 2>&1 | grep -i ratelimit
```

Headers to watch:
- `RateLimit-Limit`: Max requests per minute
- `RateLimit-Remaining`: Requests left
- `RateLimit-Reset`: Unix timestamp when limit resets
