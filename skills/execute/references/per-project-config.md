# Per-project config

Reference for `skills/execute/SKILL.md`. **Read the project's config before you cut a worktree, write a brief,
or run a project's gate** — `cat <repo>/.agents/worktree.json`, since every value in it is per-repo and
nothing derives it from the tree you are standing in.

**What each key MEANS, and what its absence means, is `skills/procedures/config-keys.md`.** This file carries
what a DISPATCH does about those values: which gate mode the project is in, the three readings that change the
flow, and the routing rule that sits on top of them.

**No config is a hard stop rather than a warning, and the stop is yours.** The helper cuts a bare worktree and
says so on stderr only (`skills/procedures/config-keys.md`), and the implementer dispatched into it then fails
its checks for reasons that look like code bugs. So do not dispatch: say the project is not set up and get it
onboarded first.

## Gate mode

Two independent readings, both properties of the **ticket** and set at enqueue —
**never inferred from the branch name**, since a rename must not silently change how a PR is gated.

**Who runs the gate.** By default the implementer runs `scopedCheck`, pushes, opens a **draft** PR and
enqueues; a runner drains the ticket, gates it and comments the verdict. **Override gate mode** is the other:
the implementer runs `gate` itself, in the foreground, comments the result on its own draft PR, never
enqueuing. Two routes: a dispatcher's brief or the dispatching user **explicitly** puts a slice there, never
self-granted, **or the project declares no `enqueue` and no `drain`, where in-line gating is the DEFAULT
rather than a grant.** **The implementer's half is unchanged in both**: still a draft at hand-back, never
marked ready by the implementer, never its own merge. In-line, though, the verdict lands *before* the
hand-back — wait for it before you tear down the tree or merge (*The PR review loop*).

**Which gate runs.** A project may offer a lighter gate for a prose-only slice (Trinity: `--mode docs` →
`pnpm docs:gate`, not the full `pnpm gate`). A **speed choice, not a workaround**: every worktree gets a real
install, so a light-mode slice that turns out to touch code just enqueues in the default mode and faces the
full gate.

**A base merge invalidates the mode, so re-derive it before you re-enqueue.** Recovering from a `merge-pr`
that stopped at `Base branch was modified` means re-attaching a tree and `git merge origin/<base>` (*Merge &
cleanup*), and that merge can land **code** on a prose-only branch. So derive the mode again from
`git diff --name-only $(git merge-base HEAD origin/<base>) HEAD` — recomputing the fork point *after* the
merge, never carrying a SHA forward — and enqueue in the **default** mode if anything outside the light mode's
prose set appears. It reads the merged **file set**, not the branch name. Nothing else catches it: a
re-enqueued PR carries a gate comment whose SHA matches its head whichever gate ran.

## Three readings that change the flow

- **No `enqueue`/`drain`** → **this project gates in-line, and that is the DEFAULT here rather than a grant**
  (*Gate mode*). The PR is still a draft at hand-back; only who ran the gate changes. Never tell an
  implementer to enqueue here — the command doesn't exist, and the run ends with committed work and no
  handoff.
- **`gate` == `scopedCheck`** → one authoritative check, no separate heavy tier. Nothing for a runner to add,
  so don't build a queue around it or split briefs into "cheap" and "full" bars that are the same command.
- **A `sharedResources` entry whose `isolatedBy` is `null`** → **"default to parallelization" does not hold in
  this project.** File-disjoint slices contend for that resource the moment two of them run checks at once.
  **The slot covers less than it looks**: it serializes *drained gates* only, so every implementer's
  `scopedCheck` and targeted test file is uncovered and concurrent — and with **no queue** there is no slot at
  all, so the exposure is the whole fan-out. Narrow the wave to one live slice against that resource, or
  sequence those slices across waves. The contention surfaces as a red in whichever slice lost the race
  (*Reading a gate result*). **A non-null `isolatedBy` leaves the default fan-out in place, and does so for
  either of its two forms**, so the honest answer and the correct dispatch decision are the same answer, and a
  resource that is shared but safe by construction never has to be written `null` to be written truthfully.

## Go through the task-runner, never around it

A shared cache only helps commands that invoke the runner (turbo/nx/bazel): `scopedCheck` and `gate` do. The
binary called **directly** — `vitest`, `tsc`, `eslint` — or a script shelling straight to it
**bypasses the cache and always runs cold**, locally and in the drained gate. So route every whole-package or
whole-suite run that is *supposed to happen* — the drained gate, an integration gate, an override-mode slice —
through the cached command (`turbo run <task> --filter=<pkg>`, or the project's `scopedCheck`), and say so in
briefs and `AGENTS.md`. Routing, not permission: for a default-mode implementer those runs are banned outright
(`skills/execute/SKILL.md`'s Implementer section). Reserve a direct-binary run for a **single targeted file**;
an `AGENTS.md` documenting the raw form as a package default is a leak to fix.
