---
name: setup
description: >-
  Onboard a repo onto the /pipeline:write-issue → /pipeline:orchestrate pipeline. Use when a repo has no
  `.agents/worktree.json`, when `setup-worktree.sh` warns "no config", when someone asks to SET UP or
  ONBOARD the pipeline (or a gate queue) for a project, when a dispatcher refuses to dispatch because the
  project is unconfigured, or to RECONCILE a config or a scaffolded queue that has gone stale against its
  repo.
argument-hint: "[path to the repo to onboard — omit to onboard the current one]"
---

# setup — onboard a repo onto the pipeline

`/pipeline:execute` cuts a worktree per task and expects each project to declare how it builds, checks and gates itself. That declaration is `<repo>/.agents/worktree.json`; this skill writes it, and scaffolds a gate queue where the project wants one. **Both artifacts live in the project, not in this plugin**, so two queues *should* be allowed to diverge.

## Why an unconfigured repo is worse than an obviously-broken one

`setup-worktree.sh` does not fail on a missing config — it notes it on stderr and cuts a bare worktree, no env symlinks and no `node_modules`, so an implementer dispatched into a project that installs anything fails its checks in the shape of a code bug. And with no config the gate, the conventions and the framework skills are guesses; a guessed gate passes while testing nothing. **Treat "no config" as a hard stop, not a warning.**

---

## Step 0 — Decide how much of this the repo actually needs

Machinery a project doesn't need is a cost, not a safety net. Pick the tier and say which.

| Tier | Looks like | Config |
|---|---|---|
| **No flow** | Nothing to isolate, no check to run | None. Say so and stop |
| **Worktrees + a check** | The check runs in seconds — this plugin's repo | `gate` == `scopedCheck`, no queue, often no `install`/`envFiles` |
| **Worktrees + gate + queue** | The gate takes minutes and saturates the box | The full set |

- **`gate` and `scopedCheck` being one command is a correct answer**: one authoritative check, no heavy tier. A fabricated heavier gate either doesn't exist or tests nothing.
- **No queue is normal too.** Omit `enqueue`/`drain` and the implementer gates in-line, commenting the verdict on its own draft PR, still a draft at hand-back — and the dispatcher's merge waits on that hand-back rather than the comment (`skills/execute/references/dispatching.md`'s *Gate mode for this slice*).
- **Keys with no honest value are left out, never guessed** — `"install": "npm install"` in a markdown repo fails every worktree setup.
- **`sharedResources` breaks that rule: `[]` is an answer, not a blank.** Missing says nobody asked what the checks touch outside the worktree; `[]` says somebody asked and found nothing, which a dispatcher reads as licence to fan out.

## Onboarding a polyrepo workspace

A **containing folder of sibling repos** — no `.git` at the root, several children that each have one — gets `.agents/workspace.json` there plus a `.agents/worktree.json` per member. That manifest is **derived and regenerated** by running this skill at the root on each machine, never tracked. Take `members` from the children holding a `.git`, `integrationBranch` from the branch they are on, and the rest from the workspace's docs — **never inferring a contract from resemblance**, which silently switches off contract closure. Verify with `setup-workspace.sh --dry-run <branch>`: the member set, and whether naming a contract's owner pulls its consumers in.

## Step 1 — Ground the repo. Never guess a command.

Every value must come from something you read; a guess produces a config that looks right and gates nothing.

**In this one repository, read the rules you ground BY out of the tree too.** You were loaded from the **installed** plugin; where that copy and this repo are one document at two versions, the tree wins because it ships. Read this file's steps and `skills/setup/references/gate-queue.md` from the tree, `diff` where one looks wrong, and say which copy you ran from — a stale one drops a whole trigger while producing a valid config and no error.

- **Package manager** — the lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`), not what's popular.
- **Scripts** — `package.json`'s `scripts`, or the `Makefile`/`justfile`/`Taskfile`.
- **The real gate** — CI (`.github/workflows/*.yml`): whatever runs before merge IS the gate; with no CI, the broadest local command that builds and tests.
- **The scoped check** — the cheap subset with no build and no test suite (format-check + lint + typecheck), composed yourself where no script already does.
- **Env files** — the gitignored files tests and builds read: `git check-ignore` over candidates, then confirm they exist in the main checkout. **Record paths only**, since the config is committed.
- **Conventions** — `AGENTS.md` / `CONTRIBUTING.md`, and only what lives nowhere else; what is already there gets pointed at, not copied.

In a monorepo, note which commands are **root** and which per-package: a root-only script run from a subpackage reports "no such script", which agents misread as a missing feature.

### Three values no file in the repo holds — ASK for them

1. **What does the gate touch that lives OUTSIDE the worktree?** No lockfile or CI config names the Postgres the suite migrates, the Redis the tests flush, the cache directory two runs share, or the port an e2e run binds. Ask that, then the follow-up that makes it testable: **does each worktree already get its own, and what makes that happen?** Both go into `sharedResources`, `[]` where nothing outside the tree is touched — a key a file-reading pass leaves absent, where absence is not the safe reading (`skills/execute/references/per-project-config.md`).
2. **What DROPS what that mechanism creates, once the worktree is gone?** Same breath, and only where the first had a mechanism: it makes one database, keyspace or cache directory per worktree and removes none, and `remove-worktree` knows nothing the tree made. An existing sweep's two commands become `reclaim`; where there is none — the common answer — **that is a gap you hand back, not a command you invent**, a `reclaim` naming a script nobody wrote being a delete command that fails or, worse, does not. With every entry `null` or non-durable, the key is absent.
3. **May a run that finds a defect in the *pipeline itself* file it into the pipeline's own public repository** — an issue, or a comment on one already describing it? That is `upstreamFindings`: consent rather than a fact, and onboarding is the only moment the owner is reliably in the conversation. Put it about the **PROJECT**, read them the facts `skills/orchestrate/SKILL.md` §7 lists rather than recalling them, and **name the repository** from `repository` in `.claude-plugin/plugin.json`. **A yes covers both**, a comment on a public issue being as public as an issue. ⚠️ **Do not make it easy to say yes**: put the question flat, and say no is a complete answer.

**Write `true` only on an explicit yes; on a no, a maybe, silence, or nobody to ask, OMIT the key** — absence and *asked, declined* both mean no. The `false` in `examples/worktree.json` shows a key rather than a decision; copied out, it records a no nobody made.

## Step 2 — Write `.agents/worktree.json`

`setup-worktree` reads `envFiles`, `env` and `install`; `merge-pr` reads `epicMerge`; the skills read the rest.

| Key | Source it from |
|---|---|
| `envFiles` | Gitignored env paths present in the main checkout. **Paths only — never inline a value, never read them to "check" them** |
| `install` | The lockfile's package manager, frozen/CI form |
| `env` | Build-cache dirs; `${VAR:-default}` so an existing value wins |
| `gate` | What CI runs before merge |
| `scopedCheck` | The no-build, no-test subset |
| `sharedResources` | **The maintainer's answer, not a file's** — Step 1's first two asks; `[]` when nothing |
| `reclaim` | `{report, drop}`, the project's own sweep. **Omit** unless an entry is durable AND the commands exist |
| `enqueue` / `drain` | Step 3 — **omit both** with no queue |
| `format` | The formatter in *write* mode |
| `frameworkSkills` | `{skill, when}` per area, from the deps imported |
| `briefConventions` | Only what `AGENTS.md` doesn't already say — point at it, and state only the gotchas that would cost a run |
| `upstreamFindings` | **Consent, not a fact** — Step 1's third ask. `true` on an explicit yes, **omit** otherwise |
| `epicMerge` | History policy — **omit** unless a release branch wants one commit per arc |

**`sharedResources` is a claim Step 4 has to falsify, which is what fixes its shape.** Each entry is `{resource, isolatedBy}`: `resource` names the thing, `isolatedBy` names the project's own mechanism *and the entry point it sits at*, or an explicit `null` — shared and staying shared, a real answer and the one Step 4 has nothing to test.

- **Write the entry point down**, never "handled in the test config": it must be one **every** invocation reaches, since a mechanism hung off `gate` misses the test files verify bars have implementers run directly.
- **You declare; you never provision** — no setup script, no lifecycle hook, nothing this plugin would call, a hook isolating only what the plugin invokes isolating the wrong set.
- **Where the mechanism creates something DURABLE, record how the resource is MARKED, not only named.** The path enters the name via `git rev-parse --path-format=absolute --show-toplevel`, never `$PWD`, which spells a symlinked entry differently and hands one worktree two databases; the mark goes onto the resource as it is created — `COMMENT ON DATABASE`, a keyspace key, a file in the directory — carrying that same path, the only thing `reclaim` can attribute back.
- **A mechanism that marks nothing is a change to the project's bootstrap, not a config gap**: write down what is missing and hand it back.

`skills/execute/references/per-project-config.md` carries the three-state reading and what the sweep must satisfy; on `epicMerge`, every value but the exact lowercase `"squash"` means `merge`, and it governs one merge — an epic branch collapsing into an integration branch that is not the repository's default (`skills/execute/references/epic-branch.md`'s *Mechanics*). `examples/worktree.json` is a complete file.

## Step 3 — The gate queue (only if the project wants one)

The queue exists so implementers never run the heavy gate: they push, open a draft PR, enqueue a durable ticket and hand back, while dispatchers drain one gate at a time — no lock to serialize a fan-out on, no thundering herd, no way for a dying agent to strand committed work. **Not every project needs it**: a repo whose gate takes seconds, or that nobody fans out across, is better off with none. Say which you chose and why. If it wants one, scaffold the three scripts with their `package.json` entries — and **read `skills/setup/references/gate-queue.md` first**, since the whole rests on a few invariants (atomic-rename claims, PID liveness, re-entrant slot) whose failure mode is a green gate against code no gate ever saw.

### Already has a queue? Reconcile it — report the delta, never rewrite

Scripts already there is a **presence** where most of this skill's triggers are an absence: the project is not onboarding but possibly *behind*, the repo owning its own queue being what leaves it unsignalled when the reference gains an invariant. Read them against the invariants in `skills/setup/references/gate-queue.md` and hand back a **per-invariant delta** — implemented, absent, or not determinable by reading, that third given with the command that would settle it. **Report, never rewrite**, an overwrite being unable to tell a deliberate divergence from a stale one; and **read the code, never a version stamp**, which says "current" on partial adoption and names the missing clause either way.

## Already configured? Reconcile the config against the repo — report the delta, never rewrite

**Another presence, arrow reversed**: that reconcile covers a project behind a **reference** that moved, this one the **repo** moving under a config that has not — a renamed gate script, a changed package manager, a deleted `envFiles` entry, a service the suite has started touching. A stale config misleads rather than errors, reaching an implementer as a check failing in the shape of a code defect.

**Re-ground, don't re-ask.** Run Step 1 again against the tree as it is now and compare key by key; a workspace's own `.agents/workspace.json` is regenerated rather than reconciled. Give each key one verdict: **agrees**; **drifted**, saying what the repo now says rather than that it differs, since a delta the maintainer must re-derive is one they will not act on; or **declared, unverified** for `sharedResources`, `reclaim`, `upstreamFindings` and `epicMerge` — `upstreamFindings` most carefully, consent being attached to whoever gave it.

**Surface a candidate; never write an entry.** Where the tree has outrun the file — a new service, a new cache directory, a newly bound port — put what you saw as a **question**: *the suite now reaches X and `sharedResources` does not name it — does it?* An inferred entry carries the authority of a reconcile: it looks checked, which is precisely what it was not.

⚠️ **Run it between arcs, never inside one.** Once worktrees are live the config is frozen for the arc (`skills/orchestrate/SKILL.md` §2's *And the window closes at dispatch*), so drift is a stop-and-report: the delta is measured against a file every live worktree was provisioned from, and the natural repair is the edit §2 forbids. **Nothing detects staleness for you** — this pass is **asked for**.

## Step 4 — Verify it, don't assert it

A config that parses is not a config that works. Prove each layer. ⚠️ Every helper below ships as `<name>.sh` and `<name>.ps1`; use the one your shell tool runs, native Windows without Git for Windows having no bash.

1. **The reader agrees.** Run `setup-worktree <branch> <base>`, then confirm each declared env file is **present** in the worktree and deps are installed, rather than that it exited 0. Present rather than symlinked is fine: on Windows the helper copies and says so.
2. **HEAD is right.** `git -C <wt> rev-parse HEAD` equals the base tip resolved **locally** (`git -C <repo> rev-parse <base>`) — no fetch, no freshness count, this worktree being a throwaway and the config's reader what is under test. The full fetch-and-compare belongs at **dispatch** (`skills/execute/references/worktree-creation.md`).
3. **The gate command exists.** Run the *scoped* check for real; for the full gate, `<pm> run <script> --help` is enough.
4. **The queue round-trips**, if you scaffolded one — four checks, each of the last three invisible to the one before it, and any you cannot produce reported as not produced.
   - Enqueue, drain, and confirm the ticket reached `done/` and the PR carries the verdict comment.
   - **`drain --status` reports and claims nothing** — no ticket moved; an unrecognised flag falling through to a full drain is indistinguishable until you read the output shape.
   - **A blocked acquire names the holder**: with one drain gating, a second must say who holds the slot, what they are gating and since when, before it waits.
   - **The PR-less enqueue** (no `--pr-number`/`--pr-url`): **either outcome is a pass** — settled into `done/` with the verdict on the ticket and the undeliverable flag set, or refused non-zero naming the missing fields. Report a refusal as a delta: the mid-arc integration gate (`skills/execute/references/integration-gate.md`) then cannot be enqueued and gets hand-run.
5. **Two worktrees, gated at once** — the only place the FULL gate earns a run here, and only where `sharedResources` declares an `isolatedBy`, collision being unobservable in one run. Cut a second worktree off the same base, start the real `gate` in both, and let them overlap: green in both is the answer, and a red reads as infrastructure rather than code, both trees holding the same untouched base. Then confirm the isolation is real rather than lucky by **reversing it** — disable the mechanism at the entry point the config names, re-run the overlap, confirm the collision reproduces. Runs too fast to overlap are contention you could not produce, never a pass. With **no** `isolatedBy` there is nothing to falsify: record the project as not parallel-safe, which `/pipeline:execute` reads before sizing a wave.
6. **Tear down** with `remove-worktree` — both worktrees, if item 5 cut a second. Where a `reclaim` is declared it runs on **both sides** of that teardown, a broken sweep and a correct one looking identical when you only look afterwards: standing, the worktrees' resources come back **live**; removed, the same ones and only those move to **dead**. Read the counts — considered, in scope, live, dead — then **stop**, `drop` being the maintainer's call. **Say what this does not establish**: the cross-clone case cannot be produced here, and with **no** `reclaim` nothing sweeps what was created.

## Step 5 — Land it as a reviewable change

Commit the config (and the queue scripts) and open a PR the way that repo normally does; in a workspace, one per member, the manifest itself having no repo to land in. One exception, stated in the message: **the project has an install step**, so a bare worktree has no `node_modules` and every check in it fails in the shape of a code bug — commit that first config straight to the integration branch. A **zero-dependency** project is not covered, a bare worktree there being fully functional.

**A later CHANGE to a config is a different case, not a second exception.** Such a slice gets a good worktree and still cannot exercise its own change: `setup-worktree` reads the **main checkout's working copy** of `.agents/worktree.json`, so every worktree cut anywhere is provisioned from the pre-change file until the change lands there — on a multi-slice arc, at the epic's close-out rather than the slice's own merge. Apply the effect by hand and **say in the hand-back that the config path itself was never exercised**. Do **not** reach into the main checkout to make the helper see it early (`skills/execute/references/worktree-creation.md` rejects it); that read is what lets Step 4 prove a new config before anything is committed.

**Handoff:** report the config, what each value was derived from, whether you scaffolded a queue, and the verification results. Then:

> **Ready to run the pipeline.** `<repo>` is configured — hand an idea to `/pipeline:write-issue` to file it, or hand a plan you already have straight to `/pipeline:orchestrate`.
