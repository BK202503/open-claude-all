#!/usr/bin/env bash
# open-claude-all uninstaller.
# Removes Claude Code or Codex CLI assets installed by install.sh.
# Does NOT touch skills/agents you created yourself — only removes the
# names shipped by this repo.
#
# Usage:
#   ./uninstall.sh            # remove Claude Code assets (backward compatible)
#   ./uninstall.sh --target codex
#   ./uninstall.sh --target both
#   ./uninstall.sh --dry-run  # print what would happen, do nothing

set -euo pipefail

DRY=0
TARGET=claude
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY=1 ;;
        --target=claude) TARGET=claude ;;
        --target=codex) TARGET=codex ;;
        --target=both) TARGET=both ;;
        --help|-h)
            grep '^#' "$0" | head -12
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

repo_root="$(cd "$(dirname "$0")" && pwd)"
claude_dir="$HOME/.claude"
codex_dir="${CODEX_HOME:-$HOME/.codex}"

# run: execute argv directly (no eval / no shell reparse).
run() {
    if [ "$DRY" = 1 ]; then
        printf 'DRY:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

uninstall_claude() {
echo "==> removing skills"
shopt -s nullglob
for src in "$repo_root/skills/"*/; do
    name="$(basename "$src")"
    dst="$claude_dir/skills/$name"
    if [ -d "$dst" ]; then
        run rm -rf "$dst"
    fi
done

echo "==> removing agents"
for src in "$repo_root/agents/"*.md; do
    name="$(basename "$src")"
    dst="$claude_dir/agents/$name"
    if [ -f "$dst" ]; then
        run rm "$dst"
    fi
done
shopt -u nullglob

echo "==> removing hooks"
if [ -f "$claude_dir/hooks/branch-guard.sh" ]; then
    run rm "$claude_dir/hooks/branch-guard.sh"
fi

echo "==> unwiring branch-guard from settings.json"
if [ ! -f "$claude_dir/settings.json" ]; then
    echo "    no settings.json — nothing to unwire"
elif ! command -v jq >/dev/null 2>&1; then
    echo "!! jq not installed. Remove the branch-guard hook entry from"
    echo "   $claude_dir/settings.json manually (look for command containing"
    echo "   'branch-guard.sh' under .hooks.PreToolUse)."
else
    if [ "$DRY" = 1 ]; then
        echo "DRY: would strip branch-guard hook entry from $claude_dir/settings.json"
    else
        tmp="$(mktemp)"
        jq '(.hooks.PreToolUse // []) |= map(select(.hooks // [] | map(.command // "") | any(contains("branch-guard.sh")) | not))' \
            "$claude_dir/settings.json" > "$tmp" && mv "$tmp" "$claude_dir/settings.json"
        echo "    unwired."
    fi
fi

echo
echo "done. Restart your Claude Code session for the changes to take effect."
}

uninstall_codex() {
    echo "==> removing Codex CLI skills"
    shopt -s nullglob
    for src in "$repo_root/codex/skills/"*/; do
        name="$(basename "$src")"
        dst="$codex_dir/skills/$name"
        if [ -d "$dst" ]; then
            run rm -rf "$dst"
        fi
    done
    shopt -u nullglob
    echo
    echo "done. Start a new Codex CLI session for the removal to take effect."
}

case "$TARGET" in
    claude) uninstall_claude ;;
    codex) uninstall_codex ;;
    both)
        uninstall_claude
        uninstall_codex
        ;;
esac
