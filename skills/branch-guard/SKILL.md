---
name: branch-guard
description: Enforce "never write on main/master/trunk". Backing PreToolUse hook blocks Write/Edit/MultiEdit/NotebookEdit when HEAD is on a protected branch, aborting with exit 2. This skill documents the rule and provides the "branch off and continue" recipe Claude should reach for whenever the guard fires or whenever a task begins on a protected branch. Auto-trigger when the guard blocks a write, when the user asks "am I on main?" / "create a new branch", or at the start of any task that will write to a git repo.
version: 0.1.0
---

# branch-guard — never write on protected branches

Direct writes to `main` / `master` / `trunk` are the most common cause of "oh no I pushed straight to main". A hook (installed by this project's `install.sh`) enforces the rule at tool-call time; this skill teaches the recovery flow.

## What the hook does

PreToolUse hook `~/.claude/hooks/branch-guard.sh`:
- Runs before `Write` / `Edit` / `MultiEdit` / `NotebookEdit`.
- Runs `git rev-parse --abbrev-ref HEAD` in the tool's target directory.
- If the current branch is `main` / `master` / `trunk` (or configured as protected), exits 2 with a message.
- If not in a git repo, exits 0 (no-op).

Bypass:
- `WW_ALLOW_MAIN_WRITE=1` env var (temporary, for CI / setup scripts).
- Writing to non-repo paths (`~/.claude/`, `/tmp/`, etc.).

## When this skill triggers

- The hook blocked a write. The tool result will include `exit code 2` and a message like "branch-guard: refuse write on protected branch 'main'".
- The user asks "am I on main?" / "let's branch" / "create a new branch".
- You're about to start a task that will write to a git repo and haven't verified the branch.

## Recovery recipe

```sh
# 1. Confirm current state
git status
git rev-parse --abbrev-ref HEAD

# 2. Branch off. Name the branch by scope:
#    feat/<short-scope>       — a feature
#    fix/<issue-or-symptom>   — a bug fix
#    chore/<what>             — non-code (docs, deps, config)
git checkout -b feat/<scope>

# 3. Re-attempt the write. The hook now allows it.
```

## Do NOT

- Set `WW_ALLOW_MAIN_WRITE=1` in your shell rc permanently. That defeats the guard for interactive sessions.
- Force-push after branching. The commit stays on the feature branch; `main` is untouched.
- Use `git commit --amend` on `main` to "fix" the guard. If you got here, your prior commit is still on `main` — reset it: `git reset --soft HEAD~1` (moves the change back to staged), branch off, commit again on the branch, `git push` on the branch, PR normally.

## Configuration

The hook reads `WW_PROTECTED_BRANCHES` env var (comma-separated, default `main,master,trunk`). Set it in your shell rc if your repo uses a different name.

```sh
# Example: also protect a release branch
export WW_PROTECTED_BRANCHES="main,master,trunk,release"
```
