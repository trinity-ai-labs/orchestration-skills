# Planning the arc — the phase map, sizing, and the epic verdict

Reference for `skills/write-issue/SKILL.md`, Step 3. Nothing downstream re-derives any of it, so
**a map left short reads as a finished one**.

## The phase map covers the whole arc

**Map the arc to its end, not to its front** — every phase, in dependency order, each with one line on why it
comes after the one before it. It is **required rather than merely allowed**, because the pass that grounds
the work is defined against it: the horizon is the set of ready items the earliest such phase holds, and with
no map there is nothing for that to pick out. **The map orders the items you file; it does not replace them**
— the phase is where an item sits, the item is what lands.

- **A dependency ordering names no files, which is why you can write it this far out** and why it does not
  decay the way a coordinate does. Give each phase a goal and an area; write no `file:line`, no owned files,
  no fences and no verify bar — those are `/pipeline:ground`'s at the horizon, and one written here is stale
  before it is read.
- **Reconcile the map against the seams you wrote**: a producer and its consumer sitting in different phases
  is a seam the map has to survive, so either name it in both places or move one of the halves into the
  other's phase.
- **The map covers everything the goal is not TRUE without, which is wider than what the work obviously
  touches** — a map whose every phase is real still reads finished while the sum falls short of the goal, so
  where the goal is *this stops happening*, the piece that stops it recurring is a phase of this arc rather
  than a neighbour of it, however small it is beside the instances it was found among.

## Sizing a phase, and sizing the items inside it

**A phase boundary is where the branch is independently shippable** — that is what decides ORDER and GROUPING,
not a tidy module edge and not an even split of the work. **It is not what a tracked item IS**: a phase
normally spans several PRs, so a plan that files one item per phase files pieces nothing can land whole, and
the tracked unit is the item below it.

- **Fewest phases that expose the real sequencing.** Every extra boundary costs a merge, a release and a
  re-read of the plan, and buys nothing where the work either side of it could have landed together.
- **Never split for tidiness — when you catch yourself splitting for "cleaner boundaries" alone, stop.** Split
  where a partial state would be broken, or where the piece is too large to land and review as one thing.
- **Read the cost out of the project, never out of a cost model you brought with you.** This pass is
  project-agnostic, so what a phase costs to land is the repo's own `gate`, its queue and its review load,
  taken from its config and `AGENTS.md`. **How many items a phase holds is yours as well**, decided here
  against that same gate: the grounding pass grounds the items you filed and never cuts one into two, so an
  oversized item has no seat downstream to fix it.

## Sizing an item — it is written to close inside ONE cycle

**Write every item to close inside ONE cycle — one item, one PR** (`skills/glossary/vocabulary/umbrella.md`) —
**and split one that cannot, here, at filing time, before the arc starts**, since an item spanning two PRs
leaves a checklist line unable to tick while real work lands. **This is the altitude the phase list already
sits at rather than grounding**: it asks how big a piece is, never which files it touches.

- **Nothing downstream cuts an item for you**, so a level you leave uncut stays uncut — the pass that grounds
  the work grounds the leaves you filed and adds none.
- **Where you cannot tell whether a piece is one PR, keep it whole** — an item too small buys its own
  worktree, install, gate run and review pass and comes back mid-arc as a report to re-author it together with
  its neighbours, where one too big is reported back to you mid-arc and re-planned against a colder tree;
  neither direction is a cut anyone downstream can make for you.
  **Both reports are answered at one seat** — `skills/write-issue/SKILL.md`'s
  *A re-author reported back from a live arc is a fourth way in*, which carries the mechanics: what the
  replacement is, and what becomes of the leaves it supersedes.

## Epic or one slice — answer it in one line, every time

`skills/glossary/vocabulary/epic-branch.md` defines an **epic branch**. `/pipeline:execute` owns its
lifecycle; the verdict is yours, because you are the pass that sets the phases it exists to hold.

- **Two rules reach for one, and they answer different questions.** *Would a partial state on the shared
  branch be broken?* — where any intermediate state leaves the integration branch unshippable, say so at any
  width from two phases up and name that state: a foundational change every consumer must follow, or a seam
  whose halves land in different phases. *What does landing the arc as N separate merges cost, whether or
  not each state would ship?* — **an arc of more than one item defaults to an epic** — unrelated fixes
  grouped into one release included, since grouping them is what makes them one arc — because N merges into
  the shared branch cost base churn under every live worktree, an integration signal that reds on every
  sibling merge, N-way revert granularity and one release per merge. Answer the first even where the second
  has already fired: it is what decides whether the epic is **knowingly red**.
- **Neither rule is a busy integration branch, and the first is not a count of phases** — counting measures
  how long a partial state sits on the branch rather than whether it is broken. The second keys on the
  **arc**: separate one-item arcs run side by side are each one slice and cut nothing, while the same fixes
  filed as one arc are its items and take the default.
- **Where the arc is one item, write "one slice" and why** — an unanswered question reads as a no, and nothing
  downstream can tell a verdict you decided from one you skipped. **One slice never cuts a branch**, so say
  that in the same line and the seat that reads it provisions off the integration branch without re-deriving
  the verdict. **Merging a multi-item arc into the integration branch item by item is the exception**, and
  only the user's instruction for this arc takes it: write "merge as it goes" and that it was asked for, or
  the seat that reads the verdict cuts the default.
- **A stated instruction settles it for the arc it was given for — the rules above are for when nobody has
  decided this one.** "Do it as an epic" or "merge as it goes" means the verdict is made: record it as made
  and plan against it. The next arc starts from the rules above again unless the user says otherwise for it.
  A decision procedure never overrides a stated instruction, and once the call is made this reference is read
  for how, not for a second opinion.
