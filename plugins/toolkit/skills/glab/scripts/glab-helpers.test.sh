#!/bin/bash
# glab-helpers.test.sh - Unit tests for glab-helpers.sh
# Run: bash plugins/toolkit/skills/glab/scripts/glab-helpers.test.sh
#
# glab is mocked, so no test talks to a GitLab server. When a real glab binary
# is on PATH, an extra section replays every recorded glab call against the
# real CLI's --help output (only --help is ever run). Set SKIP_REAL_GLAB=1 to
# skip that section.
#
# Requires: bash, jq.

# Don't exit on error - we need to test failures
# set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
HELPERS="$SCRIPT_DIR/glab-helpers.sh"
SKILL_DIR=$(dirname "$SCRIPT_DIR")

# =============================================================================
# TEST FRAMEWORK
# =============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helpers
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Testing: $1 ... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
    echo -e "    ${RED}Error: $1${NC}"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" = "$actual" ]; then
        return 0
    else
        test_fail "Expected '$expected', got '$actual'"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        test_fail "Expected to contain '$needle' in '$haystack'"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        return 0
    else
        test_fail "Expected NOT to contain '$needle' in '$haystack'"
        return 1
    fi
}

assert_function_exists() {
    local func_name="$1"
    if declare -f "$func_name" > /dev/null 2>&1; then
        return 0
    else
        test_fail "Function '$func_name' does not exist"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" -eq "$actual" ]; then
        return 0
    else
        test_fail "Expected exit code $expected, got $actual"
        return 1
    fi
}

assert_nonzero() {
    local actual="$1"
    if [ "$actual" -ne 0 ]; then
        return 0
    else
        test_fail "Expected a non-zero exit code, got 0"
        return 1
    fi
}

# =============================================================================
# PREREQUISITES AND TEMP DIR
# =============================================================================

if ! command -v jq > /dev/null 2>&1; then
    echo "jq is required to run these tests (the helpers need it too)." >&2
    exit 1
fi

# Find the real glab binary before the mock below shadows it.
REAL_GLAB=$(type -P glab 2>/dev/null || true)

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/glab-helpers-test.XXXXXX") || exit 1
trap 'rm -rf "$TEST_TMP"' EXIT

# =============================================================================
# MOCK GLAB COMMAND
# =============================================================================
# Calls are logged to files, not arrays, so calls made inside $(...) subshells
# are recorded too.

MOCK_GLAB_LOG="$TEST_TMP/calls.log"      # calls of the current test (reset per test)
MOCK_GLAB_ARGV_LOG="$TEST_TMP/argv.log"  # every call, shell-quoted (for the real-glab check)
MOCK_GLAB_OUTPUT=""
MOCK_GLAB_EXIT_CODE=0
: > "$MOCK_GLAB_LOG"
: > "$MOCK_GLAB_ARGV_LOG"

# Mock glab command. A test can define mock_glab_impl() for per-call behavior.
glab() {
    printf 'glab %s\n' "$*" >> "$MOCK_GLAB_LOG"
    printf '%q ' "$@" >> "$MOCK_GLAB_ARGV_LOG"
    printf '\n' >> "$MOCK_GLAB_ARGV_LOG"

    # Real glab (<1.100) has no --jq flag; behave like it.
    local arg
    for arg in "$@"; do
        if [ "$arg" = "--jq" ]; then
            echo "Unknown flag: --jq." >&2
            return 1
        fi
    done

    if declare -f mock_glab_impl > /dev/null; then
        mock_glab_impl "$@"
        return
    fi
    if [ -n "$MOCK_GLAB_OUTPUT" ]; then
        printf '%s\n' "$MOCK_GLAB_OUTPUT"
    fi
    return "$MOCK_GLAB_EXIT_CODE"
}

mock_calls() { cat "$MOCK_GLAB_LOG"; }
mock_call_count() { grep -c . "$MOCK_GLAB_LOG"; }

reset_mocks() {
    : > "$MOCK_GLAB_LOG"
    MOCK_GLAB_OUTPUT=""
    MOCK_GLAB_EXIT_CODE=0
    unset -f mock_glab_impl
}

# Common canned responses
mock_pipeline_42() {
    mock_glab_impl() {
        case "$*" in
            "ci get --output json") echo '{"id":42,"status":"failed","ref":"feature/x"}' ;;
            *) echo "unexpected mock call: $*" >&2; return 1 ;;
        esac
    }
}

# =============================================================================
# LOAD HELPERS
# =============================================================================

echo "Loading glab-helpers.sh..."
# shellcheck source=glab-helpers.sh
if ! source "$HELPERS"; then
    echo "Could not source $HELPERS" >&2
    exit 1
fi

echo ""
echo "=============================================="
echo "  glab-helpers.sh Unit Tests"
echo "=============================================="
echo ""

# =============================================================================
# TEST: SHORTCUT FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Shortcut Functions]${NC}"

for fn in glci glcis glcil glcit glcir glcic glcilint glmr glmrm glmrr glmrc glmrv glrel glrelc glrelv glrepo; do
    test_start "$fn exists"
    assert_function_exists "$fn" && test_pass
done

echo ""

# =============================================================================
# TEST: WATCH / PIPELINE / JOB / RELEASE / MR FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Helper Functions]${NC}"

for fn in gl-watch gl-watch-pipeline gl-wait gl-watch-jobs \
    gl-pipeline-id gl-run-watch gl-retry-watch gl-cancel-all \
    gl-check-jobs gl-failed-jobs gl-trace-failed \
    gl-release gl-mr-create gl-mr-draft gl-help; do
    test_start "$fn exists"
    assert_function_exists "$fn" && test_pass
done

echo ""

# =============================================================================
# TEST: SHORTCUT FUNCTIONS CALL GLAB CORRECTLY
# =============================================================================

echo -e "${YELLOW}[Shortcut Function Calls]${NC}"

check_shortcut() {
    local fn=$1 expected=$2
    reset_mocks
    test_start "$fn calls '$expected'"
    "$fn" > /dev/null 2>&1
    assert_contains "$(mock_calls)" "$expected" && test_pass
}

check_shortcut glci "glab ci view"
check_shortcut glcis "glab ci status"
check_shortcut glcil "glab ci list"
check_shortcut glcit "glab ci trace"
check_shortcut glcir "glab ci retry"
check_shortcut glcic "glab ci cancel pipeline"
check_shortcut glcilint "glab ci lint"
check_shortcut glmr "glab mr list"
check_shortcut glmrm "glab mr list --assignee=@me"
check_shortcut glmrr "glab mr list --reviewer=@me"
check_shortcut glmrc "glab mr create"
check_shortcut glmrv "glab mr view"
check_shortcut glrel "glab release list"
check_shortcut glrelc "glab release create"
check_shortcut glrelv "glab release view"
check_shortcut glrepo "glab repo view"

echo ""

# =============================================================================
# TEST: ARGUMENT PASSING
# =============================================================================

echo -e "${YELLOW}[Argument Passing]${NC}"

reset_mocks
test_start "glcis passes arguments"
glcis --branch main > /dev/null 2>&1
assert_contains "$(mock_calls)" "glab ci status --branch main" && test_pass

reset_mocks
test_start "glmrv passes MR number"
glmrv 123 > /dev/null 2>&1
assert_contains "$(mock_calls)" "glab mr view 123" && test_pass

reset_mocks
test_start "glcic passes pipeline ID to 'ci cancel pipeline'"
glcic 456789 > /dev/null 2>&1
assert_contains "$(mock_calls)" "glab ci cancel pipeline 456789" && test_pass

reset_mocks
test_start "glcir passes job ID to 'ci retry'"
glcir 224356863 > /dev/null 2>&1
assert_contains "$(mock_calls)" "glab ci retry 224356863" && test_pass

reset_mocks
test_start "glrelv passes version"
glrelv v1.5.0 > /dev/null 2>&1
assert_contains "$(mock_calls)" "glab release view v1.5.0" && test_pass

echo ""

# =============================================================================
# TEST: FUNCTION ARGUMENT VALIDATION
# =============================================================================

echo -e "${YELLOW}[Argument Validation]${NC}"

check_usage() {
    local label=$1
    shift
    reset_mocks
    test_start "$label"
    local output exit_code
    output=$("$@" 2>&1); exit_code=$?
    if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage, got $exit_code: $output"; fi
}

check_usage "gl-check-jobs requires arguments" gl-check-jobs
check_usage "gl-mr-create requires title" gl-mr-create
check_usage "gl-mr-draft requires title" gl-mr-draft
check_usage "gl-release requires version" gl-release
check_usage "gl-watch-pipeline requires pipeline ID" gl-watch-pipeline
check_usage "gl-watch-jobs requires pipeline ID" gl-watch-jobs
check_usage "gl-cancel-all rejects unknown arguments" gl-cancel-all --force

echo ""

# =============================================================================
# TEST: GL-HELP OUTPUT
# =============================================================================

echo -e "${YELLOW}[Help Output]${NC}"

HELP_OUTPUT=$(gl-help)

for needle in "SHORTCUTS:" "WATCH FUNCTIONS" "PIPELINE FUNCTIONS:" "JOB FUNCTIONS:" \
    "RELEASE FUNCTIONS:" "MR FUNCTIONS:" "glcis" "gl-watch" "gl-wait" \
    "gl-cancel-all [--yes]" "gl-retry-watch [PIPELINE_ID]"; do
    test_start "gl-help contains '$needle'"
    assert_contains "$HELP_OUTPUT" "$needle" && test_pass
done

echo ""

# =============================================================================
# TEST: MR FUNCTIONS WITH ARGUMENTS
# =============================================================================

echo -e "${YELLOW}[MR Function Arguments]${NC}"

reset_mocks
test_start "gl-mr-create uses default target branch 'main'"
gl-mr-create "Test MR" > /dev/null 2>&1
assert_contains "$(mock_calls)" "--target-branch main" && test_pass

reset_mocks
test_start "gl-mr-create accepts custom target branch"
gl-mr-create "Test MR" develop > /dev/null 2>&1
assert_contains "$(mock_calls)" "--target-branch develop" && test_pass

reset_mocks
test_start "gl-mr-draft includes --draft flag"
gl-mr-draft "Draft MR" > /dev/null 2>&1
assert_contains "$(mock_calls)" "--draft" && test_pass

echo ""

# =============================================================================
# TEST: GL-CHECK-JOBS WITH MULTIPLE IDS
# =============================================================================

echo -e "${YELLOW}[Multiple Job IDs]${NC}"

reset_mocks
test_start "gl-check-jobs handles multiple job IDs"
gl-check-jobs 111 222 333 > /dev/null 2>&1
call_count=$(mock_call_count)
if [ "$call_count" -eq 3 ]; then
    test_pass
else
    test_fail "Expected 3 calls, got $call_count"
fi

reset_mocks
MOCK_GLAB_OUTPUT='{"name":"unit","stage":"test","status":"success","duration":12.5,"id":111}'
test_start "gl-check-jobs prints job fields via jq"
output=$(gl-check-jobs 111 2>&1)
assert_contains "$output" '"status": "success"' && assert_contains "$output" '"name": "unit"' && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-check-jobs returns non-zero when the API call fails"
output=$(gl-check-jobs 111 2>&1); exit_code=$?
assert_nonzero "$exit_code" && assert_contains "$output" "Failed to fetch job 111" && test_pass

echo ""

# =============================================================================
# TEST: API JSON IS FILTERED WITH jq, ERRORS PROPAGATE (regression: --jq)
# =============================================================================

echo -e "${YELLOW}[JSON via jq / Error Propagation]${NC}"

test_start "helpers never pass --jq to glab"
if grep -n -- '--jq' "$HELPERS" > /dev/null; then
    test_fail "glab-helpers.sh still uses --jq: $(grep -n -- '--jq' "$HELPERS")"
else
    test_pass
fi

test_start "helpers do not use 'glab ci status --output' (no such flag)"
if grep -nE 'ci status[^#]*--output' "$HELPERS" > /dev/null; then
    test_fail "$(grep -nE 'ci status[^#]*--output' "$HELPERS")"
else
    test_pass
fi

reset_mocks
mock_pipeline_42
test_start "gl-pipeline-id reads the ID from 'glab ci get --output json'"
output=$(gl-pipeline-id 2>&1)
assert_equals "42" "$output" && assert_contains "$(mock_calls)" "glab ci get --output json" && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-pipeline-id fails with a message when no pipeline exists"
output=$(gl-pipeline-id 2>&1); exit_code=$?
assert_nonzero "$exit_code" && assert_contains "$output" "no pipeline found" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='[{"id":7,"stage":"test","name":"unit","failure_reason":"script_failure"},{"id":8,"stage":"lint","name":"eslint"}]'
test_start "gl-failed-jobs formats failed jobs"
output=$(gl-failed-jobs 42 2>&1); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$output" "[7] test:unit - script_failure" \
    && assert_contains "$output" "[8] lint:eslint - unknown" \
    && assert_contains "$(mock_calls)" "glab api projects/:id/pipelines/42/jobs?scope=failed" \
    && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='[]'
test_start "gl-failed-jobs reports when there are no failed jobs"
output=$(gl-failed-jobs 42 2>&1); exit_code=$?
assert_exit_code 0 "$exit_code" && assert_contains "$output" "No failed jobs in pipeline 42" && test_pass

reset_mocks
mock_glab_impl() { echo "glab: 404 Not Found (HTTP 404)" >&2; return 1; }
test_start "gl-failed-jobs returns non-zero when the API call fails"
output=$(gl-failed-jobs 42 2>&1); exit_code=$?
assert_nonzero "$exit_code" && assert_contains "$output" "404 Not Found" && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci get --output json") echo '{"id":42,"status":"failed"}' ;;
        api*) echo "glab: 404 Not Found (HTTP 404)" >&2; return 1 ;;
        *) return 0 ;;
    esac
}
test_start "gl-trace-failed returns non-zero (not 'No failed jobs') when the API fails"
output=$(gl-trace-failed 2>&1); exit_code=$?
assert_nonzero "$exit_code" \
    && assert_not_contains "$output" "No failed jobs found" \
    && assert_contains "$output" "could not list failed jobs for pipeline 42" \
    && assert_not_contains "$(mock_calls)" "glab ci trace" \
    && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci get --output json") echo '{"id":42,"status":"failed"}' ;;
        api*) echo '[]' ;;
        *) return 0 ;;
    esac
}
test_start "gl-trace-failed reports no failed jobs when the list is empty"
output=$(gl-trace-failed 2>&1); exit_code=$?
assert_exit_code 0 "$exit_code" && assert_contains "$output" "No failed jobs found." && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci get --output json") echo '{"id":42,"status":"failed"}' ;;
        api*) echo '[{"id":777,"name":"unit"}]' ;;
        *) return 0 ;;
    esac
}
test_start "gl-trace-failed traces the first failed job"
output=$(gl-trace-failed 2>&1); exit_code=$?
assert_exit_code 0 "$exit_code" && assert_contains "$(mock_calls)" "glab ci trace 777" && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-trace-failed returns non-zero when no pipeline exists"
output=$(gl-trace-failed 2>&1); exit_code=$?
assert_nonzero "$exit_code" && assert_not_contains "$output" "No failed jobs found" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='[{"status":"success","stage":"build","name":"compile"},{"status":"failed","stage":"test","name":"unit"}]'
test_start "gl-watch-jobs renders job symbols via jq"
output=$( sleep() { exit 0; }; clear() { :; }; gl-watch-jobs 42 2>&1 )
assert_contains "$output" "✓ build:compile" && assert_contains "$output" "✗ test:unit" && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-watch-jobs shows an error when the API call fails"
output=$( sleep() { exit 0; }; clear() { :; }; gl-watch-jobs 42 2>&1 )
assert_contains "$output" "Failed to fetch jobs" && test_pass

echo ""

# =============================================================================
# TEST: GL-WAIT
# =============================================================================

echo -e "${YELLOW}[Wait For Pipeline]${NC}"

run_wait() { ( sleep() { :; }; gl-wait "$@" ) > "$TEST_TMP/wait.out" 2>&1; }

reset_mocks
MOCK_GLAB_OUTPUT='{"id":42,"status":"success"}'
test_start "gl-wait returns 0 on success (uses 'ci get --output json')"
run_wait 1; exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$(mock_calls)" "glab ci get --output json" \
    && assert_not_contains "$(mock_calls)" "ci status" \
    && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='{"id":42,"status":"failed"}'
test_start "gl-wait returns 1 on failure"
run_wait 1; exit_code=$?
assert_exit_code 1 "$exit_code" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='{"id":42,"status":"skipped"}'
test_start "gl-wait returns 1 for a skipped pipeline"
run_wait 1; exit_code=$?
assert_exit_code 1 "$exit_code" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='{"id":42,"status":"running"}'
test_start "gl-wait returns 2 on timeout"
run_wait 1; exit_code=$?
assert_exit_code 2 "$exit_code" && assert_contains "$(cat "$TEST_TMP/wait.out")" "Timeout reached" && test_pass

reset_mocks
mock_glab_impl() { echo "No pipeline found." >&2; return 1; }
test_start "gl-wait returns 3 with a message when the status cannot be fetched"
run_wait 30; exit_code=$?
assert_exit_code 3 "$exit_code" \
    && assert_contains "$(cat "$TEST_TMP/wait.out")" "Could not fetch pipeline status" \
    && assert_equals "3" "$(mock_call_count)" \
    && test_pass

echo ""

# =============================================================================
# TEST: GL-CANCEL-ALL (branch scoped, dry run by default)
# =============================================================================

echo -e "${YELLOW}[Cancel Running Pipelines]${NC}"

mock_two_running() {
    mock_glab_impl() {
        case "$*" in
            "ci list "*) echo '[{"id":11,"ref":"feature/x","status":"running","web_url":"https://gitlab.example.com/p/-/pipelines/11"},{"id":12,"ref":"feature/x","status":"running"}]' ;;
            "ci cancel pipeline "*) echo "cancelled $4" ;;
            *) echo "unexpected mock call: $*" >&2; return 1 ;;
        esac
    }
}

reset_mocks
mock_two_running
test_start "gl-cancel-all is a dry run by default"
output=$( git() { echo "feature/x"; }; gl-cancel-all 2>&1 ); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$output" "11" \
    && assert_contains "$output" "12" \
    && assert_contains "$output" "Dry run" \
    && assert_not_contains "$(mock_calls)" "ci cancel" \
    && test_pass

reset_mocks
mock_two_running
test_start "gl-cancel-all lists only the current branch's running pipelines"
output=$( git() { echo "feature/x"; }; gl-cancel-all 2>&1 )
assert_contains "$(mock_calls)" "glab ci list --status running --ref feature/x" && test_pass

reset_mocks
mock_two_running
test_start "gl-cancel-all --yes cancels each listed pipeline"
output=$( git() { echo "feature/x"; }; gl-cancel-all --yes 2>&1 ); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$(mock_calls)" "glab ci cancel pipeline 11" \
    && assert_contains "$(mock_calls)" "glab ci cancel pipeline 12" \
    && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci list "*) echo '[{"id":11},{"id":12}]' ;;
        "ci cancel pipeline 11") return 1 ;;
        *) return 0 ;;
    esac
}
test_start "gl-cancel-all --yes returns non-zero if a cancel fails"
output=$( git() { echo "feature/x"; }; gl-cancel-all --yes 2>&1 ); exit_code=$?
assert_nonzero "$exit_code" && assert_contains "$(mock_calls)" "glab ci cancel pipeline 12" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='[]'
test_start "gl-cancel-all handles no running pipelines"
output=$( git() { echo "feature/x"; }; gl-cancel-all --yes 2>&1 ); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$output" "No running pipelines found on branch 'feature/x'" \
    && assert_not_contains "$(mock_calls)" "ci cancel" \
    && test_pass

reset_mocks
mock_two_running
test_start "gl-cancel-all refuses to run without a current branch"
output=$( git() { echo ""; }; gl-cancel-all --yes 2>&1 ); exit_code=$?
assert_nonzero "$exit_code" && assert_equals "0" "$(mock_call_count)" && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-cancel-all returns non-zero when listing fails"
output=$( git() { echo "feature/x"; }; gl-cancel-all --yes 2>&1 ); exit_code=$?
assert_nonzero "$exit_code" && assert_not_contains "$(mock_calls)" "ci cancel" && test_pass

echo ""

# =============================================================================
# TEST: GL-RETRY-WATCH (pipeline retry via API, not 'glab ci retry')
# =============================================================================

echo -e "${YELLOW}[Retry Pipeline]${NC}"

# The watch loops are stubbed so a regression fails instead of hanging the suite.
run_retry() {
    (
        sleep() { :; }
        gl-watch-pipeline() { echo "WATCHING $1"; }
        gl-watch() { echo "WATCHING current branch"; }
        gl-retry-watch "$@"
    ) 2>&1
}

reset_mocks
test_start "gl-retry-watch <ID> calls the pipeline retry API"
output=$(run_retry 123); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$(mock_calls)" "glab api --method POST projects/:id/pipelines/123/retry" \
    && assert_not_contains "$(mock_calls)" "glab ci retry" \
    && assert_contains "$output" "WATCHING 123" \
    && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci get --output json") echo '{"id":55,"status":"failed"}' ;;
        *) return 0 ;;
    esac
}
test_start "gl-retry-watch without ID retries the current branch's pipeline"
output=$(run_retry); exit_code=$?
assert_exit_code 0 "$exit_code" \
    && assert_contains "$(mock_calls)" "glab api --method POST projects/:id/pipelines/55/retry" \
    && assert_contains "$output" "WATCHING 55" \
    && test_pass

reset_mocks
MOCK_GLAB_EXIT_CODE=1
test_start "gl-retry-watch returns non-zero and does not watch when retry fails"
output=$(run_retry 123); exit_code=$?
assert_nonzero "$exit_code" && assert_not_contains "$output" "WATCHING" && test_pass

echo ""

# =============================================================================
# TEST: WATCH / RUN / RELEASE FLOWS
# =============================================================================

echo -e "${YELLOW}[Watch, Run and Release]${NC}"

reset_mocks
test_start "gl-watch-pipeline uses 'ci get --pipeline-id' (ci view takes a branch)"
output=$( sleep() { exit 0; }; clear() { :; }; gl-watch-pipeline 123 2>&1 )
assert_contains "$(mock_calls)" "glab ci get --pipeline-id 123" && assert_not_contains "$(mock_calls)" "ci view" && test_pass

reset_mocks
test_start "gl-watch shows status and recent pipelines"
output=$( sleep() { exit 0; }; clear() { :; }; gl-watch 2>&1 )
assert_contains "$(mock_calls)" "glab ci status" && assert_contains "$(mock_calls)" "glab ci list --per-page=5" && test_pass

reset_mocks
test_start "gl-run-watch triggers a pipeline on the given branch"
output=$( sleep() { exit 0; }; gl-run-watch main 2>&1 )
assert_contains "$(mock_calls)" "glab ci run --branch=main" && test_pass

reset_mocks
test_start "gl-run-watch triggers a pipeline on the current branch"
output=$( sleep() { exit 0; }; gl-run-watch 2>&1 )
assert_contains "$(mock_calls)" "glab ci run" && test_pass

reset_mocks
mock_glab_impl() {
    case "$*" in
        "ci get --output json") echo '{"id":42,"status":"success"}' ;;
        *) return 0 ;;
    esac
}
test_start "gl-release creates the release after a successful pipeline"
output=$( sleep() { :; }; gl-release v1.0.0 "Notes" 2>&1 ); exit_code=$?
assert_exit_code 0 "$exit_code" && assert_contains "$(mock_calls)" "glab release create v1.0.0 --notes Notes" && test_pass

reset_mocks
MOCK_GLAB_OUTPUT='{"id":42,"status":"failed"}'
test_start "gl-release does not create a release after a failed pipeline"
output=$( sleep() { :; }; gl-release v1.0.0 2>&1 ); exit_code=$?
assert_nonzero "$exit_code" && assert_not_contains "$(mock_calls)" "release create" && test_pass

echo ""

# =============================================================================
# TEST: DOCS LINT (known-wrong commands must not come back)
# =============================================================================

echo -e "${YELLOW}[Docs Lint]${NC}"

# Only fenced code blocks are checked: prose and the "Common Mistakes" table
# may quote the wrong forms on purpose.
DOCS_CODE="$TEST_TMP/docs-code.txt"
awk '/^[ \t]*```/ { in_block = !in_block; next } in_block { print FILENAME ":" FNR ": " $0 }' \
    "$SKILL_DIR"/*.md > "$DOCS_CODE"

docs_lint() {
    local label=$1 pattern=$2 hits
    test_start "docs: $label"
    hits=$(grep -E -- "$pattern" "$DOCS_CODE")
    if [ -z "$hits" ]; then test_pass; else test_fail "found: $hits"; fi
}

test_start "docs: code blocks were found"
if [ -s "$DOCS_CODE" ]; then test_pass; else test_fail "no fenced code blocks in $SKILL_DIR/*.md"; fi

docs_lint "no 'glab ci cancel <id>' without pipeline/job" 'glab ci cancel($| [^pj-])'
docs_lint "no 'glab ci status --output'" 'ci status[^|]*--output'
docs_lint "no 'glab api ... --jq <filter>'" "(^|[[:space:]])--jq[[:space:]]+['\"]"
docs_lint "no bracketed 'variables[KEY]' fields" 'variables\['
docs_lint "no '--verbose' flag" '--verbose'
docs_lint "no hardcoded ~/.claude/skills path" '\.claude/skills/glab'
docs_lint "no archived profclems/glab" 'profclems'

echo ""

# =============================================================================
# TEST: REAL GLAB CLI ACCEPTS EVERY RECORDED CALL (optional)
# =============================================================================
# Replays each distinct glab call the tests above recorded. For each call:
#   - the leading words must resolve to a runnable glab command (not a group
#     such as 'ci cancel', which only prints help and exits 0);
#   - every flag must appear in that command's --help.
# Only '<command path> --help' is executed, from an empty directory, with an
# empty config and an unreachable host, so nothing can reach a GitLab server.

echo -e "${YELLOW}[Real glab CLI Check]${NC}"

CHECK_DIR="$TEST_TMP/real-glab"

real_glab() {
    ( cd "$CHECK_DIR" && env -u GITLAB_TOKEN -u OAUTH_TOKEN -u GITLAB_URI -u GITLAB_URL -u GL_HOST \
        GITLAB_HOST=https://glab-help-check.invalid GLAB_CONFIG_DIR="$CHECK_DIR/config" \
        GLAB_NO_PROMPT=true GLAB_CHECK_UPDATE=false GLAB_SEND_TELEMETRY=false NO_COLOR=1 \
        "$REAL_GLAB" "$@" ) 2>/dev/null
}

# Cached '<path> --help' output.
real_glab_help() {
    local cache
    cache="$CHECK_DIR/help.$(printf '%s' "$*" | tr -c 'a-z-' '_')"
    [ -f "$cache" ] || real_glab "$@" --help > "$cache"
    cat "$cache"
}

# First line after the USAGE header, trimmed.
help_usage_line() {
    awk 'found { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; exit } /^USAGE[ \t]*$/ { found = 1 }'
}

# Prints a problem description, or nothing if the call is valid.
check_real_glab_call() {
    local path="" word usage help flag
    for word in "$@"; do
        [[ "$word" =~ ^[a-z][a-z-]*$ ]] || break
        usage=$(real_glab_help $path $word | help_usage_line)
        case "$usage" in
            "glab ${path:+$path }$word"|"glab ${path:+$path }$word "*) path="${path:+$path }$word" ;;
            *) break ;;
        esac
    done

    if [ -z "$path" ]; then
        echo "unknown glab command"
        return
    fi
    help=$(real_glab_help $path)
    usage=$(printf '%s\n' "$help" | help_usage_line)
    case "$usage" in
        *"<command>"*) echo "'glab $path' is a command group, not a runnable command"; return ;;
    esac

    for word in "$@"; do
        case "$word" in
            --) break ;;
            --*)
                flag=${word%%=*}
                grep -Eq -- "(^|[[:space:],])${flag}([[:space:],=]|\$)" <<< "$help" \
                    || echo "'glab $path' has no flag $flag"
                ;;
            -?)
                grep -Eq -- "(^|[[:space:]])${word}," <<< "$help" \
                    || echo "'glab $path' has no flag $word"
                ;;
        esac
    done
}

if [ -z "$REAL_GLAB" ] || [ "${SKIP_REAL_GLAB:-0}" = "1" ]; then
    echo "  SKIPPED (no glab binary on PATH, or SKIP_REAL_GLAB=1)"
else
    mkdir -p "$CHECK_DIR/config"
    echo "  Using $REAL_GLAB ($(real_glab --version | head -n 1))"
    argv=()
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        eval "argv=($line)"
        test_start "real glab accepts: glab ${argv[*]}"
        problem=$(check_real_glab_call "${argv[@]}")
        if [ -z "$problem" ]; then test_pass; else test_fail "$problem"; fi
    done < <(sort -u "$MOCK_GLAB_ARGV_LOG")
fi

echo ""

# =============================================================================
# TEST SUMMARY
# =============================================================================

echo "=============================================="
echo "  Test Results"
echo "=============================================="
echo ""
echo -e "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
else
    echo -e "  Failed: $TESTS_FAILED"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
