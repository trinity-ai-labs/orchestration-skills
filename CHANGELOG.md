# Changelog

Versions are the `version` field in `.claude-plugin/plugin.json`. Because that field is set, an installed plugin only picks up changes when it **changes** — pushing to `main` alone ships nothing. CI enforces the bump.

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
