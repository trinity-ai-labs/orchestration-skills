---
name: decompose
description: >-
  The PRE-EXECUTION GROUNDING pass: take a deliberately big-picture issue, verify its assumptions against
  the code, fill in the detail an executor acts on, ENRICH the issue with it, and slice ONE increment into
  a dispatch-ready breakdown. It runs on both paths — invoked directly between /pipeline:write-issue and
  /pipeline:execute on a single slice, and once per cycle inside /pipeline:orchestrate on an epic. Use
  whenever you are asked to DECOMPOSE, break down, slice or plan-for-parallelism a chunk of work; to work
  out what can run concurrently; and ALSO when the work is plainly one slice, since a plan that needs no
  splitting can still be wrong. You ground the HORIZON — the next dispatchable increment — in the actual
  codebase at the depth an executor acts on, and VALIDATE it against what the code really does, surfacing
  wrong assumptions, unspecified behavior and defects in the plan before an implementer builds on them. The
  horizon emits at SLICE depth (goal, owned files, boundaries, depends-on, framework skill, model tier, brief, verify bar);
  everything past it at SHAPE depth (goal, area, dependency — no file:line). On the GitHub path
  you post the breakdown as a comment, or convert the issue into an UMBRELLA of one sub-issue per slice.
argument-hint: "[issue # or a description of the plan to decompose — omit to decompose the plan already in chat]"
---

# Decompose — ground the horizon into dispatchable slices

**Decompose is the pass between a plan and an executor, and it runs on both of the pipeline's paths** — invoked directly on a **single slice** (`/pipeline:write-issue` → `/pipeline:decompose` → `/pipeline:execute`, no loop anywhere in it), and once per cycle as the grounding step of `/pipeline:orchestrate`'s loop on an **epic**. Either way the issue reaching you is deliberately **big-picture**: you take the **horizon** — the next dispatchable increment — ground it in the real code **at the depth an executor acts on**, **enrich the issue with what you found**, and turn it into independent slices a dispatcher can run in parallel with minimal collision. Everything past the horizon carries forward as *shape*: goal, area, what it waits on — never coordinates. You are a **planner, not a builder**.

**Maximize safe parallelism, but parallelism has a price, so the goal is the *balance***, not as many slices as possible: every slice pays a worktree, an install, a review and a gate run, and gates drain one at a time, so N slices is N serialized gate runs plus N reviews. Aim for the *fewest* slices that still expose the real independence (`skills/decompose/references/slicing.md`'s *Sizing* carries the economics, and the altitude it is measured at).

**This file is a SPINE, not the whole of your instructions.** Each action below names the reference that says *how* and carries the rules that fire at that action; **a reader who reaches the end of this file has not finished reading this skill.**

## Three input paths

- **Invoked by `/pipeline:orchestrate` for one increment** — the loop names the horizon. Ground and slice **that increment only**, emit the remainder at shape depth, hand it back.
- **In-chat plan** — decompose it and emit the breakdown **in chat**, ending with the handoff line.
- **GitHub issue** (`decompose #<issue>`) — read it with `gh issue view <N>`, ground it, then write the breakdown back to GitHub. Ask once if it's ambiguous between this and the in-chat path.

**All three paths ground the horizon and nothing else — only *who names it* changes.** On the direct paths you work it out from the plan's dependency order, as the loop's first cycle does. **The horizon is the next dispatchable set: every remaining item whose dependencies have already landed.** It alone emits at **slice depth** — owned files, boundaries, depends-on, framework skill, model tier, brief, verify bar, grounded against the tree right now; everything past it emits at **shape depth** — goal, area, what it waits on and why, and none of the grounded fields.

---

## The actions, in order

### 1. Ground the horizon in the real code → `skills/decompose/references/grounding.md`

Read the source plan whole, **re-derive the citations it carries at the depth an executor acts on** — the issue was written to what the arc rests on, and a brief needs the coordinate an implementer actually opens — read UP to any umbrella above it, then ground **only its front**: the real files each horizon slice touches, what it falsifies, the tests its callers own, the artifacts a regenerator owns, and the project's own `AGENTS.md`, config and integration branch.

### 2. Validate the plan and fill the gaps

Grounding almost always surfaces holes: unspecified behavior, an open design fork, missing acceptance criteria, ambiguous scope, an implied but unstated constraint. **Slicing a plan with holes buries them inside slice briefs where an implementer hits them mid-build.**

**Fill what you can yourself — that's the job, not a shortcut.** Most gaps are resolvable from the grounding you did: an existing pattern, `AGENTS.md`/config, the pre-launch/forward-only posture, a plainly obvious default. **Adopt the answer and write the assumption down explicitly** in the affected slice's brief (`Assumes X (existing pattern in <file>); flag if wrong`) rather than interrupting the user.

**Escalate only the gaps you genuinely can't resolve** — no obvious default, guessing wrong would change the slicing or send an implementer down the wrong path, and the codebase and conventions don't settle it: a product decision, a design fork with no house style, an undefined acceptance bar that gates other slices. Don't ask what one more file would answer.

**Hold a question to the same bar as an issue — a question handed up is a deferral wearing different clothes.** And one rule gates it: **establish why a thing is the way it is before you disposition it** — trace what looks wrong to the constraint it satisfies or the consumer it exists for, and where it has a valid reason and is idiomatic for its context, leave it and record that you checked.

**When you must ask, ask in plain chat — ONE question at a time.** State the gap, give your recommendation and why, ask the single most decision-blocking question, wait, fold the answer in, then ask the next only if still open. No option-picker dialogs, no batched wall. If the user is unavailable and a gap is non-blocking, proceed with the stated assumption and mark it.

**Validate the horizon; past it, validate only what changes the shape** — a gap three waves out blocks only if it moves a wave boundary or creates a seam. **A falsified phase boundary or epic verdict is reported onto the issue, never answered again here** — both were settled where the arc was planned, and a pass that overrides one leaves two plans for one arc. This pass runs once per increment, so a bar set slightly too wide costs a user turn every cycle.

### 3. Slice the horizon, and size the wave → `skills/decompose/references/slicing.md`

One slice = one worktree = one PR. Produce each horizon slice's fields — `Goal`, `Owns`, `Do NOT touch`, `Derives`, depends-on, skill to invoke, model tier, brief, verify bar — read them against each other, size the wave against the gate, then lay the waves out inside the issue's phase order, with the conflict map and the contract seams.

⛔ **Everything this action produces is *slice depth*, and slice depth is for the horizon only.** Both errors are silent: an item past the horizon at slice depth carries coordinates a later wave invalidates, and a horizon item left at shape depth is dispatched with no scope, so the implementer invents its own.

### 4. Emit the breakdown → `skills/decompose/references/emitting.md`

In chat, or back onto the issue as a comment or as an umbrella with one sub-issue per slice. **Writing it back is what enriches the issue** — the detail an executor acts on lands where the next reader finds it rather than only in this turn's output. Lead with the parallelization plan, then the horizon at slice depth, then the remainder at shape depth, and end with the handoff line.

⛔ **Label every item's depth, and keep the two in separate sections — never interleaved.** An unlabeled shape item reads as a slice somebody left half-finished, and both repairs are wrong — dispatch it and the implementer gets no scope, "finish" it by grounding it and you have written the stale coordinates the horizon exists to prevent.

⛔ **Then stop.** Your turn ends at the breakdown plus the handoff line: don't start making worktrees or writing code, and don't ground the next wave while you are here, because the tree that wave will run against does not exist yet.

---

## Rules that fire at no single action

- ⛔ **Never ground beyond the horizon** — no `file:line`, no owned-file list, no boundaries, no framework skill, no model tier, no verify bar on any item outside the next dispatchable set, however well you understand it and however directly a user asked. Grounding more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the paths.
- ⛔ **An enumeration you emit carries its count, and the count says what it counts.** A set has nothing in it to say it is short, so a truncated list names real files in the right format and reconciles with every other field — take the number from the command that filtered nothing, write it beside the list, and name the unit or the command, since `wc -l` counts matching lines fed a `grep` and members fed a file list. `skills/decompose/references/grounding.md`'s *An enumeration is a claim* carries the sweep mechanics.
- ⛔ **No code, no worktrees, no dispatch, no merge** — `/pipeline:execute` dispatches and merges, `/pipeline:orchestrate` owns the loop around you. You never edit a source file, and if you catch yourself opening one to change it, stop; never run a worktree helper or any harness auto-provisioner; never spawn implementer sub-agents to build; never merge a PR. Decompose is read-only against the working tree, plus GitHub writes on the issue path — the read-only search agents in action 1 are grounding, not building.
- ⛔ **No loop, and no over-decomposition.** Reconciling a landed increment, deciding what folds in and what gets filed, and rewriting the plan are steps of `/pipeline:orchestrate`'s loop — a pass that reconciles as well as grounds does it against the tree it read at the top of its own turn, the one tree that cannot falsify anything. And coordination that costs more than it saves is a regression, because the gate is a real serialized cost.
