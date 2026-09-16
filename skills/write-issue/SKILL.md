---
name: write-issue
description: >-
  Write a settled shape up as a forward-facing GitHub issue — or an umbrella + sub-issues — and plan
  the arc it runs as. Fed by /pipeline:co-think. Its input is a decision already made: the approach
  chosen, the pieces named, the order agreed, a bug already diagnosed, a follow-up a live run
  surfaced, a pile of already-filed issues to sweep and cluster into one, or a re-author a live arc
  reported back — a leaf that cannot be one PR, or N leaves that are one PR's worth of one change.
  Use whenever you're asked to WRITE UP / FILE / OPEN an issue, to DECOMPOSE or break a plan down into
  the children that will ship it, to GROUP a pile of loose issues into an umbrella, to RE-AUTHOR the
  leaves an arc reported back as wrongly sized, to capture
  agreed work as something trackable, or to turn a concluded design discussion into one. You GROUND WHAT THE ARC
  RESTS ON against the real codebase — the modules it lands in, the seams between them, the
  deliverables it names, whether the surface it assumes exists at all — then write it forward-facing
  as work to execute: goal, approach, the surface as real modules and files, the phase map, seams,
  verify. You set the phases, you cut the plan's two-level tree of tasks — umbrella to sub-issues, one
  sub-issue being one slice and one PR — and you answer whether the work is one slice or an epic, which
  decides how many cycles the loop runs rather than which command comes next. Ends with the handoff, to
  /pipeline:orchestrate.
argument-hint: "[the settled shape to write up — omit to write up what is already agreed in chat]"
---

# write-issue — author the issue that feeds the pipeline

**`co-think` settles the shape; you plan the arc, and what the plan you write decides is how many cycles it
takes to land — never which command lands it.** `/pipeline:co-think` → `/pipeline:write-issue` →
`/pipeline:orchestrate`, which loops the phases you set through `/pipeline:ground` and `/pipeline:execute`:
many cycles on a multi-phase arc, one on a standalone issue. The issue you file is deliberately
**big-picture**: `/pipeline:ground` grounds it for an executor before anything is built, so you write the arc
rather than the build.

⛔ **Your input is a shape already settled — where it is not, hand back to `/pipeline:co-think` and say so.**
Settling unshaped work is that pass's job, not this one, and the tell is that you are about to choose the
approach, name the pieces or settle the order yourself instead of writing down one already agreed: an issue
written off an unsettled shape comes out TRUE and aimed wrong, and no pass downstream reopens the goal, so the
whole arc executes it correctly.

⛔ **You set the phases and you do not ground them** — each item you file is ground into the one dispatchable
slice it already is, with owned files, fences, a model tier and a verify bar, at `/pipeline:ground`'s horizon,
and you never write code, make worktrees, dispatch or run the arc. **You are also the one pass that cuts the
plan's tree** (`skills/glossary/vocabulary/umbrella.md`), so a piece you leave too big for one PR has no seat
downstream that can cut it — the grounding pass grounds the leaves you filed and adds none. Stay
**project-agnostic** — read each repo's own conventions (`AGENTS.md`, per-project config) rather than a
hardcoded stack, and **read what a phase costs to land out of the project's own config**, never out of a cost
model you brought with you.

⛔ **Read `skills/ground-rules/SKILL.md` before you act on anything in this file — it binds you before this
file does.** Never a fork, and every searcher you spawn is itself the last agent in its chain.

**Four steps, in order — and the file does not end at the fourth**: *Two rules that fire at every step*
follows them.

---

## A follow-up from a live run is a first-class input

**A second way in, not a fifth step.** Many issues start as **something a run surfaced and did not land** —
residual cleanup, a stale doc, a half-done rename. The loop's reconcile sends here what it could neither
settle from the tree nor fold into the live arc. Write them like any other issue, through the same four steps,
keeping the recommendation they arrive with rather than re-deriving a neutral question.

- **Link it to what produced it** — unlinked it reads as a fresh idea while its umbrella closes looking
  complete; Step 4's *Follow-up linking* holds the forms.
- **Name what surfaced it, in one line, as a fact about the plan** — "the <thing> migration in #<N> moved <producer>
  and left <consumer> on the old path": **surface**, not archeology.

---

## A pile of already-filed issues is a third way in

**A third way in, not a fifth step.** Sweep the candidates and cluster them on
**a shared failure or a shared surface** — the same files, the same rule, the same failure — never on subject
area alone, since two issues that only share a subject stay unrelated even swept into one pass. That
never-on-subject-area line is Step 1's own, run here against a pile instead of one candidate. Emit an umbrella
over each cluster exactly as an authored one: the goal it shares, the phase map over its children, the
arc-wide verify bar — an ordinary epic the loop runs with no special case.
**Its children are the existing numbers, and their reports are not touched** — no re-authoring, no
summarising, no restructuring, since rewriting one loses the report whoever filed it wrote. Step 4's mechanics
cover them exactly as they cover any child — checklist, native link, and a `Part of #<umbrella>` backlink
**appended** rather than woven in, so the report stays untouched while containment stays visible.
**The reversal:** unrelated issues still ship separately — wrapping the backlog into one arc to save a gate
run trades thin-slice churn for an epic nobody can review.

---

## A re-author reported back from a live arc is a fourth way in

**A fourth way in, not a fifth step.** A live arc reports back that a ready leaf **cannot be one PR**, or that
**N ready leaves are one PR's worth of one change**, and the answer to either is authored here — a leaf cut or
merged anywhere downstream parts the unit the board holds from the unit that lands. The report arrives
settled: it is a size finding taken against the tree the arc stands on, so keep it rather than re-deriving the
question, and write what replaces those leaves through the same four steps as any other issue.

**One statement covers both directions, because both are one move**: *the leaves the report names are
superseded, the plan gains the leaves that replace them, and every superseded leaf leaves the board the same
way.* A split is one leaf superseded by several and a fold is several superseded by one, so nothing true of a
superseded leaf in the one direction is untrue of it in the other.

- **A superseded leaf is CLOSED as not planned — never edited into what replaces it — and the replacement
  takes a NEW number.** Closed as completed it says a fix shipped in some release, which is what Step 1 reads
  a closed issue as; edited in place it loses the report whoever filed it wrote, and an edit reaches one item
  where each direction has several on one side — several replacements in a split, several originals in a fold
  — so an inherited number branches both directions rather than carrying either.
- **Both artifacts move, for the leaf going out and for the leaf coming in** — the `- [ ] #<leaf>` checklist
  line and the native sub-issue link (`skills/glossary/mechanics/sub-issue-link.md`). A parent lookup reads
  the link and a markdown-only umbrella's fallback reads the checklist, so a superseded leaf keeping either
  one still reads as live to the reader that keys on it, and a replacement given only one is invisible to the
  other. Step 4's mechanics carry a replacement exactly as they carry any child.
- **Rewrite the umbrella's checklist BEFORE the close, not after.** That body is the live remaining plan and
  is re-read every cycle, so an agent arriving between the two writes has to find every leaf that remains
  named in it; closing first leaves the plan short by everything the report covered.

**A report against a standalone issue has no umbrella and the statement is unchanged, that issue being the
plan** — it is superseded exactly as a leaf is, and what replaces it is authored whole, an umbrella over
children where the report was that it cannot be one PR.

**The reversal:** this answers a report and is never a second route by which a cycle re-cuts the board. The
tracker stays the authority, the pass that grounds the work folds and cuts nothing on its own initiative, and
a re-author runs because a leaf was reported unbuildable as one PR — never because a cycle judged the plan
would read better some other way.

---

## Step 1 — Before you file, search what is already filed — by failure shape, open and closed

**Run this before you ground anything: the outcome decides whether there is a body to write at all.** Every
item out of a run — a follow-up, a residual, a close-out finding — passes it before it becomes a new number.

**Key it on the failure SHAPE — what breaks, under what conditions, with what silent symptom — never on the
item's own words, and cover CLOSED issues as well as open.**

- **Search the behavior, not the vocabulary** — two reports of one defect share almost none, so an empty
  search proves nothing. Search the symptom, the condition and the consequence separately.
- **Cover closed issues** — one flag, `--state all`. Closed says a fix shipped *in some release*: a fact about
  the tracker, not about the tree the failure was seen in.
- **Search the tracker the item will be FILED in**, naming the repository: `gh` resolves to the shell's repo,
  while a finding about the pipeline belongs to the plugin's own.

**Where the match lands decides the outcome.**

- **An open issue already describes this failure → comment on THAT issue**, saying what is *new*: the second
  run, the different mechanism, the condition that widens it. **This is what promotes a held issue**, which
  otherwise holds forever.
- **A closed issue describes it → read its close REASON, then establish which copy you read before calling
  it anything**: look in **that copy** for what the fix introduced — the rule, the flag, the branch, the
  behaviour change.
  - **Closed as not planned → nothing shipped there**: it was superseded rather than fixed, so follow it to
    what replaced it and run this step against that.
  - **Present and still failing → a REGRESSION**, naming that issue and what shipped to close it.
    **File a new issue and comment on the closed one pointing at it; never reopen it** — that erases which
    release the fix landed in.
  - **Absent → file nothing**: what was observed is **version skew**, the copy read being older than the
    release that fixed it. Say so as skew, not as a defect.
  - **You cannot establish which → say that, rather than picking**: the only one of the three a next reader
    can act on.
- **Nothing describes it → there is a body to write, and Steps 2–4 are how.**

**⛔ Not licence to skip filing because something RELATED exists — the test is whether two items share a
FAILURE, not a subject area.** A finding buried in a neighbour closes when the host does.

A comment reached this way **is** a filing — the failure, the reasoning, a recommendation rather than a fork,
why it is not the one already there, and **at least one file, symbol or route**, since the loop re-tests this
comment's verdict by intersecting exactly those and a comment carrying none reaches it as the narrowest input
it ever gets — via Step 4's comment endpoint.

---

## Step 2 — Ground what the arc RESTS ON

**Verify what the arc rests on against the actual code before you write it: the modules it lands in, the seams
between them, the deliverables it names, and whether the surface it assumes exists at all.** That depth and no
deeper — the coordinates an executor acts on are `/pipeline:ground`'s, re-derived at the horizon — and at this
depth an unchecked claim comes out confidently wrong, a consumer that isn't one or a sole call site that is
one of six, with nothing downstream able to tell it from a correct one.

**Ground with `file:line`; write down the module and the file** — the line number is how you *check* a claim,
not what the issue *carries* (Step 3's *Surface*).

- **Spawn fresh read-only search agents** — never forks — in parallel, one per subsystem, for the real files,
  the patterns to copy and the consumers a change ripples into — **invoking this skill is what authorizes
  them**, and it authorizes these read-only agents and nothing else. **Each one is the last agent in its chain
  and its brief says so** — it searches, reports, and dispatches nothing of its own, or the count you sized is
  re-sized from inside it by children whose reading you never see. **Name each one's model tier in the spawn —
  a searcher grepping one subsystem is STANDARD tier** — since a sub-agent handed no model runs on yours, and
  one searcher per subsystem then multiplies whatever tier is running this pass across the whole fan-out.
- **Grep the WHOLE repo and cite the definition line — or the claim doesn't count.** A folder-scoped grep
  produces confident-but-wrong claims. Check "X is/isn't a consumer" or "only one call site" tree-wide; two
  sources disagreeing means you read the file.
- **A SECTION citation is a load-bearing claim that method cannot settle — resolve it by OPENING the section,
  never by searching for the word it turns on.** A symbol has a definition line or none; a section citation
  attributes an *argument* to prose, where the search is agreeable rather than silent — the word it turns on
  usually sits there in an unrelated sense — and cannot dangle: a wrong one resolves to a real section, as
  authoritative-looking as a right one.
- **A COUNT is a third such claim, and its citation is its INSTRUMENT** — write the unit beside the figure and
  the tree you took it against (`grep -c` counts matching lines, `grep -o | wc -l` occurrences). **And where
  the issue's own prose summarises a list it also prints — a `Verify` bar's count, a phase map beside its
  checklist — that count is DERIVED from the list, never typed a second time.**
- **Read `AGENTS.md` / the per-project config** for the conventions the issue must respect: framework skills,
  compat policy, comment style, the gate.
- **Writing about the repository that SHIPS these skills? Ground by the TREE's copy of these rules, not the
  installed one you are reading** — the tree is what the change ships. Read its steps there, `diff` where a
  rule looks wrong, take the tree's, and say which you used.

Where the idea is under-specified, resolve what you can from the code and conventions and
**state the assumption in the issue**; escalate only genuine product/design forks, one at a time.

---

## Step 3 — Structure the body

Write the body in this order. Small issues collapse to goal + surface + verify.

- **Goal** — one or two sentences: what changes and why it's worth doing. Forward-facing.
- **Approach** — the chosen design, stated as decisions rather than options you're weighing.
- **Surface** — where the work lands: the real modules and files, grouped by area, plus the consumers each
  change ripples into. The core of what Step 2 checked, and a **map, not a checklist** — nothing phrased as a
  sequence, since a to-do list gets executed as one. Not the per-slice owned-file list — that is
  `/pipeline:ground`'s, at the horizon.
- **Type / interface sketch** — a short code block for a new type, API shape or contract, with real names.
- **Phases** — the arc's ORDERING over the items you file, yours alone to set and mapped
  **to the end of the arc**. **A phase is not the tracked unit and normally spans several PRs**, so the
  shippable-boundary test below decides order and grouping and never how big a filed item is — read as the
  tracked unit, it files children nothing can land whole. Name the phases where the work has a dependency
  order, and at **each boundary state whether the branch is independently shippable there**, plus any breaking
  foundational change (a required field, a NOT-NULL swap, a renamed export) later phases must follow, which is
  what tells the arc it runs red until the last consumer migrates. That is a property of the plan, not the
  code, so nothing downstream reads it back out of the tree and an unasked question reads as a yes — which is
  how a foundational phase sits half-migrated on a shared branch, green at every step.
  **Write the epic-versus-one-slice verdict beside the map, in one line, every time.**
  `skills/write-issue/references/arc-planning.md` carries what the map must cover, how to size a phase, and
  the two rules that settle that verdict.
- **Seams** — name any **producer → consumer** shape this plan introduces or changes whose halves land in
  different phases: a return type, a schema field, a config key, a behavior documentation describes. Write
  each as *producer → consumer → the shape between them*. **Where that shape is a status, flag or state value
  rather than a structure, say what the consuming side *does* with it** — one that only filters is safe, one
  whose read feeds an action is the seam. The **cross-tree** ones matter most — code ↔ docs, code ↔ prompt,
  code ↔ config — where nothing mechanical links the halves. The arc's running seam map is **seeded** from
  this field and re-derived nowhere, so a seam left out is one nothing downstream ever looks for.
- **Verify** — what "done" looks like: the behavior, the tests, the gate, the greps that must come back empty
  — a checkable bar, not a vibe. **A negative names its baseline** (*unchanged*, *no new X* — the fork point
  unless you name another) and **a grep names the domain it sweeps**; a bar naming neither is satisfied by
  whichever end whoever runs it picks. **A filed bar outlives the arc, so read it against the rest of the body
  first**: against the **Constraints**; against what the **Approach** asks for; any requirement against the
  vocabulary the target can express it with; any *derive X from Y* against whether Y is reachable from where
  the work will live; and any requirement against what the project's own gate, linter and ratchets will accept
  for the files it names, since a bar can be expressible, reachable and still ask for something that project
  refuses.
- **Constraints** — the project conventions that bind it, from `AGENTS.md`: compat policy, comment style, the
  rest.

**Then settle the shape — one issue, or umbrella + subs.**

- **Single issue** (the default) — small-to-medium work that lands as one PR. One body, filed;
  `/pipeline:ground` grounds it into the one dispatchable slice it already is, and enriches it with what an
  executor needs.
- **Umbrella + sub-issues** (`skills/glossary/vocabulary/umbrella.md`) — large AND multi-area.
  **File each child so it lands as ONE PR**, since a child that is really two lands half its work against a
  checklist line that cannot tick. The umbrella is the overview — goal, the phase map, a tracked
  `- [ ] #<sub>` checklist; each sub is a self-contained forward-facing spec,
  **titled with the phase it lands in** (`[P0]`, `[P1]`), the phase being the ORDERING over the children
  rather than the unit a child is. Author them at Step 4; nothing downstream converts a single issue into an
  umbrella for you.
- Don't reflexively shard — an umbrella for two small phases is overhead with no payoff, and a phase holding
  one PR's worth of work is one child rather than a level; `skills/write-issue/references/arc-planning.md`'s
  *Sizing a phase, and sizing the items inside it* carries both tests.
- **An umbrella is not an epic branch, and filing one settles nothing about the other**
  (`skills/glossary/vocabulary/epic-branch.md` separates them). The branch question is answered here on the
  two rules and carried out by `/pipeline:execute`, never read off how the issue was filed — taking it for
  answered leaves the facts unwritten.

---

## Step 4 — Write it (GitHub mechanics)

- **Use `gh api` (REST), not `gh issue create`/`edit`** — the high-level write commands go through GraphQL and
  hit rate limits in batches; REST doesn't.
- ⛔ **No AI attribution on anything this flow writes to GitHub in the maintainer's name** — the issue body,
  its title, and every comment on it name the configured git user alone: no trailer, line, footer or URL
  naming Claude, the assistant, the model, the harness, or the session. The named forms and the named
  artifacts are both instances rather than the extent, since an enumeration of either is satisfied by every
  member it omits, so leave out anything you cannot rule out.
- **Write the body to a file and reference it with `-F` (not `-f`)** —
  `skills/glossary/mechanics/gh-api-file-body.md` says why, and why the wrong one exits 0. **Verify after**:
  refetch the body and confirm it is the markdown, not `@path`.
  - Create:
    `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>" -F "milestone=<n>" --jq '.number'`
  - Edit body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"`
- **Milestone** takes a number, not a title — resolve it first
  (`gh api repos/{owner}/{repo}/milestones --jq '.[] | "\(.number)\t\(.title)"'`) and pass
  `-F "milestone=<n>"`.
- **Umbrella linking**: create the subs, capture their numbers, then PATCH the umbrella body with the
  `- [ ] #<sub>` checklist. **Each sub also carries `Part of #<umbrella>` in its body, and that backlink is a
  rule rather than a formatting nicety**: only it is readable from the child's own body, all an agent arriving
  there directly has. A backlink-less child reads as complete, so an agent arriving at it grounds the slice
  without the frame it was written inside.
- **Follow-up linking**: a follow-up filed out of a live run carries `Follows #<N>` — or `Part of #<umbrella>`
  where the originating work sits under one, which is containment and takes the **native `sub_issues` link**
  too. That native link is `skills/glossary/mechanics/sub-issue-link.md`. A bare `Follows #<N>` is provenance,
  not containment, and takes the backlink alone. **PATCH the umbrella's body to add the follow-up to its
  checklist**, or it reads as finished work that is not.
- **Superseding a leaf**: take its checklist line out of the umbrella body and unlink it as a native
  sub-issue — both, since two readers key on one each — then close **each** leaf the re-author supersedes:
  `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -f state=closed -f state_reason=not_planned`. The reason
  field is not decoration: left off, the close reads as a fix that shipped.
- **Labels**: apply an existing `epic`/`umbrella` label where the repo has one; don't invent exotic ones. It
  names the **tracking shape**, never a branch decision, though it reads as the verdict it shares a word with.

Then tell the user what you filed (issue #, or umbrella # + sub #s).

---

## Two rules that fire at every step

Neither fires at one action; both bind every line of prose this skill writes, a comment on an existing issue
included.

**Forward-facing, not archeological: the issue states the plan to execute, never how you figured it out.** An
implementer needs *what we're going to do*; exploration narrative buries the spec.

- **KEEP** — the goal, the approach, the surface the work lands on (real modules and files, grouped by area),
  a type/interface sketch where it clarifies, the phase map and its verdict, the verify bar.
- **STRIP** — "an earlier scan found / was wrong", "verified against the code", "the first pass missed X",
  "the research said", how-we-discovered-it, and any correction-of-a-prior-investigation meta.
- Where a correction matters, **bake the correct fact silently into the plan** rather than narrating it.

**No line numbers.** Not archeology, and it goes anyway: a `file:line` written for phase 4 is wrong by the
time phase 4 runs, and `/pipeline:ground` re-derives coordinates at the horizon regardless, at the depth an
executor acts on. Nothing re-checks this body, so a stale coordinate reads like a live one.

---

## Handoff

**One handoff, whatever verdict you just wrote.** Verbatim intent:

> **Ready to orchestrate.** Hand this to `/pipeline:orchestrate` (e.g. `/pipeline:orchestrate #<N>`), which runs the arc as a loop: ground the next ready leaves through `/pipeline:ground`, ship them through `/pipeline:execute` — worktree per slice, implementers, gate, PR review, merge — then reconcile the rest against the tree it produced, repeating until the plan is empty. **A standalone issue is that same loop run once**, its horizon being the issue itself and its reconcile finding nothing.

Then **stop** — grounding, worktrees and code all sit past this pass.

