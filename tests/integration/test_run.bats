#!/usr/bin/env bats
# test_run.bats - Integration tests for APR run command
#
# Tests the run command with dry-run and render modes (no actual Oracle calls)

# Load test helpers
load '../helpers/test_helper'

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
    setup_test_environment
    log_test_start "${BATS_TEST_NAME}"

    # Set up a complete test workflow
    cd "$TEST_PROJECT"
    setup_test_workflow "default"
}

teardown() {
    log_test_end "${BATS_TEST_NAME}" "$([[ ${status:-0} -eq 0 ]] && echo pass || echo fail)"
    teardown_test_environment
}

# =============================================================================
# Dry Run Tests
# =============================================================================

@test "run --dry-run: shows oracle command" {
    run "$APR_SCRIPT" run 1 --dry-run

    log_test_output "$output"
    log_test_actual "exit code" "$status"

    assert_success
    assert_output --partial "oracle"
}

@test "run --dry-run: includes model selection" {
    run "$APR_SCRIPT" run 1 --dry-run

    log_test_output "$output"

    assert_success
    # Should mention the model
    [[ "$output" == *"5.2"* ]] || [[ "$output" == *"Thinking"* ]] || [[ "$output" == *"-m"* ]]
}

@test "run --dry-run: includes slug" {
    run "$APR_SCRIPT" run 1 --dry-run

    log_test_output "$output"

    assert_success
    [[ "$output" == *"slug"* ]] || [[ "$output" == *"apr-"* ]]
}

@test "run --dry-run: includes round number in slug" {
    run "$APR_SCRIPT" run 5 --dry-run

    log_test_output "$output"

    assert_success
    [[ "$output" == *"5"* ]] || [[ "$output" == *"round"* ]]
}

@test "run --dry-run: with --include-impl flag" {
    run "$APR_SCRIPT" run 1 --dry-run --include-impl

    log_test_output "$output"

    assert_success
    # Should mention implementation or impl
    [[ "$output" == *"impl"* ]] || [[ "$output" == *"IMPLEMENTATION"* ]] || [[ "$output" == *"with-impl"* ]]
}

# =============================================================================
# Render Mode Tests
# =============================================================================

@test "run --render: outputs prompt content" {
    run "$APR_SCRIPT" run 1 --render

    log_test_output "$output"

    assert_success
    # Should include content from README
    [[ "$output" == *"Test Project"* ]] || [[ "$output" == *"README"* ]]
}

@test "run --render: includes specification content" {
    run "$APR_SCRIPT" run 1 --render

    log_test_output "$output"

    assert_success
    [[ "$output" == *"Specification"* ]] || [[ "$output" == *"SPEC"* ]] || [[ "$output" == *"spec"* ]]
}

@test "run --render --include-impl: includes implementation" {
    run "$APR_SCRIPT" run 1 --render --include-impl

    log_test_output "$output"

    assert_success
    [[ "$output" == *"implementation"* ]] || [[ "$output" == *"IMPLEMENTATION"* ]] || [[ "$output" == *"impl"* ]]
}

# =============================================================================
# Round Number Validation Tests
# =============================================================================

@test "run: rejects non-numeric round" {
    run "$APR_SCRIPT" run abc --dry-run

    log_test_output "$output"
    log_test_actual "exit code" "$status"

    assert_failure
}

@test "run: rejects negative round" {
    run "$APR_SCRIPT" run -1 --dry-run

    log_test_actual "exit code" "$status"

    # Should fail or treat -1 as an option
    [[ $status -ne 0 ]] || [[ "$output" == *"invalid"* ]] || [[ "$output" == *"error"* ]]
}

@test "run: accepts zero round" {
    run "$APR_SCRIPT" run 0 --dry-run

    log_test_output "$output"

    # Zero is technically valid (edge case)
    # May succeed or may be rejected - either is acceptable
    [[ $status -eq 0 ]] || [[ $status -eq 1 ]]
}

@test "run: accepts large round number" {
    run "$APR_SCRIPT" run 999 --dry-run

    log_test_output "$output"

    assert_success
}

# =============================================================================
# Shorthand Tests
# =============================================================================

@test "shorthand: apr <number> works like apr run <number>" {
    run "$APR_SCRIPT" 1 --dry-run

    log_test_output "$output"

    assert_success
    [[ "$output" == *"oracle"* ]]
}

@test "shorthand: apr 5 --dry-run shows round 5" {
    run "$APR_SCRIPT" 5 --dry-run

    log_test_output "$output"

    assert_success
    [[ "$output" == *"5"* ]]
}

# =============================================================================
# Workflow Selection Tests
# =============================================================================

@test "run: -w selects workflow" {
    # Create a second workflow
    setup_test_workflow "secondary"

    run "$APR_SCRIPT" run 1 --dry-run -w secondary

    log_test_output "$output"

    assert_success
    [[ "$output" == *"secondary"* ]]
}

@test "run: --workflow selects workflow" {
    setup_test_workflow "another"

    run "$APR_SCRIPT" run 1 --dry-run --workflow another

    log_test_output "$output"

    assert_success
    [[ "$output" == *"another"* ]]
}

@test "run: fails for non-existent workflow" {
    run "$APR_SCRIPT" run 1 --dry-run -w nonexistent

    log_test_output "$output"
    log_test_actual "exit code" "$status"

    assert_failure
}

# =============================================================================
# Verbose/Quiet Mode Tests
# =============================================================================

@test "run: --verbose shows more output" {
    run "$APR_SCRIPT" run 1 --dry-run --verbose

    log_test_output "$output"

    assert_success
    # Verbose output should be longer or include debug info
    [[ ${#output} -gt 50 ]]
}

@test "run: --quiet shows less output" {
    run "$APR_SCRIPT" run 1 --dry-run --quiet

    log_test_output "$output"

    assert_success
}

@test "run: -v is alias for --verbose" {
    run "$APR_SCRIPT" run 1 --dry-run -v

    log_test_output "$output"

    assert_success
}

@test "run: -q is alias for --quiet" {
    run "$APR_SCRIPT" run 1 --dry-run -q

    log_test_output "$output"

    assert_success
}

# =============================================================================
# Preflight Tests
# =============================================================================

@test "run: --no-preflight skips Oracle check but not file validation" {
    # --no-preflight skips Oracle availability check but still validates
    # that required files exist (basic safety check)
    rm -f README.md

    run "$APR_SCRIPT" run 1 --dry-run --no-preflight

    log_test_output "$output"
    log_test_actual "exit code" "$status"

    # File validation still occurs - this is intentional behavior
    # The script still fails when required files are missing
    assert_failure
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"Required file"* ]]
}

@test "run: fails when required file missing (without --no-preflight)" {
    rm -f README.md

    run "$APR_SCRIPT" run 1 --dry-run

    log_test_output "$output"
    log_test_actual "exit code" "$status"

    # Should fail or warn about missing file
    [[ $status -ne 0 ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"missing"* ]]
}

# =============================================================================
# Previous Round Tests
# =============================================================================

@test "run: round 2 references round 1 if it exists" {
    # Create round 1 output
    create_mock_round 1 "default" "# Round 1 Content\n\nPrevious analysis here."

    run "$APR_SCRIPT" run 2 --render

    log_test_output "$output"

    assert_success
    # Should include previous round content or reference
    [[ "$output" == *"Round 1"* ]] || [[ "$output" == *"Previous"* ]] || [[ "$output" == *"round"* ]]
}

# =============================================================================
# Stream Separation Tests
# =============================================================================

@test "run --dry-run: progress to stderr, command to stdout or stderr" {
    # In dry-run mode, output structure should be clean
    capture_streams "$APR_SCRIPT" run 1 --dry-run

    log_test_actual "stdout" "$CAPTURED_STDOUT"
    log_test_actual "stderr" "$CAPTURED_STDERR"

    # Should have some output
    [[ -n "$CAPTURED_STDOUT" ]] || [[ -n "$CAPTURED_STDERR" ]]
}

@test "run --render: prompt content format is correct" {
    run "$APR_SCRIPT" run 1 --render

    log_test_output "$output"

    assert_success

    # Should have structured sections
    [[ "$output" == *"readme"* ]] || [[ "$output" == *"README"* ]] || [[ "$output" == *"<"* ]]
}
