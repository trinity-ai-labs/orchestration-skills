---
name: review
argument-hint: "[file or path to narrow the pass]"
description: >-
  The implementer's own quality + correctness pass over its UNCOMMITTED work, before it commits.
  Use when an implementer in the worktree flow has finished writing a change and is about to commit
  it, whenever an `orchestrate` brief says to run a review pass for the slice, and whenever you are
  asked to review, tighten, simplify, or clean up a change you just wrote and have not committed.
  Reviews reuse, simplification, efficiency, altitude AND correctness in one pass over the working
  tree, then applies what it judges right and reports what it rejected. It NEVER dispatches
  sub-agents and NEVER commits — the agent running the slice is the one that decides what goes in,
  and the commit step belongs to the flow that called this. Not for reviewing a committed range or
  someone else's PR (that's the dispatcher reading the diff, plus the gate).
---

# Review — the implement-time pass

One agent, one working tree, one pass. You have just written a change and have **not** committed it.
Before you do, you review your own uncommitted diff for both quality and correctness, apply what
belongs, and report what you deliberately left alone.

This is the **narrow, early** tier of review. The broad tier already exists in this flow and is not
yours: the dispatcher reads your PR's diff, and the drained gate runs the full build and suite over
the committed result. So this pass is not a second gate and not a PR review. It is the last thing that
happens while the change is still entirely yours.

## The three hard constraints

These are the whole reason this skill exists rather than a general-purpose review tool. Each one is
load-bearing and each one has been violated in production with real cost.

### 1. Never dispatch sub-agents. Do this pass yourself, inline.

**Not a preference — the correctness argument.** A sub-agent spawned as a *fork* inherits the full
conversation of whoever spawned it. In this flow that conversation is an implementer's brief, and an
implementer's brief is a list of imperatives ending in *commit, push, open a draft PR, enqueue the
gate*. A reviewer that inherits it does not read it as background; it reads it as its instructions,
and it executes them.

That is not hypothetical. Observed, across three consecutive slices of one epic: review agents
applied fixes, ran the repo's formatter at root, committed in logical blocks, pushed, opened the pull
requests, and enqueued the gate tickets — all before the implementer that spawned them got its turn
back. Every artifact looked correct, because the reviewers were faithfully executing a correct brief.
They were simply not the agent whose judgment those artifacts were supposed to represent.

The second-order damage was worse than the mess. Once unauthorized writes were in play, agents lost
the ability to tell authorized work from rogue work. A sibling implementer, correctly alarmed, saw a
legitimate parallel slice's branch and PR appear mid-run, concluded it was more of the same, and
quarantined that slice's gate ticket with a careful, well-evidenced, and entirely wrong rationale. A
careful agent and a runaway agent produce identical artifacts: a branch, a PR, a queued ticket.

Even a *non*-fork sub-agent, which inherits no conversation, still holds write tools and can act on a
misread prompt. So the rule is the simple one, with no exception to reason your way into: **this pass
spawns nothing.** You read your own diff yourself.

### 2. Never commit, and never push.

Leave every change uncommitted. The flow that called you owns the commit step, and it commits in
logical, self-contained blocks after this pass — that ordering is the point, because a pass that runs
after the commits cannot see them.

Do not `git add`, `git commit`, `git push`, open a PR, or enqueue anything. If you believe the change
is finished, say so in your report and stop; the caller takes it from there.

### 3. Never run a full-suite or whole-package test run.

The gate owns that, one PR at a time, and running it here saturates the machine the gate is queued
for. Your verification budget is the project's **scoped check** (`scopedCheck` in
`<repo>/.agents/worktree.json` — typically format-check + lint + typecheck, no build, no tests) plus,
at most, a **single targeted test file** run directly.

Backgrounding a banned run does not make it allowed. Read the project's config for the actual
command rather than assuming one.

**And the run that actually stalls this pass is a permitted one, so that sentence cannot reach it.**
Your entire budget — the scoped check and one targeted test file — is allowed, and the stall shape
does not care which run it was: the turn ends, and the caller never gets the report. So the rule is
keyed to the handoff rather than to the ban. **Never background a check and end your turn on it.**
Both of your checks run in the **foreground**, and this pass ends at its report, never at a wait.
The rule reaches checks and commands and nothing else; here it reaches nothing else by construction,
since constraint 1 above leaves this pass no sub-agents to be waiting on.

*The failure this prevents, observed on `trinity-ai-labs/trinity` PR #4798, at exactly the moment
this pass runs: an agent had finished its change and was about to commit, backgrounded the project's
`pnpm check` — its `scopedCheck`, permitted here, and re-run by the pre-commit hook on `git commit`
anyway — and ended its turn on it. The change was complete, correct and uncommitted: no commit, no
push, no PR. The wait bought nothing the commit would not have enforced one step later. The gate
runner claimed the ticket and spent the claim refusing a dirty tree, which is the queue detecting the
symptom while nothing anywhere had a rule against the cause.*

## Scope

- **Only the code this change touched.** Read `git diff` **and** `git status` (untracked files are
  part of your change and are the ones a plain `git diff` misses). Diff against the fork point, not
  `HEAD` — `git diff $(git merge-base HEAD origin/<base>)` — so an already-committed early block is
  still in view.
- **Stay inside the worktree you were given.** Never edit a file outside it.
- **Do not refactor pre-existing code the change merely sits near.** Flag it in the report instead. A
  cleanup that widens the diff makes the dispatcher's PR review harder, and the slice's do-not-touch
  boundaries exist because another slice may own that file right now.
- **Respect the brief's boundaries.** If the brief says a path is owned by another slice, it is out of
  bounds here too.

**And when the diff in front of you IS this corpus, the bar you are judging by has two copies — the
worktree's is the one that counts.** You were loaded from the **installed** plugin, at whatever
version the cache happens to be serving. In every other repository that copy and the tree you are
standing in are unrelated documents and the question never arises; in the one that ships these skills
they are a single document at two versions, and the tree is authoritative because it is what the
change ships — a rule that disagrees with it is the cache being behind, not the tree being wrong. So
read a governing rule out of `skills/` before you judge by it, `diff` the copies where one looks wrong
or absent, take the tree's, and say in your report which copy you read. The implementer whose tree
this is has been told the same thing, and that does not cover you: you were loaded as your own skill
from that same cache, and it is *your* lenses that decide what gets edited.

**Being the pass that acts by REWRITING is what makes a stale copy worse here than anywhere else it
lands.** Reuse and Simplification below both push a change toward the pattern already established —
and a rule this diff has just changed still reads as established in the copy you were handed, so
*converge on what is already there* comes out as an edit dragging the new wording back to the old one.
That is a revert, and it arrives in your Applied list wearing the word convergence. *The failure this
prevents: measured in the tree that shipped this, against the cache that was actually enabled, this
file differed from that copy by 16 lines — every one of them in the* Flagged, out of scope *bullet and
the hand-back line that closes this file, both of which say what becomes of a flagged item. The older
copy said it becomes a filed, linked issue and nothing else; the tree says it becomes that **or** a
comment on the issue already carrying that failure. A pass reading the older bar flags the item
correctly and hands the caller the wrong disposition for it, which is the duplicate
`skills/write-issue/SKILL.md`'s* Before you file, search what is already filed *exists to stop.
Nothing errors in either direction, and a report written under a superseded bar reads exactly like one
written under the current one.*

## What to look for

Run the lenses in this order. It matters: a correctness fix can introduce something to simplify, and
a simplification can expose a correctness problem.

### Correctness

- The change does what the brief actually asked, including the parts that are easy to skip.
- Edge cases the happy path hides: empty collections, absent optional values, the first and last
  iteration, a failure partway through a multi-step write.
- Error handling that swallows rather than surfaces — a `catch` that logs and continues past a
  condition the caller needed to know about.
- Anything that would fail only in combination with a sibling slice's half of a contract. You cannot
  test that here, so **name it in the report** for the dispatcher, who can.
- **Comments your diff rewrote or moved, checked against the code they describe.** A comment that
  asserts what other code does is prose against behavior — no checker compares the two, so this pass
  is one of the few places it can be caught. A claim that proves false is a finding to report, never
  a sentence to quietly correct: accurate prose over a real bug documents the bug as the design.
  `skills/execute/references/implementer.md` carries the rule and the failure behind it.

### Reuse

- Reimplements a helper, type, or utility that already exists — call the existing one.
- A new abstraction duplicating one already in the codebase — converge on the established pattern.
- Logic copy-pasted across two or more spots inside this change — extract one shared helper.

### Simplification

- Single-use wrappers, indirection, or abstractions with exactly one caller — inline them.
- Generics, options bags, or config knobs with one concrete use — collapse to the concrete case.
- Dead code: unused variables, unreachable branches, functions never called.
- Over-defensive guards for states the surrounding code makes impossible.
- Nested conditionals that flatten cleanly with early returns.

### Efficiency

- Repeated lookups or recomputation, work inside a loop that belongs outside it.
- N+1 or per-item I/O that should be batched.
- Only where the win is real. Never trade clarity for a micro-gain.

### Altitude and clarity

- A low-level detail leaking into a high-level flow, or a one-liner buried under ceremony — move
  logic to the layer it belongs in.
- Vague names (`data`, `result`, `tmp`) → names that say what the value holds.
- Comments restating the code → delete. Comments explaining a non-obvious *why* or *how* → keep.
- Match the conventions of the files you are already in.

## What NOT to change

- **Formatting and import order** — the formatter owns those, and the caller runs it in write mode
  immediately before committing.
- **Observable behavior**, unless you are fixing a correctness defect you can name. A "cleanup" that
  changes what the code does is a behavior change wearing a cleanup's clothes.
- **Subjective style** that reduces neither reuse, complexity, nor cost.
- **An existing suppression** (`eslint-disable`, `@ts-expect-error`) that the change did not add. It
  is the previous author's claim, already reviewed on the PR that introduced it. Removing it to look
  tidy is a behavior change nobody asked for. Flag it if you think it is wrong.
- **Anything whose reason you have not established.** The bullet above is one case of a general rule,
  and `skills/orchestrate/SKILL.md` §4 is where that rule lives — establish why a thing is the way it
  is before you disposition it, and where it has a valid reason and is idiomatic for its context,
  leave it and say you checked. Read it there; this skill does not carry a second copy. *The failure
  this prevents: this pass edits the working tree directly, so a construct tidied away before it was
  understood is gone by the time anyone could have asked why it was there — and in a diff, removing
  something load-bearing looks exactly like removing something redundant. A suppression is only the
  case that comes up often enough to have earned its own line; the odd-looking guard, the redundant
  check and the narrower type fail the same way.*

## Process

1. **Gather.** `git diff` against the fork point, `git status` for untracked files, and read the
   current on-disk version of every file the change touched.
2. **Read context.** Follow imports out of the changed files far enough to spot the existing helper
   you should be reusing instead of the one you just wrote.
3. **Decide, then apply.** Smallest safe edits first. You are the agent that owns this slice, so the
   call on every finding is yours — apply what belongs and consciously reject the rest.
4. **Verify.** Run the project's `scopedCheck`. If a targeted test file covers what you changed, run
   that one file. If an edit breaks a check, fix the cause or revert that edit — never suppress the
   check.
5. **Report** (below), and stop. Do not commit.

## Output

Report to the caller in prose, covering four things. Keep it short enough to read at a glance:

- **Applied** — each change you made and the one-line reason.
- **Rejected** — each finding you considered and deliberately did not act on, and why. This is not
  filler. A finding you silently dropped is indistinguishable from one you never saw, and the
  dispatcher reviewing your PR has no way to tell the difference.
- **Flagged, out of scope** — pre-existing problems you found and correctly left alone, and any
  cross-slice interaction you could not verify from inside this worktree. **The admission test is
  narrow, and it is about the boundary rather than the effort:** an item belongs here only when
  fixing it falls outside the slice boundary the brief drew, or is genuinely unverifiable from
  this worktree. It is not a bucket for work you could have done — for that the caller's flow
  already has a sanctioned path, the out-of-scope fix isolated in its own commit, and that path
  is preferred over deferring. What is genuinely left is the **caller's** to file — as a linked
  issue, or as a comment on the one already carrying that failure; this pass reports it and files
  nothing, exactly as it dispatches nothing, commits nothing, and pushes nothing. *The failure this
  prevents: a flagged list reads as diligence, so a bucket with a loose admission test quietly
  absorbs the work the pass was called in to do — and every item in it dies with the turn unless
  the caller makes it tracked.*
- **Verification** — which scoped check you ran and its result, and which single test file if any.

Then hand back to whatever called you. The commit, the push, the PR, the gate ticket, and whatever
filing a flagged item becomes are the caller's, in that order, and none of them are yours.
