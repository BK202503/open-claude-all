---
name: frontend-perf-impact-scan
description: The frontend counterpart to `pr-impact-scan`. Before you PR a change to a React / Next.js / SPA codebase, enumerate the concrete performance regressions the diff introduces. New heavy imports, client-bundle bloat from server-to-client migration, list rendering without virtualization or keys, images without dimensions (CLS), fonts without preload (LCP), RSC network waterfalls, and hydration-mismatch risk. Produces a ranked list of blockers vs nits with file:line citations. Triggers include "perf review this PR", "will this ship slow", "check bundle impact", "frontend impact scan", "why did LCP regress".
version: 0.1.0
---

# frontend-perf-impact-scan

Reasons about a frontend diff the way `pr-impact-scan` reasons about symbol callers. The goal: before you open a PR, know every user-observable perf regression the change adds and decide whether to ship, mitigate, or split.

Runs after the code is written and before the PR is opened. Not a lint rule replacement, not a Lighthouse replacement. Complementary.

## Phase 1: Enumerate the diff

Read `git diff` for the PR. For every added or modified file, extract:
- New import statements (from and to).
- New JSX elements at the render root of any exported component.
- New effect / state declarations.
- New async operations (`fetch`, `await`, Promises).
- File-level markers that flip runtime mode: `"use client"`, `export const dynamic`, `export const revalidate`.

If the diff exceeds ~800 changed lines, request a scope split before scanning. Perf review on large PRs misses more than it catches.

## Phase 2: Score each impact

Categorize every finding into one of:
- **Blocker**: user-visible regression on the golden path. Do not ship until mitigated.
- **Watch**: likely regression on edge cases (slow network, large list, low-end device). Ship with awareness.
- **Nit**: cost is measurable but marginal.

Do not lump everything as "consider optimizing". Ranking is the point.

## Phase 3: Concrete checks

### Bundle size
- Any new import from a heavy library (`moment`, `lodash`, `date-fns` full import, `chart.js`, `three`, whole `firebase`). Suggest a lighter alternative or a subpath import (`lodash/get`) or a dynamic import boundary.
- Any component newly marked `"use client"` that pulls large server-only modules through its imports. That code now ships to the browser.
- Any newly imported file that transitively brings in an entire icon set or an entire style system.

### Render cost
- `.map()` over a list of unknown or unbounded size with no virtualization (`react-window`, `TanStack Virtual`) and no explicit maximum length.
- `.map()` where `key={index}` is used and items can reorder or delete.
- Newly added state that lives above a heavy subtree, causing re-renders on every keystroke.
- New inline object / array / function props to memoized children.

### Layout stability (CLS)
- `<img>` or `next/image` without `width` and `height` (or `fill` with a sized parent).
- Newly rendered late-arriving content that pushes existing content down (ads, chat widgets, notification bars).
- Skeletons whose dimensions do not match the loaded content.

### Largest Contentful Paint (LCP)
- Hero image / hero video newly added without `priority` (Next `Image`) or preload hints.
- Custom font newly added without `font-display: swap` or Next's `next/font` handling.
- New render-blocking third-party script added to `<head>`.

### Network waterfalls (RSC / App Router)
- Sequential `await` in a server component that could be `Promise.all`.
- A server component whose data fetch depends on the result of a client-side query, forcing a round-trip.
- Missing `preload` hints for critical resources referenced by the primary render path.

### Hydration mismatch risk
- Server-rendered output that depends on `Date.now()`, `Math.random()`, `window`, `localStorage`, or the user's locale without a stable fallback.
- Conditional rendering based on `typeof window !== "undefined"` at the top level of a component that also renders on the server.

## Phase 4: Report

Group findings by category and rank Blocker first, Nit last. For each finding, include:
- File and line.
- One-sentence description of the regression.
- Concrete mitigation (not "consider optimizing"). Name the API, the library, or the code shape that fixes it.

At the end, one line of overall verdict: "ship", "ship with the two Watch items filed", or "mitigate blockers first".

## When NOT to trigger

- Backend-only diffs.
- Config-only diffs.
- Refactors that provably do not change render output or bundle graph.
- PRs with a scope one heavy import wide that the user already flagged as a spike / prototype.
