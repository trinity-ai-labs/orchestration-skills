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

The pipeline is two commands: **`/pipeline:write-issue` → `/pipeline:orchestrate`**. This skill owns everything after the issue: it runs the arc to completion one increment at a time, re-grounding what remains against the tree each increment produced.

```
issue / plan  ──/pipeline:orchestrate──▶  ground the horizon · dispatch · reconcile · rewrite the rest  ──▶  repeat until empty
```

You are a **loop, not a builder**: you invoke `/pipeline:decompose` to ground an increment and `/pipeline:execute` to run it, read the merged diffs, decide what the arc still needs, and rewrite the plan — never editing a source file yourself. **The defect this fixes:** a front-loaded decomposition writes `file:line` into briefs later waves execute, and a brief naming a path an earlier wave renamed is wrong when run, without erroring.

---

## 1. Two grounding depths, and the horizon that separates them

Every item in the plan sits at exactly one of two depths, decided by where the horizon is — never by how important it is or how well you understand it.

- **Shape depth** — everything *beyond* the horizon: goal, area, dependency, one line on why it comes after the thing before it. **No `file:line`, no owned files, no do-not-touch boundaries, no framework skill, no model tier, no verify bar.** An item at shape depth is not unfinished.
- **Slice depth** — the horizon *only*: everything `/pipeline:decompose` emits — owned files as real paths, do-not-touch boundaries, artifacts derived, depends-on, framework skill, model tier, brief, verify bar — grounded against the tree **right now** and dispatched in the same cycle.

**The horizon is the next dispatchable set: every remaining item whose dependencies have already landed** — usually a wave, and where the rest of one still waits on something unmerged, the dispatchable subset rather than the whole wave. **It moves outward as increments land, and it is the only thing that promotes an item to slice depth**: not a well-understood item, not one a user asked about, not a small one. Both errors are silent — grounding early writes coordinates that stop existing, dispatching at shape depth leaves an implementer to invent its scope.

---

## 2. The five-step loop

```
1. GROUND THE FRONTIER   /pipeline:decompose at slice depth — this increment ONLY
2. DISPATCH              /pipeline:execute — worktrees, implementers, gate, PR review, merge
3. RECONCILE             what did landing this increment change about everything still outstanding?
4. REWRITE THE PLAN      the remaining plan is replaced, not appended to
5. repeat until the remaining plan is empty → close out
```

**Before the loop: the config precondition.** Check for `<repo>/.agents/worktree.json` before Step 1 grounds anything. **Missing is a hard stop, not a note**: the helper cuts a **bare** worktree instead of failing, so an implementer's checks fail for reasons shaped like code defects (`skills/setup/SKILL.md`'s *Why an unconfigured repo is worse than an obviously-broken one*). **It is a precondition on the ARC, not the horizon.**

**Four acts, in order, the first three user-facing.** (1) Say plainly the project is not set up and that you are setting it up first. (2) Explain what onboarding does — ground the repo's scripts and CI, write the config, scaffold a gate queue if wanted, verify by cutting worktrees. (3) **Ask for the values that cannot be ground**, `sharedResources` above all: a guessed one is a safety property that looks present and is not. (4) Invoke `/pipeline:setup`, then resume at Step 1. **It terminates at a reviewable change you do not merge** — §9 forbids merging or pushing, so hand the config PR over.

**And the window closes at dispatch.** Once worktrees are live the config is **frozen for the arc**: drift is stop-and-report, never repair. `/pipeline:execute`'s ⚠️ on the config it reads is the authority — the helper reads the main checkout's working copy, shared with any session cutting worktrees.

**Also before the loop, and only in one repository: fix which copy of these rules you are running.** Inside the repository that ships these skills the installed plugin you loaded is not the tree being edited, and **the rules an arc has just shipped are the ones most likely to be missing from it**. Read the tree's `skills/` copy of any rule you act on, `diff` where one looks wrong, trust the tree, and say in the close-out which copy you ran from.

**Step 1 — ground the frontier.** On the first cycle read the source plan — `gh issue view <N> --comments`, or the conversation — and work out where the horizon falls: **establishing the horizon is the first cycle's work, not a precondition for starting**. Then invoke `/pipeline:decompose` against that horizon and nothing else, telling it the rest stays at shape depth.

**Read UP before you read DEEP: establish whether the issue is a sub-issue and read the parent before grounding the child.** `skills/decompose/SKILL.md` Step 1 is the authority — the two-step check, the timeline fallback's candidate-set trap, the disambiguator — and **§7 makes an umbrella's body the arc's live remaining plan**, so missing the parent starts a second plan for one arc.

**Step 2 — dispatch.** Invoke `/pipeline:execute` as the **dispatcher**; worktrees, the epic-branch decision, model tiers, the gate, PR review and merge-not-squash are all its mechanics.

**Step 2 is not finished when the agents are dispatched — it is finished when they have merged, and you owe a divergence tick roughly every 10 minutes in between.** Arm it with `ScheduleWakeup` at ≈600s, callable right here: the tool is not confined to `/loop`. **Arming it is part of dispatching, not something you reach for once something looks wrong** — a dispatch report not naming the armed tick is a Step 2 still open — and **arm it LAST, after the implementers are launched.**

**The tick is NOT how you learn an agent finished**; that arrives as a harness notification. It is for **early divergence detection**, catching a wandering agent mid-flight. **No reading of `ScheduleWakeup`'s own tool description reaches this requirement** — its polling warning is about polling for completion. `/pipeline:execute`'s *Dispatch in the background, then monitor for divergence* carries what you check, including the epic branch's integration merge, run in the **epic's own worktree** and never the main checkout. Interval, purpose and requirement are settled **here**, because an instruction reached only by a pointer is one a reader can skip while satisfying every step in front of them.

**What the tick's prompt may carry: handles, never conclusions** — anything *derived* at arming time is grounding written for a later moment, which §9 forbids everywhere else. Carry what you look a fact up **with** (branch, worktree path, PR number) and re-derive what you looked **up**: the file list, whether a revision is outstanding, above all the next action. **The fork-point SHA reads as identity and is not**; recompute it each tick after a fetch.

**Step 3 — reconcile**, after the increment has **merged** and against the **merged tree** rather than the PR diffs: the tree the next increment forks from is the only one that can falsify anything (§3 is the checklist). **Step 4 — rewrite the remaining plan**: findings are folded in or filed out (§4) and placed (§5), and the plan is **rewritten in place**, not amended (§7 says where it lives). **Step 5 — repeat, then close out**: back to Step 1 with the horizon moved, and on an empty plan close out per `/pipeline:execute`'s *Gate the integrated whole* plus the epic → integration PR.

**A one-increment arc runs one cycle**: ground, dispatch, close out — no umbrella, no rewrite, no reconcile against an empty plan. **Grounding is not on that list: it is Step 1 exactly as written, the one step a single-slice arc does not trim**, because a one-slice plan can still carry a false premise nothing downstream re-checks.

---

## 3. The reconcile checklist

Run all of them, every cycle, in this order. **Stated mechanically on purpose, so it is not a fresh judgement each time**: a cycle that skips a re-derived step produces exactly the output of one that found nothing.

**1. Coordinate drift.** Every path, symbol, table, route or key named in the remaining plan: does it still resolve against the merged tree? Check them; do not recall them. **A target that does not resolve is stale by definition, not a maybe**, and shape depth keeps the list short but **short is not empty**.

**2. Vocabulary drift — checked per SENSE, not per string.** For each rename the increment performed, write down the *senses* the old word carried and decide each separately: **a string match cannot tell two senses apart**, so a find-and-replace rewrites the surviving one and the next brief renames what was already correct.

**3. Revealed forced work.** What does the merged tree now force that **no remaining item owns**? A helper taking a type this arc deletes is forced work the compiler hands to whichever slice hits it first, and **a merged change to `.agents/worktree.json` is the same question with the compiler taken out of it** — provisioning forced *silently*, every gate green while worktrees are still cut from the pre-change file (`skills/execute/references/worktrees-and-branches.md` says which merge ends that window).

**4. Falsified assumptions.** `/pipeline:decompose` writes `Assumes X (existing pattern in <file>); flag if wrong` into briefs; re-check every one still live against the merged tree, since **a falsified assumption is a plan defect fixed here, not an implementer's problem**.

**5. Deferred decisions — a deferral has no owner, so it renews itself in silence.** List every question the increment deliberately left open and re-ask each at the **new** horizon; **a deferral is neither an assumption nor a stale coordinate, so items 1-4 cannot catch it**. The test is **does the merged tree still hold together with it open?** — where it does not it is forced work and gets a slice, and where it does, record that you re-asked.

**6. Derived state — items 1-5 all interrogate the PLAN; this one interrogates the TREE.** Every artifact whose correct contents are a function of the whole tree rather than one slice's files — a ratchet ledger, a regenerated backlog, a generated type, an unimported-exports manifest — gets **re-derived against the merged tip and compared with what is committed there**, by running the project's regenerator rather than reading the file and reasoning about it (`skills/decompose/SKILL.md`'s `Derives` field is where a slice declares one).

**7. Scope drift — items 1-5 the PLAN, item 6 the TREE; this one the REQUEST, written in neither.** Compare **the arc's goal in the filer's own words**, quoted rather than recalled, against **what the remaining plan would deliver** if every item landed as written; it fires when the second cannot be stated as an instance of the first. **A fire binds the AGGREGATE, re-opens nothing, and HALTS rather than asking** — §4's verdicts stand, so report what the plan has become against what was asked and stop, because re-scoping is the user's.

**8. Follow-ups filed out of this arc — items 1-5 the PLAN, item 6 the TREE, item 7 the REQUEST; this one the TRACKER, where a finding can sit looking handled.** Every issue filed **out of** this arc — this loop's §4 filings and those its dispatchers and implementers filed under `/pipeline:execute`'s follow-up-ownership rule — goes back through §4 whenever its `Follows #<N>` or `Part of #<umbrella>` names a live arc. **Who filed it does not narrow this**, and **filing is how a finding is tracked, not how it is disposed of**: the tree may since have answered it.

**9. The seam map — items 1-5 the PLAN, item 6 the TREE, item 7 the REQUEST, item 8 the TRACKER; this one the artifact the loop itself CARRIES between cycles.** Take the arc's contract-seam map, which §7 owns, and ask of every seam what the increment did: **closed** it by landing both halves — strike it and say so, since a row that stops appearing is unreadable afterwards; **moved one half without the other**, a live break and forced work under item 3; or **opened** a new one. Then re-read the whole union with this cycle's seams added, not only the rows this increment touched (`skills/decompose/SKILL.md`'s *Contract seams* defines a seam and the map).

**Write the outcome down even when it is empty** — a cycle that found nothing and a cycle where nobody ran the checklist produce identical plans. Each item then goes through §4, which opens by establishing *why the thing is the way it is*: everything above produces findings, none of it explanations.

---

## 4. Fold vs. file

**Establish why a thing is the way it is before you disposition it — this gates everything below.** Trace what looks wrong to what made it that way: the constraint it satisfies, the consumer it exists for, the commit that put it there. **If it has a valid reason and is idiomatic for its context, leave it and record that you checked**; only then fix, raise or file.

**One class of finding arrives with that tracing already known to be shallow — an issue carrying `Filed from behind a fence`.** Its premises were established by **reading** rather than by changing, its filer fenced out of the file (`skills/execute/references/implementer.md`'s *File your follow-ups BEFORE you hand back*). **Treat each claim as an unverified premise — re-ground it before it becomes a slice, and never inherit one as a premise for something else.** **The marker is a claim to check, not one to doubt.**

**Then the first question is not where the item goes — it is whether it is yours to settle at all.**

- **I can reason out an answer myself → settle it.** **This is the default, and most findings land here** — an existing pattern, a convention `AGENTS.md` states, a plainly obvious default. Write the answer and what it rests on into the cycle's record. **Settling means answering the question, not writing the code**; where it implies work, the placement test places that.
- **It genuinely needs the user → ask, with the reasoning already done** — a product or design decision the code and conventions cannot settle, the only class that reaches the user as a question, at §6's bar.
- **The scope is genuinely an arc in its own right → file it, and say it is worth talking through first.** **If this arc also cannot land without it, filing does not make it shippable** — report that as the plan defect it is.

**Only what survives reaches the placement test, where the original question decides: can the arc land without it?**

- **Forced** — the arc cannot compile, pass, or ship without it. **Fold it in** as a *named slice with its own wave*, sized and placed like any other.
- **Adjacent** — real work, worth doing, but the arc is correct without it. **File it and link it**, per `/pipeline:write-issue`, and track it as its own arc; never fold it.

Run it in the arc's direction — "can it ship without this?" — never the item's: **filing something actually forced ships an arc that does not build.**

**An *Adjacent* verdict says the item gets filed; it does not say it needs a NEW number.** Before the create call, run `skills/write-issue/SKILL.md`'s *Before you file, search what is already filed*, keyed on the failure shape rather than the item's words and over closed issues as well as open. An open issue already carrying the failure takes the observation as a comment; a closed one makes the item a **regression** only where the fix that closed it is present in the copy the failure was observed in — absent, it is version skew and nothing is filed, and where neither is established the item says so rather than picking.

**A verdict is final for the item; the sum is what gets re-examined** — §3's item 7 binds the **aggregate** only, and its item 8 re-asks the per-item question against a moved tree, so *Adjacent* is this cycle's disposition rather than a discharge.

**Two costs sit under this and the guard names both**: an arc that absorbs everything never terminates, and **filing moves the reasoning from the run with the tree open to a human without it**, a channel **§7's close-out finding also feeds**. **When they conflict, lean toward settling**, since non-termination is visible from inside the loop and backlog transfer is not; **settling is not absorbing**, producing a *decision* where folding produces a *slice*. **Whatever you file or ask carries the reasoning and a recommendation, not a fork.**

**A filed item leaves the loop's hands only by being handed to a person — §6's bar reached through the issue channel rather than the chat one, not a second class beside it.** That class has four shapes: a design decision the arc never discussed; a frozen-contract change, or anything else needing re-agreement first; an irreversible or destructive change; and work whose scope is the user's to size. **Everything outside them the loop carries, for as long as it runs**, and an item still *Adjacent* when the plan empties simply leaves as its own tracked arc — so §7 says which of the two states, **handed over** or **left as its own arc**, a surviving follow-up is in.

Two riders:

- **"Filed" means filed — and *linked* is one act or two.** **The relation decides which: `Part of #<umbrella>` is containment and takes the body backlink AND the native `sub_issues` POST, while a bare `Follows #<N>` on a plain issue is provenance and takes the backlink alone.** `/pipeline:execute`'s follow-up-ownership rule binds this loop as it binds an implementer — **a bullet in a report is not a follow-up** — and **the two-link case is this loop's default**; the call and its database-id trap are in its *File your follow-ups BEFORE you hand back*.
- **A fold is a new slice, never a widening of a live one**, since growing a dispatched slice's scope mid-flight is indistinguishable from the divergence the dispatcher polls for.

---

## 5. Where folded work goes — merge surface outranks slice cohesion

One ordered criterion, ordered rather than balanced: **merge surface first, slice cohesion only as a tiebreaker between placements with the same merge surface.** Cohesion putting an item with the live slice that owns its module loses to a merge surface forty files wide.

**Churn discovered mid-arc goes in a serial wave — one slice, nothing else in flight.** Parallel slices fork from different bases, so a large-footprint change beside them merges textually clean and semantically wrong; and where the shared shape is a **runtime string** — a query key, a table name, a route, a config key — it does not fail to compile at all, splitting one cache entry into two while every gate stays green (`/pipeline:execute`'s *Merging a shared hotspot* is the remedy for a wave that holds one).

**Nothing folded ever joins a wave already dispatched, whatever its size** — those slices forked before the folded item existed, so their do-not-touch boundaries cannot name it. A small fold is fine in the *next* wave, never the live one.

---

## 6. The decide-don't-ask bar

**Wave assignment, fold-vs-file, sizing and re-slicing are this loop's calls to make and report**, not questions to put to the user: decide them, act, and say what you decided in the cycle's record.

Escalate exactly one class of thing: **a product or design fork the code and conventions cannot settle.** Ask in plain chat, **one question at a time, with your recommendation and why**. `skills/decompose/SKILL.md`'s *Step 2 — Validate the plan and fill the gaps* is the canonical statement of that split and binds this loop unchanged; **read it there rather than here.** One thing is specific to a loop: **the bar is applied once per cycle, so setting it slightly too low multiplies**.

**And this loop has two channels to the user, not one — §4's first question is where the bar actually bites.** Most of what reaches a user arrives as a *filed issue* rather than a question in chat, so a bar policed only over questions leaves the larger channel unguarded. Hold both to it.

---

## 7. Loop state and termination

**The umbrella issue body carries the live remaining plan, rewritten every cycle** — state, not history, at the depth §1 assigns, and `/pipeline:write-issue`'s forward-facing rule applies to every rewrite. **One comment per completed increment records what landed and what it invalidated**: comments the history, the body the state.

**The body carries one more piece of arc state, and the loop is the only pass positioned to hold it: the arc's contract-seam map, a running union rather than a per-cycle re-derivation.** Seed it from the issue body's `Seams` field, grow it with each cycle's decomposition, keep it in the **body** beside the plan, never assembled from the comment thread; a closed seam leaves it and §3's item 9 records why (`skills/decompose/SKILL.md`'s *Contract seams* defines it).

Read the issue with `gh issue view <N> --comments`; write the rewritten body and each increment comment through the `gh api` REST endpoints, passing a body read from a file with `--field`, never `--raw-field` (`/pipeline:decompose`'s *GitHub write mechanics*) — only `--field` expands a leading `@` into the file's contents, and the raw form stores the path and **exits 0 with a comment URL**.

**In-chat, with no issue,** the plan and the seam map are **restated in full each cycle** rather than referred back to; past roughly two increments, file an umbrella.

**Termination has two halves and needs both: the remaining plan is empty AND the close-out is green. And the arc's issues are closed — the tracker is part of termination, not a courtesy after it.** Close them yourself rather than trusting a PR's closing keywords, whose firing turns on that PR's base (`/pipeline:execute`'s *Merge & cleanup*).

**And one question the close-out has to answer in writing: did this arc surface a defect or a gap in the pipeline itself?** Exactly one of three — **filed**, naming the issue; **none found**; or **not enabled here**. There is no fourth, and it is a **step with an output**, not a habit: "none found" is cheap but must still be written, since an arc that surfaced nothing and one where nobody asked look identical afterwards.

- **The bar is an observed failure the finding can name** — a run that broke, a rule read and not followed, a check green over a tree it never saw. An improvement you think would be nice is not a finding, and manufacturing one per arc is worse than never asking.
- **That bar rations filing; the corpus ceilings ration what a filed rule costs to read.** This repository caps shipped prose with two `wc -w` ceilings over tracked files under `skills/`: no file over **30,000 words**, and the whole corpus under a **ratchet** lowered to the tree's measured total once a cut lands and never raised. Extraction settles the per-file half alone — the corpus half counts the same words wherever they sit.
- **A finding that clears the bar is FILED — an artifact with a number, and "recorded" is not a second disposition.** Run §4's already-filed search first, with its regression-versus-version-skew test: an open issue carrying that failure takes the observation as a comment, which **satisfies** filing rather than excepting it, and a skew reading takes the *"none found"* route. **The ordinary case here is an observer who is behind**, **"none found" needs no artifact**, and the report is never where a finding lives.
- **Where the issue goes is RESOLVED, never remembered** — the **plugin's own repository**, from the `repository` field of `.claude-plugin/plugin.json`; never the consuming tracker unless the finding is about that project, and never the version-pinned plugin cache, which is not a git repository at all. **The disposition is an issue and only an issue**, and one close-out line names it and the repository.
- **Filing upstream is OFF unless the project turned it on, and a MISSING KEY IS A NO** — `.agents/worktree.json`'s `upstreamFindings`, where only exactly `true` enables it, the opposite of how `sharedResources` reads absence. **Not enabled, the question is still asked and answered in writing** — *not enabled here* — and the finding goes to the maintainer in the run's report in full, the one place a report may house one.
- **Where the resolved target IS the repository the arc is running in, the finding is FILED and the key does not apply**, since the key gates a crossing and nothing crosses. Compare the manifest's `repository` against the arc's origin by owner and name, never as URL strings: **same → file; different → the opt-in applies as it stands**, as it does for an unreadable origin.
- **Genericising a finding is a LEAK GUARD, not tidiness, and it binds whether or not the project opted in.** The tracker is public: a finding **keeps** the failure's shape, the counts and the conclusion, and **never** a file path, a symbol, a route, a branch name, a client or engagement name, or a home directory. **Opt-in is consent to FILE, never to DISCLOSE**, and **each count names its unit**.

**A cycle that lands nothing must stop and report** — a cycle whose remaining plan comes out identical to the one it started with has not advanced, and nothing else stops the loop.

**The loop has three exits and only one is finishing**: it terminates on an empty plan and a green close-out, halts on a cycle that stopped advancing, or halts on §3's item 7 — the exit that does not look like one, since it fires on a loop landing work cleanly.

**Whichever exit the arc leaves by, the follow-ups it leaves behind are told so.** Comment on each issue filed out of this arc that it did not land — the arc is over, this was not folded in, the loop is not coming back — and **which state §4 left it in**. **They are not among the issues the close-out closes**, and **a halt owes this exactly as termination does.**

---

## 8. A verify rider that generalises

**Any slice that renames an identifier crossing a string boundary — a table, a route, a cache key, a config key, an env var, a feature flag — carries a bare-string sweep in its verify bar.** It greps the *old literal* across the whole tree — fixtures, snapshots, generated files, docs and config included — and proves either zero hits or that every survivor is deliberate, since neither check an implementer runs can see a literal in a fixture.

It **attaches to a shape of slice, not to a change**, and **goes into the verify bar at grounding time**, never at review.

---

## 9. What orchestrate does NOT do (hard boundaries)

- **No implementation code, ever.** You ground, dispatch, read merged diffs, and rewrite the plan; take an implementer's turn on the item that "would take a second" and nobody is holding the loop.
- **Never ground beyond the horizon** — the single rule the whole skill exists to enforce. A `file:line` three waves out rebuilds the exact defect this loop replaces, while looking like diligence.

- **Don't reopen the goal.** The loop reshapes *how* the arc gets there, never *what it is for*; a changed goal is a new issue. **This is not in tension with §3's item 7, which is its converse:** item 7 holds the goal fixed and asks whether the plan has drifted, halting rather than restating it.
- **Don't re-slice what is already dispatched.** A live slice's brief is fixed for the life of its worktree and corrections go through `/pipeline:execute`'s stop-and-replace, since an implementer reads its brief once.
- **No merging, no rebasing, no direct push, no self-merge.** `/pipeline:execute`'s hard rules bind this loop unchanged — read them there.
