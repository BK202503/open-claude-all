#!/usr/bin/env bash
# branch-guard PreToolUse hook — refuse writes on protected branches.
#
# Wired via ~/.claude/settings.json:
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "matcher": "Write|Edit|MultiEdit|NotebookEdit",
#         "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/branch-guard.sh" }]
#       }]
#     }
#   }
#
# Behaviour:
#   - Reads the tool input from stdin (JSON with .tool_input.file_path).
#   - Resolves the git repo for that path.
#   - Exits 2 (block) if current branch is in $WW_PROTECTED_BRANCHES.
#   - Exits 0 (allow) if not in a git repo, or on any other error.
#
# Bypass:
#   - Set WW_ALLOW_MAIN_WRITE=1 for temporary bypass (CI, setup scripts).
#   - Configure WW_PROTECTED_BRANCHES (comma-separated) to override defaults.

set -uo pipefail

if [ "${WW_ALLOW_MAIN_WRITE:-}" = "1" ]; then
    exit 0
fi

protected="${WW_PROTECTED_BRANCHES:-main,master,trunk}"

# Read tool call JSON from stdin
payload="$(cat)"
file_path="$(echo "$payload" | /usr/bin/env python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || echo "")"

if [ -z "$file_path" ]; then
    exit 0
fi

# Resolve directory containing the target file
if [ -d "$file_path" ]; then
    target_dir="$file_path"
else
    target_dir="$(dirname "$file_path")"
fi

# Not in a git repo? no-op
branch="$(cd "$target_dir" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
[ -z "$branch" ] && exit 0

# Is current branch protected?
IFS=',' read -r -a protected_list <<< "$protected"
for p in "${protected_list[@]}"; do
    if [ "$branch" = "$p" ]; then
        echo "branch-guard: refuse write on protected branch '$branch' (path: $file_path)." >&2
        echo "branch off first:  git checkout -b feat/<scope>" >&2
        echo "bypass (careful):  WW_ALLOW_MAIN_WRITE=1" >&2
        exit 2
    fi
done

exit 0
