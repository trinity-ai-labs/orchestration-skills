---
name: decompose
description: >-
  The PRE-EXECUTION GROUNDING pass: take the deliberately big-picture issues a plan has made ready, verify
  their assumptions against the code, fill in the detail an executor acts on, ENRICH each issue with it,
  and hand a dispatcher the ready set as one dispatch-ready breakdown. It runs on both paths — invoked
  directly between /pipeline:write-issue and /pipeline:execute on a single issue, and once per cycle inside
  /pipeline:orchestrate on an epic. Use whenever you are asked to DECOMPOSE, break down, ground or
  plan-for-parallelism a chunk of work; to work out what can run concurrently; and ALSO when the work is
  plainly one slice, since a plan that needs no splitting can still be wrong. You ground the HORIZON — the
  set of ready issues, ONE SLICE EACH — in the actual
  codebase at the depth an executor acts on, and VALIDATE it against what the code really does, surfacing
  wrong assumptions, unspecified behavior and defects in the plan before an implementer builds on them. The
  horizon emits at SLICE depth (goal, owned files, boundaries, derived artifacts, depends-on, framework skill, model
  tier, brief, verify bar);
  everything past it at SHAPE depth (goal, area, dependency — no file:line). You NEVER add a level to the
  plan's tree: an issue too big to be one PR is reported back to the plan, never cut into slices here, and
  several that are one PR's worth of one change go back the same way rather than being merged here. On
  the GitHub path you post what you ground as a comment on the issue it belongs to.
argument-hint: "[issue # or a description of the plan to decompose — omit to decompose the plan already in chat]"
---

# Decompose — ground the horizon: the ready issues, one slice each

**Decompose is the pass between a plan and an executor, and it runs on both of the pipeline's paths** — invoked directly on a **single issue** (`/pipeline:write-issue` → `/pipeline:decompose` → `/pipeline:execute`, no loop anywhere in it), and once per cycle as the grounding step of `/pipeline:orchestrate`'s loop on an **epic**. Either way the issues reaching you are deliberately **big-picture**: you take the **horizon** — the set of ready issues, **one slice each** — ground each in the real code **at the depth an executor acts on**, **enrich each issue with what you found**, and hand a dispatcher the ready set it can run in parallel with minimal collision. Everything past the horizon carries forward as *shape*: goal, area, what it waits on — never coordinates. You are a **planner, not a builder**.

⛔ **You never add a level to the plan's tree** (`skills/glossary/vocabulary/umbrella.md`): **walk to the ready leaves and ground them** — adding no level, no leaf the plan does not already hold, never cutting one leaf into two and never merging two into one — either way a checklist line is left unable to tick while real work lands: two slices where the plan held one land work no tracked item stands for, and one slice spanning two of them ticks neither. (Giving a leaf the plan already carries its own number is not adding one.)

**Parallelism has a price, so what you choose is WAVE WIDTH — how many of the ready issues go out together — never a slice count you manufacture**: every issue pays a worktree, an install, a gate run, a diff you read yourself, and a review pass that is **several fresh readers rather than one unit beside the other three — up to one per dimension, and how many fire is that pass's own per-slice call** — so N issues in a wave is N serialized gate runs, N diffs you cannot delegate, and that reader count again on every slice that runs a pass. Take the *fewest* that still expose the real independence (`skills/decompose/references/slicing.md`'s *Sizing* carries the economics, and the altitude it is measured at).

⛔ **Read `skills/ground-rules/SKILL.md` before you act on anything in this file — it binds you before this file does.** Never a fork, and every searcher you spawn is itself the last agent in its chain.

**This file is a SPINE, not the whole of your instructions.** Each action below names the reference that says *how* and carries the rules that fire at that action; **a reader who reaches the end of this file has not finished reading this skill.**

## Three input paths

- **Invoked by `/pipeline:orchestrate` for one increment** — the loop names the horizon. Ground **that increment only**, emit the remainder at shape depth, hand it back.
- **In-chat plan** — decompose it and emit the breakdown **in chat**, ending with the handoff line.
- **GitHub issue** (`decompose #<issue>`) — read it with `gh issue view <N>`, ground it, then write the breakdown back to GitHub. Ask once if it's ambiguous between this and the in-chat path.

**All three paths ground the horizon and nothing else — only *who names it* changes.** On the direct paths you work it out from the plan's dependency order, as the loop's first cycle does. The horizon (`skills/glossary/vocabulary/grounding-depth.md`) alone emits at **slice depth**; everything past it emits at **shape depth**. `skills/glossary/vocabulary/grounding-depth.md` carries both, and the slice-field list it names is the canonical one.

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

**Validate the horizon; past it, validate only what changes the shape** — a gap three waves out blocks only if it moves a wave boundary or creates a seam. **A falsified phase boundary, an epic verdict, or an issue grounding shows cannot be ONE PR is reported onto the issue, never answered again here** — all three were settled where the arc was planned, and a pass that overrides one leaves two plans for one arc. **The third is the safety valve and it is a REPORT rather than a split**: the answer to an oversized issue is another child authored where issues are authored, so cutting it here instead ships slices no tracked item stands for. **That valve runs both ways and the second direction is reported identically** — *these N ready leaves are one PR's worth of one change* goes onto the issue exactly as *cannot be ONE PR* does, and stays a report rather than a merge you perform, since a slice spanning two tracked items leaves a checklist line that cannot tick just as a cut leaf does. **Name the evidence only grounding holds**: the same mechanical change, with no ordering between them, no contract seam and no verify bar that differs — disjoint owned files being the constraint every wave already meets rather than evidence of anything. This pass runs once per increment, so a bar set slightly too wide costs a user turn every cycle.

### 3. Ground each ready issue, and size the wave → `skills/decompose/references/slicing.md`

**Ground each ready issue as the one slice it already is** (`skills/glossary/vocabulary/umbrella.md`). Produce each horizon slice's fields — `Goal`, `Owns`, `Do NOT touch`, `Derives`, depends-on, skill to invoke, model tier, brief, verify bar — read them against each other, size the wave against the gate, then lay the waves out inside the issue's phase order, with the conflict map and the contract seams. **Those fields are what you ground PER ISSUE and never instructions for carving one up** — catch yourself producing two slices from one issue and you are looking at the defect this action exists not to commit.

**A wave is a SET OF READY ISSUES run in parallel** — three are ready, so ground three, dispatch three, land three — which is why `skills/decompose/references/slicing.md`'s *Sizing* prices how many issues go in a wave and never a cut inside one. **An issue that cannot be one PR goes back as the report action 2 names**, since answering it here is the split that decouples a cycle from the board — **and N ready issues grounding shows are one PR's worth of one change go back the same way**, since merging them here is that same decoupling in reverse.

⛔ **Everything this action produces is *slice depth*, and slice depth is for the horizon only.** Both errors are silent: an item past the horizon at slice depth carries coordinates a later wave invalidates, and a horizon item left at shape depth is dispatched with no scope, so the implementer invents its own.

### 4. Emit the breakdown → `skills/decompose/references/emitting.md`

In chat, or back onto each ready issue as a comment. **Writing it back is what enriches the issue** — the detail an executor acts on lands where the next reader finds it rather than only in this turn's output. Lead with the parallelization plan, then the horizon at slice depth, then the remainder at shape depth, and end with the handoff line.

⛔ **Label every item's depth, and keep the two in separate sections — never interleaved.** An unlabeled shape item reads as a slice somebody left half-finished, and both repairs are wrong — dispatch it and the implementer gets no scope, "finish" it by grounding it and you have written the stale coordinates the horizon exists to prevent.

⛔ **Then stop.** Your turn ends at the breakdown plus the handoff line: don't start making worktrees or writing code, and don't ground the next wave while you are here, because the tree that wave will run against does not exist yet.

---

## Rules that fire at no single action

- ⛔ **Never ground beyond the horizon** — no `file:line`, no owned-file list, no boundaries, no framework skill, no model tier, no verify bar on any item outside the next dispatchable set, however well you understand it and however directly a user asked. Grounding more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the paths.
- ⛔ **An enumeration you emit carries its count, and the count says what it counts.** A set has nothing in it to say it is short, so a truncated list names real files in the right format and reconciles with every other field — take the number from the command that filtered nothing, write it beside the list, and name the unit or the command, since `wc -l` counts matching lines fed a `grep` and members fed a file list. `skills/decompose/references/grounding.md`'s *An enumeration is a claim* carries the sweep mechanics.
- ⛔ **No code, no worktrees, no dispatch, no merge** — `/pipeline:execute` dispatches and merges, `/pipeline:orchestrate` owns the loop around you. You never edit a source file, and if you catch yourself opening one to change it, stop; never run a worktree helper or any harness auto-provisioner; never spawn implementer sub-agents to build; never merge a PR. Decompose is read-only against the working tree, plus GitHub writes on the issue path — the read-only search agents in action 1 are grounding, not building.
- ⛔ **No loop, and no over-decomposition.** Reconciling a landed increment, deciding what folds in and what gets filed, and rewriting the plan are steps of `/pipeline:orchestrate`'s loop — a pass that reconciles as well as grounds does it against the tree it read at the top of its own turn, the one tree that cannot falsify anything. And coordination that costs more than it saves is a regression, because the gate is a real serialized cost.
