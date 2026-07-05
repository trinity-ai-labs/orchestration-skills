# write-issue

A Claude Code skill that turns an **idea or a rough plan** into a **clean, grounded, forward-facing GitHub issue** (or an umbrella + sub-issues) — the first leg of the [`/write-issue`](https://github.com/trinity-ai-labs/write-issue) → [`/decompose`](https://github.com/trinity-ai-labs/decompose) → [`/orchestrate`](https://github.com/trinity-ai-labs/worktree-orchestrate) pipeline.

`write-issue` produces the **plan**; `decompose` turns it into orchestration-ready **slices**; `orchestrate` **executes** them. This skill never writes code, makes worktrees, or dispatches — it produces the issue the rest of the pipeline runs.

```
idea / plan  ──/write-issue──▶  grounded, forward-facing issue  ──/decompose──▶  slices + waves  ──/orchestrate──▶  worktrees · PRs · merges
```

It is **project-agnostic** — like its siblings, it reads each repo's own `AGENTS.md` / conventions rather than hardcoding a stack.

---

## The one rule that defines a good issue

**Forward-facing, not archeological.** An issue states the plan to execute — never how you figured it out. It's read by an implementer (or `/decompose`) who needs *what we're going to do*, not the journey.

- **KEEP** — the goal, the approach, concrete `file:line` targets (the to-do list), a type/interface sketch, phases/waves, the verify bar.
- **STRIP** — exploration narrative, discovery history, "an earlier scan found/was wrong", "verified against the code", "the research said". If a correction matters, bake the *correct fact* in silently; don't narrate the plot twist.

---

## What it does

- **Grounds the plan in the real code** — spawns read-only `Explore` agents and greps the **whole repo** (citing definition lines) so every target is a real `file:line`, not a guess. Load-bearing claims get verified against the code before they're written.
- **Writes the body in the shape the pipeline consumes** — goal → approach → `file:line` targets → type/interface sketch → phases → verify → constraints, all forward-facing.
- **Decides single issue vs umbrella + sub-issues** — a single issue by default; an umbrella with one sub-issue per slice when the work is large AND multi-area AND independently trackable.
- **Files it via `gh api` (REST)** — never the rate-limited `gh issue` GraphQL commands; `-F body=@file` (not `-f`), milestone by number, umbrella `- [ ] #<sub>` checklist.
- **Hands off to `/decompose`** and stops.

## What it does NOT do

Slice into orchestration units with do-not-touch boundaries and model tiers (that's `/decompose`); write code, make worktrees, dispatch, or merge (that's `/orchestrate`). It authors the issue and hands off.

---

## Install

```sh
./install.sh
```

Symlinks `skills/write-issue/` into `~/.claude/skills/write-issue/` and `~/.agents/skills/write-issue/`, so `git pull` in this repo updates your live skill. Pass `--copy` to copy instead.

Then open Claude Code in any repo and use `/write-issue`.
