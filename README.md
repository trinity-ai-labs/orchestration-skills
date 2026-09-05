# orchestration-skills

The **dev pipeline**, packaged as one plugin for **Claude Code and Codex**: turn an idea into an issue that plans the arc, ground it against the code, then ship it off an integration branch through isolated git worktrees and dispatcher / implementer sub-agents.

**The issue says which of two paths the work is on**, and writing it is where that gets decided:

```
                                                    ┌ one slice ─▶ /pipeline:decompose ─▶ /pipeline:execute ─▶ done
rough idea ─/pipeline:co-think─▶ /pipeline:write-issue ─┤
                                                    └ an epic ───▶ /pipeline:orchestrate ─▶ done
                                                                   (loops the phases through those same two)
```

**Nine skills in two families, and one front door.** Six **arc** passes ship work into the integration branch, starting at `/pipeline:co-think`, which settles the shape and routes it — every command after that is named for you by the pass before it. Two **project** passes change the project itself and are invoked rather than routed to: `/pipeline:setup` onboards a repo and reconciles its config, and `/pipeline:cut-release` rolls the version and the branch work lands on. `/pipeline:glossary` is the map both families read.

| You type | Does |
|---|---|
| [`/pipeline:setup`](skills/setup/SKILL.md) | Onboards a repo once: grounds its real commands, writes `.agents/worktree.json`, scaffolds a gate queue if the project wants one, and verifies by cutting real worktrees. Also reconciles a config that has gone stale — against its repo, or against this plugin. |
| [`/pipeline:cut-release`](skills/cut-release/SKILL.md) | Cuts the next release branch and moves the version, as one reviewable commit in its own worktree — the repository side only, never tags or publishing. It exists because that moment was the one nothing in the flow was present for, which is how `integrationBranch` went stale and the version moved invisibly. |
| [`/pipeline:co-think`](skills/co-think/SKILL.md) | The front door, and where a request for your judgment on a shape lands as much as a request to build one. Writes the goal down as one testable sentence, classifies the work — spike, bounded or architectural — shapes an arc with you before anything is filed, and routes: to `write-issue`, straight to `orchestrate`, or to a root cause first when it is a bug. It shapes toward that goal rather than around the mechanisms it finds, so an existing check, ceiling or step is something it may propose changing or deleting. |
| [`/pipeline:write-issue`](skills/write-issue/SKILL.md) | Takes a shape you have already settled and **plans the arc**: grounds what the arc rests on — the real modules, the seams, whether the surface exists — sets the phases and their order, answers whether the work is one slice or an epic, and files it as a forward-facing issue. Where the shape is not settled it hands back to `co-think` rather than filing. |
| [`/pipeline:orchestrate`](skills/orchestrate/SKILL.md) | Runs a **multi-phase** arc to completion as a loop: grounds the horizon, dispatches it, reconciles the rest against the tree that increment produced, repeats. One slice never comes here. |

| Behind them | Does |
|---|---|
| [`/pipeline:decompose`](skills/decompose/SKILL.md) | The **pre-execution grounding** pass, on both paths: verifies a deliberately big-picture issue against the code, fills in the detail an executor acts on and enriches the issue with it, then turns the horizon into independent slices with owned files, do-not-touch fences and a verify bar. |
| [`/pipeline:execute`](skills/execute/SKILL.md) | The **dispatch** pass: cuts a worktree per slice, dispatches a fresh implementer into each, reviews the diffs and merges. |
| [`/pipeline:review`](skills/review/SKILL.md) | An implementer's own quality pass over its **uncommitted** diff, run inline before it commits. |

On the one-slice path those first two are the whole of the run and you invoke them yourself — that is the path, not a side door. On an epic the loop invokes both for you.

The plugin also ships the machinery `execute` drives. Claude Code puts a plugin's `bin/` on the `PATH` of whichever shell tool it hands you, so these are bare commands once the plugin is enabled — nothing to install. **Codex installs the same `bin/` but puts nothing on `PATH`**, so there they are called by absolute path from the installed plugin root; the skills carry that rule and neither host needs anything installed. Each helper ships **twice**: `<name>.sh` for the Bash tool, `<name>.ps1` for the PowerShell tool (see [Prerequisites](#prerequisites) for which you get) — same arguments, same environment variables, same output, same exit codes, one CLI contract implemented twice. What holds that pair together is the frozen contract in [AGENTS.md](AGENTS.md) and the review of every change to it; what the repo's own gate can and cannot see of it is in [Adding a skill](docs/adding-a-skill.md).

| Command | What it does |
|---|---|
| `setup-worktree.sh` · `.ps1` | Creates a worktree — or attaches one to an existing branch with `--existing` — symlinks the project's env files, exports its env, installs deps |
| `setup-workspace.sh` · `.ps1` | The polyrepo form: one worktree per member repo, same branch name in each — the members named outright, or the default set less `--exclude <repo,repo>`, with `--dry-run` printing the resolved member set and creating nothing |
| `merge-pr.sh` · `.ps1` | Atomic close-out: preflight mergeability, tear down the worktree, real merge commit, fast-forward the local base branch — and, at the epic boundary only and only where the project opted in, squash instead and verify the landed tree against the gated one before deleting the branch |
| `remove-worktree.sh` · `.ps1` | Safely tear down a worktree — found by branch leaf in either layout, bare or workspace member, or named outright by absolute path — killing processes rooted in it first, and stopping loudly rather than reporting a clean no-op when the tree it was asked for is registered somewhere it did not look |

---

## Reference

The detail lives in [`docs/`](docs/), one page per topic:

| Page | Covers |
|---|---|
| [Filing findings upstream](docs/filing-findings-upstream.md) | **Read this before you install** — what this plugin can write into its own public repository, and the per-project key that is off unless you switch it on |
| [Troubleshooting](docs/troubleshooting.md) | The three causes behind a git error while installing, and the fix for each |
| [Per-project config](docs/per-project-config.md) | Every key in `.agents/worktree.json`, what reads it, and what its absence means |
| [The mental model](docs/mental-model.md) | The loop, the two grounding depths, the branch levels, and why the shape is this shape |
| [Onboarding a new project](docs/onboarding-a-project.md) | What `/pipeline:setup` grounds, what it asks you, and how it reconciles a config that has drifted |
| [The hard rules](docs/hard-rules.md) | The rules the agent follows, stated so you can check its work |
| [Adding a skill](docs/adding-a-skill.md) | The gate, the checks worth understanding before you push, and the validator |

---

## Install

**On Claude Code, install from the marketplace** (the supported path — versioned, auto-updating):

```
/plugin marketplace add trinity-ai-labs/claude-plugins
/plugin install pipeline@trinity-ai-labs
```

Then turn on auto-update: `/plugin` → **Marketplaces** → select `trinity-ai-labs` → **Enable auto-update**. It is **off by default for third-party marketplaces**, so without this you never receive anything. Equivalently, set `"autoUpdate": true` on the marketplace's `extraKnownMarketplaces` entry in `~/.claude/settings.json`.

⚠️ **Auto-update delivers a new `version`, not a new commit.** Because `plugin.json` declares `version`, an install is pinned to that string — pushing to `main` without bumping it ships nothing to anyone. CI fails the build if shipped content changes without a bump, so this can't happen silently. See [CHANGELOG.md](CHANGELOG.md).

**On Codex**, add this repository as a marketplace and install from it. The marketplace manifest ships at `.agents/plugins/marketplace.json`, so the repository is the marketplace:

```bash
codex plugin marketplace add trinity-ai-labs/orchestration-skills
codex plugin add pipeline@trinity-ai-labs
```

`codex plugin marketplace add` also takes a local path, which is how you install a checkout you are editing. Codex reads `.codex-plugin/plugin.json` where Claude Code reads `.claude-plugin/plugin.json`; the `skills/` tree is shared, and the repo's gate fails if the two manifests disagree on `version`. Refresh with `codex plugin marketplace upgrade`.

**For developing the plugin itself**, clone it into your skills directory instead — edits then apply live, with no release step:

```bash
git clone https://github.com/trinity-ai-labs/orchestration-skills ~/.claude/skills/pipeline
```

Any folder under `~/.claude/skills/` with a `.claude-plugin/plugin.json` loads as a plugin on the next session. The directory name is the namespace.

**Or load it for one session**, which is the way to test a change:

```bash
claude --plugin-dir ~/Code/orchestration-skills
```

Verify with `/plugin list` on Claude Code — you should see `pipeline`, its nine skills, and eight executables (the four helpers, each shipped in bash and in PowerShell). On Codex, `codex plugin list` shows the `pipeline` row with its version and install status.

### Prerequisites

**Platform support.** Two questions: which language of helper runs, and whether it is on your `PATH`.

**Which language.** Every helper ships in both, because Claude Code does not hand every platform the same shell:

| Where Claude Code runs | Shell tool you get | Helpers that run there |
|---|---|---|
| macOS or Linux | Bash tool | `bin/*.sh` |
| Windows + WSL 2 | Bash tool (inside WSL) | `bin/*.sh` |
| Native Windows **with** Git for Windows | Bash tool, via Git Bash | `bin/*.sh` |
| Native Windows **without** Git for Windows | **PowerShell tool — there is no bash at all** | `bin/*.ps1` |

The PowerShell tool is rolling out progressively *alongside* the Bash tool rather than replacing it, so a Windows session can land in either one. That is why both copies ship and why neither may be added alone: a helper that exists in only one language is simply missing from `PATH` for everyone on the other shell, with no error until someone tries to run it.

**Whether it is on `PATH`.** Claude Code puts an enabled plugin's `bin/` on the shell tool's `PATH`, so the helpers are bare commands. **Codex does not** — its manifest has no `bin` key — though it does install `bin/` with the rest of the plugin, under `$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/`. On Codex the helpers are therefore called by absolute path from that root. The skills state this where they invoke a helper, so you should not have to think about it; it matters when you are reading a run that died at its first command.

- **git** (worktrees are built in)
- **[GitHub CLI](https://cli.github.com/)** (`gh`) authenticated: `gh auth login` — used to file issues and open/merge PRs
- **A host that loads the plugin** — [Claude Code](https://claude.com/claude-code) or [Codex](https://developers.openai.com/codex); the same `skills/` tree runs on both
- **A JSON interpreter for the `.sh` helpers only** — bash has no JSON parser, so they shell out to the first of `node`, `python3`, `python`, or `py -3` that works. They *run* each candidate rather than trusting `command -v`, because Windows ships a `python3.exe` alias that is a stub launching the Microsoft Store and returning nothing — a probe that only checks for the name on `PATH` picks it and then fails with an empty config. The `.ps1` helpers need none of this: `ConvertFrom-Json` is built into PowerShell, so that path has no interpreter to be missing in the first place.
- Whatever your project needs to install and test

---

## Daily usage

```
/pipeline:setup                                           # → once per repo: writes .agents/worktree.json
/pipeline:write-issue add per-workspace model overrides   # → files issue #1042 with its phase map and its verdict
```

`write-issue` ends with an explicit handoff line and **stops** — the line names the next command, and you decide whether to run it. Which line you get depends on the verdict it just wrote.

**One slice** — two more commands, no loop:

```
/pipeline:decompose #1042          # → grounds it for an executor and enriches the issue
/pipeline:execute #1042            # → worktree, implementer, gate, draft PR, review, merge
```

**An epic** — one:

```
/pipeline:orchestrate #1042        # → grounds the horizon, dispatches it, reconciles, repeats
```

`orchestrate` runs the arc to completion on its own, cycle after cycle, reporting what it decided each time; it comes back to you only for a genuine product or design fork the code and conventions cannot settle, asked in plain chat, one question at a time, with a recommendation — or to halt, which is a report rather than a question and happens when a cycle lands nothing or when what is left of the plan has stopped answering what you asked for.

**As an implementer, directly:** `build the toast-position fix` → Claude codes it in a fresh worktree, brings the docs it falsifies along with it, greens the scoped check, opens a draft PR, enqueues the gate, hands back.

**By hand:**

```bash
setup-worktree.sh fix/toast-position release/0.4.0     # fork a new branch off the integration branch
setup-worktree.sh --existing fix/toast-position        # attach a tree to a branch that already exists
```

`bin/` is on `PATH` inside whichever tool Claude Code hands you — Bash tool or PowerShell tool, per the platform table under [Prerequisites](#prerequisites) — but not in your own terminal, Bash or PowerShell alike, and not on Codex at all. To call the `.sh` helpers from a plain shell, or the `.ps1` helpers from a plain PowerShell prompt, add them once — somewhere **non-interactive** shells read too (the gate runner, the drain, and dispatched agents are all non-interactive):

```bash
# zsh — in ~/.zshenv, not ~/.zshrc
export PATH="$HOME/.claude/skills/pipeline/bin:$PATH"
```

```powershell
# Windows — persist it once; $PROFILE would only cover your interactive session
setx PATH "$env:USERPROFILE\.claude\skills\pipeline\bin;$env:PATH"
```

Both args of the first form are required — no default base, since integration branches roll over and a hardcoded default goes stale. `--existing` is the recovery form, for when a branch outlives its worktree (a close-out that failed at the merge, a tree removed by hand); it takes no base, because an existing branch's base is whatever it already forked from, and it refuses rather than creating a branch that isn't there. It is a flag and never an inference — attaching to a branch you meant to fork fresh is how a worktree ends up quietly behind the integration tip.

**Verify HEAD before you dispatch an agent into either kind of tree.** The helper prints it — `READY: <path>`, then `HEAD: <sha>` — and the comparison that catches a base gone stale under it, plus why the fetch is part of that comparison rather than preparation for it, is in [The hard rules](docs/hard-rules.md#the-hard-rules-the-agent-follows-these-good-to-know).

---

## Layout

```
.
├── .agents/
│   ├── worktree.json            # this repo's OWN pipeline config — contributor-only
│   └── plugins/marketplace.json # the Codex marketplace entry — this repo IS the marketplace
├── .claude-plugin/
│   └── plugin.json              # the Claude Code manifest — `name` sets the namespace
├── .codex-plugin/
│   └── plugin.json              # the Codex manifest — same version, or the gate reds
├── .github/workflows/ci.yml     # runs scripts/check.sh on Linux AND Windows, plus the version-bump guard
├── .gitattributes               # pins bin/* to LF — a CRLF checkout kills every helper at its shebang
├── AGENTS.md                    # repo conventions, the frozen helper contract, and the rules a change here is held to
├── bin/                         # SHIPPED — on PATH under Claude Code; by absolute path under Codex
│   ├── setup-worktree.sh        # .sh for the Bash tool, .ps1 for the PowerShell tool —
│   ├── setup-worktree.ps1       #   one contract, two languages, kept in step by scripts/check.sh
│   ├── setup-workspace.sh
│   ├── setup-workspace.ps1
│   ├── merge-pr.sh
│   ├── merge-pr.ps1
│   ├── remove-worktree.sh
│   └── remove-worktree.ps1
├── scripts/check.sh             # the repo gate — contributor-only, never shipped
├── examples/worktree.json       # a complete per-project config
└── skills/
    ├── setup/
    │   ├── SKILL.md
    │   └── references/gate-queue.md
    ├── cut-release/SKILL.md
    ├── co-think/SKILL.md
    ├── write-issue/
    │   ├── SKILL.md
    │   └── references/arc-planning.md
    ├── orchestrate/
    │   ├── SKILL.md
    │   └── references/reconciling.md
    ├── decompose/
    │   ├── SKILL.md
    │   └── references/           # grounding, slicing, emitting
    ├── execute/
    │   ├── SKILL.md              # a spine: an ordered list of actions, each naming its reference
    │   └── references/           # one file per phase, opened when you reach that phase
    ├── review/SKILL.md
    └── glossary/
        ├── SKILL.md              # the index both families read
        ├── vocabulary/           # what a shared term IS — defined once, cited from everywhere
        └── mechanics/            # how one operation is performed
```

To change the workflow: edit the file, commit, push. A clone-install picks it up on `git pull`.

---

## License

MIT — see [LICENSE](LICENSE).
