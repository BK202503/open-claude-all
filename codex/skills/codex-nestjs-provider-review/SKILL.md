---
name: codex-nestjs-provider-review
description: "Review changed NestJS modules and providers for dependency-injection, lifecycle, and request-pipeline regressions. Use when changed TypeScript contains NestJS modules, controllers, or providers."
---

# NestJS provider review

Review changed NestJS files only.

Check request or transient providers injected into singleton graphs, `forwardRef` cycles, providers missing module exports, unjustified global modules, exception filters that fail to send a response, incorrect middleware/guard/interceptor/pipe ordering assumptions, untyped or miswired async factories, and adapter-specific manual response handling.

Report severity, file and line, boot or runtime impact, and a concrete fix. Do not modify code.
