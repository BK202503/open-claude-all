---
name: oss-contribute
description: End-to-end upstream OSS contribution workflow. Clone target project, apply a scoped patch, run project's own tests, commit with signoff, prepare upstream submission (PR body / patch file). Triggers include "start on <PR>", "contribute to X", "let's fix that upstream bug we found in /oss-survey". Assumes maintainer-priority discipline (small diff, tests, no scope creep).
version: 0.1.0
---

# oss-contribute — end-to-end upstream contribution

Turns a chosen bug/improvement candidate into a submittable upstream patch. Meant to compose with `oss-survey` (finding the candidate) and `oss-pr-status` (tracking after submit).

---

## Prerequisites

- `gh` CLI authenticated for the target host (GitHub / GitLab).
- Clone directory convention: `$OSS_WORK_ROOT/<project>/` (default `~/oss-work/<project>/`, overridable per invocation).
- Fork exists on your account for GitHub targets. If not, `gh repo fork <owner>/<project> --clone=false --remote=false` first.

## Phase 1 — Clarify the target

Confirm from user or prior context:

- Project (`owner/repo`).
- Ticket / issue / discussion link.
- Scope in one sentence.
- Target branch (usually `main`; sometimes `x.y.x` maintenance line).

If any of these is fuzzy, stop and ask. Contribution PRs get rejected on scope disagreement more than on code quality.

## Phase 2 — Clone + baseline

```sh
cd "${OSS_WORK_ROOT:-$HOME/oss-work}"
gh repo clone <fork_owner>/<project>
cd <project>
git remote add upstream https://github.com/<upstream_owner>/<project>.git
git fetch upstream
git checkout -b <branch> upstream/<base>
```

Run the project's own baseline build/test to confirm the tree is clean before you touch it. If baseline is red on `upstream/<base>`, that is a project-level bug — surface it to the user; do not silently work on a red tree.

## Phase 3 — Patch discipline

- **One concern per PR.** Bug fix + drive-by refactor = two PRs.
- **Match project style.** Read `CONTRIBUTING.md` / existing code before writing new. Copy their brace style, javadoc convention, test naming.
- **Signature stability.** Don't change method signatures unless the ticket explicitly asks. Additive changes only when possible.
- **Test the fix.** Add a regression test that fails without your change. If the project has an integration-test module, use it — unit tests alone are often rejected for bug fixes.

## Phase 4 — Validate

Run the project's own commands (from `README.md` or `CONTRIBUTING.md`):

- Compile / build
- Unit + integration tests for changed modules
- Linter / format (spotless / prettier / rustfmt)
- License header check

If a step is expensive (>10 min), run it in the background and continue writing the PR body while it finishes.

## Phase 5 — Commit + push

```sh
git add -p                                    # stage per-hunk, review the diff
git commit -s -m "<title>"                    # -s adds Signed-off-by (DCO)
git push origin <branch>
```

**Do not `git push --force` after a maintainer starts reviewing** unless requested. Amend + force-push is fine before the first review; after that, add commits and let squash-merge collapse them.

## Phase 6 — Draft the PR / patch

Draft the PR body in a local file (e.g. `<project>-<n>-pr-body.md`) — do NOT open the PR yet.

Structure the body around:

1. **What** — one paragraph, plain language.
2. **Why** — cite the issue. If you diagnosed root cause, state it briefly.
3. **Validation** — what commands you ran locally, what integration tests you added.
4. **Backwards compatibility** — none / list surface changes.

Show the draft to the user. **Do not `gh pr create` without explicit "post it" confirmation.**

## Phase 7 — Handoff

After PR is opened, hand off to `oss-pr-status` for tracking. Do not comment on the PR ("gentle ping" etc.) without user approval — every upstream-visible action (reply, ping, close) must be shown as a draft first and posted only after explicit "post it".

---

## Non-negotiables

- No `--no-verify` on git hooks. If a hook fails, fix the underlying issue.
- No `--force-with-lease` before first review.
- No secondary refactors bundled in the PR.
- No AI-attribution footer in commit message or PR body.
- No "clean locally" comment right after push — wait for CI, then optionally note "Build green."
