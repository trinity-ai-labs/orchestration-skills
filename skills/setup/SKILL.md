---
name: setup
description: >-
  Onboard a repo onto the write-issue → decompose → orchestrate pipeline. Use whenever a repo has no
  `.agents/worktree.json` yet, whenever `setup-worktree.sh` warns "no config", when someone asks to
  SET UP / ONBOARD / WIRE UP the pipeline (or a gate queue / enqueue system) for a project, or when
  an orchestrator refuses to dispatch because the project is unconfigured. You GROUND the repo in its
  real scripts, CI, and AGENTS.md — never guessed commands — then write `.agents/worktree.json` and,
  when the project wants one, scaffold a durable gate queue INTO THAT REPO. The artifacts belong to
  the project: this skill carries the knowledge, the repo carries the code, so each project owns and
  evolves its own queue. You do NOT slice work, write features, or dispatch implementers.
argument-hint: "[path to the repo to onboard — omit to onboard the current one]"
---

# setup — onboard a repo onto the pipeline

`/pipeline:orchestrate` cuts a worktree per task and expects each project to declare how it builds, checks, and gates itself. That declaration is `<repo>/.agents/worktree.json`. This skill writes it, and scaffolds the gate queue when the project wants one.

**The artifacts live in the project, not in this plugin.** The plugin stays markdown plus three thin helpers; the repo gets its own `worktree.json` and its own queue scripts, which it then owns and evolves. Two projects' queues *should* be allowed to diverge — one may grow transient-red baseline handling the other never needs.

## Why an unconfigured repo is worse than an obviously-broken one

`setup-worktree.sh` does not fail when config is missing. It prints a note **to stderr** and cuts a bare worktree — no env symlinks, no `node_modules`. **Where the project has an install step**, an implementer dispatched into that worktree then fails its checks for reasons that look like code bugs, and burns a run before anyone notices the real cause. A zero-dependency project escapes that particular failure — a bare worktree is the only kind it has — but not the rest of it: with no config, the gate command, the conventions, and the framework skills are all things the orchestrator has to guess, and a guessed gate is one that passes while testing nothing. Treat "no config" as a hard stop, not a warning.

---

## Step 0 — Decide how much of this the repo actually needs

Most repos are not Trinity-shaped. Adopting machinery a project doesn't need is a cost, not a safety net — decide the tier first and say which you picked.

| Tier | Looks like | Config |
|---|---|---|
| **No flow at all** | A scratch or single-author repo with nothing to isolate and no check to run — you edit `main` and push | No `worktree.json` needed. Say so and stop |
| **Worktrees + a check** | Isolation is useful, but the check runs in seconds. This plugin's own repo is one | `gate` == `scopedCheck`; no `enqueue`/`drain`. Often no `install` and no `envFiles` either |
| **Worktrees + gate + queue** | The gate takes minutes, saturates the box, and several tasks run in parallel | The full set |

**`gate` and `scopedCheck` being the same command is a normal, correct answer.** It means the repo has one authoritative check and no separate heavy tier. Don't invent a heavier gate to fill the key — a fabricated `gate` is a command that either doesn't exist or tests nothing.

**A repo with no queue is normal too.** Omit `enqueue` and `drain`, and the implementer runs the check itself and comments the result on its own draft PR — `/pipeline:orchestrate` reads their absence as "this project gates in-line". The PR is still a draft at hand-back; only who runs the gate changes.

Keys you have no honest value for are **left out**, never guessed. A markdown repo has no `install` and no `envFiles`; writing `"install": "npm install"` into it produces a worktree setup that fails every time.

## Onboarding a polyrepo workspace

If the target is a **containing folder of sibling repos** rather than a repo — no `.git` at the root, several child directories that each have one — you are setting up a workspace. Write `.agents/workspace.json` at that root, plus a `.agents/worktree.json` inside each member.

**The workspace manifest is a derived artifact, not source.** The containing folder is a local convention: its name, and which members are cloned, differ per machine. So it is normal and correct that the manifest is untracked and gets **regenerated** by running this skill at the root on each new machine — the same way nobody syncs `node_modules`. Don't invent a meta-repo to hold it.

That only holds if regeneration is faithful, which puts the weight on where each field comes from:

| Field | Derive it from |
|---|---|
| `members` | The child directories that contain a `.git` |
| `integrationBranch` | The branch the members are actually on — they share one because they release together |
| `branchPrefixes` | The workspace's own `CLAUDE.md`/`AGENTS.md` branch policy |
| `crossRepoContracts` | **The workspace's own docs.** A "cross-project sync" section that says which repo generates an artifact and which repos hold copies is the contract, stated by the people who built it |
| `briefConventions` | The conventions in those same docs that every member shares |

**Never infer a contract from resemblance.** Noticing that three repos contain an identical `generated.d.ts` and concluding one owns it is a guess. When a guess is wrong, contract closure — the rule that stops a task changing a contract owner without the repos that consume it — silently stops protecting anything, and the drift surfaces only after both sides have merged. If the docs don't state the ownership, say so and leave `crossRepoContracts` empty rather than filling it speculatively. An absent contract degrades to "no closure", which is honest; a wrong one is a safety property that looks present and isn't.

**Ask about the preferences, don't derive them.** Whether a member is `"default": false` — skipped unless named — is a judgement about how the team works, not a fact about the repos. Default to including everything and say which member looks like a candidate (a marketing site beside an app), rather than deciding for them.

Then verify by cutting a real task: `setup-workspace.sh --dry-run <branch>` shows the resolved member set, including anything closure pulls in. If a contract is declared, confirm that naming the owner alone pulls its consumers in — that is the check that the manifest actually does its job.

## Step 1 — Ground the repo. Never guess a command.

Every value you write must come from something you read. Guessing produces a config that looks right and gates nothing.

- **Package manager** — from the lockfile (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`, `bun.lockb`), not from what's popular.
- **Scripts** — read `package.json` (`scripts`), or the `Makefile`/`justfile`/`Taskfile` for non-JS repos. Find what actually exists.
- **The real gate** — read CI (`.github/workflows/*.yml`). Whatever CI runs before merge IS the gate; if the repo has no CI, the gate is the broadest local command that builds and tests.
- **The scoped check** — the cheap subset with no build and no test suite (typically format-check + lint + typecheck). If a single script already composes them, use it; otherwise compose one and say so.
- **Env files** — the gitignored files tests and builds read. `git check-ignore` over candidates, then confirm they exist in the main checkout. **Record paths only** — the config is committed, so a value would leak a secret.
- **Conventions** — read `AGENTS.md` / `CONTRIBUTING.md`. These belong in `briefConventions` only if they live nowhere else; a convention already in `AGENTS.md` should stay there and be pointed at, not copied.

For a monorepo, note which commands live at the **root** and which are per-package — a root-only script run from a subpackage reports "no such script", which is a wrong-directory error that agents reliably misread as a missing feature.

## Step 2 — Write `.agents/worktree.json`

| Key | Read by | Source it from |
|---|---|---|
| `envFiles` | `setup-worktree.sh` | Gitignored env paths that exist in the main checkout |
| `install` | `setup-worktree.sh` | The lockfile's package manager, frozen/CI form |
| `env` | `setup-worktree.sh` | Shared build-cache dirs; `${VAR:-default}` so an existing value wins |
| `gate` | skills | What CI runs before merge |
| `scopedCheck` | skills | The no-build, no-test subset |
| `enqueue` / `drain` | skills | Step 3 — **omit both if the project has no queue** |
| `format` | skills | The formatter in *write* mode |
| `frameworkSkills` | skills | `{skill, when}` per area, from the deps actually imported |
| `briefConventions` | skills | Only what `AGENTS.md` doesn't already say |

Keep `briefConventions` short. It is not a place to restate the orchestration protocol — "don't run the full gate", "enqueue then hand back", "never rebase", the transient-red reading and the formatter rule are all in `/pipeline:orchestrate` already and are identical for every project. Duplicating them there means two copies that drift, and the copy agents read is the one no human ever opens. Point at `AGENTS.md`; state only the gotchas that would otherwise cost a run.

See `examples/worktree.json` in this plugin for a complete file.

## Step 3 — The gate queue (only if the project wants one)

The queue exists so implementers never run the heavy gate: they push, open a draft PR, enqueue a durable ticket, and hand back, while orchestrators drain the queue one gate at a time. It buys three things — no gate lock for a wide fan-out to serialize on, no thundering herd of concurrent builds, and no way for a dying agent to strand committed work.

**Not every project needs it.** A repo whose gate takes seconds, or that no one fans out across, is better off with no queue at all: omit `enqueue`/`drain`, and the implementer runs the gate itself and comments the result on its own draft PR. Say which you chose and why. Adding a queue to a repo that doesn't need one is pure ceremony.

If it does want one, scaffold the three scripts into the project and add their `package.json` entries. **Read `references/gate-queue.md` before writing a line of it** — the correctness of the whole thing rests on a few invariants (atomic-rename claims, PID liveness, re-entrant slot) that are easy to get subtly wrong and whose failure mode is a green gate against code no gate ever saw.

## Step 4 — Verify it, don't assert it

A config that parses is not a config that works. Prove each layer:

⚠️ Every helper named below ships as both `<name>.sh` and `<name>.ps1`. Use the extension your shell tool can run: on native Windows with no Git for Windows, Claude Code hands you the **PowerShell tool** and there is no bash at all, so the `.sh` is not a script that fails — it is a command that does not exist, and the error reads as a broken plugin rather than a wrong extension. Both take the same arguments and print the same output, so the verification below is otherwise identical.

1. **The reader agrees.** `setup-worktree.sh <branch> <base>` (or `setup-worktree.ps1`) in the repo, then confirm each declared env file is **present** in the new worktree and deps are installed — not that the command exited 0. Present, not necessarily symlinked: on Windows a real symlink needs Developer Mode or an elevated shell, so the helper falls back to a **copy** and says so on stderr. That is a working setup, not a broken one — the only thing it costs is that a later edit to the main checkout's env file will not propagate, which the helper's own warning spells out.
2. **HEAD is right.** `git -C <wt> rev-parse HEAD` equals the base tip.
3. **The gate command exists.** Run the *scoped* check for real. Don't run the full gate just to prove it resolves — `<pm> run <script> --help` or the script listing is enough.
4. **The queue round-trips**, if you scaffolded one: enqueue a ticket, drain it, confirm the ticket reached `done/` and the PR carries the gate's verdict comment. A queue that enqueues but never drains is worse than none — work vanishes into a directory nobody reads.
5. **Tear down** the verification worktree with `remove-worktree.sh` (or `remove-worktree.ps1`).

## Step 5 — Land it as a reviewable change

Commit the config (and the queue scripts) to the project and open a PR the way that repo normally does. In a workspace this applies to each member's `.agents/worktree.json`; the workspace manifest itself has no repo to land in, which is expected — it is regenerated, not shared. Say that plainly rather than leaving someone wondering why one file went uncommitted.

One exception where committing straight to the integration branch is correct, and say so in the message:

- **The project has an install step.** A repo with no config still cuts a worktree — `setup-worktree.sh` warns on stderr and makes a **bare** one — but bare means no `node_modules`, so every check inside it fails for reasons that read as code bugs rather than as a missing config, and the run burns before anyone reads the stderr note. Writing the config *from* such a worktree is what this exception prevents.

A **zero-dependency** project is not covered by it. A bare worktree there is fully functional — nothing to install, nothing to symlink — so the config lands through a normal PR like any other change. This plugin's own repo is the worked example: it had no `.agents/worktree.json`, `setup-worktree.sh` cut it a working worktree anyway, and the config reached `main` as a reviewed PR. Claiming the flow can never bootstrap itself would have made that PR look like a rule violation.

## What setup does NOT do (hard boundaries)

- **No guessed commands.** Every value traces to a file you read. If you genuinely cannot determine the gate, write the config without `gate` and say so — a missing key is honest, a wrong one is a gate that passes while testing nothing.
- **No secrets.** `envFiles` carries paths. Never inline a value, never read the env files to "check" them.
- **No feature work, no slicing, no dispatch.** You configure the repo and stop. Slicing is `/pipeline:decompose`; execution is `/pipeline:orchestrate`.
- **Don't scaffold a queue into a project that doesn't want one.**

**Handoff:** report the config, what each value was derived from, whether you scaffolded a queue, and the verification results. Then:

> **Ready to orchestrate.** `<repo>` is configured — hand work to `/pipeline:write-issue` to file it, or `/pipeline:orchestrate` to execute a plan you already have.
