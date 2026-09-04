---
name: setup
description: >-
  Onboard a repo onto the /pipeline:co-think → /pipeline:write-issue pipeline and the passes that run off
  it. Use when a repo has no `.agents/worktree.json`, when `setup-worktree.sh` warns "no config", when
  someone asks to SET UP or ONBOARD the pipeline (or a gate queue) for a project, when a dispatcher
  refuses to dispatch because the project is unconfigured, when a pass reports that a project's config
  declares none of a key this plugin now reads, or to RECONCILE a config or a scaffolded queue that has
  gone stale — against its repo, or against this plugin.
argument-hint: "[path to the repo to onboard — omit to onboard the current one]"
---

# setup — onboard a repo onto the pipeline

`/pipeline:execute` cuts a worktree per task and expects each project to declare how it builds, checks and gates itself. That declaration is `<repo>/.agents/worktree.json`; this skill writes it and scaffolds a gate queue where the project wants one. **Both artifacts live in the project**, so two queues *should* be free to diverge.

## Why an unconfigured repo is worse than an obviously-broken one

`setup-worktree.sh` does not fail on a missing config — it notes it on stderr and cuts a bare worktree, no env symlinks and no `node_modules`, so an implementer dispatched into a project that installs anything fails its checks in the shape of a code bug. And with no config the gate, the conventions and the framework skills are guesses; a guessed gate passes while testing nothing. **Treat "no config" as a hard stop, not a warning.**

---

**Six steps, in order.** Each carries the rules that fire at it; Step 3 is the only one with a reference behind it.

## Step 0 — Decide how much of this the repo needs

Machinery a project doesn't need is a cost. Pick the tier, and say which one and why.

| Tier | Looks like | Config |
|---|---|---|
| **No flow** | Nothing to isolate, no check to run | None. Say so and stop |
| **Worktrees + a check** | The check runs in seconds — this plugin's repo | `gate` == `scopedCheck`, no queue, often no `install`/`envFiles` |
| **Worktrees + gate + queue** | The gate takes minutes and saturates the box | The full set |

- **`gate` and `scopedCheck` being one command is a correct answer** — one authoritative check, no heavy tier; a fabricated heavier one tests nothing.
- **No queue is normal too**: omit `enqueue`/`drain` and the implementer gates in-line on its own draft PR, still handing back a draft.
- ⛔ **A key with no honest value is left out, never guessed** — `"install": "npm install"` in a markdown repo fails every worktree setup. **`sharedResources` is the exception: `[]` is an answer, absent is an unasked question**, and a dispatcher reads `[]` as licence to fan out.

### The polyrepo case

A **containing folder of sibling repos** — no `.git` at the root, several children that each have one — gets `.agents/workspace.json` there plus a `.agents/worktree.json` per member, and every step below runs per member. **`integrationBranch` there is DECLARED and belongs under review** — it names the branch every member's work lands on, `merge-pr` reads it, and a value regenerated from whatever branch a machine happened to be on gives two engineers different merges for the same repos. The rest of the manifest is **derived and regenerated** per machine: `members` from the children holding a `.git`, and the remainder from the workspace's docs — **never inferring a contract from resemblance**, which silently switches off contract closure. Verify with `setup-workspace.sh --dry-run <branch>`: the member set, and whether naming a contract's owner pulls its consumers in.

## Step 1 — Ground the repo

Every value must trace to a file you read.

⛔ **Never guess a command.** A missing key is honest; a wrong one passes while testing nothing.

- **Package manager** — the lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`), not what's popular.
- **Scripts** — `package.json`'s `scripts`, or the `Makefile`/`justfile`/`Taskfile`.
- **The real gate** — whatever CI runs before merge (`.github/workflows/*.yml`); with no CI, the broadest local command that builds and tests.
- **The scoped check** — the cheap subset with no build and no test suite (format-check + lint + typecheck), composed yourself where no script already does.
- **Env files** — the gitignored files tests and builds read: `git check-ignore` over candidates, then confirm they exist in the main checkout. **Record paths only**, since the config is committed.
- **Conventions** — `AGENTS.md` / `CONTRIBUTING.md`, and only what lives nowhere else; what is already there gets pointed at, not copied.
- **Where a version lives, and where the docs are.** Grep the manifests and the changelog for the current version; read the docs tree's layout. **Ground candidates, then confirm the list is COMPLETE** — that is the half a search cannot supply, and an incomplete `bumpFiles` ships a version to one host and not another. **A project whose version comes from tags or commit messages declares none of it**: the tooling owns the version there, and a hand-edited file fights it.
- **The integration branch** (`skills/glossary/vocabulary/integration-branch.md`) — a **candidate**, confirmed rather than written. The branches are evidence and not proof: a long-lived `release/x.y.z` or a `develop` suggests one answer and the repository's default branch suggests another, and those are different facts of which either can be right. Put the candidate and the evidence, take the answer, and **write a literal name, never a pattern**. **Getting it wrong is not symmetric**: every worktree of every later arc forks from this branch, so a wrong one is a base nobody notices until a close-out.

In a monorepo, note which commands are **root** and which per-package: a root-only script run from a subpackage reports "no such script", which agents misread as a missing feature.

**In this one repository, ground yourself out of the tree too**: you were loaded from the **installed** plugin, and where the two are one document at two versions the tree wins because it ships. Read this file's steps and `skills/setup/references/gate-queue.md` from the tree, `diff` where one looks wrong, and say which copy you ran from.

### Already configured? Re-ground it and report the delta — never rewrite

Here the **repo** moved and the config did not: a renamed gate script, a changed package manager, a deleted `envFiles` entry, a service the suite now touches. A stale config misleads rather than errors, reaching an implementer as a check failing in the shape of a code defect.

**Re-ground, don't re-ask.** Run this step against the tree as it stands and compare key by key (a workspace's `.agents/workspace.json` is regenerated, not reconciled). One verdict per key: **agrees**; **drifted**, saying what the repo now says rather than that it differs; or **declared, unverified** for `sharedResources`, `reclaim`, `upstreamFindings` and `epicMerge` — `upstreamFindings` most carefully, consent being attached to whoever gave it.

**Surface a candidate; never write an entry** — put what you saw as a question, an inferred entry looking checked when that is precisely what it was not.

**One drift IS cheaply detectable, and in a project that rolls its branch it is the normal case.** The main checkout holds the integration branch and nothing else, so a `HEAD` naming a different branch than `integrationBranch` declares means the project rolled and the config did not follow — report both names. It happens because **cutting a release branch is outside the arc flow entirely**, so nothing in the pipeline is present at that moment to update the config.

⚠️ **Between arcs, never inside one.** Once worktrees are live the config is frozen for the arc, so drift is a stop-and-report — the natural repair is the edit that freeze exists to forbid. **Nothing detects this kind of staleness for you**: re-grounding every script is what it costs, so this direction is **asked for**.

### Behind the PLUGIN? Report which keys it now reads that this config does not declare

A third arrow, and the cheap one. The two above compare a project against its own repo and a queue against the reference; neither notices that **this plugin has started reading a key the config predates**. A project onboarded before a key existed never learns it exists, so a key that ships optional-with-a-fallback reaches nobody already running.

**Read the key set from `examples/worktree.json`** — the one machine-readable copy of it, and the one the gate already parses — and report the keys it carries that the project's config does not. **Same posture as the other two, cited rather than restated: report the delta, never rewrite, and read the structure rather than a version stamp.**

**This one is cheap enough to have a trigger, and that is the whole difference.** Comparing against the repo means re-deriving every script; comparing against the plugin is a set difference over key names, so a pass that has the config open can run it without doing a reconcile. **It reports and routes — it never stops**, because every such key ships with a working fallback and halting an arc over a value that has one costs more than it saves.

⚠️ **A key absent on purpose is not a delta to fix.** `upstreamFindings`, `epicMerge`, `install` and `envFiles` are all omitted deliberately by projects that mean it, and `integrationBranch` is omitted honestly by a project nobody has confirmed a branch for. Report what is undeclared and what declaring it would change; the decision is the project's.

## Step 2 — Write `.agents/worktree.json`

`setup-worktree` reads `envFiles`, `env` and `install`; `merge-pr` reads `epicMerge` and `integrationBranch`, the second from a workspace's `.agents/workspace.json` as well; the skills read the rest.

### First, ask for the three values no file in the repo holds

1. **What does the gate touch OUTSIDE the worktree?** No lockfile or CI file names the Postgres the suite migrates, the Redis the tests flush, the cache directory two runs share, or the port an e2e run binds. Then the follow-up that makes it testable: **does each worktree already get its own, and what makes that happen?** Both go into `sharedResources`, `[]` where nothing outside the tree is touched.
2. **What DROPS what that mechanism creates, once the worktree is gone?** Same breath, and only where the first had a mechanism: it makes one resource per worktree and removes none, and `remove-worktree` knows nothing the tree made. An existing sweep's two commands become `reclaim`; where there is none — the common answer — **that is a gap you hand back, not a command you invent**.
3. **May a run that finds a defect in the *pipeline itself* file it into the pipeline's own public repository** — an issue, or a comment on one already describing it? That is `upstreamFindings`: consent, not a fact, and onboarding is the only moment the owner is reliably there. Put it about the **PROJECT**, read them the facts rather than recalling them — the tracker is **public**, a filed finding keeps the failure's shape and its counts and never a path, symbol, route, branch, client name or home directory — and **name the repository** from `repository` in `.claude-plugin/plugin.json`. **A yes covers both.** ⚠️ **Do not make it easy to say yes**: put it flat, and say no is a complete answer. **Write `true` only on an explicit yes** — a no, a maybe, silence or nobody to ask all mean OMIT the key, and the `false` in `examples/worktree.json` is a key shown, not a decision made.

### Then write the keys

| Key | Source it from |
|---|---|
| `envFiles` | Gitignored env paths present in the main checkout. **Paths only — never inline a value, never read them to "check" them** |
| `install` | The lockfile's package manager, frozen/CI form |
| `env` | Build-cache dirs; `${VAR:-default}` so an existing value wins |
| `gate` | What CI runs before merge |
| `scopedCheck` | The no-build, no-test subset |
| `sharedResources` | **The maintainer's answer, not a file's** — the first ask; `[]` when nothing |
| `reclaim` | `{report, drop}`, the project's own sweep — the second ask. **Omit** unless an entry is durable AND the commands exist |
| `enqueue` / `drain` | Step 3 — **omit both** with no queue |
| `format` | The formatter in *write* mode |
| `frameworkSkills` | `{skill, when}` per area, from the deps imported |
| `briefConventions` | Only what `AGENTS.md` doesn't already say — point at it, and state only the gotchas that would cost a run |
| `upstreamFindings` | **Consent, not a fact** — the third ask. `true` on an explicit yes, **omit** otherwise |
| `integrationBranch` | The branch this project's work lands on — a literal name the maintainer confirms, never a pattern and never read off the default branch. **Omit** where they will not confirm one: absence keeps the older behaviour, and a guessed branch is the value here whose error is silent and durable, since every worktree of every later arc forks from it |
| `bumpFiles` | Every file whose version string moves when a change ships — grounded from the repo, then confirmed as **complete**. **Omit** where nothing hand-edits a version: tag- or commit-derived versioning has tooling that owns it |
| `changelog` | The one file a new section is prepended to. Not a member of `bumpFiles` — a different operation |
| `docsPaths` | `{path, when}` per doc tree: where it lives, and what kind of change makes it stale |
| `epicMerge` | History policy — **omit** unless the project wants one commit per arc. Note that without `integrationBranch` it does nothing wherever work lands on the default branch |

**`sharedResources` is a claim Step 4 has to falsify, which is what fixes its shape.** Each entry is `{resource, isolatedBy}`: `resource` names the thing; `isolatedBy` names the project's mechanism *and the entry point it sits at* — one **every** invocation reaches, since a mechanism hung off `gate` misses the test files implementers run directly — or an explicit `null`, shared and staying shared.

- ⛔ **You declare; you never provision** — no setup script, no lifecycle hook, nothing this plugin would call; a hook isolating only what the plugin invokes isolates the wrong set.
- **Where the mechanism creates something DURABLE, record how the resource is MARKED, not only named** — at creation (`COMMENT ON DATABASE`, a keyspace key, a file in the directory), carrying the worktree's path from `git rev-parse --path-format=absolute --show-toplevel`, never `$PWD`, which spells a symlinked entry differently and hands one worktree two databases. The mark is the only thing `reclaim` can attribute back, so **a mechanism that marks nothing is a bootstrap change, not a config gap**: write it down and hand it back.

`epicMerge` governs one merge — an epic branch collapsing into an integration branch that is not the repository's default — and every value but the exact lowercase `"squash"` means `merge`. `examples/worktree.json` is a complete file.

## Step 3 — Scaffold the gate queue, only where the project wants one → `skills/setup/references/gate-queue.md`

Only where Step 0 picked the queue tier. The queue is what lets implementers never run the heavy gate — they push, open a draft PR, enqueue a durable ticket and hand back, while dispatchers drain one gate at a time. Scaffold the three scripts with their `package.json` entries, and **read the reference first**: the whole rests on a few invariants (atomic-rename claims, PID liveness, re-entrant slot) whose failure mode is a green gate against code no gate ever saw.

### Already has a queue? Reconcile it — report the delta, never rewrite

The arrow is reversed from Step 1's: the project is not onboarding but possibly *behind a reference that moved*. Read the scripts against the invariants in `skills/setup/references/gate-queue.md` and hand back a **per-invariant delta** — implemented, absent, or not determinable by reading, that third with the command that would settle it. **Report, never rewrite**, an overwrite being unable to tell a deliberate divergence from a stale one; and **read the code, never a version stamp**, which says "current" on partial adoption.

**Expect the newest invariant absent from every queue predating it — that is the delta working, not drift.** The tenth, the refusal to gate a worktree carrying uncommitted tracked changes, is currently that one, so every already-scaffolded queue reports one absence. Report it like any other, with what the runner would have to add, and leave the adopting to the project.

## Step 4 — Verify it, don't assert it

A config that parses is not a config that works. Prove each layer. ⚠️ Every helper ships as `<name>.sh` and `<name>.ps1`; use the one your shell tool runs, and call it by absolute path on a host that does not put the plugin's `bin/` on `PATH`.

1. **The reader agrees.** Run `setup-worktree <branch> <base>`, then confirm each declared env file is **present** in the worktree and deps are installed — not merely that it exited 0. Present rather than symlinked is fine; on Windows the helper copies.
2. **HEAD is right.** `git -C <wt> rev-parse HEAD` equals the base tip resolved **locally** (`git -C <repo> rev-parse <base>`) — no fetch, no freshness count: the config's reader is what is under test. The full fetch-and-compare belongs at **dispatch**.
3. **The gate command exists.** Run the *scoped* check for real; for the full gate, `<pm> run <script> --help` is enough.
4. **The queue round-trips**, if you scaffolded one. Enqueue, drain, confirm the ticket reached `done/` and the PR carries the verdict comment. Then three more, each invisible to the one before it: **`drain --status` reports and claims nothing** — an unrecognised flag falling through to a full drain looks identical until you read the output shape; **a blocked acquire names the holder**, what they are gating and since when, before it waits; and **a PR-less enqueue** (no `--pr-number`/`--pr-url`) **passes either way**, settling into `done/` with the verdict on the ticket or refused non-zero naming the missing fields — report a refusal as a delta, the dispatcher's mid-arc integration gate then getting hand-run. Report any check you could not produce as not produced.
5. **Two worktrees, gated at once** — the only place the FULL gate earns a run here, and only where `sharedResources` declares an `isolatedBy`: collision is unobservable in one run. Cut a second off the same base and overlap the real `gate` in both — green in both is the answer, a red reads as infrastructure rather than code, both trees holding the same untouched base. Then prove it was not luck by **reversing it**: disable the mechanism at the entry point the config names, re-run the overlap, confirm the collision reproduces. Runs too fast to overlap are contention you could not produce, never a pass. With **no** `isolatedBy`, record the project as not parallel-safe — `/pipeline:execute` reads that before sizing a wave.
6. **Tear down** with `remove-worktree`, both trees, running a declared `reclaim` on **both sides** of it: a broken sweep and a correct one look identical afterwards, where standing the resources come back **live** and removed the same ones and only those **dead**. Read the counts — considered, in scope, live, dead — then **stop**; `drop` is the maintainer's call. **Say what this does not establish**: the cross-clone case cannot be produced here, and with **no** `reclaim` nothing sweeps what was created.

## Step 5 — Land it as a reviewable PR

Commit the config (and the queue scripts) and open a PR the way that repo normally does; in a workspace, one per member, the manifest itself having no repo to land in. One exception, stated in the message: **the project has an install step**, so a bare worktree has no `node_modules` and every check in it fails in the shape of a code bug — commit that first config straight to the integration branch. A **zero-dependency** project is not covered.

**A later CHANGE to a config is a different case, not a second exception.** `setup-worktree` reads the **main checkout's working copy**, so such a slice cannot exercise its own change until it lands there. Apply the effect by hand, **say in the hand-back that the config path itself was never exercised**, and never reach into the main checkout to make the helper see it early: that writes to the one piece of shared mutable state here, and another session cutting a worktree inside that window is provisioned from an unmerged config with nothing anywhere to tell it. It is the same read that lets Step 4 prove a new config before anything is committed.

**Handoff:** report the config, what each value was derived from, whether you scaffolded a queue, and the verification results. Then:

> **Ready to run the pipeline.** `<repo>` is configured — hand an idea to `/pipeline:co-think`, or a shape you have already settled to `/pipeline:write-issue`, which files it and names the next command: `/pipeline:decompose` then `/pipeline:execute` for one slice, `/pipeline:orchestrate` for an epic.
