---
name: write-issue
description: >-
  Turn an idea or a rough plan into a clean, grounded, forward-facing GitHub issue (or an umbrella +
  sub-issues) that feeds /decompose. The FIRST leg of the write-issue → decompose → orchestrate pipeline.
  Use whenever you're asked to WRITE UP / FILE / OPEN an issue, capture a plan as an issue, or turn a
  design discussion into trackable work. You GROUND the plan in the real codebase (real file:line
  targets, verified against the code — never guesses or half-remembered claims), then write the issue as
  a PLAN TO EXECUTE — goal, approach, concrete targets, type/interface sketch, phases, verify — stripped
  of exploration narrative and history. You do NOT slice into orchestration waves with do-not-touch
  boundaries and model tiers (that's /decompose), write code, or dispatch (that's /orchestrate). This
  skill is project-agnostic — it reads each repo's own AGENTS.md / conventions rather than hardcoding one
  project. For large multi-area work you write an umbrella + one sub-issue per slice; otherwise a single
  issue. Ends with the handoff to /decompose.
---

# write-issue — author the issue that feeds the pipeline

The dev pipeline is **`/write-issue` → `/decompose` → `/orchestrate`**: write the issue, slice it into parallel waves, execute it in worktrees. This skill owns the first leg — turning an idea or a design discussion into a **clean, grounded, forward-facing issue** the other two can consume without re-deriving the plan.

```
idea / plan  ──/write-issue──▶  a grounded, forward-facing issue  ──/decompose──▶  slices + waves  ──/orchestrate──▶  worktrees · PRs · merges
```

`write-issue` produces the **plan**; `decompose` turns it into orchestration-ready **slices**; `orchestrate` **runs** them. This skill never writes code, makes worktrees, or dispatches — it produces the issue the rest of the pipeline executes.

It is **project-agnostic**. Like `decompose`/`orchestrate`, it reads each repo's own conventions (`AGENTS.md`, per-project config) rather than hardcoding a stack. Nothing below assumes a particular project.

---

## The one rule that defines a good issue: forward-facing, not archeological

**The issue states the plan to execute — never how you figured it out.** An issue is read by an implementer (human or `/decompose`) who needs *what we're going to do*, not the journey to it. Exploration narrative, discovery history, and corrections-to-earlier-analysis are noise that buries the actionable spec.

- **KEEP** — the goal, the approach, concrete `file:line` targets (the to-do list), a type/interface sketch where it clarifies, the phases/waves, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X", "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- If a correction to earlier understanding matters, **bake the correct fact silently into the plan** — don't narrate the correction. The reader doesn't need the plot twist; they need the right target.

A body that reads like a lab notebook is a bug. A body that reads like a build order is the goal.

---

## Step 1 — Ground it in the real code (this is what makes the targets trustworthy)

An issue written from the idea alone names files that don't exist and misstates the coupling. **Ground every target before you write it.** This grounding is the single biggest lever on how well `/decompose` and the implementer do — real paths, real consumers, real boundaries.

- **Spawn read-only `Explore` agents** (in parallel, one per subsystem the plan touches) to find the actual files, the patterns to copy, and the consumers a change ripples into. You want real `file:line` before you assert a target.
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep (searching only `src/` when the thing lives under `server/`, say) produces confident-but-wrong claims ("that function doesn't exist") that poison the plan. When a claim is load-bearing — "X is/isn't a consumer", "this function doesn't exist", "only one call site" — verify it against the actual code across the whole tree, and cite the def line. Cross-check anything that surprises you; two sources disagreeing means you go read the file, not pick one.
- **Read `AGENTS.md` / the per-project config** for the conventions the issue should respect (framework skills, compat policy, comment style, the gate) — so the plan inherits them and `/decompose` doesn't have to re-discover them.

If grounding surfaces that the idea is under-specified — a missing behavior, an open design fork, an unstated constraint — resolve what you can from the code/conventions and **state the assumption in the issue**; escalate only the genuine product/design forks the codebase can't settle, one at a time, in plain conversation.

---

## Step 2 — Structure the body (the shape decompose + implementers consume best)

Write the body in this order. Not every issue needs every section — small issues collapse to goal + targets + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions (not options you're weighing). If there's a key structural choice, state it and move on.
- **Targets** — the concrete `file:line` list the work touches, as the to-do list. This is the grounded core; it's what makes the issue actionable. Group by area.
- **Type / interface sketch** — a short code block for a new type, API shape, or contract, when it clarifies the plan. Real names.
- **Phases / waves** — if the work has a clear dependency order (foundational thing first, consumers after), name the phases at a high level. Leave the *detailed* slicing (do-not-touch boundaries, model tiers, conflict map) to `/decompose` — don't pre-empt it; just give the shape.
- **Verify** — what "done" looks like: the behavior, the tests, the gate/check that must pass, the greps that must come back empty. A checkable bar, not a vibe.
- **Constraints** — the project conventions that bind it (from `AGENTS.md`): compat policy (e.g. forward-only/no-shims where that's the house rule), comment style, etc.

Keep every section in the *forward-facing* register from the rule above.

---

## Step 3 — Single issue vs umbrella + sub-issues

- **Single issue** (the default) — small-to-medium work, a handful of related changes, one release effort. One body, filed; `/decompose` reads it and posts its breakdown as a comment or fans out then.
- **Umbrella + sub-issues** — large AND multi-area AND each piece is a PR someone would want to track/close on its own. Write the umbrella as the overview (goal, the phase/wave shape, a tracked `- [ ] #<sub>` checklist) and one sub-issue per slice (or tightly-coupled cluster), each a self-contained forward-facing spec. Prefix sub-issue titles with their wave (`[W0]`, `[W1]`) so the order is visible.
- Don't reflexively shard — an umbrella for 2 small slices is tracking overhead with no payoff. Warrant it: multiple waves AND multiple areas AND independently-trackable PRs.

You may author the umbrella + subs directly, or hand a single issue to `/decompose` and let *it* convert to an umbrella when the work proves large enough — both are fine; pick based on whether you already know the slice shape.

---

## Step 4 — Write it (GitHub mechanics)

- **Use `gh api` (REST), not `gh issue create`/`edit`.** The high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't.
- **Write the body to a file and reference it with `-F` (not `-f`).** `-f body=@file` silently stores the literal string `@file`; `-F body=@file` reads the file. **Verify after** — refetch the body and confirm it's the markdown, not `@path`.
  - Create: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>" -F "milestone=<n>" --jq '.number'`
  - Edit body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"`
- **Milestone** takes a number, not a title — resolve it first (`gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number)\t\(.title)"'`) and pass `-F "milestone=<n>"`.
- **Umbrella linking**: create the subs, capture their numbers, then PATCH the umbrella body with the `- [ ] #<sub>` checklist. Each sub references the umbrella (`Part of #<umbrella>`).
- **Labels**: apply an existing `epic`/`umbrella` label if the repo has one; don't invent exotic labels.

After writing, tell the user what you filed (issue #, or umbrella # + sub #s) and end with the handoff.

---

## Handoff

End with, verbatim intent:

> **Ready to decompose.** Hand this to `/decompose` (e.g. `/decompose #<N>`), which grounds it into parallel slices + waves; then `/orchestrate` cuts a worktree per slice and merges.

Then **stop.** Don't slice into waves-with-boundaries, make worktrees, or write code — the next legs own those.

---

## What write-issue does NOT do (hard boundaries)

- **No slicing into orchestration units.** You give the *shape* (phases); `/decompose` produces the slices with owned files, do-not-touch boundaries, model tiers, and the conflict map. Don't do its job in the issue body.
- **No code, no worktrees, no dispatch, no merge.** You author an issue. `/orchestrate` executes. (You *do* spawn read-only `Explore`/research agents in Step 1 — that's grounding, not building.)
- **No archeology.** See the rule at the top. If you catch yourself narrating how you discovered a fact, cut it and keep the fact.
- **Hand off, then stop.** Your turn ends at the filed issue + the handoff line.

**Why this shape:** the pipeline is only as good as its first artifact. A vague or archeological issue forces `/decompose` to re-ground and re-interpret, and an implementer to guess. A grounded, forward-facing issue — real targets, stated decisions, a checkable verify — is a plan the rest of the pipeline executes instead of reverse-engineering.
