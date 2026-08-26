# orchestration-skills

The Claude Code **dev pipeline**, packaged as one plugin: turn an idea into a grounded GitHub issue, then run it to completion as a just-in-time loop — ground the next dispatchable increment, ship it off an integration branch through isolated git worktrees and orchestrator / implementer sub-agents, then re-ground what remains against the tree that increment actually produced.

```
idea / plan  ──/pipeline:write-issue──▶  grounded issue  ──/pipeline:execute──▶  ground the horizon · dispatch · reconcile · repeat until empty
```

Six skills in one plugin, and **two commands**. `setup` onboards a repo once; after that `/pipeline:write-issue` files the plan and `/pipeline:execute` runs it. `decompose` and `orchestrate` are the two passes the loop drives each cycle — still directly invocable when you want one increment grounded or one increment dispatched, but not where an arc starts. `review` is the one an implementer calls on itself mid-slice.

| Skill | Does | Never does |
|---|---|---|
| [`/pipeline:setup`](skills/setup/SKILL.md) | Onboards a repo: grounds its real commands, writes `.agents/worktree.json`, scaffolds a gate queue if it wants one | Guess a command; write features |
| [`/pipeline:write-issue`](skills/write-issue/SKILL.md) | Grounds an idea in the real code and files it as a forward-facing issue (or umbrella + subs) | Slice into waves; write code |
| [`/pipeline:execute`](skills/execute/SKILL.md) | Runs an arc to completion as a loop: grounds the horizon, dispatches it, reconciles everything still outstanding against the merged tree, rewrites the rest, repeats | Write code; ground beyond the horizon |
| [`/pipeline:decompose`](skills/decompose/SKILL.md) | The loop's **grounding** pass: turns the horizon into independent slices with owned files, do-not-touch boundaries, waves, conflict map, model tiers | Ground past the horizon; make worktrees; dispatch; merge |
| [`/pipeline:orchestrate`](skills/orchestrate/SKILL.md) | The loop's **dispatch** pass: cuts a worktree per slice, dispatches implementers, reviews each PR's diff, merges, cleans up | Run the loop around itself; write the code it dispatches |
| [`/pipeline:review`](skills/review/SKILL.md) | An implementer's own quality + correctness pass over its **uncommitted** diff, run inline right before it commits | Spawn sub-agents; commit; push; run the full suite |

The plugin also ships the machinery `orchestrate` drives. Claude Code puts a plugin's `bin/` on the `PATH` of whichever shell tool it hands you, so these are bare commands once the plugin is enabled — nothing to install. Each helper ships **twice**: `<name>.sh` for the Bash tool, `<name>.ps1` for the PowerShell tool (see [Prerequisites](#prerequisites) for which you get). Same arguments, same environment variables, same output, same exit codes — and `scripts/check.sh` compares the two on every run, so the pair cannot drift apart quietly.

| Command | What it does |
|---|---|
| `setup-worktree.sh` · `.ps1` | Creates a worktree — or attaches one to an existing branch with `--existing` — symlinks the project's env files, exports its env, installs deps |
| `setup-workspace.sh` · `.ps1` | The polyrepo form: one worktree per member repo, same branch name in each |
| `merge-pr.sh` · `.ps1` | Atomic close-out: preflight mergeability, tear down the worktree, real merge commit, fast-forward the local base branch |
| `remove-worktree.sh` · `.ps1` | Safely tear down a worktree, killing processes rooted in it first |

---

## Install

**Install from the marketplace** (the supported path — versioned, auto-updating):

```
/plugin marketplace add trinity-ai-labs/claude-plugins
/plugin install pipeline@trinity-ai-labs
```

Then turn on auto-update: `/plugin` → **Marketplaces** → select `trinity-ai-labs` → **Enable auto-update**. It is **off by default for third-party marketplaces**, so without this you never receive anything. Equivalently, set `"autoUpdate": true` on the marketplace's `extraKnownMarketplaces` entry in `~/.claude/settings.json`.

⚠️ **Auto-update delivers a new `version`, not a new commit.** Because `plugin.json` declares `version`, an install is pinned to that string — pushing to `main` without bumping it ships nothing to anyone. CI fails the build if shipped content changes without a bump, so this can't happen silently. See [CHANGELOG.md](CHANGELOG.md).

**For developing the plugin itself**, clone it into your skills directory instead — edits then apply live, with no release step:

```bash
git clone https://github.com/trinity-ai-labs/orchestration-skills ~/.claude/skills/pipeline
```

Any folder under `~/.claude/skills/` with a `.claude-plugin/plugin.json` loads as a plugin on the next session. The directory name is the namespace.

**Or load it for one session**, which is the way to test a change:

```bash
claude --plugin-dir ~/Code/orchestration-skills
```

Verify with `/plugin list` — you should see `pipeline`, its six skills, and eight executables (the four helpers, each shipped in bash and in PowerShell).

### Prerequisites

**Platform support.** Every helper ships in both languages, because Claude Code does not hand every platform the same shell:

| Where Claude Code runs | Shell tool you get | Helpers that run there |
|---|---|---|
| macOS or Linux | Bash tool | `bin/*.sh` |
| Windows + WSL 2 | Bash tool (inside WSL) | `bin/*.sh` |
| Native Windows **with** Git for Windows | Bash tool, via Git Bash | `bin/*.sh` |
| Native Windows **without** Git for Windows | **PowerShell tool — there is no bash at all** | `bin/*.ps1` |

The PowerShell tool is rolling out progressively *alongside* the Bash tool rather than replacing it, so a Windows session can land in either one. That is why both copies ship and why neither may be added alone: a helper that exists in only one language is simply missing from `PATH` for everyone on the other shell, with no error until someone tries to run it.

- **git** (worktrees are built in)
- **[GitHub CLI](https://cli.github.com/)** (`gh`) authenticated: `gh auth login` — used to file issues and open/merge PRs
- **[Claude Code](https://claude.com/claude-code)** — where the skills run
- **A JSON interpreter for the `.sh` helpers only** — bash has no JSON parser, so they shell out to the first of `node`, `python3`, `python`, or `py -3` that works. They *run* each candidate rather than trusting `command -v`, because Windows ships a `python3.exe` alias that is a stub launching the Microsoft Store and returning nothing — a probe that only checks for the name on `PATH` picks it and then fails with an empty config. The `.ps1` helpers need none of this: `ConvertFrom-Json` is built into PowerShell, so that path has no interpreter to be missing in the first place.
- Whatever your project needs to install and test

---

## Troubleshooting

**A git error while installing this plugin is not evidence of an auth or permissions problem.** Every repository behind this plugin is public, clones clean (no illegal Windows filename characters, no case collisions, no reserved DOS names), and needs no credentials — so when a clone or fetch fails, the cause lives in *your* environment or in how a marketplace declared its source, never in a broken or private repo. It is never a permissions problem with the plugin itself.

All three causes below present as the same undifferentiated "git error," and their fixes have nothing in common — match your error text to a cause before changing anything:

| Your error names... | Cause |
|---|---|
| `Host key verification failed`, `No ED25519 host key is known for github.com` | The marketplace declared its source with the GitHub `owner/repo` shorthand, which clones over SSH by default |
| `SSL certificate problem: unable to get local issuer certificate` | Corporate TLS interception |
| `detected dubious ownership in repository` | Git's dubious-ownership check |

### Cause 1: the GitHub shorthand source clones over SSH by default

The literal error:

```
Failed to install: Failed to clone repository: Cloning into 'C:\Users\...\.claude\plugins\cache\temp_github_...'...
No ED25519 host key is known for github.com and you have requested strict checking.
Host key verification failed.
fatal: Could not read from remote repository.
```

Per Claude Code's own documentation: a marketplace entry that declares its source as `{"source": "github", "repo": "owner/repo"}` — the GitHub `owner/repo` shorthand — clones over **SSH** by default, not HTTPS; set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` to make it clone over HTTPS instead. This marketplace's entries used exactly that shorthand for three fully public repositories that need no credentials at all, so Claude Code silently chose SSH for a request that had no reason to need it. With no `github.com` entry in `known_hosts` — normal for anyone who has never pushed over SSH from that machine — strict host-key checking rejects the clone before it starts.

This reads as a broken plugin rather than as a protocol choice, because nothing about installing a public plugin suggests SSH is involved: the reader never typed `git@github.com`, never touched their own git config, and the failure has the same "clone failed" shape a real permissions problem produces. The actual decision — HTTPS vs. SSH — was made by the marketplace entry's source type, on the reader's behalf, before git ever looked at anything on their machine.

**This is fixed in the marketplace as of now.** `trinity-ai-labs/claude-plugins` declares all three plugins with an explicit `{"source": "url", "url": "https://github.com/....git"}`, which Claude Code takes verbatim and clones over HTTPS — so a current install will not hit this. If you're pinned to an older marketplace entry, or you hit this same error shape installing from a *different* marketplace that still uses the `github` shorthand, set the escape hatch in your Claude Code settings:

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_PREFER_HTTPS": "1"
  }
}
```

> **If you publish a marketplace:** prefer an explicit `{"source": "url", "url": "https://github.com/owner/repo.git"}` over the GitHub `owner/repo` shorthand for public plugins. The shorthand clones over SSH by default, which silently requires an SSH key and a trusted host key your users have no reason to have for a repo that needs neither — turning a working public install into a "broken plugin" report that traces back to the marketplace manifest, not their machine.

### Cause 2: corporate TLS interception

Presents as:

```
SSL certificate problem: unable to get local issuer certificate
```

Your network is intercepting TLS and presenting a certificate signed by a corporate CA that git doesn't trust. Point git at that CA bundle instead of rejecting it:

```
git config --global http.sslCAInfo /path/to/corporate-ca-bundle.pem
```

**Never** `git config --global http.sslVerify false`. Disabling verification to get one clone through leaves it disabled for every fetch afterward, silently — the fix for today's clone becomes a standing hole that makes every future fetch on that machine interceptable without warning.

### Cause 3: dubious ownership

Presents as:

```
fatal: detected dubious ownership in repository at 'C:/...'
```

Fix:

```
git config --global --add safe.directory <path>
```

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
| `install` | script | Run inside a new worktree — worktrees never share `node_modules`. Omit it, and `envFiles`, for a zero-dependency repo: a guessed install command fails every worktree setup |
| `env` | script | Exported before the install; most usefully a shared build-cache dir |
| `gate` | skills | The authoritative check before merge. With a queue, the *runner* runs it, never an implementer. May equal `scopedCheck` when the repo has only one tier |
| `scopedCheck` | skills | The cheap bar an implementer's commits are held to |
| `enqueue` / `drain` | skills | How a PR joins the gate queue, and how an orchestrator drains it. **Omit both** if the project has no queue — the implementer then gates in-line |
| `format` | skills | The auto-formatter in *write* mode, run right before committing |
| `frameworkSkills` | skills | `{skill, when}` pairs — the skill each area opens with |
| `briefConventions` | skills | Conventions baked into every dispatched implementer brief |

See [`examples/worktree.json`](examples/worktree.json) for a complete file.

**Why it lives in the repo.** It travels with the clone, works under any checkout directory name, and is reviewed in the same PR as the change that alters it. Keying it to a directory name instead — the old design — meant a repo cloned to a different folder silently got no config, and the helper would cut a bare worktree with no env and no `node_modules` while only warning on stderr.

⚠️ **A shared cache var has to be set somewhere non-interactive shells read.** The config's `env` covers the install step, but the gate runner, the drain, and dispatched agents run in **non-interactive** shells — so a var set only where an interactive shell reads it reaches your terminal and nothing else, and the cache silently never applies to a gated PR.

| Shell | Set it in | NOT in |
|---|---|---|
| zsh (macOS default) | `~/.zshenv` | `~/.zshrc` — interactive only |
| bash | `~/.bashrc` **and** point `BASH_ENV` at it, since that is the only file a non-interactive bash reads | `~/.bash_profile` — login shells only |
| PowerShell / Windows | a **persisted user environment variable**: `setx VAR value` once, or System Properties → Environment Variables | `$PROFILE` — interactive only, so it is the exact same trap as `~/.zshrc`, and there is no Windows file that behaves like `~/.zshenv` |

A persisted Windows environment variable is inherited by every process started afterwards regardless of shell, so it also covers Git Bash — which is why it, and not a dotfile, is the Windows answer.

---

## The mental model

**An arc is a loop, not a plan you write once.** `/pipeline:execute` grounds only the **horizon** — the next dispatchable increment, meaning every remaining item whose dependencies have already landed — dispatches it, then **reconciles** everything still outstanding against the tree that increment actually produced, rewrites what remains, and goes round again until the plan is empty and the close-out is green. That is the whole loop, and it is why the surface is two commands rather than three.

Every item in the plan therefore sits at one of **two grounding depths**, decided by where the horizon is and by nothing else:

| Depth | Applies to | Carries |
|---|---|---|
| **Slice depth** | the horizon, and only the horizon | Owned files as real paths, do-not-touch boundaries, depends-on, the framework skill to open with, the model tier, the brief, the verify bar — grounded against the tree as it stands *right now* and dispatched in the same cycle |
| **Shape depth** | everything beyond it | Goal, area, what it waits on, one line on why it comes after the thing before it — and **no `file:line`, no owned files, no boundaries, no model tier, no verify bar** |

Reaching the horizon is the only thing that promotes an item from one depth to the other — not a well-understood item, not a small one, not one you were asked about. Both mistakes are silent. A coordinate grounded three waves early names a path an intervening wave has since moved: nothing errors, the brief still reads well, and the implementer opens a tree where the target is not there, finds the nearest plausible thing, and builds against that. An item dispatched at shape depth has no owned-file list and no boundary, so the implementer invents its own scope and the first anyone hears of it is a PR in a sibling slice's core files.

After every increment merges, the loop re-checks the rest of the plan against the merged tree — coordinates that no longer resolve, renames whose *senses* the plan still uses the old word for, work the tree now forces that no remaining item owns, and assumptions the increment falsified — then folds what the arc cannot ship without into a named slice and files the rest as linked issues. It decides wave assignment, fold-vs-file, sizing and re-slicing itself, and asks you only about a product or design fork the code and conventions cannot settle.

You **never code directly in the main checkout.** The main checkout holds the **integration branch** (for Trinity, `release/x.x.x`). Every task gets its own worktree under `$WORKTREE_HOME/<project>/<branch-leaf>`, branched off the integration branch. `WORKTREE_HOME` defaults to `~/.worktrees`, except on Windows where it defaults to `%LOCALAPPDATA%\wt` — a worktree path there ends up carrying a whole dependency tree (`…/<repo>/node_modules/.pnpm/<pkg>@<version>/…`), and from `~/.worktrees` that routinely runs past Windows' 260-character `MAX_PATH`, which surfaces as an install failing on some deeply nested filename rather than on the length. Setting `WORKTREE_HOME` yourself overrides the default on every platform. Work → commit → push → PR back into the integration branch → review → **merge with a real merge commit** → sync the local integration branch → delete branch + worktree.

**One optional second level: the epic branch.** Two rules reach for it. A multi-slice epic that is only correct *as a whole* — a schema swap every consumer must follow, two halves of one contract — would otherwise leave the integration branch carrying a half-finished change set for the entire run, with everyone else's worktrees cut from whatever state it happens to be in. And multi-slice work **dispatched in parallel** reaches for it by default even when every intermediate state would ship, because concurrent slices converging on the shared branch cost something regardless of that: each live slice's base moves under the others, the branch ends up carrying merged trees no single slice's gate ever ran, an epic that turns out wrong is N merges to unpick instead of one to revert, and the two halves of a contract seam are far easier to compare while both are still converging somewhere you control. For those, an **epic branch** is cut from the integration branch in the main checkout: the epic's slices fork from it and PR into it, it is gated as a whole once they have all landed — when the merges actually produced a tree the slice gates did not already cover, which is a one-command check rather than a habit — and it reaches the integration branch as one ordinary merge at the end. Neither rule is a slice count, and neither is "the integration branch is busy": the first asks whether a partial state is *broken*, and the second keys on your own fan-out across one change rather than on other sessions' traffic. It buys isolation and costs deferred conflicts, so the orchestrator merges the integration branch back into it on the same tick that drains the gate queue — mandatory, and the more so now that the second rule fires on the shape this flow reaches for most often. **Single-slice work never cuts one**, and the flow above is unchanged when there isn't one.

**Where the review approval lives.** A PR is opened as a **draft** and stays one for its whole life. The gate reports its verdict as a **comment** — a pass or the failing tail — so the reading is one sentence: *a PR is gated iff it carries a gate comment.* The `draft → ready` flip means something different and stronger: an orchestrator read this diff and is merging it. `merge-pr.sh` is the only thing that sets it, one line above `gh pr merge`, so approval can never go stale between the review and the merge. A green gate says the suite passed; it cannot say the agent solved the right problem.

`/pipeline:orchestrate` is where one increment gets shipped, and it runs in one of **two roles — decided by how it was entered, not by how the work looks**:

- **Orchestrator** — entered from `/pipeline:execute`'s loop, which invokes it once per cycle to dispatch the increment it has just grounded, or from you asking it to coordinate one increment directly. It does **not** write code. It makes + verifies a worktree per slice, dispatches implementer sub-agents in parallel, reviews each PR by reading the diff, drains the gate queue, and merges. Unfinished work a slice reports is its move to make — a fix agent, a resume, or a filed and linked follow-up folded into the plan.
- **Implementer** — entered from a dispatch brief (an orchestrator handed it one slice and the worktree to build it in), or from you telling it to *build / fix / implement* a specific thing. It codes in its worktree, updates the docs its change falsifies, greens the scoped check, opens a **draft** PR, enqueues the gate, and **hands back — it never merges its own PR**, reporting a verdict per doc it checked. Work it found but could not land, it files as a linked issue and reports by number rather than leaving in prose.

An arc, an epic, or a whole issue enters at **`/pipeline:execute`** instead — including one that turns out to be a single increment, because working out where the horizon falls is the loop's first cycle rather than something you have to settle before entering it.

### Why this shape
- **Just-in-time grounding** → `execute` grounds one increment at a time, against the tree that increment's implementers will actually open, then re-grounds what remains once it has merged. A plan grounded once up front is at its most accurate the moment before any of it runs and decays from there: every wave that lands moves coordinates the later waves were written against, and nothing about that decay raises an error.
- **Isolated worktrees** → parallel tasks never collide; each has its own `node_modules` and branch.
- **A durable gate queue** → implementers enqueue and hand back rather than waiting, so a wide fan-out never serializes on a gate lock and a dying agent can't strand committed work.
- **Real merge commits, never squash/rebase** → history is preserved; parallel-branch conflicts resolve at merge time.

---

## Daily usage

```
/pipeline:setup                                           # → once per repo: writes .agents/worktree.json
/pipeline:write-issue add per-workspace model overrides   # → files issue #1042, hands off
/pipeline:execute #1042                                   # → grounds the horizon, dispatches it, reconciles, repeats
```

Two commands. `write-issue` ends with an explicit handoff line and **stops** — you decide whether to run the second. `execute` then runs the arc to completion on its own, cycle after cycle, reporting what it decided each time; it comes back to you only for a genuine product or design fork the code and conventions cannot settle, asked in plain chat, one question at a time, with a recommendation.

The two passes the loop drives are still there when you want one on its own — they simply aren't where an arc starts:

```
/pipeline:decompose #1042            # → grounds ONE increment and posts the breakdown; no dispatch, no loop
/pipeline:orchestrate wave 1 of #1042  # → dispatches ONE increment already grounded; no loop around it
```

**As an implementer, directly:** `build the toast-position fix` → Claude codes it in a fresh worktree, brings the docs it falsifies along with it, greens the scoped check, opens a draft PR, enqueues the gate, hands back.

**By hand:**

```bash
setup-worktree.sh fix/toast-position release/0.4.0     # fork a new branch off the integration branch
setup-worktree.sh --existing fix/toast-position        # attach a tree to a branch that already exists
```

`bin/` is on `PATH` inside whichever tool Claude Code hands you — Bash tool or PowerShell tool, per the table above — but not in your own terminal, Bash or PowerShell alike. To call the `.sh` helpers from a plain shell, or the `.ps1` helpers from a plain PowerShell prompt, add them once — somewhere **non-interactive** shells read too (the gate runner, the drain, and dispatched agents are all non-interactive):

```bash
# zsh — in ~/.zshenv, not ~/.zshrc
export PATH="$HOME/.claude/skills/pipeline/bin:$PATH"
```

```powershell
# Windows — persist it once; $PROFILE would only cover your interactive session
setx PATH "$env:USERPROFILE\.claude\skills\pipeline\bin;$env:PATH"
```

Both args of the first form are required — no default base, since integration branches roll over and a hardcoded default goes stale. `--existing` is the recovery form, for when a branch outlives its worktree (a close-out that failed at the merge, a tree removed by hand); it takes no base, because an existing branch's base is whatever it already forked from, and it refuses rather than creating a branch that isn't there. It is a flag and never an inference — attaching to a branch you meant to fork fresh is how a worktree ends up quietly behind the integration tip.

> **Always verify HEAD before dispatching an agent into a worktree.** The helper prints it — `READY: <path>` and then `HEAD: <sha>` — but does not check it for you:
> ```bash
> git rev-parse origin/release/0.4.0     # the HEAD: line must match this
> ```
> A mismatch means the base is stale. Compare the sha, not the `READY: … off <base>` text: that says what was asked for, and this check exists for the case where what you got is something else.

---

## Onboarding a new project

Run **`/pipeline:setup`** in that repo. It grounds the commands in the repo's real lockfile, scripts, and CI, writes `.agents/worktree.json`, and scaffolds a durable gate queue *into that repo* if the project wants one — the plugin carries the knowledge, the project owns the code, so each queue can evolve independently. It verifies by cutting a real worktree and round-tripping a ticket, then tears the worktree down.

To do it by hand instead: add `.agents/worktree.json` to that repo, declaring the keys above, and commit it. Read the repo's `AGENTS.md`, its package scripts, and its CI to fill in the commands rather than guessing.

A repo with no config still cuts a worktree — but a **bare** one, with no env symlinks and no install. Where the project has an install step that worktree is unusable: it has no `node_modules`, so every check inside it fails for reasons that read as code bugs, and the run burns before anyone reads the stderr warning. Don't dispatch into it. For a **zero-dependency** repo a bare worktree is the only kind there is and it works fine — this repo is one, and its own config landed through a normal PR — but you still want the config, because without it the gate and the conventions are things an orchestrator has to guess, and a guessed gate passes while testing nothing.

---

## The hard rules (Claude follows these; good to know)

- **Never ground beyond the horizon.** Only the increment about to be dispatched gets real paths, owned files, boundaries and a model tier; everything past it stays at shape depth until the horizon reaches it. Grounding more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the paths — and then nothing errors.
- **Never** use the Agent tool's `isolation: "worktree"` param or any auto worktree provisioner — they seed worktrees at a **stale base** and put them in the wrong place. Only `setup-worktree.sh` makes worktrees.
- **Never squash-merge, never rebase.** Always real merge commits.
- **Branch from the branch the work converges on, not `main`.** That is the integration branch, or the epic branch when a multi-slice epic has cut one. A PR targets the same branch its worktree came from.
- **Implementers never run the full gate, never mark their own PRs ready, and never merge their own PRs** — they enqueue; a runner gates and comments the verdict; the orchestrator reviews the diff, marks it ready, and merges.
- **Named stashes only — never a blind `git stash pop`.** The stash stack is a **repo-global** ref: the main checkout and every worktree push onto and pop off the same one, and git's `WIP on <branch>` subject names no owner. So a bare pop in one worktree applies *and drops* whatever happens to be on top — another agent's work, or yours. Agents stash under a `pipeline-stash/<branch-leaf>/<epoch>` marker, re-find their own entry by that marker immediately before every pop, and stop and report rather than guess when it is not there. `git stash clear` is banned outright.
- **An agent owns its follow-ups.** Work a change reveals but doesn't land becomes a filed, linked issue folded into the run — not a bullet in a hand-back for you to triage. That holds for orchestrators too: a slice reporting unfinished work is the orchestrator's next move, not something to forward on. You get asked only for a genuine design or product fork the codebase and conventions can't settle — in plain chat, one question at a time, with a recommendation.
- **Close out with one command** — `merge-pr.sh <n>` runs the whole sequence in its one correct order: preflight that the PR can actually merge, remove the worktree (git won't delete a branch checked out in one), real merge commit with `--delete-branch`, then fast-forward the local base branch — the step with no forcing feedback, and the one a hand-run close-out drops. Then close the issue yourself (`gh issue close` — GitHub won't auto-close, since PRs merge into the integration branch, not `main`).

---

## Adding a skill

Drop `skills/<slug>/SKILL.md` in and it loads — no manifest edit needed. The repo's gate enforces the two things that make a skill actually load: frontmatter carrying `name`, `description`, and `argument-hint`; and `name` matching the directory, since Claude Code registers the slash-command from the directory name.

Run it before you push — it is the same command CI runs, so there is no second copy to drift:

```bash
sh scripts/check.sh
```

Alongside shellcheck, the manifest, and the skill frontmatter, it also holds `bin/` to the parity rule: every `<name>.sh` has a `<name>.ps1` sibling and vice versa, the two agree on their usage line and on the environment variables they read, and every `.ps1` is printable ASCII terminated by LF — Windows PowerShell 5.1 decodes a BOM-less file as the system ANSI codepage, so one stray em-dash corrupts it and the parse error lands nowhere near the character that caused it. Those checks need nothing installed, so they always run.

The one step that needs an optional tool is PSScriptAnalyzer, which needs `pwsh`. When `pwsh` or the module is missing it prints **`SKIP`**, never `ok` — a check that could not run must not read as green — and CI's `check` job (`ubuntu-latest`) is where it actually lints, since that runner ships both `pwsh` and PSScriptAnalyzer preinstalled. `pwsh` is deliberately *not* on the gate's required-tool list: this repo is zero-dependency by design, and a gate that needs an install is a gate nobody can run before pushing.

Before publishing, also run the authoritative validator — the same one the community-marketplace review runs:

```bash
claude plugin validate . --strict
```

---

## Layout

```
.
├── .agents/worktree.json        # this repo's OWN pipeline config — contributor-only
├── .claude-plugin/
│   └── plugin.json              # the plugin manifest — `name` sets the namespace
├── .github/workflows/ci.yml     # runs scripts/check.sh on Linux AND Windows, plus the version-bump guard
├── .gitattributes               # pins bin/* to LF — a CRLF checkout kills every helper at its shebang
├── AGENTS.md                    # repo conventions, the frozen helper contract, the bin/ parity rule
├── bin/                         # SHIPPED — on PATH while the plugin is enabled
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
    ├── write-issue/SKILL.md
    ├── execute/SKILL.md
    ├── decompose/SKILL.md
    ├── orchestrate/SKILL.md
    └── review/SKILL.md
```

To change the workflow: edit the file, commit, push. A clone-install picks it up on `git pull`.

---

## License

MIT — see [LICENSE](LICENSE).
