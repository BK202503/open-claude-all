# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.3] - unreleased

### Added
- `branch-guard`: `WW_STRICT=1` fail-closed mode (PR-2). When set, the hook denies writes if it cannot determine the current branch, instead of allowing them.
- Bats smoke tests covering `install.sh`, `uninstall.sh`, and the `branch-guard` hook (PR-3).
- `CHANGELOG.md` and release-tag pinning guidance in `README.md` for `curl | bash` and `npx` install paths (this PR).

### Changed
- `install.sh` / `uninstall.sh`: dropped `eval` from the internal `run()` helper (PR-1). Reduces the shell-injection surface of the piped-install path.

## [0.1.2] - 2026-07-27

Initial npm publish.

- Skills: `pr-impact-scan`, `spring-kafka-listener-review`, `kotlin-coroutine-review`, `react-hooks-review`, `nextjs-app-router-review`, `nestjs-provider-review`, `frontend-perf-impact-scan`, `parallel-dev`, `parallel-dispatch`, `branch-guard`.
- Hook: `branch-guard` PreToolUse.
