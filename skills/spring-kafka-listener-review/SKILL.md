---
name: spring-kafka-listener-review
description: Review a Spring Kafka listener (Java or Kotlin) for common pitfalls before you PR — unbounded async retry, silent record loss on same-partition failures, misconfigured DefaultErrorHandler + RetryTopicConfiguration, missing DLT wiring, suspend @KafkaListener support gaps by version, ack strategy correctness, and consumer-side idempotency assumptions. Triggers include "review my Kafka listener", "check this @KafkaListener", "why does my listener retry forever", "suspend listener retry not working".
version: 0.1.0
context: fork
agent: diff-scoped-reviewer
background: false
---

# spring-kafka-listener-review

Spring Kafka's listener + error-handler surface has several known-bad interaction patterns that are silent until production. This skill runs a structured review against a specific listener class or module.

## Prerequisites

- Target listener code is visible in the repo (path or class name).
- `pom.xml` / `build.gradle` visible so the Spring Kafka + Spring Boot version can be resolved.

## Phase 1 — Version fingerprint

Before reviewing, resolve:

- Spring Kafka version (`org.springframework.kafka:spring-kafka` in dependencies)
- Spring Boot version (BOM)
- Kotlin version if the listener is `suspend`

Version matters because several classes of bug are version-specific:

| Pattern | Broken in | Fixed in |
|---|---|---|
| Suspend `@KafkaListener` unsupported | ≤ 3.2.x | 3.3+ |
| `RecordInRetryException` re-queued into `failedRecords` causing infinite re-delivery | 4.0.0–4.0.1 | 4.0.2 (fix in GH-4465 / PR #4469) |
| Silent record loss when two records on the same partition fail async | 4.0.0–4.0.x | GH-4504 / PR #4505 |
| Async retry head-of-line amplification unbounded | pre PR #4512 | PR #4512 |

Flag matches upfront so the user knows some of the "bugs" are actually already-known-and-fixed by an upgrade.

## Phase 2 — Structural review

Walk the listener and check each item:

### Error handling

- Is a `CommonErrorHandler` (usually `DefaultErrorHandler`) wired? If not, the container falls back to a logging handler that eats poison messages.
- Is the backoff bounded (`FixedBackOff`, `ExponentialBackOff` with `maxRetries` set)? An unbounded backoff blocks the consumer thread forever on a poison message.
- Is there a recoverer (`DeadLetterPublishingRecoverer`) after retries exhaust? Without one, the exhausted record is dropped.
- Does the recoverer publish to a DLT with a naming scheme (`<topic>.DLT`) the ops team actually monitors?

### Retry topic vs blocking retry

- Is `@RetryableTopic` in use? If yes:
  - `blockingRetryable` classes list is not `Throwable.class` (which would double-retry everything).
  - `attempts` and `backoff` are set explicitly.
  - The DLT strategy is `FAIL_ON_ERROR` unless you want silent drop.
- If `@RetryableTopic` and `DefaultErrorHandler` are both present, they interact — retry-topic takes precedence but the fallback path still runs. Verify the developer intended both.

### Ack mode

- `AckMode.MANUAL` requires the listener to call `acknowledgment.acknowledge()` on every code path. Missing calls = infinite re-delivery.
- `AckMode.RECORD` is safe but expensive. Confirm it wasn't picked accidentally when `BATCH` was intended.
- `AckMode.MANUAL_IMMEDIATE` + async processing = high risk of ack-before-commit races.

### Suspend / coroutine specifics (Kotlin only)

- `suspend fun` `@KafkaListener` requires Spring Kafka 3.3+.
- Inside a suspend listener, do NOT call `runBlocking { ... }` — you already have a coroutine scope.
- If the listener launches child jobs (`launch { ... }`), the parent will return before children complete unless `coroutineScope { ... }` wraps them. `MessageListenerContainer` acks on parent return → silent race.
- `CoroutineExceptionHandler` must be installed on the scope, or async failures are swallowed.

### Idempotency

- Do the message payload + business logic assume at-least-once delivery? If the DB write isn't idempotent (missing unique key, no upsert), replays cause duplicates.
- Consumer group rebalance triggers re-delivery of un-acked records. Verify.

### Observability

- Is `micrometer-tracing` on the classpath and are listener spans emitted? Without them, you can't correlate a poison-message stall with the offending offset.
- Is the DLT topic instrumented for alerting?

## Phase 3 — Emit findings

For each hit, emit:

```
[<severity>] <topic>: <one-line summary>
  Where: <file>:<line>
  Why it matters: <impact in 1 sentence>
  Fix: <concrete code change or config setting>
  Reference: <upstream Spring Kafka issue / commit if applicable>
```

Severity ladder:
- **must-fix** — data loss, silent drop, infinite loop
- **should-fix** — production ops pain (no DLT, no monitoring)
- **consider** — style / idempotency assumption / performance

Sort must-fix first. If there are zero findings, say so plainly — do not invent.

## Non-goals

- Not a full Kafka consumer-group / rebalance audit — that's a broader ops review.
- Not a performance tuner. `max.poll.records`, `fetch.min.bytes` etc. are out of scope.
- Does not fix the code. The user reviews the findings and decides.
