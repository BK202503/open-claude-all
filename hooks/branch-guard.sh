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
#   - Default (fail-open): exits 0 if the payload has no file_path, if the
#     target is not inside a git repo, or if the branch cannot be resolved.
#   - Strict (fail-closed): with WW_STRICT=1, those same cases exit 2 unless
#     the target lives under a WW_STRICT_ALLOWLIST prefix.
#
# Bypass:
#   - Set WW_ALLOW_MAIN_WRITE=1 for temporary bypass (CI, setup scripts).
#   - Configure WW_PROTECTED_BRANCHES (comma-separated) to override defaults.
#   - Configure WW_STRICT_ALLOWLIST (colon-separated path prefixes) for
#     always-allowed sinks under strict mode.
#     Default: $HOME/.claude:/tmp:/var/tmp

set -uo pipefail

if [ "${WW_ALLOW_MAIN_WRITE:-}" = "1" ]; then
    exit 0
fi

protected="${WW_PROTECTED_BRANCHES:-main,master,trunk}"
strict="${WW_STRICT:-0}"
strict_allowlist="${WW_STRICT_ALLOWLIST:-$HOME/.claude:/tmp:/var/tmp}"

# Called when we cannot resolve the target's git branch.
# Default: allow (fail-open). Strict: block unless allowlisted.
deny_or_allow() {
    local path="$1" reason="$2"
    if [ "$strict" != "1" ]; then
        exit 0
    fi

    if [ -n "$path" ]; then
        IFS=':' read -r -a allow_list <<< "$strict_allowlist"
        for prefix in "${allow_list[@]}"; do
            [ -n "$prefix" ] || continue
            case "$path" in
                "$prefix"|"$prefix"/*) exit 0 ;;
            esac
        done
    fi

    echo "branch-guard[strict]: refuse write — $reason (path: $path)." >&2
    echo "allowlist prefixes (WW_STRICT_ALLOWLIST): $strict_allowlist" >&2
    echo "bypass (careful):  WW_ALLOW_MAIN_WRITE=1" >&2
    exit 2
}

# Read tool call JSON from stdin
payload="$(cat)"
file_path="$(echo "$payload" | /usr/bin/env python3 -c 'import json,sys;d=json.load(sys.stdin);print(d.get("tool_input",{}).get("file_path",""))' 2>/dev/null || echo "")"

if [ -z "$file_path" ]; then
    deny_or_allow "" "no file_path in tool input"
fi

# Resolve directory containing the target file
if [ -d "$file_path" ]; then
    target_dir="$file_path"
else
    target_dir="$(dirname "$file_path")"
fi

# Not in a git repo? default fail-open; strict: block unless allowlisted.
branch="$(cd "$target_dir" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    || deny_or_allow "$file_path" "target is not inside a git repo"

if [ -z "$branch" ]; then
    deny_or_allow "$file_path" "could not determine current branch"
fi

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
