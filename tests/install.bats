#!/usr/bin/env bats
# Smoke tests for install.sh.
# Dry-run only; nothing here touches ~/.claude.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "install.sh --dry-run exits 0 and emits DRY: lines for skills" {
    run bash "$REPO_ROOT/install.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY: rsync"*"skills/"* ]]
}

@test "install.sh --dry-run --skip-hook exits 0 and does not wire settings.json" {
    run bash "$REPO_ROOT/install.sh" --dry-run --skip-hook
    [ "$status" -eq 0 ]
    # Positive: skip path prints an explicit "not wiring" line.
    [[ "$output" == *"not wiring branch-guard"* ]]
    # Negative: none of the actual wiring signals appear.
    [[ "$output" != *"would merge branch-guard hook"* ]]
    [[ "$output" != *"branch-guard-like hook already present"* ]]
    [[ "$output" != *"    wired."* ]]
}

@test "install.sh --target codex --dry-run installs only Codex skills" {
    run bash "$REPO_ROOT/install.sh" --target=codex --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"Codex CLI skills"* ]]
    [[ "$output" == *"codex-project-policy"* ]]
    [[ "$output" != *"wiring branch-guard"* ]]
}

@test "install.sh --help prints usage and exits 0" {
    run bash "$REPO_ROOT/install.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "install.sh --bogus exits 2 with unknown arg message" {
    run bash "$REPO_ROOT/install.sh" --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"unknown arg"* ]]
}
