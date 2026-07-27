#!/usr/bin/env bats
# Smoke tests for uninstall.sh.
# Dry-run only; nothing here touches ~/.claude.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
}

@test "uninstall.sh --dry-run exits 0" {
    run bash "$REPO_ROOT/uninstall.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"removing skills"* ]]
}

@test "uninstall.sh --help prints usage and exits 0" {
    run bash "$REPO_ROOT/uninstall.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}
