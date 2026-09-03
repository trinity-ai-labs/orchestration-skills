---
name: decompose
description: >-
  Ground, validate, and slice ONE increment of work into a dispatch-ready breakdown — the grounding pass
  /pipeline:orchestrate invokes each cycle, and a directly-invocable pass for anyone who wants a single breakdown.
  Use whenever you're asked to DECOMPOSE, break down, slice, or plan-for-parallelism a chunk of work; to figure
  out what can run concurrently; and ALSO when the work is plainly a single slice — grounding and validation
  stand on their own, and a plan that needs no splitting can still be wrong. You ground the HORIZON — the next
  dispatchable increment — in the actual codebase (real files/modules, not guesses) and VALIDATE it against what
  the code actually does, surfacing wrong assumptions, unspecified behavior, and defects in the plan itself
  before an implementer builds on them. The horizon emits at SLICE depth (owned files, do-not-touch boundaries,
  depends-on, the framework skill each slice must invoke, a model-tier hint, brief, verify bar); everything past
  it emits at SHAPE depth (goal, area, dependency — no file:line), because coordinates grounded now and executed
  three waves later name paths that stopped existing. You NEVER ground beyond the horizon, and you do NOT write
  code, make worktrees, dispatch implementers, or merge — /pipeline:execute dispatches and merges,
  /pipeline:orchestrate owns the loop around you. On the GitHub path you post the breakdown as a comment, or — when
  the arc is large/multi-area enough — convert the issue into an UMBRELLA with one sub-issue per slice.
argument-hint: "[issue # or a description of the plan to decompose — omit to decompose the plan already in chat]"
---

# Decompose — ground the horizon into dispatchable slices

`/pipeline:orchestrate` runs an arc as a just-in-time loop: ground the next dispatchable increment, dispatch it, reconcile what remains against the tree that increment produced, repeat. `/pipeline:execute` ships each increment off an integration branch: one task → one worktree → one PR → merge.

**Decompose is the grounding step of that loop.** You take the next dispatchable increment — the **horizon** — ground it in the real code, and turn it into independent slices the dispatcher can run in parallel with minimal collision. Everything past the horizon you carry forward as *shape*: goal, area, what it waits on — never coordinates. You are a **planner, not a builder**: you never write code, make worktrees, dispatch implementers, or merge, and you never run the loop around yourself.

**Maximize safe parallelism, but parallelism has a price, so the goal is the *balance***, not as many slices as possible: every slice pays a worktree, an install, a review and a gate run, and gates drain one at a time. Aim for the *fewest* slices that still expose the real independence. **Sizing** (Step 3) carries the economics.

## Three input paths

- **Invoked by `/pipeline:orchestrate` for one increment** — the loop names the horizon. Ground and slice **that increment only**, emit the remainder at shape depth, hand it back.
- **In-chat plan** — decompose it and emit the breakdown **in chat**, ending with the handoff line.
- **GitHub issue** (`decompose #1042`) — read it with `gh issue view <N>`, ground it, then write the breakdown back to GitHub (*Writing it back to GitHub*). Ask once if it's ambiguous between this and the in-chat path.

**All three paths ground the horizon and nothing else — only *who names it* changes.** On the direct paths you work it out from the plan's dependency order, as the loop's first cycle does. **`skills/orchestrate/SKILL.md` section 1 is the authority on the horizon and on the two depths.**

---

## Step 1 — Read the plan and ground the horizon in the codebase

A breakdown built from the plan text alone names files that don't exist and misses the real coupling. **Ground every horizon slice in the actual code first — and stop at the horizon**: a coordinate grounded now and executed three waves later names a path an earlier wave moved, with nothing erroring, so the implementer builds against the nearest plausible thing instead.

- **Read the source plan fully — the whole arc, then ground only its front.** For a GH issue: `gh issue view <N> --comments` — body **and** discussion, since constraints often live in comments; for an in-chat plan, or an arc handed to you by the loop, re-read what was laid out.
- **Re-derive the citations the plan carries — a SECTION citation most of all, because nothing further down the flow will.** A stale path fails to resolve; a stale section citation **resolves perfectly**, to a real section not carrying the argument attributed to it. **Open the section and read what it argues**, never search for the word the claim turns on — that word is usually there in an unrelated sense, so the search reads as confirmation. Send one that does not hold to Step 2.
- **Read UP before you read DEEP — on the GitHub path, establish whether the issue is a sub-issue of an umbrella and read the parent FIRST**, since a child issue reads as complete and gives no sign it was written inside a frame. Two steps, in order:
  1. **`gh api repos/{owner}/{repo}/issues/<N>/parent --jq .number`** — definitive when the umbrella used native sub-issue links. With no native parent it returns **HTTP 404 `No parent issue found`** and `gh` **exits non-zero**: the endpoint answering, not failing, so branch on the exit status rather than chaining with `&&`.
  2. **When it 404s, fall back to the timeline**, which finds a markdown-only umbrella step 1 structurally cannot see:
     ```
     gh api repos/{owner}/{repo}/issues/<N>/timeline --paginate \
       --jq '.[]|select(.event=="cross-referenced")|.source.issue.number' | sort -un
     ```
     **This returns a CANDIDATE SET, not the parent** — every issue and PR that ever cross-referenced this one, the umbrella in no way distinguished from the arc's sibling slices and PRs. Disambiguate rather than take the lowest or the first: **the umbrella is the candidate whose own body carries this issue in its tracked checklist**:
     ```
     gh issue view <candidate> --json body -q .body \
       | grep -qE "^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*#<N>([^0-9]|$)"
     ```
     Use `([^0-9]|$)` rather than `\b`, for portability across BSD and GNU grep. That checklist line is the artifact step 1 of *Umbrella + sub-issues* mandates writing.

  Then read the parent with `gh issue view <umbrella> --comments` **before** you ground the child: it carries the wave map, the epic-branch answer, the seam list and the constraints the child was written inside, none of it restated in the child.
- **Research the codebase to anchor each horizon slice** — **fresh** `Explore` agents in parallel, never forks, one per subsystem the **horizon** touches, for the real files, modules, patterns to copy and consumers a change ripples into; invoking this skill authorizes them (`skills/execute/SKILL.md` → *First: which role are you?*). Don't research subsystems only a later wave touches. **This establishes only that a coordinate EXISTS in the tree, never that it is REACHABLE from where the slice needing it will live** — Step 3's closing check tests the second.
- **Find what each horizon slice will falsify — docs first, then every other artifact that asserts something about the code — and put it in that slice's scope.**
  - **The docs come first, and you derive them from the behavior, never from a keyword grep**: user-facing prose carries none of your new identifiers by construction, so the empty grep reads as *nothing affected*. Ask what a reader of each doc believes and which beliefs this slice makes false, then **read** the candidates.
  - **Then the greppable complement: does this slice delete or move a file the docs cite by path?** A path names something the tree either has or does not, so `grep -rF '<path>' <doc-set>` answers it exactly.
  - **Then ask the same of everything else that asserts something about the code** — a guard-proof table row, a `package.json` script entry, a pre-commit chain entry, a test fixture, a CI job, a ledger entry — and **find every declaration, not the first**, since an enforcement chain is routinely declared in several places.
  - **And ask what PRODUCES the artifact, not only what reads it**: *asserts something about the code* describes a consumer, and a producer omitting a new field emits a valid artifact, so it never errors.
  - **And ask what the slice ADDS that no doc describes at all** — *what does this falsify?* asks about a difference, so a new gate, flag or endpoint on an undescribed surface returns *nothing*. Name the doc that **should** describe it, scoped as needing **new prose**.
  - **Scoping a doc OUT is a claim from the plan, not from the diff** — record an explicit not-affected-because so the implementer can overturn it. Beyond the horizon, record only that an item has docs to falsify and in which area.
  - **In an epic this bullet does not move — only the edit does.** Still name the docs slice by slice; the deliverable becomes an entry in the epic's **falsification ledger**, both kinds, consumed by a closing docs slice against the final tree — except the coordinate case, which ships with the slice that moved the path (`skills/execute/references/worktrees-and-branches.md` → *Docs land at the end*).
- **Then ask which existing assertions depend on the value produced at the site you are changing — and answer by reading that site's CALLERS, never by grepping**: the assertion that breaks names a shape that survives on the type and merely stops being populated there. Put the test files that come back in the slice's `Owns` with their disposition — *the assertion moves here*, not *build here*.
- **Then sweep for the artifacts a REGENERATOR owns, so `Derives` (Step 3) is filled from the repo rather than from memory.** Half is mechanical: a `package.json` script writing a file **into the tree** rather than a build directory; a checker with a `--write`/`--update` mode; a gate or pre-commit chain entry that regenerates something; a generated file `.gitignore` does **not** list. The other half is the falsification question pointed at checkers, which catches the generated file whose regenerator is a test.
- **Read `AGENTS.md` and the per-project config** (`<repo>/.agents/worktree.json`, the same config `/pipeline:execute` reads) for the **framework skills** per area, the **gate**, the **compat policy** and the style conventions, and bake them into each slice. **No config is a hard stop, not a note** — `skills/orchestrate/SKILL.md` §2's *Before the loop: the config precondition* owns it, `skills/setup/SKILL.md`'s *Why an unconfigured repo is worse than an obviously-broken one* carries why.
- **Grounding an arc inside the repository that SHIPS these skills? Your own rules are a coordinate too.** You were loaded from the installed plugin, not the tree you are grounding against, and the rules an arc has just shipped are the ones most likely missing from your copy. Read a governing rule out of that repo's own `skills/` before grounding by it; where one looks wrong, `diff` the copies and trust the tree. Say which copy you read your rules from, and **put the same sentence into the briefs you emit** (`skills/execute/references/dispatching.md`'s *Dispatching into the repository that SHIPS these skills*).
- **Discover the integration branch**, don't assume it: `git branch --list 'release/*'` / the current branch. Slices target the active integration branch, never `main`, never a hardcoded version — or the **epic branch** if Step 4 warrants one, which is cut from it.

**An enumeration is a claim, and its cardinality is part of it — so take the count from the command that filtered nothing.** **A set has nothing in it to say it is short**: a truncated enumeration names real files in the right format and reconciles with every other field, so Step 3's closing check reads it as sound — that check compares a brief's fields against **each other**, and this one is wrong against the **tree**. A truncated list, a suppressed error and a search that never ran are byte-identical to a clean empty result. So:

- **Count first and print untruncated** — `… | wc -l`, then the set itself with nothing between it and you — and **write the number beside the list in the slice**. Never `head`/`tail` the set.
- **Say what the number counts, because `wc -l` on its own does not**: fed a `grep` it counts **matching lines**, fed `grep -o` **occurrences**, fed a file list **members**. The number in the slice counts **the thing being enumerated** — consumers, call sites, declarations, files — with the sweep's own count beside it, named with its command; otherwise an implementer who re-measures cannot tell a short list from a different instrument.
- **A count offered as evidence names its baseline too**: two counts of one quantity against two trees are not comparable however fixed the unit.
- **Read the exit status and the stderr before you write *no consumers*.** A suppressed error is indistinguishable from a clean no-match, which is why `2>/dev/null` is *banned* on a search; so is a search that never ran — a rejected regex, a glob the shell ate, a printer truncating each line before the match.
- **Exclude the query from its own answer** wherever the command can see itself, as a process match on its own command line does.

**`Owns` (Step 3) carries this failure inverted** — a brief that kept a query's cardinality and threw away its members (*40 references, find them, they are yours*); the list and the count ship together.

---

## Step 2 — Validate the plan and fill the gaps

Grounding almost always surfaces holes: unspecified behavior, an open design fork, missing acceptance criteria, ambiguous scope, an implied but unstated constraint. **Slicing a plan with holes buries them inside slice briefs where an implementer hits them mid-build.**

**Fill what you can yourself — that's the job, not a shortcut.** Most gaps are resolvable from the grounding you did: an existing pattern, `AGENTS.md`/config, the pre-launch/forward-only posture, a plainly obvious default. **Adopt the answer and write the assumption down explicitly** in the affected slice's brief (`Assumes X (existing pattern in <file>); flag if wrong`) rather than interrupting the user.

**Escalate only the gaps you genuinely can't resolve** — no obvious default, guessing wrong would change the slicing or send an implementer down the wrong path, and the codebase and conventions don't settle it: a product decision, a design fork with no house style, an undefined acceptance bar that gates other slices. Don't ask what one more file would answer.

**Hold a question to the same bar as an issue — a question handed up is a deferral wearing different clothes.** That is the bar `skills/orchestrate/SKILL.md` §4 applies to a reconcile finding before filing it, including the rule that gates it: establish *why a thing is the way it is* before you disposition it.

**When you must ask, ask in plain chat — ONE question at a time.** State the gap, give your recommendation and why, ask the single most decision-blocking question, wait, fold the answer in, then ask the next only if still open. No option-picker dialogs, no batched wall. If the user is unavailable and a gap is non-blocking, proceed with the stated assumption and mark it.

**Validate the horizon; past it, validate only what changes the shape** — a gap three waves out blocks only if it moves a wave boundary, changes the epic-branch answer, or creates a seam. This pass runs once per increment, so a bar set slightly too wide costs a user turn every cycle.

---

## Step 3 — Slice the horizon into independent tasks

One slice = one worktree = one PR. **Optimize for independence**: slices that are *cohesive* (one logical change) and *isolated* (a disjoint set of files) are the ones a dispatcher can run concurrently.

**Everything this step produces is *slice depth*, and slice depth is for the horizon only.** Outside the horizon an item carries what **shape depth** allows — goal, area, what it depends on, why it comes after the thing before it — and **none of the grounded fields**: no branch name, no owned files, no boundaries, no derived artifacts, no framework skill, no model tier, no brief, no verify bar. Both errors are silent: an item past the horizon at slice depth carries coordinates a later wave invalidates, and a horizon item left at shape depth is dispatched with no scope, so the implementer invents its own.

For **each horizon** slice, produce:

- **Title** + **branch name** with the right prefix (`feat/…`, `fix/…`, `refactor/…`, `docs/…`). Flag a docs-only slice for `execute`'s ticket-scoped `--mode docs` gate (its *Gate mode*), which is set on the ticket at enqueue and never inferred from the branch name.
- **Owns (scope)** — the concrete files, globs and directories this slice may change, as real paths from your grounding.
  - **A predicate is not a scope until it has been evaluated**: *every caller of `<helper>`* names a file set that does not exist yet, so run the query while grounding and check what it returns against every sibling's `Owns`, or declare the slice **exclusive over the predicate's whole domain**.
  - **The docs the slice falsifies, named individually**, plus a one-line not-affected-because for any you left out — an implementer told a doc is out of scope will not revisit it. **A surface with NO doc is a scope entry too**: name the doc that should describe it, marked as needing **new prose**.
  - **The tests Step 1's caller sweep came back with**, each with its disposition — `Owns` is the files the slice may CHANGE, never the files it opens to do the work.
  - **On an epic a named doc carries one of THREE dispositions, not two**: ledger entry, coordinate fix, or both. Docs mostly leave *edit* scope to the closing docs slice, except a structural coordinate the slice moves — a file path, or a route literal in the same clause — which it repoints in its own PR, since a checker can tell that is stale without reading the sentence. Write down which: read as ledger-only the slice reds a path-citation gate, read as edit-scope it rewrites the paragraph the closing slice was going to.
- **Do NOT touch** — files another slice owns, or that a foundational slice will change. Name them explicitly; these are the collision guards.
  - **A boundary fences BEHAVIOUR, not coverage: a directory or module glob does NOT imply the tests under it**, so a fence meaning to take the module's test file must say so in words. **Whenever a verify bar asserts something about a module the slice does not own, say in the fence which way the tests go**; where the assertion belongs to the fenced module *and* the slice must not own it, that is a seam — name its owner or a later wave.
  - **Say what a slice does when it finds something trivially untrue INSIDE the fence**, or its only move is to file an issue. **In scope after all**: name the class of finding it may correct there, where correcting it is not the behaviour the fence guards. **Or out of scope, so filed**, with the filing carrying the line saying where its premises were established (`skills/execute/references/implementer.md`'s *File your follow-ups BEFORE you hand back*). Where you cannot tell in advance, say **that**, and say the slice stops and reports rather than widening its own fence.
  - **Don't split the fence** into *do not change this behaviour* versus *do not go near this file*: that hands the call to the party furthest from what a slice will find.
- **Derives** — the artifacts this slice feeds whose correct contents are a function of the **whole tree**, not of any one slice's files: a ratchet ledger, a regenerated backlog JSON, a generated type, an unimported-exports manifest. This is the collision `Owns` and `Do NOT touch` cannot cover, where two slices edit disjoint sources, each correct, and the artifact is right on neither branch and merges clean; Step 1's regenerator sweep fills the field. **A slice may not treat a derived artifact as final**, so write both clauses into the entry beside the path — `reports/unimported.json — regenerated from the whole tree; report the delta, don't hand-edit` — since a bare path reads as ordinary scope. The dispatcher re-derives on the merged tip before gating (`skills/execute/references/landing.md`).
- **Depends on** — which other slices must merge first (or "none — independent"). This builds the waves.
- **Skill to invoke first** — the framework skill the implementer opens with, from `AGENTS.md`/config. For Trinity, **app = `frameworks:solid`, sidecar = `frameworks:effect-v3`**; a full-stack slice invokes both, a pure docs/config slice none.
- **Model** — `sonnet` (well-scoped, mechanical, mirrors an existing pattern) or `opus` (subtle algorithms, design-heavy, tricky concurrency, security-sensitive, large cross-cutting), with one line of *why*; the easier the model, the more explicit the brief — a sonnet slice needs near-deterministic steps and exact files. **Then apply the predictor that catches what that list cannot: does the slice touch something declared, or enforced, in more than one place?** If so the work is adjudicating a disagreement between two sources of truth nobody has checked agree, and wants the stronger model however small the diff.
- **Brief** — 2–5 sentences the dispatcher can hand almost verbatim to an implementer: what to build, the pattern or file to copy, the hard boundaries, any research-first step.
  - **Point at the source, never at your conclusion about it** — *read the route handler and use the schema it parses the body with*, not *use `FooRequest`*, since an implementer cannot tell a name you verified from one you inferred.
  - **A claim lifted from a dependency's own docs or generated output is an INPUT to grounding, not a grounded coordinate**: it states the **general** case where your brief states the **local** one, so settle which branch of that hedge this repo is on, or write `Assumes X; flag if wrong`.
  - **Where the prose you are briefing about SHIPS to other repos, cite it by path**, since a bare `README.md` or `AGENTS.md` there names the **reader's** repo: such a sentence may **instruct** (*consult your repo's own doc set*) and may never **cite** (*this corpus argues X there*).
  - **A measured VALUE you hand down carries its tie-break with it** — a test total, a timing, a row count, a file count, the size of a set. Write beside it that the implementer **re-measures before changing anything**, that **the implementer's number wins**, and where yours came from. **And write what the number COUNTS**, naming the unit or command (*7 lines*, *18 occurrences*, *4 files*), since a tie-break cannot settle a disagreement that is a unit. **A number INHERITED from the plan rather than measured is one you measure here**, or write `Assumes N; flag if wrong`; a number in `Verify` takes the same sentence.
- **Verify** — what "done" looks like: the behavior, the tests to add or touch, the acceptance check.
  - **For a slice that adds a check or fixes a bug, the bar includes proving the new test fails against the PRE-change code — and names the specific reversal that proves it**: restore the old matcher and confirm the new fixture goes red, point the test's mock back at the old symbol, reverse the rename and confirm the formatter reproduces the original byte for byte. A bare "confirm it fails first" is a step an implementer can report with nothing behind it.
  - **When the bar asserts agreement with a consumer the slice does not own, name the INSTRUMENT as well as the property, and make it the entry point the production caller reaches** — otherwise the cheapest instrument is a local reimplementation that diverges on the day the test was supposed to fire, and calling the consumer's matcher below its callers' preprocessing reports coverage the real pipeline does not provide. A stand-in is allowed only where the slice names it and justifies it. **Name the consumer-side reversal too**: break, stub or swap the consumer and confirm red.
  - **A bar that ships a COMMAND states the property in words as well, and you CHECK the command against the property on a case the slice is expected to produce** — an instrument narrower than its property fails a correct slice, a wider one passes an incorrect one, and only the narrow direction is ever visible.
  - **A whole-package or whole-suite check named here is the RUNNER's to execute, never the implementer's**: when the bar names the gate it is fixing the ticket's **gate mode**, so write it that way (*gate in the default mode, not `--mode docs`*) rather than as a command line (`skills/execute/references/per-project-config.md`'s *Gate mode*). **The only check an implementer may be told to run directly is a single targeted test file**; route anything wider through the project's cached runner (Trinity: `pnpm check`, or `turbo run <task> --filter=<pkg>`), never raw `vitest`/`tsc`/`eslint`.
  - **A bar that asserts a NEGATIVE names what it is measured against** — *X is unchanged*, *no new Y*, *that grep comes back empty* are claims about a difference, and the end an implementer reaches for is its own previous commit, which sits **inside** the change. Make the baseline the **fork point** unless you name another; a sweep is the exception, naming its **domain** instead. **Where the honest claim is narrower than the bar's phrasing, write the narrow one** — *unchanged for a caller who has not opted in*.

**Sizing.** A slice should be a meaningful but reviewable PR — not so small that the worktree and PR overhead dominates, not so large that it owns half the repo. Where two candidates can't avoid heavy file overlap, merge them or sequence them across waves.

**Size against the gate, not against an idealized infinite machine.** `/pipeline:execute` drains the queue one PR at a time behind a slim machine-wide slot, so N slices means N sequential gate runs plus N reviews. **Make each slice carry enough weight that its share of the gate cost is justified.**

- **A gate run's cost is proportional to what the slice CHANGED, because of the shared build cache**, so **prefer package-disjoint slices** and keep an edit to a low-level shared package — which invalidates every dependent however small the diff — in a *tight Wave-0 slice*.
- **Fold sub-PR fragments**: a rename, a one-liner, a single test does not deserve its own worktree and gate. **Bound wave width to the gate, not to file-independence**, and **when you catch yourself splitting for "cleaner boundaries" alone, stop** — split only when the slice is too big to review *or* the split removes a real merge collision.
- **File-disjoint is not independent when the slices share a resource that lives outside the worktree — the one entry here that can make the right wave width ONE.** A worktree isolates the filesystem and nothing further, so two slices touching no common file still contend for one database, Redis instance, cache directory or fixed port. Read `sharedResources` in the project's `.agents/worktree.json` (`skills/execute/references/per-project-config.md`): `"isolatedBy": null` says the resource stays shared, and the key **missing entirely** says nobody has been asked — not an answer, and not a no. The drained gate does not cover it: the slot serializes *gates* and never sees the implementers' `scopedCheck` and targeted test runs. Size the wave against the resource — one live slice touching it, the rest sequenced.
- **Gate once on the merged tip and the binding constraint moves to the dispatcher's own capacity to read N diffs.** An epic gating as a whole (`skills/execute/references/landing.md`) barely pays the per-slice cost, so size that wave against the reading: a green gate cannot tell whether the agent solved the right problem.
- The *scoped* per-commit check implementers run is NOT the sizing cost; the **drained full gate** is. Size against the *actual* `gate`, cache and drain model you read in config.

**Before you emit a slice, read its fields against each other — as these four PAIRS, never as a general check of your work.** Nothing downstream reads any two fields against each other and you are the only party holding all of them at once, so a slice can be internally unsatisfiable and still look finished: the implementer meets one field by breaking another and reports the half it met, and no gate can read a brief.

- **A fence against the verify bar** — `Do NOT touch` against `Verify`; the worked example is a glob and an assertion that both land on the same test file, and the `Do NOT touch` field carries the two rules that settle it.
- **A content requirement against a style constraint** — two halves of one `Brief`, or a `Brief` against the conventions the slice inherits, each satisfiable alone and contradictory only in the pair.
- **Any requirement against the vocabulary the target actually has** — a brief can demand a distinction the target cannot express, as a chapter told to say which consumer a rule is for, in a corpus whose pages never name their readers. That is **satisfiability**, not style: no wording satisfies it, so the implementer invents vocabulary the medium lacks or drops the requirement.
- **A derivation instruction against reachability from where the slice lives** — a `Brief` saying *derive X from Y* against the workspace position the slice's `Owns` sits in. The pair above is expressibility; this is reach: the symbol exists and the derivation is expressible, but there is no path to it from the slice — the wrong side of a workspace boundary, a package the slice does not depend on — and Step 1's research establishes only that Y exists *somewhere*. **Resolve Y from where the slice lives before writing the sentence**, or the implementer transcribes the values the derivation would have produced, the slice goes green, and the false premise is contradicted nowhere (`skills/execute/references/implementer.md`'s *A brief that contradicts ITSELF*).

---

## Step 4 — The parallelization plan (the part the loop steers by)

The dispatcher needs the **shape of the parallelism**, and the loop needs a dependency order to move the horizon along. **The wave map covers the whole arc; the grounding does not** — a dependency ordering names no files, so waves to the end of the arc are *shape*, and they are required rather than merely allowed, because the horizon is *defined* as the next set whose dependencies have landed.

- **Waves.** Group slices by dependency: **Wave 0** is the foundational layer that must land first — a schema change, a shared type, a renamed module, a new core service — and Wave 1+ are the consumers that run in parallel once it merges. **Say which wave is the horizon**: the earliest whose dependencies have all landed, and the only one you grounded. Where it is only the dispatchable part of a wave, don't promote the rest on the strength of its blocker landing soon.
- **Transient-red window.** Flag a breaking wave-0 change (NOT-NULL schema swap, required interface field, renamed export) and name the slices living in the window, since the branch's gate won't be green until every consumer migrates. **Your flag is also what tells `/pipeline:execute` to OPEN the window** — it cuts a `transient-red/<epic-slug>` marker ref, the only form of the fact anything inside a slice worktree can read.
- **Epic branch — answer it explicitly, every time, in one line — when it is yours to answer.** An epic branch is a convergence branch cut from the integration branch that an epic's slices fork from and PR into, so the shared branch never carries the epic half-finished; `/pipeline:execute` owns its lifecycle, and you are the pass positioned to see whether it is warranted.
  - **Two rules reach for one, and they answer different questions.** *Would a partial state on the shared branch be broken?* — if any intermediate state leaves the integration branch unshippable, recommend one at any width from two slices up and name that state: a wave-0 change every consumer must follow, or a **contract seam** whose halves must land together. *What does landing one change as N separate merges cost, whether or not each state would ship?* — **multi-slice work defaults to an epic branch** (`skills/execute/references/worktrees-and-branches.md` → *Two rules reach for one* carries the accounting). Answer the first even on a multi-slice arc: it decides whether the epic is **knowingly red**, which opens the transient-red window. Where neither fires, say "not needed" and why — an unanswered question reads as "no".
  - **Neither rule is a slice count, and neither is a busy integration branch**: counting slices measures how long a partial state sits on the branch, never whether it is broken, and the second rule keys on **one change decomposed into slices**, so unrelated one-slice fixes side by side are not an epic. **Single-slice work never cuts one.**
  - **A stated instruction settles it — the rules above are for when nobody has decided.** "Do it as an epic" means the branch is decided: read `skills/execute/references/worktrees-and-branches.md` for the **mechanics** and slice against it. **A skill's decision procedure never overrides a stated instruction — once the call is made, the skill is read for how, not for a second opinion.**
  - **Reconcile the answer against the seam map you just produced** — you cannot answer "not needed" over a contract seam whose halves land in different waves, or a wave-0 change every consumer must follow, without naming it and saying why it does not count.
- **Conflict map.** Name any pair of slices that will touch the same file (both add a route to one registry, both add a case to one exhaustive switch); the dispatcher resolves these **at merge time**, never by rebasing.
- **Shared hotspots — hoist the seam in Wave 0, don't just name the conflict.** **3+ slices all extending one structure** — a control loop's `tick()`, a reducer, an event handler, an exhaustive switch — is a decomposition smell: they fork off different bases, so the merges come out textually clean (git reports `MERGEABLE`) and behaviorally wrong, each adding its case only to the siblings that existed when it forked. Land the extensibility seam first — an interface, a registry, a `Monitor[]` the others *register into*. When you can't, do both: emit the **shared invariant** into every touching slice's brief (*"every parked-state branch must freeze ALL kill-clocks"*), and mark the hotspot so `/pipeline:execute` reviews the merged region semantically rather than just resolving markers.
- **Contract seams — who *defines* a shape someone else *consumes*.** Neither the conflict map nor the hotspot list catches slices sharing **no file at all** that still break each other over a return type, a schema field, a tool grant, a prompt variable or a config key: both gates are green and the break appears only when both are on the branch. Emit a second, separate map: **producer → consumer → the shape between them → what the consumer does with it.**
  - **A row is not FINISHED until you ask what the consuming side DOES with the value.** A consumer that only *filters* is safe; one whose read feeds an **action** — a charge, a send, a delete, a state transition — is the seam, because that action can be computed from something captured before the producer's value could exist. It bites hardest on a status or flag, where enumerating the readers terminates quickly and looks exhaustive while what matters is what happens to a row after a read selects it.
  - **Two seams a file map structurally cannot see**: producer and consumer in **different languages or trees** (code defining a value that documentation or a prompt describes), and a seam with **no compiler between the halves** (a config, a prompt template, a generated brief).
  - Every seam whose halves land in different waves is evidence for the epic-branch answer above — reconcile the two before emitting either.
  - **From the loop, what you emit is one cycle's contribution to an arc-level union, not the arc's map.** Read the union `skills/orchestrate/SKILL.md` section 7 carries, name the seams the arc already holds that this horizon closes, and hand your new rows to it; a missing row reads exactly like a seam that was closed. On the direct paths there is no union and your map is the whole of it.
- **Scaffolding is planned with its teardown, in one plan** — the check, its fixture, its ledger and its documentation removed in one slice rather than a trail of partial removals. **Write the teardown's precondition down when you plan the build**: it depends on every draining slice, and its verify bar names the state that makes it legal (the ledger at zero, the last consumer migrated). An empty ledger reads as an invitation, so an unwritten precondition lands the teardown while the thing it enforced is still incomplete; a teardown never planned leaves dead scaffolding that reads as live machinery.
- **Don't schedule documentation of a model another slice is changing** — it must land *after* every slice that changes it, or it documents a shape that no longer exists and nothing fails. Docs for a part this epic does not touch are exempt and should say so in the wave note. **In an epic this becomes a slice**: a closing docs slice, last in the map, depending on every other, consuming the falsification ledger and writing against the final tree (`skills/execute/references/worktrees-and-branches.md`) — named in the wave map, and **given both inputs, because the ledger alone is short by construction**: it derives rows from what the epic **added** and reconciles them against what it inherited.
- **Critical path.** One line: the longest dependency chain (wave 0 → its slowest, most-coupled consumer), so the dispatcher knows where to start and what gates the finish.

Be honest about what is genuinely sequential. **Real independence > optimistic independence.**

---

## Step 5 — Emit the breakdown

### In-chat path — output format

Lead with the parallelization plan (waves + critical path), then the horizon's slices at slice depth, then the remainder at shape depth. **Label every item's depth, and keep the two in separate sections — never interleaved**: an unlabeled shape item reads as a slice somebody left half-finished, and both repairs are wrong — dispatch it and the implementer gets no scope, "finish" it by grounding it and you have written the stale coordinates the horizon exists to prevent.

Use this shape (the arc here is mid-flight, Wave 0 already merged; on a first cycle the horizon is usually Wave 0 alone and every later wave is shape):

```
## Decomposition: <plan title>
Integration branch: release/x.x.x   ·   Epic branch: <epic-branch> (or: not needed — <why>)
Horizon: Wave 1 — Slices 2, 3, 4

### Parallelization plan (whole arc — dependency shape, not grounding)
- Wave 0 (landed): Slice 1
- Wave 1 — THE HORIZON, grounded below, dispatch now: Slices 2, 3, 4
- Wave 2 (after W1 — shape depth, grounded next cycle): Slice 5
- Wave 3 (last — the closing docs slice; consumes the falsification ledger, and derives from what the epic added): Slice 6
- Transient-red: Slices 2–4 run against the W0 schema change (gate read per execute's transient-red rules)
- Epic branch: yes — the W0 schema change leaves the branch half-migrated until Slices 2-4 land; slices fork from and PR into it
- Conflicts to merge-resolve: Slice 3 & 4 both edit src/routes/registry.ts
- Critical path: Slice 1 → Slice 4 → Slice 5 → Slice 6

### Horizon — SLICE DEPTH (grounded against the tree as it stands right now)

#### Slice 2 — <title>
- Branch: `feat/<leaf>`   ·   Wave: 1   ·   Depends on: Slice 1 (merged)   ·   Model: opus (subtle migration)
- Skill to invoke first: effect
- Owns: sidecar/services/foo.ts   ·   docs/foo.md: repoint the moved path (coordinate fix, ships here); §"Retention" prose → ledger entry; the new eviction hook has no prose anywhere → ledger entry marked needs-new-prose
- Do NOT touch: any UI under app/ (Wave 2 owns those)
- Derives: reports/unimported.json — regenerated from the whole tree; report the delta, don't hand-edit
- Brief: <2–5 sentences>
- Verify: <acceptance + tests, incl. the reversal that proves the new test fails pre-change>

#### Slice 3 — <title>
...

### Beyond the horizon — SHAPE DEPTH (deliberately not grounded: no file:line, no owned files, no boundaries, no model tier)

#### Slice 5 — <title>
- Wave: 2   ·   Depends on: Slices 2–4
- Goal: let a user pick the retention window the W0 schema change made storable
- Area: the settings UI
- Why it comes after: it renders the field Slice 2 adds, so its shape is not decided until Slice 2 merges

#### Slice 6 — the epic's closing docs slice
- Wave: 3   ·   Depends on: Slices 2–5
- Goal: answer every falsification-ledger entry — corrections and needs-new-prose alike — reconciled against what the epic added, written against the final tree
- Area: the user-facing doc set
- Why it comes after: each entry describes a state not final until the last slice merges
```

**The epic branch's *prefix* carries no mechanical meaning; its *leaf* does** (`skills/execute/references/worktrees-and-branches.md` → *Mechanics*), so that slot takes the real branch name. **It should not read like a slice branch**, or it is indistinguishable in a PR list from the `feat/<leaf>` slices merging into it. **And its leaf must be one no slice branch you name reuses** — `setup-worktree.sh` derives a worktree's directory from the leaf and refuses a second branch resolving to the same one, and the likeliest collider is the closing docs slice. Check it every cycle against the slices you are grounding now.

End with the handoff line, verbatim intent:

> **Horizon ready to dispatch.** `/pipeline:orchestrate` takes it from here: it dispatches this increment through `/pipeline:execute` — a worktree per slice, implementers, gate, PR review, merge — then reconciles the remainder against the tree the increment actually produced and moves the horizon. Say that whether the loop invoked you or a user did; the next step is the same either way.

Then **stop.** Do not start making worktrees or writing code, and do not ground the next wave while you are here: the tree that wave will run against does not exist yet.

### GitHub path — see *Writing it back to GitHub* below.

---

## Writing it back to GitHub

For the issue path, decide **comment** vs **umbrella + sub-issues**. Read the issue, ground it (Step 1), validate and fill gaps (Step 2), slice it (Steps 3–4), then choose:

### Comment (the default)

When the work is small-to-medium — a handful of slices that are clearly one release effort and don't each need independent tracking — **post the whole breakdown as a single comment** on the issue, carrying both depths and their labels exactly as the in-chat format does. The loop reads the comment and dispatches the horizon from it.

### Umbrella + sub-issues (when warranted)

When the work is **large and multi-area** — many slices, several waves, slices deserving independent assignment, review and closure — **convert the issue into an umbrella**:

1. **Rewrite the issue body** into an umbrella overview: the goal, the parallelization plan (waves, conflict map, critical path), and a **tracked checklist** linking each sub-issue (`- [ ] #<sub>`), which GitHub renders as progress.
2. **Create one sub-issue per horizon slice** (or per tightly-coupled cluster) carrying that slice's full brief — scope, do-not-touch, depends-on, skill-to-invoke, model hint, verify. Beyond the horizon, a slice gets a checklist line or a placeholder sub-issue and no brief. Title each with its wave (e.g. `[W1] <title>`) so the dispatch order is visible at a glance.
3. **Link them as native sub-issues — always, never an optional extra.** The relationship is a plain REST endpoint that is simply there and *GitHub write mechanics* below carries the exact call, so there is no availability to condition on. **The native link is also what makes the reader-side check in Step 1 cheap**: its first step is one `/parent` call, which 404s on every child of a markdown-only umbrella and forces an arriving agent onto the timeline fallback. And *always* keep the `- [ ] #<sub>` checklist too — it is the index reviewers scan, and the artifact that fallback matches on.
4. Label the umbrella (`epic`/`umbrella` if such a label exists; create nothing exotic).

Warrant the umbrella; don't reflexively shard a 3-slice issue into 3 issues. Rule of thumb: **umbrella when slices span multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**

**A sub-issue may exist ahead of the horizon; a grounded brief may not.** File a beyond-horizon slice as a placeholder when you want it tracked — title, wave, goal, area, depends-on — marked on its face as *shape depth, not yet grounded*; it gets its owned files, boundaries, model tier and verify bar when the horizon reaches it. A sub-issue reads as a brief at whatever depth it was written, so an ungrounded one gets dispatched from as though finished, and a prematurely grounded one hands an implementer coordinates an intervening wave has moved. The umbrella **body** is the live remaining plan, rewritten every cycle rather than appended to; `skills/orchestrate/SKILL.md` section 7 owns that state model.

### GitHub write mechanics (important)

- **Use `gh api` (REST), not `gh issue create`/`gh issue edit` for the writes** — the high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't. Read with `gh issue view` is fine.
- **Write the body to a file and reference it with `-F` (not `-f`).** `-f` is `--raw-field` and sends its value verbatim, so the `@file` form stores the literal string as the comment; only `-F` expands a leading `@` into the file's contents. It fails in the worst direction — the command exits 0 and prints a comment URL, so the run reports success and the damage is visible only to a human opening the issue. **Verify after**: refetch the body and confirm it's the markdown, not the literal path.
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"` (a temp file also spares you quoting hell with long markdown).
  - New sub-issue: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>"`, then capture the returned number. The title stays `-f` — a genuine literal; only the `@file` value needs `-F`.
  - Edit umbrella body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`.
- **Native sub-issue link:** `gh api -X POST repos/{owner}/{repo}/issues/<umbrella>/sub_issues -F sub_issue_id=<child's DATABASE id>`. Two traps, both failing in a direction that reads as "this endpoint is unavailable":
  - **`sub_issue_id` is the child's database id (`.id`, e.g. `5261102081`), NOT its issue number** — different fields on the same object, both plain integers, so nothing about the value's shape distinguishes them. Passing the number returns a bare `404 Not Found`, which reads as *"this endpoint doesn't exist"* rather than *"wrong id"*, so the step gets quietly skipped — exactly how an umbrella ends up markdown-only. Take the id from the create call's own response, or `gh api repos/{owner}/{repo}/issues/<n> --jq .id`.
  - **`-F` here is doing TYPE work, not `@file` expansion — the rule above does not carry over.** That rule keeps genuine literals on `-f`, and an id is a literal, so `-f` is the natural reach; but `--raw-field` sends the id as a **string**, which the endpoint rejects with `422 Invalid property /sub_issue_id: not of type integer`. Only `-F` types a bare number as a JSON integer, so both flags fail on a wrong id with two different errors and neither saying *use the other flag*.
- **Cross-reference, don't auto-close.** Each sub carries `Part of #<umbrella>` in its body and the umbrella carries that sub in its `- [ ] #<sub>` checklist — both directions, every time; `skills/write-issue/SKILL.md` Step 4's *Umbrella linking* is the authority on why the backlink is a rule rather than a formatting nicety. The dispatcher then closes each sub by hand as its PR merges, never a `Closes` keyword — `skills/execute/references/landing.md` carries when one fires and why the hand-close is right either way.
- End your turn by telling the user what you wrote (umbrella and sub-issue numbers, or the comment link) and the same **Horizon ready to dispatch** handoff.

---

## What decompose does NOT do (hard boundaries)

- **Never ground beyond the horizon** — no `file:line`, no owned-file list, no boundaries, no framework skill, no model tier, no verify bar on any item outside the next dispatchable set, however well you understand it and however directly a user asked. Grounding more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the paths.
- **No code.** You never edit source files; if you catch yourself opening one to change it, stop.
- **No worktrees.** Never `setup-worktree.sh`, never the Agent tool's `isolation: "worktree"` param, never provisioning anything. Decompose is read-only against the working tree, plus GitHub writes on the issue path.
- **No dispatch, no merge.** You don't spawn implementer sub-agents to build and you don't merge PRs. (Read-only `Explore` agents in Step 1 are grounding, not building.)
- **Don't over-decompose.** Coordination that costs more than it saves is a regression, and the gate is a real serialized cost (*Sizing*).
- **No loop.** Reconciling a landed increment, deciding what folds in and what gets filed, and rewriting the plan are steps of `/pipeline:orchestrate`'s loop (its section 2) — a pass that reconciles as well as grounds does it against the tree it read at the top of its own turn, the one tree that cannot falsify anything.
- **Hand off, then stop.** Your turn ends at the breakdown plus the handoff line.
