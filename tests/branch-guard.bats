#!/usr/bin/env bats
# Smoke tests for hooks/branch-guard.sh.
# Each test spins up its own throwaway git repo in $BATS_TEST_TMPDIR.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    HOOK="$REPO_ROOT/hooks/branch-guard.sh"
    TESTREPO="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$TESTREPO"
    (
        cd "$TESTREPO"
        git init -q
        git config user.email "t@t"
        git config user.name  "t"
        git commit --allow-empty -q -m init
    )
    # Ensure bypass env is not leaking in from the caller.
    unset WW_ALLOW_MAIN_WRITE
    unset WW_PROTECTED_BRANCHES
}

teardown() {
    :  # BATS_TEST_TMPDIR is cleaned up by bats automatically.
}

@test "protected branch (main) blocks a Write payload with exit 2" {
    ( cd "$TESTREPO" && git checkout -q -B main )
    payload="{\"tool_input\":{\"file_path\":\"$TESTREPO/foo.txt\"}}"
    run bash -c "echo '$payload' | bash '$HOOK'"
    [ "$status" -eq 2 ]
    [[ "$output" == *"refuse write on protected branch"* ]]
}

@test "non-protected branch (feat/x) allows the same Write payload" {
    ( cd "$TESTREPO" && git checkout -q -B feat/x )
    payload="{\"tool_input\":{\"file_path\":\"$TESTREPO/foo.txt\"}}"
    run bash -c "echo '$payload' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "WW_ALLOW_MAIN_WRITE=1 bypasses guard on protected branch" {
    ( cd "$TESTREPO" && git checkout -q -B main )
    payload="{\"tool_input\":{\"file_path\":\"$TESTREPO/foo.txt\"}}"
    run bash -c "echo '$payload' | WW_ALLOW_MAIN_WRITE=1 bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "empty stdin exits 0 (default fail-open)" {
    ( cd "$TESTREPO" && git checkout -q -B main )
    run bash -c "printf '' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "payload with no file_path exits 0 (default fail-open)" {
    ( cd "$TESTREPO" && git checkout -q -B main )
    run bash -c "echo '{\"tool_input\":{}}' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "path outside any git repo exits 0" {
    outside="$BATS_TEST_TMPDIR/not-a-repo/foo.txt"
    mkdir -p "$(dirname "$outside")"
    payload="{\"tool_input\":{\"file_path\":\"$outside\"}}"
    run bash -c "echo '$payload' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}
