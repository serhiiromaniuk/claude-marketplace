# Troubleshooting

Common issues and solutions when using `glab` CLI.

## Authentication Issues

### "401 Unauthorized"

**Cause:** Token expired or invalid.

**Fix:**
```bash
# Check current auth status
glab auth status

# Re-authenticate
glab auth login

# For self-hosted GitLab
glab auth login --hostname gitlab.example.com
```

### "403 Forbidden"

**Cause:** Token lacks required scopes.

**Fix:**
1. Go to GitLab → Settings → Access Tokens
2. Create new token with scopes: `api`, `read_repository`, `write_repository`
3. Re-authenticate:
```bash
glab auth login
```

### Token Not Persisting

**Cause:** Keyring issues on Linux.

**Fix:**
```bash
# Use plain text storage (less secure but works)
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx

# Or add to shell config
echo 'export GITLAB_TOKEN=glpat-xxxxxxxxxxxx' >> ~/.bashrc
```

## Project Not Found

### "404 Project Not Found"

**Cause:** Wrong project path or no access.

**Fix:**
```bash
# Verify project exists and you have access
glab repo view org/project

# Check if you're in a git repo with GitLab remote
git remote -v

# Use explicit project path
glab ci status -R org/project
```

### "Could not resolve project path"

**Cause:** Not in a git repository or no GitLab remote.

**Fix:**
```bash
# Add GitLab remote
git remote add origin git@gitlab.com:org/project.git

# Or specify project explicitly
glab mr list -R org/project
```

## Pipeline Issues

### "Pipeline not found"

**Cause:** No pipeline exists for current branch.

**Fix:**
```bash
# Trigger a new pipeline
glab ci run

# Check if branch exists on remote
git push origin HEAD
glab ci run
```

### "Cannot merge: pipeline must succeed"

**Cause:** Pipeline failed or still running.

**Fix:**
```bash
# Check pipeline status
glcis

# Wait for completion
gl-wait 30

# If failed, retry
glcir

# Check failed jobs
gl-failed-jobs
```

### Pipeline Stuck in "Pending"

**Cause:** No available runners or runner tags mismatch.

**Check:**
```bash
# View pipeline jobs
glab api "projects/:id/pipelines/123/jobs" \
    | jq '.[] | select(.status == "pending") | {name, tags}'

# Check project runners
glab api "projects/:id/runners" | jq '.[].description'
```

**Fix:** Contact GitLab admin or check runner configuration.

## API Errors

### "400 Bad Request"

**Cause:** Malformed request or invalid parameters.

**Debug:**
```bash
# Add verbose output
glab api "projects/:id/pipelines" --verbose

# Check parameter format
glab api "projects/:id/pipeline" -X POST \
    -f ref=main \
    -f "variables[KEY]=value"  # Note the bracket syntax
```

### "422 Unprocessable Entity"

**Cause:** Validation failed (e.g., duplicate tag, invalid ref).

**Common causes:**
- Release tag already exists
- Branch doesn't exist
- Invalid variable names

**Fix:**
```bash
# Check if tag exists
glab release list | grep v1.0.0

# Delete and recreate if needed
glab release delete v1.0.0
glab release create v1.0.0
```

### Rate Limiting (429)

**Cause:** Too many API requests.

**Check:**
```bash
glab api "projects/:id" --include 2>&1 | grep -i ratelimit
```

**Fix:** Wait for rate limit reset or reduce request frequency.

## Helper Function Issues

### "command not found: gl-watch"

**Cause:** Helper script not sourced.

**Fix:**
```bash
# Source the helpers
source ~/.claude/skills/glab/scripts/glab-helpers.sh

# Add to shell config for persistence
echo 'source ~/.claude/skills/glab/scripts/glab-helpers.sh' >> ~/.bashrc
# or for zsh
echo 'source ~/.claude/skills/glab/scripts/glab-helpers.sh' >> ~/.zshrc

# Reload shell
source ~/.bashrc
```

### Helpers Not Working in Scripts

**Cause:** Functions not exported.

**Fix:**
```bash
# Source at the start of your script
#!/bin/bash
source ~/.claude/skills/glab/scripts/glab-helpers.sh

# Then use helpers
gl-wait 30
```

### jq Errors in Helpers

**Cause:** `jq` not installed or API returned error instead of JSON.

**Fix:**
```bash
# Install jq
sudo apt install jq      # Debian/Ubuntu
brew install jq          # macOS

# Debug API output
glab api "projects/:id/pipelines/123" 2>&1 | head -20
```

## Self-Hosted GitLab

### Connection Refused

**Cause:** Wrong hostname or network issues.

**Fix:**
```bash
# Verify hostname
curl -I https://gitlab.example.com

# Set correct host
export GITLAB_HOST=gitlab.example.com

# Re-authenticate
glab auth login --hostname gitlab.example.com
```

### SSL Certificate Errors

**Cause:** Self-signed certificate.

**Fix (not recommended for production):**
```bash
export GIT_SSL_NO_VERIFY=1
glab auth login --hostname gitlab.example.com
```

**Better fix:** Add CA certificate to system trust store.

## Debug Commands

### Enable Verbose Output

```bash
# For any glab command
glab <command> --verbose

# Example
glab ci status --verbose
```

### Check Configuration

```bash
# Auth status
glab auth status

# Current user
glab api user | jq '{username, name, email}'

# Config location
glab config list
```

### Test API Connectivity

```bash
# Simple test
glab api version

# Check permissions
glab api "projects/:id" | jq '{id, name, permissions}'
```

### Get Raw API Response

```bash
# Include headers
glab api "projects/:id/pipelines" --include

# Raw output (no jq processing)
glab api "projects/:id/pipelines/123"
```

## Common Mistakes

| Mistake | Correct |
|---------|---------|
| `glab api projects/org/app/pipelines` | `glab api "projects/org%2Fapp/pipelines"` |
| `glab ci view 123` without being in repo | `glab ci view 123 -R org/app` |
| Forgetting quotes in jq | `jq '.[] \| .name'` → `jq '.[] | .name'` |
| Using `--output json` with `glab api` | `glab api` already returns JSON |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GITLAB_TOKEN` | Authentication token |
| `GITLAB_HOST` | Self-hosted GitLab hostname |
| `GITLAB_URI` | Full GitLab URL |
| `NO_COLOR` | Disable colored output |

```bash
# Example setup
export GITLAB_HOST=gitlab.example.com
export GITLAB_TOKEN=glpat-xxxxxxxxxxxx
```

## Getting Help

```bash
# glab help
glab --help
glab ci --help
glab mr create --help

# Helper functions help
gl-help

# Check glab version
glab --version
```
