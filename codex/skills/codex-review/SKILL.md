---
name: codex-review
description: "Review the current Git change set before a pull request. Use for code review, PR review, or a final diff check; identify changed languages and invoke only relevant Codex reviewer skills."
---

# Codex diff review

1. Resolve the base branch from `gh pr view --json baseRefName -q .baseRefName`. If no PR exists, use `origin/HEAD`; state the fallback in the report.
2. List tracked changed files with `git diff --merge-base <base> --diff-filter=d --name-only`. Include staged and unstaged tracked changes. Report untracked files separately rather than silently reviewing them.
3. Perform a general review of only those files: scope, obvious correctness or security regressions, hardcoded secrets, and missing tests.
4. Invoke a specialist only when its file criteria are present:
   - Java or Kotlin: `$codex-jvm-memory-leak-review`
   - Kotlin: `$codex-kotlin-coroutine-review`
   - React: `$codex-react-hooks-review`
   - Next.js App Router: `$codex-nextjs-app-router-review`
   - NestJS: `$codex-nestjs-provider-review`
   - Spring Kafka listener: `$codex-spring-kafka-listener-review`
5. Aggregate the general and specialist findings. Do not modify code during the review.

Use this format:

```markdown
# Diff review — <branch>

**Base:** <base>  **Files:** <count>

## Must fix
- <file>:<line> — <impact and concrete next action>

## Should fix
- <file>:<line> — <impact and concrete next action>

## Consider
- <file>:<line> — <suggestion>

## Checks
- <reviewer>: <findings or not applicable>
```

Keep empty sections as `- (none)`. If no tracked files are in scope, say so and stop.
