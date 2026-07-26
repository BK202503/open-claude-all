#!/usr/bin/env bash
# open-claude-all installer.
# Copies skills, agents, and hooks into ~/.claude and wires the branch-guard hook into settings.json.
# Idempotent (rsync); safe to re-run.
#
# Usage:
#   ./install.sh                # install everything
#   ./install.sh --dry-run      # print what would happen, do nothing
#   ./install.sh --skip-hook    # skills + agents only, no hook wiring

set -euo pipefail

DRY=0
SKIP_HOOK=0
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY=1 ;;
        --skip-hook) SKIP_HOOK=1 ;;
        --help|-h)
            grep '^#' "$0" | head -20
            exit 0
            ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

repo_root="$(cd "$(dirname "$0")" && pwd)"
claude_dir="$HOME/.claude"

run() {
    if [ "$DRY" = 1 ]; then echo "DRY: $*"; else eval "$@"; fi
}

echo "==> installing to $claude_dir"
run "mkdir -p '$claude_dir/skills' '$claude_dir/agents' '$claude_dir/hooks'"

echo "==> skills"
for src in "$repo_root/skills/"*/; do
    name="$(basename "$src")"
    dst="$claude_dir/skills/$name"
    if [ -d "$dst" ]; then
        echo "    skill '$name' already present — merging (rsync)."
    fi
    run "rsync -a --delete '$src' '$dst/'"
done

echo "==> agents"
for src in "$repo_root/agents/"*.md; do
    [ -e "$src" ] || continue
    name="$(basename "$src")"
    run "cp '$src' '$claude_dir/agents/$name'"
done

echo "==> hooks"
run "cp '$repo_root/hooks/branch-guard.sh' '$claude_dir/hooks/branch-guard.sh'"
run "chmod +x '$claude_dir/hooks/branch-guard.sh'"

if [ "$SKIP_HOOK" = 1 ]; then
    echo "==> --skip-hook — not wiring branch-guard into settings.json"
    exit 0
fi

echo "==> wiring branch-guard into $claude_dir/settings.json"
if [ ! -f "$claude_dir/settings.json" ]; then
    run "echo '{}' > '$claude_dir/settings.json'"
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
    exit 0
fi

already="$(jq '.hooks.PreToolUse // [] | map(select(.matcher // "" | contains("Write"))) | length' "$claude_dir/settings.json" 2>/dev/null || echo 0)"
if [ "$already" != "0" ]; then
    echo "    branch-guard-like hook already present — not modifying settings.json"
else
    tmp="$(mktemp)"
    if [ "$DRY" = 1 ]; then
        echo "DRY: would merge branch-guard hook into settings.json"
    else
        jq '. + {hooks: ((.hooks // {}) + {PreToolUse: (((.hooks // {}).PreToolUse // []) + [{
            matcher: "Write|Edit|MultiEdit|NotebookEdit",
            hooks: [{ type: "command", command: ("\(env.HOME)/.claude/hooks/branch-guard.sh") }]
        }])})}' "$claude_dir/settings.json" > "$tmp" && mv "$tmp" "$claude_dir/settings.json"
        echo "    wired."
    fi
fi

echo
echo "done. Restart your Claude Code session to load the new skills."
