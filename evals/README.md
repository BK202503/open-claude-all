# evals

Precision / recall harness for review skills in this repo.

## Why

Review skills in `skills/` claim to catch specific regression patterns. Without a measured baseline those claims are unverifiable, and every prompt change is a coin flip. This harness runs each skill against planted-bug fixtures and reports TP / FP / FN.

## Requirements

- Claude Code v2.1+ (`claude` on PATH — uses `-p` headless mode)
- Node 18+
- Auth: uses whatever your local `claude` CLI already has (OAuth from a Claude Code session, or `ANTHROPIC_API_KEY` if you have one set).
- Opt-in reproducible mode: pass `--strict-auth` (or `OCA_EVAL_STRICT=1`) to run `claude --bare`, which ignores OAuth / keychain and requires `ANTHROPIC_API_KEY`. Use this in CI.

## Run

```sh
# validate fixture format only (no API calls)
node evals/runner.mjs --dry-run

# score everything
node evals/runner.mjs

# focus on one skill
node evals/runner.mjs --skill react-hooks-review

# single fixture, dump raw claude output
node evals/runner.mjs --skill react-hooks-review --fixture 01-stale-closure --verbose
```

Cost per fixture is capped by `--review-budget-usd` (default 0.20) and `--extract-budget-usd` (default 0.05).

## Fixture format

```
evals/fixtures/<skill-name>/<NN-slug>/
├── input.<ext>       # the file the skill will review (tsx / ts / kt / etc.)
└── expected.jsonc    # what the skill must (and must not) flag
```

`expected.jsonc`:

```jsonc
{
  "must_flag": [
    {
      "line": 10,
      "category": ["stale-closure", "missing-dep"],  // any listed category counts
      "hint": "useCallback deps missing count, onCommit"
    }
  ],
  "must_not_flag": [],
  "notes": "Free-form context for humans; not scored."
}
```

Scoring:

- **TP** — model finding matches an unmatched `must_flag` entry: line within ±3 AND category matches (any of the alternatives)
- **FP** — model finding matches no `must_flag` entry
- **FN** — `must_flag` entry with no matching model finding

Categories (canonical set enforced by JSON schema on the extractor):

- `missing-dep`, `stale-closure`, `functional-updater`, `over-memoization`, `key-antipattern`, `async-cleanup`, `rules-of-hooks`, `server-component-leak`

## Two-pass design

1. **Review pass** — `claude -p --plugin-dir <REPO_ROOT> --allowedTools Read` invokes the skill against the fixture. The skill produces its natural human-readable review — no output format is imposed on the skill itself.
2. **Extract pass** — a separate `claude -p --json-schema ...` call converts the review markdown into `{findings: [{line, category, snippet}]}`. The schema constrains category to the canonical set.

Under `--strict-auth`, both passes get `--bare` appended for reproducibility (CI use).

Keeping the skill's output natural means we score the skill as users experience it, not a synthetic JSON-mode variant.

## Adding a new fixture

1. `evals/fixtures/<skill>/<NN-slug>/input.<ext>` — the smallest file that exhibits the pattern. One or two closely-related issues per fixture; don't cram unrelated regressions together.
2. `expected.jsonc` — list every issue that a correct review should flag. Use `must_not_flag` for lines the skill should *not* touch (guards against false-positive drift).
3. `node evals/runner.mjs --dry-run` — confirms the file parses.

## Adding a new skill

Create `evals/fixtures/<skill-name>/` with fixtures. The runner discovers skills automatically. Extend `CANONICAL_CATEGORIES` in `runner.mjs` if the skill needs new labels.

## Results

Written to `evals/results/latest.json` (gitignored). Each result:

```json
{
  "skill": "react-hooks-review",
  "fixture": "01-stale-closure",
  "review_chars": 812,
  "tp": 1, "fp": 0, "fn": 0,
  "total_expected": 1, "total_found": 1,
  "findings_audit": [{ "line": 10, "category": "stale-closure", "verdict": "TP", "matched_expected": 0 }],
  "missed": []
}
```
