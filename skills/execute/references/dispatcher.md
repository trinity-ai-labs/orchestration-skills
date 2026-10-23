# Dispatcher

Reference for `skills/execute/SKILL.md` → *First: which role are you?*. **The dispatcher opens this file
first, and it carries every phase in order**; each phase names the reference that says how.

We work off an **integration branch** (`skills/glossary/vocabulary/integration-branch.md`) — the branch this
project's work lands on, **declared** in its own config as `integrationBranch` and never derived, since a
repository's default branch is a different fact that coincides in some projects and not in others. Undeclared,
take it from the main checkout's current branch **and say in your report that you inferred it** — an inferred
integration branch is a base every worktree of the arc forks from, so it is a fact worth stating rather than
one to leave implicit. Never hardcode a version. One task → one worktree → commit, push, PR back into it →
merge → **sync the local integration branch first**, then delete the branch and its worktree.
**One level sits above it: the epic branch** (`skills/glossary/vocabulary/epic-branch.md` defines one;
`skills/execute/references/worktrees-and-branches.md` carries its mechanics) — cut by default for any arc of
more than one slice, merging each slice into the integration branch as it lands being the exception a user
asks for, and never for single-slice work. Per-project values live in each repo's own config
(`skills/execute/references/per-project-config.md`).

**Parallelization is the default, and the project's `sharedResources` decides whether it holds**: where no
entry's `isolatedBy` is `null`, independent tasks run concurrently in their own worktrees and nothing an
implementer runs serializes on a lock; where one is, the slices touching that resource run one at a time.

**One increment is the unit here, and the dispatcher seat is REACHED FROM `/pipeline:orchestrate` rather than
typed** — that loop grounds the **horizon**, dispatches it through this skill, reconciles what remains against
the tree the increment produced, and repeats, so the dispatcher you are is that loop's own half rather than a
second seat it hands work to. **What the SHAPE of the arc decides is how many cycles it runs, never which
command a user typed**: dependency phases are what make an arc take many cycles — a set of leaves all ready at
once is one wave and lands in one — and a standalone issue is one cycle over one leaf.
**So what you finish here is the INCREMENT and never the arc** — whatever remains, empty or not, is reconciled
by the same seat you are standing in rather than by this step.

**A harness guard against spawning sub-agents unbidden is answered by the invocation of a pipeline skill
itself**, and authorizes **exactly the sub-agents the pass you are in declares it uses, and no more**; where a
pass declares none, it authorizes none. Read each pass's own answer in its own file — a roster here would be a
second copy, and nothing would mark which one had gone stale. `skills/procedures/host-tools.md` names your
host's spawn tool.

---

## Polyrepo workspaces

In a **workspace** — sibling repos released together under one `.agents/workspace.json` at a root that is not
itself a git repo — `setup-workspace.sh <branch> [repo ...]`, or `--exclude <repo,repo>`, cuts one worktree
per member under the **same branch name in every one**. Name the repos a task touches; each is an install
— **and naming a repo that owns a cross-repo contract also cuts every consumer of it**, so a slice that
touches ONE member is cut with the worktree helper run inside that member, which lands in the same
workspace layout and applies no closure.
Three things then change for the dispatcher:

- **Verify HEAD in every member — and fetch in every member too**: that comparison reads a remote-tracking
  ref, and those are per-repository, so one fetch leaves every other member's cache stale.
- **Order merges by contract** — a contract and its consumer are two PRs with a mandatory order, the owning
  repo first. Nothing enforces it; you do.
- **Each member gates itself.** As many queues as repos, so per-repo green says nothing about the pair:
  integrated-green is what ships.

---

## The durable gate queue

The heavy gate (`gate` = build + full test suite, which may be partial only where the project declares
`fullGate`) is CPU-saturating, and **the project's `enqueue`/`drain` decide who runs it** — queue mode or
in-line mode, both defined under *Gate mode* below. Either way an implementer holds itself to the cheap
**preflight** — every no-compile check of the gate (`skills/procedures/config-keys.md`), enforced by a hook
where one runs it, git's pre-commit hook or the host's commit-hook row in `skills/procedures/host-tools.md`,
and run by the implementer before each commit where neither does — then pushes, and opens its **draft PR**.

**In queue mode EVERY gate in this flow is one of yours, and while the runner will take them none is run by
hand**: a slice's, against its draft PR once you have read the diff; the epic's **close-out gate** against
its own draft PR, whose shape is draft, panel review with its dimension comments, any fix round, enqueue, gate
comment, posted review, merge — draft-before-gate all along, the panel and the fix round it can earn arriving
with the close-out review (`skills/execute/references/worktrees-and-branches.md`); and the **integration
gate** after a merge onto the integration branch, as a **PR-less ticket** whose verdict settles onto the
ticket (*Gate the integrated whole*); and the **tip audit** each time a tip moves, a PR-less `audit` ticket
run cold that gives way to every other (`skills/glossary/vocabulary/tip-audit.md`). **No gate runs before
dispatch and none in front of a merge into an epic branch** — the audit after one holds no merge. Only a
`full` ticket and the audit run a declared `fullGate`, the `full` ticket on demand, before a release, and at a
close-out whose epic moved the boundary (`skills/procedures/config-keys.md`). A runner scaffolded before the
PR-less ticket refuses it, as one not verified to take the `full` mode may, and only there is a hand-run gate
sanctioned; an audit a runner refuses is skipped, never hand-run. **In a project declaring no
`enqueue`/`drain`** those gates of yours are run by hand in their own worktree, and each slice's is its
implementer's.

⛔ **Fixes that land straight on a long-lived branch share one gate, never one gate each.** Outside an epic —
a bug bash, a test pass, a run of independent fixes into a release or integration branch — each fix still
gets its own worktree, branch and PR for review, but **the gate is per wave, not per PR**: you merge the
reviewed fixes of a wave onto one wave branch cut from the target, open one PR for it, and enqueue that one
ticket; its green merges every fix at once. A full gate costs tens of minutes and runs one at a time, so
gating each ten-minute fix serially makes the queue the bottleneck of the whole run and leaves the machine
saturated by a gate that proves less than the batched one does, since it never tests the fixes together.
**The same arithmetic caps how many implementers you run beside the gate**: size the live set to what the
host takes alongside the runner and whatever else it serves, keep the rest QUEUED, and start the next one as
a slot frees — never dispatch everything you have found the moment you find it. A red wave is bisected by
its failing files to the fix that owns them, which is fixed on its own branch and re-merged; the wave is
re-gated once, never split into per-PR gates.

---

## Dispatcher — four phases, in order

Each phase names the reference that tells you **how**; open it before you act, not when you reach it. The ⛔
lines are the rules whose action needs no reference, so they live here and nowhere else.

**Read the project's config first** — gate mode, the gate and preflight commands, `sharedResources`,
`epicMerge`, the three `autoMerge*` keys deciding whether each merge is yours to make, brief
conventions. Everything below is provisioned from it. →
*The project's config* below for what a dispatch DOES about each value, the merge decision your dispatch
report states included, `skills/execute/references/per-project-config.md` for the readings an implementer
acts on, and
`skills/procedures/config-keys.md` for what each key MEANS and what its absence means. The helper you
provision with is `skills/procedures/worktree-helper.md`, and your host's tool for every capability named
below is `skills/procedures/host-tools.md`.

### 1. Set up → `skills/execute/references/worktrees-and-branches.md`

Decide the branch level — an epic branch cut from the integration branch when the ARC is more than one slice,
unless the user asked this arc to merge each slice as it lands, and the integration branch itself when the
arc is one slice — then cut **one worktree per slice and verify all four invariants** before anything is
dispatched into it.

### 2. Dispatch and watch → `skills/execute/references/dispatching.md`

Write each brief — every setting that changes it named in it, by the reference's table — dispatch, arm the
tick, and, where the project declares `drain`, drain the gate queue on that same tick.

⛔ **Every sub-agent you spawn is a FRESH agent, never a fork.** A fork inherits your whole conversation and
reads your brief as its own instructions — *commit, push, open a PR, enqueue* — and executes it, producing
artifacts nothing can tell from authorized work.

⛔ **You have not dispatched until the divergence tick is armed** — your host's self-paced timer at ≈600s
(`skills/procedures/host-tools.md`), as the **last** act of the turn, after the agents are launched. It is not
how you learn an agent finished; that arrives free. It is for catching a wandering one mid-flight —
**and what you do about what it catches is two levers rather than one**, since most of what a tick surfaces is
a wrong fact you correct by messaging the live agent, not a scope change nobody granted that you stop it over.
**The tick also carries the questions your slices have asked you** — answering one is neither lever and kills
nothing. The reference carries the test.

### 3. Judge what comes back → `skills/execute/references/reviewing.md`

Read the diff and post the verdict you form onto the PR as a review each round, recording in it whether the
slice ran the review pass or skipped it and why. **Where the project declares `enqueue`, enqueue that slice's
gate only once the code is final**, then read the verdict the runner comments; **where it does not**, the
implementer's own verdict is already on the PR, and its hand-back, not that comment, is what you wait on
before you merge. **On an epic branch, plan and run review checkpoints over the epic tip**
(`skills/execute/references/worktrees-and-branches.md`, *Review checkpoints*).

⛔ **Only the merge marks a PR ready — that flag is your signature, never a gate verdict.** A green comment
says a gate finished, not that anyone read the change.

### 4. Land it → `skills/execute/references/landing.md`

Gate the integrated whole with `gate` when a merge onto the integration branch combined work from more than
one slice — a merge into an epic branch takes none, its close-out gating the combined diff — then merge,
clean up and sync as one step, and
close each issue the PR settled with a comment that is its outcome record
(`skills/glossary/vocabulary/outcome-record.md`) — one `gh-post` close per issue,
keyed `outcome/<n>/<pr>` (`skills/procedures/github-writes.md`).

⛔ **Merge commits, never squash; never rebase.** The one exception is an epic branch collapsing back, and only
where the project declared `epicMerge` — its call, not yours at merge time.

⛔ **The three `trinity-ai-labs` skills repos are PR-only** — `market-skills`, `orchestration-skills`,
`framework-skills` — never a direct push to `main`, docs and CHANGELOG included.

---

## The project's config — the dispatcher's readings

**No config is a hard stop rather than a warning, and the stop is yours.** The helper cuts a bare worktree and
says so on stderr only (`skills/procedures/config-keys.md`), and the implementer dispatched into it then fails
its checks for reasons that look like code bugs. So do not dispatch: say the project is not set up and get it
onboarded first.

### Gate mode

Two independent readings, **never inferred from the branch name**, since a rename must not silently change how
a PR is gated — in queue mode both are properties of the **ticket**, set at enqueue.

**Who runs the gate — the project's `enqueue`/`drain` decide it:**

- **Queue mode — both declared: the dispatcher enqueues and the dispatcher drains, and an implementer does
  neither.** The implementer runs `preflight`, pushes, opens a **draft** PR and hands back; **you enqueue that
  slice's ticket (`enqueue`) once you have read its diff**, since nothing should gate a tree you are about to
  have rewritten — which is the order phase 3 already asks for, *review BEFORE you drain*. **Nothing is at
  risk in the gap**: the branch is pushed and the PR open before you are handed anything, so the work is
  durable in git and a ticket nobody queued costs a gate run's latency rather than work. A runner (`drain`)
  then claims tickets **one at a time**, in each ticket's own worktree behind a slim machine-wide slot,
  gating in the mode that ticket declared (*Which gate runs*, below) and commenting the verdict on the PR
  while leaving it draft.
- **In-line mode — neither declared, where it is the project's default rather than a grant, or a slice a
  dispatcher's brief or the dispatching user EXPLICITLY puts there (override mode), never self-granted:** the
  implementer runs `gate` itself, once, in the foreground, comments the result on its own draft PR under the
  `gate-verdict/<leaf>` key, and
  **no ticket is created at all**. The verdict lands *before* the hand-back — wait for the hand-back before
  you tear down the tree or merge (*The PR review loop*).

**The implementer's half reads the same in both, and in neither does it enqueue**: still a draft at
hand-back, never marked ready by the implementer, never its own merge.

**Which gate runs.** A queued project may offer a lighter gate for a prose-only slice (say `--mode docs`
→ `pnpm docs:gate`, not the full `pnpm gate`). A **speed choice, not a workaround**: every worktree gets a
real install, so a light-mode slice that turns out to touch code just enqueues in the default mode and faces
`gate`. **A project declaring `fullGate` adds a `full` mode that runs it, cold, reading no cache**, and that
mode is never a slice's: it gates an on-demand run, a release run and a close-out whose epic moved the
boundary (`skills/glossary/vocabulary/code-shape.md`) alone — for a structure-selected gate a change to its
selection machinery, never shared code alone, whose reach that gate already prints. **Every queued project
also has an `audit` mode**, never a slice's either: the tip audit (`skills/glossary/vocabulary/tip-audit.md`),
a PR-less ticket you enqueue each time a tip moves.

**A base merge invalidates the mode, so re-derive it before you re-enqueue.** Recovering from a `merge-pr`
that stopped at `Base branch was modified` means re-attaching a tree and `git merge origin/<base>` (*Merge &
cleanup*), and that merge can land **code** on a prose-only branch. So derive the mode again from
`git diff --name-only $(git merge-base HEAD origin/<base>) HEAD` — recomputing the fork point *after* the
merge, never carrying a SHA forward — and enqueue in the **default** mode if anything outside the light mode's
prose set appears. It reads the merged **file set**, not the branch name. Nothing else catches it: a
re-enqueued PR carries a gate comment whose SHA matches its head whichever gate ran.

### Five readings that change the flow

- **No `enqueue`/`drain`** → **this project gates in-line, and that is the DEFAULT here rather than a grant**
  (*Gate mode*). The PR is still a draft at hand-back; only who ran the gate changes. **Nothing enqueues here
  at all**, a tip audit included — the command doesn't exist, so a brief telling an implementer to enqueue, or a
  dispatcher reaching for the ticket once it has read the diff, ends with committed work and no handoff.
- **`gate` == `preflight`** → one authoritative check, no separate heavy tier. Nothing for a runner to add,
  so don't build a queue around it or split briefs into "cheap" and "full" bars that are the same command.
- **`fullGate` absent** → **`gate` is the full gate at every seat.** **`fullGate` declared** → that project's
  `gate` may be partial, and you run `fullGate` where `skills/procedures/config-keys.md` places it, as a
  `full`-mode ticket where the project has a queue; every other gate stays `gate`.
- **`targetedTest` declared** → an implementer's one targeted test run is that template with its one of
  `{files}` or `{names}` filled; **absent** → it is single test files, each run singly, never a suite.
- **A `sharedResources` entry whose `isolatedBy` is `null`** → **parallelization is not the default in this
  project.** File-disjoint slices contend for that resource the moment two of them run checks at once.
  **The slot covers less than it looks**: it serializes *drained gates* only, so every implementer's
  `preflight` and targeted test file is uncovered and concurrent — and with **no queue** there is no slot at
  all, so the exposure is the whole fan-out. Narrow the wave to one live slice against that resource, or
  sequence those slices across waves. The contention surfaces as a red in whichever slice lost the race
  (*Reading a gate result*). **A non-null `isolatedBy` leaves the default fan-out in place, and does so for
  either of its two forms**, so the honest answer and the correct dispatch decision are the same answer, and a
  resource that is shared but safe by construction never has to be written `null` to be written truthfully.

### The merge decision — read it here, before you report a dispatch

Three keys decide whether each merge is yours to make, and **the axis they partition is the branch the PR
targets** (`skills/procedures/config-keys.md` carries each one's meaning):

| Key | Governs a PR targeting | Absent |
|---|---|---|
| `autoMergeOntoIntegration` | the integration branch, from a slice | `true` — merges |
| `autoMergeOntoEpic` | an epic branch, from a slice | `true` — merges |
| `autoMergeEpicCloseOut` | the integration branch, from the epic branch's close-out | `false` — holds |

**Only an exact `true` or a wholly absent key on the first two merges; anything else holds**, and **a retired
name the config still declares holds its row's merge** (`skills/procedures/config-keys.md` names them). In an
arc that cuts no epic branch every slice PR reads `autoMergeOntoIntegration`, and `autoMergeOntoEpic` governs
nothing. **Any report stating a merge posture — the dispatch report, a held-merge comment, the merge itself —
names the key it consulted and that key's resolved value**: *`autoMergeOntoIntegration` absent → `true` →
merging*, or for a retired name *`autoMergeTrivial` retired → `autoMergeOntoIntegration` → held*.
The check itself runs at *Merge & cleanup*, after the gate and before the merge.
