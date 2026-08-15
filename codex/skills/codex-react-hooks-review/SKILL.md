---
name: codex-react-hooks-review
description: "Review changed JSX and TSX files for React Hooks regressions. Use during a diff review when React functional components or hooks changed."
---

# React Hooks review

Review only changed `.tsx` and `.jsx` files.

Check effect dependencies and unstable dependencies, stale state closures in asynchronous callbacks, missing functional state updaters, index keys on mutable lists, unnecessary memoization, async effect cancellation, Rules-of-Hooks violations, and server/client component boundary errors.

Return severity, file and line, user-visible impact, and a concrete fix. Do not modify code; report no findings plainly when applicable.
