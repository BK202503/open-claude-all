---
name: oss-status-sweep
description: Fan-out status check across a list of upstream OSS artifacts (PRs, issues, commits). Spawns one oss-pr-status subagent per target in a single message (parallel), then aggregates into a prioritised report. Triggers include "sweep my upstream PRs", "what's waiting on me", "check all these PRs". One-shot; for scheduled monitoring use /schedule.
version: 0.1.0
---

# oss-status-sweep — parallel status check

Snapshot the current state of many upstream artifacts in one round-trip. Prioritise items that need your action.

---

## Phase 1 — Enumerate targets

Get the list of targets from one of:

1. **Explicit args** — user pasted a list. One artifact reference per line.
2. **Env var** — `OSS_SWEEP_TARGETS=<newline-separated URLs>` or a file path `OSS_SWEEP_TARGETS_FILE=~/.config/oss-sweep-targets`.
3. **Discovery** — if the user has a portfolio site whose pages list open badges, grep it. E.g. `grep -r 'state-open' <site-root>/**/*.html | grep -oE 'https://github.com/[^"]+/(pull|issues|commit)/[0-9a-f]+' | sort -u`. Only do this if the user's setup follows a known convention.

If more than 12 targets are found, ask the user whether to sweep all or narrow. 12 is the parallel-fan-out budget guideline (Claude Code parallel Agent calls tend to serialize past this).

## Phase 2 — Fan out

Emit a single assistant message containing one `Agent(subagent_type="oss-pr-status", ...)` tool call per target. All in one message = parallel execution.

```
Agent(subagent_type="oss-pr-status", description="apache/kafka#22536", prompt="https://github.com/apache/kafka/pull/22536")
Agent(subagent_type="oss-pr-status", description="strimzi/kao#143",   prompt="https://github.com/strimzi/kafka-access-operator/pull/143")
...
```

Do NOT run them sequentially. Do NOT bundle multiple URLs into one prompt.

## Phase 3 — Aggregate + prioritise

When every subagent has returned, group the results into three buckets:

1. **Needs your action** — `CHANGES_REQUESTED`, CI failing, or ambiguous ("waiting on you").
2. **Merged / closed since last sweep** — surface these so the user can push follow-up work.
3. **Needs upstream action** — `REVIEW_REQUIRED` with no reviewer picked, `triage` label, no reviews for > 14 days.

Emit one Markdown section per bucket. Inside each, one line per artifact:

```
- <owner>/<repo>#<n> — <state> — <action-recommendation>
```

Order buckets as (1), (2), (3). Bucket (1) unblocks progress; (2) is a positive follow-up; (3) is idle triage.

If any bucket is empty, omit its section entirely.

---

## Guardrails

- **Read-only sweep.** No PR edits, no comments, no side effects.
- **Parallelism limit.** Cap at 12 in one message. Beyond that, split into two ordered by project (most recently active first).
- **Cache respect.** If the user asks to sweep again within 60 seconds, refuse and point at the previous report unless they explicitly re-request.
- **Do not chain follow-up actions.** If artifacts merged, surface them — the user decides whether to publish, comment, etc.
- **Not for monitoring.** For "watch every hour" style, tell the user to `/schedule` this skill.

---

## Common slip-ups

- **Sequential invocation.** If you emit one Agent call per message, the fan-out is worthless. Batch them in one assistant message.
- **Bundling.** Do not pass a comma-separated list to one subagent; each subagent handles exactly one target.
- **Stale portfolio badge.** If a site says `open` but the sub-agent reports `MERGED`, that is a "site update needed" (bucket 2), not an error.
- **Rate limits.** GitHub API allows ~5000 req/hr for authenticated `gh` calls; sweeps of 12 artifacts are well within budget.
