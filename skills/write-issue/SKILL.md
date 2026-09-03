---
name: write-issue
description: >-
  Turn an idea or a rough plan into a grounded, forward-facing GitHub issue — or an umbrella +
  sub-issues — feeding /pipeline:orchestrate. The FIRST of the pipeline's two legs:
  /pipeline:write-issue → /pipeline:orchestrate. Use whenever you're asked to WRITE UP / FILE / OPEN an
  issue, capture a plan as an issue, or turn a design discussion into trackable work. You GROUND the
  plan in the real codebase — every load-bearing claim verified against the code — then write it as a
  PLAN TO EXECUTE: goal, approach, the surface it lands on as real modules and files, phases, seams,
  verify — no exploration narrative, history or line numbers. You do NOT slice into dispatchable
  waves, run the arc, or dispatch: /pipeline:orchestrate owns that loop.
  Ends with the handoff to /pipeline:orchestrate.
argument-hint: "[the idea or plan to write up — omit to write up the plan already in chat]"
---

# write-issue — author the issue that feeds the pipeline

The pipeline is two commands: **`/pipeline:write-issue` → `/pipeline:orchestrate`**. This skill owns the first leg: an idea turned into a **grounded, forward-facing issue** the loop executes without re-deriving it.

You never write code, make worktrees, or dispatch. Stay **project-agnostic** — read each repo's own conventions (`AGENTS.md`, per-project config), not a hardcoded stack.

---

## The one rule that defines a good issue: forward-facing, not archeological

**The issue states the plan to execute — never how you figured it out.** An implementer needs *what we're going to do*; exploration narrative buries the spec.

- **KEEP** — the goal, the approach, the surface the work lands on (real modules and files, grouped by area), a type/interface sketch where it clarifies, the phases/waves, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X", "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- Where a correction matters, **bake the correct fact silently into the plan** rather than narrating it.
- **And one thing that is not archeology but goes anyway: the line numbers.** A `file:line` written for phase 4 is wrong by the time phase 4 runs, and `/pipeline:decompose` re-derives them at the horizon anyway; nothing re-checks this body, so a stale coordinate reads like a live one.

---

## A follow-up from a live run is a first-class input

Many issues start as **something a run surfaced and did not land** — residual cleanup, a stale doc, a half-done rename; `skills/orchestrate/SKILL.md` §4 sends here what it could neither settle from the tree nor fold into the live arc. Write them like any other issue, keeping the recommendation they arrive with rather than re-deriving a neutral question.

- **Link it to what produced it** — unlinked it reads as a fresh idea while its umbrella closes looking complete. `Follows #<N>` for the issue whose work surfaced it; `Part of #<umbrella>` where that work sits under an umbrella, plus that umbrella's `- [ ] #<sub>` checklist (Step 4). **A finding from behind a fence takes one further line**: an item found inside a file its brief marked `Do NOT touch` carries `Filed from behind a fence: <the fenced path>` — `skills/execute/references/implementer.md`'s *File your follow-ups BEFORE you hand back* holds the form, `skills/orchestrate/SKILL.md` §4 keys on the line.
- **Name what surfaced it, in one line, as a fact about the plan** — "the <thing> migration in #<N> moved <producer> and left <consumer> on the old path": **surface**, not archeology.

---

## Before you file, search what is already filed — by failure shape, open and closed

**Check what the tracker already holds before an item filed out of a run — a follow-up, a residual, a close-out finding — becomes a new number**, and run it **before** grounding: the outcome decides whether there is a body to write.

**Key it on the failure SHAPE — what breaks, under what conditions, with what silent symptom — never on the item's own words, and cover CLOSED issues as well as open.**

- **Search the behavior, not the vocabulary** — two reports of one defect share almost none, so an empty search proves nothing. Search the symptom, the condition and the consequence separately (`skills/execute/references/implementer.md`'s *Docs are part of the change, not a follow-up* argues it).
- **Cover closed issues** — one flag, `--state all`. Closed says a fix shipped *in some release*: a fact about the tracker, not about the tree the failure was seen in.
- **Search the tracker the item will be FILED in**, naming the repository: `gh` resolves to the shell's repo, while a finding about the pipeline belongs to the plugin's own.

**Where the match lands decides the outcome.**

- **An open issue already describes this failure → comment on THAT issue**, saying what is *new*: the second run, the different mechanism, the condition that widens it. **This is what promotes a held issue**, which otherwise holds forever.
- **A closed issue describes it → establish which copy you read before calling it anything**: look in **that copy** for what the fix introduced — the rule, the flag, the branch, the behaviour change.
  - **Present and still failing → a REGRESSION**, naming that issue and what shipped to close it. **File a new issue and comment on the closed one pointing at it; never reopen it** — that erases which release the fix landed in.
  - **Absent → file nothing**: what was observed is **version skew**, the copy read being older than the release that fixed it. Say so as skew, not as a defect.
  - **You cannot establish which → say that, rather than picking**: the only one of the three a next reader can act on.
- **Nothing describes it → file, exactly as before.**

**⛔ Not licence to skip filing because something RELATED exists — the test is whether two items share a FAILURE, not a subject area.** A finding buried in a neighbour closes when the host does.

A comment reached this way **is** a filing — the failure, the reasoning, a recommendation rather than a fork, and why it is not the one already there — via *Step 4*'s comment endpoint.

---

## Step 1 — Ground it in the real code

**Verify every load-bearing claim against the actual code before you write it.** An ungrounded issue comes out confidently wrong — a consumer that isn't one, a sole call site that is one of six — and nothing downstream can tell it from a correct one.

**Ground with `file:line`; write down the module and the file** — the line number is how you *check* a claim, not what the issue *carries* (Step 2's *Surface*).

- **Spawn read-only `Explore` agents** in parallel, one per subsystem, for the real files, the patterns to copy and the consumers a change ripples into — **invoking this skill authorizes them** (`skills/execute/SKILL.md` → *First: which role are you?*).
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep produces confident-but-wrong claims. Check "X is/isn't a consumer" or "only one call site" tree-wide; two sources disagreeing means you read the file.
- **A SECTION citation is a load-bearing claim that method cannot settle — resolve it by OPENING the section, never by searching for the word it turns on.** A symbol has a definition line or none; a section citation attributes an *argument* to prose, where the search is agreeable rather than silent — the word it turns on usually sits there in an unrelated sense — and cannot dangle: a wrong one resolves to a real section, as authoritative-looking as a right one.
- **A COUNT is a third such claim, and its citation is its INSTRUMENT** — write the unit beside the figure and the tree you took it against (`grep -c` counts matching lines, `grep -o | wc -l` occurrences).
- **Read `AGENTS.md` / the per-project config** for the conventions the issue must respect: framework skills, compat policy, comment style, the gate.
- **Writing about the repository that SHIPS these skills? Ground by the TREE's copy of these rules, not the installed one you are reading** — the tree is what the change ships. Read its steps there, `diff` where a rule looks wrong, take the tree's, and say which you used.

Where the idea is under-specified, resolve what you can from the code and conventions and **state the assumption in the issue**; escalate only genuine product/design forks, one at a time.

---

## Step 2 — Structure the body

Write the body in this order. Small issues collapse to goal + surface + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions rather than options you're weighing.
- **Surface** — where the work lands: the real modules and files, grouped by area, plus the consumers each change ripples into. The grounded core, and a **map, not a checklist** — no line numbers, nothing phrased as a sequence, since a to-do list gets executed as one. Not the per-slice owned-file list — that is `/pipeline:decompose`'s, at the horizon.
- **Type / interface sketch** — a short code block for a new type, API shape or contract, with real names.
- **Phases / waves** — name the phases where the work has a dependency order, and at **each boundary state whether the branch is independently shippable there**, plus any breaking foundational change (a required field, a NOT-NULL swap, a renamed export) later phases must follow. That is a property of the plan, not the code, so nothing downstream reads it back out of the tree and an unasked question reads as a yes — which is how a foundational phase sits half-migrated on a shared branch, green at every step. **Never write the branch verdict itself** ("use an epic branch", "no epic branch needed") — that is `/pipeline:decompose`'s, on your facts.
- **Seams** — name any **producer → consumer** shape this plan introduces or changes whose halves land in different phases: a return type, a schema field, a config key, a behavior documentation describes. Write each as *producer → consumer → the shape between them*. **Where that shape is a status, flag or state value rather than a structure, say what the consuming side *does* with it** — one that only filters is safe, one whose read feeds an action is the seam. The **cross-tree** ones matter most — code ↔ docs, code ↔ prompt, code ↔ config — where nothing mechanical links the halves. `skills/orchestrate/SKILL.md` §7 seeds the arc's seam map here and re-derives nothing.
- **Verify** — what "done" looks like: the behavior, the tests, the gate, the greps that must come back empty — a checkable bar, not a vibe. **A negative names its baseline** (*unchanged*, *no new X* — the fork point unless you name another) and **a grep names the domain it sweeps**; a bar naming neither is satisfied by whichever end whoever runs it picks. **A filed bar outlives the arc, so read it against the rest of the body first**: against the **Constraints**; against what the **Approach** asks for; any requirement against the vocabulary the target can express it with; any *derive X from Y* against whether Y is reachable (`skills/decompose/SKILL.md` Step 3's `Verify` field and closing check argue both).
- **Constraints** — the project conventions that bind it, from `AGENTS.md`: compat policy, comment style, the rest.

Keep every section in the *forward-facing* register.

---

## Step 3 — Single issue vs umbrella + sub-issues

- **Single issue** (the default) — small-to-medium work, one release effort. One body, filed; `/pipeline:decompose` comments its breakdown on it, or fans out then.
- **Umbrella + sub-issues** — large AND multi-area AND each piece a PR someone would want to track/close alone. The umbrella is the overview — goal, phase/wave shape, a tracked `- [ ] #<sub>` checklist; each sub is one slice, a self-contained forward-facing spec titled with its wave (`[W0]`, `[W1]`).
- Don't reflexively shard — an umbrella for 2 small slices is overhead with no payoff; that test is `/pipeline:decompose`'s own.
- **An umbrella is not an epic branch, and filing one settles nothing about the other.** An umbrella is a *tracking shape*; an epic branch is a *branch lifecycle*, decided by `/pipeline:decompose` on its own two rules, never from how the issue was filed. "Epic" names both, so reading them as one takes the branch question for answered and leaves the facts unwritten.

Author the umbrella + subs directly, or let `/pipeline:orchestrate`'s first cycle convert one.

---

## Step 4 — Write it (GitHub mechanics)

- **Use `gh api` (REST), not `gh issue create`/`edit`** — the high-level write commands go through GraphQL and hit rate limits in batches; REST doesn't.
- **Write the body to a file and reference it with `-F` (not `-f`)**: `-f body=@file` silently stores the literal string `@file`, `-F body=@file` reads it. **Verify after** — refetch the body and confirm it is the markdown, not `@path`.
  - Create: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>" -F "milestone=<n>" --jq '.number'`
  - Edit body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"`
- **Milestone** takes a number, not a title — resolve it first (`gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number)\t\(.title)"'`) and pass `-F "milestone=<n>"`.
- **Umbrella linking**: create the subs, capture their numbers, then PATCH the umbrella body with the `- [ ] #<sub>` checklist. **Each sub also carries `Part of #<umbrella>` in its body, and that backlink is a rule rather than a formatting nicety**: only it is readable from the child's own body, all an agent arriving there directly has. A backlink-less child reads as complete (`skills/decompose/SKILL.md` Step 1 consumes both).
- **Follow-up linking**: a follow-up filed out of a live run carries `Follows #<N>` — or `Part of #<umbrella>` where the originating work sits under one, which is containment and takes the **native `sub_issues` link** too. `skills/execute/references/implementer.md`'s *File your follow-ups BEFORE you hand back* holds that form — the call, its database-id trap, and why a bare `Follows #<N>` takes the backlink alone. **PATCH the umbrella's body to add the follow-up to its checklist**, or it reads as finished work that is not.
- **Labels**: apply an existing `epic`/`umbrella` label where the repo has one; don't invent exotic ones. It names the **tracking shape**, never a branch decision, though it reads as the verdict it shares a word with.

Then tell the user what you filed (issue #, or umbrella # + sub #s).

---

## Handoff

End with, verbatim intent:

> **Ready to orchestrate.** Hand this to `/pipeline:orchestrate` (e.g. `/pipeline:orchestrate #<N>`), which runs the arc as a loop: ground the next increment through `/pipeline:decompose`, ship it through `/pipeline:execute` — worktree per slice, implementers, gate, PR review, merge — then reconcile the rest against the tree it produced, repeating until the plan is empty.

Then **stop** — the loop owns slicing, worktrees and code.

