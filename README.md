# decompose

A Claude Code skill that turns a **plan** into an **orchestration-ready task breakdown** — the prep phase that feeds [`/orchestrate`](https://github.com/trinity-ai-labs/worktree-orchestrate). You hand it a plan (a GitHub issue, or a plan already in the conversation); it grounds the plan in the real codebase and emits independent task **slices** with explicit scope, do-not-touch boundaries, dependency **waves**, the framework skill each slice must invoke, and a model-tier hint — exactly what the orchestrator's dispatch loop consumes.

`decompose` plans; `orchestrate` executes. Decompose **never** writes code, makes worktrees, dispatches implementers, or merges — it produces the plan the orchestrator runs.

```
plan  ──/decompose──▶  grounded slices + waves + conflict map  ──/orchestrate──▶  worktrees · PRs · merges
```

---

## Why a separate prep pass

`/orchestrate` can already slice work on the fly — but it does so mid-flight, without deep grounding, while also juggling worktrees, PR reviews, and merges. `decompose` front-loads the expensive thinking:

- **Grounds in the real code** — spawns read-only `Explore` agents to find the actual files, patterns, and ripple consumers, so slices reference real paths, not guesses.
- **Maximizes safe parallelism** — works out which slices are truly independent, which foundational slice must land first (**wave 0**), and where two slices would fight over the same file (**conflict map**, resolved at merge time).
- **Speaks orchestrate's language** — every slice carries the exact fields the dispatch loop needs: scope, do-not-touch boundaries, depends-on, the framework skill to invoke first (`effect` / `solid` for Trinity), a `sonnet`/`opus` model hint, brief, and verify.

Better decomposition in → more parallelism and fewer wrong-approach restarts out.

---

## What it produces

- **Parallelization plan** — waves (wave 0 = foundational/schema-first; wave 1+ = parallel consumers), the transient-red window callout, a conflict map, and the critical path.
- **One slice per worktree/PR** — title + branch, owned files, do-not-touch boundaries, dependencies, skill-to-invoke-first, model tier, brief, and verify steps.
- A **Ready to orchestrate** handoff line.

### Two input paths

| You invoked… | decompose… |
|---|---|
| `/decompose` with a plan already in chat (or you wrote one in plan mode) | grounds it and emits the breakdown **in chat**, then hands off |
| `/decompose #1042` (a GitHub issue) | reads the issue + comments, grounds it, and **writes the breakdown back to GitHub** |

On the GitHub path it chooses between:

- **Comment** (default) — small-to-medium work: the whole breakdown posted as one comment on the issue.
- **Umbrella + sub-issues** (when warranted) — large multi-area epics: the issue becomes an umbrella with a tracked `- [ ] #N` checklist, and one sub-issue per slice carries its full brief. Writes go through `gh api` (REST), not the GraphQL-backed `gh issue create/edit`, to dodge rate limits.

---

## Prerequisites

> **macOS or Linux** — `install.sh` is portable `bash` (re-runnable; cleanly converts a prior `--copy` install to symlinks). On Windows, run it under WSL.

- **[Claude Code](https://claude.com/claude-code)** — where `/decompose` runs.
- **[GitHub CLI](https://cli.github.com/)** (`gh`) authenticated — only for the GitHub-issue path (read + comment/sub-issue writes).
- **[worktree-orchestrate](https://github.com/trinity-ai-labs/worktree-orchestrate)** — the companion that *executes* the breakdown. Not required to install decompose, but it's the whole point: decompose also reads orchestrate's per-project config (`~/.worktrees/config/<project>.sh`) to learn the gate, framework skills, and brief conventions. With no config, decompose still works — slices just won't carry env/gate specifics.

---

## Install

```bash
git clone git@github.com:trinity-ai-labs/decompose.git
cd decompose
./install.sh
```

`install.sh` **symlinks** the skill into both skill homes (`~/.claude/skills/` and `~/.agents/skills/`), so a later `git pull` in this repo updates your live skill automatically. Use `./install.sh --copy` for independent copies.

Verify:

```bash
ls -la ~/.claude/skills/decompose     # -> .../decompose/skills/decompose
ls -la ~/.agents/skills/decompose     # -> .../decompose/skills/decompose
```

Then in Claude Code, `/decompose` should appear in the skills list.

---

## Usage

### Decompose a GitHub issue

```
/decompose #1042
```

Claude reads the issue and its comments, spawns Explore agents to ground it in the codebase, slices it into independent tasks with waves and a conflict map, and writes the result back to the issue — as a comment, or (if it's a large multi-area epic) by converting it into an umbrella with sub-issues. Then it hands off to `/orchestrate`.

### Decompose an in-chat plan

```
/decompose
```

(after a plan exists in the conversation, e.g. from plan mode). Claude grounds and slices the plan, prints the breakdown in chat, and ends with the **Ready to orchestrate** handoff.

### The handoff

decompose always ends by pointing at the executor:

```
/orchestrate work issue #1042      # GitHub path
orchestrate this plan              # in-chat path
```

`/orchestrate` then cuts a worktree per slice, dispatches implementers wave by wave, reviews each PR's diff, and merges.

---

## Layout of this repo

```
.
├── install.sh                   # symlink (or --copy) the skill into both skill homes
├── README.md
└── skills/decompose/SKILL.md    # the /decompose playbook
```

To change the skill: edit `skills/decompose/SKILL.md`, commit, push. Everyone who installed via symlink picks it up on `git pull`.

---

## See also

- **[worktree-orchestrate](https://github.com/trinity-ai-labs/worktree-orchestrate)** — the executor. decompose plans the work; orchestrate ships it.
