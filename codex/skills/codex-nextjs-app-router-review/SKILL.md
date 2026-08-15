---
name: codex-nextjs-app-router-review
description: "Review changed Next.js App Router files for server/client boundary, caching, routing, and secret-exposure regressions. Use when app routes, middleware, or Next.js TSX changed."
---

# Next.js App Router review

Review changed App Router files only. Resolve the Next.js version from `package.json` when version semantics matter.

Check client components importing server-only code or secrets, hooks in server components, unintended fetch caching or dynamic rendering, async `params` and `searchParams` in Next 15+, route handlers returning invalid responses or missing caching policy, Edge-incompatible middleware APIs, and environment variables exposed to client code.

Report severity, file and line, runtime or data-exposure impact, and a concrete fix. Do not modify code.
