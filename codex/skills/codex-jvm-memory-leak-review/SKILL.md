---
name: codex-jvm-memory-leak-review
description: "Review changed Java or Kotlin files for JVM and Spring memory leaks. Use during a diff review when .java or .kt files changed."
---

# JVM memory-leak review

Determine the changed `.java` and `.kt` files from the current Git diff. Read only those files; read `pom.xml` or Gradle files only to resolve dependency versions, never as findings.

Check for:

- Static or companion-object mutable collections that accumulate without bounded eviction.
- `ThreadLocal` or security/request context values set without `finally` cleanup.
- Listeners, callbacks, or Flow collectors registered without lifecycle cancellation.
- Naked `ConcurrentHashMap` or cache configuration without size/TTL bounds.
- Streams, JDBC resources, or `EntityManager` instances opened without structured closing.
- Singleton beans retaining prototype, request, or session scoped objects.
- `@Async`, `CompletableFuture`, scheduled tasks, or coroutines retaining large mutable state.
- `Channel(UNLIMITED)`, excessive SharedFlow replay, and callbackFlow without `awaitClose`.

For every finding return severity (`must-fix`, `should-fix`, `consider`), file and line, memory-retention impact, and a concrete fix. Say `no JVM memory-leak pattern found` if none apply.
