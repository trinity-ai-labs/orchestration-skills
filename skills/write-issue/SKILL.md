---
name: write-issue
description: >-
  Write a settled shape up as a forward-facing GitHub issue — or an umbrella + sub-issues — and plan
  the arc it runs as. Fed by /pipeline:co-think. Its input is a decision already made: the approach
  chosen, the pieces named, the order agreed, a bug already diagnosed, or a follow-up a live run
  surfaced. Use whenever you're asked to WRITE UP / FILE / OPEN an issue, to capture agreed work as
  something trackable, or to turn a concluded design discussion into one. You GROUND WHAT THE ARC
  RESTS ON against the real codebase — the modules it lands in, the seams between them, the
  deliverables it names, whether the surface it assumes exists at all — then write it forward-facing
  as work to execute: goal, approach, the surface as real modules and files, the phase map, seams,
  verify. You set the phases, and you answer whether the work is one slice or an epic. Ends with the
  handoff — to /pipeline:decompose for one slice, to /pipeline:orchestrate for an epic.
argument-hint: "[the settled shape to write up — omit to write up what is already agreed in chat]"
---

# write-issue — author the issue that feeds the pipeline

**`co-think` settles the shape; you plan the arc, and the plan you write chooses between two paths.** **One slice** — `/pipeline:co-think` → `/pipeline:write-issue` → `/pipeline:decompose` → `/pipeline:execute`, no loop anywhere in it. **An epic** — `/pipeline:co-think` → `/pipeline:write-issue` → `/pipeline:orchestrate`, which loops the phases you set through `/pipeline:decompose` and `/pipeline:execute`. Either way the issue you file is deliberately **big-picture**: `/pipeline:decompose` grounds it for an executor before anything is built, so you write the arc rather than the build.

⛔ **Your input is a shape already settled — where it is not, hand back to `/pipeline:co-think` and say so.** Settling unshaped work is that pass's job, not this one, and the tell is that you are about to choose the approach, name the pieces or settle the order yourself instead of writing down one already agreed: an issue written off an unsettled shape comes out TRUE and aimed wrong, and no pass downstream reopens the goal, so the whole arc executes it correctly.

⛔ **You set the phases and you do not ground them** — a phase becomes dispatchable slices with owned files, fences, a model tier and a verify bar at `/pipeline:decompose`'s horizon, and you never write code, make worktrees, dispatch or run the arc. Stay **project-agnostic** — read each repo's own conventions (`AGENTS.md`, per-project config) rather than a hardcoded stack, and **read what a phase costs to land out of the project's own config**, never out of a cost model you brought with you.

**Four steps, in order — and the file does not end at the fourth**: *Two rules that fire at every step* follows them.

---

## A follow-up from a live run is a first-class input

**A second way in, not a fifth step.** Many issues start as **something a run surfaced and did not land** — residual cleanup, a stale doc, a half-done rename. The loop's reconcile sends here what it could neither settle from the tree nor fold into the live arc. Write them like any other issue, through the same four steps, keeping the recommendation they arrive with rather than re-deriving a neutral question.

- **Link it to what produced it** — unlinked it reads as a fresh idea while its umbrella closes looking complete; Step 4's *Follow-up linking* holds the forms. **A finding from behind a fence takes one further line**: an item found inside a file its brief marked `Do NOT touch` carries `Filed from behind a fence: <the fenced path>` on its own line in the body, or heading the comment where the observation lands on an existing issue. Its premises were established by **reading** rather than by changing, so whoever picks it up re-grounds every claim before it becomes a slice.
- **Name what surfaced it, in one line, as a fact about the plan** — "the <thing> migration in #<N> moved <producer> and left <consumer> on the old path": **surface**, not archeology.

---

## Step 1 — Before you file, search what is already filed — by failure shape, open and closed

**Run this before you ground anything: the outcome decides whether there is a body to write at all.** Every item out of a run — a follow-up, a residual, a close-out finding — passes it before it becomes a new number.

**Key it on the failure SHAPE — what breaks, under what conditions, with what silent symptom — never on the item's own words, and cover CLOSED issues as well as open.**

- **Search the behavior, not the vocabulary** — two reports of one defect share almost none, so an empty search proves nothing. Search the symptom, the condition and the consequence separately.
- **Cover closed issues** — one flag, `--state all`. Closed says a fix shipped *in some release*: a fact about the tracker, not about the tree the failure was seen in.
- **Search the tracker the item will be FILED in**, naming the repository: `gh` resolves to the shell's repo, while a finding about the pipeline belongs to the plugin's own.

**Where the match lands decides the outcome.**

- **An open issue already describes this failure → comment on THAT issue**, saying what is *new*: the second run, the different mechanism, the condition that widens it. **This is what promotes a held issue**, which otherwise holds forever.
- **A closed issue describes it → establish which copy you read before calling it anything**: look in **that copy** for what the fix introduced — the rule, the flag, the branch, the behaviour change.
  - **Present and still failing → a REGRESSION**, naming that issue and what shipped to close it. **File a new issue and comment on the closed one pointing at it; never reopen it** — that erases which release the fix landed in.
  - **Absent → file nothing**: what was observed is **version skew**, the copy read being older than the release that fixed it. Say so as skew, not as a defect.
  - **You cannot establish which → say that, rather than picking**: the only one of the three a next reader can act on.
- **Nothing describes it → there is a body to write, and Steps 2–4 are how.**

**⛔ Not licence to skip filing because something RELATED exists — the test is whether two items share a FAILURE, not a subject area.** A finding buried in a neighbour closes when the host does.

A comment reached this way **is** a filing — the failure, the reasoning, a recommendation rather than a fork, and why it is not the one already there — via Step 4's comment endpoint.

---

## Step 2 — Ground what the arc RESTS ON

**Verify what the arc rests on against the actual code before you write it: the modules it lands in, the seams between them, the deliverables it names, and whether the surface it assumes exists at all.** That depth and no deeper — the coordinates an executor acts on are `/pipeline:decompose`'s, re-derived at the horizon — and at this depth an unchecked claim comes out confidently wrong, a consumer that isn't one or a sole call site that is one of six, with nothing downstream able to tell it from a correct one.

**Ground with `file:line`; write down the module and the file** — the line number is how you *check* a claim, not what the issue *carries* (Step 3's *Surface*).

- **Spawn fresh read-only search agents** — never forks — in parallel, one per subsystem, for the real files, the patterns to copy and the consumers a change ripples into — **invoking this skill is what authorizes them**, and it authorizes these read-only agents and nothing else.
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep produces confident-but-wrong claims. Check "X is/isn't a consumer" or "only one call site" tree-wide; two sources disagreeing means you read the file.
- **A SECTION citation is a load-bearing claim that method cannot settle — resolve it by OPENING the section, never by searching for the word it turns on.** A symbol has a definition line or none; a section citation attributes an *argument* to prose, where the search is agreeable rather than silent — the word it turns on usually sits there in an unrelated sense — and cannot dangle: a wrong one resolves to a real section, as authoritative-looking as a right one.
- **A COUNT is a third such claim, and its citation is its INSTRUMENT** — write the unit beside the figure and the tree you took it against (`grep -c` counts matching lines, `grep -o | wc -l` occurrences).
- **Read `AGENTS.md` / the per-project config** for the conventions the issue must respect: framework skills, compat policy, comment style, the gate.
- **Writing about the repository that SHIPS these skills? Ground by the TREE's copy of these rules, not the installed one you are reading** — the tree is what the change ships. Read its steps there, `diff` where a rule looks wrong, take the tree's, and say which you used.

Where the idea is under-specified, resolve what you can from the code and conventions and **state the assumption in the issue**; escalate only genuine product/design forks, one at a time.

---

## Step 3 — Structure the body

Write the body in this order. Small issues collapse to goal + surface + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions rather than options you're weighing.
- **Surface** — where the work lands: the real modules and files, grouped by area, plus the consumers each change ripples into. The core of what Step 2 checked, and a **map, not a checklist** — nothing phrased as a sequence, since a to-do list gets executed as one. Not the per-slice owned-file list — that is `/pipeline:decompose`'s, at the horizon.
- **Type / interface sketch** — a short code block for a new type, API shape or contract, with real names.
- **Phases** — the arc's ordering, yours alone to set and mapped **to the end of the arc**: name the phases where the work has a dependency order, and at **each boundary state whether the branch is independently shippable there**, plus any breaking foundational change (a required field, a NOT-NULL swap, a renamed export) later phases must follow, which is what tells the arc it runs red until the last consumer migrates. That is a property of the plan, not the code, so nothing downstream reads it back out of the tree and an unasked question reads as a yes — which is how a foundational phase sits half-migrated on a shared branch, green at every step. **Write the epic-versus-one-slice verdict beside the map, in one line, every time.** `skills/write-issue/references/arc-planning.md` carries what the map must cover, how to size a phase, and the two rules that settle that verdict.
- **Seams** — name any **producer → consumer** shape this plan introduces or changes whose halves land in different phases: a return type, a schema field, a config key, a behavior documentation describes. Write each as *producer → consumer → the shape between them*. **Where that shape is a status, flag or state value rather than a structure, say what the consuming side *does* with it** — one that only filters is safe, one whose read feeds an action is the seam. The **cross-tree** ones matter most — code ↔ docs, code ↔ prompt, code ↔ config — where nothing mechanical links the halves. The arc's running seam map is **seeded** from this field and re-derived nowhere, so a seam left out is one nothing downstream ever looks for.
- **Verify** — what "done" looks like: the behavior, the tests, the gate, the greps that must come back empty — a checkable bar, not a vibe. **A negative names its baseline** (*unchanged*, *no new X* — the fork point unless you name another) and **a grep names the domain it sweeps**; a bar naming neither is satisfied by whichever end whoever runs it picks. **A filed bar outlives the arc, so read it against the rest of the body first**: against the **Constraints**; against what the **Approach** asks for; any requirement against the vocabulary the target can express it with; any *derive X from Y* against whether Y is reachable from where the work will live.
- **Constraints** — the project conventions that bind it, from `AGENTS.md`: compat policy, comment style, the rest.

**Then settle the shape — one issue, or umbrella + subs.**

- **Single issue** (the default) — small-to-medium work, one release effort. One body, filed; `/pipeline:decompose` grounds it, enriches it with what an executor needs, and comments its breakdown on it or fans out then.
- **Umbrella + sub-issues** (`skills/glossary/vocabulary/umbrella.md`) — large AND multi-area AND each piece a PR someone would want to track/close alone. The umbrella is the overview — goal, the phase map, a tracked `- [ ] #<sub>` checklist; each sub is one phase, a self-contained forward-facing spec titled with it (`[P0]`, `[P1]`). Author them at Step 4, or let `/pipeline:orchestrate`'s first cycle convert a single issue.
- Don't reflexively shard — an umbrella for two small phases is overhead with no payoff; `skills/write-issue/references/arc-planning.md`'s *Sizing a phase* carries that test.
- **An umbrella is not an epic branch, and filing one settles nothing about the other** (`skills/glossary/vocabulary/epic-branch.md` separates them). The branch question is answered here on the two rules and carried out by `/pipeline:execute`, never read off how the issue was filed — taking it for answered leaves the facts unwritten.

---

## Step 4 — Write it (GitHub mechanics)

- **Use `gh api` (REST), not `gh issue create`/`edit`** — the high-level write commands go through GraphQL and hit rate limits in batches; REST doesn't.
- **Write the body to a file and reference it with `-F` (not `-f`)** — `skills/glossary/mechanics/gh-api-file-body.md` says why, and why the wrong one exits 0. **Verify after**: refetch the body and confirm it is the markdown, not `@path`.
  - Create: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>" -F "milestone=<n>" --jq '.number'`
  - Edit body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"`
- **Milestone** takes a number, not a title — resolve it first (`gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number)\t\(.title)"'`) and pass `-F "milestone=<n>"`.
- **Umbrella linking**: create the subs, capture their numbers, then PATCH the umbrella body with the `- [ ] #<sub>` checklist. **Each sub also carries `Part of #<umbrella>` in its body, and that backlink is a rule rather than a formatting nicety**: only it is readable from the child's own body, all an agent arriving there directly has. A backlink-less child reads as complete, so an agent arriving at it grounds the slice without the frame it was written inside.
- **Follow-up linking**: a follow-up filed out of a live run carries `Follows #<N>` — or `Part of #<umbrella>` where the originating work sits under one, which is containment and takes the **native `sub_issues` link** too. That native link is `skills/glossary/mechanics/sub-issue-link.md`. A bare `Follows #<N>` is provenance, not containment, and takes the backlink alone. **PATCH the umbrella's body to add the follow-up to its checklist**, or it reads as finished work that is not.
- **Labels**: apply an existing `epic`/`umbrella` label where the repo has one; don't invent exotic ones. It names the **tracking shape**, never a branch decision, though it reads as the verdict it shares a word with.

Then tell the user what you filed (issue #, or umbrella # + sub #s).

---

## Two rules that fire at every step

Neither fires at one action; both bind every line of prose this skill writes, a comment on an existing issue included.

**Forward-facing, not archeological: the issue states the plan to execute, never how you figured it out.** An implementer needs *what we're going to do*; exploration narrative buries the spec.

- **KEEP** — the goal, the approach, the surface the work lands on (real modules and files, grouped by area), a type/interface sketch where it clarifies, the phase map and its verdict, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X", "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- Where a correction matters, **bake the correct fact silently into the plan** rather than narrating it.

**No line numbers.** Not archeology, and it goes anyway: a `file:line` written for phase 4 is wrong by the time phase 4 runs, and `/pipeline:decompose` re-derives coordinates at the horizon regardless, at the depth an executor acts on. Nothing re-checks this body, so a stale coordinate reads like a live one.

---

## Handoff

**Route on the verdict you just wrote — one of these two, never both.**

**One slice**, verbatim intent:

> **Ready to ground.** Hand this to `/pipeline:decompose`, which verifies it against the code, fills in what an executor acts on and enriches this issue with it — then `/pipeline:execute` ships it: worktree, implementer, gate, draft PR, review, merge. No loop.

**An epic**, verbatim intent:

> **Ready to orchestrate.** Hand this to `/pipeline:orchestrate` (e.g. `/pipeline:orchestrate #<N>`), which runs the arc as a loop: ground the next phase through `/pipeline:decompose`, ship it through `/pipeline:execute` — worktree per slice, implementers, gate, PR review, merge — then reconcile the rest against the tree it produced, repeating until the plan is empty.

Then **stop** — grounding, worktrees and code all sit past this pass.

