---
name: decompose
description: >-
  Ground, validate, and slice ONE increment of work into a dispatch-ready breakdown — the grounding pass
  /pipeline:execute invokes each cycle, and a directly-invocable pass for anyone who wants a single breakdown.
  Use whenever you're asked to DECOMPOSE, break down, slice, or plan-for-parallelism a chunk of work; to figure
  out what can run concurrently; and ALSO when the work is plainly a single slice — grounding and validation
  stand on their own, and a plan that needs no splitting can still be wrong. You ground the HORIZON — the next
  dispatchable increment — in the actual codebase (real files/modules, not guesses) and VALIDATE it against what
  the code actually does, surfacing wrong assumptions, unspecified behavior, and defects in the plan itself
  before an implementer builds on them. The horizon emits at SLICE depth (owned files, do-not-touch boundaries,
  depends-on, the framework skill each slice must invoke, a model-tier hint, brief, verify bar); everything past
  it emits at SHAPE depth (goal, area, dependency — no file:line), because coordinates grounded now and executed
  three waves later name paths that stopped existing. You NEVER ground beyond the horizon, and you do NOT write
  code, make worktrees, dispatch implementers, or merge — /pipeline:orchestrate dispatches and merges,
  /pipeline:execute owns the loop around you. On the GitHub path you post the breakdown as a comment, or — when
  the arc is large/multi-area enough — convert the issue into an UMBRELLA with one sub-issue per slice.
argument-hint: "[issue # or a description of the plan to decompose — omit to decompose the plan already in chat]"
---

# Decompose — ground the horizon into dispatchable slices

`/pipeline:execute` runs an arc as a just-in-time loop: ground the next dispatchable increment, dispatch it, reconcile everything still outstanding against the tree that increment actually produced, repeat. `/pipeline:orchestrate` ships each increment off an integration branch: one task → one worktree → one PR → merge, and it does its best work when it's handed a **clean, grounded, parallel-aware breakdown** instead of a vague blob it has to slice on the fly.

**Decompose is the grounding step of that loop.** You take the next dispatchable increment — the **horizon** — ground it in the real code, and turn it into independent task slices the orchestrator can dispatch in parallel with minimal collision. Everything past the horizon you carry forward as *shape*: the goal, the area, what it waits on — never coordinates.

You are a **planner, not a builder.** You read, research, and emit a breakdown (in chat, or onto a GitHub issue). You **never** write code, make worktrees, dispatch implementer sub-agents, or merge — that all belongs to `/pipeline:orchestrate` — and you never run the loop around yourself, which is `/pipeline:execute`'s. Your deliverable is the *increment they execute*.

**The whole point is to maximize safe parallelism — but parallelism has a price, so the real goal is the *balance*.** A good decomposition is one where the orchestrator can cut N worktrees and run N implementers at once across the increment you grounded, because you've already worked out which of its slices are independent, which must land first, and where two of them would fight over the same file. What it is **not** is "as many slices as possible." Every slice pays a fixed overhead — a worktree, an install, a review, and **a full gate run**. Implementers don't run that gate themselves (they enqueue it; `/pipeline:orchestrate` drains the queue and runs the gate one PR at a time behind a slim slot), so a wide fan-out doesn't strand agents waiting on a lock — but the gate is still **serialized on the drain side**: N slices means N sequential gate runs to drain. Each run is cheaper than it looks — a **shared build cache** (turbo, for Trinity) lets a gate *replay* the packages a slice didn't touch near-instantly and only rebuild+retest the ones it did — but the runs still queue behind one slot, so past a point more slices means more total gate + review time, not a faster finish. So aim for the *fewest* slices that still expose the real independence — meaty, cohesive slices over a cloud of fragments. See **Sizing** (Step 3) for the economics, including how the cache rewards **package-disjoint** slicing.

## Three input paths

Decide which one you're in from how you were invoked:

- **Invoked by `/pipeline:execute` for one increment** — the loop hands you an arc and tells you which part of it is the horizon. Ground and slice **that increment only**, emit the remainder at shape depth, and hand the whole thing back to the loop; it dispatches, reconciles, and invokes you again for the next horizon. This is the ordinary path in a multi-increment arc.
- **In-chat plan** — the user has a plan in the conversation (they wrote one, you produced one in plan mode, or they just described the work). Decompose it and emit the breakdown **in chat**, ending with the handoff line (below).
- **GitHub issue** — you were given an issue (`decompose #1042`, `decompose issue 1042`, "slice issue 1042"). Read it with `gh issue view <N>`, ground it, then **write the breakdown back to GitHub** — as a comment, or as an umbrella + sub-issues (see *Writing it back to GitHub*).

If it's ambiguous between the last two, ask once; don't guess and post to GitHub when the user only wanted it in chat.

**All three paths ground the horizon and nothing else — only *who names it* changes.** The loop hands you one; on the other two you work it out yourself from the plan's dependency order, exactly as the loop's first cycle does. *The failure this prevents: reading the horizon as a property of being called by `/pipeline:execute` makes a directly-invoked decomposition the one that grounds the whole arc — the same stale coordinates, reached by deciding the discipline did not apply here.*

**`skills/execute/SKILL.md` section 1 is the authority on the horizon and on the two depths** — what each contains, what promotes an item from one to the other, and the failure that sits under each. Read it there; this skill does not carry a second copy. *The failure this prevents: two statements of one definition drift, and once they disagree nothing marks which is stale, so the copy a reader happens to open wins by accident.*

---

## Step 1 — Read the plan and ground the horizon in the codebase

A breakdown built from the plan text alone is guesswork — it names files that don't exist and misses the real coupling. **Ground every horizon slice in the actual code first.** This grounding is the single biggest lever on how well the orchestrator does: real paths, real boundaries, real dependencies.

**And the grounding stops at the horizon — that boundary is the point of the pass, not a budget saving.** *The failure this prevents: a coordinate grounded now and executed three waves later names a path an earlier wave already moved, and* ***nothing errors*** *— the brief still reads well, the implementer opens a tree where the target is not there, finds the nearest plausible thing, and builds against that. Grounding the whole arc is the version of this pass that looks most thorough at the moment you do it, which is exactly why it is a rule here and not a judgement call.*

- **Read the source plan fully — the whole arc, then ground only its front.** For a GH issue: `gh issue view <N> --comments` (read the body AND the discussion — constraints often live in comments). For an in-chat plan, or an arc handed to you by `/pipeline:execute`: re-read what was laid out. You need all of it to see where the horizon falls and what each remaining item waits on; you *ground* what is inside it.
- **Research the codebase to anchor each horizon slice.** Spawn `Explore` agents (in parallel — one per subsystem the **horizon** touches) to find the real files, modules, existing patterns to copy, and the consumers a change would ripple into. You need actual paths before you can assign scope and boundaries. Don't skip this to save time — it's the work. **Don't extend it to subsystems only a later wave touches**: that research costs exactly as much as the research that pays off, and it is the half that goes stale before anyone spends it.
- **Find the docs each horizon slice will falsify, and put them in that slice's scope.** Every slice that changes user-visible behavior has docs describing that behavior, and they belong in its `Owns` list — named here, where you are looking at the code, not left to the implementer to notice. **Derive them from the behavior, never from a keyword grep.** This is the trap and it is a decomposer's trap specifically: you search the docs for the identifiers your change introduces, get no hits, and conclude nothing is affected — but user-facing prose describes features in plain language and contains none of your new terms by construction, so the grep was always going to come back empty. Ask instead what a reader of each doc currently believes, and which of those beliefs this slice makes false. Then read the candidate docs rather than grepping them; a README paragraph that enumerates something your slice adds a member to is the commonest miss, and no search finds it. **Scoping a doc OUT is a claim you are making from the plan rather than from the diff** — record it as an explicit not-affected-because in the slice, so the implementer can overturn it when the code says otherwise, instead of inheriting it as settled. For an item **beyond** the horizon, record only that it has docs to falsify and in which area — naming the file is grounding, and a doc set is moved and rewritten by an arc exactly as its code is.
- **Read `AGENTS.md` and the per-project config** (`<repo>/.agents/worktree.json`, where `<project>` is the repo's directory name — the same config `/pipeline:orchestrate` reads). They tell you the **framework skills** to invoke per area, the **gate**, the **compat policy**, and comment/style conventions. Bake these into each slice so the orchestrator (and its implementers) inherit them. If there's no config, note it — slices just won't carry env/gate specifics.
- **Discover the integration branch**, don't assume it. `git branch --list 'release/*'` / the current branch — slices target the active integration branch, never `main`, never a hardcoded version. (If Step 4 concludes the epic warrants an **epic branch**, the slices target that instead — but it is cut from this branch, so you still have to find it.)

---

## Step 2 — Validate the plan and fill the gaps

Grounding (Step 1) almost always surfaces holes: behavior the plan never specifies, a design fork it leaves open, missing acceptance criteria, scope that's ambiguous about what's in vs. out, a constraint that's implied but never stated. **A breakdown is only as good as the plan under it — slicing a plan with holes just buries the holes inside slice briefs where an implementer hits them mid-build.** So before you slice, validate that the plan is complete enough to slice, and close the gaps.

**Fill what you can yourself — that's the job, not a shortcut.** Most gaps are resolvable from the grounding you already did: the codebase already has a pattern to follow, `AGENTS.md`/config already dictates the convention, the pre-launch/forward-only posture already settles a "do we migrate?" question, or there's a plainly obvious default. When a gap has a sensible answer, **adopt it and write the assumption down explicitly** in the affected slice's brief (`Assumes X (existing pattern in <file>); flag if wrong`) rather than interrupting the user. Filling gaps with grounded, stated assumptions is exactly "do its best to fill in gaps."

**Escalate to the user only the gaps you genuinely can't resolve** — the ones where (a) there's no obvious default, (b) guessing wrong would change the slicing or send an implementer down the wrong path, and (c) the codebase/conventions don't settle it. A product decision ("should deleting an org cascade-delete its projects or soft-archive them?"), a real design fork with no house style, an undefined acceptance bar on something that gates other slices — those are worth a question. Don't ask what you could answer by reading one more file or picking the conventional default.

**When you must ask, ask in plain chat — ONE question at a time.** No option-picker dialogs, no batched wall of questions. State the gap, give your recommendation and why, and ask the single most decision-blocking question. Wait for the answer, fold it in, then ask the next one only if it's still open after that answer (answers often resolve several gaps at once). Order questions by blocking impact — the one that most changes the slice shape first. This keeps the prep conversational and lets the user redirect early instead of reacting to a form.

Only once the plan's decision-blocking gaps are closed (filled-with-assumption or answered) do you move on to slicing. If the user is unavailable and a gap is non-blocking, proceed with the stated assumption and mark it; don't stall the whole decomposition on a minor open question.

**Validate the horizon; past it, validate only what changes the shape.** A gap inside the increment you are about to dispatch blocks now. A gap three waves out blocks only if it moves a wave boundary, changes the epic-branch answer, or creates a seam — everything else waits for the cycle that grounds it. *The failure this prevents: this pass runs once per increment, so a bar set slightly too wide multiplies — eight cycles of one avoidable question each is eight user turns spent on forks the intervening increments would have settled or made moot, and every one of them teaches the user that the loop cannot be left to run.*

---

## Step 3 — Slice the horizon into independent tasks

One slice = one worktree = one PR. **Optimize for independence**: the more slices that can run concurrently without touching each other's files, the more the orchestrator parallelizes. Aim for slices that are *cohesive* (one logical change) and *isolated* (own a disjoint set of files).

**Everything this step produces is *slice depth*, and slice depth is for the horizon only.** Produce the whole field set below for every item inside the horizon. Outside it, an item carries what **shape depth** allows — goal, area, what it depends on, and one line on why it comes after the thing before it — and **none of the grounded fields**: no branch name, no owned files, no do-not-touch boundaries, no framework skill, no model tier, no brief, no verify bar. At that depth it is a *finished* item, not a slice you ran out of time to write.

*The failure this prevents runs in both directions, and both directions are silent. A beyond-horizon item written at slice depth carries owned-file lists and boundaries that a later wave invalidates before anyone reads them — the stale-coordinate failure Step 1 names. A horizon item left at shape depth gets dispatched with no owned files and no do-not-touch boundary, so the implementer invents its own scope, and the first anyone hears of it is a PR in a sibling slice's core files, by which point the sibling has already forked.*

For **each horizon** slice, produce:

- **Title** + **branch name** with the right prefix (`feat/…`, `fix/…`, `refactor/…`, `docs/…`). Flag a docs-only slice for `orchestrate`'s ticket-scoped `--mode docs` gate (its *Gate mode*) instead of a branch-prefix fast path — that mode is set on the ticket at enqueue, never inferred from the branch name.
- **Owns (scope)** — the concrete files / globs / directories this slice is allowed to change. Real paths from your grounding, not guesses. **This includes the docs the slice falsifies**, named individually — plus, for any doc you considered and left out, a one-line not-affected-because. An implementer told a doc is out of scope will not revisit it, so an unexamined omission ships as a decision.
- **Do NOT touch** — files another slice owns, or that a foundational slice will change. These are the collision guards that let slices run in parallel safely; name them explicitly.
- **Depends on** — which other slices must merge first (or "none — independent"). This is what builds the waves below.
- **Skill to invoke first** — the framework skill the implementer must open with (from `AGENTS.md`/config). For Trinity the split is **app = `frameworks:solid`, sidecar = `frameworks:effect-v3`**: a slice with SolidJS UI (`solid-js`, `@solidjs/router`, `@tanstack/solid-query`, Kobalte) opens with the `frameworks:solid` skill; a slice with Effect-TS on the sidecar (services, layers, HTTP routes, typed errors) opens with the `frameworks:effect-v3` skill; a full-stack slice invokes both; a pure-docs/config slice, none.
- **Model** — `sonnet` (default: well-scoped, mechanical, mirrors an existing pattern) or `opus` (reserve for genuinely hard: subtle algorithms, ambiguous/design-heavy, tricky concurrency/lifecycle, security-sensitive, large cross-cutting). One line of *why*. Remember: the easier the model, the more explicit the brief must be — Sonnet slices need near-deterministic steps and exact files.
- **Brief** — 2–5 sentences the orchestrator can hand almost verbatim to an implementer: what to build, the existing pattern/file to copy, and the hard boundaries. Include any research-first step.
- **Verify** — what "done" looks like: the behavior, the tests to add/touch, the acceptance check. When you name a whole-package or whole-suite check here, route it through the project's cached runner (Trinity: `pnpm check`, or `turbo run <task> --filter=<pkg>`), never a raw `vitest`/`tsc`/`eslint` — a direct-binary run bypasses the shared cache and goes cold. A single targeted test file run directly is the only sanctioned exception.

**Sizing.** A slice should be a meaningful but reviewable PR — not so small that the worktree/PR overhead dominates (fold trivial bits into a sibling), not so large that it owns half the repo (split it, and the split usually reveals a foundational sub-slice). When two candidate slices can't avoid heavy file overlap, either merge them into one slice or sequence them across waves — don't pretend they're parallel.

**The gate-cost economics (size against the gate, not against an idealized infinite machine).** Every slice becomes a PR that must be gated. Implementers don't run the gate — they enqueue it, and `/pipeline:orchestrate` drains the queue, running `gate` **one PR at a time** behind a slim machine-wide slot (Trinity: `pnpm gate`). So the gate still **doesn't parallelize**: N slices = N sequential drained gate runs, and a wave of 8 tiny slices can burn far more total drain (plus 8 reviews) than the 4 cohesive slices the same work would have gated in. This cost never *strands* anyone — implementers enqueue and hand back rather than blocking on the gate, so fan-out width is bounded by genuine independence, not by the gate — but total gate + review time still scales with slice count. The lever isn't "minimize slices" or "maximize slices" — it's **make each slice carry enough weight that its share of the gate cost is justified.** Concretely:
- **A gate run's cost is proportional to what the slice CHANGED, not a flat number — because of the shared build cache.** Trinity's gate runs through a task-runner (turbo) backed by a shared cache, so a drained gate *replays* every package the slice didn't touch near-instantly (a cache hit — even in a fresh worktree, even if another checkout built it) and only rebuilds + retests the packages the slice actually changed and their dependents. Two sizing consequences fall out of this:
  - **Prefer package-disjoint slices.** A slice confined to one leaf package gates cheap (only that package and its dependents rebuild; everything else replays). Slicing along package boundaries keeps every gate in the wave cheap *and* keeps the slices genuinely independent — the cache rewards the same disjointness the parallelism does.
  - **A slice that touches a low-level shared package gates expensive** — it invalidates every dependent, so its gate rebuilds a large fan-out no matter how small the diff. That's a reason to keep such foundational edits in a *tight Wave-0 slice* (gate the expensive rebuild once) rather than smeared across several slices that each re-pay the full-fanout rebuild. And many slices all churning the *same* hot package don't share cache with each other (they forked independently), so each re-pays that package's cold rebuild — another pull toward disjoint packages.
- **Fold sub-PR fragments.** If a candidate slice would gate in a couple of edits (rename, a one-liner, a single test), it does not deserve its own worktree+gate — fold it into the cohesive sibling it's closest to.
- **Bound wave width to the gate, not to the file-independence.** Two slices being *independent* doesn't mean they should both run if a third cohesive slice could absorb one of them; with a serialized gate, a narrower wave of heavier slices often finishes the whole wave sooner.
- **When you catch yourself splitting for "cleaner boundaries" alone, stop.** Boundary aesthetics are not worth an extra full gate. Split only when the slice is genuinely too big to review *or* the split removes a real merge collision.
- The *scoped* per-commit check implementers run (Trinity: `pnpm check` — fast, unlocked, parallel) is NOT the sizing cost; the **drained full gate** is. If a project's full gate is genuinely cheap, well-cached, or parallelizable, this pressure relaxes and you can fan out wider — so always size against the *actual* `gate`, cache, and drain model you read in config, not a default assumption.

---

## Step 4 — The parallelization plan (the part the loop steers by)

Slices alone aren't enough; the orchestrator needs the **shape of the parallelism**, and the loop needs a dependency order to move the horizon along.

**The wave map covers the whole arc; the grounding does not.** A dependency ordering names no files, so laying out waves to the end of the arc is *shape*, not grounding — and it is required rather than merely allowed, because the horizon is *defined* as the next set whose dependencies have landed and there is nothing to compute that from without it. *The failure this prevents: "never ground beyond the horizon" read as "never plan beyond the horizon" drops the wave map, and the next cycle then has no dependency order to move the horizon along — so it re-derives the arc from scratch every cycle, or moves the horizon by guess.*

Lay it out explicitly:

- **Waves.** Group slices into waves by dependency. **Wave 0** is the foundational layer that must land first — a schema change, a shared type/interface, a renamed module, a new core service everything imports. Wave 1+ are the consumers that can each run in parallel *once wave 0 merges*. Most epics have a small wave 0 and a wide wave 1. **Say which wave is the horizon** — the earliest one whose dependencies have all landed, and the only one you grounded. It is usually a whole wave and sometimes only the part of one that is genuinely dispatchable; do not promote the rest on the strength of its blocker landing soon.
- **Transient-red window.** If a wave-0 slice is a breaking foundational change (NOT-NULL schema swap, required interface field, renamed export), say so explicitly: the branch's gate won't be fully green again until every consumer migrates, and `/pipeline:orchestrate` runs its transient-red gate semantics for the consumer slices. Flag which slices live in that window so the orchestrator reads the gate correctly instead of chasing a green exit.
- **Epic branch — answer it explicitly, every time, in one line — when it is yours to answer.** An epic branch is a convergence branch cut from the integration branch that an epic's slices fork from and PR into, so the shared branch never carries the epic half-finished; `/pipeline:orchestrate` owns its lifecycle, and **you are the pass positioned to see whether it is warranted**, because you ground slices in real code and produce the seam map. **Two rules reach for one, and they answer different questions.** *Would a partial state on the shared branch be broken?* — **does any intermediate state leave the integration branch in a condition you would not ship?** If yes, recommend one — at any width from two slices up — and name the unshippable state: the two shapes are a wave-0 foundational change every consumer must follow (the transient-red case above, where the branch is knowingly red for the whole run) and a **contract seam** whose halves must land together (below), which is the same condition arriving by another route. *What does running several slices concurrently cost the shared branch, whether or not each state would ship?* — **multi-slice work you are dispatching in parallel defaults to an epic branch**, on four costs that land regardless of shippability: the base churn of N slices moving under each other, an integration gate that only ever sees interleaved partial trees, N merges to unpick instead of one to revert, and a contract seam far easier to review while both halves still converge on a branch you control. Only when neither rule fires do the slices target the integration branch as usual — say "not needed" and why. Answer it either way: an unanswered question reads as "no" without anyone having asked it. **Neither rule is a slice count, and neither is a busy integration branch.** Counting slices measures how long a partial state sits on the branch, never whether it is broken — a five-slice epic that is independently shippable at every step still answers the first question "no", which is why a count can never answer it; what a count also never showed is that such a run is *operationally* free on the shared branch, and that is the second question's whole subject. So the second rule keys on **your own parallel fan-out on one change**, not on a threshold: unrelated one-slice fixes running side by side are not an epic and cut nothing, and "other sessions are on that branch" stays rejected outright — near-permanently true in a multi-session shop, so as a standalone trigger it degenerates into "always". And **single-slice work never cuts one**: it has no intermediate state to leave behind, cannot churn its own base, gates the tree it produced, is one merge to revert, and has no sibling to hold a seam with. You recommend; `/pipeline:orchestrate` cuts the branch, points the slices at it, and pays its cost (deferred conflicts, mitigated by merging integration → epic on its poll tick — mandatory, and more load-bearing now that the second rule fires on the shape this flow reaches for most often) — the same find/act split as the contract seam map.
  - **A stated instruction settles it — the rules above are for when nobody has decided.** When the user names the approach, that is a decision, not a hypothesis to check: **"do it as an epic" means the branch is decided.** Record it, read this skill and `/pipeline:orchestrate`'s *The epic branch* for the **mechanics** — what the branch is, how it is cut, who owns its lifecycle, what it costs, and the merge-back cadence it requires — and slice against it. Do not re-run either rule to see whether the user was right. **The general form, and it is not specific to this decision: a skill's decision procedure never overrides a stated instruction — once the call is made, the skill is read for how, not for a second opinion.** *The failure this prevents, and the second half is the worse one: the user spends turns repeating an instruction they already gave, and — because this question is answered in one line inside a document that is then handed to `/pipeline:orchestrate` and executed as written — the overruling ships. An unwarranted "not needed" points every slice at the shared integration branch when the user asked for exactly the isolation an epic branch provides, and it produces a perfectly well-formed breakdown, so nothing downstream can tell it apart from a correct one.*
  - **Reconcile the answer against the seam map you just produced.** The answer and the evidence live in one document, so they have to agree: if you wrote down a contract seam whose halves land in different waves — or a wave-0 foundational change every consumer must follow — you cannot answer "not needed" without naming that seam and saying why it does not count. *The failure this prevents: the map and the answer come out of different steps and get read as independent, so the trigger fires on evidence the same breakdown already contains and the answer still comes back "no" — a wrong call reached with every fact needed to get it right already written down.*
- **Conflict map.** Call out any pair of slices that, despite your best slicing, will touch the same file (e.g. both add a route to the same registry, both add a case to the same exhaustive switch). The orchestrator resolves these **at merge time** (merge one, then merge the other and fix the conflict) — never by rebasing. Naming them up front turns a surprise into a planned merge.
- **Shared hotspots — hoist the seam in Wave 0, don't just name the conflict.** The conflict map handles *pairs* that brush one file. But when **3+ slices must all extend the same structure** — a control loop's `tick()`, a reducer, an event handler, an exhaustive switch — that isn't a conflict to resolve, it's a **decomposition smell**. Parallel slices fork off *different* bases and each edits that structure against a different version, so the merges drift **semantically**: textually clean (git sees no overlapping lines, reports `MERGEABLE`) but behaviorally wrong — e.g. each slice adds its new case only to the sibling branches that existed *when it forked*, leaving a newer sibling silently missing it. The right move is to make the structure **pluggable as a Wave-0 slice**: land the extensibility seam first — an interface / registry / `Monitor[]` the others *register into* — so each consumer adds a self-contained module instead of editing the shared body. That converts a semantic-merge hazard into genuinely independent slices. When you can't hoist the seam (the abstraction isn't worth it, or it's already shipped inline), do both: (1) emit an explicit **shared invariant** in every touching slice's brief — the rule the structure must keep no matter who edits it (*"every parked-state branch must freeze ALL kill-clocks"*, *"every new event type must be handled in BOTH the reducer and the renderer"*) — and (2) mark the hotspot so `/pipeline:orchestrate` reviews the *merged region semantically*, not just resolves markers. A green integration gate will NOT save you here — it only catches the drift if a test happens to exercise that exact cross-slice interaction.
- **Contract seams — who *defines* a shape someone else *consumes*.** The conflict map and shared hotspots both key on files: two slices brushing one, or several editing one structure. Neither catches the case where slices touch **no file in common at all** and still break each other, because one produces a shape the other consumes — a return type, a schema field, a tool grant, a prompt variable, a config key. The producer changes what it emits, its own gate is green, the consumer's gate is green, and the break appears only when both are on the branch. Emit a second, separate map: **producer → consumer → the shape between them.** Two seams are the ones a file map structurally cannot see: a producer and consumer in **different languages or different trees** (code defining a value that documentation or a prompt describes — nothing mechanical links them), and a seam with **no compiler between the halves** (a config, a prompt template, a generated brief). Cross-tree seams are the ones to write down most carefully, precisely because nothing else will catch them. Every seam whose halves land in different waves is also evidence for the epic-branch answer above — reconcile the two before you emit either. *The failure this prevents: a run whose slices were perfectly file-disjoint — zero merge conflicts across every worktree — and which still produced several genuine cross-slice breaks, every one of them a contract, none of them visible in a conflict map.*
- **Don't schedule documentation of a model another slice is changing.** A slice that documents a subsystem must land *after* every slice that changes it, or it documents a shape that no longer exists by the time it merges — and unlike stale code, nothing fails. Documentation of a part of the system this epic does NOT touch is exempt and should say so explicitly in the wave note, otherwise "docs last" strands a correction that is already misleading readers. *The failure this prevents: two agents dispatched in parallel because their files were disjoint — one documenting a model, the other rewriting it.*
- **Critical path.** One line: the longest dependency chain (wave 0 → its slowest/most-coupled consumer), so the orchestrator knows where to start and what gates the finish.

Be honest about what is genuinely sequential. Inventing parallelism that isn't there (two slices that both need the same not-yet-built foundation) just makes the orchestrator stop-and-replace agents later. **Real independence > optimistic independence.**

---

## Step 5 — Emit the breakdown

### In-chat path — output format

Emit a structured breakdown. Lead with the parallelization plan (waves + critical path), then the horizon's slices at slice depth, then the remainder at shape depth.

**Label every item's depth, and keep the two in separate sections — never interleaved.** A reader, human or loop, must never have to infer which one they are looking at. *The failure this prevents: an unlabeled shape item reads as a slice somebody left half-finished, and both repairs are wrong. Dispatch it and the implementer gets no owned files and no boundaries. "Finish" it by grounding it and you have written exactly the stale coordinates the horizon exists to prevent. One missing label, two failures, and neither of them errors.*

Use this shape (here the arc is mid-flight, with Wave 0 already merged; on a first cycle the horizon is usually Wave 0 alone and every later wave is shape):

```
## Decomposition: <plan title>
Integration branch: release/x.x.x   ·   Epic branch: feat/<epic-leaf> (or: not needed — <why>)
Horizon: Wave 1 — Slices 2, 3, 4

### Parallelization plan (whole arc — dependency shape, not grounding)
- Wave 0 (landed): Slice 1
- Wave 1 — THE HORIZON, grounded below, dispatch now: Slices 2, 3, 4
- Wave 2 (after W1 — shape depth, grounded next cycle): Slice 5
- Transient-red: Slices 2–4 run against the W0 schema change (gate read per orchestrate's transient-red rules)
- Epic branch: yes — the W0 schema change leaves the branch half-migrated until Slices 2-4 land, and three slices fan out in parallel; slices fork from and PR into it
- Conflicts to merge-resolve: Slice 3 & 4 both edit src/routes/registry.ts
- Critical path: Slice 1 → Slice 4 → Slice 5

### Horizon — SLICE DEPTH (grounded against the tree as it stands right now)

#### Slice 2 — <title>
- Branch: `feat/<leaf>`   ·   Wave: 1   ·   Depends on: Slice 1 (merged)   ·   Model: opus (subtle migration)
- Skill to invoke first: effect
- Owns: sidecar/services/foo.ts, docs/foo.md
- Do NOT touch: any UI under app/ (Wave 2 owns those)
- Brief: <2–5 sentences>
- Verify: <acceptance + tests>

#### Slice 3 — <title>
...

### Beyond the horizon — SHAPE DEPTH (deliberately not grounded: no file:line, no owned files, no boundaries, no model tier)

#### Slice 5 — <title>
- Wave: 2   ·   Depends on: Slices 2–4
- Goal: let a user pick the retention window the W0 schema change made storable
- Area: the settings UI
- Why it comes after: it renders the field Slice 2 adds, so its shape is not decided until Slice 2 merges
```

End with the handoff line, verbatim intent:

> **Horizon ready to dispatch.** `/pipeline:execute` takes it from here: it dispatches this increment through `/pipeline:orchestrate` — a worktree per slice, implementers, gate, PR review, merge — then reconciles the remainder against the tree the increment actually produced and moves the horizon. Say that whether the loop invoked you or a user did; the next step is the same either way.

Then **stop.** Do not start making worktrees or writing code — that's `/pipeline:orchestrate`'s turn — and do not ground the next wave while you are here: moving the horizon is a step of the loop, and the tree that wave will run against does not exist yet.

### GitHub path — see *Writing it back to GitHub* below.

---

## Writing it back to GitHub

For the issue path, decide **comment** vs **umbrella + sub-issues**. Read the issue, ground it (Step 1), validate and fill gaps (Step 2), slice it (Steps 3–4), then choose:

### Comment (the default)
When the work is small-to-medium — a handful of slices that are clearly one release effort and don't each need independent tracking/assignment — **post the whole breakdown as a single comment** on the issue, carrying both depths and their labels exactly as the in-chat format does. The loop reads the comment and dispatches the horizon from it. Keep the issue itself as the unit of work.

### Umbrella + sub-issues (when warranted)
When the work is **large and multi-area** — many slices, several waves, slices that deserve independent assignment, review, and closure — **convert the issue into an umbrella**:

1. **Rewrite the issue body** into an umbrella overview: the goal, the parallelization plan (waves, conflict map, critical path), and a **tracked checklist** linking each sub-issue (`- [ ] #<sub>`), which GitHub renders as progress.
2. **Create one sub-issue per horizon slice** (or per tightly-coupled slice cluster) containing that slice's full brief — scope, do-not-touch, depends-on, skill-to-invoke, model hint, verify. Beyond the horizon, a slice gets a checklist line or a placeholder sub-issue and no brief (below). Title each with its wave (e.g. `[W1] <title>`) so the dispatch order is visible at a glance.
3. **Link them as native sub-issues** where available (GitHub's sub-issue relationship), and *always* keep the umbrella's `- [ ] #N` checklist as the human-readable index — it works regardless and is what reviewers scan.
4. Label the umbrella (`epic`/`umbrella` if such a label exists; create nothing exotic).

Warrant the umbrella; don't reflexively shard a 3-slice issue into 3 issues — that's tracking overhead with no payoff. Rule of thumb: **umbrella when slices span multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**

**A sub-issue may exist ahead of the horizon; a grounded brief may not.** File a beyond-horizon slice as a placeholder when you want it tracked and assignable — title, wave, goal, area, depends-on — and mark it on its face as *shape depth, not yet grounded*. It gets its owned files, do-not-touch boundaries, model tier and verify bar when the horizon reaches it and this pass runs again, against the tree as it will be then. *The failure this prevents: a sub-issue reads as a brief at whatever depth it was written, so an ungrounded one gets dispatched from as though it were finished, and a prematurely grounded one hands an implementer coordinates an intervening wave has already moved — inside a document that reads as settled precisely because it was filed before any of the arc ran.* The umbrella **body** is the live remaining plan and is rewritten every cycle rather than appended to; `/pipeline:execute` section 7 owns that state model.

### GitHub write mechanics (important)
- **Use `gh api` (REST), not `gh issue create`/`gh issue edit` for the writes** — the high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't. Read with `gh issue view` is fine.
- **Write the body to a file and reference it with `-F` (not `-f`).** `-f` is `--raw-field`, which sends its value verbatim: `-f body=@file` stores the literal string `@file` as the comment. Only `-F` expands a leading `@` into the file's contents. This fails in the worst direction — the command exits 0 and prints a comment URL, so the run reports success and the damage is visible only to a human opening the issue. **Verify after** — refetch the body and confirm it's the markdown, not `@path`. For writes:
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"` (a temp file also spares you quoting hell with long markdown).
  - New sub-issue: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>"` then capture the returned number. The title stays `-f` — it's a genuine literal, and only the `@file` value needs `-F`.
  - Edit umbrella body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`.
- **Cross-reference, don't auto-close.** Sub-issues reference the umbrella (`#<umbrella>`); the orchestrator closes each as its PR merges (PRs merge into the integration branch, not `main`, so GitHub won't auto-close).
- End your turn by telling the user what you wrote (umbrella # + sub-issue #s, or the comment link) and the same **Horizon ready to dispatch** handoff.

---

## What decompose does NOT do (hard boundaries)

- **Never ground beyond the horizon.** No `file:line`, no owned-file list, no do-not-touch boundaries, no framework skill, no model tier, no verify bar on any item outside the next dispatchable set — however well you happen to understand it, however small it is, and however directly a user asked about it. Reaching the horizon is the only thing that promotes an item to slice depth. *The failure this prevents: this is the exact defect `/pipeline:execute` exists to fix, rebuilt one item at a time from inside the pass that is supposed to prevent it — and it arrives looking like diligence, because grounding more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the paths.*
- **No code.** You never edit source files. If you catch yourself opening a file to change it, stop — that's an implementer's job.
- **No worktrees.** You never run `setup-worktree.sh`, never use the Agent tool's `isolation: "worktree"` param, never provision anything. Decompose is read-only against the working tree (plus GitHub writes on the issue path).
- **No dispatch, no merge.** You don't spawn implementer sub-agents to build, and you don't merge PRs. (You *do* spawn read-only `Explore`/research agents in Step 1 — that's grounding, not building.)
- **Don't over-decompose.** Granularity that creates more coordination cost than it saves is a regression. When unsure, fewer, well-bounded slices beat many fragile ones. **And remember the gate is a real, serialized cost** (see Sizing): the orchestrator drains gates one PR at a time, so a wider fan-out of thin slices costs more total drain + review time than a narrower set of cohesive ones. Size against the actual `gate`, and never split for boundary-aesthetics alone.
- **No loop.** Reconciling a landed increment against the remaining plan, deciding what folds in and what gets filed, and rewriting the plan are steps 3 and 4 of `/pipeline:execute`'s loop (its section 2), not a sixth step of yours. *The failure this prevents: a pass that reconciles as well as grounds does it against the tree it read at the top of its own turn — which is the tree* ***before*** *the increment merged, and therefore the one tree that cannot falsify anything.*
- **Hand off, then stop.** Your turn ends at the breakdown + the handoff line. `/pipeline:execute` takes it from there — it dispatches this increment, reconciles the rest against the merged tree, and invokes you again for the next horizon.

**Why this shape:** the orchestrator *can* slice work on the fly, but it does so mid-flight, without deep grounding, while also juggling worktrees and merges. A dedicated grounding pass buys that thinking properly — real file scopes, the dependency waves, the conflict map — so the orchestrator spends its budget executing a good plan instead of discovering the plan while executing. Scoping it to the horizon is what keeps the thinking *accurate* as well as deep: grounding is only ever true about the tree it ran against, so it is bought one increment before it is spent rather than once for the whole arc. Better grounding in → more safe parallelism and fewer wrong-approach restarts out; grounding it just in time → briefs that describe the tree the implementer will actually open.
