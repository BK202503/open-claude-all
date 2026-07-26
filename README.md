# open-claude-all

[![npm](https://img.shields.io/npm/v/open-claude-all.svg)](https://www.npmjs.com/package/open-claude-all)
[![license](https://img.shields.io/npm/l/open-claude-all.svg)](LICENSE)

Claude Code skills and hooks focused on **shipping clean PRs and pre-verifying the impact on existing code**.

npm: https://www.npmjs.com/package/open-claude-all

## Why use this

Claude Code writes code fine on its own. What it tends to miss is what happens **right before that code goes out as a PR**:

1. **Is the PR clean?** Scope drifted, commit messages restate the diff, unrelated refactors slipped in.
2. **What does it touch in existing code?** Every caller of a signature that changed, every reference to a renamed config key, N+1 regressions, known regression patterns.

This repository automates those two axes:

- **(A) Clean PRs.** Scope discipline, commit style that lowers the review bar, blocking direct writes to protected branches.
- **(B) Impact verification on existing code.** `pr-impact-scan` enumerates caller / test / config blind spots. Domain-specific review skills (Spring Kafka listener, Kotlin coroutine) catch known regression patterns before they land.

Competing frameworks (oh-my-claudecode, claude-forge, etc.) focus mostly on "writing code" automation (agent orchestration, prompt injection, etc.). This project specializes in the back end: **getting the code you already wrote safely out as a PR**.

## What's inside

### Impact and PR quality (general)

- `pr-impact-scan`: enumerate every caller of changed functions / classes / config keys, judge signature compatibility, compute test coverage delta, draft PR body.
- `parallel-dispatch`: parallel read (status / lookup) fan-out.
- `parallel-dev`: worktree-isolated parallel development (write).
- `branch-guard`: block direct writes to `main` / `master` / `trunk` (backed by a PreToolUse hook).

### Kotlin / JVM Spring track

- `spring-kafka-listener-review`: catches known regression patterns around `DefaultErrorHandler`, `@RetryableTopic`, ack mode, DLT wiring, suspend `@KafkaListener` version gaps, and more.
- `kotlin-coroutine-review`: structured-concurrency violations, blocking-in-suspend, dispatcher misuse, `GlobalScope` leaks, missing `CoroutineExceptionHandler`, and more.

## Install

Lightest path (requires Node 18+):

```sh
npx open-claude-all
```

Options:
- `npx open-claude-all --dry-run`: print what would happen, change nothing.
- `npx open-claude-all --skip-hook`: install skills only, skip `branch-guard` hook wiring.
- `npx open-claude-all uninstall`: reverse the install.

If you would rather not use Node, clone the repo and run the scripts directly:

```sh
git clone https://github.com/BK202503/open-claude-all.git ~/.open-claude-all
~/.open-claude-all/install.sh
```

Restart your Claude Code session, then run `/status` to confirm the skills are picked up.

## Requires

- Claude Code v2.1+ (skills / hooks support).
- `jq` (used only for hook wiring; without it the installer skips wiring and prints manual instructions).

## Configure (environment variables, all optional)

- `WW_PROTECTED_BRANCHES`: branches `branch-guard` blocks. Default `main,master,trunk`.
- `WW_ALLOW_MAIN_WRITE=1`: temporary bypass for `branch-guard` (CI / setup scripts).

## Uninstall

```sh
~/.open-claude-all/uninstall.sh
```

Only removes items installed by this repo. Skills and hooks you created yourself are untouched.

## Design principles

- **Read-only fan-out is safe; write fan-out needs isolation.** `parallel-dispatch` is read; `parallel-dev` uses worktree isolation for writes.
- **Scope discipline.** One PR / commit does not mix concerns. `pr-impact-scan` enforces this.
- **Impact-first review.** Understanding what the new code touches comes before writing more code.
- **Never write on protected branches.** The `branch-guard` hook blocks file edits on `main` / `master` / `trunk`.

## Non-goals

- Reimplementing or replacing Claude Code core.
- A multi-agent orchestration framework.
- A build / test wrapper for every language. Project-native commands are used as-is.
- An interactive orchestration UI.

## Contributing

PRs target the `dev` branch. Full rules in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. See `LICENSE`.
