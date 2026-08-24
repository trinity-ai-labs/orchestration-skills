---
name: write-issue
description: >-
  Turn an idea or a rough plan into a clean, grounded, forward-facing GitHub issue (or an umbrella +
  sub-issues) that feeds /pipeline:decompose. The FIRST leg of the write-issue → decompose → orchestrate pipeline.
  Use whenever you're asked to WRITE UP / FILE / OPEN an issue, capture a plan as an issue, or turn a
  design discussion into trackable work. You GROUND the plan in the real codebase (real file:line
  targets, verified against the code — never guesses or half-remembered claims), then write the issue as
  a PLAN TO EXECUTE — goal, approach, concrete targets, type/interface sketch, phases, verify — stripped
  of exploration narrative and history. You do NOT slice into orchestration waves with do-not-touch
  boundaries and model tiers (that's /pipeline:decompose), write code, or dispatch (that's /pipeline:orchestrate). This
  skill is project-agnostic — it reads each repo's own AGENTS.md / conventions rather than hardcoding one
  project. For large multi-area work you write an umbrella + one sub-issue per slice; otherwise a single
  issue. Ends with the handoff to /pipeline:decompose.
argument-hint: "[the idea or plan to write up — omit to write up the plan already in chat]"
---

# write-issue — author the issue that feeds the pipeline

The dev pipeline is **`/pipeline:write-issue` → `/pipeline:decompose` → `/pipeline:orchestrate`**: write the issue, slice it into parallel waves, execute it in worktrees. This skill owns the first leg — turning an idea or a design discussion into a **clean, grounded, forward-facing issue** the other two can consume without re-deriving the plan.

```
idea / plan  ──/pipeline:write-issue──▶  a grounded, forward-facing issue  ──/pipeline:decompose──▶  slices + waves  ──/pipeline:orchestrate──▶  worktrees · PRs · merges
```

`write-issue` produces the **plan**; `decompose` turns it into orchestration-ready **slices**; `orchestrate` **runs** them. This skill never writes code, makes worktrees, or dispatches — it produces the issue the rest of the pipeline executes.

It is **project-agnostic**. Like `decompose`/`orchestrate`, it reads each repo's own conventions (`AGENTS.md`, per-project config) rather than hardcoding a stack. Nothing below assumes a particular project.

---

## The one rule that defines a good issue: forward-facing, not archeological

**The issue states the plan to execute — never how you figured it out.** An issue is read by an implementer (human or `/pipeline:decompose`) who needs *what we're going to do*, not the journey to it. Exploration narrative, discovery history, and corrections-to-earlier-analysis are noise that buries the actionable spec.

- **KEEP** — the goal, the approach, concrete `file:line` targets (the to-do list), a type/interface sketch where it clarifies, the phases/waves, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X", "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- If a correction to earlier understanding matters, **bake the correct fact silently into the plan** — don't narrate the correction. The reader doesn't need the plot twist; they need the right target.

A body that reads like a lab notebook is a bug. A body that reads like a build order is the goal.

---

## A follow-up from a live run is a first-class input

Most issues start as an idea. Many start instead as **something a run surfaced and did not land** — residual cleanup, a doc a change made stale, a second call site, a missing test, a rename left half-done. `/pipeline:orchestrate` requires both roles to *file* those rather than list them in a hand-back, so this skill is where they arrive, and they are written exactly like any other issue: grounded, forward-facing, real `file:line` targets. Two things are additional.

- **Link it to what produced it.** `Follows #<N>` for the issue whose work surfaced it, or `Part of #<umbrella>` when that work is a sub-issue of an umbrella — and in the umbrella case, add it to the umbrella's `- [ ] #<sub>` checklist the same way Step 4 links any sub-issue. *The failure this prevents: an unlinked follow-up is indistinguishable from a fresh idea, so whoever picks it up has to reconstruct the slice, the PR and the decision that created the residue before they can size it — and the umbrella it belongs to closes looking complete while its leftovers sit untracked beside it.*
- **Name what surfaced it, in one line, as a fact about the plan** — "the <thing> migration in #<N> moved <producer> and left <consumer> on the old path". That is a **target**, not archeology: it says where the residue is and why it is there. How the run went, what was tried first, and who noticed still go in the bin, per the rule above.

The linking convention is also what makes a follow-up placeable by `/pipeline:decompose` and `/pipeline:orchestrate`: an issue that says which arc it belongs to can be folded into that arc's wave plan — and while the arc has an **epic branch** live, onto that branch — instead of being scheduled as unrelated work.

---

## Step 1 — Ground it in the real code (this is what makes the targets trustworthy)

An issue written from the idea alone names files that don't exist and misstates the coupling. **Ground every target before you write it.** This grounding is the single biggest lever on how well `/pipeline:decompose` and the implementer do — real paths, real consumers, real boundaries.

- **Spawn read-only `Explore` agents** (in parallel, one per subsystem the plan touches) to find the actual files, the patterns to copy, and the consumers a change ripples into. You want real `file:line` before you assert a target.
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep (searching only `src/` when the thing lives under `server/`, say) produces confident-but-wrong claims ("that function doesn't exist") that poison the plan. When a claim is load-bearing — "X is/isn't a consumer", "this function doesn't exist", "only one call site" — verify it against the actual code across the whole tree, and cite the def line. Cross-check anything that surprises you; two sources disagreeing means you go read the file, not pick one.
- **Read `AGENTS.md` / the per-project config** for the conventions the issue should respect (framework skills, compat policy, comment style, the gate) — so the plan inherits them and `/pipeline:decompose` doesn't have to re-discover them.

If grounding surfaces that the idea is under-specified — a missing behavior, an open design fork, an unstated constraint — resolve what you can from the code/conventions and **state the assumption in the issue**; escalate only the genuine product/design forks the codebase can't settle, one at a time, in plain conversation.

---

## Step 2 — Structure the body (the shape decompose + implementers consume best)

Write the body in this order. Not every issue needs every section — small issues collapse to goal + targets + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions (not options you're weighing). If there's a key structural choice, state it and move on.
- **Targets** — the concrete `file:line` list the work touches, as the to-do list. This is the grounded core; it's what makes the issue actionable. Group by area.
- **Type / interface sketch** — a short code block for a new type, API shape, or contract, when it clarifies the plan. Real names.
- **Phases / waves** — if the work has a clear dependency order (foundational thing first, consumers after), name the phases at a high level, and at **each boundary between them state whether the branch is independently shippable there** — plus any breaking foundational change (a required field, a NOT-NULL swap, a renamed export) every later phase must follow. That fact is a property of the plan you just designed rather than of the code as it stands, so nothing downstream can read it back out of the tree; left out, it defaults to "shippable", because an unasked question reads as a no. *The failure this prevents: a foundational phase lands on the shared integration branch and sits there half-migrated — green at every step, and forked from by every other session — because the plan never said the states in between were ones you would not ship.* Leave the *detailed* slicing (do-not-touch boundaries, model tiers, conflict map) to `/pipeline:decompose` — don't pre-empt it; just give the shape.
- **Seams** — name any **producer → consumer** shape this plan introduces or changes whose two halves land in different phases: a return type, a schema field, a config key, a prompt variable, a behavior that documentation describes. Write each one as *producer → consumer → the shape between them*. The ones to write down most carefully are the **cross-tree** seams — code ↔ docs, code ↔ prompt, code ↔ config — where the halves sit in different languages or different trees and nothing mechanical links them, so each half is correct on its own and only the pair is wrong. *The failure this prevents: an unnamed seam is invisible to a file-based conflict map (the halves share no file), invisible to each half's own checks, and invisible to every later reader — and the author who designed the change is the last person who can still see it without rediscovering it.*
- **Verify** — what "done" looks like: the behavior, the tests, the gate/check that must pass, the greps that must come back empty. A checkable bar, not a vibe.
- **Constraints** — the project conventions that bind it (from `AGENTS.md`): compat policy (e.g. forward-only/no-shims where that's the house rule), comment style, etc.

Keep every section in the *forward-facing* register from the rule above.

---

## What `/pipeline:decompose` does with this

The next leg reads this issue and makes **two path decisions** off it. Neither is yours to make — but both are only as good as the facts above, so write the body knowing what they feed.

- **Output path — a comment, or an umbrella + sub-issues.** `/pipeline:decompose` posts its breakdown as a comment on the issue by default, and converts the issue into an umbrella with one sub-issue per slice when the work is large **and** multi-area **and** each slice is a PR someone would want to track on its own. Your **phases**, your **targets grouped by area**, and your **verify bar** are what that reads from — they say how many waves there are, how many areas they span, and whether a piece closes on its own.
- **Epic-branch path — the integration branch, or an epic branch cut from it.** Two rules reach for an epic branch and they answer different questions: **does any intermediate state leave the integration branch in a condition you would not ship?**, and — independently of that — whether the slices will be **dispatched in parallel**, since multi-slice work fanned out concurrently defaults to converging on an epic branch rather than on the shared one. Single-slice work never cuts one, and neither rule is a slice count or a busy integration branch. `/pipeline:decompose` answers both in one line every time — the first from your per-boundary **shippability** statements and your **seam** list, the second from the slice shape it derives. Read `/pipeline:decompose` for the rules in full and what the branch costs; this issue's job is to make the first one answerable.

**You supply the evidence; `/pipeline:decompose` returns the verdict.** Write the facts into the body — the phase shape, where the branch is shippable and where it is not, which seams the plan creates — and stop there. *The failure this prevents: an issue that states a conclusion instead of its inputs hands the grounding pass an answer it can no longer check, and leaves the facts behind that answer unwritten anywhere.*

---

## Step 3 — Single issue vs umbrella + sub-issues

- **Single issue** (the default) — small-to-medium work, a handful of related changes, one release effort. One body, filed; `/pipeline:decompose` reads it and posts its breakdown as a comment or fans out then.
- **Umbrella + sub-issues** — large AND multi-area AND each piece is a PR someone would want to track/close on its own. Write the umbrella as the overview (goal, the phase/wave shape, a tracked `- [ ] #<sub>` checklist) and one sub-issue per slice (or tightly-coupled cluster), each a self-contained forward-facing spec. Prefix sub-issue titles with their wave (`[W0]`, `[W1]`) so the order is visible.
- Don't reflexively shard — an umbrella for 2 small slices is tracking overhead with no payoff. Warrant it on the same test `/pipeline:decompose` applies: **multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**
- **An umbrella is not an epic branch, and filing one settles nothing about the other.** The two are orthogonal: an umbrella is a *tracking shape* — how the work is written down, assigned, and closed — while an epic branch is a *branch lifecycle*, where the slices fork from and PR into. Either can exist without the other, and `/pipeline:decompose` decides the branch on its own two rules, never from how the issue was filed. *The failure this prevents: "epic" names both things, so an author who reads it as one concludes that filing an umbrella already answered the branch question — and the facts that would actually answer it never get written.*

You may author the umbrella + subs directly, or hand a single issue to `/pipeline:decompose` and let *it* convert to an umbrella when the work proves large enough — both are fine; pick based on whether you already know the slice shape.

---

## Step 4 — Write it (GitHub mechanics)

- **Use `gh api` (REST), not `gh issue create`/`edit`.** The high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't.
- **Write the body to a file and reference it with `-F` (not `-f`).** `-f body=@file` silently stores the literal string `@file`; `-F body=@file` reads the file. **Verify after** — refetch the body and confirm it's the markdown, not `@path`.
  - Create: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>" -F "milestone=<n>" --jq '.number'`
  - Edit body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"`
- **Milestone** takes a number, not a title — resolve it first (`gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number)\t\(.title)"'`) and pass `-F "milestone=<n>"`.
- **Umbrella linking**: create the subs, capture their numbers, then PATCH the umbrella body with the `- [ ] #<sub>` checklist. Each sub references the umbrella (`Part of #<umbrella>`).
- **Follow-up linking**: a follow-up filed out of a live run carries `Follows #<N>` — or `Part of #<umbrella>` when the originating work sits under one, in which case PATCH the umbrella body to add it to the checklist as well. An umbrella whose checklist is complete while its follow-ups sit outside it reads as finished work that is not.
- **Labels**: apply an existing `epic`/`umbrella` label if the repo has one; don't invent exotic labels. That label names the **tracking shape** and nothing else — it is not a branch decision, and `/pipeline:decompose` still answers the epic-branch question on its own two rules. *The failure this prevents: the label reads as the verdict it shares a word with, and an umbrella filed under it looks like a branch already chosen.*

After writing, tell the user what you filed (issue #, or umbrella # + sub #s) and end with the handoff.

---

## Handoff

End with, verbatim intent:

> **Ready to decompose.** Hand this to `/pipeline:decompose` (e.g. `/pipeline:decompose #<N>`), which grounds it into parallel slices + waves; then `/pipeline:orchestrate` cuts a worktree per slice and merges.

Then **stop.** Don't slice into waves-with-boundaries, make worktrees, or write code — the next legs own those.

---

## What write-issue does NOT do (hard boundaries)

- **No slicing into orchestration units.** You give the *shape* (phases); `/pipeline:decompose` produces the slices with owned files, do-not-touch boundaries, model tiers, and the conflict map. Don't do its job in the issue body.
- **No branch verdict — state the facts instead.** Write where the branch is shippable between phases and which seams the plan creates, and never write "use an epic branch" (or "no epic branch needed") into an issue body: that is `/pipeline:decompose`'s one-line answer to make, on your evidence plus the code it grounds against. *The failure this prevents: a verdict in the body reads as settled to everyone downstream, though it was reached without the grounding pass that is supposed to reach it — and it displaces the facts that would let anyone re-check it.*
- **No code, no worktrees, no dispatch, no merge.** You author an issue. `/pipeline:orchestrate` executes. (You *do* spawn read-only `Explore`/research agents in Step 1 — that's grounding, not building.)
- **No archeology.** See the rule at the top. If you catch yourself narrating how you discovered a fact, cut it and keep the fact.
- **Hand off, then stop.** Your turn ends at the filed issue + the handoff line.

**Why this shape:** the pipeline is only as good as its first artifact. A vague or archeological issue forces `/pipeline:decompose` to re-ground and re-interpret, and an implementer to guess. A grounded, forward-facing issue — real targets, stated decisions, a checkable verify — is a plan the rest of the pipeline executes instead of reverse-engineering.
