---
name: parallel-dev
description: When the user asks for MULTIPLE INDEPENDENT development features/tasks in one turn ("build A, B, C in parallel", "3개 병렬로 짜"), fan out to N general-purpose subagents — each in its own git worktree with strictly non-overlapping file scopes — then review and merge sequentially. Distinct from parallel-dispatch (which handles read-only status/lookup fan-out). Use this when the units require WRITES (code changes, migrations, new files).
version: 0.1.0
---

# parallel-dev — multi-feature fan-out with worktree isolation

The default failure mode is (a) implementing multi-feature requests sequentially, or (b) fanning out without isolation and eating merge conflicts. This skill enforces:

- one worktree per feature
- non-overlapping file scopes stated in the prompt
- one assistant response emits all agents in parallel
- parent reviews + merges each branch back into `main` sequentially after all complete

## When to trigger

Trigger when the user's turn contains ≥ 2 independent **development** units. Examples:
- "build A, B, C in parallel with 3 agents"
- "이 세 개 다 같이 짜"

Do NOT trigger when:
- The task is read-only or lookup-heavy → use `parallel-dispatch` instead.
- The units share a file that would cause obvious merge conflicts.
- Any unit depends on another's output.
- Only ONE unit — no parallelism needed.

## Phase 1 — Enumerate units

Split the request into concrete, independently-shippable features. If the user gave a number, match it. If not, pick the natural split — usually 2–4.

For each unit write a one-line spec:
- Unit name
- Primary directories it will touch
- Any schema / config file changes (yes/no)

## Phase 2 — Partition scope

**This is the critical step.** Before spawning, list every directory each unit will touch. If two units both need to write to the SAME file, either:
- Give ownership to one unit and route the other around it, OR
- Serialize the two (spawn one, wait, spawn the next), OR
- Refuse parallelism for the pair and tell the user.

Common conflict zones (project-dependent):
- **Shared router / dispatcher** files (a switch-statement often shared across features).
- **DB schema** — at most ONE unit touches per fan-out.
- **Shared protocol / API contract** — ask each unit to add its own file and export.
- **CI config** — one unit per fan-out.

## Phase 3 — Brief each unit

Each subagent prompt MUST include:

1. **Project rules** — copy the strict rules from `CLAUDE.md`.
2. **Current state** — verified facts about what exists in the codebase for this unit. Include file paths and function names the agent can grep. Don't let the agent rediscover this.
3. **Scope** — numbered list of what to build.
4. **Do NOT** — explicit list of other units' file territory, naming the other units.
5. **Verification** — the exact commands to run (typecheck, tests, build).
6. **Deliverable** — commit locally, report worktree path + branch + commit SHA + short summary, cap at 300 words.

Prompt length: 400–800 words per agent. Terse prompts produce shallow work.

## Phase 4 — Spawn — ONE assistant response

Emit every `Agent` call in the same response. Every agent MUST use `isolation: "worktree"` and `run_in_background: true`. Use `subagent_type: "general-purpose"` for coding.

```
Agent(subagent_type="general-purpose",
      description="...",
      isolation="worktree",
      run_in_background=true,
      prompt=<self-contained brief per Phase 3>)
```

**Never** spawn parallel dev agents without `isolation: "worktree"`. They will collide on the same working tree.

**Concurrency cap: 4 dev agents.** Beyond 4, sequential merge review becomes the bottleneck. If more asked, do 4 first, queue the rest.

## Phase 5 — While agents run

Do not sit idle if the user stacked unrelated one-liners in the same turn. Do NOT poll agents — you get completion notifications.

## Phase 6 — Review + merge (sequential)

For each returned worktree, in the order the user prioritised (or in the order they finished):

1. `cd <worktree>` and `git log <base>..HEAD` — see what the agent committed.
2. Read the diff — reject scope creep, unrequested refactors, dead code.
3. If OK: `git checkout main && git merge --no-ff <branch>` back in the main repo.
4. If conflict: resolve manually — do not delegate this to another agent.
5. Remove worktree: `git worktree remove <path>`.

Never merge without reading the diff.

## Phase 7 — Final verification

Run the project's full verify command (typecheck, tests, build) on `main` post-merge. If red, bisect: which agent's merge introduced it, revert, re-brief that agent.
