---
name: kotlin-coroutine-review
description: Review Kotlin coroutine usage (typically in Spring Boot / Ktor code) for structured-concurrency violations, blocking calls inside suspend functions, dispatcher misuse, GlobalScope leaks, missing CoroutineExceptionHandler, and Job/Deferred lifecycle bugs. Triggers include "review this coroutine code", "why does my suspend function block", "kotlin async review", "am I using GlobalScope right".
version: 0.1.0
context: fork
agent: diff-scoped-reviewer
background: false
---

# kotlin-coroutine-review

Coroutine bugs are almost never at compile time and rarely visible in unit tests — they show up as thread-pool starvation, silent exception swallowing, or leaked jobs. This skill runs a structured audit of a specific coroutine-heavy file or module.

## Prerequisites

- Target file(s) visible.
- Kotlin version resolvable from `build.gradle` / `build.gradle.kts`.
- `kotlinx-coroutines-core` version resolvable (behavior differs between 1.6, 1.7, 1.8).

## Phase 1 — Anti-pattern sweep

Walk the file and flag each hit against this catalog:

### Blocking inside suspend

- `Thread.sleep(...)` in a `suspend fun` → use `delay(...)`.
- `.get()` / `.await()` on a `Future` / `CompletableFuture` → use the `-await` bridge (`kotlinx-coroutines-jdk8`).
- Any JDBC call in a suspend function on the default dispatcher → wrap with `withContext(Dispatchers.IO)`. JDBC is blocking.
- `runBlocking { ... }` inside a suspend function → almost always a mistake; you're already in a coroutine.

### GlobalScope / structured-concurrency violations

- `GlobalScope.launch { ... }` → leaked coroutine; won't be cancelled by parent. Use an injected `CoroutineScope` or `coroutineScope { ... }`.
- `CoroutineScope(Dispatchers.IO).launch { ... }` inline → same issue; the scope has no parent.
- Any `launch { ... }` inside a suspend function whose result the caller depends on → parent may return before child completes. Wrap the block in `coroutineScope { ... }` or make it a top-level `async`.

### Dispatcher misuse

- `Dispatchers.Default` for I/O work → occupies the CPU pool. Use `Dispatchers.IO`.
- `Dispatchers.IO` for CPU-bound work → starves I/O for other consumers. Use `Dispatchers.Default`.
- `newSingleThreadContext(...)` in library code → creates and never closes a thread. Use an existing dispatcher or take a `CoroutineScope` from the caller.
- `Dispatchers.Main` used in a non-UI backend service → the main dispatcher isn't installed on the JVM by default; runtime error at first use.

### Exception handling

- `try { ... } catch (e: CancellationException) { ... }` that swallows the exception → breaks cancellation propagation. Rethrow, or use `try/finally` for cleanup.
- `launch { ... }` without a `CoroutineExceptionHandler` on the scope → uncaught exceptions terminate the parent scope (structured concurrency) or crash the process (root scope).
- `async { ... }` whose `.await()` is never called → exception is swallowed until `await()` is invoked.
- `supervisorScope { ... }` used where you actually want failure to propagate → sibling coroutines keep running after a failure.

### Flow / Channel pitfalls

- `flow { emit(...) }` doing I/O without `.flowOn(Dispatchers.IO)` → emissions block the collector's dispatcher.
- `stateIn(scope, WhileSubscribed(), initial)` without a `WhileSubscribed(5000)` timeout → subscription churn on config changes recreates upstream unnecessarily.
- `Channel(UNLIMITED)` in a producer without a bounded consumer → memory leak under back-pressure.
- `.collectLatest { ... }` in a UI where every emission triggers cancellation of in-flight work → intentional if for user typing, dangerous if for RPC calls.

### Scope lifecycle

- Spring `@Component` holding a `CoroutineScope` field with no cancellation on `@PreDestroy` → jobs outlive the bean.
- Ktor `Application` scope leaked into request handlers → request-scoped work runs beyond the request.
- Android `viewModelScope` in a repository → repository logic tied to a specific viewmodel's lifecycle by accident.

## Phase 2 — Version-specific gotchas

Note behaviour differences by `kotlinx-coroutines` version:

- **1.6.x** — `Dispatchers.IO.limitedParallelism(n)` limits the shared pool globally. Later releases have per-instance behaviour.
- **1.7.x** — `runInterruptible` interop with blocking JVM APIs was rewritten; older `withContext(IO) { blockingCall() }` may not surface `InterruptedException` correctly.
- **1.8+** — `Flow.filterIsInstance` short-circuiting semantics changed for empty inputs.

If the file relies on version-specific behaviour, note it.

## Phase 3 — Emit findings

Same format as `spring-kafka-listener-review`:

```
[<severity>] <category>: <one-line summary>
  Where: <file>:<line>
  Why it matters: <impact in 1 sentence>
  Fix: <concrete code change>
  Reference: <kotlinx-coroutines doc / KEEP link if applicable>
```

Severity ladder:
- **must-fix** — leaks, silent exception swallowing, cancellation-safety violations
- **should-fix** — dispatcher misuse, scope lifecycle unclarity
- **consider** — style, more idiomatic patterns

## Non-goals

- Not a Kotlin style linter (ktlint / detekt cover that).
- Does not run the code. Verification of behaviour is the user's next step.
- Does not migrate blocking code to coroutines wholesale — that's a design decision, not a review output.
