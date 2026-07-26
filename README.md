# orchestration-skills

The Claude Code **dev pipeline**, packaged as one plugin: turn an idea into a grounded GitHub issue, slice it into parallel waves, then ship it off an integration branch using isolated git worktrees and orchestrator / implementer sub-agents.

```
idea / plan  ──/pipeline:write-issue──▶  grounded issue  ──/pipeline:decompose──▶  slices + waves  ──/pipeline:orchestrate──▶  worktrees · PRs · merges
```

Three skills in one plugin, because they're one pipeline: each skill's handoff names the next by slash-command, and `decompose` + `orchestrate` both read the same per-project config.

| Skill | Does | Never does |
|---|---|---|
| [`/pipeline:write-issue`](skills/write-issue/SKILL.md) | Grounds an idea in the real code and files it as a forward-facing issue (or umbrella + subs) | Slice into waves; write code |
| [`/pipeline:decompose`](skills/decompose/SKILL.md) | Turns that plan into independent slices with owned files, do-not-touch boundaries, waves, conflict map, model tiers | Make worktrees; dispatch; merge |
| [`/pipeline:orchestrate`](skills/orchestrate/SKILL.md) | Cuts a worktree per slice, dispatches implementers, reviews each PR's diff, merges, cleans up | — (it's the executor) |

The plugin also ships the machinery `orchestrate` drives. Claude Code puts a plugin's `bin/` on the Bash tool's `PATH`, so these are bare commands once the plugin is enabled — nothing to install:

| Command | What it does |
|---|---|
| `setup-worktree.sh` | Creates a worktree, symlinks the project's env files, exports its env, installs deps |
| `merge-pr.sh` | Atomic close-out: tear down the worktree, real merge commit, fast-forward the local integration branch |
| `remove-worktree.sh` | Safely tear down a worktree, killing processes rooted in it first |

---

## Install

**Clone it into your skills directory** — no marketplace, no install step:

```bash
git clone https://github.com/trinity-ai-labs/orchestration-skills ~/.claude/skills/pipeline
```

Any folder under `~/.claude/skills/` with a `.claude-plugin/plugin.json` loads as a plugin on the next session. Update with `git pull`. The directory name is the namespace, so keep it `pipeline` unless you want to retype every cross-reference.

**Or install it as a marketplace plugin**, if you'd rather have versioning and auto-update:

```
/plugin marketplace add trinity-ai-labs/orchestration-skills
/plugin install pipeline@trinity-ai-labs
```

**Or load it for one session**, which is the way to test a change:

```bash
claude --plugin-dir ~/Code/orchestration-skills
```

Verify with `/plugin list` — you should see `pipeline`, its three skills, and three executables.

### Prerequisites

> **macOS or Linux.** The helpers are portable `bash` and need **python3 or node** on `PATH` to read a project's JSON config. On Windows, run under WSL.

- **git** (worktrees are built in)
- **[GitHub CLI](https://cli.github.com/)** (`gh`) authenticated: `gh auth login` — used to file issues and open/merge PRs
- **[Claude Code](https://claude.com/claude-code)** — where the skills run
- Whatever your project needs to install and test

---

## Per-project config

Each project declares its own specifics at **`<repo>/.agents/worktree.json`**, committed to that repo. `setup-worktree.sh` reads `envFiles`, `env`, and `install`; the skills read the rest.

```json
{
  "envFiles": ["app/.env.local", "worker/.dev.vars"],
  "install": "pnpm install --frozen-lockfile",
  "gate": "pnpm gate",
  "scopedCheck": "pnpm check",
  "enqueue": "pnpm gate:enqueue",
  "drain": "pnpm gate:drain",
  "format": "pnpm format",
  "env": { "TURBO_CACHE_DIR": "${TURBO_CACHE_DIR:-$HOME/.cache/my-turbo}" },
  "frameworkSkills": [{ "skill": "solid", "when": "SolidJS UI" }],
  "briefConventions": "Match surrounding style. Never rebase, never self-merge."
}
```

| Key | Read by | Meaning |
|---|---|---|
| `envFiles` | script | Gitignored files symlinked from the main checkout into each worktree |
| `install` | script | Run inside a new worktree — worktrees never share `node_modules` |
| `env` | script | Exported before the install; most usefully a shared build-cache dir |
| `gate` | skills | The heavy build+test gate. The *runner* runs this, never an implementer |
| `scopedCheck` | skills | The cheap bar an implementer's commits are held to |
| `enqueue` / `drain` | skills | How a PR joins the gate queue, and how an orchestrator drains it |
| `format` | skills | The auto-formatter in *write* mode, run right before committing |
| `frameworkSkills` | skills | `{skill, when}` pairs — the skill each area opens with |
| `briefConventions` | skills | Conventions baked into every dispatched implementer brief |

See [`examples/worktree.json`](examples/worktree.json) for a complete file.

**Why it lives in the repo.** It travels with the clone, works under any checkout directory name, and is reviewed in the same PR as the change that alters it. Keying it to a directory name instead — the old design — meant a repo cloned to a different folder silently got no config, and the helper would cut a bare worktree with no env and no `node_modules` while only warning on stderr.

⚠️ **A shared cache var must also live in `~/.zshenv`, not `~/.zshrc`.** The config's `env` covers the install step, but the gate runner, the drain, and dispatched agents all run in **non-interactive** shells, which read `~/.zshenv` only.

---

## The mental model

You **never code directly in the main checkout.** The main checkout holds the **integration branch** (for Trinity, `release/x.x.x`). Every task gets its own worktree under `~/.worktrees/<project>/<branch-leaf>`, branched off the integration branch. Work → commit → push → PR back into the integration branch → review → **merge with a real merge commit** → sync the local integration branch → delete branch + worktree.

When you invoke `/pipeline:orchestrate`, Claude first decides **which role it's in**:

- **Orchestrator** — you asked it to *coordinate* work, *work a GitHub issue*, or *execute a plan*. It does **not** write code. It decomposes, makes + verifies a worktree per task, dispatches implementer sub-agents in parallel, reviews each PR by reading the diff, drains the gate queue, and merges.
- **Implementer** — you told it to *build / fix / implement* a specific thing (or it was dispatched as a sub-agent). It codes in its worktree, greens the scoped check, opens a **draft** PR, enqueues the gate, and **hands back — it never merges its own PR**.

### Why this shape
- **Front-loaded planning** → `write-issue` and `decompose` do the expensive grounding *before* any worktree exists, so the orchestrator isn't slicing work mid-flight while juggling PRs and merges.
- **Isolated worktrees** → parallel tasks never collide; each has its own `node_modules` and branch.
- **A durable gate queue** → implementers enqueue and hand back rather than waiting, so a wide fan-out never serializes on a gate lock and a dying agent can't strand committed work.
- **Real merge commits, never squash/rebase** → history is preserved; parallel-branch conflicts resolve at merge time.

---

## Daily usage

```
/pipeline:write-issue add per-workspace model overrides   # → files issue #1042, hands off
/pipeline:decompose #1042                                 # → posts slices + waves onto the issue
/pipeline:orchestrate work issue #1042                    # → worktrees, PRs, merges
```

Each leg ends with an explicit handoff line and **stops** — you decide whether to run the next.

**As an implementer, directly:** `build the toast-position fix` → Claude codes it in a fresh worktree, greens the scoped check, opens a draft PR, enqueues the gate, hands back.

**By hand:**

```bash
setup-worktree.sh fix/toast-position release/0.4.0
```

`bin/` is on `PATH` inside Claude Code's Bash tool, but not in your own terminal. To call the helpers from a plain shell, add them once — in `~/.zshenv`, not `~/.zshrc`, so non-interactive shells (the gate runner, the drain, dispatched agents) see it too:

```bash
export PATH="$HOME/.claude/skills/pipeline/bin:$PATH"
```

Both args are required — no default base, since integration branches roll over and a hardcoded default goes stale.

> **Always verify HEAD before dispatching an agent into a worktree:**
> ```bash
> git -C ~/.worktrees/trinity/toast-position rev-parse HEAD
> git rev-parse origin/release/0.4.0     # must match
> ```
> The helper doesn't verify this — a mismatch means the base is stale.

---

## Onboarding a new project

Add `.agents/worktree.json` to that repo, declaring the keys above, and commit it. Read the repo's `AGENTS.md`, its package scripts, and its CI to fill in the commands rather than guessing. A repo with no config still cuts a worktree — but a bare one, with no env and no install, so don't dispatch into it.

---

## The hard rules (Claude follows these; good to know)

- **Never** use the Agent tool's `isolation: "worktree"` param or any auto worktree provisioner — they seed worktrees at a **stale base** and put them in the wrong place. Only `setup-worktree.sh` makes worktrees.
- **Never squash-merge, never rebase.** Always real merge commits.
- **Branch from the integration branch, not `main`.** PRs target the integration branch.
- **Implementers never run the full gate and never merge their own PRs** — they enqueue; a runner gates; the orchestrator reviews the diff and merges.
- **After merge:** sync the local integration branch *first*, then delete the merged branch, remove the worktree, and close the issue yourself (`gh issue close` — GitHub won't auto-close, since PRs merge into the integration branch, not `main`).

---

## Adding a skill

Drop `skills/<slug>/SKILL.md` in and it loads — no manifest edit needed. CI enforces the two things that make a skill actually load: frontmatter carrying `name`, `description`, and `argument-hint`; and `name` matching the directory, since Claude Code registers the slash-command from the directory name.

Before publishing, run the authoritative validator — the same one the community-marketplace review runs:

```bash
claude plugin validate . --strict
```

---

## Layout

```
.
├── .claude-plugin/
│   ├── plugin.json              # the plugin manifest — `name` sets the namespace
│   └── marketplace.json         # so the repo is also a one-plugin marketplace
├── .github/workflows/ci.yml     # shellcheck · manifests · skill frontmatter · config reader
├── bin/                         # on PATH while the plugin is enabled
│   ├── setup-worktree.sh
│   ├── merge-pr.sh
│   └── remove-worktree.sh
├── examples/worktree.json       # a complete per-project config
└── skills/
    ├── write-issue/SKILL.md
    ├── decompose/SKILL.md
    └── orchestrate/SKILL.md
```

To change the workflow: edit the file, commit, push. A clone-install picks it up on `git pull`.

---

## License

MIT — see [LICENSE](LICENSE).
