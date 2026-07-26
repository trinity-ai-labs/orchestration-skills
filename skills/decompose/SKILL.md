---
name: decompose
description: >-
  Turn a plan into an orchestration-ready task breakdown — the PREP phase that feeds /orchestrate. Use
  whenever you're asked to DECOMPOSE, break down, slice, or plan-for-parallelism a chunk of work; to get
  a GitHub issue or an in-chat plan READY for orchestration; or to figure out what can run concurrently.
  You read the plan (a GitHub issue OR a plan already in the conversation), GROUND it in the actual
  codebase (real files/modules, not guesses), and emit independent task slices with explicit scope,
  do-not-touch boundaries, dependency waves, the framework skill each slice must invoke, and a model-tier
  hint — exactly what the orchestrator's dispatch loop consumes. You do NOT write code, make worktrees,
  dispatch implementers, or merge — that's /orchestrate's job. For a GitHub issue you either POST the
  decomposition as a comment, or — when the work is large/multi-area enough to warrant it — convert the
  issue into an UMBRELLA and spawn one sub-issue per slice. Pairs with the orchestrate skill.
argument-hint: "[issue # or a description of the plan to decompose — omit to decompose the plan already in chat]"
---

# Decompose — get a plan ready for orchestration

`/orchestrate` ships work off an integration branch: one task → one worktree → one PR → merge. It does its best work when it's handed a **clean, grounded, parallel-aware breakdown** instead of a vague blob it has to slice on the fly. **Decompose is that prep pass.** You take a plan, ground it in the real code, and turn it into independent task slices the orchestrator can dispatch in parallel with minimal collision.

You are a **planner, not a builder.** You read, research, and emit a breakdown (in chat, or onto a GitHub issue). You **never** write code, make worktrees, dispatch implementer sub-agents, or merge — that all belongs to `/orchestrate`. Your deliverable is the *plan it executes*.

**The whole point is to maximize safe parallelism — but parallelism has a price, so the real goal is the *balance*.** A good decomposition is one where the orchestrator can cut N worktrees and run N implementers at once because you've already worked out which slices are independent, which must land first, and where two slices would fight over the same file. What it is **not** is "as many slices as possible." Every slice pays a fixed overhead — a worktree, an install, a review, and **a full gate run**. Implementers don't run that gate themselves (they enqueue it; `/orchestrate` drains the queue and runs the gate one PR at a time behind a slim slot), so a wide fan-out doesn't strand agents waiting on a lock — but the gate is still **serialized on the drain side**: N slices means N sequential gate runs to drain. Each run is cheaper than it looks — a **shared build cache** (turbo, for Trinity) lets a gate *replay* the packages a slice didn't touch near-instantly and only rebuild+retest the ones it did — but the runs still queue behind one slot, so past a point more slices means more total gate + review time, not a faster finish. So aim for the *fewest* slices that still expose the real independence — meaty, cohesive slices over a cloud of fragments. See **Sizing** (Step 3) for the economics, including how the cache rewards **package-disjoint** slicing.

## Two input paths

Decide which one you're in from how you were invoked:

- **In-chat plan** — the user has a plan in the conversation (they wrote one, you produced one in plan mode, or they just described the work). Decompose it and emit the breakdown **in chat**, ending with the handoff line (below).
- **GitHub issue** — you were given an issue (`decompose #1042`, `decompose issue 1042`, "get issue 1042 ready to orchestrate"). Read it with `gh issue view <N>`, ground it, then **write the breakdown back to GitHub** — as a comment, or as an umbrella + sub-issues (see *Writing it back to GitHub*).

If it's ambiguous which path, ask once; don't guess and post to GitHub when the user only wanted it in chat.

---

## Step 1 — Read the plan and ground it in the codebase

A breakdown built from the plan text alone is guesswork — it names files that don't exist and misses the real coupling. **Ground every slice in the actual code first.** This grounding is the single biggest lever on how well the orchestrator does: real paths, real boundaries, real dependencies.

- **Read the source plan fully.** For a GH issue: `gh issue view <N> --comments` (read the body AND the discussion — constraints often live in comments). For an in-chat plan: re-read what the user/you laid out.
- **Research the codebase to anchor each piece.** Spawn `Explore` agents (in parallel — one per subsystem the plan touches) to find the real files, modules, existing patterns to copy, and the consumers a change would ripple into. You need actual paths before you can assign scope and boundaries. Don't skip this to save time — it's the work.
- **Read `AGENTS.md` and the per-project config** (`~/.worktrees/config/<project>.sh`, where `<project>` is the repo's directory name — the same config `/orchestrate` reads). They tell you the **framework skills** to invoke per area, the **gate**, the **docs fast-path prefix**, the **compat policy**, and comment/style conventions. Bake these into each slice so the orchestrator (and its implementers) inherit them. If there's no config, note it — slices just won't carry env/gate specifics.
- **Discover the integration branch**, don't assume it. `git branch --list 'release/*'` / the current branch — slices target the active integration branch, never `main`, never a hardcoded version.

---

## Step 2 — Validate the plan and fill the gaps

Grounding (Step 1) almost always surfaces holes: behavior the plan never specifies, a design fork it leaves open, missing acceptance criteria, scope that's ambiguous about what's in vs. out, a constraint that's implied but never stated. **A breakdown is only as good as the plan under it — slicing a plan with holes just buries the holes inside slice briefs where an implementer hits them mid-build.** So before you slice, validate that the plan is complete enough to slice, and close the gaps.

**Fill what you can yourself — that's the job, not a shortcut.** Most gaps are resolvable from the grounding you already did: the codebase already has a pattern to follow, `AGENTS.md`/config already dictates the convention, the pre-launch/forward-only posture already settles a "do we migrate?" question, or there's a plainly obvious default. When a gap has a sensible answer, **adopt it and write the assumption down explicitly** in the affected slice's brief (`Assumes X (existing pattern in <file>); flag if wrong`) rather than interrupting the user. Filling gaps with grounded, stated assumptions is exactly "do its best to fill in gaps."

**Escalate to the user only the gaps you genuinely can't resolve** — the ones where (a) there's no obvious default, (b) guessing wrong would change the slicing or send an implementer down the wrong path, and (c) the codebase/conventions don't settle it. A product decision ("should deleting an org cascade-delete its projects or soft-archive them?"), a real design fork with no house style, an undefined acceptance bar on something that gates other slices — those are worth a question. Don't ask what you could answer by reading one more file or picking the conventional default.

**When you must ask, ask in plain chat — ONE question at a time.** No option-picker dialogs, no batched wall of questions. State the gap, give your recommendation and why, and ask the single most decision-blocking question. Wait for the answer, fold it in, then ask the next one only if it's still open after that answer (answers often resolve several gaps at once). Order questions by blocking impact — the one that most changes the slice shape first. This keeps the prep conversational and lets the user redirect early instead of reacting to a form.

Only once the plan's decision-blocking gaps are closed (filled-with-assumption or answered) do you move on to slicing. If the user is unavailable and a gap is non-blocking, proceed with the stated assumption and mark it; don't stall the whole decomposition on a minor open question.

---

## Step 3 — Slice into independent tasks

One slice = one worktree = one PR. **Optimize for independence**: the more slices that can run concurrently without touching each other's files, the more the orchestrator parallelizes. Aim for slices that are *cohesive* (one logical change) and *isolated* (own a disjoint set of files).

For **each** slice, produce:

- **Title** + **branch name** with the right prefix (`feat/…`, `fix/…`, `refactor/…`, `docs/…`). Docs-only slices that match the config's `DOCS_BRANCH_PREFIX` get the fast path — flag them.
- **Owns (scope)** — the concrete files / globs / directories this slice is allowed to change. Real paths from your grounding, not guesses.
- **Do NOT touch** — files another slice owns, or that a foundational slice will change. These are the collision guards that let slices run in parallel safely; name them explicitly.
- **Depends on** — which other slices must merge first (or "none — independent"). This is what builds the waves below.
- **Skill to invoke first** — the framework skill the implementer must open with (from `AGENTS.md`/config). For Trinity the split is **app = `solid`, sidecar = `effect-v3`**: a slice with SolidJS UI (`solid-js`, `@solidjs/router`, `@tanstack/solid-query`, Kobalte) opens with the `solid` skill; a slice with Effect-TS on the sidecar (services, layers, HTTP routes, typed errors) opens with the `effect-v3` skill; a full-stack slice invokes both; a pure-docs/config slice, none.
- **Model** — `sonnet` (default: well-scoped, mechanical, mirrors an existing pattern) or `opus` (reserve for genuinely hard: subtle algorithms, ambiguous/design-heavy, tricky concurrency/lifecycle, security-sensitive, large cross-cutting). One line of *why*. Remember: the easier the model, the more explicit the brief must be — Sonnet slices need near-deterministic steps and exact files.
- **Brief** — 2–5 sentences the orchestrator can hand almost verbatim to an implementer: what to build, the existing pattern/file to copy, and the hard boundaries. Include any research-first step.
- **Verify** — what "done" looks like: the behavior, the tests to add/touch, the acceptance check. When you name a whole-package or whole-suite check here, route it through the project's cached runner (Trinity: `pnpm check`, or `turbo run <task> --filter=<pkg>`), never a raw `vitest`/`tsc`/`eslint` — a direct-binary run bypasses the shared cache and goes cold. A single targeted test file run directly is the only sanctioned exception.

**Sizing.** A slice should be a meaningful but reviewable PR — not so small that the worktree/PR overhead dominates (fold trivial bits into a sibling), not so large that it owns half the repo (split it, and the split usually reveals a foundational sub-slice). When two candidate slices can't avoid heavy file overlap, either merge them into one slice or sequence them across waves — don't pretend they're parallel.

**The gate-cost economics (size against the gate, not against an idealized infinite machine).** Every slice becomes a PR that must be gated. Implementers don't run the gate — they enqueue it, and `/orchestrate` drains the queue, running `GATE_CMD` **one PR at a time** behind a slim machine-wide slot (Trinity: `pnpm gate`). So the gate still **doesn't parallelize**: N slices = N sequential drained gate runs, and a wave of 8 tiny slices can burn far more total drain (plus 8 reviews) than the 4 cohesive slices the same work would have gated in. This cost never *strands* anyone — implementers enqueue and hand back rather than blocking on the gate, so fan-out width is bounded by genuine independence, not by the gate — but total gate + review time still scales with slice count. The lever isn't "minimize slices" or "maximize slices" — it's **make each slice carry enough weight that its share of the gate cost is justified.** Concretely:
- **A gate run's cost is proportional to what the slice CHANGED, not a flat number — because of the shared build cache.** Trinity's gate runs through a task-runner (turbo) backed by a shared cache, so a drained gate *replays* every package the slice didn't touch near-instantly (a cache hit — even in a fresh worktree, even if another checkout built it) and only rebuilds + retests the packages the slice actually changed and their dependents. Two sizing consequences fall out of this:
  - **Prefer package-disjoint slices.** A slice confined to one leaf package gates cheap (only that package and its dependents rebuild; everything else replays). Slicing along package boundaries keeps every gate in the wave cheap *and* keeps the slices genuinely independent — the cache rewards the same disjointness the parallelism does.
  - **A slice that touches a low-level shared package gates expensive** — it invalidates every dependent, so its gate rebuilds a large fan-out no matter how small the diff. That's a reason to keep such foundational edits in a *tight Wave-0 slice* (gate the expensive rebuild once) rather than smeared across several slices that each re-pay the full-fanout rebuild. And many slices all churning the *same* hot package don't share cache with each other (they forked independently), so each re-pays that package's cold rebuild — another pull toward disjoint packages.
- **Fold sub-PR fragments.** If a candidate slice would gate in a couple of edits (rename, a one-liner, a single test), it does not deserve its own worktree+gate — fold it into the cohesive sibling it's closest to.
- **Bound wave width to the gate, not to the file-independence.** Two slices being *independent* doesn't mean they should both run if a third cohesive slice could absorb one of them; with a serialized gate, a narrower wave of heavier slices often finishes the whole wave sooner.
- **When you catch yourself splitting for "cleaner boundaries" alone, stop.** Boundary aesthetics are not worth an extra full gate. Split only when the slice is genuinely too big to review *or* the split removes a real merge collision.
- The *scoped* per-commit check implementers run (Trinity: `pnpm check` — fast, unlocked, parallel) is NOT the sizing cost; the **drained full gate** is. If a project's full gate is genuinely cheap, well-cached, or parallelizable, this pressure relaxes and you can fan out wider — so always size against the *actual* `GATE_CMD`, cache, and drain model you read in config, not a default assumption.

---

## Step 4 — The parallelization plan (the part that makes orchestrate good)

Slices alone aren't enough; the orchestrator needs the **shape of the parallelism**. Lay it out explicitly:

- **Waves.** Group slices into waves by dependency. **Wave 0** is the foundational layer that must land first — a schema change, a shared type/interface, a renamed module, a new core service everything imports. Wave 1+ are the consumers that can each run in parallel *once wave 0 merges*. Most epics have a small wave 0 and a wide wave 1.
- **Transient-red window.** If a wave-0 slice is a breaking foundational change (NOT-NULL schema swap, required interface field, renamed export), say so explicitly: the branch's gate won't be fully green again until every consumer migrates, and `/orchestrate` runs its transient-red gate semantics for the consumer slices. Flag which slices live in that window so the orchestrator reads the gate correctly instead of chasing a green exit.
- **Conflict map.** Call out any pair of slices that, despite your best slicing, will touch the same file (e.g. both add a route to the same registry, both add a case to the same exhaustive switch). The orchestrator resolves these **at merge time** (merge one, then merge the other and fix the conflict) — never by rebasing. Naming them up front turns a surprise into a planned merge.
- **Shared hotspots — hoist the seam in Wave 0, don't just name the conflict.** The conflict map handles *pairs* that brush one file. But when **3+ slices must all extend the same structure** — a control loop's `tick()`, a reducer, an event handler, an exhaustive switch — that isn't a conflict to resolve, it's a **decomposition smell**. Parallel slices fork off *different* bases and each edits that structure against a different version, so the merges drift **semantically**: textually clean (git sees no overlapping lines, reports `MERGEABLE`) but behaviorally wrong — e.g. each slice adds its new case only to the sibling branches that existed *when it forked*, leaving a newer sibling silently missing it. The right move is to make the structure **pluggable as a Wave-0 slice**: land the extensibility seam first — an interface / registry / `Monitor[]` the others *register into* — so each consumer adds a self-contained module instead of editing the shared body. That converts a semantic-merge hazard into genuinely independent slices. When you can't hoist the seam (the abstraction isn't worth it, or it's already shipped inline), do both: (1) emit an explicit **shared invariant** in every touching slice's brief — the rule the structure must keep no matter who edits it (*"every parked-state branch must freeze ALL kill-clocks"*, *"every new event type must be handled in BOTH the reducer and the renderer"*) — and (2) mark the hotspot so `/orchestrate` reviews the *merged region semantically*, not just resolves markers. A green integration gate will NOT save you here — it only catches the drift if a test happens to exercise that exact cross-slice interaction.
- **Critical path.** One line: the longest dependency chain (wave 0 → its slowest/most-coupled consumer), so the orchestrator knows where to start and what gates the finish.

Be honest about what is genuinely sequential. Inventing parallelism that isn't there (two slices that both need the same not-yet-built foundation) just makes the orchestrator stop-and-replace agents later. **Real independence > optimistic independence.**

---

## Step 5 — Emit the breakdown

### In-chat path — output format

Emit a structured breakdown. Lead with the parallelization plan (waves + critical path), then the slices. Use this shape:

```
## Decomposition: <plan title>
Integration branch: release/x.x.x

### Parallelization plan
- Wave 0 (must land first): Slice 1
- Wave 1 (parallel after W0): Slice 2, 3, 4
- Wave 2 (parallel after W1): Slice 5
- Transient-red: Slices 2–4 run against the W0 schema change (gate read per orchestrate's transient-red rules)
- Conflicts to merge-resolve: Slice 3 & 4 both edit src/routes/registry.ts
- Critical path: Slice 1 → Slice 4 → Slice 5

### Slice 1 — <title>
- Branch: `feat/<leaf>`   ·   Wave: 0   ·   Depends on: none   ·   Model: opus (foundational schema)
- Skill to invoke first: effect
- Owns: db/schema/*.ts, sidecar/services/foo.ts
- Do NOT touch: any UI under app/ (Wave 1 consumers own those)
- Brief: <2–5 sentences>
- Verify: <acceptance + tests>

### Slice 2 — <title>
...
```

End with the handoff line, verbatim intent:

> **Ready to orchestrate.** Hand this to `/orchestrate` — e.g. `/orchestrate work issue #<N>` (GH path) or "orchestrate this plan" (in-chat path). It will cut a worktree per slice, dispatch implementers wave by wave, review each PR, and merge.

Then **stop.** Do not start making worktrees or writing code — that's the orchestrator's turn.

### GitHub path — see *Writing it back to GitHub* below.

---

## Writing it back to GitHub

For the issue path, decide **comment** vs **umbrella + sub-issues**. Read the issue, ground it (Step 1), validate and fill gaps (Step 2), slice it (Steps 3–4), then choose:

### Comment (the default)
When the work is small-to-medium — a handful of slices that are clearly one release effort and don't each need independent tracking/assignment — **post the whole breakdown as a single comment** on the issue. The orchestrator reads the comment and dispatches from it. Keep the issue itself as the unit of work.

### Umbrella + sub-issues (when warranted)
When the work is **large and multi-area** — many slices, several waves, slices that deserve independent assignment, review, and closure — **convert the issue into an umbrella**:

1. **Rewrite the issue body** into an umbrella overview: the goal, the parallelization plan (waves, conflict map, critical path), and a **tracked checklist** linking each sub-issue (`- [ ] #<sub>`), which GitHub renders as progress.
2. **Create one sub-issue per slice** (or per tightly-coupled slice cluster) containing that slice's full brief — scope, do-not-touch, depends-on, skill-to-invoke, model hint, verify. Title each with its wave (e.g. `[W1] <title>`) so the dispatch order is visible at a glance.
3. **Link them as native sub-issues** where available (GitHub's sub-issue relationship), and *always* keep the umbrella's `- [ ] #N` checklist as the human-readable index — it works regardless and is what reviewers scan.
4. Label the umbrella (`epic`/`umbrella` if such a label exists; create nothing exotic).

Warrant the umbrella; don't reflexively shard a 3-slice issue into 3 issues — that's tracking overhead with no payoff. Rule of thumb: **umbrella when slices span multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**

### GitHub write mechanics (important)
- **Use `gh api` (REST), not `gh issue create`/`gh issue edit` for the writes** — the high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't. Read with `gh issue view` is fine. For writes:
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -f body=@<file>` (write the body to a temp file and reference it — avoids quoting hell with long markdown).
  - New sub-issue: `gh api repos/{owner}/{repo}/issues -f title=… -f body=@<file>` then capture the returned number.
  - Edit umbrella body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -f body=@<file>`.
- **Cross-reference, don't auto-close.** Sub-issues reference the umbrella (`#<umbrella>`); the orchestrator closes each as its PR merges (PRs merge into the integration branch, not `main`, so GitHub won't auto-close).
- End your turn by telling the user what you wrote (umbrella # + sub-issue #s, or the comment link) and the same **Ready to orchestrate** handoff.

---

## What decompose does NOT do (hard boundaries)

- **No code.** You never edit source files. If you catch yourself opening a file to change it, stop — that's an implementer's job.
- **No worktrees.** You never run `setup-worktree.sh`, never use the Agent tool's `isolation: "worktree"` param, never provision anything. Decompose is read-only against the working tree (plus GitHub writes on the issue path).
- **No dispatch, no merge.** You don't spawn implementer sub-agents to build, and you don't merge PRs. (You *do* spawn read-only `Explore`/research agents in Step 1 — that's grounding, not building.)
- **Don't over-decompose.** Granularity that creates more coordination cost than it saves is a regression. When unsure, fewer, well-bounded slices beat many fragile ones. **And remember the gate is a real, serialized cost** (see Sizing): the orchestrator drains gates one PR at a time, so a wider fan-out of thin slices costs more total drain + review time than a narrower set of cohesive ones. Size against the actual `GATE_CMD`, and never split for boundary-aesthetics alone.
- **Hand off, then stop.** Your turn ends at the breakdown + the handoff line. The user (or you, in a fresh `/orchestrate` invocation) takes it from there.

**Why this shape:** the orchestrator already *can* slice work on the fly, but it does so mid-flight, without deep grounding, while also juggling worktrees and merges. A dedicated decompose pass front-loads the expensive thinking — real file scopes, the dependency waves, the conflict map — so the orchestrator spends its budget executing a good plan instead of discovering the plan while executing. Better decomposition in → more safe parallelism and fewer wrong-approach restarts out.
