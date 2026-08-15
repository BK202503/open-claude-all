#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    TEST_REPO="$(mktemp -d)"
    git -C "$TEST_REPO" init -q -b main
}

teardown() {
    rm -rf "$TEST_REPO"
}

@test "Codex branch guard blocks apply_patch on main" {
    run bash -c "printf '%s' '{\"tool_name\":\"apply_patch\",\"cwd\":\"$TEST_REPO\"}' | bash '$REPO_ROOT/codex/hooks/branch-guard.sh'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"protected branch 'main'"* ]]
}

@test "Codex branch guard allows read-only commands on main" {
    run bash -c "printf '%s' '{\"tool_name\":\"exec_command\",\"tool_input\":{\"command\":\"git status\"},\"cwd\":\"$TEST_REPO\"}' | bash '$REPO_ROOT/codex/hooks/branch-guard.sh'"
    [ "$status" -eq 0 ]
}
