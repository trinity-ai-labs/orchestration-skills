## Per-project config

Each project declares its own specifics at **`<repo>/.agents/worktree.json`**, committed to that repo. Two scripts read it: `setup-worktree.sh` reads `envFiles`, `env`, and `install`, and `merge-pr.sh` reads `epicMerge`. The skills read the rest — and `install` as well, the one key both a script and a skill read, because the epic worktree's tick re-runs it. Both scripts read the **main checkout's working copy** of the file, never the branch they are acting on, so a change to this config is exercised by no worktree at all until it reaches that copy — not the one that writes it, and not any cut after it either, which on a multi-slice arc is the rest of the arc: [`skills/execute/references/worktrees-and-branches.md`](../skills/execute/references/worktrees-and-branches.md) carries why neither pushing the branch nor cutting a second worktree gets round it, which merge ends the window, and how to verify such a change in the meantime.

```json
{
  "envFiles": ["app/.env.local", "worker/.dev.vars"],
  "install": "pnpm install --frozen-lockfile",
  "gate": "pnpm gate",
  "scopedCheck": "pnpm check",
  "enqueue": "pnpm gate:enqueue",
  "drain": "pnpm gate:drain",
  "format": "pnpm format",
  "upstreamFindings": false,
  "epicMerge": "merge",
  "sharedResources": [
    { "resource": "the Postgres database the suite migrates", "isolatedBy": "tests/bootstrap derives a database name from `git rev-parse --path-format=absolute --show-toplevel`, and marks the database with that same path" }
  ],
  "reclaim": { "report": "pnpm worktree:reclaim", "drop": "pnpm worktree:reclaim --drop" },
  "env": { "TURBO_CACHE_DIR": "${TURBO_CACHE_DIR:-$HOME/.cache/my-turbo}" },
  "frameworkSkills": [{ "skill": "solid", "when": "SolidJS UI" }],
  "briefConventions": "Match surrounding style. Never rebase, never self-merge."
}
```

| Key | Read by | Meaning |
|---|---|---|
| `envFiles` | script | Gitignored files symlinked from the main checkout into each worktree |
| `install` | script + skills | Run inside a new worktree — worktrees never share `node_modules` — and re-run on every tick in the epic worktree, the one tree whose dependencies can go stale under it. Omit it, and `envFiles`, for a zero-dependency repo: a guessed install command fails every worktree setup |
| `env` | script | Exported before the install; most usefully a shared build-cache dir |
| `gate` | skills | The authoritative check before merge. With a queue, the *runner* runs it, never an implementer. May equal `scopedCheck` when the repo has only one tier |
| `scopedCheck` | skills | The cheap bar an implementer's commits are held to |
| `sharedResources` | skills | What the checks touch **outside** the worktree and how each worktree gets its own — `{resource, isolatedBy}` entries, `isolatedBy: null` for one that stays shared. Write `[]` when there is nothing: here alone, omitting the key and declaring it empty mean opposite things. See the `sharedResources` note |
| `reclaim` | skills | `{report, drop}` — the project's own sweep for resources whose worktree is gone, run by a dispatcher at arc close-out. **Omit both** where nothing durable is created; unlike `sharedResources`, that absence is derived from the entries above rather than an unasked question. See the `sharedResources` note |
| `enqueue` / `drain` | skills | How a **gate** joins the queue — a PR's, or a dispatcher's own integration gate on a merged tree that has no PR — and how a dispatcher drains it. **Omit both** if the project has no queue — every gate is then run by hand, the implementer's included. A project that *has* one still hand-runs the dispatcher's mid-arc integration gate where its runner predates the PR-less ticket and refuses it |
| `format` | skills | The auto-formatter in *write* mode, run right before committing |
| `upstreamFindings` | skills | `true` lets an arc's close-out file a **pipeline** finding against this plugin's own **public** repository — as a new issue, or as a comment on one already describing that failure. Absent, `false`, or anything that is not exactly `true` means **no** — a decided answer, and the opposite reading of absence to `sharedResources`. Moot in the plugin's own repository, where the target and the tree are one. See [Filing findings upstream](filing-findings-upstream.md#filing-findings-upstream-off-by-default) |
| `frameworkSkills` | skills | `{skill, when}` pairs — the skill each area opens with |
| `briefConventions` | skills | Conventions baked into every dispatched implementer brief |
| `epicMerge` | `merge-pr.sh` + `.ps1` | `"merge"` (the default) or `"squash"` — whether an epic branch collapses to one commit when it merges back into the integration branch. Omitting it means `"merge"`; see the `epicMerge` note before setting it |

See [`examples/worktree.json`](../examples/worktree.json) for a complete file.

**`sharedResources` is a value no file in your repo can tell you, and the one key whose absence is not the safe reading.** A worktree gets its own checkout, its own branch and its own `node_modules` — and still reaches the same database, the same Redis, the same cache directory, the same port as every other worktree on the machine. That key is where a project says which of those its checks touch and what gives each worktree its own; `/pipeline:setup` **asks** for it, because it cannot be derived from a lockfile or a CI file, and then **falsifies** the answer by cutting two worktrees and gating both at once. It is a declaration, not a mechanism: the plugin never provisions anything and never calls a project's isolation code, because that code has to sit at an entry point *every* invocation reaches — the test bootstrap — and a hook the plugin called would isolate only the runs it launched, while the flow routinely has an implementer run a single test file directly. Two consequences worth knowing before you fill it in. An entry with `"isolatedBy": null` says the resource stays shared, which means this project's checks are **not** parallel-safe and a wave has to be narrowed or sequenced. And a mechanism that derives a per-worktree name from the worktree's own absolute path — the only thing already unique per tree — creates resources that **outlive the tree**: they are named after a path rather than a branch, so a dead worktree's is indistinguishable *by name* from a live one's, and `remove-worktree` drops nothing it created. `reclaim` is what owns that cleanup, and it puts one requirement back on the mechanism: as it creates each resource it must **mark** it with the worktree's absolute path — a `COMMENT ON DATABASE`, a key in the keyspace, a file in the directory — taken from `git rev-parse --path-format=absolute --show-toplevel` and never from `$PWD`, which spells a symlinked entry differently and hands one worktree two databases. The mark is the only thing that ever attributes a resource back to a worktree; an unmarked one is never dropped, and never found either.

**`upstreamFindings` is the key that lets a finding leave your repository, which is why it is disclosed at the top rather than only here.** [Filing findings upstream](filing-findings-upstream.md#filing-findings-upstream-off-by-default) is the full statement — what a finding may and may not contain, why enabling it is consent to file and never consent to disclose, and why the close-out says out loud when it has filed. **And *leave* is the operative word**, which is why the key has nothing to decide in the plugin's own repository: there the resolved target and the tree are the same repository, so an arc files without it — a case that can only ever arise here, and never in a project that installed the plugin. Two things belong beside the key itself. It is read only by the skills, never by a helper, so nothing in `bin/` behaves differently either way. And its **absence** is a deliberate reading rather than a shrug, the opposite one to `sharedResources`: there the unsafe direction is assuming a hazard away, so a missing key means the question was never put; here the unsafe direction is acting, so a missing key is a no. [`skills/orchestrate/SKILL.md`](../skills/orchestrate/SKILL.md) → §7 is where the close-out rule itself lives.

**`integrationBranch` is the one fact no repository states about itself.** It names the branch this project's work lands on — `main` where that is also the default branch, the live `release/x.y.z` where work lands on a release branch, `develop` under gitflow. **Nothing derives it**: a repository's DEFAULT branch is a different fact that coincides in some projects and not in others, and reading either off the other is wrong in whichever direction it is tried — a local ref recording the default can also be stale, so the inference fails without erroring. A project that moves this branch restates it in the same change that cuts the new one, which is one reviewed line and the reason it is a literal name rather than a pattern: a pattern has to be resolved, and resolving is guessing again. **Absence is answered, not ignored**: `merge-pr` keeps its older squash test exactly. The skills' fallback did change — they now take the branch the main checkout is standing on **and say that they inferred it**, where 4.9.x looked for a `release/*` branch first — so a project that declares nothing and parks its main checkout away from where work lands resolves a different branch than it did. Reported rather than silent, which is the argument for declaring.

**`epicMerge` reaches exactly one merge, and without `integrationBranch` declared it does not reach it wherever work lands on the default branch.** It governs an epic branch's own collapse back into the integration branch — the branch is scaffolding, cut for one arc and deleted at its end, so a project may prefer one commit per arc to N slice merges plus a merge commit. Every other merge in the flow stays a real merge commit with no opt-out. Even under `"squash"` two conditions must both hold, and one is the reason to read the rule before setting the key: **the head branch must not be the integration branch**, which is what the declaration establishes. Undeclared, the helper falls back to asking whether the PR's *base* is the repository's default branch — a proxy that holds only where the two branches differ — so an undeclared project whose work lands on its default branch gets no squash at the genuine epic boundary, and the behaviour is otherwise indistinguishable from the option being broken. Both ports compare the key, the value and the branch names case-sensitively, so `"Squash"` and `"EpicMerge"` mean `merge` in bash and PowerShell alike. The other condition, why every unanswerable question falls back to `merge`, and the trade the option makes are all in [`skills/execute/references/worktrees-and-branches.md`](../skills/execute/references/worktrees-and-branches.md) → *Mechanics*.

**Why it lives in the repo.** It travels with the clone, works under any checkout directory name, and is reviewed in the same PR as the change that alters it. Keying it to a directory name instead — the old design — meant a repo cloned to a different folder silently got no config, and the helper would cut a bare worktree with no env and no `node_modules` while only warning on stderr.

⚠️ **A shared cache var has to be set somewhere non-interactive shells read.** The config's `env` covers the install step, but the gate runner, the drain, and dispatched agents run in **non-interactive** shells — so a var set only where an interactive shell reads it reaches your terminal and nothing else, and the cache silently never applies to a gated PR.

| Shell | Set it in | NOT in |
|---|---|---|
| zsh (macOS default) | `~/.zshenv` | `~/.zshrc` — interactive only |
| bash | `~/.bashrc` **and** point `BASH_ENV` at it, since that is the only file a non-interactive bash reads | `~/.bash_profile` — login shells only |
| PowerShell / Windows | a **persisted user environment variable**: `setx VAR value` once, or System Properties → Environment Variables | `$PROFILE` — interactive only, so it is the exact same trap as `~/.zshrc`, and there is no Windows file that behaves like `~/.zshenv` |

A persisted Windows environment variable is inherited by every process started afterwards regardless of shell, so it also covers Git Bash — which is why it, and not a dotfile, is the Windows answer.
