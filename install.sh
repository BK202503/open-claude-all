#!/usr/bin/env bash
# open-claude-all installer.
# Installs Claude Code or Codex CLI assets without mixing their configuration roots.
# Idempotent (rsync); safe to re-run.
#
# Usage:
#   ./install.sh                # install Claude Code assets (backward compatible)
#   ./install.sh --target codex # install Codex CLI skills only
#   ./install.sh --target both  # install assets for both CLIs
#   ./install.sh --dry-run      # print what would happen, do nothing
#   ./install.sh --skip-hook    # skills + agents only, no hook wiring

set -euo pipefail

DRY=0
SKIP_HOOK=0
TARGET=claude
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY=1 ;;
        --skip-hook) SKIP_HOOK=1 ;;
        --target=claude) TARGET=claude ;;
        --target=codex) TARGET=codex ;;
        --target=both) TARGET=both ;;
        --help|-h)
            grep '^#' "$0" | head -20
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

repo_root="$(cd "$(dirname "$0")" && pwd)"
claude_dir="$HOME/.claude"
codex_dir="${CODEX_HOME:-$HOME/.codex}"

# run: execute argv directly (no eval / no shell reparse).
# For DRY, print a shell-quoted preview of what would run.
run() {
    if [ "$DRY" = 1 ]; then
        printf 'DRY:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

install_claude() {
echo "==> installing to $claude_dir"
run mkdir -p "$claude_dir/skills" "$claude_dir/agents" "$claude_dir/hooks"

echo "==> skills"
shopt -s nullglob
for src in "$repo_root/skills/"*/; do
    name="$(basename "$src")"
    dst="$claude_dir/skills/$name"
    if [ -d "$dst" ]; then
        echo "    skill '$name' already present — merging (rsync)."
    fi
    run rsync -a --delete "$src" "$dst/"
done

echo "==> agents"
for src in "$repo_root/agents/"*.md; do
    name="$(basename "$src")"
    run cp "$src" "$claude_dir/agents/$name"
done
shopt -u nullglob

echo "==> hooks"
run cp "$repo_root/hooks/branch-guard.sh" "$claude_dir/hooks/branch-guard.sh"
run chmod +x "$claude_dir/hooks/branch-guard.sh"

if [ "$SKIP_HOOK" = 1 ]; then
    echo "==> --skip-hook — not wiring branch-guard into settings.json"
    return
fi

echo "==> wiring branch-guard into $claude_dir/settings.json"
if [ ! -f "$claude_dir/settings.json" ]; then
    if [ "$DRY" = 1 ]; then
        echo "DRY: init empty settings.json at $claude_dir/settings.json"
    else
        printf '{}\n' > "$claude_dir/settings.json"
    fi
fi

# Add branch-guard hook if not already present.
# We use jq to preserve any existing settings.
if ! command -v jq >/dev/null 2>&1; then
    echo "!! jq not installed. Install it (brew install jq) or wire branch-guard manually:"
    cat <<'EOF'
    add to ~/.claude/settings.json:
    {
      "hooks": {
        "PreToolUse": [{
          "matcher": "Write|Edit|MultiEdit|NotebookEdit",
          "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/branch-guard.sh" }]
        }]
      }
    }
EOF
    return
fi

already="$(jq '.hooks.PreToolUse // [] | map(select(.matcher // "" | contains("Write"))) | length' "$claude_dir/settings.json" 2>/dev/null || echo 0)"
if [ "$already" != "0" ]; then
    echo "    branch-guard-like hook already present — not modifying settings.json"
else
    if [ "$DRY" = 1 ]; then
        echo "DRY: would merge branch-guard hook into $claude_dir/settings.json"
    else
        tmp="$(mktemp)"
        jq '. + {hooks: ((.hooks // {}) + {PreToolUse: (((.hooks // {}).PreToolUse // []) + [{
            matcher: "Write|Edit|MultiEdit|NotebookEdit",
            hooks: [{ type: "command", command: ("\(env.HOME)/.claude/hooks/branch-guard.sh") }]
        }])})}' "$claude_dir/settings.json" > "$tmp" && mv "$tmp" "$claude_dir/settings.json"
        echo "    wired."
    fi
fi

echo
echo "done. Restart your Claude Code session to load the new skills."
}

install_codex() {
    echo "==> installing Codex CLI skills to $codex_dir"
    run mkdir -p "$codex_dir/skills"
    shopt -s nullglob
    for src in "$repo_root/codex/skills/"*/; do
        name="$(basename "$src")"
        dst="$codex_dir/skills/$name"
        if [ -d "$dst" ]; then
            echo "    skill '$name' already present — merging (rsync)."
        fi
        run rsync -a --delete "$src" "$dst/"
    done
    shopt -u nullglob
    echo "done. Start a new Codex CLI session to use the installed skills."
}

case "$TARGET" in
    claude) install_claude ;;
    codex) install_codex ;;
    both)
        install_claude
        install_codex
        ;;
esac
