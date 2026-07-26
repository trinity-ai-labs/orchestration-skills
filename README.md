# orchestration-skills

The Claude Code **dev pipeline**: turn an idea into a grounded GitHub issue, slice it into parallel waves, then ship it off an integration branch using isolated git worktrees and orchestrator / implementer sub-agents.

```
idea / plan  ──/write-issue──▶  grounded issue  ──/decompose──▶  slices + waves  ──/orchestrate──▶  worktrees · PRs · merges
```

Three skills, one repo, because they're one pipeline: each skill's handoff names the next by slash-command, and `decompose` + `orchestrate` both read the same per-project config. They install as a set.

| Skill | Does | Never does |
|---|---|---|
| [`/write-issue`](skills/write-issue/SKILL.md) | Grounds an idea in the real code and files it as a forward-facing issue (or umbrella + subs) | Slice into waves; write code |
| [`/decompose`](skills/decompose/SKILL.md) | Turns that plan into independent slices with owned files, do-not-touch boundaries, waves, conflict map, model tiers | Make worktrees; dispatch; merge |
| [`/orchestrate`](skills/orchestrate/SKILL.md) | Cuts a worktree per slice, dispatches implementers, reviews each PR's diff, merges, cleans up | — (it's the executor) |

All three are **project-agnostic**: they read each repo's own `AGENTS.md` and per-project config rather than hardcoding a stack.

Alongside the skills, the repo ships the machinery `/orchestrate` drives:

| Piece | Lives at (after install) | What it does |
|---|---|---|
| `bin/setup-worktree.sh` | `~/.worktrees/setup-worktree.sh` | Generic helper that creates a worktree, symlinks env files, installs deps |
| `bin/merge-pr.sh` | `~/.worktrees/merge-pr.sh` | Atomic close-out: tear down the worktree, real merge commit, fast-forward the local integration branch (so the post-merge sync can't be dropped) |
| `bin/remove-worktree.sh` | `~/.worktrees/remove-worktree.sh` | Safely tear down a worktree, killing processes rooted in it first |
| `config/<project>.sh` | `~/.worktrees/config/<project>.sh` | Per-project settings the helper + skills read (gate, env files, conventions) |

---

## The mental model

You **never code directly in the main checkout**. The main checkout holds the **integration branch** (for Trinity that's `release/x.x.x` — the current release line). Every task gets its own git worktree under `~/.worktrees/<project>/<branch-leaf>`, branched off the integration branch. Work → commit → push → PR back into the integration branch → review → **merge with a real merge commit** → sync the local integration branch → delete branch + worktree.

When you invoke `/orchestrate`, Claude first decides **which role it's in**:

- **Orchestrator** — you asked it to *coordinate* work, *work a GitHub issue*, or *execute a plan/batch*. It does **not** write code. It decomposes the work, makes + verifies a worktree per task, dispatches implementer sub-agents (in parallel when independent), reviews each PR by reading the diff, and merges.
- **Implementer** — you told it to *build / fix / implement* a specific thing (or it was dispatched as a sub-agent). It codes in its worktree, runs `/simplify`, greens the gate, opens a PR, and **hands back — it never merges its own PR**.

### Why this shape
- **Front-loaded planning** → `write-issue` and `decompose` do the expensive grounding *before* any worktree exists, so the orchestrator isn't slicing work mid-flight while also juggling PRs and merges. Better decomposition in → more parallelism and fewer wrong-approach restarts out.
- **Isolated worktrees** → parallel tasks never collide; each has its own `node_modules` and branch.
- **Integration branch as merge point** → PRs target the release line, not `main`.
- **Real merge commits, never squash/rebase** → individual commit history is preserved; conflicts between parallel branches are resolved at merge time.
- **Gate as a backstop** → the implementer greens the gate before the PR; the orchestrator re-runs it only when there's reason to (an agent died, or a merge combined branches never tested together).

---

## Prerequisites

> **macOS or Linux** — `install.sh` is portable `bash` (re-runnable; cleanly converts a prior `--copy` install to symlinks). On Windows, run it under WSL.

- **git** (worktrees are built in; nothing extra to install)
- **[GitHub CLI](https://cli.github.com/)** (`gh`) authenticated: `gh auth login` — used to file issues and open/merge PRs
- **[Claude Code](https://claude.com/claude-code)** — this is where the skills run
- Whatever your project needs to install + test (for Trinity: **pnpm**)

---

## Install

```bash
git clone git@github.com:trinity-ai-labs/orchestration-skills.git
cd orchestration-skills
./install.sh
```

`install.sh` **symlinks** the pieces into place (`~/.worktrees/` and both skill homes — `~/.claude/skills/` and `~/.agents/skills/`), so a later `git pull` in this repo updates your live tools automatically. Use `./install.sh --copy` if you'd rather have independent copies.

Verify:

```bash
ls -la ~/.worktrees/setup-worktree.sh                              # -> .../orchestration-skills/bin/setup-worktree.sh
ls -la ~/.claude/skills/{write-issue,decompose,orchestrate}        # -> .../orchestration-skills/skills/*
ls -la ~/.agents/skills/{write-issue,decompose,orchestrate}        # -> .../orchestration-skills/skills/*
```

Then in Claude Code, all three should appear in the skills list.

---

## Setting up with Trinity

The Trinity config (`config/trinity.sh`) ships in this repo, so `install.sh` already wired it up. It assumes your Trinity clone's directory is named `trinity` (the helper keys off the directory name). What it declares:

- **ENV_FILES** — symlinks `trinity/.env.local`, the `trinityailabs.com/.env.*` files, and `cf/.dev.vars` into each worktree (you must already have these in your main checkout — get them from the team vault, they're gitignored).
- **INSTALL_CMD** — `pnpm install --frozen-lockfile`
- **GATE_CMD** — `pnpm check && pnpm test` (this is the green bar before any PR)
- **DOCS_BRANCH_PREFIX** — `docs/` branches skip env + install (markdown comes up instantly)
- **BRIEF_CONVENTIONS** — baked into every implementer brief: use the `effect-v3` skill for Effect-TS code; pre-launch **forward-only, no backwards-compat shims**; comments explain the mechanism (no issue/PR/version refs); run `/simplify` then the gate before committing.

**One-time Trinity setup:**

1. Clone Trinity to a directory named `trinity` and check out the active release branch in the main checkout (`git switch release/x.x.x`). Release/integration branches live in the **main checkout**; worktrees are only for feature/fix work.
2. Drop the gitignored env files (`trinity/.env.local`, etc.) into the main checkout — the helper symlinks *these* into every worktree, so they only need to exist once.
3. `pnpm install` in the main checkout once.
4. Open Claude Code in the Trinity repo and you're ready.

---

## Daily usage

### The full pipeline

```
/write-issue add per-workspace model overrides     # → files issue #1042, hands off
/decompose #1042                                   # → posts slices + waves onto the issue
/orchestrate work issue #1042                      # → worktrees, PRs, merges
```

Each leg ends with an explicit handoff line and **stops** — you decide whether to run the next one.

### Writing the issue

`/write-issue` spawns read-only `Explore` agents and greps the whole repo so every target is a real `file:line`, not a guess. The body is **forward-facing**: goal → approach → targets → type/interface sketch → phases → verify. Exploration narrative and discovery history get stripped — an issue states the plan to execute, never how you figured it out. It files via `gh api` (REST), not the rate-limited `gh issue` GraphQL commands.

Single issue by default; an umbrella with one sub-issue per slice when the work is large **and** multi-area **and** independently trackable.

### Decomposing

| You invoked… | decompose… |
|---|---|
| `/decompose` with a plan already in chat (or from plan mode) | grounds it and emits the breakdown **in chat**, then hands off |
| `/decompose #1042` (a GitHub issue) | reads the issue + comments, grounds it, and **writes the breakdown back to GitHub** — as a comment (default), or by converting the issue into an umbrella + sub-issues when it's a large multi-area epic |

Every slice carries exactly what the dispatch loop consumes: scope, owned files, do-not-touch boundaries, depends-on, the framework skill to invoke first (`effect-v3` / `solid` for Trinity), a `sonnet`/`opus` model hint, brief, and verify steps. Plus the wave plan: wave 0 = foundational/schema-first, wave 1+ = parallel consumers, with a conflict map and the critical path.

### Orchestrating

```
/orchestrate work issue #1042
```

Claude discovers the active integration branch, makes + verifies a worktree per slice, dispatches implementer sub-agents wave by wave, reviews each PR's diff, and merges + cleans up. You stay in the loop on the merge decisions.

### As the implementer (one specific thing, yourself)

```
build the toast-position fix
```

Claude codes it in a fresh worktree, simplifies, greens the gate, opens a PR targeting the integration branch, and hands back for you to review/merge.

### Making a worktree by hand

```bash
# from anywhere inside the repo:
~/.worktrees/setup-worktree.sh fix/toast-position release/0.3.10
```

Both args are **required** (no default base — integration branches roll over, so a hardcoded default goes stale). It creates `~/.worktrees/trinity/toast-position`, symlinks env files, and installs deps. If the base isn't a local ref yet, it tells you to `git fetch` first.

> **Always verify HEAD before dispatching an agent into a worktree:**
> ```bash
> git -C ~/.worktrees/trinity/toast-position rev-parse HEAD
> git rev-parse origin/release/0.3.10     # must match
> ```
> The helper doesn't verify this — a mismatch means the base is stale; fix it before any work starts.

---

## Onboarding a new project

Drop a `~/.worktrees/config/<project>.sh` (named after the repo's directory) declaring the keys you need — see [`config/example.sh`](config/example.sh) for an annotated template. Add it to *this* repo's `config/` and re-run `install.sh` so it's symlinked and shared with the team. A repo with no config still works; it just gets a bare worktree (no env, no install), and slices won't carry env/gate specifics.

---

## The hard rules (Claude follows these; good to know)

- **Never** use the Agent tool's `isolation: "worktree"` param or any auto worktree provisioner — they seed worktrees at a **stale base** and put them in the wrong place. Only `setup-worktree.sh` makes worktrees.
- **Never squash-merge, never rebase.** Always real merge commits. Resolve parallel-branch conflicts at merge time.
- **Branch from the integration branch, not `main`.** PRs target the integration branch.
- **Implementers never merge their own PRs** — the orchestrator reviews the diff and merges.
- **After merge:** sync the local integration branch *first*, then delete the merged branch (only past git's "fully merged" check), remove the worktree, and close the issue yourself (`gh issue close` — GitHub won't auto-close, since PRs merge into the integration branch, not `main`).

---

## Layout of this repo

```
.
├── install.sh                       # symlink (or --copy) every piece into place
├── bin/
│   ├── setup-worktree.sh            # the generic worktree helper
│   ├── merge-pr.sh                  # atomic merge + local-branch sync
│   └── remove-worktree.sh           # safe teardown
├── config/
│   ├── trinity.sh                   # Trinity's real config (working example)
│   └── example.sh                   # annotated template for new projects
└── skills/
    ├── write-issue/SKILL.md         # the /write-issue playbook
    ├── decompose/SKILL.md           # the /decompose playbook
    └── orchestrate/SKILL.md         # the /orchestrate playbook
```

To change the workflow: edit the file here, commit, push. Everyone who installed via symlink picks it up on `git pull`.
