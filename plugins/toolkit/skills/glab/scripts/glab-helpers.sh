#!/bin/bash
# glab-helpers.sh - Aliases and functions for GitLab CLI operations
#
# SETUP:
#   Add to your shell config (~/.bashrc or ~/.zshrc):
#     source ~/.claude/skills/glab/scripts/glab-helpers.sh
#
#   Then reload: source ~/.bashrc
#
# USAGE:
#   gl-help                    Show all available commands
#   glcis                      Quick pipeline status
#   gl-watch                   Watch pipeline with auto-refresh
#   gl-wait 30                 Wait up to 30 min for pipeline
#
# REQUIREMENTS:
#   - glab CLI installed and authenticated (glab auth status)
#   - jq installed for JSON parsing (apt install jq / brew install jq)

# =============================================================================
# SHORTCUTS - Functions for common operations (work in non-interactive shells)
# =============================================================================

# Pipeline operations
glci() { glab ci view "$@"; }                # Watch pipeline (interactive)
glcis() { glab ci status "$@"; }             # Quick status check
glcil() { glab ci list "$@"; }               # List pipelines
glcit() { glab ci trace "$@"; }              # Trace job logs
glcir() { glab ci retry "$@"; }              # Retry failed pipeline
glcic() { glab ci cancel "$@"; }             # Cancel running pipeline
glcilint() { glab ci lint "$@"; }            # Lint CI config

# Merge request operations
glmr() { glab mr list "$@"; }                # List MRs
glmrm() { glab mr list --assignee=@me "$@"; }  # My MRs
glmrr() { glab mr list --reviewer=@me "$@"; }  # MRs to review
glmrc() { glab mr create "$@"; }             # Create MR
glmrv() { glab mr view "$@"; }               # View MR

# Release operations
glrel() { glab release list "$@"; }          # List releases
glrelc() { glab release create "$@"; }       # Create release
glrelv() { glab release view "$@"; }         # View release

# Repository operations
glrepo() { glab repo view "$@"; }            # View repo info

# =============================================================================
# WATCH FUNCTIONS - Monitor pipelines with auto-refresh
# =============================================================================

# Watch pipeline status with refresh interval
# Usage: gl-watch [INTERVAL_SECONDS]
# Example: gl-watch 30
gl-watch() {
    local interval=${1:-10}
    echo "Watching pipeline status (refresh every ${interval}s). Press Ctrl+C to stop."
    while true; do
        clear
        echo "=== Pipeline Status @ $(date '+%H:%M:%S') ==="
        glab ci status
        echo ""
        echo "--- Recent Pipelines ---"
        glab ci list --per-page=5
        sleep "$interval"
    done
}

# Watch specific pipeline by ID
# Usage: gl-watch-pipeline <PIPELINE_ID> [INTERVAL_SECONDS]
gl-watch-pipeline() {
    local pipeline_id=$1
    local interval=${2:-10}

    if [ -z "$pipeline_id" ]; then
        echo "Usage: gl-watch-pipeline <PIPELINE_ID> [INTERVAL_SECONDS]"
        return 1
    fi

    echo "Watching pipeline $pipeline_id (refresh every ${interval}s). Press Ctrl+C to stop."
    while true; do
        clear
        echo "=== Pipeline $pipeline_id @ $(date '+%H:%M:%S') ==="
        glab ci view "$pipeline_id"
        sleep "$interval"
    done
}

# Watch and wait for pipeline completion
# Usage: gl-wait [TIMEOUT_MINUTES]
# Returns: 0 on success, 1 on failure, 2 on timeout
gl-wait() {
    local timeout_minutes=${1:-30}
    local timeout_seconds=$((timeout_minutes * 60))
    local elapsed=0
    local interval=15

    echo "Waiting for pipeline to complete (timeout: ${timeout_minutes}m)..."

    while [ $elapsed -lt $timeout_seconds ]; do
        local status=$(glab ci status --output json 2>/dev/null | jq -r '.status // "unknown"')

        echo "[$(date '+%H:%M:%S')] Status: $status"

        case "$status" in
            "success"|"passed")
                echo "Pipeline succeeded!"
                return 0
                ;;
            "failed")
                echo "Pipeline failed!"
                return 1
                ;;
            "canceled"|"cancelled")
                echo "Pipeline was canceled!"
                return 1
                ;;
            *)
                sleep $interval
                elapsed=$((elapsed + interval))
                ;;
        esac
    done

    echo "Timeout reached after ${timeout_minutes} minutes"
    return 2
}

# Watch jobs in a pipeline with status updates
# Usage: gl-watch-jobs <PIPELINE_ID> [INTERVAL_SECONDS]
gl-watch-jobs() {
    local pipeline_id=$1
    local interval=${2:-10}

    if [ -z "$pipeline_id" ]; then
        echo "Usage: gl-watch-jobs <PIPELINE_ID> [INTERVAL_SECONDS]"
        return 1
    fi

    echo "Watching jobs for pipeline $pipeline_id (refresh every ${interval}s). Press Ctrl+C to stop."
    while true; do
        clear
        echo "=== Jobs @ $(date '+%H:%M:%S') ==="
        glab api "projects/:id/pipelines/${pipeline_id}/jobs?per_page=50" \
            --jq '.[] | "\(.status | if . == "success" then "✓" elif . == "failed" then "✗" elif . == "running" then "●" else "○" end) \(.stage):\(.name)"' 2>/dev/null \
            || echo "Failed to fetch jobs"
        sleep "$interval"
    done
}

# =============================================================================
# PIPELINE HELPER FUNCTIONS
# =============================================================================

# Get pipeline ID for current branch
# Usage: gl-pipeline-id
gl-pipeline-id() {
    glab ci status --output json 2>/dev/null | jq -r '.id // empty'
}

# Trigger pipeline and watch
# Usage: gl-run-watch [BRANCH]
gl-run-watch() {
    local branch=$1
    if [ -n "$branch" ]; then
        echo "Triggering pipeline for branch: $branch"
        glab ci run --branch="$branch"
    else
        echo "Triggering pipeline for current branch"
        glab ci run
    fi
    sleep 3
    gl-watch
}

# Retry and watch pipeline
# Usage: gl-retry-watch [PIPELINE_ID]
gl-retry-watch() {
    local pipeline_id=$1

    if [ -z "$pipeline_id" ]; then
        glab ci retry
    else
        glab ci retry "$pipeline_id"
    fi

    sleep 3
    gl-watch
}

# Cancel all running pipelines for current branch
# Usage: gl-cancel-all
gl-cancel-all() {
    echo "Fetching running pipelines..."
    local pipelines=$(glab ci list --status running --output json | jq -r '.[].id')

    if [ -z "$pipelines" ]; then
        echo "No running pipelines found."
        return 0
    fi

    echo "Found pipelines: $pipelines"
    for pid in $pipelines; do
        echo "Canceling pipeline $pid..."
        glab ci cancel "$pid"
    done
    echo "Done."
}

# =============================================================================
# JOB DEBUGGING FUNCTIONS
# =============================================================================

# Check status of multiple jobs
# Usage: gl-check-jobs <JOB_ID_1> <JOB_ID_2> ...
gl-check-jobs() {
    if [ $# -eq 0 ]; then
        echo "Usage: gl-check-jobs <JOB_ID_1> <JOB_ID_2> ..."
        return 1
    fi

    for job_id in "$@"; do
        echo "=== Job $job_id ==="
        glab api "projects/:id/jobs/$job_id" \
            --jq '{name: .name, stage: .stage, status: .status, duration: .duration}' 2>/dev/null \
            || echo "Failed to fetch job $job_id"
    done
}

# Get failed jobs from pipeline
# Usage: gl-failed-jobs [PIPELINE_ID]
gl-failed-jobs() {
    local pipeline_id=${1:-$(gl-pipeline-id)}

    if [ -z "$pipeline_id" ]; then
        echo "No pipeline ID found. Provide as argument or run from branch with pipeline."
        return 1
    fi

    echo "Failed jobs in pipeline $pipeline_id:"
    glab api "projects/:id/pipelines/${pipeline_id}/jobs?scope=failed" \
        --jq '.[] | "[\(.id)] \(.stage):\(.name) - \(.failure_reason // "unknown")"' 2>/dev/null
}

# Trace failed job from current pipeline
# Usage: gl-trace-failed
gl-trace-failed() {
    local pipeline_id=$(gl-pipeline-id)

    if [ -z "$pipeline_id" ]; then
        echo "No pipeline found for current branch."
        return 1
    fi

    local failed_job=$(glab api "projects/:id/pipelines/${pipeline_id}/jobs?scope=failed&per_page=1" \
        --jq '.[0].id // empty' 2>/dev/null)

    if [ -z "$failed_job" ]; then
        echo "No failed jobs found."
        return 0
    fi

    echo "Tracing failed job $failed_job..."
    glab ci trace "$failed_job"
}

# =============================================================================
# RELEASE HELPER FUNCTIONS
# =============================================================================

# Create release after pipeline success
# Usage: gl-release <VERSION> [NOTES]
gl-release() {
    local version=$1
    local notes=${2:-"Release $version"}

    if [ -z "$version" ]; then
        echo "Usage: gl-release <VERSION> [NOTES]"
        return 1
    fi

    echo "Waiting for pipeline to succeed..."
    if gl-wait 30; then
        echo "Creating release $version..."
        glab release create "$version" --notes "$notes"
    else
        echo "Pipeline did not succeed. Release not created."
        return 1
    fi
}

# =============================================================================
# MR HELPER FUNCTIONS
# =============================================================================

# Create MR with common options
# Usage: gl-mr-create <TITLE> [TARGET_BRANCH]
gl-mr-create() {
    local title=$1
    local target=${2:-main}

    if [ -z "$title" ]; then
        echo "Usage: gl-mr-create <TITLE> [TARGET_BRANCH]"
        return 1
    fi

    glab mr create --title "$title" --target-branch "$target"
}

# Create draft MR
# Usage: gl-mr-draft <TITLE> [TARGET_BRANCH]
gl-mr-draft() {
    local title=$1
    local target=${2:-main}

    if [ -z "$title" ]; then
        echo "Usage: gl-mr-draft <TITLE> [TARGET_BRANCH]"
        return 1
    fi

    glab mr create --title "$title" --target-branch "$target" --draft
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Show glab helper commands
# Usage: gl-help
gl-help() {
    cat << 'EOF'
glab-helpers - Available commands:

SHORTCUTS:
  glci          - Watch pipeline (interactive)
  glcis         - Quick status check
  glcil         - List pipelines
  glcit         - Trace job logs
  glcir         - Retry failed pipeline
  glcic         - Cancel running pipeline
  glcilint      - Lint CI config
  glmr          - List MRs
  glmrm         - My MRs
  glmrr         - MRs to review
  glmrc         - Create MR
  glmrv         - View MR
  glrel         - List releases
  glrelc        - Create release
  glrelv        - View release
  glrepo        - View repo info

WATCH FUNCTIONS:
  gl-watch [INTERVAL]              - Watch pipeline status
  gl-watch-pipeline <ID> [INT]     - Watch specific pipeline
  gl-watch-jobs <PIPELINE_ID>      - Watch job statuses
  gl-wait [TIMEOUT_MIN]            - Wait for pipeline completion

PIPELINE FUNCTIONS:
  gl-pipeline-id                   - Get current pipeline ID
  gl-run-watch [BRANCH]            - Trigger and watch pipeline
  gl-retry-watch [ID]              - Retry and watch pipeline
  gl-cancel-all                    - Cancel all running pipelines

JOB FUNCTIONS:
  gl-check-jobs <ID1> <ID2>...     - Check multiple job statuses
  gl-failed-jobs [PIPELINE_ID]     - List failed jobs
  gl-trace-failed                  - Trace first failed job

RELEASE FUNCTIONS:
  gl-release <VERSION> [NOTES]     - Create release after pipeline success

MR FUNCTIONS:
  gl-mr-create <TITLE> [TARGET]    - Create MR
  gl-mr-draft <TITLE> [TARGET]     - Create draft MR

Run any function with no args for usage info.
EOF
}
