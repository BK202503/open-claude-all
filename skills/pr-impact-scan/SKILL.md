---
name: pr-impact-scan
description: Before opening a PR, enumerate every caller / reference / test / config that touches the symbols or files you changed, so you can decide (a) whether your change is source-compatible, (b) whether tests exist for every affected path, and (c) whether the PR description should call out any behaviour deltas. Triggers include "check impact of this change", "who calls X", "am I ready to PR", "impact scan on this diff".
version: 0.1.0
---

# pr-impact-scan — enumerate blast radius before you PR

Most bugs shipped in PRs are not in the changed lines — they're in the un-updated callers, missing test coverage, and stale docs. This skill runs a repeatable "who is affected" sweep before you hit `gh pr create`.

## When to trigger

- User is about to open a PR and asks "is this ready?"
- User modified a function signature, class name, config key, DB column, protocol field, or CLI flag
- Diff touches >5 files or crosses module boundaries
- User asks "who uses X" / "who imports Y" / "any tests for Z"

Do NOT trigger for:
- Trivial one-liners in docs or comments
- Purely additive changes (new file / new function that nothing calls yet)
- Test-only changes

## Phase 1 — Inventory the change

Enumerate exactly what changed. Do NOT rely on `git status` alone:

```sh
git diff --stat <base>...HEAD
git diff <base>...HEAD --name-status
```

For each modified file, extract:
- Changed function / method signatures (name + arity)
- Changed class / interface / trait names
- Changed public config keys, environment variables, CLI flags
- Changed DB migrations, protocol fields, API endpoints
- Deleted symbols

Present this inventory to the user before scanning.

## Phase 2 — Scan for references

For each entry in the inventory, run a repository-wide reference search. Language-specific tooling first, `grep` as fallback:

| Language | Preferred tool | Fallback |
|---|---|---|
| Java / Kotlin | `rg -tjava -tkotlin '\bSymbolName\b'`, LSP `find_references` if available | `grep -rn` |
| Python | `rg -tpy '\bSymbolName\b'`, `pyright --outputjson` | `grep -rn` |
| Go | `rg -tgo`, `go/types` reference | `grep -rn` |
| TypeScript | `rg -tts -ttsx`, tsc `--listFiles` | `grep -rn` |
| Rust | `rg -trust`, `cargo check` reference errors | `grep -rn` |
| SQL / config | `rg` on the exact key string | `grep -rn` |

Bucket the hits into:
1. **Same-PR callers** — already covered by your diff. No action needed.
2. **Untouched callers** — files that reference the changed symbol but aren't in your diff. Each needs a decision: update in this PR, or verify source-compatibility.
3. **Tests** — every untouched-caller file should have a matching test file. If missing, note it.
4. **Docs / config / examples** — README, CHANGELOG, sample configs. If the changed symbol is public API, these must be updated.

## Phase 3 — Signature-compatibility check

For each changed function / method signature:

- Parameter added → is the caller using positional or named args? Positional callers break unless the new param has a default.
- Parameter removed / reordered → all callers break.
- Return type widened → callers pattern-matching on the return value may break.
- Exception / error type added → callers with `catch (SpecificException)` may miss the new one.
- Access modifier tightened (public → private) → external callers break.

Emit one line per signature change with the compatibility verdict.

## Phase 4 — Test coverage delta

For each changed file, check the corresponding test file(s):

- If no test file exists: flag "no test coverage for this file — regression risk".
- If test file exists but doesn't reference the changed function name: flag "test file exists but doesn't cover this symbol".
- If tests exist and reference the symbol: OK; note the test line ranges so the user can eyeball whether the assertions match the new behaviour.

## Phase 5 — PR-description material

Draft the impact-relevant sections the user should paste into the PR body:

- **Behaviour changes** — bulleted list of user-observable deltas
- **Source-compatibility** — "no signature changes" / "N callers updated, all in this PR" / "public API signature changed — semver bump required"
- **Test coverage** — "N new tests" / "existing tests updated" / "gap: <file> has no test"
- **Migration required** — "none" / "config key <X> renamed, old key still read for 1 release with deprecation warning" / etc.

Show the draft to the user. Do not open the PR — that's the user's own workflow (`gh pr create` after review).

## Non-goals

- Not a semantic diff tool. This is a repeatable checklist that surfaces blind spots.
- Does not run tests. Verification of test PASS/FAIL is the user's next step.
- Does not decide whether the change is a good idea. Scope + design are upstream of this skill.
