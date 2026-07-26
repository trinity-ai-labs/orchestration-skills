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

`setup-worktree.sh` does not fail when config is missing. It prints a note **to stderr** and cuts a bare worktree — no env symlinks, no `node_modules`. An implementer dispatched into that worktree then fails its checks for reasons that look like code bugs, and burns a run before anyone notices the real cause. Treat "no config" as a hard stop, not a warning.

---

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

**Not every project needs it.** A repo whose gate takes seconds, or that no one fans out across, is better off with no queue at all: omit `enqueue`/`drain`, and the implementer runs the gate itself before opening a non-draft PR. Say which you chose and why. Adding a queue to a repo that doesn't need one is pure ceremony.

If it does want one, scaffold the three scripts into the project and add their `package.json` entries. **Read `references/gate-queue.md` before writing a line of it** — the correctness of the whole thing rests on a few invariants (atomic-rename claims, PID liveness, re-entrant slot) that are easy to get subtly wrong and whose failure mode is a green gate against code no gate ever saw.

## Step 4 — Verify it, don't assert it

A config that parses is not a config that works. Prove each layer:

1. **The reader agrees.** `setup-worktree.sh <branch> <base>` in the repo, then confirm the env files are symlinked and deps are installed in the new worktree — not that the command exited 0.
2. **HEAD is right.** `git -C <wt> rev-parse HEAD` equals the base tip.
3. **The gate command exists.** Run the *scoped* check for real. Don't run the full gate just to prove it resolves — `<pm> run <script> --help` or the script listing is enough.
4. **The queue round-trips**, if you scaffolded one: enqueue a ticket, drain it, confirm the ticket reached `done/` and the PR flipped. A queue that enqueues but never drains is worse than none — work vanishes into a directory nobody reads.
5. **Tear down** the verification worktree with `remove-worktree.sh`.

## Step 5 — Land it as a reviewable change

Commit the config (and the queue scripts) to the project and open a PR the way that repo normally does. Two exceptions where committing straight to the integration branch is correct, and say so in the message:

- The repo can't cut a worktree until this file exists — the flow can't bootstrap itself.
- The repo is a tooling repo whose own convention is direct-on-main.

## What setup does NOT do (hard boundaries)

- **No guessed commands.** Every value traces to a file you read. If you genuinely cannot determine the gate, write the config without `gate` and say so — a missing key is honest, a wrong one is a gate that passes while testing nothing.
- **No secrets.** `envFiles` carries paths. Never inline a value, never read the env files to "check" them.
- **No feature work, no slicing, no dispatch.** You configure the repo and stop. Slicing is `/pipeline:decompose`; execution is `/pipeline:orchestrate`.
- **Don't scaffold a queue into a project that doesn't want one.**

**Handoff:** report the config, what each value was derived from, whether you scaffolded a queue, and the verification results. Then:

> **Ready to orchestrate.** `<repo>` is configured — hand work to `/pipeline:write-issue` to file it, or `/pipeline:orchestrate` to execute a plan you already have.
