---
name: parallel-pr
description: When the user has N independent improvements against a single upstream repo and each unit must land as its own upstream PR ("각각 PR로 올려", "open a PR for each", "fan out and send N PRs", "split these findings into separate PRs", "one PR per unit against upstream"), fan out N general-purpose subagents — each in its own git worktree with non-overlapping file scope — where every agent commits, pushes, and runs `gh pr create --base <base>` against the upstream repo, then the parent reports the N PR URLs. Distinct from parallel-dev (which merges locally into the base branch and is right for solo/personal repos) and parallel-dispatch (which is read-only status/lookup fan-out with no writes and no worktrees).
version: 0.1.0
---

# parallel-pr — one PR per unit against an upstream repo

The default failure mode is squashing N independent improvements into one giant PR (reviewer rejects the whole thing because one bullet is wrong) or, worse, merging them locally on a repo you do not own the trunk of. This skill enforces:

- one worktree per unit
- non-overlapping file scopes stated in the prompt
- one assistant response emits all agents in parallel
- terminal step for each agent is `gh pr create --base <base>` against the upstream repo — NOT a local merge
- parent aggregates the N returned PR URLs and reports them together

## When to trigger

- User says "each as its own PR", "각각 PR로 올려", "one PR per finding", "fan out and open N PRs", "split these into separate upstream PRs".
- User has ≥ 2 independent units and the target repo has a PR-review culture (OSS project, team repo, any repo where a maintainer other than the author reviews before merge).
- User just finished an evaluation / audit / survey (e.g. `pr-impact-scan`, `oss-survey`) and is now converting each finding into an upstream PR.
- Target repo's CONTRIBUTING.md exists and requires PR review — a local merge would violate the contract.

## When NOT to trigger

- Only ONE unit → open a single PR directly, no fan-out.
- Units share a file → they cannot be separate PRs anyway; either serialize or merge into one PR.
- Target repo is personal / solo and the user owns the trunk → use `parallel-dev` (local merge is fine).
- Read-only lookup / status sweep → use `parallel-dispatch`.
- Any unit depends on another's merge landing first → serialize; parallel-pr assumes independent PRs that reviewers can merge in any order.

## Phase 1 — Enumerate units and read the contract

Split the request into concrete, independently-shippable PR-sized units. If the user gave a number, match it. Otherwise pick the natural split — usually 2–5.

Before spawning anything, **read the target repo's `CONTRIBUTING.md`** (or equivalent) and extract:

- **Base branch** for PRs (`main`, `dev`, `develop`, `next`, release branch, etc.). Do NOT assume `main`.
- **Scope rule** ("one thing per PR", size limits, "no unrelated refactors").
- **Attribution policy** (some repos ban `Co-Authored-By: Claude` / `Generated with Claude Code` trailers — surface this to every subagent).
- **Sign-off / DCO** (`Signed-off-by:` required?).
- **Commit-message conventions** (Conventional Commits, `[component]` prefix, etc.).
- **CI / verification** the maintainer expects to pass before review.

If these constraints look recurring for this upstream, save them to memory so future runs skip the re-read.

For each unit write a one-line spec: unit name, primary directories/files it will touch, whether it touches schema/config/CI.

## Phase 2 — Prepare worktrees

For each unit, from the main checkout:

```sh
git fetch origin
git worktree add -b <slug> <path> origin/<base-branch>
```

`<slug>` should be descriptive (`fix/null-deref-in-parser`, not `unit-1`). `<path>` sits outside the main checkout (e.g. `../<repo>-pr-<slug>`).

**Non-overlapping file scopes are mandatory.** If two units both need to touch the same file, either give ownership to one and route the other around it, serialize, or refuse parallelism for that pair and tell the user. Common conflict zones: shared router / dispatcher files, DB schema (at most ONE unit per fan-out), shared protocol / API contract, CI config.

## Phase 3 — Fan out (one assistant response, all in parallel)

Emit every `Agent` call in the same response with `isolation: "worktree"` and `run_in_background: true`. Each brief must be self-contained.

Brief template per subagent:

1. **Repo path** — the main checkout, for reference only.
2. **Worktree path + branch** — where the agent works. It must `cd` here and stay here.
3. **Upstream contract (verbatim from CONTRIBUTING.md)** — base branch, scope rule, attribution policy (explicitly: "do NOT add `Co-Authored-By: Claude` if the repo bans it"), sign-off / DCO, commit-message convention.
4. **Scope for this unit** — numbered list of what to change. Include file paths.
5. **Do NOT touch** — explicit list of the other units' file territory, naming the other units.
6. **Verification** — exact commands to run before push (typecheck, lint, tests, project-specific `make check`).
7. **Commit shape** — one commit preferred; message explains **why**. If the repo bans AI-attribution, use `git -c commit.gpgsign=false commit -m` with a plain heredoc body, no Claude trailer.
8. **Push + PR** — exact command shape:

   ```sh
   git push -u origin <slug>
   gh pr create --base <base-branch> --head <slug> \
     --title "<terse title>" \
     --body "$(cat <<'EOF'
   <PR body matching the repo's template>
   EOF
   )"
   ```

9. **Deliverable** — return the PR URL, worktree path, branch name, commit SHA, and any deviations flagged during the run. Cap at 300 words.

Prompt length: 400–800 words per agent. Terse prompts produce shallow PRs that maintainers reject.

**Concurrency cap: 4 agents.** Beyond 4, review-by-parent (Phase 5) becomes the bottleneck and reviewer bandwidth on the upstream side is also finite. Queue the rest.

## Phase 4 — Wait

Do not poll agents. Completion notifications arrive; act on them. If the user stacked unrelated one-liners in the same turn, work those in the interim.

## Phase 5 — Aggregate

Once all agents return, produce ONE aggregated response listing:

- N PR URLs, each with its title and target base branch.
- Any deviations each agent flagged (e.g. "had to also touch shared config; scope broadened by one file").
- Any agent that failed to push or open a PR — surface the error inline; do not silently retry.
- Suggested reviewer / label if the CONTRIBUTING calls it out.

Do NOT merge anything. Merge is the upstream maintainer's job.

## Pre-flight checklist

Before Phase 3, verify:

- [ ] `gh auth status` clean and pointed at the account that should own the PRs.
- [ ] `origin` in the main checkout points at the intended remote (fork vs. upstream — know which model the repo uses; some workflows require pushing to a fork and PR'ing across forks).
- [ ] Base branch exists on `origin` (`git ls-remote --heads origin <base>`).
- [ ] CONTRIBUTING.md read; base branch, scope rule, attribution policy, sign-off, commit convention all known.
- [ ] Each unit has a non-overlapping file scope written down.

## Failure modes

- **Unauthenticated `gh`** — agent's `gh pr create` fails at the last step. Pre-flight catches this.
- **Base branch missing on origin** — `gh pr create` errors with "base branch not found". Usually the repo uses `dev` or `develop`, not `main`.
- **Two units touching the same file** — second push conflicts on the shared file or the two PRs conflict on the upstream review side. Caught in Phase 2 if scopes are honest.
- **Agent bypassed CONTRIBUTING** — added an AI-attribution trailer to a repo that bans it, or opened the PR against the wrong base. Parent must review each PR URL in Phase 5 and, if wrong, force-push a fixup or close and reopen.
- **PR opened against wrong base** — usually `main` when the repo wants `dev`. `gh pr edit --base <correct>` fixes it without closing.
- **Fork-vs-upstream confusion** — agent pushed to `origin` but `origin` is the upstream (read-only for the user). Pre-flight the remote model before Phase 3.
