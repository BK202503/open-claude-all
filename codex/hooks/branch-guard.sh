#!/usr/bin/env bash
# Codex PreToolUse hook: block write-capable operations on protected branches.
set -uo pipefail

[ "${WW_ALLOW_MAIN_WRITE:-}" = "1" ] && exit 0

payload="$(head -c 1048576)"
read_json() {
    printf '%s' "$payload" | /usr/bin/env python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit
value = data
for key in sys.argv[1].split("."):
    if not isinstance(value, dict):
        print("")
        raise SystemExit
    value = value.get(key, "")
print(value if isinstance(value, str) else "")
' "$1" 2>/dev/null
}

tool="$(read_json tool_name)"
[ -n "$tool" ] || tool="$(read_json tool)"
[ -n "$tool" ] || tool="$(read_json name)"
command="$(read_json tool_input.command)"
[ -n "$command" ] || command="$(read_json tool_input.cmd)"

write=0
case "$tool" in
    apply_patch|write_stdin|write_file|edit_file) write=1 ;;
    exec_command|Bash|bash)
        case "$command" in
            *' >'*|*'>>'*|*'tee '*|*'sed -i'*|*'perl -i'*|*'cp '*|*'mv '*|*'rm '*|*'git add'*|*'git commit'*|*'git switch'*|*'git checkout'*|*'git reset'*) write=1 ;;
        esac
        ;;
esac

[ "$write" = 1 ] || exit 0

cwd="$(read_json cwd)"
[ -n "$cwd" ] || cwd="$(read_json tool_input.cwd)"
[ -n "$cwd" ] || cwd="$(pwd)"
branch="$(cd -- "$cwd" 2>/dev/null && git symbolic-ref --quiet --short HEAD 2>/dev/null)" \
    || branch="$(cd -- "$cwd" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    || exit 0

IFS=',' read -r -a protected <<< "${WW_PROTECTED_BRANCHES:-main,master,trunk}"
for candidate in "${protected[@]}"; do
    if [ "$branch" = "$candidate" ]; then
        echo "branch-guard: refuse write-capable Codex operation on protected branch '$branch'." >&2
        echo "Create a feature branch first, or use WW_ALLOW_MAIN_WRITE=1 for an explicit temporary bypass." >&2
        exit 2
    fi
done
