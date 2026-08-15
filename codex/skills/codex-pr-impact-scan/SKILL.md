---
name: codex-pr-impact-scan
description: "Trace callers, compatibility risks, and test gaps introduced by the current Git diff. Use before opening a pull request when a changed API, config, export, CLI flag, or data contract may affect other code."
---

# PR impact scan

Determine the base and changed files from the current Git diff. For every changed public symbol, configuration key, route, CLI flag, or schema:

1. Find direct callers, imports, consumers, and tests.
2. Compare each call site against the changed signature or contract.
3. Identify migration requirements, compatibility risks, and missing focused tests.
4. Distinguish proven impact from assumptions.

Return a ranked report with `Blocker`, `Watch`, and `Nit`, followed by affected files and proposed test coverage. Do not modify source files or generate a PR automatically.
