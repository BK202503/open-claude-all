# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - 2026-07-28

### Added
- Claude Code plugin marketplace support: `.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json` + `hooks/hooks.json`. Install via `/plugin marketplace add BK202503/open-claude-all`.
- `agents/` starter set: `pr-reviewer` and `pr-impact-runner`, both with explicit Bash command allowlists to close prompt-injection exec paths.
- `parallel-pr` skill for one-PR-per-unit upstream fan-out (complements `parallel-dev` which merges locally).
- `branch-guard`: `WW_STRICT=1` fail-closed mode. When set, the hook denies writes if it cannot determine the current branch, instead of allowing them.
- Bats smoke tests covering `install.sh`, `uninstall.sh`, and the `branch-guard` hook.
- Release-tag pinning guidance in `README.md` for `curl | bash` and `npx` install paths.
- CI: fork-repo gate on `npm-pack` job so untrusted PRs cannot exec via `npx <tarball>`.

### Changed
- README `Install` section restructured: tabular overview + `###` per-path headers, marketplace listed first as recommended path.
- `install.sh` / `uninstall.sh`: dropped `eval` from the internal `run()` helper. Reduces the shell-injection surface.
- `branch-guard`: bounded stdin at 1 MiB before `python3 json.load` (DoS cap); `cd --` guards against dash-prefixed paths.
- `package.json.files`: include `agents/` and `.claude-plugin/` so npm consumers get the full skill/agent/plugin manifest set.

## [0.1.2] - 2026-07-27

Initial npm publish.

- Skills: `pr-impact-scan`, `spring-kafka-listener-review`, `kotlin-coroutine-review`, `react-hooks-review`, `nextjs-app-router-review`, `nestjs-provider-review`, `frontend-perf-impact-scan`, `parallel-dev`, `parallel-dispatch`, `branch-guard`.
- Hook: `branch-guard` PreToolUse.
