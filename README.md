# orchestration-skills

The Claude Code **dev pipeline**, packaged as one plugin: turn an idea into a grounded GitHub issue, slice it into parallel waves, then ship it off an integration branch using isolated git worktrees and orchestrator / implementer sub-agents.

```
idea / plan  ──/pipeline:write-issue──▶  grounded issue  ──/pipeline:decompose──▶  slices + waves  ──/pipeline:orchestrate──▶  worktrees · PRs · merges
```

Four skills in one plugin — `setup` onboards a repo once, then the three-leg pipeline runs on it: each skill's handoff names the next by slash-command, and `decompose` + `orchestrate` both read the same per-project config.

| Skill | Does | Never does |
|---|---|---|
| [`/pipeline:setup`](skills/setup/SKILL.md) | Onboards a repo: grounds its real commands, writes `.agents/worktree.json`, scaffolds a gate queue if it wants one | Guess a command; write features |
| [`/pipeline:write-issue`](skills/write-issue/SKILL.md) | Grounds an idea in the real code and files it as a forward-facing issue (or umbrella + subs) | Slice into waves; write code |
| [`/pipeline:decompose`](skills/decompose/SKILL.md) | Turns that plan into independent slices with owned files, do-not-touch boundaries, waves, conflict map, model tiers | Make worktrees; dispatch; merge |
| [`/pipeline:orchestrate`](skills/orchestrate/SKILL.md) | Cuts a worktree per slice, dispatches implementers, reviews each PR's diff, merges, cleans up | — (it's the executor) |

The plugin also ships the machinery `orchestrate` drives. Claude Code puts a plugin's `bin/` on the `PATH` of whichever shell tool it hands you, so these are bare commands once the plugin is enabled — nothing to install. Each helper ships **twice**: `<name>.sh` for the Bash tool, `<name>.ps1` for the PowerShell tool (see [Prerequisites](#prerequisites) for which you get). Same arguments, same environment variables, same output, same exit codes — and `scripts/check.sh` compares the two on every run, so the pair cannot drift apart quietly.

| Command | What it does |
|---|---|
| `setup-worktree.sh` · `.ps1` | Creates a worktree, symlinks the project's env files, exports its env, installs deps |
| `setup-workspace.sh` · `.ps1` | The polyrepo form: one worktree per member repo, same branch name in each |
| `merge-pr.sh` · `.ps1` | Atomic close-out: tear down the worktree, real merge commit, fast-forward the local integration branch |
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

Verify with `/plugin list` — you should see `pipeline`, its four skills, and eight executables (the four helpers, each shipped in bash and in PowerShell).

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

You **never code directly in the main checkout.** The main checkout holds the **integration branch** (for Trinity, `release/x.x.x`). Every task gets its own worktree under `$WORKTREE_HOME/<project>/<branch-leaf>`, branched off the integration branch. `WORKTREE_HOME` defaults to `~/.worktrees`, except on Windows where it defaults to `%LOCALAPPDATA%\wt` — a worktree path there ends up carrying a whole dependency tree (`…/<repo>/node_modules/.pnpm/<pkg>@<version>/…`), and from `~/.worktrees` that routinely runs past Windows' 260-character `MAX_PATH`, which surfaces as an install failing on some deeply nested filename rather than on the length. Setting `WORKTREE_HOME` yourself overrides the default on every platform. Work → commit → push → PR back into the integration branch → review → **merge with a real merge commit** → sync the local integration branch → delete branch + worktree.

**Where the review approval lives.** A PR is opened as a **draft** and stays one for its whole life. The gate reports its verdict as a **comment** — a pass or the failing tail — so the reading is one sentence: *a PR is gated iff it carries a gate comment.* The `draft → ready` flip means something different and stronger: an orchestrator read this diff and is merging it. `merge-pr.sh` is the only thing that sets it, one line above `gh pr merge`, so approval can never go stale between the review and the merge. A green gate says the suite passed; it cannot say the agent solved the right problem.

When you invoke `/pipeline:orchestrate`, Claude first decides **which role it's in**:

- **Orchestrator** — you asked it to *coordinate* work, *work a GitHub issue*, or *execute a plan*. It does **not** write code. It decomposes, makes + verifies a worktree per task, dispatches implementer sub-agents in parallel, reviews each PR by reading the diff, drains the gate queue, and merges.
- **Implementer** — you told it to *build / fix / implement* a specific thing (or it was dispatched as a sub-agent). It codes in its worktree, updates the docs its change falsifies, greens the scoped check, opens a **draft** PR, enqueues the gate, and **hands back — it never merges its own PR**, reporting a verdict per doc it checked.

### Why this shape
- **Front-loaded planning** → `write-issue` and `decompose` do the expensive grounding *before* any worktree exists, so the orchestrator isn't slicing work mid-flight while juggling PRs and merges.
- **Isolated worktrees** → parallel tasks never collide; each has its own `node_modules` and branch.
- **A durable gate queue** → implementers enqueue and hand back rather than waiting, so a wide fan-out never serializes on a gate lock and a dying agent can't strand committed work.
- **Real merge commits, never squash/rebase** → history is preserved; parallel-branch conflicts resolve at merge time.

---

## Daily usage

```
/pipeline:setup                                           # → once per repo: writes .agents/worktree.json
/pipeline:write-issue add per-workspace model overrides   # → files issue #1042, hands off
/pipeline:decompose #1042                                 # → posts slices + waves onto the issue
/pipeline:orchestrate work issue #1042                    # → worktrees, PRs, merges
```

Each leg ends with an explicit handoff line and **stops** — you decide whether to run the next.

**As an implementer, directly:** `build the toast-position fix` → Claude codes it in a fresh worktree, brings the docs it falsifies along with it, greens the scoped check, opens a draft PR, enqueues the gate, hands back.

**By hand:**

```bash
setup-worktree.sh fix/toast-position release/0.4.0
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

Both args are required — no default base, since integration branches roll over and a hardcoded default goes stale.

> **Always verify HEAD before dispatching an agent into a worktree:**
> ```bash
> git -C ~/.worktrees/trinity/toast-position rev-parse HEAD   # %LOCALAPPDATA%\wt\trinity\… on Windows
> git rev-parse origin/release/0.4.0     # must match
> ```
> The helper doesn't verify this — a mismatch means the base is stale.

---

## Onboarding a new project

Run **`/pipeline:setup`** in that repo. It grounds the commands in the repo's real lockfile, scripts, and CI, writes `.agents/worktree.json`, and scaffolds a durable gate queue *into that repo* if the project wants one — the plugin carries the knowledge, the project owns the code, so each queue can evolve independently. It verifies by cutting a real worktree and round-tripping a ticket, then tears the worktree down.

To do it by hand instead: add `.agents/worktree.json` to that repo, declaring the keys above, and commit it. Read the repo's `AGENTS.md`, its package scripts, and its CI to fill in the commands rather than guessing.

A repo with no config still cuts a worktree — but a **bare** one, with no env symlinks and no install. Where the project has an install step that worktree is unusable: it has no `node_modules`, so every check inside it fails for reasons that read as code bugs, and the run burns before anyone reads the stderr warning. Don't dispatch into it. For a **zero-dependency** repo a bare worktree is the only kind there is and it works fine — this repo is one, and its own config landed through a normal PR — but you still want the config, because without it the gate and the conventions are things an orchestrator has to guess, and a guessed gate passes while testing nothing.

---

## The hard rules (Claude follows these; good to know)

- **Never** use the Agent tool's `isolation: "worktree"` param or any auto worktree provisioner — they seed worktrees at a **stale base** and put them in the wrong place. Only `setup-worktree.sh` makes worktrees.
- **Never squash-merge, never rebase.** Always real merge commits.
- **Branch from the integration branch, not `main`.** PRs target the integration branch.
- **Implementers never run the full gate, never mark their own PRs ready, and never merge their own PRs** — they enqueue; a runner gates and comments the verdict; the orchestrator reviews the diff, marks it ready, and merges.
- **After merge:** sync the local integration branch *first*, then delete the merged branch, remove the worktree, and close the issue yourself (`gh issue close` — GitHub won't auto-close, since PRs merge into the integration branch, not `main`).

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
    ├── decompose/SKILL.md
    └── orchestrate/SKILL.md
```

To change the workflow: edit the file, commit, push. A clone-install picks it up on `git pull`.

---

## License

MIT — see [LICENSE](LICENSE).
