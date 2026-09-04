---
name: review
argument-hint: "[file or path to narrow the pass]"
description: >-
  The implementer's own quality + correctness pass over its UNCOMMITTED work, before it commits.
  Use when an implementer in the worktree flow has finished writing a change and is about to commit
  it, whenever the brief you were dispatched with says to run a review pass for the slice, and
  whenever you are asked to review, tighten, simplify, or clean up a change you just wrote and have
  not committed. Reviews whether the slice's GOAL is met, plus reuse, simplification, efficiency,
  altitude AND correctness, in one pass over the working tree, then applies what it judges right and
  reports what it rejected.
---

# Review — the implement-time pass

One agent, one working tree, one pass. You have just written a change and have **not** committed it.
Before you do, you review your own uncommitted diff for both quality and correctness, apply what
belongs, and report what you deliberately left alone.

This is the **narrow, early** tier. The broad tier is not yours: the dispatcher reads your PR's diff,
and the drained gate runs the full build and suite over the committed result. So this is neither a
second gate nor a PR review, and it is not for a committed range or someone else's PR — it is the last
thing that happens while the change is still entirely yours.

**Four actions, in order; each carries the rules that fire at it.** Two more fire at no single action
and so bind at all four — they close the file, and they are why this skill exists rather than a
general-purpose review tool.

---

## 1. Gather the diff — against the fork point

`git diff $(git merge-base HEAD origin/<base>)`, then `git status` for the untracked files a plain
`git diff` misses — they are part of your change — then read the current on-disk version of every file
the change touched, following imports out of them far enough to spot the existing helper you should be
reusing instead of the one you just wrote.

**Recompute that base here; never carry a SHA forward.** `HEAD` hides an early block you already
committed, so the pass runs against a fraction of its own change. The integration branch's **tip** is
worse: every commit merged there since you forked lands in your diff too — reversed, as your change
deleting work you never touched, or, against a fork point captured *before* you merged that branch
back in, as phantom additions. Either way you are reviewing another slice's PR with your name on it.

What is in scope, once you have it:

- **Only the code this change touched.**
- **Stay inside the worktree you were given.** Never edit a file outside it.
- **Do not refactor pre-existing code the change merely sits near.** Flag it in the report instead. A
  cleanup that widens the diff makes the dispatcher's PR review harder, and the slice's do-not-touch
  boundaries exist because another slice may own that file right now.
- **Respect the brief's boundaries.** If the brief says a path is owned by another slice, it is out of
  bounds here too.

---

## 2. Run the lenses, in this order

**The order is load-bearing:** the goal goes first because every lens under it asks whether the code
is good and none of them asks whether it achieved anything, so a diff aimed at the wrong thing passes
all five while getting steadily tidier. Then a correctness fix can introduce something to simplify,
and a simplification can expose a correctness problem. Reversed, the pass spends its budget polishing
a change the goal check is about to send back, or tidying code the correctness fix is about to
rewrite.

**And when the diff in front of you IS this corpus, the bar you are judging by has two copies — the
worktree's is the one that counts.** You were loaded from the **installed** plugin, at whatever
version the cache is serving. In every other repository those two are unrelated documents and the
question never arises; in the one that ships these skills they are one document at two versions, and
the tree is authoritative because it is what the change ships — a rule that disagrees with it is the
cache being behind, not the tree being wrong. So read a governing rule out of `skills/` before you
judge by it, `diff` the copies where one looks wrong or absent, take the tree's, and say in your
report which copy you read. The implementer whose tree this is has been told the same, and that does
not cover you: you were loaded as your own skill from that same cache, and it is *your* lenses that
decide what gets edited.

**Being the pass that acts by REWRITING is what makes a stale copy worse here than anywhere else it
lands.** Reuse and Simplification below both push a change toward the established pattern — and a rule
this diff has just changed still reads as established in the copy you were handed, so *converge on
what is already there* comes out as an edit dragging the new wording back to the old one. That is a
revert, and it arrives in your Applied list wearing the word convergence.

### Goal met

- **The slice's `Goal` says in outcome terms what this work is FOR. Ask whether the diff in front of
  you achieves it** — a different question from whether it matches the brief, which is the next lens
  down and which a wrongly-aimed brief passes.
- **You are the first party positioned to ask it.** You hold the intent and the real diff at the same
  moment, while the change is still uncommitted and a correction costs nothing. The gate runs
  commands and cannot read a goal; the reader at the PR gets here only after the work is done.
- **Then the other half of the same question: what does this leave BEHIND, and does the goal need it?**
  Goal-met asks whether the diff reaches the goal; this asks what it strands on the way. A rename with
  three call sites migrated and a fourth left, a helper the change makes dead, a doc the behaviour just
  falsified, a test asserting the old shape. **You are the only reader who sees the whole diff while it
  is still uncommitted**, so a straggler caught here is one edit and caught later is its own task.
- **Where the goal needs it, it belongs in THIS diff, not in a list.** Say so and do it. What the goal
  genuinely does not need is a finding you report, in the same breath, so the dispatcher dispositions it
  rather than discovering it — and **a straggler you neither fixed nor reported is the one shape of
  finding that reaches nobody**, since the diff will read as complete to everyone downstream.
- **A brief is a route to the goal, and a route can be wrong.** Where following it literally would
  miss the point, that is a finding you report — with what you did instead, or with what you would
  need — never a silent reinterpretation of the slice, and never a step you carry out anyway on the
  grounds that it was written down.
- **Where the slice carries no goal, say so and judge nothing against an inferred one.** A goal you
  reconstruct from the brief is the brief scored against itself, which passes by construction and
  reads afterwards exactly like a goal that was checked.

### Correctness

- The change does what the brief actually asked, including the parts that are easy to skip.
- Edge cases the happy path hides: empty collections, absent optional values, the first and last
  iteration, a failure partway through a multi-step write.
- Error handling that swallows rather than surfaces — a `catch` that logs and continues past a
  condition the caller needed to know about.
- Anything that would fail only in combination with a sibling slice's half of a contract. You cannot
  test that here, so **name it in the report** for the dispatcher, who can.
- **Comments your diff rewrote or moved, checked against the code they describe.** A comment
  asserting what other code does is prose against behavior — no checker compares the two, so this
  pass is one of the few places it can be caught. A claim that proves false is a finding to report,
  never a sentence to quietly correct: accurate prose over a real bug documents the bug as the design
  and removes the last thing that would have led anyone to look.

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

**Not observable behavior, though**, unless you are fixing a correctness defect you can name. A
"cleanup" that changes what the code does is a behavior change wearing a cleanup's clothes.

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

**Not formatting or import order, though** — the formatter owns those, and the caller runs it in write
mode immediately before committing. Nor **subjective style** that reduces neither reuse, complexity,
nor cost.

**The ceiling on all six lenses: anything whose reason you have not established, you leave.**
Establish why a thing is the way it is before you disposition it — trace what looks wrong to the
constraint it satisfies, the consumer it exists for, or the commit that put it there — and where it
has a valid reason and is idiomatic for its context, leave it and say you checked. The case common
enough to have earned its own line is **an existing suppression** (`eslint-disable`, `@ts-expect-error`)
the change did not add: it is the previous author's claim, already reviewed on the PR that introduced
it, so removing it to look tidy is a behavior change nobody asked for — flag it if you think it is
wrong rather than deleting it, since this pass edits the working tree directly and a construct removed
before it is understood is gone before anyone could ask why it was there. The odd-looking guard, the
redundant check and the narrower type fail the same way.

---

## 3. Decide what you apply, then verify it

**The agent running this slice decides, and that agent is you** — so the call on every finding is
yours: apply what belongs, smallest safe edits first, and consciously reject the rest. **You apply
nothing on anyone's behalf**: nothing lands in this tree you did not decide on, and a finding you are
not the party to act on is reported rather than delegated.

**Then verify, on a fixed budget.** The project's **scoped check** (`scopedCheck` in
`<repo>/.agents/worktree.json` — typically format-check + lint + typecheck, no build, no tests) plus,
at most, a **single targeted test file** run directly, where one covers what you changed. Read the
project's config for the actual command rather than assuming one. If an edit breaks a check, fix the
cause or revert that edit — never suppress the check.

⛔ **Never run a full-suite or whole-package test run.** The gate owns that, one PR at a time, and
running it here saturates the machine the gate is queued for. Backgrounding a banned run does not make
it allowed.

⛔ **Never background a check and end your turn on it.** The run that actually stalls this pass is a
*permitted* one, so the ban above cannot reach it: your whole budget is allowed, and the stall shape
does not care which run it was — the turn ends, and the caller never gets the report. So this rule is
keyed to the handoff rather than to the ban. Both of your checks run in the **foreground**, and this
pass ends at its report, never at a wait. It reaches checks and commands and nothing else; here it
reaches nothing else by construction, since the closing ban on sub-agents leaves this pass none to
wait on.

---

## 4. Report — Goal, Applied, Rejected, Flagged, Verification

Report to the caller in prose, covering five things. Keep it short enough to read at a glance:

- **Goal** — the slice's goal, and your verdict on whether this diff achieves it. Where the slice
  carried none, say that rather than supplying one. **This report is the only route that verdict has
  to the reader of your PR**, who is told to anchor the right-problem judgement to it and otherwise
  has the brief and the diff — two artifacts that agree with each other whether or not the work was
  aimed correctly.
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
  nothing, exactly as it dispatches, commits and pushes nothing.
- **Verification** — which scoped check you ran and its result, and which single test file if any.

Then hand back to whatever called you. The commit, the push, the PR, the gate ticket, and whatever
filing a flagged item becomes are the caller's, in that order, and none of them are yours.

---

## Hard rules — they fire at no single action, so they hold at every one

### Never dispatch sub-agents. Do this pass yourself, inline.

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

### Never commit, and never push.

Leave every change uncommitted. The flow that called you owns the commit step, and it commits in
logical, self-contained blocks after this pass — that ordering is the point, because a pass that runs
after the commits cannot see them.

Do not `git add`, `git commit`, `git push`, open a PR, or enqueue anything. If you believe the change
is finished, say so in your report and stop; the caller takes it from there.
