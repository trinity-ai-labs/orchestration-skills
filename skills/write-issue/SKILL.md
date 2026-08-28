---
name: write-issue
description: >-
  Turn an idea or a rough plan into a clean, grounded, forward-facing GitHub issue (or an umbrella +
  sub-issues) that feeds /pipeline:orchestrate. The FIRST of the pipeline's two user-facing legs:
  /pipeline:write-issue → /pipeline:orchestrate. Use whenever you're asked to WRITE UP / FILE / OPEN an
  issue, capture a plan as an issue, or turn a design discussion into trackable work. You GROUND the
  plan in the real codebase — every load-bearing claim verified against the code, never a guess or a
  half-remembered one — then write the issue as a PLAN TO EXECUTE: goal, approach, the surface it lands
  on as real modules and files, type/interface sketch, phases, verify — stripped of exploration
  narrative and history. Grounding is how you establish the plan is TRUE — not a file:line to-do list
  across the whole arc, which decays as earlier phases move what later ones name and which
  /pipeline:decompose re-derives at the horizon anyway. You do NOT
  slice into dispatchable waves with do-not-touch boundaries and model tiers, run the arc, or dispatch
  anything: /pipeline:orchestrate owns the loop that does, grounding each increment through
  /pipeline:decompose and shipping it through /pipeline:execute. This skill is project-agnostic — it
  reads each repo's own AGENTS.md / conventions rather than hardcoding one project. For large multi-area
  work you write an umbrella + one sub-issue per slice; otherwise a single issue. Ends with the handoff
  to /pipeline:orchestrate.
argument-hint: "[the idea or plan to write up — omit to write up the plan already in chat]"
---

# write-issue — author the issue that feeds the pipeline

The dev pipeline is two commands: **`/pipeline:write-issue` → `/pipeline:orchestrate`**. Write the issue, then run the arc to completion as a just-in-time loop. This skill owns the first leg — turning an idea or a design discussion into a **clean, grounded, forward-facing issue** the loop can execute without re-deriving the plan.

```
idea / plan  ──/pipeline:write-issue──▶  a grounded, forward-facing issue  ──/pipeline:orchestrate──▶  ground the horizon · dispatch · reconcile · repeat until empty
```

`write-issue` produces the **plan**; `/pipeline:orchestrate` **runs** it — grounding one increment at a time through `/pipeline:decompose`, shipping each through `/pipeline:execute`, then reconciling everything still outstanding against the tree that increment actually produced. This skill never writes code, makes worktrees, or dispatches — it produces the issue the loop executes.

It is **project-agnostic**. Like `decompose`/`orchestrate`, it reads each repo's own conventions (`AGENTS.md`, per-project config) rather than hardcoding a stack. Nothing below assumes a particular project.

---

## The one rule that defines a good issue: forward-facing, not archeological

**The issue states the plan to execute — never how you figured it out.** An issue is read by an implementer (human or `/pipeline:orchestrate`) who needs *what we're going to do*, not the journey to it. Exploration narrative, discovery history, and corrections-to-earlier-analysis are noise that buries the actionable spec.

- **KEEP** — the goal, the approach, the surface the work lands on (real modules and files, grouped by area), a type/interface sketch where it clarifies, the phases/waves, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X", "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- If a correction to earlier understanding matters, **bake the correct fact silently into the plan** — don't narrate the correction. The reader doesn't need the plot twist; they need the right fact.
- **And one thing that is not archeology but goes anyway: the line numbers.** A path is durable; a `file:line` is a coordinate, and one written for phase 4 is wrong by the time phase 4 runs, because phases 1-3 moved it. `/pipeline:decompose` re-derives the exact anchors at the horizon every cycle against the tree an implementer will actually open, so writing them here buys nothing and costs accuracy. *The failure this prevents: the issue body is the one artifact nothing in the loop re-checks — `/pipeline:orchestrate`'s reconcile pass runs over the **remaining plan**, not over the source issue — so a coordinate written here survives every cycle that would have caught it anywhere else. And it goes wrong silently: a stale coordinate reads exactly like a live one, and an implementer handed a coordinate does not treat its absence as a stop; it finds the nearest plausible thing and builds against that.*

A body that reads like a lab notebook is a bug. A body that reads like a build order is the goal.

---

## A follow-up from a live run is a first-class input

Most issues start as an idea. Many start instead as **something a run surfaced and did not land** — residual cleanup, a doc a change made stale, a second call site, a missing test, a rename left half-done. `/pipeline:execute` requires both roles to *file* those rather than list them in a hand-back, and `/pipeline:orchestrate` sends every item its fold-vs-file test declines to fold the same way — so this skill is where they arrive, and they are written exactly like any other issue: grounded, forward-facing, naming the real modules and files the residue sits in. Two things are additional.

- **Link it to what produced it.** `Follows #<N>` for the issue whose work surfaced it, or `Part of #<umbrella>` when that work is a sub-issue of an umbrella — and in the umbrella case, add it to the umbrella's `- [ ] #<sub>` checklist the same way Step 4 links any sub-issue. *The failure this prevents: an unlinked follow-up is indistinguishable from a fresh idea, so whoever picks it up has to reconstruct the slice, the PR and the decision that created the residue before they can size it — and the umbrella it belongs to closes looking complete while its leftovers sit untracked beside it.*
- **Name what surfaced it, in one line, as a fact about the plan** — "the <thing> migration in #<N> moved <producer> and left <consumer> on the old path". That is **surface**, not archeology: it says where the residue is and why it is there. How the run went, what was tried first, and who noticed still go in the bin, per the rule above.

The linking convention is also what makes a follow-up **placeable**: an issue that names the arc it came out of is one `/pipeline:orchestrate` can run its fold-vs-file test against — folded into that arc's wave plan as a named slice when the arc genuinely cannot land without it, and otherwise left linked and tracked beside it rather than scheduled as unrelated work. Either way it inherits the arc's branch level: while that arc has an **epic branch** live, the follow-up it surfaced forks from and PRs into that branch like any other slice of it.

---

## Step 1 — Ground it in the real code (this is how you know the plan is TRUE)

An issue written from the idea alone names files that don't exist and misstates the coupling. **Grounding is how you establish that the plan is true: verify every load-bearing claim against the actual code before you write it.** It is the single biggest lever on how well `/pipeline:decompose` and the implementer do — real modules, real consumers, real boundaries. *The failure this prevents: an ungrounded issue does not come out vague, it comes out confidently wrong — asserting a consumer that isn't one, a sole call site that is one of six, a function deleted last month — and nothing downstream can tell those claims from correct ones. That is strictly worse than a stale coordinate: a coordinate can at least be re-checked against the tree, and `/pipeline:orchestrate`'s reconcile pass is built to do exactly that. A false claim has nothing to check it against.*

**Ground with `file:line`; write down the module and the file.** The line number is how you *check* a claim, not what the issue *carries* — see Step 2's *Surface*, and the line-numbers rule in the KEEP/STRIP list above.

- **Spawn read-only `Explore` agents** (in parallel, one per subsystem the plan touches) to find the actual files, the patterns to copy, and the consumers a change ripples into. Read the real code before you assert anything about it.
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep (searching only `src/` when the thing lives under `server/`, say) produces confident-but-wrong claims ("that function doesn't exist") that poison the plan. When a claim is load-bearing — "X is/isn't a consumer", "this function doesn't exist", "only one call site" — verify it against the actual code across the whole tree, and cite the def line. Cross-check anything that surprises you; two sources disagreeing means you go read the file, not pick one.
- **Read `AGENTS.md` / the per-project config** for the conventions the issue should respect (framework skills, compat policy, comment style, the gate) — so the plan inherits them and `/pipeline:decompose` doesn't have to re-discover them.

If grounding surfaces that the idea is under-specified — a missing behavior, an open design fork, an unstated constraint — resolve what you can from the code/conventions and **state the assumption in the issue**; escalate only the genuine product/design forks the codebase can't settle, one at a time, in plain conversation.

---

## Step 2 — Structure the body (the shape decompose + implementers consume best)

Write the body in this order. Not every issue needs every section — small issues collapse to goal + surface + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions (not options you're weighing). If there's a key structural choice, state it and move on.
- **Surface** — where the work lands and what it touches: the real modules and files, grouped by area, plus the consumers each change ripples into. This is the grounded core, and it is a **map, not a checklist** — no line numbers, and nothing phrased as a sequence to work down. It is also not the per-slice owned-file list with do-not-touch boundaries: that is `/pipeline:decompose`'s, drawn at the horizon. *The failure this prevents: a section that reads as a to-do list gets executed as one — worked down item by item, so an entry three phases out is opened as an instruction rather than read as context.*
- **Type / interface sketch** — a short code block for a new type, API shape, or contract, when it clarifies the plan. Real names.
- **Phases / waves** — if the work has a clear dependency order (foundational thing first, consumers after), name the phases at a high level, and at **each boundary between them state whether the branch is independently shippable there** — plus any breaking foundational change (a required field, a NOT-NULL swap, a renamed export) every later phase must follow. That fact is a property of the plan you just designed rather than of the code as it stands, so nothing downstream can read it back out of the tree; left out, it defaults to "shippable", because an unasked question reads as a no. *The failure this prevents: a foundational phase lands on the shared integration branch and sits there half-migrated — green at every step, and forked from by every other session — because the plan never said the states in between were ones you would not ship.* Leave the *detailed* slicing (do-not-touch boundaries, model tiers, conflict map) to `/pipeline:decompose` — don't pre-empt it; just give the shape.
- **Seams** — name any **producer → consumer** shape this plan introduces or changes whose two halves land in different phases: a return type, a schema field, a config key, a prompt variable, a behavior that documentation describes. Write each one as *producer → consumer → the shape between them*. The ones to write down most carefully are the **cross-tree** seams — code ↔ docs, code ↔ prompt, code ↔ config — where the halves sit in different languages or different trees and nothing mechanical links them, so each half is correct on its own and only the pair is wrong. *The failure this prevents: an unnamed seam is invisible to a file-based conflict map (the halves share no file), invisible to each half's own checks, and invisible to every later reader — and the author who designed the change is the last person who can still see it without rediscovering it.*
- **Verify** — what "done" looks like: the behavior, the tests, the gate/check that must pass, the greps that must come back empty. A checkable bar, not a vibe.
- **Constraints** — the project conventions that bind it (from `AGENTS.md`): compat policy (e.g. forward-only/no-shims where that's the house rule), comment style, etc.

Keep every section in the *forward-facing* register from the rule above.

---

## What the second leg does with this

`/pipeline:orchestrate` runs the arc as a loop: it grounds the next dispatchable increment — the **horizon** — through `/pipeline:decompose`, ships it through `/pipeline:execute`, then reconciles everything still outstanding against the tree that increment produced and goes round again. Your **phases** are what its first cycle reads the horizon out of; everything past that horizon deliberately stays ungrounded until the cycle that dispatches it. That is the whole reason this body names modules rather than lines: the exact anchors for a phase get grounded in the cycle that dispatches it, against the tree that cycle's implementers will actually open.

Two path decisions come off this issue on that first cycle. Neither is yours to make — but both are only as good as the facts above, so write the body knowing what they feed.

- **Output path — a comment, or an umbrella + sub-issues.** `/pipeline:decompose` posts its breakdown as a comment on the issue by default, and converts the issue into an umbrella with one sub-issue per slice when the work is large **and** multi-area **and** each slice is a PR someone would want to track on its own. Your **phases**, your **surface grouped by area**, and your **verify bar** are what that reads from — they say how many waves there are, how many areas they span, and whether a piece closes on its own. An umbrella that gets filed then becomes the loop's live state: its body carries the **remaining** plan and is rewritten every cycle rather than appended to, with one comment per completed increment as the history.
- **Epic-branch path — the integration branch, or an epic branch cut from it.** Two rules reach for an epic branch and they answer different questions: **does any intermediate state leave the integration branch in a condition you would not ship?**, and — independently of that — whether the slices will be **dispatched in parallel**, since multi-slice work fanned out concurrently defaults to converging on an epic branch rather than on the shared one. Single-slice work never cuts one, and neither rule is a slice count or a busy integration branch. `/pipeline:decompose` answers both in one line every time — the first from your per-boundary **shippability** statements and your **seam** list, the second from the slice shape it derives. Read `/pipeline:decompose` for the rules in full and what the branch costs; this issue's job is to make the first one answerable.

**You supply the evidence; `/pipeline:decompose` returns the verdict.** Write the facts into the body — the phase shape, where the branch is shippable and where it is not, which seams the plan creates — and stop there. *The failure this prevents: an issue that states a conclusion instead of its inputs hands the grounding pass an answer it can no longer check, and leaves the facts behind that answer unwritten anywhere.*

---

## Step 3 — Single issue vs umbrella + sub-issues

- **Single issue** (the default) — small-to-medium work, a handful of related changes, one release effort. One body, filed; `/pipeline:decompose` reads it and posts its breakdown as a comment or fans out then.
- **Umbrella + sub-issues** — large AND multi-area AND each piece is a PR someone would want to track/close on its own. Write the umbrella as the overview (goal, the phase/wave shape, a tracked `- [ ] #<sub>` checklist) and one sub-issue per slice (or tightly-coupled cluster), each a self-contained forward-facing spec. Prefix sub-issue titles with their wave (`[W0]`, `[W1]`) so the order is visible.
- Don't reflexively shard — an umbrella for 2 small slices is tracking overhead with no payoff. Warrant it on the same test `/pipeline:decompose` applies: **multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**
- **An umbrella is not an epic branch, and filing one settles nothing about the other.** The two are orthogonal: an umbrella is a *tracking shape* — how the work is written down, assigned, and closed — while an epic branch is a *branch lifecycle*, where the slices fork from and PR into. Either can exist without the other, and `/pipeline:decompose` decides the branch on its own two rules, never from how the issue was filed. *The failure this prevents: "epic" names both things, so an author who reads it as one concludes that filing an umbrella already answered the branch question — and the facts that would actually answer it never get written.*

You may author the umbrella + subs directly, or hand a single issue to `/pipeline:orchestrate` and let its first grounding cycle convert to an umbrella when the work proves large enough — both are fine; pick based on whether you already know the slice shape.

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

> **Ready to orchestrate.** Hand this to `/pipeline:orchestrate` (e.g. `/pipeline:orchestrate #<N>`), which runs the arc as a loop: it grounds the next dispatchable increment through `/pipeline:decompose`, ships it through `/pipeline:execute` — a worktree per slice, implementers, gate, PR review, merge — then reconciles the rest against the tree that increment produced and repeats until the plan is empty.

Then **stop.** Don't slice into waves-with-boundaries, make worktrees, or write code — the loop owns those.

---

## What write-issue does NOT do (hard boundaries)

- **No slicing into dispatchable units.** You give the *shape* (phases); `/pipeline:decompose` produces the slices with owned files, do-not-touch boundaries, model tiers, and the conflict map — one increment at a time, as `/pipeline:orchestrate`'s loop reaches each one. Don't do its job in the issue body.
- **No line-level to-do list.** Ground with `file:line`; write down modules and files. Stated in full, with the failure it prevents, in *the one rule that defines a good issue* at the top of this file — which is the authoritative copy. It is named again here because the temptation lands at writing time and arrives looking like thoroughness, exactly as over-slicing does.
- **No branch verdict — state the facts instead.** Write where the branch is shippable between phases and which seams the plan creates, and never write "use an epic branch" (or "no epic branch needed") into an issue body: that is `/pipeline:decompose`'s one-line answer to make, on your evidence plus the code it grounds against. *The failure this prevents: a verdict in the body reads as settled to everyone downstream, though it was reached without the grounding pass that is supposed to reach it — and it displaces the facts that would let anyone re-check it.*
- **No code, no worktrees, no dispatch, no merge.** You author an issue. `/pipeline:orchestrate` runs it. (You *do* spawn read-only `Explore`/research agents in Step 1 — that's grounding, not building.)
- **No archeology.** See the rule at the top. If you catch yourself narrating how you discovered a fact, cut it and keep the fact.
- **Hand off, then stop.** Your turn ends at the filed issue + the handoff line.

**Why this shape:** the pipeline is only as good as its first artifact, and the loop that consumes it re-reads that artifact every cycle — so the issue has to still be true on the cycle that reaches its last phase, not only on the day it was filed. A vague or archeological issue forces each cycle to re-derive what the arc is for before it can ground anything, and an implementer to guess. An ungrounded one is worse: it reads as confident and asserts things that are simply false. So the body carries the two things that do not decay — **what the change is for, and what shape it takes** — grounded hard enough that every claim in it is true, and stops at the modules and files the work lands on rather than the line numbers the phases in front of it are about to move. Real modules, stated decisions, a checkable verify: a plan `/pipeline:orchestrate` runs instead of reverse-engineering, and one that ages into shorter rather than into wrong.
