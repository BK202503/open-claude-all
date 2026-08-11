---
name: nestjs-provider-review
description: Review NestJS module / provider / dependency-injection code before you PR for common regressions. Injection scope misuse (DEFAULT vs REQUEST vs TRANSIENT), circular module dependencies masked by `forwardRef`, missing `exports` in module definitions, exception filter / interceptor / pipe / guard ordering, and async-provider typing gaps. Triggers include "review this NestJS code", "check my module wiring", "why is my provider undefined", "nest DI review".
version: 0.1.0
context: fork
agent: diff-scoped-reviewer
background: false
---

# nestjs-provider-review

Catches regressions in the DI graph and request-lifecycle layer of a NestJS app. These bugs pass unit tests (which build their own module) and fail only in the full app boot. Runs before you PR.

## What to check

### 1. Injection scope
- Default scope is singleton. A REQUEST-scoped provider injected into a DEFAULT-scoped provider silently upgrades the whole graph to request-scoped, degrading throughput.
- TRANSIENT-scoped providers create a new instance per consumer. If the provider holds a connection or timer, you leak one per consumer.
- Grep for `scope: Scope.REQUEST` and confirm every consumer up the chain understands the cost.

### 2. Circular deps and `forwardRef`
- Every `forwardRef` is a smell. It usually means the two modules should be one, or one dependency should be inverted.
- A cycle that "works" today can fail at boot after a refactor because the eager-init order changed. Prefer restructuring the graph.

### 3. Module `exports`
- A provider works in `providers` for internal use but is invisible to importing modules until it is in `exports`.
- Common failure: fixed a service in tests (module has its own `providers`), broke in prod (importing module has no access).

### 4. Global module overuse
- `@Global()` hides the dep graph and makes module refactoring painful.
- Use it only for cross-cutting infra (config, logging, tracing). Not for business services.

### 5. Exception filter chain
- Filters registered globally, at controller level, and at method level all apply. The most specific wins for the same error type. Confirm the intended catch order.
- A filter that returns without calling `response.send` (or without returning a value under the fastify adapter) hangs the request.

### 6. Pipe / Guard / Interceptor order
- Runtime order: middleware, then guards, then interceptors (pre), then pipes, then handler, then interceptors (post), then filters.
- A DTO transformation done in a pipe is not visible to a guard. If a guard needs the transformed value, move that logic into the guard or into an interceptor.

### 7. Async providers
- `useFactory` with an async function returns a Promise. TypeScript infers the token as the awaited type, but if the `inject:` array is wrong, the factory receives `undefined` at boot and Nest throws only when the first consumer resolves.
- Always annotate the factory return type explicitly.

### 8. Fastify vs Express adapter differences
- Return value semantics differ. A handler returning a plain object works in both, but streaming, cookies, and header manipulation differ.
- If you swap adapters mid-project, re-audit every filter, interceptor, and manual `response.` call.

## Common failure patterns to grep for

- `forwardRef(() => ` appearing in imports across more than two modules.
- `scope: Scope.REQUEST` on a provider whose consumers are DEFAULT-scoped controllers.
- `useFactory: async (...)` with no explicit return type annotation.
- Providers listed in `providers:` but missing from `exports:` in the same module.

## When to invoke

Trigger when the user asks for a NestJS review, mentions DI confusion, or opens a PR touching `*.module.ts`, `*.service.ts`, or the app bootstrap file.
