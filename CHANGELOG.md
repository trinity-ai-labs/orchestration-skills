# Changelog

Versions are the `version` field in `.claude-plugin/plugin.json`. Because that field is set, an installed plugin only picks up changes when it **changes** — pushing to `main` alone ships nothing. CI enforces the bump.

## 1.3.0

- **Contract closure.** A cross-repo contract now declares its `owner` and `consumers`, and a task that includes the owner automatically includes them. A repo whose generated types live in three other repos cannot be changed alone — excluding a consumer while the owner is in the task is refused outright rather than producing a task that can neither update nor verify the other side.
- `--dry-run` prints the resolved member set without cutting anything, so an orchestrator can see a task's real surface — including repos pulled in by closure — before paying for the installs.

## 1.2.0

- **Polyrepo workspaces.** A containing folder of sibling repos can declare `.agents/workspace.json`, and `setup-workspace.sh <branch> [repo…]` cuts one worktree per member into `~/.worktrees/<workspace>/<leaf>/<repo>` — the workspace's own layout, so cross-repo paths still resolve and both stacks run side by side. Members are selectable by name, by `--exclude`, or by a manifest `"default": false` for the repo a workspace rarely touches with the others.
- Worktrees for a repo inside a workspace are namespaced under it. Bare polyrepo names — `api`, `client`, `admin` — collide across unrelated projects in a flat `~/.worktrees`.
- Fixed: `setup-worktree.sh` created its directory from the old flat path, leaving stray empty dirs when the real destination was elsewhere.

## 1.1.0

- The marketplace now carries a second plugin, [`frameworks`](https://github.com/trinity-ai-labs/framework-skills) — the Effect v3 and SolidJS reference skills, previously two repos behind shell installers.
- `orchestrate` and `decompose` name those skills by their namespaced ids (`frameworks:effect-v3`, `frameworks:solid`), since plugin skills are always namespaced and the bare names no longer resolve.

## 1.0.1

- Marketplace install documented as the primary path; the skills-directory clone demoted to a development convenience.
- `CHANGELOG.md`, plus a CI job that fails when plugin content changes without a version bump.

## 1.0.0

First release as a Claude Code plugin.

- **Four skills** — `setup`, `write-issue`, `decompose`, `orchestrate`, namespaced `/pipeline:*`.
- **`bin/` on PATH** — `setup-worktree.sh`, `merge-pr.sh`, `remove-worktree.sh` are bare commands while the plugin is enabled, replacing the old `install.sh` symlink dance.
- **Per-project config moved into each repo** at `.agents/worktree.json`, declarative rather than sourced bash. The previous location keyed config to a checkout's *directory name*, which had already forced a duplicate config file for one repo cloned under two names.
- **`setup` skill** — onboards a repo by grounding its real lockfile, scripts, and CI, then scaffolds a durable gate queue into that repo if it wants one. The plugin carries the knowledge; the project owns the code.
- **Tiering** — a repo may want no flow at all, worktrees plus a single check, or the full gate-and-queue. `gate` == `scopedCheck` is a valid answer, and absent `enqueue`/`drain` means the implementer gates in-line.
