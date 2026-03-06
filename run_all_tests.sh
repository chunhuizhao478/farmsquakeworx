#!/usr/bin/env bash
# =============================================================================
# run_all_tests.sh — Unified test runner for farmsquakeworx
#
# Runs all three test tiers:
#   1. C++ Unit tests      (GoogleTest, unit/farmsquakeworx-unit-opt)
#   2. MOOSE Integration   (TestHarness, run_tests)
#   3. Python Application  (unittest, applications/dynamicelastic_app)
#
# Usage:
#   ./run_all_tests.sh              # run all, log to test_results_<timestamp>.log
#   ./run_all_tests.sh -o results   # custom log file prefix
#   ./run_all_tests.sh -j 8         # parallel jobs for integration tests
#   ./run_all_tests.sh --skip-build # skip rebuilding unit test binary
#   ./run_all_tests.sh --unit-only  # run only unit tests
#   ./run_all_tests.sh --integ-only # run only integration tests
#   ./run_all_tests.sh --app-only   # run only application tests
#
# Prerequisites:
#   - Unit tests: unit/farmsquakeworx-unit-opt must be built (or use --skip-build=false)
#   - Integration tests: MOOSE conda environment must be activated
#     (conda activate moose)
#   - Application tests: python3 available
# =============================================================================

set -o pipefail

# --- Configuration -----------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT_DIR="${PROJECT_DIR}/unit"
UNIT_BIN="${UNIT_DIR}/farmsquakeworx-unit-opt"
APP_TEST_DIR="${PROJECT_DIR}/applications/dynamicelastic_app"

# Auto-detect MOOSE_DIR from run_tests or environment
MOOSE_DIR="${MOOSE_DIR:-$(cd "${PROJECT_DIR}/../moose" 2>/dev/null && pwd)}"
if [[ -d "${MOOSE_DIR}/python" ]]; then
    export PYTHONPATH="${MOOSE_DIR}/python${PYTHONPATH:+:$PYTHONPATH}"
fi

JOBS=4
LOG_PREFIX="test_results"
SKIP_BUILD=false
RUN_UNIT=true
RUN_INTEG=true
RUN_APP=true

# --- Parse arguments ---------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)   LOG_PREFIX="$2"; shift 2 ;;
        -j|--jobs)     JOBS="$2"; shift 2 ;;
        --skip-build)  SKIP_BUILD=true; shift ;;
        --unit-only)   RUN_INTEG=false; RUN_APP=false; shift ;;
        --integ-only)  RUN_UNIT=false; RUN_APP=false; shift ;;
        --app-only)    RUN_UNIT=false; RUN_INTEG=false; shift ;;
        -h|--help)
            sed -n '2,/^# =====/p' "$0" | head -n -1 | sed 's/^# //'
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="${PROJECT_DIR}/${LOG_PREFIX}_${TIMESTAMP}.log"

# --- Helpers -----------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

section() {
    local msg="$1"
    local line
    line=$(printf '=%.0s' {1..72})
    echo ""
    echo "$line"
    echo "  $msg"
    echo "$line"
    echo ""
}

record_result() {
    local tier="$1" name="$2" status="$3" detail="$4"
    if [[ "$status" == "PASS" ]]; then
        PASS=$((PASS + 1))
        printf "  %-12s %-45s [PASS]\n" "[$tier]" "$name"
    elif [[ "$status" == "FAIL" ]]; then
        FAIL=$((FAIL + 1))
        printf "  %-12s %-45s [FAIL]  %s\n" "[$tier]" "$name" "$detail"
    else
        SKIP=$((SKIP + 1))
        printf "  %-12s %-45s [SKIP]  %s\n" "[$tier]" "$name" "$detail"
    fi
}

# --- Begin logging -----------------------------------------------------------
exec > >(tee -a "$LOGFILE") 2>&1

echo "farmsquakeworx — Unified Test Report"
echo "Date:    $(date)"
echo "Host:    $(hostname)"
echo "Log:     ${LOGFILE}"

# =============================================================================
# TIER 1: C++ Unit Tests (GoogleTest)
# =============================================================================
if $RUN_UNIT; then
    section "TIER 1: C++ Unit Tests (GoogleTest)"

    # Build
    if ! $SKIP_BUILD; then
        echo "Building unit tests ..."
        if make -j"${JOBS}" -C "${UNIT_DIR}" 2>&1 | tail -5; then
            echo "Build succeeded."
        else
            record_result "UNIT" "build" "FAIL" "make failed"
            echo ""
            echo "Unit test build failed — skipping unit tests."
            RUN_UNIT_EXEC=false
        fi
    fi

    RUN_UNIT_EXEC=${RUN_UNIT_EXEC:-true}

    if $RUN_UNIT_EXEC; then
        if [[ ! -x "$UNIT_BIN" ]]; then
            record_result "UNIT" "binary" "FAIL" "binary not found: $UNIT_BIN"
        else
            echo "Running unit tests ..."
            echo ""

            # Capture gtest output and parse line-by-line
            UNIT_OUTPUT=$("${UNIT_BIN}" 2>&1)
            UNIT_EXIT=$?
            echo "$UNIT_OUTPUT"

            # Parse GoogleTest results from stdout
            UNIT_PASSED=0
            UNIT_FAILED=0
            while IFS= read -r line; do
                if echo "$line" | grep -qE '^\[\s+OK\s+\]'; then
                    UNIT_PASSED=$((UNIT_PASSED + 1))
                elif echo "$line" | grep -qE '^\[\s+FAILED\s+\]' && ! echo "$line" | grep -qE '^\[\s+FAILED\s+\]\s+[0-9]+ test'; then
                    UNIT_FAILED=$((UNIT_FAILED + 1))
                fi
            done <<< "$UNIT_OUTPUT"

            PASS=$((PASS + UNIT_PASSED))
            FAIL=$((FAIL + UNIT_FAILED))

            echo ""
            echo "  Unit test summary: ${UNIT_PASSED} passed, ${UNIT_FAILED} failed ($((UNIT_PASSED + UNIT_FAILED)) total)"
        fi
    fi
fi

# =============================================================================
# TIER 2: MOOSE Integration Tests (TestHarness)
# =============================================================================
if $RUN_INTEG; then
    section "TIER 2: MOOSE Integration Tests (TestHarness)"

    if [[ ! -f "${PROJECT_DIR}/run_tests" ]]; then
        record_result "INTEG" "run_tests" "FAIL" "run_tests script not found"
    else
        echo "Running integration tests ..."
        echo ""

        # Determine correct python for MOOSE (conda moose uses 'python' not 'python3')
        MOOSE_PYTHON="python3"
        if python -c "import pyhit" 2>/dev/null; then
            MOOSE_PYTHON="python"
        elif ! python3 -c "import pyhit" 2>/dev/null; then
            echo "WARNING: MOOSE Python environment not detected."
            echo "         Activate the MOOSE conda environment first:"
            echo "           conda activate moose"
            echo ""
            echo "Attempting to run anyway..."
            echo ""
        fi

        INTEG_OUTPUT=$("${MOOSE_PYTHON}" "${PROJECT_DIR}/run_tests" -j"${JOBS}" 2>&1)
        INTEG_EXIT=$?
        echo "$INTEG_OUTPUT"

        # Parse TestHarness output for individual test results
        # Format: "test/tests/.../tests:test_name .... OK" or "FAILED"
        INTEG_PARSED=false
        while IFS= read -r line; do
            if echo "$line" | grep -qE '\.\.\.\s+OK$'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "INTEG" "$tname" "PASS"
                INTEG_PARSED=true
            elif echo "$line" | grep -qE '\.\.\.\s+FAILED'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "INTEG" "$tname" "FAIL"
                INTEG_PARSED=true
            elif echo "$line" | grep -qE '\.\.\.\s+SKIPPED'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "INTEG" "$tname" "SKIP" "skipped by harness"
                INTEG_PARSED=true
            fi
        done <<< "$INTEG_OUTPUT"

        # If no individual results were parsed, record overall result
        if ! $INTEG_PARSED; then
            if [[ $INTEG_EXIT -eq 0 ]]; then
                record_result "INTEG" "all-integration-tests" "PASS"
            else
                record_result "INTEG" "all-integration-tests" "FAIL" "TestHarness failed (exit $INTEG_EXIT). Is MOOSE conda env active?"
            fi
        fi
    fi
fi

# =============================================================================
# TIER 3: Python Application Tests (unittest)
# =============================================================================
if $RUN_APP; then
    section "TIER 3: Python Application Tests (unittest)"

    if [[ ! -d "$APP_TEST_DIR" ]]; then
        record_result "APP" "dynamicelastic_app" "SKIP" "directory not found"
    else
        echo "Running application tests (dynamicelastic_app) ..."
        echo ""

        # Use conda python if available, else python3
        APP_PYTHON="python3"
        if command -v python &>/dev/null && python -c "import sys; assert sys.version_info >= (3,6)" 2>/dev/null; then
            APP_PYTHON="python"
        fi
        APP_OUTPUT=$(cd "$APP_TEST_DIR" && "$APP_PYTHON" -m unittest discover -s tests -v 2>&1)
        APP_EXIT=$?
        echo "$APP_OUTPUT"

        # Parse unittest verbose output
        # Format: "test_name (test_module.TestClass) ... ok" or "FAIL" or "ERROR"
        while IFS= read -r line; do
            if echo "$line" | grep -qE '\.\.\.\s+ok$'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "APP" "$tname" "PASS"
            elif echo "$line" | grep -qE '\.\.\.\s+FAIL$'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "APP" "$tname" "FAIL"
            elif echo "$line" | grep -qE '\.\.\.\s+ERROR$'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "APP" "$tname" "FAIL" "error"
            elif echo "$line" | grep -qE '\.\.\.\s+skipped'; then
                tname=$(echo "$line" | sed 's/\s*\.\.\..*$//' | xargs)
                record_result "APP" "$tname" "SKIP"
            fi
        done <<< "$APP_OUTPUT"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
section "FINAL SUMMARY"

TOTAL=$((PASS + FAIL + SKIP))

echo "  Total:    ${TOTAL}"
echo "  Passed:   ${PASS}"
echo "  Failed:   ${FAIL}"
echo "  Skipped:  ${SKIP}"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo "  Result:   ALL TESTS PASSED"
else
    echo "  Result:   SOME TESTS FAILED"
fi
echo ""
echo "Log saved to: ${LOGFILE}"

if [[ $FAIL -eq 0 ]]; then
    exit 0
else
    exit 1
fi
