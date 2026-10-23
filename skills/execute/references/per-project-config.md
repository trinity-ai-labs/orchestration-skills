# Per-project config

Reference for `skills/execute/SKILL.md`. **Read the project's config before you cut a worktree, write a brief,
or run a project's gate** — `cat <repo>/.agents/worktree.json`, since every value in it is per-repo and
nothing derives it from the tree you are standing in.

**What each key MEANS, and what its absence means, is `skills/procedures/config-keys.md`.** This file carries
what an implementer reads before its first edit; what a DISPATCH does about the rest is
`skills/execute/references/dispatcher.md`, *The project's config*.

## The reading that changes your build

- **`targetedTest` declared** → an implementer's one targeted test run is that template with its one of
  `{files}` or `{names}` filled; **absent** → it is single test files, each run singly, never a suite.

## Go through the task-runner, never around it

A shared cache only helps commands that invoke the runner (turbo/nx/bazel): `preflight` and `gate` do, and
`fullGate` where declared. The binary called **directly** — `vitest`, `tsc`, `eslint` — or a script shelling
straight to it **bypasses the cache and always runs cold**, locally and in the drained gate. So route every
whole-package or whole-suite run that is *supposed to happen* — the drained gate, an integration gate, an
in-line slice's gate — through the cached command (`turbo run <task> --filter=<pkg>`, or the project's
`preflight`), and say so in briefs and in the project's agent guidance. **A `fullGate` run and the tip audit
go through the runner too**, in its no-cache form (`turbo run <task> --force`), never around it to the raw
binary. Routing, not permission:
for a queue-mode implementer those runs are banned outright (`skills/execute/references/implementer-queue.md`).
Reserve a direct-binary run for one targeted test run — the project's `targetedTest` where declared, else
single test files, each run singly; guidance documenting the raw form as a package default is a leak to fix.
