#!/bin/bash
# glab-helpers.test.sh - Unit tests for glab-helpers.sh
# Run: bash ~/claude-skills/glab/scripts/glab-helpers.test.sh

# Don't exit on error - we need to test failures
# set -e

# =============================================================================
# TEST FRAMEWORK
# =============================================================================

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helpers
test_start() {
    CURRENT_TEST="$1"
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

# =============================================================================
# MOCK GLAB COMMAND
# =============================================================================

MOCK_GLAB_CALLS=()
MOCK_GLAB_OUTPUT=""
MOCK_GLAB_EXIT_CODE=0

# Mock glab command
glab() {
    MOCK_GLAB_CALLS+=("glab $*")
    echo "$MOCK_GLAB_OUTPUT"
    return $MOCK_GLAB_EXIT_CODE
}

# Mock jq command for testing
mock_jq() {
    MOCK_JQ_OUTPUT="$1"
    jq() {
        echo "$MOCK_JQ_OUTPUT"
    }
}

reset_mocks() {
    MOCK_GLAB_CALLS=()
    MOCK_GLAB_OUTPUT=""
    MOCK_GLAB_EXIT_CODE=0
}

# =============================================================================
# LOAD HELPERS (without echo message)
# =============================================================================

echo "Loading glab-helpers.sh..."
# Suppress the load message
source "$(dirname "$0")/glab-helpers.sh" 2>/dev/null || source ~/claude-skills/glab/scripts/glab-helpers.sh 2>/dev/null

echo ""
echo "=============================================="
echo "  glab-helpers.sh Unit Tests"
echo "=============================================="
echo ""

# =============================================================================
# TEST: SHORTCUT FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Shortcut Functions]${NC}"

test_start "glci exists"
assert_function_exists "glci" && test_pass

test_start "glcis exists"
assert_function_exists "glcis" && test_pass

test_start "glcil exists"
assert_function_exists "glcil" && test_pass

test_start "glcit exists"
assert_function_exists "glcit" && test_pass

test_start "glcir exists"
assert_function_exists "glcir" && test_pass

test_start "glcic exists"
assert_function_exists "glcic" && test_pass

test_start "glcilint exists"
assert_function_exists "glcilint" && test_pass

test_start "glmr exists"
assert_function_exists "glmr" && test_pass

test_start "glmrm exists"
assert_function_exists "glmrm" && test_pass

test_start "glmrr exists"
assert_function_exists "glmrr" && test_pass

test_start "glmrc exists"
assert_function_exists "glmrc" && test_pass

test_start "glmrv exists"
assert_function_exists "glmrv" && test_pass

test_start "glrel exists"
assert_function_exists "glrel" && test_pass

test_start "glrelc exists"
assert_function_exists "glrelc" && test_pass

test_start "glrelv exists"
assert_function_exists "glrelv" && test_pass

test_start "glrepo exists"
assert_function_exists "glrepo" && test_pass

echo ""

# =============================================================================
# TEST: WATCH FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Watch Functions]${NC}"

test_start "gl-watch exists"
assert_function_exists "gl-watch" && test_pass

test_start "gl-watch-pipeline exists"
assert_function_exists "gl-watch-pipeline" && test_pass

test_start "gl-wait exists"
assert_function_exists "gl-wait" && test_pass

test_start "gl-watch-jobs exists"
assert_function_exists "gl-watch-jobs" && test_pass

echo ""

# =============================================================================
# TEST: PIPELINE FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Pipeline Functions]${NC}"

test_start "gl-pipeline-id exists"
assert_function_exists "gl-pipeline-id" && test_pass

test_start "gl-run-watch exists"
assert_function_exists "gl-run-watch" && test_pass

test_start "gl-retry-watch exists"
assert_function_exists "gl-retry-watch" && test_pass

test_start "gl-cancel-all exists"
assert_function_exists "gl-cancel-all" && test_pass

echo ""

# =============================================================================
# TEST: JOB FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Job Functions]${NC}"

test_start "gl-check-jobs exists"
assert_function_exists "gl-check-jobs" && test_pass

test_start "gl-failed-jobs exists"
assert_function_exists "gl-failed-jobs" && test_pass

test_start "gl-trace-failed exists"
assert_function_exists "gl-trace-failed" && test_pass

echo ""

# =============================================================================
# TEST: RELEASE & MR FUNCTIONS EXIST
# =============================================================================

echo -e "${YELLOW}[Release & MR Functions]${NC}"

test_start "gl-release exists"
assert_function_exists "gl-release" && test_pass

test_start "gl-mr-create exists"
assert_function_exists "gl-mr-create" && test_pass

test_start "gl-mr-draft exists"
assert_function_exists "gl-mr-draft" && test_pass

test_start "gl-help exists"
assert_function_exists "gl-help" && test_pass

echo ""

# =============================================================================
# TEST: SHORTCUT FUNCTIONS CALL GLAB CORRECTLY
# =============================================================================

echo -e "${YELLOW}[Shortcut Function Calls]${NC}"

reset_mocks
test_start "glcis calls 'glab ci status'"
glcis > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci status" && test_pass

reset_mocks
test_start "glcil calls 'glab ci list'"
glcil > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci list" && test_pass

reset_mocks
test_start "glcit calls 'glab ci trace'"
glcit > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci trace" && test_pass

reset_mocks
test_start "glcir calls 'glab ci retry'"
glcir > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci retry" && test_pass

reset_mocks
test_start "glcic calls 'glab ci cancel'"
glcic > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci cancel" && test_pass

reset_mocks
test_start "glcilint calls 'glab ci lint'"
glcilint > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab ci lint" && test_pass

reset_mocks
test_start "glmr calls 'glab mr list'"
glmr > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab mr list" && test_pass

reset_mocks
test_start "glmrm calls 'glab mr list --assignee=@me'"
glmrm > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab mr list --assignee=@me" && test_pass

reset_mocks
test_start "glmrr calls 'glab mr list --reviewer=@me'"
glmrr > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab mr list --reviewer=@me" && test_pass

reset_mocks
test_start "glrel calls 'glab release list'"
glrel > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab release list" && test_pass

reset_mocks
test_start "glrepo calls 'glab repo view'"
glrepo > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "glab repo view" && test_pass

echo ""

# =============================================================================
# TEST: ARGUMENT PASSING
# =============================================================================

echo -e "${YELLOW}[Argument Passing]${NC}"

reset_mocks
test_start "glcis passes arguments"
glcis --output json > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "--output json" && test_pass

reset_mocks
test_start "glmrv passes MR number"
glmrv 123 > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "123" && test_pass

reset_mocks
test_start "glcic passes pipeline ID"
glcic 456789 > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "456789" && test_pass

reset_mocks
test_start "glrelv passes version"
glrelv v1.5.0 > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "v1.5.0" && test_pass

echo ""

# =============================================================================
# TEST: FUNCTION ARGUMENT VALIDATION
# =============================================================================

echo -e "${YELLOW}[Argument Validation]${NC}"

test_start "gl-check-jobs requires arguments"
output=$(gl-check-jobs 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

test_start "gl-mr-create requires title"
output=$(gl-mr-create 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

test_start "gl-mr-draft requires title"
output=$(gl-mr-draft 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

test_start "gl-release requires version"
output=$(gl-release 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

test_start "gl-watch-pipeline requires pipeline ID"
output=$(gl-watch-pipeline 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

test_start "gl-watch-jobs requires pipeline ID"
output=$(gl-watch-jobs 2>&1); exit_code=$?
if [ $exit_code -eq 1 ] && [[ "$output" == *"Usage"* ]]; then test_pass; else test_fail "Expected exit 1 with Usage"; fi

echo ""

# =============================================================================
# TEST: GL-HELP OUTPUT
# =============================================================================

echo -e "${YELLOW}[Help Output]${NC}"

HELP_OUTPUT=$(gl-help)

test_start "gl-help contains SHORTCUTS section"
assert_contains "$HELP_OUTPUT" "SHORTCUTS:" && test_pass

test_start "gl-help contains WATCH FUNCTIONS section"
assert_contains "$HELP_OUTPUT" "WATCH FUNCTIONS:" && test_pass

test_start "gl-help contains PIPELINE FUNCTIONS section"
assert_contains "$HELP_OUTPUT" "PIPELINE FUNCTIONS:" && test_pass

test_start "gl-help contains JOB FUNCTIONS section"
assert_contains "$HELP_OUTPUT" "JOB FUNCTIONS:" && test_pass

test_start "gl-help contains RELEASE FUNCTIONS section"
assert_contains "$HELP_OUTPUT" "RELEASE FUNCTIONS:" && test_pass

test_start "gl-help contains MR FUNCTIONS section"
assert_contains "$HELP_OUTPUT" "MR FUNCTIONS:" && test_pass

test_start "gl-help lists glcis"
assert_contains "$HELP_OUTPUT" "glcis" && test_pass

test_start "gl-help lists gl-watch"
assert_contains "$HELP_OUTPUT" "gl-watch" && test_pass

test_start "gl-help lists gl-wait"
assert_contains "$HELP_OUTPUT" "gl-wait" && test_pass

echo ""

# =============================================================================
# TEST: MR FUNCTIONS WITH ARGUMENTS
# =============================================================================

echo -e "${YELLOW}[MR Function Arguments]${NC}"

reset_mocks
test_start "gl-mr-create uses default target branch 'main'"
gl-mr-create "Test MR" > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "--target-branch main" && test_pass

reset_mocks
test_start "gl-mr-create accepts custom target branch"
gl-mr-create "Test MR" develop > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "--target-branch develop" && test_pass

reset_mocks
test_start "gl-mr-draft includes --draft flag"
gl-mr-draft "Draft MR" > /dev/null 2>&1
assert_contains "${MOCK_GLAB_CALLS[*]}" "--draft" && test_pass

echo ""

# =============================================================================
# TEST: GL-CHECK-JOBS WITH MULTIPLE IDS
# =============================================================================

echo -e "${YELLOW}[Multiple Job IDs]${NC}"

reset_mocks
test_start "gl-check-jobs handles multiple job IDs"
gl-check-jobs 111 222 333 > /dev/null 2>&1
# Should make 3 API calls
call_count=${#MOCK_GLAB_CALLS[@]}
if [ "$call_count" -eq 3 ]; then
    test_pass
else
    test_fail "Expected 3 calls, got $call_count"
fi

echo ""

# =============================================================================
# TEST: GL-CANCEL-ALL
# =============================================================================

echo -e "${YELLOW}[Cancel All Pipelines]${NC}"

reset_mocks
MOCK_GLAB_OUTPUT=""
test_start "gl-cancel-all handles no running pipelines"
# Mock jq to return empty
jq() { echo ""; }
output=$(gl-cancel-all 2>&1)
assert_contains "$output" "No running pipelines found" && test_pass

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
