---
name: nextjs-app-router-review
description: Review Next.js App Router code before you PR for common regressions. Server/client component boundary mistakes, `fetch` cache/revalidate misuse, `params`/`searchParams` async in Next 15+, server-only secrets leaking into client bundles, hydration mismatches, and route handler pitfalls. Triggers include "review this Next.js code", "check my app router page", "why is my page hydrating twice", "server component review".
version: 0.1.0
context: fork
agent: diff-scoped-reviewer
background: false
---

# nextjs-app-router-review

Catches Next.js 13+ App Router regressions that are easy to ship and painful to debug in production. Runs before you open a PR.

## What to check

### 1. Server vs client component boundary
- Every file is a server component unless it opens with `"use client"`.
- A `"use client"` file must not transitively import `server-only` modules (db clients, secrets, `fs`, build-time `process.env`). If it does, secrets ship to the browser bundle.
- `"use client"` propagates. Any component imported by a client component becomes a client component. Verify you did not accidentally client-ify a heavy server tree by importing it from a client parent.
- Hooks (`useState`, `useEffect`, `useContext`, ...) are illegal in server components. Verify both `next build` and the actual bundle output.

### 2. Data fetching cache semantics
- Bare `fetch(url)` in App Router is cached (SSG-like) by default. Almost never what dashboards want.
- Use `fetch(url, { cache: "no-store" })` for per-request freshness, or `{ next: { revalidate: N } }` for ISR.
- Do not rely on `cache: "default"`. The App Router default differs from the browser `fetch` default.
- A route becomes dynamic (per-request) as soon as it reads `cookies()`, `headers()`, or unrestricted `searchParams`. Confirm the intended rendering mode in the build output.

### 3. `params` and `searchParams` are async (Next 15+)
- In Next 15, `params` and `searchParams` are Promises. Await them or wrap in `use()`. Not doing so silently returns Promise objects that coerce to `[object Object]` at runtime.
- If you support both Next 14 and 15, gate the shape check explicitly.

### 4. Route handlers (`app/api/*/route.ts`)
- Return `Response` or `NextResponse`. Returning a plain object gives a 500 with no obvious error.
- `GET` handlers with no cache-control default to static and cache the response. Set `export const dynamic = "force-dynamic"` or explicit cache headers.
- Handlers do not auto-parse the request body. `await request.json()` yourself and error-handle malformed bodies.

### 5. Middleware
- Runs on Edge runtime. Node built-ins (`fs`, most `crypto`, `child_process`) are unavailable.
- Every middleware invocation is a cold call in production. Do not put heavy logic there.

### 6. Environment variables
- `process.env.X` in server components is fine. In client components only `NEXT_PUBLIC_*` are available.
- A `process.env.SECRET_KEY` referenced inside a `"use client"` file evaluates to `undefined` and often silently branches to unintended code paths.

## Common failure patterns to grep for

- `"use client"` at the top of a file that imports from `db/`, `auth/`, or reads `process.env.SECRET_*`.
- `fetch(...)` without an options object in list, dashboard, or admin pages.
- `params.id` or `searchParams.q` accessed synchronously in a Next 15 project.
- `export async function GET` without `dynamic = "force-dynamic"` and no explicit cache headers.

## When to invoke

Trigger when the user asks for a Next.js code review, mentions App Router pitfalls, or opens a PR touching `app/**/page.tsx`, `app/**/route.ts`, `middleware.ts`, or `next.config.*`.
