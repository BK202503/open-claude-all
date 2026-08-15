# open-claude-all

[![npm](https://img.shields.io/npm/v/open-claude-all.svg)](https://www.npmjs.com/package/open-claude-all)
[![license](https://img.shields.io/npm/l/open-claude-all.svg)](LICENSE)

Harness engineering for Claude Code. Skills and hooks that catch issues before PRs land, block unsafe writes, and map the blast radius of every change.


## Install

```sh
npx open-claude-all
```

Restart Claude Code after install, then run `/status` to confirm skills are active.

Other install paths:

| Path | Command |
| --- | --- |
| Plugin marketplace | `/plugin marketplace add BK202503/open-claude-all` |
| curl | `curl -fsSL https://bk202503.github.io/open-claude-all/get \| bash` |
| Git clone | `git clone https://github.com/BK202503/open-claude-all.git ~/.open-claude-all && ~/.open-claude-all/install.sh` |

To pin a version: `npx open-claude-all@0.1.3`

### Codex CLI

Install only the Codex CLI assets without changing Claude Code settings:

```sh
npx open-claude-all --target codex
```

Install both CLIs explicitly:

```sh
npx open-claude-all --target both
```

Claude Code assets install under `~/.claude`; Codex CLI assets install under
`${CODEX_HOME:-~/.codex}`. They do not share settings, hooks, or skills.

Codex CLI support currently includes `codex-project-policy`, `codex-review`,
`codex-pr-impact-scan`, and the JVM, Kotlin coroutine, Spring Kafka, React,
Next.js, and NestJS reviewers. Invoke a skill with `$skill-name` in Codex.


## What's inside

### PR review pipeline

Run `/review` and the skills below chain together automatically.

| Skill | What it does |
| --- | --- |
| `review` | Detects file types in the diff and routes to the right specialist skills. AUTO-INVOKEs `review-loop` when must-fix findings are found. |
| `review-loop` | Runs review, auto-fixes deterministic issues (em dashes, AI footers, code-restating comments), re-runs review, repeats until clean or 5 iterations max. Passes judgment calls to you. |
| `ai-tell-cleanup` | Removes AI writing tells from comments, commit messages, and PR bodies. Runs automatically after edits. Disable with `"ai-tell-cleanup off"`. |
| `pr-impact-scan` | Before opening a PR, traces every caller of changed functions, checks signature compatibility, identifies missing tests, and drafts the PR body. |

### Java / Kotlin

| Skill | What it catches |
| --- | --- |
| `jvm-memory-leak-review` | Static collection accumulation, ThreadLocal not removed, listener not unregistered, unbounded caches, unclosed resources, bean scope mismatch, `@Async` shared state, Kotlin Channel/Flow leaks. AUTO-INVOKEs on `.java` / `.kt` diffs. |
| `kotlin-coroutine-review` | Blocking calls in suspend functions, `GlobalScope` leaks, dispatcher misuse, missing `CoroutineExceptionHandler`, Flow back-pressure issues. |
| `spring-kafka-listener-review` | `DefaultErrorHandler` misconfiguration, `@RetryableTopic` pitfalls, ack mode correctness, DLT wiring gaps, suspend `@KafkaListener` version compatibility. |

### React / Next.js

| Skill | What it catches |
| --- | --- |
| `react-hooks-review` | `useEffect` dep-array bugs, stale closures, functional-updater misses, list-key anti-patterns, async-effect cleanup leaks. |
| `nextjs-app-router-review` | Server/client component boundary mistakes, `fetch` cache misuse, async params in Next 15+, server secrets leaking into client bundles. |
| `frontend-perf-impact-scan` | Bundle bloat, LCP/CLS risks, network waterfalls, hydration mismatch. Ranked Blocker / Watch / Nit. |

### NestJS

| Skill | What it catches |
| --- | --- |
| `nestjs-provider-review` | Injection-scope misuse, circular deps hidden by `forwardRef`, missing module exports, filter/interceptor/pipe/guard ordering pitfalls. |

### Parallel work

| Skill | When to use |
| --- | --- |
| `parallel-dev` | Fan out N independent coding tasks, each in its own git worktree. Parent merges sequentially after reviewing each diff. Use when any unit writes to disk. |
| `parallel-dispatch` | Fan out N read-only lookups (PR status, log queries, etc.) in one response. No worktrees, fast. |

### Safety

| Hook | What it does |
| --- | --- |
| `branch-guard` | Blocks file edits on `main` / `master` / `trunk` via a PreToolUse hook. |

### Agents

| Agent | What it does |
| --- | --- |
| `pr-reviewer` | Checks scope discipline, impact enumeration, and commit hygiene in one shot. Ranks findings Blocker / Watch / Nit. |
| `pr-impact-runner` | Takes a PR URL, runs `pr-impact-scan`, returns a compact ranked report. |
| `diff-scoped-reviewer` | Read-only agent used via `context: fork` by the language-specific review skills. Determines its own diff scope (base branch → changed files → matching extensions) before applying the invoking skill's checklist, so it never scans the whole repo and can't modify the code it's reviewing. |


## Configuration

`branch-guard` reads these environment variables (all optional):

| Variable | Default | Effect |
| --- | --- | --- |
| `WW_PROTECTED_BRANCHES` | `main,master,trunk` | Branches to block writes on |
| `WW_ALLOW_MAIN_WRITE=1` | off | Temporary bypass for CI / setup scripts |
| `WW_STRICT=1` | off | Fail-closed: unknown branch = deny |
| `WW_STRICT_ALLOWLIST` | `$HOME/.claude:/tmp:/var/tmp` | Paths allowed even under strict mode |


## Requirements

- Claude Code v2.1+
- `jq` (for hook wiring; installer prints manual instructions if missing)

## Uninstall

```sh
~/.open-claude-all/uninstall.sh
```

Only removes what this repo installed. Your own skills and hooks are untouched.

## Contributing

PRs target the `dev` branch. Full rules in [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. See `LICENSE`.
