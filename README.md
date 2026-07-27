# open-claude-all

[![npm](https://img.shields.io/npm/v/open-claude-all.svg)](https://www.npmjs.com/package/open-claude-all)
[![license](https://img.shields.io/npm/l/open-claude-all.svg)](LICENSE)

Claude Code skills and hooks focused on **shipping clean PRs and pre-verifying the impact on existing code**.

npm: https://www.npmjs.com/package/open-claude-all

## Install

Four install paths. Pick whichever fits your environment.

**A. `curl | bash` (no Node required)**

```sh
curl -fsSL https://bk202503.github.io/open-claude-all/get | bash
```

Downloads the latest `main` from GitHub and runs `install.sh`. Works on any POSIX shell (macOS, Linux, WSL). Forward flags after `bash -s --`, e.g.:

```sh
curl -fsSL https://bk202503.github.io/open-claude-all/get | bash -s -- --dry-run
curl -fsSL https://bk202503.github.io/open-claude-all/get | bash -s -- --skip-hook
```

*Pinning to a release tag.* `curl | bash` against a moving `main` is a supply-chain risk — you get whatever HEAD looks like at fetch time. Once release tags exist, pin explicitly:

```sh
# via get.sh (planned; OCA_REF support is not yet wired in the get endpoint):
OCA_REF=v0.1.3 curl -fsSL https://bk202503.github.io/open-claude-all/get | bash

# direct from GitHub at a tag (works today, once the tag is pushed):
curl -fsSL https://raw.githubusercontent.com/BK202503/open-claude-all/v0.1.3/install.sh | bash
```

For the npm path, pin the version explicitly: `npx open-claude-all@0.1.3`.

**B. `npx` (requires Node 18+)**

```sh
npx open-claude-all
```

Options:
- `npx open-claude-all --dry-run`: print what would happen, change nothing.
- `npx open-claude-all --skip-hook`: install skills only, skip `branch-guard` hook wiring.
- `npx open-claude-all uninstall`: reverse the install.

**C. Git clone (fully manual)**

```sh
git clone https://github.com/BK202503/open-claude-all.git ~/.open-claude-all
~/.open-claude-all/install.sh
```

**D. Claude Code plugin marketplace** (recommended for Claude Code v2.1+ users)

```sh
/plugin marketplace add BK202503/open-claude-all
/plugin install open-claude-all@open-claude-all
```

Auto-discovers skills + wires branch-guard hook. No shell script needed.

This coexists with `install.sh` — pick whichever fits. The marketplace path handles updates via `/plugin update`; skills install namespaced as `/open-claude-all:<skill-name>`.

After any path, restart your Claude Code session, then run `/status` to confirm the skills are picked up.

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

### `parallel-dispatch` vs `parallel-dev` — when to use which

Same "fan out N subagents in one response" shape, different safety envelope.

- **Read fan-out → `parallel-dispatch`.** No worktree, no writes, no isolation. Example:
  - *"Check the status of PR #22536, #4523, and #18103 in parallel"* → three read-only subagents fan out, each calls `gh pr view`, results are aggregated in one reply.
- **Write fan-out → `parallel-dev`.** Each unit gets its own git worktree, file scopes must be non-overlapping, and the parent merges branches back sequentially after reviewing each diff. Example:
  - *"Build the login page, the settings page, and the API client at once"* → three worktree-isolated `general-purpose` agents, disjoint directories, sequential `--no-ff` merge back to base.

Rule of thumb: if any unit writes to disk, use `parallel-dev`. If every unit is read-only, use `parallel-dispatch`.

### Kotlin / JVM Spring track

- `spring-kafka-listener-review`: catches known regression patterns around `DefaultErrorHandler`, `@RetryableTopic`, ack mode, DLT wiring, suspend `@KafkaListener` version gaps, and more.
- `kotlin-coroutine-review`: structured-concurrency violations, blocking-in-suspend, dispatcher misuse, `GlobalScope` leaks, missing `CoroutineExceptionHandler`, and more.

### React / Next.js track

- `react-hooks-review`: `useEffect` dep-array bugs, stale closures, functional-updater misses, over-memoization, list-key anti-patterns, async-effect cleanup leaks, silent Rules-of-Hooks violations.
- `nextjs-app-router-review`: server / client component boundary mistakes, `fetch` cache and revalidate misuse, async `params` / `searchParams` in Next 15+, server-only secrets leaking into client bundles, hydration mismatches, route handler pitfalls.
- `frontend-perf-impact-scan`: the frontend counterpart to `pr-impact-scan`. Enumerates concrete perf regressions in a diff (bundle bloat, LCP / CLS risks, network waterfalls, hydration mismatch surface) and ranks them Blocker / Watch / Nit before you PR.

### NestJS track

- `nestjs-provider-review`: injection-scope misuse, circular deps hidden by `forwardRef`, missing module `exports`, exception-filter / interceptor / pipe / guard ordering pitfalls, async-provider typing gaps.

### Agents

Agents wrap the skills above for one-shot invocation against a concrete PR.

- `pr-reviewer`: opinionated PR reviewer aligned with this repo's clean-PR philosophy. Checks scope discipline, impact enumeration, commit hygiene, and AI-attribution rules. Ranks findings Blocker / Watch / Nit.
- `pr-impact-runner`: thin dispatcher over `pr-impact-scan`. Takes a PR URL, fetches the diff, runs the impact-scan flow, returns a compact ranked report.

## Requires

- Claude Code v2.1+ (skills / hooks support).
- `jq` (used only for hook wiring; without it the installer skips wiring and prints manual instructions).

## Configure (environment variables, all optional)

- `WW_PROTECTED_BRANCHES`: branches `branch-guard` blocks. Default `main,master,trunk`.
- `WW_ALLOW_MAIN_WRITE=1`: temporary bypass for `branch-guard` (CI / setup scripts).
- `WW_STRICT=1`: fail-closed mode for `branch-guard`. Payloads with no `file_path`, targets outside a git repo, and unresolvable branches are **blocked** instead of allowed. Combine with `WW_STRICT_ALLOWLIST` to whitelist known-safe sinks.
- `WW_STRICT_ALLOWLIST`: colon-separated path prefixes that stay allowed under `WW_STRICT=1`. Default `$HOME/.claude:/tmp:/var/tmp`.

Default is fail-open (unchanged): if `branch-guard` cannot resolve the target's git branch, the write proceeds. Set `WW_STRICT=1` in environments where "unknown = deny" is the right policy (shared machines, CI sandboxes, review workflows).

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
