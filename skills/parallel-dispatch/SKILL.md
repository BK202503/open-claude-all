---
name: parallel-dispatch
description: When the user's message contains multiple INDEPENDENT tasks in one turn, fan out to N subagents in a single response instead of executing sequentially. Detects compound requests ("A 하고 B도 확인해줘", "이거 세 개 다", "kafka#22536 상태 보고 spring-kafka#4523 리뷰도 확인해줘") and routes each unit to the most specific worker (oss-pr-status, oss-router, general-purpose, ...). Triggers automatically whenever a single user turn has ≥ 2 independent actionable items. Skip when items depend on each other (must be sequential).
version: 0.1.0
---

# Parallel dispatch — one user turn, N parallel workers

The default failure mode of the primary Claude is executing multi-task user turns sequentially. That is measurably slower on I/O-bound work (`gh`, `WebFetch`, `git`, log polling) and burns cache repeatedly. This skill enforces a different pattern: read the whole turn, split into independent units, dispatch all units in one assistant response.

---

## Phase 1 — Split the request

Read the user's message and enumerate INDEPENDENT actionable items. Two items are independent if:
- Neither reads the other's output.
- The user's phrasing lists them as parallel (`A, B, C`, `X 하고 Y도`, `이거 다`).
- Order does not matter for correctness.

Items are NOT independent if:
- Item B needs a value / decision from item A.
- User uses sequencing words (`먼저 A 하고 그 다음 B`, `A 끝나면 B`).
- Item B is a follow-up (`A 확인하고 문제 있으면 B`).

If in doubt: sequential. Do NOT force parallelism when it introduces ordering risk.

If only ONE item is present, this skill does not apply. Return control immediately without emitting anything.

## Phase 2 — Route each unit

For every independent unit, pick exactly one worker:

| Unit shape | Worker |
|---|---|
| "check status of upstream PR / commit / issue" | Agent(`oss-pr-status`, prompt=<url>) |
| "which OSS skill fits this?" (broad OSS ask) | Agent(`oss-router`, prompt=<request>) |
| "look up file / grep / read" | Agent(`Explore`, prompt=<query>) |
| Anything else that is a well-scoped research / analysis / summary | Agent(`general-purpose`, prompt=<unit>) |

If a unit needs a skill that only takes user-visible context (e.g. `oss-contribute` involves live user approval gates), do NOT parallelise it — hand it back to the parent as sequential.

## Phase 3 — Emit all workers in ONE response

Critical: emit every `Agent(...)` call in the same assistant response. Claude Code executes tool calls in the same response concurrently; splitting across responses is sequential.

Concrete example. User says: "kafka#22536 상태 봐줘, spring-kafka#4523 리뷰도 확인해줘, 그리고 postgres btree_gist 커밋 상태도."

Correct emission (one response, three tool calls):

```
Agent(subagent_type="oss-pr-status", description="kafka#22536 status", prompt="https://github.com/apache/kafka/pull/22536")
Agent(subagent_type="oss-pr-status", description="spring-kafka#4523 status", prompt="https://github.com/spring-projects/spring-kafka/issues/4523")
Agent(subagent_type="oss-pr-status", description="postgres btree_gist commit", prompt="https://github.com/postgres/postgres/commit/7d3448961da3f8cb5c78b9d58c5e03b6bff53364")
```

Incorrect — three separate responses:
```
Response 1: Agent(oss-pr-status, kafka)
Response 2: Agent(oss-pr-status, spring-kafka)
Response 3: Agent(oss-pr-status, postgres)
```

## Phase 4 — Aggregate

When all subagents return, produce ONE aggregated response for the user. Never regurgitate each subagent's raw output — group by outcome (needs-your-action / merged / idle / etc.) and put the most actionable bucket first.

If any subagent errored, surface the error inline with the unit's label; do not retry silently.

---

## Concurrency budget

- **Hard cap: 12 subagents per response.** Beyond that Claude Code starts serializing.
- If the user's turn has > 12 independent units, split into two responses of ≤ 12 each. Announce the split briefly (`Fanning out in two batches (12 + N)…`).
- Do NOT chain the second batch behind the first if the units are truly independent — emit the second batch as soon as the first returns.

---

## Anti-patterns

- **Fake parallelism (sequential in disguise).** Emitting one Agent per response and pretending it is parallel. It is not.
- **Fake independence.** Splitting a workflow that has dependencies (`fix bug → run tests → commit`) into parallel workers. That will corrupt state.
- **Over-parallelising trivial work.** Do not spawn a subagent for a single `gh pr view` when the parent can just call Bash directly in one turn.
- **Skipping the aggregation.** Returning raw subagent transcripts to the user is noise. Always aggregate.
- **Racing writes.** If two units both edit the same file / repo / branch, they are NOT independent. Sequential.

---

## When NOT to invoke

- Single-task user turns.
- Any user turn where ordering matters (all `then`, `after`, `if X`).
- Tasks that require the user's live approval mid-flight (upstream PR post, site PR merge).
- One-shot debugging where a fast Bash call in parent is cheaper than spawning a subagent.
