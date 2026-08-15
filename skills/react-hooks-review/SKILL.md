---
name: react-hooks-review
description: Review React (functional component + hooks) code before you PR for common regressions. `useEffect` dependency-array bugs, stale closures in event handlers, `useState` set-with-stale-value, over-memoization, list `key` anti-patterns, async effect cleanup leaks, and Rules-of-Hooks violations that a lint pass missed. Triggers include "review this React code", "check my hooks", "why does my effect run twice", "am I using useMemo right".
version: 0.1.0
context: fork
agent: diff-scoped-reviewer
background: false
---

# react-hooks-review

Catches React regressions that ship green through TypeScript and `eslint-plugin-react-hooks` yet still cause production bugs. Runs before you open a PR.

## What to check

### 1. `useEffect` dependency arrays
- Every value the effect body reads that is defined in component scope must appear in the deps. Missing deps mean stale reads.
- Do not disable `react-hooks/exhaustive-deps` to "make the warning go away". If the warning is wrong, that is usually a signal to lift the value out or use a ref.
- Deps that are recreated every render (inline objects, arrays, functions) reset the effect every render. Wrap in `useMemo` / `useCallback` or move outside the component.

### 2. Stale closures in event handlers
- A handler passed to a child at mount captures the values from that render. Later `setX` calls re-render, but the child still holds the old handler unless its props changed.
- Fix by using `useCallback` with proper deps, or by using the functional updater form of `useState`.

### 3. `useState` functional updater
- `setCount(count + 1)` in an async callback can lose updates. Prefer `setCount(c => c + 1)`.
- Same for arrays: `setItems(items => [...items, x])`, not `setItems([...items, x])`.

### 4. `useMemo` and `useCallback`: perf theater vs actual need
- Only useful when either (a) the memoized value is expensive to recompute, or (b) the value is passed to a memoized child or used as an effect dep. Otherwise it costs memory plus a shallow compare per render.
- Do not blanket-wrap every helper function in `useCallback`. That is noise.

### 5. List `key` prop
- Never use array index as `key` for lists that can reorder, delete, or insert. React reuses component state across the wrong items.
- Use a stable ID from the data. If none exists, add one on ingest, not on render.

### 6. Async effects: cleanup and cancellation
- Any effect that starts an async request must cancel it in the cleanup. Otherwise a race can `setState` after unmount.
- Prefer `AbortController` and check `signal.aborted` before `setState`, or a mounted-flag ref pattern.

### 7. Rules of Hooks (silent violations)
- No hooks inside conditionals, loops, or early returns. Lint catches most cases. Watch for hooks called inside custom hooks that are themselves called conditionally.
- No hooks in event handlers or class components.

### 8. Server component leak (React 19 / Next App Router)
- Hooks in a component that ends up being a server component is a build error. Confirm the `"use client"` boundary and where the component is imported from.

## Common failure patterns to grep for

- `useEffect(() => { fetch(...) })` with no cleanup and no deps.
- `key={index}` in a `.map()` that renders form inputs or components with internal state.
- `setState(state + 1)` inside `setTimeout`, `Promise.then`, or `WebSocket.onmessage`.
- `// eslint-disable-next-line react-hooks/exhaustive-deps` without a comment explaining why.

## When to invoke

Trigger when the user asks for a React review, mentions hook confusion, or opens a PR touching `*.tsx` / `*.jsx` files with hook calls.
