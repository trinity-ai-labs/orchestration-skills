# Grounding the ready issues, and sizing the wave

Reference for `skills/ground/SKILL.md`, action 3. **Every field below is what you produce PER ISSUE — one
ready leaf, ground whole** (`skills/glossary/vocabulary/umbrella.md`) —
**never an instruction for carving one up**, since two slices out of one issue land work no tracked item
stands for. **Optimize for independence**: issues that are *cohesive* (one logical change) and *isolated* (a
disjoint set of files) are the ones a dispatcher can run concurrently. Every field below is *slice depth* and
belongs to the horizon alone (`skills/glossary/vocabulary/grounding-depth.md`).

<!-- gate-anchor:enum-3:begin -->
## The slice fields

For **each horizon** slice — one ready issue, ground as the one slice it already is — produce:

- **Title** + **branch name** with the right prefix (`feat/…`, `fix/…`, `refactor/…`, `docs/…`). Flag a
  docs-only slice for the project's lighter gate, which is set on the ticket at enqueue and never inferred
  from the branch name.
- **Owns (scope)** — the concrete files, globs and directories **this slice owns**, as real paths from your
  grounding. **Ownership is an ASSIGNMENT before it is a permission**: the list is a floor on what the change
  must reach, never a ceiling on what it may touch.
  - **Two slices wanting the same file is NOT a reason to split a wave, delay one, or invent an ordering.** A
    shared path means a merge conflict, and a merge conflict is a routine thing resolved in under a minute by
    whoever merges second. Splitting the wave to avoid one costs a whole cycle; rewording a fence to avoid one
    costs a defect left standing. Note the overlap so the second merge expects it, and run them together.
  - **A predicate is not a scope until it has been evaluated**: *every caller of `<helper>`* names a file set
    that does not exist yet, so run the query while grounding and check what it returns against every
    sibling's `Owns`, or declare the slice **exclusive over the predicate's whole domain**.
  - **The docs the slice falsifies, named individually**, plus a one-line not-affected-because for any you
    left out — an implementer told a doc is out of scope will not revisit it.
    **A surface with NO doc is a scope entry too**: name the doc that should describe it, marked as needing
    **new prose**.
  - **The tests the caller sweep in `skills/ground/references/grounding.md` came back with**, each with its
    disposition.
  - **An entry may carry a DISPOSITION, and where it does that disposition BINDS.** The two cases this field
    already sanctions — the tests a sweep returned, above, and a doc on an epic, below — are instances rather
    than the extent, and one on any other kind of path is this field doing the same thing.
    **Write both clauses into the entry beside the path**, the way
    `Derives` does — `docs/mental-model.md — ledger entry only; record what this falsifies rather than
    rewriting it` — since a bare path reads as ordinary scope and a disposition left out of the entry reaches
    nobody. **It narrows the KIND of edit that path takes and never what the change must reach**: the field is
    a floor still, and a path carrying a disposition is a path the change must land on.
  - ⛔ **`Owns` is a FLOOR, never a ceiling — the files the change must reach, not the only files it may
    touch.** Everything neither owned by this slice nor named in its `Do NOT touch` is the UNLISTED MIDDLE,
    and the unlisted middle is fixable: a slice that finds something broken there repairs it in the PR it is
    already building. Read as a closed allowlist instead, this field silently reclassifies every defect
    outside it as somebody else's — which is what turns a one-line fix into a filed item, a read, a
    discussion, a worktree, an agent, a gate run and a merge. A grounding pass that wants a path left alone
    says so in `Do NOT touch` and gives the reason; silence means fix it.
  - **On an epic a named doc carries one of THREE dispositions, not two**: ledger entry, coordinate fix, or
    both. Docs mostly leave *edit* scope to the closing docs slice, except a structural coordinate the slice
    moves — a file path, or a route literal in the same clause — which it repoints in its own PR, since a
    checker can tell that is stale without reading the sentence. Write down which: read as ledger-only the
    slice reds a path-citation gate, read as edit-scope it rewrites the paragraph the closing slice was going
    to.
- **Do NOT touch** — files another slice owns, or that a foundational slice will change. Name them explicitly;
  these are the collision guards, **and collision is the whole of what they guard**.
  **Keep this field nearly empty.** What it prevents is a merge conflict, which is a routine thing a developer
  resolves in under a minute; what it costs, whenever it is drawn wider than a file somebody is editing this
  very moment, is a defect left standing and a unit of work invented to go back for it. That trade is almost
  never worth making. Where two slices do collide, the answer is to resolve the conflict like any other. This
  field is not a scope statement and carries no judgement about what is worth fixing: a path belongs here
  because a concurrent editor would conflict with it, never because the work there looks like somebody else's
  problem. A fence with nothing live behind it is a defect left standing for no reason.
  - **A boundary fences BEHAVIOUR, not coverage: a directory or module glob does NOT imply the tests under
    it**, so a fence meaning to take the module's test file must say so in words.
    **Whenever a verify bar asserts something about a module the slice does not own, say in the fence which
    way the tests go**; where the assertion belongs to the fenced module *and* the slice must not own it, that
    is a seam — name its owner or a later wave.
  - **A slice that finds something untrue inside a fenced path FIXES it unless the fence is live.** A fence
    names a file another agent is editing right now; where that agent exists, the slice asks rather than
    collides, and where the fence is stale or nobody is behind it, the fix is simply made. Neither answer is
    ever a ticket. Say which case a given fence is, so the slice is not left guessing between correcting the
    thing and sitting on it.
  - **Don't split the fence** into *do not change this behaviour* versus *do not go near this file*: that
    hands the call to the party furthest from what a slice will find.
- **Derives** — the artifacts this slice feeds whose correct contents are a function of the **whole tree**,
  not of any one slice's files: a ratchet ledger, a regenerated backlog JSON, a generated type, an
  unimported-exports manifest. This is the collision `Owns` and `Do NOT touch` cannot cover, where two slices
  edit disjoint sources, each correct, and the artifact is right on neither branch and merges clean; the
  regenerator sweep in `skills/ground/references/grounding.md` fills the field.
  **A slice may not treat a derived artifact as final**, so write both clauses into the entry beside the path
  — `reports/unimported.json — regenerated from the whole tree; report the delta, don't hand-edit` — since a
  bare path reads as ordinary scope. The dispatcher re-derives it on the merged tip before gating.
- **Depends on** — which other slices must merge first (or "none — independent").
  **A REAL dependency is the only thing that sequences anything**: B cannot be built until A exists. Nothing
  else does — not a shared file, not an adjacent subsystem, not two slices that merely look related.
  - **And a short dependency chain is usually ONE slice, not two plus an ordering.** Where A and B are small
    and B needs A, hand both to one agent and let it do A then B in the same worktree. Two slices, two
    worktrees, two gate runs and a wave boundary to express "do these in order" is machinery for something a
    single agent expresses by doing them in order.
- **Skill to invoke first** — the framework skill the implementer opens with: the skill of each
  `frameworkSkills` entry whose `when` matches the slice's area, and none where no entry matches or the
  project declares none. For Trinity, **app = `frameworks:solid`, sidecar = `frameworks:effect-v3`**; a
  full-stack slice invokes both, a pure docs/config slice none.
- **Model** — **standard tier** (well-scoped, mechanical, mirrors an existing pattern) or **top tier** (subtle
  algorithms, design-heavy, tricky concurrency, security-sensitive, large cross-cutting), with one line of
  *why*; name the tier, never a host's model id. **This field is where the tier is DECIDED, and you are the
  seat that read the code, so write the *why* as the reason a dispatcher resolves against rather than
  re-decides**: a dispatcher turns your tier into a host model, may **RAISE** it where it sees what you could
  not — how wide the wave ended up, a slice already back once — with its reason beside it and nobody's
  permission, and may **lower** it only with a written reason in the brief, since the cheaper reading is
  always the defensible one and a silent downgrade leaves nothing behind that records what the slice was
  judged to need. The easier the model, the more explicit the brief — a standard-tier slice needs
  near-deterministic steps and exact files. **Then apply the predictor that catches what that list cannot:
  does the slice touch something declared, or enforced, in more than one place?** If so the work is
  adjudicating a disagreement between two sources of truth nobody has checked agree, and wants the stronger
  model however small the diff.
- **Brief** — 2–5 sentences the dispatcher can hand almost verbatim to an implementer: what to build, the
  pattern or file to copy, the hard boundaries, any research-first step.
  - **Say in it whether this slice warrants a `/pipeline:review` pass and why, on the same reading the `Model`
    field above took** — one predictor answers both, so a mechanical rename mirroring an existing pattern
    earns neither the stronger model nor a fan of readers, while work adjudicating two sources of truth earns
    both, and *Sizing* below prices that fan as the dominant term in a wave.
    **It is a RECOMMENDATION the dispatcher may override with a reason of its own, which is why it rides in
    this field rather than becoming a field of its own** — that seat holds the same facts about the wave it
    raises a tier on. **Write the *no* as explicitly as the *yes*, a one-liner being the clearest *no* there
    is**: a recommendation that only ever says yes is a default yes, which spends on every slice exactly what
    pricing the fan-out was for.
  - **Point at the source, never at your conclusion about it** — *read the route handler and use the schema it
    parses the body with*, not *use `FooRequest`*, since an implementer cannot tell a name you verified from
    one you inferred.
  - **A claim lifted from a dependency's own docs or generated output is an INPUT to grounding, not a grounded
    coordinate**: it states the **general** case where your brief states the **local** one, so settle which
    branch of that hedge this repo is on, or write `Assumes X; flag if wrong`.
  - **Where the prose you are briefing about SHIPS to other repos, cite it by path**, since a bare `README.md`
    or `AGENTS.md` there names the **reader's** repo: such a sentence may **instruct** (*consult your repo's
    own doc set*) and may never **cite** (*this corpus argues X there*).
  - **A measured VALUE you hand down names the commit it was taken on and what it COUNTS** — its SHA beside
    its unit or command (*7 lines*, *18 occurrences*, *4 files*). **On the commit the slice forks from it IS
    the slice's baseline and is never taken again**; where the slice will fork from another commit, the
    dispatcher re-takes the value there before dispatch or has the brief tell the implementer to take it
    before its first edit. **A number inherited from the plan is measured here, not carried**, and a value no
    commit decides — a timing — is one the brief tells the implementer to take before its first edit. A number
    in `Verify` takes the same sentence.
- **Goal** — one line, in outcome terms, saying what this slice is FOR. `Brief` says what to build and
  `Verify` says which commands must come back clean; neither says what the work is for, so a slice without
  this field can be green on every command it was given and miss the point, with no party positioned to notice
  — the gate runs commands, the implementer built to the letter, and the reader at the PR is judging against
  nothing but prose describing the task.
  - **`Verify` is checked by a RUNNER; `Goal` is checked by a READER, and that is the whole distinction.** A
    verify bar is mechanical and falsifiable — a command, a test, a sweep — and it either passes or does not.
    A goal is what the work is for, so only judgment can settle it. Write the goal in the terms whoever asked
    for the work would use, never in the mechanism this slice happens to reach for: a goal written as its own
    mechanism is scored against itself and passes by construction.
  - **You are not inventing this at the horizon, you are KEEPING it.** An item beyond the horizon already
    carries a goal — it is one of the few things shape depth does carry — so a promotion that grounds
    everything else and drops the goal deletes it at exactly the moment it becomes actionable, and the slice
    that reaches an implementer is the first version of that item in the whole arc with no statement of what
    it is for. Carry it across the promotion and sharpen it against what grounding just taught you.
  - **The arc's goal and the phase's deliverable came with the issue; this is that altitude one step down.**
    Carrying it here is what makes the chain end to end rather than stopping at the phase boundary — arc goal,
    phase deliverable, slice goal, and a reader at each of the two ends of the slice.
- **Verify** — what "done" looks like: the behavior, the tests to add or touch, the acceptance check.
  - **For a slice that adds a check or fixes a bug, the bar includes proving the new test fails against the
    PRE-change code — and names the specific reversal that proves it**: restore the old matcher and confirm
    the new fixture goes red, point the test's mock back at the old symbol, reverse the rename and confirm the
    formatter reproduces the original byte for byte. A bare "confirm it fails first" is a step an implementer
    can report with nothing behind it.
  - **A reversal MOVES the implementer's tree, so a bar that names one names the mechanic beside it, or the
    seat performing it reaches for whatever is quickest** — a blind pop off a stack every worktree of the
    repo shares, a copy of the file parked outside git where one `rm` ends it: git holds the work first
    (`skills/ground-rules/SKILL.md`, rule 6 — committed where it is ready, stashed under that seat's own
    marker where it is not), then the breaking edit, the one targeted test, and the restore from that commit
    or that marked entry. **Or write the bar so the reversal runs against the FORK POINT instead**, where
    the pre-change code is already a commit and no tree has to move at all — the cheaper of the two whenever
    the slice's own base still carries the behaviour being broken.
  - **When the bar asserts agreement with a consumer the slice does not own, name the INSTRUMENT as well as
    the property, and make it the entry point the production caller reaches** — otherwise the cheapest
    instrument is a local reimplementation that diverges on the day the test was supposed to fire, and calling
    the consumer's matcher below its callers' preprocessing reports coverage the real pipeline does not
    provide. A stand-in is allowed only where the slice names it and justifies it.
    **Name the consumer-side reversal too**: break, stub or swap the consumer and confirm red.
  - **A bar that ships a COMMAND states the property in words as well, and you CHECK the command against the
    property on a case the slice is expected to produce** — an instrument narrower than its property fails a
    correct slice, a wider one passes an incorrect one, and only the narrow direction is ever visible.
  - **A whole-package or whole-suite check named here is the GATE's, never a run the implementer makes while
    it builds** — a runner executes it on the ticket where the project declares `enqueue`/`drain`, and the
    implementer runs `gate` once, after opening its draft PR, where it declares neither. So when the bar
    names the gate it is fixing which gate runs — the ticket's **gate mode** in a queued project — and you
    write it that way (*gate in the default mode, not `--mode docs`*) rather than as a command line.
    **The only check an implementer may be told to run directly is a single targeted test file**; route
    anything wider through the project's cached runner (Trinity: `pnpm check`, or
    `turbo run <task> --filter=<pkg>`), never raw `vitest`/`tsc`/`eslint`.
  - **A bar that asserts a NEGATIVE names what it is measured against** — *X is unchanged*, *no new Y*, *that
    grep comes back empty* are claims about a difference, and the end an implementer reaches for is its own
    previous commit, which sits **inside** the change. Make the baseline the **fork point** unless you name
    another; a sweep is the exception, naming its **domain** instead. **Where the honest claim is narrower
    than the bar's phrasing, write the narrow one** — *unchanged for a caller who has not opted in*.

<!-- gate-anchor:enum-3:end -->

## Sizing — the evidence you hold, and the width you recommend

**This is WAVE WIDTH — how many of the ready issues go out together — never a slice count you manufacture and
never the phase boundaries themselves**, both of which came with the plan, and a pass that re-cuts either
plans the arc a second time. **And the width is a RECOMMENDATION you hand up rather than a call you make**:
you read the code and the plan, and you cannot see the gate queue, which slices are already live, or what the
running host can take, so what you owe the dispatching seat is the width you argue for and the evidence behind
it, resolved there against the machine. **The pass that reads the code recommends; the seat that holds the
machine decides**, and a seat that departs from your width writes its reason beside it rather than widening a
wave you argued against in silence. **It is a recommendation rather than a tenth slice field** — the nine a
slice carries are the canonical set named at the top of this file, and a width is a property of the WAVE
rather than of any slice in it.

**State the evidence, not only the number, because the evidence is the half only you hold**: which ready
issues are the same mechanical change, which have an ordering between them, which share a contract seam or a
fence, and which owned paths overlap. A bare width carries nothing the seat can weigh against what it alone
can see, so it can only be taken whole or ignored whole.

**And the test is not *can these run in parallel* but *must they be separate*** — an ordering between them, a
contract seam, a fence, or a verify bar that differs is what makes two items two, where
**disjointness is a SAFETY property rather than a reason to split**: it is what makes concurrent work safe
once the plan has already separated them, so reading it as the reason for the separation manufactures slices
the board cannot record. **That test stays yours whatever the seat does with the width**, being a property of
the PLAN rather than of the machine — no queue depth and no host moves it.

A ready issue should already be a meaningful but reviewable PR — not so small that the worktree and PR
overhead dominates, not so large that it owns half the repo — and where it is not, that is the report onto the
issue rather than a re-cut, in either direction. Where two ready issues can't avoid heavy file overlap,
sequence them across waves — and **one shared OWNED path already forces that, however light the overlap
looks**, since the `Owns` constraint above is absolute where this trigger is a matter of degree.

**Size against the gate, not against an idealized infinite machine.** Where the project declares
`enqueue`/`drain`, `/pipeline:execute` drains the queue one PR at a time behind a slim machine-wide slot, so N
slices means N sequential gate runs; where it declares neither, each implementer runs its own, so N slices
means N gate runs with no slot between them. Either way add N review passes —
and a review pass is **several fresh readers rather than one unit beside the worktree and the install, up to
one per dimension, with how many fire that pass's own per-slice call** — so the reader cost is N times that
count rather than N times one — **and the `Brief` field above is where each slice says whether it fires that
fan at all, which is the only place in this pass the dominant term can be argued down.**
**Make each slice carry enough weight that its share of the gate cost is justified.**

- **A gate run's cost is proportional to what the slice CHANGED, because of the shared build cache**, so
  **prefer package-disjoint slices** and keep an edit to a low-level shared package — which invalidates every
  dependent however small the diff — in a *tight Wave-0 slice*.
- **Beside that gate sits CONTENTION, and it is the one axis `sharedResources` structurally cannot
  carry** — that key reads a project's *declared* list and CPU is never on one, so what you state is the shape
  rather than the key. Concurrent implementers, their review readers and their targeted test runs all contend
  with whatever is gating at the same moment — the runner's one gate in a queued project, every sibling's own
  in an in-line one — and a suite with thin timeout headroom reds on load
  alone — a failure that is real, reproducible and nothing to do with the change under it.
  **The reversal is the tell, and a width argued without it sends someone chasing a ghost**: the same commit
  reds under concurrent implementers and passes on a quiet machine, so this is a cost of the width you
  recommended rather than a flaky suite for anyone to fix.
- **A sub-PR fragment — a rename, a one-liner, a single test — still buys a worktree and a gate**, so it is a
  fact about wave width and a note back to the plan — **and where several such leaves are one mechanical
  change with no ordering between them, that note goes onto the issue exactly as an oversized one does,
  answered where issues are authored by re-authoring those leaves as one** — never two tracked items you merge
  here. **Bound wave width to the gate, not to file-independence**, and where an issue is too big to review as
  one PR report it rather than splitting it, since a split performed here is the one move that leaves the
  board unable to record what landed.
- **File-disjoint is not independent when the slices share a resource that lives outside the worktree — the
  one entry here that can make the right wave width ONE.** A worktree isolates the filesystem and nothing
  further, so two slices touching no common file still contend for one database, Redis instance, cache
  directory or fixed port. Read `sharedResources` in the project's `.agents/worktree.json`:
  `"isolatedBy": null` says the resource stays shared, and the key **missing entirely** says nobody has been
  asked — not an answer, and not a no. The drained gate does not cover it: the slot serializes *gates* and
  never sees the implementers' `scopedCheck` and targeted test runs, and a project declaring no
  `enqueue`/`drain` has no slot at all. Size the wave against the resource — one
  live slice touching it, the rest sequenced.
- **Gate once on the merged tip and the binding constraint moves to the dispatcher's own capacity to read N
  diffs.** An epic gating as a whole barely pays the per-slice cost, so size that wave against the reading: a
  green gate cannot tell whether the agent solved the right problem — only a reader holding the slice's `Goal`
  beside its diff can, which is why that field is worth the line it costs.
- The *scoped* per-commit check implementers run is NOT the sizing cost; the **full gate** is — drained where
  the project declares `enqueue`/`drain`, run by each implementer where it declares neither. Size against
  the *actual* `gate`, cache and gate mode you read in config.

## The closing check — read a slice's fields against each other, and against what the project will accept

**Before you emit a slice, read its fields against each other and against what the project will accept — as
ONE CLOSED QUESTION over the path-keyed family plus these five PAIRS, never as a general check of your work.**
Nothing downstream reads any two fields against each
other and you are the only party holding all of them at once, so a slice can be internally unsatisfiable and
still look finished: the implementer meets one field by breaking another and reports the half it met, and no
gate can read a brief — **nor could one ever read a prose summary against a prose table, which is why this
stays a rule you run rather than a check that runs it.**

**The question, run per path and answered per path:**

> **For every field that constrains what may happen to a named path, does any other field demand of that same
> path something the first forbids?**

`Owns` with a disposition beside an entry, `Do NOT touch` and `Derives` all constrain a path; `Verify` and
`Brief` both demand outcomes of one. **Key it on the PATHS rather than on the fields**: gather every path
those five name, ask the question once for each, and **write a verdict per path** — the per-path verdict is
what makes this a test, where one answer over the whole slice is the invitation to feel careful it replaces.
**The worked example is a fence against a verify bar** — a `Do NOT touch` glob and an assertion that both land
on the same test file, the case the `Do NOT touch` field above carries two rules to settle.
**`Derives` has the identical hole and earns no pair of its own**: it already carries a disposition beside a
path, so the question reaches it by construction.

**Then these five pairs, which the question cannot reach**, each reading a field against something other than
another field's claim on a path:

- **A goal against its verify bar** — `Goal` against `Verify`, and the test is satisfiability by one sentence:
  where a single sentence would satisfy both, the goal is a restatement of the bar and you have not written
  one yet. A field every slice carries and no reader uses is worse than no field, because it costs prose on
  every slice and teaches its readers to skip the place a real goal would have been.
- **A content requirement against a style constraint** — two halves of one `Brief`, or a `Brief` against the
  conventions the slice inherits, each satisfiable alone and contradictory only in the pair.
- **Any requirement against the vocabulary the target actually has** — a brief can demand a distinction the
  target cannot express, as a chapter told to say which consumer a rule is for, in a corpus whose pages never
  name their readers. That is **satisfiability**, not style: no wording satisfies it, so the implementer
  invents vocabulary the medium lacks or drops the requirement.
- **A derivation instruction against reachability from where the slice lives** — a `Brief` saying *derive X
  from Y* against the workspace position the slice's `Owns` sits in. The pair above is expressibility; this is
  reach: the symbol exists and the derivation is expressible, but there is no path to it from the slice — the
  wrong side of a workspace boundary, a package the slice does not depend on — and the research in
  `skills/ground/references/grounding.md` establishes only that Y exists *somewhere*.
  **Resolve Y from where the slice lives before writing the sentence**, or the implementer transcribes the
  values the derivation would have produced, the slice goes green, and the false premise is contradicted
  nowhere.
- **Any requirement against what the project's declared guardrails PERMIT for the files it names** — the pair
  before this is reach and the one before that is expressibility; this is **permissibility**, and it is the
  one a brief passes while being wrong — internally consistent, expressible, reachable, and asking for
  something the project's own gate rejects. Read each requirement naming a file against what that project's
  declared gate, linter and ratchets will accept there, since nothing downstream checks a brief against the
  tree: the slice finds out by going red, or by deviating silently and correctly, which is indistinguishable
  from diverging.

## The parallelization plan (the part the dispatcher steers by)

The dispatcher needs the **shape of the parallelism** for the increment it is about to run.
**The arc's ordering is the issue's phase map, which you carry forward rather than produce** — read it, say
which phase the horizon sits in, and lay the waves out inside that phase; an arc re-ordered here is a second
plan for one arc, and nothing marks which of the two a later reader took.

- **Waves.** Group slices by dependency: **Wave 0** is the foundational layer that must land first — a schema
  change, a shared type, a renamed module, a new core service — and Wave 1+ are the consumers that run in
  parallel once it merges. **Say which wave is the horizon**: the earliest whose dependencies have all landed,
  and the only one you grounded. Where it is only the dispatchable part of a wave, don't promote the rest on
  the strength of its blocker landing soon.
- **Transient-red window.** Flag a breaking wave-0 change (NOT-NULL schema swap, required interface field,
  renamed export) and name the slices living in the window, since the branch's gate won't be green until every
  consumer migrates. **Your flag is also what tells `/pipeline:execute` to OPEN the window** — it cuts a
  `transient-red/<epic-slug>` marker ref, the only form of the fact anything inside a slice worktree can read.
- **Epic branch — carried from the issue, never answered again here.**
  (`skills/glossary/vocabulary/epic-branch.md` defines one.) The verdict was written where the arc was planned
  and `/pipeline:execute` owns the lifecycle, which leaves nobody owning it twice. Read the verdict, put it in
  the breakdown so the dispatcher knows which branch the slices fork from and PR into, and where it says
  "epic" name the branch itself.
  - **A knowingly-red epic is what opens the transient-red window**, so carry that half of the verdict too
    rather than only the branch name — the *Transient-red window* entry above is what the dispatcher acts on.
  - **Where your grounding CONTRADICTS the verdict, report it on the issue rather than settling it** — a
    contract seam whose halves you now see landing in different waves, or a foundational change every consumer
    must follow, against an issue that says one slice. Naming the contradiction is the finding; answering it
    here answers a question already settled somewhere a human reviewed it.
- **Conflict map.** Name any pair of slices that will touch the same file **neither of them owns** (both add a
  route to one registry, both add a case to one exhaustive switch); the dispatcher resolves these
  **at merge time**, never by rebasing. **Two slices both OWNING a path is not a row here but a slicing
  defect**, settled by the `Owns` constraint above before this map is written — a map row treats as a
  merge-time cost what that constraint treats as a plan defect to report.
  - **Give documentation its own AXIS on this map, and write down why the `Owns` lists cannot be relied on to
    find it** — `Owns` names the docs grounding can FORESEE, so what escapes the per-path check is the page a
    slice discovers it must write only once it sees what its change did, which is by construction the one no
    list contained. **Write that reason in the map** rather than leaving a reader to conclude the per-path
    check above already covers it.
  - **Off an epic, name an OWNER: one issue writes the shared pages and every other slice REPORTS the doc
    change it needs rather than writing it**, since two agents discovering one page produce a merge nobody
    sized and a page that is right on neither branch. **On an epic the falsification ledger already is that
    regime**, so name on this axis the shared pages the closing docs slice will write and leave the pen there
    — handing a live sibling a shared page mid-arc is the edit that slice was told to record rather than make.
    **Where that closing docs work is several slices rather than one, name on this axis which of them owns
    the ledger entries that route to no page**, since an entry handed to all of them is answered by none.
- **Shared hotspots — hoist the seam in Wave 0, don't just name the conflict.**
  **3+ slices all extending one structure** — a control loop's `tick()`, a reducer, an event handler, an
  exhaustive switch — is a decomposition smell: they fork off different bases, so the merges come out
  textually clean (git reports `MERGEABLE`) and behaviorally wrong, each adding its case only to the siblings
  that existed when it forked. Land the extensibility seam first — an interface, a registry, a `Monitor[]` the
  others *register into*. When you can't, do both: emit the **shared invariant** into every touching slice's
  brief (*"every parked-state branch must freeze ALL kill-clocks"*), and mark the hotspot so
  `/pipeline:execute` reviews the merged region semantically rather than just resolving markers.
- **Contract seams — who *defines* a shape someone else *consumes*.** Neither the conflict map nor the hotspot
  list catches slices sharing **no file at all** that still break each other over a return type, a schema
  field, a tool grant, a prompt variable or a config key: both gates are green and the break appears only when
  both are on the branch. Emit a second, separate map: **producer → consumer → the shape between them → what
  the consumer does with it.**
  - **A row is not FINISHED until you ask what the consuming side DOES with the value.** A consumer that only
    *filters* is safe; one whose read feeds an **action** — a charge, a send, a delete, a state transition —
    is the seam, because that action can be computed from something captured before the producer's value could
    exist. It bites hardest on a status or flag, where enumerating the readers terminates quickly and looks
    exhaustive while what matters is what happens to a row after a read selects it.
  - **Two seams a file map structurally cannot see**: producer and consumer in
    **different languages or trees** (code defining a value that documentation or a prompt describes), and a
    seam with **no compiler between the halves** (a config, a prompt template, a generated brief).
  - Every seam whose halves land in different waves is evidence about the issue's epic verdict — reconcile the
    two before emitting either, and report a contradiction rather than settling it.
  - **From the loop, what you emit is one cycle's contribution to an arc-level union, not the arc's map.**
    Read the arc-level union the loop keeps in the umbrella issue body, name the seams the arc already holds
    that this horizon closes, and hand your new rows to it; a missing row reads exactly like a seam that was
    closed. On the direct paths there is no union and your map is the whole of it.
- **Scaffolding is planned with its teardown, in one plan** — the check, its fixture, its ledger and its
  documentation removed in one slice rather than a trail of partial removals.
  **Write the teardown's precondition down when you plan the build**: it depends on every draining slice, and
  its verify bar names the state that makes it legal (the ledger at zero, the last consumer migrated). An
  empty ledger reads as an invitation, so an unwritten precondition lands the teardown while the thing it
  enforced is still incomplete; a teardown never planned leaves dead scaffolding that reads as live machinery.
- **Don't schedule documentation of a model another slice is changing** — it must land *after* every slice
  that changes it, or it documents a shape that no longer exists and nothing fails. Docs for a part this epic
  does not touch are exempt and should say so in the wave note. **In an epic this becomes a slice**: a closing
  docs slice, last, depending on every other, consuming the falsification ledger and writing against the final
  tree — named in the plan, and **given both inputs, because the ledger alone is short by construction**: it
  derives rows from what the epic **added** and reconciles them against what it inherited.
- **Critical path.** One line: the longest dependency chain (wave 0 → its slowest, most-coupled consumer), so
  the dispatcher knows where to start and what gates the finish.

Be honest about what is genuinely sequential, and equally about what is genuinely separate.
**Real independence > optimistic independence, and real separateness > disjointness mistaken for it.**
