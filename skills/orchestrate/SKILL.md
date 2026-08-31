---
name: orchestrate
description: >-
  Run an arc of work to completion as a just-in-time loop — the SECOND and last user-facing leg of the
  pipeline, after /pipeline:write-issue, and the one command you type to take a body of work end to end.
  Use whenever you're asked to ORCHESTRATE or coordinate an arc, an epic, an issue or a batch of tasks,
  to EXECUTE or RUN a plan, to WORK or COMPLETE a GitHub issue, or to SHIP one through to merge. You are
  the ORCHESTRATOR and you own the whole arc: you ground only the HORIZON — the next dispatchable
  increment — at full slice depth via /pipeline:decompose, dispatch it via /pipeline:execute (worktrees,
  implementer sub-agents, gate, PR review, merge), then RECONCILE everything still outstanding against the
  tree that increment actually produced, rewrite what remains, and repeat until the plan is empty and the
  close-out is green. Everything beyond the horizon deliberately stays at SHAPE depth — goal, area,
  dependency, no file:line — because coordinates grounded now and executed three waves later name paths
  that stopped existing. You never write implementation code yourself and you never ground beyond the
  horizon.
argument-hint: "[issue # or umbrella # to orchestrate — omit to run the plan already in chat]"
---

# Orchestrate — the just-in-time arc loop

The pipeline is two commands: **`/pipeline:write-issue` → `/pipeline:orchestrate`**. The first turns an idea into a grounded, forward-facing issue. This skill owns everything after that — it runs the arc to completion, one increment at a time, re-grounding what remains against the tree each increment actually produced.

```
issue / plan  ──/pipeline:orchestrate──▶  ground the horizon · dispatch · reconcile · rewrite the rest  ──▶  repeat until empty
```

You are a **loop, not a builder.** You invoke `/pipeline:decompose` to ground an increment and `/pipeline:execute` to run it; you read the merged diffs, decide what the arc still needs, and rewrite the plan. You never edit a source file yourself.

**The defect this shape exists to fix.** A front-loaded decomposition grounds every wave against the tree as it stands when the pass runs, and writes `file:line` coordinates into briefs that later waves will execute. A wave-4 brief naming `/api/team-secrets*` is correct when written and wrong when run, because wave 1 renamed it to `/api/workspace/secrets*`. **Nothing errors.** The brief simply names a path that stopped existing, and the implementer opens a tree where the target is not there — then finds the nearest plausible thing and builds against that, because an implementer handed a coordinate does not treat its absence as a stop. The same pass also asserts a completeness it cannot have: work the arc structurally forces but no slice owns stays invisible until an implementer walks into it mid-wave, out of scope, with no owner and no boundary.

---

## 1. Two grounding depths, and the horizon that separates them

Every item in the plan sits at exactly one of two depths, and which one it sits at is decided by where the horizon is — never by how important the item is or how well you happen to understand it.

- **Shape depth** — for everything *beyond* the horizon. Goal, area, dependency, and one line on why it comes after the thing before it. **No `file:line`, no owned-file list, no do-not-touch boundaries, no framework skill, no model tier, no verify bar.** This is deliberately ungrounded, and that is the feature: grounding it now is precisely what goes stale. An item at shape depth is not an unfinished item.
- **Slice depth** — for the horizon *only*. Everything `/pipeline:decompose` emits: owned files as real paths, do-not-touch boundaries, the artifacts the slice derives, depends-on, the framework skill to open with, the model tier, the brief, and the verify bar. Grounded against the tree as it stands **right now**, and dispatched inside the same cycle it was grounded in.

**The horizon is the next dispatchable set: every remaining item whose dependencies have already landed.** Usually that is a wave. Sometimes it is only part of one — when some items in the next wave still depend on something that has not merged, the horizon is the subset that is genuinely dispatchable, not the whole wave on the strength of the rest arriving soon.

Both depths carry a failure, in opposite directions, and both are silent:

- *Grounding beyond the horizon:* the stale-coordinate failure above. It never surfaces as an error, and at the moment you write it, it looks like thoroughness.
- *Dispatching at shape depth:* an implementer handed an item with no owned-file list and no do-not-touch boundary invents its own scope, and the first anyone knows of it is a PR touching a sibling slice's core files — by which point the sibling has already forked.

**The horizon moves outward as increments land, and it is the only thing that promotes an item from shape depth to slice depth.** Nothing else does — not a well-understood item, not one a user asked about, not a small one.

---

## 2. The five-step loop

```
1. GROUND THE FRONTIER   /pipeline:decompose at slice depth — this increment ONLY
2. DISPATCH              /pipeline:execute — worktrees, implementers, gate, PR review, merge
3. RECONCILE             what did landing this increment change about everything still outstanding?
4. REWRITE THE PLAN      the remaining plan is replaced, not appended to
5. repeat until the remaining plan is empty → close out
```

**Step 1 — ground the frontier.** On the first cycle, read the source plan first — `gh issue view <N> --comments` for an issue, the conversation for an in-chat plan — and work out where the horizon falls in it. An issue from `/pipeline:write-issue` carries phases and a shape, not depths, so **establishing the horizon is the first cycle's work, not a precondition for starting**. Then invoke `/pipeline:decompose` against that horizon and nothing else, telling it the rest of the arc stays at shape depth. Its grounding pass runs against the tree as it is at the top of this cycle, which is the tree the implementers will actually open.

**And read UP before you read DEEP: when you were handed an issue, establish whether it is a sub-issue of an umbrella and read the parent before you ground the child.** `skills/decompose/SKILL.md` Step 1 is the authority — the two-step check, the candidate-set trap in the timeline fallback, and the disambiguator that resolves it. Read it there; this skill does not carry a second copy. One thing is specific to a loop: **§7 makes an umbrella's body the arc's live remaining plan**, so arriving at a child without finding the parent does not merely cost context — it starts a second plan for an arc that already has one. *The failure this prevents: the loop then rewrites its own plan every cycle while the umbrella's body goes stale beside it, and both read as authoritative — so whoever picks the arc up next inherits two remaining plans that disagree, with nothing marking which one the increments were actually dispatched from.*

**Step 2 — dispatch.** Invoke `/pipeline:execute` and act as the **dispatcher**. Worktree creation and its four invariants, the epic-branch decision, model-tier choice, background dispatch and divergence polling, the gate, the PR review loop, merge-not-squash and the close-out are all its mechanics — read them there. *The failure this prevents: two copies of one procedure drift, and when they disagree there is nothing to tell a reader which copy is stale.*

**Step 2 is not finished when the agents are dispatched — it is finished when they have merged, and you owe a divergence tick roughly every 10 minutes in between.** Arming that tick — `ScheduleWakeup`, ≈600s — is **part of dispatching, not a thing you reach for once something looks wrong**: you have not dispatched until the timer is set, and a dispatch report that does not name the armed tick is a step 2 that is still open.

**The tick is NOT how you learn an agent finished.** That arrives as a harness notification, for free, and it is not the mechanism. The tick exists for **early divergence detection** — catching a wandering agent mid-flight, before it burns a whole run going the wrong way. `/pipeline:execute`'s *Dispatch in the background, then monitor for divergence* carries what you check and how (fork-point anchoring, the divergence-vs-compile-ripple line, confirming an alarm before `TaskStop`, the drain rider that rides the same tick), and you still need it — but the interval, the purpose and the requirement are settled **here**, so that not opening it cannot end in deciding the tick was optional.

**⚠️ Do not reason from `ScheduleWakeup`'s own description to a conclusion this instruction has already answered.** That description warns against scheduling wakeups to poll for background work the harness already tracks — a warning about polling **for completion**, which is exactly what this tick is not for and exactly what the free notification already covers. It says nothing about a divergence check, which has no notification and no other way to fire. **If you find yourself weighing the tool's description against this paragraph, you have already skipped the step.**

*The failure this prevents: these five steps read as a sequence, so the wait between dispatch and merge — where the agents actually live — is invisible in the list, and an instruction reached only by a pointer is one a reader can skip while satisfying every step that is written here. Observed twice. First: a dispatcher ran a whole session on completion notifications with no tick armed, so its first sight of any diff was a fragment the USER pasted — and it killed a healthy agent on it. Then, after the requirement was added but left as a pointer: a dispatcher read this section, did NOT open `/pipeline:execute`, read `ScheduleWakeup`'s tool description instead, concluded the instruction did not apply to harness-tracked sub-agents, ran an entire session with no tick — and wrote a confident critique of this skill naming three defects the unopened section already answered. A pointer plus a plausible-looking rationale is enough to feel informed while doing none of it, which is why the number, the purpose and the rationalization are stated above instead of delegated. Skipping the tick does not merely delay detection; it hands the detection job to whoever happens to be watching, through the one channel that arrives with no fork point behind it.*

**Step 3 — reconcile.** The step a front-loaded decomposition does not have. It runs **after the increment has merged**, against the **merged tree** — not against the PR diffs, and not against a summary of them. The merged tree is what the next increment forks from, so it is the only tree whose state can falsify anything. Section 3 is the checklist.

**Step 4 — rewrite the remaining plan.** What reconcile found gets folded in or filed out (section 4), placed (section 5), and the remaining plan is then **rewritten in place** — not amended with a correction. Section 7 covers where that plan lives.

**Step 5 — repeat, then close out.** Back to step 1 with the horizon in its new position. When the remaining plan is empty, close out per `/pipeline:execute`'s *Gate the integrated whole* and, if the arc ran on an epic branch, its epic → integration PR.

**A one-increment arc runs one cycle.** Ground, dispatch, close out — no umbrella, no rewrite, no reconcile against a plan with nothing left in it. *The failure this prevents: a loop that assumes several cycles wraps a single-slice fix in tracking ceremony that costs more than the fix.*

---

## 3. The reconcile checklist

Run all six, every cycle, in this order. **Stated mechanically on purpose, so it is not a fresh judgement each time.** *The failure this prevents: a step whose content is re-derived each cycle gets a little shorter each cycle, and the cycle where it is skipped entirely produces exactly the same output as the cycle where it found nothing.*

**1. Coordinate drift.** Every path, symbol, table, route, or key named anywhere in the remaining plan: does it still resolve against the merged tree? Check them; do not recall them. **A target that does not resolve is stale by definition, not a maybe** — there is no version of "it probably moved but the brief still reads fine." This list is short precisely because everything past the horizon is at shape depth, and because a `/pipeline:write-issue` body names modules and files rather than a line-level to-do list; that is the payoff for the discipline in section 1. **Short is not empty** — a module path is still a path, and the increment that just merged is the likeliest thing to have moved one. *The failure this prevents: reading that discipline as a guarantee turns this item into a formality, and a formality reports the same clean result whether or not anything moved.*

**2. Vocabulary drift — checked per SENSE, not per string.** For each rename the increment performed, write down the *senses* the old word carried, and decide each one separately. One word routinely carries two meanings that a single rename splits: a cache-key helper meaning *"not partitioned by workspace"* survives a collapse that retires the same word meaning *"not project-specific"*. **A string match cannot tell them apart.** *The failure this prevents: a find-and-replace across the remaining plan rewrites the surviving sense too, and the next increment's brief then instructs an implementer to rename a helper that was already correct — a change that compiles, passes, and is wrong.*

**3. Revealed forced work.** What does the merged tree now force that **no remaining item owns**? A helper whose signature takes a type this arc deletes is forced work: nothing in the plan named it, and the compiler will hand it to whichever slice happens to hit it first. Ask the question against the merged tree rather than against the plan — the plan is the thing that failed to mention it. *The failure this prevents: the completeness a front-loaded decomposition claims but cannot have; unowned forced work surfaces as an implementer mid-wave discovering it, outside its scope, with no boundary telling it whether to touch it.*

**4. Falsified assumptions.** `/pipeline:decompose` writes `Assumes X (existing pattern in <file>); flag if wrong` into briefs. Re-check every assumption still live in the remaining plan against the merged tree. A landed increment can falsify one, and when it does **that is a plan defect, not an implementer's problem** — it is fixed here, in the plan, not discovered later by whoever inherits the brief.

**5. Deferred decisions — a deferral has no owner, so it renews itself in silence.** List every question the landed increment deliberately left open — *"whether the type names follow the renamed one is undecided"*, *"out of scope for this slice"*, *"leave the call sites for now"* — and re-ask each one at the **new** horizon. **A deferral is neither an assumption nor a stale coordinate, so items 1-4 cannot catch it**: nothing about it stops resolving, nothing about it gets falsified, and the brief that carried it still reads exactly as well as the day it was written. The test is not *was deferring it right* — it was, in a slice that had no business answering it — but **does the merged tree still hold together with it open?** Where it does not, it is forced work (section 4) and gets a slice of its own; where it does, write down that you re-asked it. *The failure this prevents: a scoping line written for one slice is inherited by the sweep that follows it, and the half-state ships — a field named `accountId` typed `UserId`, which is the exact contradiction the arc was cleaning up and is worse than either endpoint, because a half-done rename reads as a deliberate distinction to everyone who arrives later. Nobody decides to ship that. It ships because the decision not to decide was never re-opened.*

**6. Derived state — items 1-5 all interrogate the PLAN; this one interrogates the TREE.** Every artifact whose correct contents are a function of the whole tree rather than of any one slice's files — a ratchet ledger, a backlog a checker regenerates, a generated type, an unimported-exports manifest — gets **re-derived against the merged tip and compared with what is committed there**, by running the project's own regenerator rather than by reading the file and reasoning about it. `skills/decompose/SKILL.md`'s `Derives` field is where a slice declares these and why they are their own kind of scope, and `/pipeline:execute`'s *Gate the integrated whole* is the dispatcher re-deriving them before it gates the merged tip — so this item is not that step repeated, it is the loop confirming the merged tree it is about to ground the next increment against actually holds. *The failure this prevents: two slices edit disjoint files, each is individually correct, and the shared artifact is right on neither branch — with no textual conflict anywhere, so the merge is clean. Items 1-5 all come back clean too: nothing moved, nothing was renamed, no assumption was falsified, nothing was deferred. What is wrong is the tree, and it is wrong in the one file the next increment will read as ground truth — so the error is inherited by every slice grounded after it instead of surfacing.*

**Write the outcome down even when it is empty.** A cycle that reconciled and found nothing, and a cycle where nobody ran the checklist, produce identical plans. *The failure this prevents: the only record that the question was asked at all is the record you write; without it, the next cycle cannot tell a clean reconcile from a skipped one, and neither can a reviewer.*

Each item the checklist surfaces then goes through section 4.

---

## 4. Fold vs. file

Every item reconcile surfaces gets exactly one of two dispositions, decided by one test: **can the arc land without it?**

- **Forced** — the arc cannot compile, pass, or ship without it. **Fold it in** as a *named slice with its own wave*, sized and placed like any other.
- **Adjacent** — real work, genuinely worth doing, but the arc is correct without it. **File it and link it**, per `/pipeline:write-issue`. Never fold it.

**This guard is what keeps a re-decomposing loop finite.** *The failure this prevents: a loop that re-grounds every cycle makes absorbing new work trivially easy — the increment is already open, the tree is already read, and folding costs one line — so an arc that absorbs everything it touches never terminates. No single cycle is where that becomes obviously wrong; each fold is individually defensible and the close-out simply never arrives.*

The mirror failure is just as real and looks even more like diligence: **filing something that was actually forced ships an arc that does not build**, and it leaves a tidy linked issue behind as evidence of thoroughness. So run the test in the direction of the arc — "can it ship without this?" — never in the direction of the item, where every item looks worth doing.

Two riders:

- **"Filed" means filed.** An issue with a number, linked with `Follows #<N>` — or `Part of #<umbrella>` when the arc has one. `/pipeline:execute`'s follow-up-ownership rule binds this loop exactly as it binds an implementer: **a bullet in a report is not a follow-up**, and it stops existing the moment the turn ends.
- **A fold is a new slice, never a widening of a live one.** Growing a dispatched slice's scope mid-flight is indistinguishable from the divergence the dispatcher polls for, and the implementer's do-not-touch boundaries were written before the folded work existed.

---

## 5. Where folded work goes — merge surface outranks slice cohesion

One ordered criterion, and it is ordered rather than balanced: **merge surface first, slice cohesion only as a tiebreaker between placements with the same merge surface.** When cohesion says *"this belongs with the slice that owns that module, which is running right now"* and merge surface says *"it rewrites a shape that forty files reference"*, merge surface wins and cohesion loses outright.

**Churn discovered mid-arc goes in a serial wave — a wave holding exactly one slice, dispatched with nothing else in flight.** *The failure this prevents: parallel slices fork from different bases, so a large-footprint change dispatched alongside them merges textually clean and semantically wrong. Git merges by line; it has no idea two edits must compose. And when the shared shape is a **runtime string** — a query key, a table name, a route, a config key — the bad merge does not fail to compile at all: it silently splits one cache entry into two, or collides two into one, and every gate in the wave stays green.* `/pipeline:execute`'s *Merging a shared hotspot* is the same hazard reached from the other end — it carries the read-the-merged-region remedy for when a wave already contains one.

**Nothing folded ever joins a wave that has already been dispatched, whatever its size.** The slices in that wave forked before the folded item existed, and their briefs' do-not-touch boundaries cannot name it. A genuinely small-footprint fold — one file nobody else owns — is fine in the *next* wave; it is never fine in the live one.

---

## 6. The decide-don't-ask bar

**Wave assignment, fold-vs-file, sizing and re-slicing are this loop's calls to make and report** — not questions to put to the user. Decide them, act, and say what you decided in the cycle's record.

Escalate exactly one class of thing: **a product or design fork the code and conventions cannot settle.** When you must, ask in plain chat, **one question at a time, with your recommendation and why**. `skills/decompose/SKILL.md`'s *Step 2 — Validate the plan and fill the gaps* is the canonical statement of that split — what to fill from grounding, what to escalate, and how to ask — and it binds this loop unchanged. **Read it there rather than here.** *The failure this prevents: two copies of one rule drift apart, and once they disagree nobody can tell which one is stale — so the copy that happens to be read wins by accident.*

One thing is specific to a loop and is not in that statement: **the bar gets applied once per cycle, so setting it slightly too low multiplies.** *The failure this prevents: one avoidable question per cycle across eight cycles is eight user turns spent on things the repo already answers — and each one teaches the user that the loop cannot be left to run, which is the entire value the loop was supposed to deliver.*

---

## 7. Loop state and termination

**The umbrella issue body carries the live remaining plan, rewritten every cycle.** It is state, not history — it always describes what is *left*, at the depth section 1 assigns, and it is never archeological. `/pipeline:write-issue`'s forward-facing rule applies to every rewrite: a body that reads like a log of what the loop learned is a bug; a body that reads like the remaining build order is the goal.

**One comment per completed increment records what landed and what it invalidated.** Comments are the history; the body is the state. *The failure this prevents: with only comments, the current plan has to be reconstructed by reading the whole thread in order and applying each correction in sequence — and two readers reconstruct it differently. With only a rewritten body, an item that disappears leaves no trace of why, so nobody can tell a completed item from a dropped one.*

Read the issue and its thread with `gh issue view <N> --comments`. Write the rewritten body and each increment comment through the `gh api` REST endpoints, passing any body read from a file with `--field`, never `--raw-field` — `/pipeline:decompose`'s *GitHub write mechanics* carries the exact commands. The one thing to hold in your head while writing: only `--field` expands a leading `@` into the file's contents; the raw form stores the literal path as the body and **exits 0 with a comment URL**, so nothing downstream notices and only a human opening the issue ever sees it.

**In-chat, with no issue,** the remaining plan lives in the conversation and must be **restated in full each cycle** rather than referred back to. *The failure this prevents: a plan held only in context degrades silently across a long loop — items thin out, boundaries soften, and there is no artifact to diff against to notice.* Past roughly two increments, file an umbrella instead.

**Termination has two halves and needs both: the remaining plan is empty AND the close-out is green.** An empty plan over a red close-out is not done, and a green gate with items still outstanding is not done either. **And the arc's issues are closed — the tracker is part of termination, not a courtesy after it.** GitHub closes nothing here: a PR based on an integration or epic branch has its closing keywords ignored outright, no link created, and nothing re-evaluates them later (`/pipeline:execute`'s *Merge & cleanup*). *The failure this prevents: the loop's record says done, the tree says done, and the board says nothing ever landed — silently and cumulatively, so it surfaces only when somebody finally reads the issue list, by which point working out which PR settled which issue costs far more than closing them would have.*

**And one question the close-out has to answer in writing: did this arc surface a defect or a gap in the pipeline itself?** Ship it, or record that none were found. It is a **step with an output**, not a habit — a habit fires only if it is remembered at the end of a long session, which is exactly when it is not, while a missing answer is visible. **"None found" is a valid and cheap answer; what is not optional is writing it**, which is the device §3 already uses on the reconcile checklist for the same reason: an arc that surfaced nothing and an arc where nobody asked look identical afterwards, and the second is the common case. Running this flow at volume against a real tree turns these up constantly, and none of them are found by going looking — they arrive mid-work, get noticed in passing, and die in the transcript when the session ends, because by the time the arc closes the work is done and the finding is somebody's memory. **The bar is an observed failure the finding can name**, the same bar every rule in these skills is held to: this is not a prompt to produce a rule per arc, and a close-out that manufactures one is worse than a close-out that never asks — the skills fill with entries nobody reads, and the real findings stop being visible among them. *Where* the answer is recorded is the project's business — a findings file a run appends to, a comment on the umbrella, a line in the close-out report — and this skill requires only that the question be asked and answered.

**A cycle that lands nothing must stop and report.** Concretely: if a cycle completes and the remaining plan comes out identical to the one it started with, the loop has not advanced — stop and report what blocked it. *The failure this prevents: the loop's own structure — re-ground, dispatch, reconcile, repeat — has no natural stopping condition when an increment keeps failing. It will re-ground the same frontier and re-dispatch it indefinitely, and every individual cycle looks locally like progress.*

---

## 8. A verify rider that generalises

**Any slice that renames an identifier crossing a string boundary — a table, a route, a cache key, a config key, an env var, a feature flag — carries a bare-string sweep in its verify bar.** The sweep greps the *old literal* across the whole tree — fixtures, snapshots, generated files, docs, and config included — and proves either zero hits or that every survivor is deliberate.

*The failure this prevents: a typecheck cannot see a renamed table asserted as a literal in a fixture, and the single targeted test file an implementer is allowed to run will not be the file that asserts it. Both checks an implementer actually runs are structurally blind to the thing, so the slice reports green and the break lands.*

Two properties make this a rider rather than a note about one arc:

- **It attaches to a shape of slice, not to a change.** Any identifier that leaves the type system's reach and re-enters the program as text qualifies, in any arc, forever. That is why it is written here and not in the brief of whichever slice happens to trip it this week.
- **It goes into the verify bar at grounding time**, when the loop takes that slice to slice depth — not at review. *The failure this prevents: a rider added at review arrives after the implementer has already run its checks and reported green, so it costs a round trip to re-open a worktree that was about to be torn down.*

---

## 9. What execute does NOT do (hard boundaries)

- **No implementation code, ever.** You ground, dispatch, read merged diffs, and rewrite the plan. `/pipeline:execute` already forbids the dispatcher role from implementing; it is restated here because the loop is where the temptation actually lands — on the small folded item that "would take a second." *The failure this prevents: the moment you take an implementer's turn, nobody is holding the loop — the cycle's reconcile does not run, and the plan silently stops being rewritten.*
- **Never ground beyond the horizon.** This is the single rule the whole skill exists to enforce. Writing a `file:line` into an item three waves out rebuilds the exact defect this loop replaces, and it does so while looking like diligence.
- **Don't reopen the goal.** The arc's goal comes from the issue `/pipeline:write-issue` produced. The loop reshapes *how* the arc gets there — folding, re-slicing, re-waving — and never rewrites *what it is for*. A goal that genuinely changed is a new issue. *The failure this prevents: an arc whose target moves during execution can never be said to have finished, because the bar it is measured against moved with it.*
- **Don't re-slice what is already dispatched.** A live slice's brief is fixed for the duration of its worktree; corrections go through `/pipeline:execute`'s stop-and-replace. *The failure this prevents: an implementer reads its brief once, at dispatch — so an edit to the plan reaches nobody, and the plan and the running worktree then disagree while only the plan is in front of you. The correction reads as applied, and the slice builds the original brief to completion.*
- **No merging, no rebasing, no direct push, no self-merge.** `/pipeline:execute`'s hard rules bind this loop unchanged — read them there.

**Why this shape:** a plan grounded once, up front, is at its most accurate the moment before any of it runs, and decays from there — every wave that lands moves coordinates the later waves were written against, and nothing about that decay raises an error. Grounding just-in-time trades a little re-work per cycle for briefs that describe the tree the implementer will actually open, and the reconcile step turns each merged increment into evidence about the rest of the plan instead of leaving it as an assumption nobody re-checks.
