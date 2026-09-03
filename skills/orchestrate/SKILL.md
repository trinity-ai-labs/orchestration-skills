---
name: orchestrate
description: >-
  Run an arc of work to completion as a just-in-time loop — the pipeline's last leg, after /pipeline:co-think and /pipeline:write-issue, and the one command you type to take a body of work end to end. Use whenever
  you're asked to ORCHESTRATE or coordinate an arc, an epic, an issue or a batch of tasks, to EXECUTE or RUN
  a plan, to WORK or COMPLETE a GitHub issue, or to SHIP one through to merge. You ground only the HORIZON —
  the next dispatchable increment — via /pipeline:decompose, dispatch it via /pipeline:execute, then
  RECONCILE what is still outstanding against the tree that increment produced, rewrite what remains, and
  repeat until the plan is empty and the close-out is green. Everything past the horizon stays at SHAPE
  depth.
argument-hint: "[issue # or umbrella # to orchestrate — omit to run the plan already in chat]"
---

# Orchestrate — the just-in-time arc loop

The pipeline is **`/pipeline:co-think` → `/pipeline:write-issue` → `/pipeline:orchestrate`**. This skill owns everything after the issue, running the arc to completion one increment at a time.

```
issue / plan  ──/pipeline:orchestrate──▶  ground the horizon · dispatch · reconcile · rewrite the rest  ──▶  repeat until empty
```

You are a **loop, not a builder**: you ground an increment, dispatch it, read the merged diffs, decide what the arc still needs, and rewrite the plan — never editing a source file yourself. **The defect this fixes:** a front-loaded decomposition writes `file:line` into briefs later waves execute, and a brief naming a path an earlier wave renamed is wrong when run, without erroring.

**This file is a SPINE**: the actions below are in order, each naming the pass or reference that carries the *how* and holding the rules that fire at it. **Steps 3 and 4 are performed out of `skills/orchestrate/references/reconciling.md`**, and a reader who reaches the end of this file without opening it has not finished reading this skill.

---

## Two grounding depths, and the horizon that separates them

Every item in the plan sits at exactly one of two depths, decided by where the horizon is — never by how important it is or how well you understand it.

- **Shape depth** — everything *beyond* the horizon: goal, area, dependency, one line on why it comes after the thing before it. **No `file:line`, no owned files, no do-not-touch boundaries, no framework skill, no model tier, no verify bar.** An item at shape depth is not unfinished.
- **Slice depth** — the horizon *only*: everything `/pipeline:decompose` emits — owned files as real paths, do-not-touch boundaries, artifacts derived, depends-on, framework skill, model tier, brief, verify bar — grounded against the tree **right now** and dispatched in the same cycle.

**The horizon is the next dispatchable set: every remaining item whose dependencies have already landed** — usually a wave, or the dispatchable subset of one whose rest still waits on something unmerged. **It is whatever you are about to ground and dispatch in THIS cycle — it moves outward only as increments land, and it is the only thing that promotes an item to slice depth**: not a well-understood item, not one a user asked about, not a small one. Both errors are silent — grounding early writes coordinates that stop existing, dispatching at shape depth leaves an implementer to invent its scope.

---

## 0. Before the loop: the config precondition

Check for `<repo>/.agents/worktree.json` before step 1 grounds anything. **Missing is a hard stop, not a note**: the helper cuts a **bare** worktree instead of failing — no env symlinks, no dependencies — so an implementer's checks fail for reasons shaped like code defects, and the gate, the conventions and the framework skills are all guesses. **It is a precondition on the ARC, not the horizon.**

**Four acts, in order, the first three user-facing.** (1) Say plainly the project is not set up and that you are setting it up first. (2) Explain what onboarding does — ground the repo's scripts and CI, write the config, scaffold a gate queue if wanted, verify by cutting worktrees. (3) **Ask for the values that cannot be ground**, `sharedResources` above all: a guessed one is a safety property that looks present and is not. (4) Invoke `/pipeline:setup`, then resume at step 1. **It terminates at a reviewable change you do not merge** — *Rules that fire at no single action* forbids merging and pushing — so hand the config PR over.

**And the window closes at dispatch.** Once worktrees are live the config is **frozen for the arc**: drift is stop-and-report, never repair, because the helper reads the main checkout's working copy — shared mutable state, which any other session cutting a worktree reads too.

**In the repository that ships these skills, and only there, also fix which copy of them you are running.** The installed plugin you loaded is not the tree being edited, and **the rules an arc has just shipped are the ones likeliest to be missing from it**: read the tree's `skills/` copy of any rule you act on, trust the tree where the two disagree, and say in the close-out which copy you ran from.

## 1. Ground the horizon → `/pipeline:decompose`

On the first cycle read the source plan — `gh issue view <N> --comments`, or the conversation — and work out where the horizon falls: **establishing the horizon is the first cycle's work, not a precondition for starting**. Then invoke `/pipeline:decompose` against that horizon and nothing else, telling it the rest stays at shape depth.

**Read UP before you read DEEP: establish whether the issue is a sub-issue and read the parent before grounding the child.** `/pipeline:decompose` runs that check for you; what you owe it is the instruction to, because step 4 makes an umbrella's body the arc's live remaining plan and missing the parent starts a second plan for one arc.

## 2. Dispatch it → `/pipeline:execute`

Invoke `/pipeline:execute` as the **dispatcher**; worktrees, the epic-branch decision, model tiers, the gate, PR review and merge-not-squash are its mechanics.

⛔ **This step is not finished when the agents are dispatched — it is finished when they have merged, and you owe a divergence tick roughly every 10 minutes in between.** Arm it with `ScheduleWakeup` at ≈600s, callable right here: the tool is not confined to `/loop`. **Arming it is part of dispatching, not something you reach for once something looks wrong** — a dispatch report not naming the armed tick is a step still open — and **arm it LAST, after the implementers are launched.**

**The tick is NOT how you learn an agent finished**, which arrives as a harness notification; it catches a wandering agent mid-flight, and **no reading of `ScheduleWakeup`'s own tool description reaches this requirement**, its polling warning being about polling for completion. Interval, purpose and requirement are settled **here**, because an instruction reached only by a pointer is one a reader can skip while satisfying every step in front of them; each tick you snapshot every live worktree's diff against its **fork point**, drain the gate queue, fast-forward the local integration branch, sweep for parked work, and — where an epic branch is live — merge the integration branch into it in the **epic's own worktree**, never the main checkout.

⛔ **What the tick's prompt may carry: handles, never conclusions** — anything *derived* at arming time is grounding written for a later moment. Carry what you look a fact up **with** (branch, worktree path, PR number) and re-derive what you looked **up**: the file list, whether a revision is outstanding, above all the next action. **The fork-point SHA reads as identity and is not**; recompute it each tick after a fetch.

## 3. Reconcile against the merged tree → `skills/orchestrate/references/reconciling.md`

Run the checklist there — all of it, every cycle, in order — **after the increment has MERGED and against the MERGED tree** rather than the PR diffs: the tree the next increment forks from is the only one that can falsify anything.

## 4. Rewrite the remaining plan → `skills/orchestrate/references/reconciling.md`

Everything the checklist produced is dispositioned by that file's *Fold vs. file*, placed by its *Where folded work goes*, and written back as its *Rewriting the plan* says — **the remaining plan is rewritten in place, not amended**, and it lives with the arc's contract-seam map in the umbrella issue body, as state rather than history, at the depth *Two grounding depths* assigns.

## 5. Repeat, or close out

Back to step 1 with the horizon moved. **A one-increment arc runs one cycle**: ground, dispatch, close out — no umbrella, no rewrite, no reconcile against an empty plan. **Grounding is the one step it does not trim**, because a one-slice plan can still carry a false premise nothing downstream re-checks.

**Termination has two halves and needs both: the remaining plan is empty AND the close-out is green** — the integration gate plus the epic → integration PR. **And the arc's issues are closed — the tracker is part of termination, not a courtesy after it**; close them yourself rather than trusting a PR's closing keywords, which fire only where that PR's base is the repository's **default** branch and never fire later.

**Three exits, and only one is finishing**: an empty plan and a green close-out **terminates**; **a cycle that lands nothing halts** — a remaining plan identical to the one it started with, since nothing else stops the loop; and the checklist's *Scope drift* **halts**, the exit that does not look like one because it fires on a loop landing work cleanly. **Whichever exit the arc leaves by, the follow-ups it leaves behind are told so** — comment on each issue filed out of this arc that it did not land, that the loop is not coming back, and **which state *Fold vs. file* left it in**. **They are not among the issues the close-out closes**, and **a halt owes this exactly as termination does.**

**And one question the close-out answers in writing: did this arc surface a defect or a gap in the pipeline itself?** Exactly one of three — **filed**, naming the issue; **none found**; or **not enabled here**. "None found" is cheap but must still be written, since an arc that surfaced nothing and one where nobody asked look identical afterwards.

- **The bar is an observed failure the finding can name** — a run that broke, a rule read and not followed, a check green over a tree it never saw; an improvement that would be nice is not one, and manufacturing one per arc is worse than never asking. **That bar rations filing; two `wc -w` ceilings ration what a filed rule costs to read** — no shipped file over 30,000 words, and a corpus total under a ratchet lowered once a cut lands and never raised, which extraction cannot buy back because it counts the same words wherever they sit.
- **A finding that clears it is FILED — an artifact with a number, "recorded" is not a second disposition, and the report is never where a finding lives** (*"none found"* needs no artifact). Run *Fold vs. file*'s already-filed search first: an open issue carrying that failure takes the observation as a comment, which **satisfies** filing rather than excepting it, and a version-skew reading — **the ordinary case being an observer who is behind** — takes the *"none found"* route.
- **Where it goes is RESOLVED, never remembered** — the **plugin's own repository**, from `repository` in `.claude-plugin/plugin.json`; never the consuming tracker unless the finding is about that project, and never the version-pinned plugin cache, which is not a git repository at all.
- **Filing upstream is OFF unless the project turned it on, and a MISSING KEY IS A NO** — `.agents/worktree.json`'s `upstreamFindings`, where only exactly `true` enables it. **Not enabled, the question is still asked and answered in writing** — *not enabled here* — and the finding goes to the maintainer in the run's report in full, the one place a report may house one. **Where the resolved target IS the repository the arc is running in the key does not apply and the finding is FILED**, since the key gates a crossing and nothing crosses: compare the manifest's `repository` against the arc's origin by owner and name, never as URL strings, and treat an unreadable origin as different.
- **Genericising is a LEAK GUARD, not tidiness, and binds whether or not the project opted in.** The tracker is public: a finding **keeps** the failure's shape, the counts and the conclusion, and **never** a file path, a symbol, a route, a branch name, a client or engagement name, or a home directory. **Opt-in is consent to FILE, never to DISCLOSE**, and **each count names its unit**.

---

## Rules that fire at no single action

Three rules bind the loop at any moment rather than at one step, so they sit here rather than on one.

- ⛔ **The decide-don't-ask bar. Wave assignment, fold-vs-file, sizing and re-slicing are this loop's calls to make and report**, not questions to put to the user: decide them, act, and record what you decided. Escalate exactly one class — **a product or design fork the code and conventions cannot settle** — in plain chat, **one question at a time, with your recommendation and why**. Two things are specific to a loop: **the bar is applied once per cycle, so setting it slightly too low multiplies**, and **this loop has two channels to the user** — most of what reaches one arrives as a *filed issue* rather than a question in chat, so a bar policed only over questions leaves the larger channel unguarded.
- ⛔ **The bare-string verify rider. Any slice that renames an identifier crossing a string boundary — a table, a route, a cache key, a config key, an env var, a feature flag — carries a bare-string sweep in its verify bar**, grepping the *old literal* across the whole tree, fixtures, snapshots, generated files, docs and config included, and proving either zero hits or that every survivor is deliberate — since no check an implementer runs can see a literal in a fixture. It **attaches to a shape of slice, not to a change**, and **goes in at grounding time**, never at review.
- ⛔ **The boundaries. No implementation code, ever** — take an implementer's turn on the item that "would take a second" and nobody is holding the loop. **Never ground beyond the horizon**, the single rule the whole skill exists to enforce: a `file:line` three waves out rebuilds the exact defect this loop replaces, while looking like diligence. **Don't reopen the goal** — the loop reshapes *how* the arc gets there, never *what it is for*, and a changed goal is a new issue; the checklist's *Scope drift* is its converse rather than a tension with it, holding the goal fixed and asking whether the plan has drifted. **Don't re-slice what is already dispatched**: a live slice's brief is fixed for the life of its worktree, so a correction means stopping that agent and dispatching a fresh one into the same worktree with a tighter brief — an implementer reads its brief once. **And no merging, no rebasing, no direct push, no self-merge.**
