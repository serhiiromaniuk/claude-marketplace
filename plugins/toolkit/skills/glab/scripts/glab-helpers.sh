#!/bin/bash
# glab-helpers.sh - Aliases and functions for GitLab CLI operations
#
# This file is meant to be sourced, not executed. It works in bash and zsh.
#
# SETUP:
#   Inside Claude Code, source it in the same Bash call that uses it:
#     source "${CLAUDE_PLUGIN_ROOT}/skills/glab/scripts/glab-helpers.sh" && gl-help
#
#   For your own shell, see setup.md ("Shell Helper Functions") for a snippet
#   that finds the installed plugin copy without hardcoding its version.
#
# USAGE:
#   gl-help                    Show all available commands
#   glcis                      Quick pipeline status
#   gl-watch                   Watch pipeline with auto-refresh (until Ctrl+C)
#   gl-wait 30                 Wait up to 30 min for pipeline
#
# REQUIREMENTS:
#   - glab >= 1.54 installed and authenticated (glab auth status)
#   - jq installed for JSON parsing (apt install jq / brew install jq)

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

# Fail with a clear message when jq is missing.
_gl_need_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "glab-helpers: jq is required but not installed (https://jqlang.org/download/)." >&2
        return 127
    fi
}

# Call `glab api` and filter the JSON response through jq.
# glab's own error output is passed through; a failed call returns non-zero.
# Usage: _gl_api_jq <JQ_FILTER> <glab api arguments...>
_gl_api_jq() {
    local filter=$1
    shift
    _gl_need_jq || return
    local body
    if ! body=$(glab api "$@"); then
        echo "glab-helpers: 'glab api $*' failed." >&2
        return 1
    fi
    printf '%s\n' "$body" | jq -r "$filter"
}

# =============================================================================
# SHORTCUTS - Functions for common operations (work in non-interactive shells)
# =============================================================================

# Pipeline operations
glci() { glab ci view "$@"; }                # Watch pipeline (interactive)
glcis() { glab ci status "$@"; }             # Quick status check
glcil() { glab ci list "$@"; }               # List pipelines
glcit() { glab ci trace "$@"; }              # Trace job logs (job ID or name; no arg = pick)
glcir() { glab ci retry "$@"; }              # Retry a JOB (job ID or name; no arg = pick)
glcic() { glab ci cancel pipeline "$@"; }    # Cancel pipeline(s) by ID
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
# WATCH FUNCTIONS - Monitor pipelines with auto-refresh (loop until Ctrl+C)
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
        glab ci get --pipeline-id "$pipeline_id"
        sleep "$interval"
    done
}

# Watch and wait for pipeline completion (current branch's latest pipeline)
# Usage: gl-wait [TIMEOUT_MINUTES]
# Returns: 0 on success, 1 on failure/cancel/skip, 2 on timeout,
#          3 when the status cannot be fetched (3 consecutive glab errors,
#          e.g. no pipeline exists for the branch)
gl-wait() {
    local timeout_minutes=${1:-30}
    local timeout_seconds=$((timeout_minutes * 60))
    local elapsed=0 interval=15 errors=0 max_errors=3
    local json pipeline_status

    _gl_need_jq || return 3
    echo "Waiting for pipeline to complete (timeout: ${timeout_minutes}m)..."

    while [ "$elapsed" -lt "$timeout_seconds" ]; do
        if json=$(glab ci get --output json) &&
            pipeline_status=$(printf '%s\n' "$json" | jq -r '.status // "unknown"'); then
            errors=0
        else
            errors=$((errors + 1))
            pipeline_status="error (attempt $errors/$max_errors)"
            if [ "$errors" -ge "$max_errors" ]; then
                echo "Could not fetch pipeline status: glab ci get failed $errors times in a row (see error above)." >&2
                return 3
            fi
        fi

        echo "[$(date '+%H:%M:%S')] Status: $pipeline_status"

        case "$pipeline_status" in
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
            "skipped")
                echo "Pipeline was skipped!"
                return 1
                ;;
        esac
        sleep "$interval"
        elapsed=$((elapsed + interval))
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
        _gl_api_jq '.[] | "\(.status | if . == "success" then "✓" elif . == "failed" then "✗" elif . == "running" then "●" else "○" end) \(.stage):\(.name)"' \
            "projects/:id/pipelines/${pipeline_id}/jobs?per_page=100" \
            || echo "Failed to fetch jobs (see error above)"
        sleep "$interval"
    done
}

# =============================================================================
# PIPELINE HELPER FUNCTIONS
# =============================================================================

# Get pipeline ID for current branch
# Usage: gl-pipeline-id
gl-pipeline-id() {
    _gl_need_jq || return
    local json
    if ! json=$(glab ci get --output json); then
        echo "gl-pipeline-id: no pipeline found for the current branch (glab ci get failed)." >&2
        return 1
    fi
    printf '%s\n' "$json" | jq -r '.id // empty'
}

# Trigger pipeline and watch
# Usage: gl-run-watch [BRANCH]
gl-run-watch() {
    local branch=$1
    if [ -n "$branch" ]; then
        echo "Triggering pipeline for branch: $branch"
        glab ci run --branch="$branch" || return 1
    else
        echo "Triggering pipeline for current branch"
        glab ci run || return 1
    fi
    sleep 3
    gl-watch
}

# Retry a pipeline (re-runs its failed and canceled jobs), then watch it.
# `glab ci retry` retries a single JOB, so this calls the pipeline retry API.
# Usage: gl-retry-watch [PIPELINE_ID]   (default: current branch's latest pipeline)
gl-retry-watch() {
    local pipeline_id=$1

    if [ -z "$pipeline_id" ]; then
        pipeline_id=$(gl-pipeline-id) || return 1
        if [ -z "$pipeline_id" ]; then
            echo "gl-retry-watch: no pipeline found for the current branch." >&2
            return 1
        fi
    fi

    echo "Retrying failed/canceled jobs in pipeline $pipeline_id..."
    if ! glab api --method POST "projects/:id/pipelines/${pipeline_id}/retry" >/dev/null; then
        echo "gl-retry-watch: retry request for pipeline $pipeline_id failed." >&2
        return 1
    fi

    sleep 3
    gl-watch-pipeline "$pipeline_id"
}

# Cancel running pipelines on the current git branch.
# Dry run by default: lists what would be cancelled. Pass --yes to cancel.
# The list includes pipelines started by anyone on this branch, not only yours.
# Usage: gl-cancel-all [--yes]
gl-cancel-all() {
    local confirm=""
    case "${1:-}" in
        "") ;;
        --yes|-y) confirm=1 ;;
        *) echo "Usage: gl-cancel-all [--yes]"; return 1 ;;
    esac
    _gl_need_jq || return

    local branch
    branch=$(git branch --show-current 2>/dev/null)
    if [ -z "$branch" ]; then
        echo "gl-cancel-all: not on a git branch (detached HEAD or not a git repository)." >&2
        return 1
    fi

    echo "Fetching running pipelines on branch '$branch'..."
    local json ids
    if ! json=$(glab ci list --status running --ref "$branch" --per-page 100 --output json) ||
        ! ids=$(printf '%s\n' "$json" | jq -r '.[]?.id'); then
        echo "gl-cancel-all: could not list running pipelines for '$branch'." >&2
        return 1
    fi

    if [ -z "$ids" ]; then
        echo "No running pipelines found on branch '$branch'."
        return 0
    fi

    echo "Running pipelines on '$branch' (started by anyone on this branch):"
    printf '%s\n' "$json" | jq -r '.[]? | "  \(.id)  \(.web_url // "")"'

    if [ -z "$confirm" ]; then
        echo "Dry run: nothing was cancelled. Re-run as 'gl-cancel-all --yes' to cancel these."
        return 0
    fi

    local pid rc=0
    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        echo "Canceling pipeline $pid..."
        glab ci cancel pipeline "$pid" || rc=1
    done <<< "$ids"
    echo "Done."
    return $rc
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

    local job_id rc=0
    for job_id in "$@"; do
        echo "=== Job $job_id ==="
        _gl_api_jq '{name: .name, stage: .stage, status: .status, duration: .duration}' \
            "projects/:id/jobs/$job_id" \
            || { echo "Failed to fetch job $job_id"; rc=1; }
    done
    return $rc
}

# Get failed jobs from pipeline
# Usage: gl-failed-jobs [PIPELINE_ID]   (default: current branch's latest pipeline)
gl-failed-jobs() {
    local pipeline_id=$1

    if [ -z "$pipeline_id" ]; then
        pipeline_id=$(gl-pipeline-id) || return 1
    fi
    if [ -z "$pipeline_id" ]; then
        echo "No pipeline ID found. Provide as argument or run from branch with pipeline."
        return 1
    fi

    local jobs
    jobs=$(_gl_api_jq '.[] | "[\(.id)] \(.stage):\(.name) - \(.failure_reason // "unknown")"' \
        "projects/:id/pipelines/${pipeline_id}/jobs?scope=failed&per_page=100") || return 1

    if [ -z "$jobs" ]; then
        echo "No failed jobs in pipeline $pipeline_id."
        return 0
    fi
    echo "Failed jobs in pipeline $pipeline_id:"
    printf '%s\n' "$jobs"
}

# Trace failed job from current pipeline
# Usage: gl-trace-failed
gl-trace-failed() {
    local pipeline_id
    pipeline_id=$(gl-pipeline-id) || return 1

    if [ -z "$pipeline_id" ]; then
        echo "No pipeline found for current branch."
        return 1
    fi

    local failed_job
    if ! failed_job=$(_gl_api_jq '.[0].id // empty' \
        "projects/:id/pipelines/${pipeline_id}/jobs?scope=failed&per_page=1"); then
        echo "gl-trace-failed: could not list failed jobs for pipeline $pipeline_id." >&2
        return 1
    fi

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
  glcit         - Trace job logs (job ID/name; no arg = pick)
  glcir         - Retry a job (job ID/name; no arg = pick)
  glcic         - Cancel pipeline(s) by ID
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

WATCH FUNCTIONS (loop until Ctrl+C):
  gl-watch [INTERVAL]              - Watch pipeline status
  gl-watch-pipeline <ID> [INT]     - Watch specific pipeline
  gl-watch-jobs <PIPELINE_ID>      - Watch job statuses
  gl-wait [TIMEOUT_MIN]            - Wait for pipeline completion (bounded)

PIPELINE FUNCTIONS:
  gl-pipeline-id                   - Get current pipeline ID
  gl-run-watch [BRANCH]            - Trigger and watch pipeline
  gl-retry-watch [PIPELINE_ID]     - Retry a pipeline's failed jobs and watch it
  gl-cancel-all [--yes]            - Cancel running pipelines on current branch
                                     (dry run unless --yes)

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
