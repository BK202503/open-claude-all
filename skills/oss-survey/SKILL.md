---
name: oss-survey
description: This skill should be used when the user wants to find one or more concrete, unclaimed bug / improvement candidates in a specific upstream OSS project to work on. Triggers include "find me a bug to fix in X", "what should I contribute next to X", "2차 가자" (when prior context is OSS contributions), "survey contrib/ for unclaimed issues". Returns a small ranked list with full provenance so the user can pick one with confidence the work isn't a duplicate.
version: 0.1.0
---

# OSS bug / improvement survey

You are surveying an upstream OSS project for a concrete next contribution. The output is a small (3–5 entries) ranked list of candidates, each with provenance the user can audit in 30 seconds.

The single biggest failure mode is recommending a candidate that is already taken. Treat "no one is working on this" as a claim that requires evidence, not as a default.

---

## Phase 1 — Pin the search target

If not already specified, ask the user (one batched message):

1. **Project** (e.g. `spring-projects/spring-kafka`, `apache/kafka`, `strimzi/strimzi-kafka-operator`, `postgres/postgres`).
2. **Area constraint** — full repo, a specific subdirectory (e.g. `contrib/`, `clients/`, `cluster-operator/`), or a specific subsystem.
3. **Time budget** — "1 week", "1–2 weeks", "first patch ever, easy". This shapes how aggressive to be.

If the user already gave answers in the triggering message, skip the questions.

---

## Phase 2 — Establish the contribution model for this project

Some projects don't take external PRs at all. Failing to check this wastes hours.

Known states worth remembering (add your own as you go):

- **jOOQ** — `limit PR creation to collaborators` enabled at GitHub policy level; external forks cannot open PRs at all.
- **PostgreSQL** — mailing-list only; GitHub mirror is read-only. Patches go to `pgsql-hackers@lists.postgresql.org` and are tracked in CommitFest.
- **Strimzi** — GitHub PR, but requires shared template + AI-assistance checkbox in the PR body.
- **MapStruct** — GitHub PR friendly; no CLA required.

Verify before surveying if the project is unfamiliar:

- `gh api repos/<owner>/<name> --jq '.has_pull_requests_enabled'` (rare flag — usually true).
- Check the repo's `CONTRIBUTING.md` for mailing-list / patch-tracker mentions.
- Look at the most recent merged PRs (`gh pr list --state merged --limit 5`) — if the only mergers are committers and "External Contributor" PRs sit untouched for months, treat the project as effectively closed and tell the user.

---

## Phase 3 — Source candidates

Search in this order — first source that yields evidence-backed candidates wins.

### A. Active bug tracker / -bugs mailing list (most recent first)

- GitHub: `gh api 'search/issues?q=repo:<owner>/<name>+is:issue+is:open+label:bug+sort:created-desc' --jq '.items[] | {number, title, comments, created_at}'`
- PostgreSQL: `https://www.postgresql.org/list/pgsql-bugs/<YYYY-MM>/` archives, last 2–3 months.

Skip anything older than ~6 months (stale issues are stale for a reason).

### B. Commitfest / patch tracker (project-specific)

- PostgreSQL: `https://commitfest.postgresql.org/<N>/` — look for "Waiting on Author" or "Needs Review" entries that have stalled.
- Linux kernel: lore.kernel.org by subsystem.
- Apache Kafka: KIPs in DISCUSS state.

### C. TODO wiki / `good-first-issue` labels

Useful only if everything else is dry. Heavily competed for.

### D. Code grep for `TODO` / `FIXME` / `XXX` in the source

Last resort. Most internal markers are intentional reminders, not invitations.

---

## Phase 4 — Verify each candidate is not taken

For every candidate before ranking, do all four:

1. **Read the full thread / issue.** Not just the title and first reply — open every reply.
2. **Check for an attached patch.** GitHub: any reply with `.patch` or `.diff` file. Mailing list: look for the `📎` paperclip marker or "Attaching a patch" in body text. **An attached patch = taken**, even if not yet merged.
3. **Check the master branch for an already-landed fix.** `git log --since=<thread-date> --oneline -- <suspected-area>` or `gh api search/commits?q=repo:<owner>/<name>+<keyword>`. If a commit already references the issue number, **skip**.
4. **Read the maintainer engagement pattern.** If a committer (e.g. Tom Lane, Fujii Masao, Sobychacko, scholzj) has replied with detailed review comments to the reporter, the maintainer is likely about to commit the reporter's patch directly. **Likely taken** — flag as risk.

A candidate fails verification → drop it. Be honest about coming back with zero. The user explicitly approved "report zero with provenance rather than invent" — never weaken on this.

---

## Phase 5 — Return ranked candidates

For each surviving candidate (target 3–5; less is fine):

```
**Candidate N — <one-line summary>**

- Module / file / function: <path>:<line> · `<function>`
- Reproducer / repro signal: <verbatim SQL / command / steps>
- Provenance: <URL with message-id or issue number> · reporter <name + date>
- Unclaimed evidence: read N replies, no patch attached, no committer engagement; master branch has no `<keyword>` commit since <date>.
- Risk flags: <none / "X replied once, may pick it up" / "design controversy in thread">
- Why it's tractable: <small surface area / clear repro / mechanical fix pattern>
```

Rank from most-confident-to-merge to most-risky.

If zero candidates survive, say so plainly. Suggest one of: wait for next bug wave, switch to docs/test improvements, work on a different project. Do not invent.

---

## Phase 6 — Hand-off

Recommend the top candidate and ask the user to pick. Once they pick, **do not auto-start coding** — the user may want to invoke `oss-contribute` (which is the workflow skill), or they may want to refine scope first. Pause for the user's next instruction.
