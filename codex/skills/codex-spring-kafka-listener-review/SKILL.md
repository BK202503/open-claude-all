---
name: codex-spring-kafka-listener-review
description: "Review changed Spring Kafka listener code for retry, acknowledgement, DLT, and coroutine safety failures. Use when a changed Java or Kotlin file contains @KafkaListener."
---

# Spring Kafka listener review

Review changed listener files only. Read `pom.xml` or Gradle manifests only to identify Spring Boot and Spring Kafka versions.

Check bounded retries and backoff, a recoverer and monitored DLT after exhausted retries, `@RetryableTopic` interactions with `DefaultErrorHandler`, acknowledgement on every MANUAL path, ack-before-async-completion races, Kotlin `suspend` listener compatibility, child coroutine completion before acknowledgement, and consumer idempotency assumptions.

Return findings with severity, file and line, delivery or data-loss impact, and a concrete fix. Do not modify code.
