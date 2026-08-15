---
name: codex-kotlin-coroutine-review
description: "Review changed Kotlin files for coroutine lifecycle, cancellation, and dispatcher mistakes. Use during a diff review when Kotlin coroutine code changed."
---

# Kotlin coroutine review

Review only changed Kotlin files. Read Gradle manifests only for Kotlin or kotlinx-coroutines version context.

Check for blocking calls in `suspend` functions, `runBlocking` in coroutine code, unbounded `GlobalScope` or inline root scopes, I/O on `Dispatchers.Default`, CPU work on `Dispatchers.IO`, lost cancellation exceptions, `async` results never awaited, unmanaged Spring/Ktor scopes, and unbounded Flow or Channel buffering.

Report severity, file and line, runtime impact, and a concrete idiomatic fix. Do not modify code. If no issue applies, say so plainly.
