#!/usr/bin/env bash
##===----------------------------------------------------------------------===##
##
## Tests for configure.sh non-interactive flag support
##
##===----------------------------------------------------------------------===##

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
TEMPLATE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
CONFIGURE="$TEMPLATE_DIR/configure.sh"

PASS_COUNT=0
FAIL_COUNT=0
TEST_TMPDIR=""

setup() {
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    if [ -n "$TEST_TMPDIR" ]; then
        rm -rf "$TEST_TMPDIR"
    fi
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    local msg="$3"
    if [ ! -f "$file" ]; then
        echo "  FAIL: $msg — file not found: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return
    fi
    if grep -q "$expected" "$file"; then
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $msg — expected '$expected' in $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_file_not_contains() {
    local file="$1"
    local pattern="$2"
    local msg="$3"
    if [ ! -f "$file" ]; then
        echo "  PASS: $msg (file does not exist)"
        PASS_COUNT=$((PASS_COUNT + 1))
        return
    fi
    if grep -q "$pattern" "$file"; then
        echo "  FAIL: $msg — did not expect '$pattern' in $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="$2"
    if [ -f "$file" ]; then
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $msg — file not found: $file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_dir_exists() {
    local dir="$1"
    local msg="$2"
    if [ -d "$dir" ]; then
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $msg — directory not found: $dir"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_dir_not_exists() {
    local dir="$1"
    local msg="$2"
    if [ ! -d "$dir" ]; then
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $msg — directory should not exist: $dir"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

assert_exit_code() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $msg"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  FAIL: $msg — expected exit code $expected, got $actual"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# ============================================================================
# Test: Fully non-interactive with all flags
# ============================================================================
test_all_flags() {
    echo "TEST: All flags provided (fully non-interactive)"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/myapp"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "MyApp" \
        --executable-name "MyServer" \
        --openapi \
        --vscode-snippets \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_exists "$OUTPUT_DIR/Package.swift" "Package.swift is created"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "MyApp" "Package.swift contains package name"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "MyServer" "Package.swift contains executable name"
    assert_dir_exists "$OUTPUT_DIR/Sources/AppAPI" "OpenAPI Sources/AppAPI directory created"
    assert_file_exists "$OUTPUT_DIR/README.md" "README.md is created"
    assert_file_contains "$OUTPUT_DIR/README.md" "MyApp" "README.md contains package name"

    teardown
}

# ============================================================================
# Test: Fully non-interactive with --lambda flag
# ============================================================================
test_lambda_flag() {
    echo "TEST: Lambda flag (fully non-interactive)"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/lambdaapp"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "LambdaApp" \
        --lambda \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_exists "$OUTPUT_DIR/Package.swift" "Package.swift is created"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "LambdaApp" "Package.swift contains package name"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "hummingbird-lambda" "Package.swift contains Lambda dependency"

    teardown
}

# ============================================================================
# Test: --lambda overrides --executable-name
# ============================================================================
test_lambda_overrides_executable() {
    echo "TEST: --lambda ignores --executable-name"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/lambdaoverride"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "LambdaOverride" \
        --lambda \
        --executable-name "CustomExe" \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_not_contains "$OUTPUT_DIR/Package.swift" "CustomExe" "executable name flag is ignored when --lambda is set"

    teardown
}

# ============================================================================
# Test: Minimal flags — booleans default to "no"
# ============================================================================
test_minimal_flags() {
    echo "TEST: Minimal flags (only --package-name, booleans default to no)"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/minimalapp"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "MinimalApp" \
        --executable-name "MinExe" \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_exists "$OUTPUT_DIR/Package.swift" "Package.swift is created"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "MinimalApp" "Package.swift contains package name"
    assert_file_not_contains "$OUTPUT_DIR/Package.swift" "hummingbird-lambda" "Lambda is not enabled"
    assert_dir_not_exists "$OUTPUT_DIR/Sources/AppAPI" "OpenAPI directory not created"

    teardown
}

# ============================================================================
# Test: Invalid package name via flag
# ============================================================================
test_invalid_package_name() {
    echo "TEST: Invalid package name via flag"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/badname"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "Bad Name!" \
        --executable-name "App" \
        </dev/null 2>&1

    assert_exit_code $? 1 "exits with error for invalid package name"

    teardown
}

# ============================================================================
# Test: Invalid executable name via flag
# ============================================================================
test_invalid_executable_name() {
    echo "TEST: Invalid executable name via flag"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/badexe"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "GoodName" \
        --executable-name "Bad Exe!" \
        </dev/null 2>&1

    assert_exit_code $? 1 "exits with error for invalid executable name"

    teardown
}

# ============================================================================
# Test: Unknown flag produces error
# ============================================================================
test_unknown_flag() {
    echo "TEST: Unknown flag produces error"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/unknownflag"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "TestApp" \
        --bogus-flag \
        </dev/null 2>&1

    assert_exit_code $? 1 "exits with error for unknown flag"

    teardown
}

# ============================================================================
# Test: Flags can appear before or after positional arg
# ============================================================================
test_flags_after_positional() {
    echo "TEST: Flags after positional argument"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/flagsafter"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "FlagsAfter" \
        --executable-name "App" \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "FlagsAfter" "Package.swift contains package name"

    teardown
}

test_flags_before_positional() {
    echo "TEST: Flags before positional argument"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/flagsbefore"

    "$CONFIGURE" \
        --package-name "FlagsBefore" \
        --executable-name "App" \
        "$OUTPUT_DIR" \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_contains "$OUTPUT_DIR/Package.swift" "FlagsBefore" "Package.swift contains package name"

    teardown
}

# ============================================================================
# Test: Generated project contains valid ci.yml
# ============================================================================
test_generated_ci_yml() {
    echo "TEST: Generated project contains valid ci.yml"
    setup
    local OUTPUT_DIR="$TEST_TMPDIR/citest"

    "$CONFIGURE" "$OUTPUT_DIR" \
        --package-name "CiTest" \
        --executable-name "App" \
        </dev/null 2>&1

    assert_exit_code $? 0 "exits successfully"
    assert_file_exists "$OUTPUT_DIR/.github/workflows/ci.yml" "ci.yml exists in generated project"
    assert_file_not_contains "$OUTPUT_DIR/.github/workflows/ci.yml" "{{hb" "ci.yml does not contain mustache syntax"

    teardown
}

# ============================================================================
# Run all tests
# ============================================================================
echo "========================================"
echo "configure.sh test suite"
echo "========================================"
echo ""

test_all_flags
echo ""
test_lambda_flag
echo ""
test_lambda_overrides_executable
echo ""
test_minimal_flags
echo ""
test_invalid_package_name
echo ""
test_invalid_executable_name
echo ""
test_unknown_flag
echo ""
test_flags_after_positional
echo ""
test_flags_before_positional
echo ""
test_generated_ci_yml

echo ""
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
    exit 1
fi
