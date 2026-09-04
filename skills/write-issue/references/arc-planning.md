# Planning the arc — the phase map, sizing, and the epic verdict

Reference for `skills/write-issue/SKILL.md`, Step 3. Nothing downstream re-derives any of it, so **a map left short reads as a finished one**.

## The phase map covers the whole arc

**Map the arc to its end, not to its front** — every phase, in dependency order, each with one line on why it comes after the one before it. It is **required rather than merely allowed**, because the pass that grounds the work is defined against it: the horizon is the earliest phase whose dependencies have all landed, and with no map there is nothing for that to pick out.

- **A dependency ordering names no files, which is why you can write it this far out** and why it does not decay the way a coordinate does. Give each phase a goal and an area; write no `file:line`, no owned files, no fences and no verify bar — those are `/pipeline:decompose`'s at the horizon, and one written here is stale before it is read.
- **Reconcile the map against the seams you wrote**: a producer and its consumer sitting in different phases is a seam the map has to survive, so either name it in both places or move one of the halves into the other's phase.

## Sizing a phase

**A phase boundary is where the branch is independently shippable** — that is the whole test, not a tidy module edge and not an even split of the work.

- **Fewest phases that expose the real sequencing.** Every extra boundary costs a merge, a release and a re-read of the plan, and buys nothing where the work either side of it could have landed together.
- **Never split for tidiness — when you catch yourself splitting for "cleaner boundaries" alone, stop.** Split where a partial state would be broken, or where the piece is too large to land and review as one thing.
- **Read the cost out of the project, never out of a cost model you brought with you.** This pass is project-agnostic, so what a phase costs to land is the repo's own `gate`, its queue and its review load, taken from its config and `AGENTS.md`. How many slices a phase then cuts into is `/pipeline:decompose`'s call against that same gate, at the horizon — you size the phases, it sizes inside one.

## Epic or one slice — answer it in one line, every time

`skills/glossary/vocabulary/epic-branch.md` defines an **epic branch**. `/pipeline:execute` owns its lifecycle; the verdict is yours, because you are the pass that sets the phases it exists to hold.

- **Two rules reach for one, and they answer different questions.** *Would a partial state on the shared branch be broken?* — where any intermediate state leaves the integration branch unshippable, say so at any width from two phases up and name that state: a foundational change every consumer must follow, or a seam whose halves land in different phases. *What does landing one change as N separate merges cost, whether or not each state would ship?* — **multi-phase work defaults to an epic**, because N merges into the shared branch cost base churn under every live worktree, an integration signal that reds on every sibling merge, N-way revert granularity and one release per merge. Answer the first even where the second has already fired: it is what decides whether the epic is **knowingly red**.
- **Neither rule is a count of phases, and neither is a busy integration branch** — counting measures how long a partial state sits on the branch rather than whether it is broken, and the second rule keys on **one change decomposed into phases**, so unrelated one-off fixes side by side are not an epic.
- **Where neither rule fires, write "one slice" and why** — an unanswered question reads as a no, and nothing downstream can tell a verdict you decided from one you skipped. One slice never cuts a branch and takes the shorter path, `/pipeline:decompose` then `/pipeline:execute`, so name that path in the same line and the reader routes without re-deriving it.
- **A stated instruction settles it — the rules above are for when nobody has decided.** "Do it as an epic" means the verdict is made: record it as made and plan against it. A decision procedure never overrides a stated instruction, and once the call is made this reference is read for how, not for a second opinion.
