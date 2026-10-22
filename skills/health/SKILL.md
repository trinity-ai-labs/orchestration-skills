---
name: health
description: >-
  Measure how healthy a project's setup is — its code-shape signals and the shape of its agent guidance,
  each with its unit — compare each against its last value, record the result on the project's one
  rolling `Setup debt` issue, and report every item with its trend, its cost, a recommendation and the
  route that removes it. Use whenever someone asks how healthy a project's setup is, what its setup
  debt is, why every gate is so slow, or whether a past fix to the setup moved anything — and whenever
  /pipeline:setup or /pipeline:orchestrate runs it for you. It never restructures anything.
argument-hint: "[path to the repo to measure — omit for the current one; a calling pass may add setup-debt items it decided, for the record]"
---

# health — measure the setup, keep its one record, route each item

**A project pass, not an arc pass**, like `/pipeline:setup` and `/pipeline:cut-release`: typed when wanted,
never routed through the co-think → write-issue → orchestrate chain. **It is the one owner of setup debt**
(`skills/glossary/vocabulary/code-shape.md` defines it): `/pipeline:setup` runs it on onboarding and on
reconcile, `/pipeline:orchestrate` runs it once per arc as the arc leaves, and both quote its summary rather
than taking a signal themselves.

⛔ **Read `skills/ground-rules/SKILL.md` before you act on anything in this file — it binds you before this
file does.** This pass declares no sub-agents, so it authorizes none.

⛔ **Read-only against the tree.** No restructure, no edit to config or guidance, no worktree, no PR. **Its
one write is the project's rolling `Setup debt` issue.** A monolith, a missing map or a slow gate is an item
here and a fix somewhere else.

---

## 1. Measure

Measure what the main checkout holds — the integration branch — and never a slice's worktree, whose tree is
mid-change. Read the project's config where it has one for `gate`, `fullGate` and `preflight`
(`skills/procedures/config-keys.md`); with none, the gate is what CI runs before merge.

1. **Read the code shape** by `skills/procedures/code-shape.md`'s *Reading a project's code shape*, and **state
   the project's shape in one line** — its release units, its test suite beyond the gate's own checks, and its
   full-gate minutes — since that line decides which rows apply.
2. **Take every signal in its table** with the project's own tooling, **each figure with its unit beside it**.
   One the tooling cannot take is reported as not taken, with what it would take, never estimated, and **no
   signal is taken by running the suite**. **A signal is an item only where some change pays the table's *What
   it costs*** — an unmapped file, an untagged test; one with nothing to pay is a value, not an item. No map
   at all, in a project with a test suite beyond the gate's own checks and where no gate is structure-selected (`skills/glossary/vocabulary/code-shape.md`) either, is the
   `Map coverage` item, its value `no map`; a structure-selected gate needs none, and an untagged test in its
   subject's folder pays nothing. **Full-gate cost is an item past the threshold its row names**, whether or not the project declares `fullGate`, **and so are
   `Preflight cost` and `Gate share`, each past the threshold its row names**. **`Gate-minute slope` is an item where its days left before that threshold fall
   under 90**, and **a file the `Hotspots` row lists is its own item, `Hotspot: <path>`, only where more than
   half of those 50 PRs touched it** — below that it is the row's value. **Every row whose precondition is absent
   (`skills/procedures/code-shape.md`, *The signals*) goes on ONE line**, `does not apply here: <rows> —
   <the precondition each lacks>`, never taken row by row.
3. **Check the agent guidance's shape** by `skills/procedures/agent-guidance-layout.md`'s *Checking the
   shape*, or take the verdict a calling pass handed you rather than checking again. A monolith is the
   `Guidance: monolith` item, its value the count of marks, each mark with its file.
4. **Name the items no single table row carries** — four no row measures, and `Prune candidates`, drawn from
   the *Tests per domain*, *Minutes per domain* and *Sweep multiplicity* rows:
   - **A missing tool** — a signal this run took by hand that the issue already carries a value for has now
     been worked out by hand twice (`skills/procedures/code-shape.md`, *Recognising a missing tool*), so it is
     an item naming the signal.
   - **A central list** — a file every domain, component or release unit edits to register a module, a route, a
     test or a product by name, where a declaration in its own folder could be discovered instead; an item
     naming its path.
   - **A baseline** — a file that grandfathers existing violations of a ratchet or an allowlist (file size,
     lint, guidance), so each may shrink but never grow; the item `Baseline: <path>`, its value the count of
     entries with each one's size in the unit the baseline records, ticked off only when the baseline is empty.
   - **A preflight off its definition** (`skills/procedures/config-keys.md`) — one that compiles the product or
     runs tests, or that omits a no-compile step of the gate with no reason stated, read from the config and
     the gate's script, never by running either; the item `Preflight: <what>`, where `preflight` is distinct
     from `gate`, since a `preflight` equal to a seconds-long `gate` is the sanctioned answer.
   - **Prune candidates** — the specific tests to clear, by `skills/procedures/code-shape.md`'s *Pruning*. The
     item `Prune candidates`, its value the count of tests listed and the minutes per run they cost, the list
     beneath it. **Health lists them and never deletes one.**
5. **Add every item a calling pass handed you**, named as it named it, carried into *3. Record* like your own.

In a workspace, run every step per member, from that member's directory, against its own tracker.

## 2. Compare

**Find the rolling issue: the one whose title is exactly `Setup debt`, in this project's own tracker.**
Search open and closed alike, keeping only an exact title match:
`gh issue list --state all --search 'in:title "Setup debt"' --json number,title,state,body`.
**One found is the issue; none found is the one create, made in *3. Record*. Never a second**: two or more
matches stop this pass's write, never the calling pass — report every number and carry on to step 4.
Read each listed item's last value, so every figure from step 1 has a `last` to sit beside.

**Where the tracker cannot be reached**, carry on to step 4 and say no record was kept and no trend could
be read.

## 3. Record

**The item lines are STATE, rewritten whole each run**, one line per item, keyed on the item's name — the
signal as the table names it, `Guidance: monolith`, `Missing tool: <signal>`, `Central list: <path>`,
`Hotspot: <path>`, `Baseline: <path>`, `Preflight: <what>` or `Prune candidates`, whose tests sit beneath its line as indented
`- <file> — <cost> <unit> — <reason>` entries, rewritten with it
— **and anything else on the body is carried across unchanged**:

```
- [ ] **<name>** — <value> <unit> (<last> → <now>) · costs: <what every change pays> · recommend: <move>, because <why> · alternatives: <a> (<its cost>); <b> (<its cost>) · changes it: <the fact that would> · route: <command>
```

- **New item: append it**, with a recommendation and two or three alternatives, each with its cost, as
  `skills/ground-rules/SKILL.md` rule 13 asks.
- **Listed item: update its value and its trend** (`41% → 28%`) and **keep its recommendation and
  alternatives as they stand** — a user's edit to that one line is the decision, and it stands until they
  change it.
- **Gone on re-measure: tick it off** (`- [x]`) with the value that cleared it. A ticked item is left in place,
  and one that comes back is unticked with its trend, never appended a second time.
- **Settled: an item whose recommendation is to leave it, with its reason** — set by this pass or by the user's
  edit — is marked `- [x] **<name>** — settled: <reason>` and keeps its value and trend. It holds the issue
  open no more than a ticked item does, and it is unsettled — unticked, its recommendation re-made — only when
  its value crosses the fact its *changes it* names or the user edits the recommendation away from leaving it.
- **The issue is closed when no item is unticked** — every item ticked off or settled — and reopened only when
  an unticked one appears.
- **The first recommendation for a slow gate is to prune or merge tests**, from the `Prune candidates`
  item — one arc of deletions and merges, paid once. **Splitting the gate is the alternative**, by
  `skills/procedures/code-shape.md`'s *The shape of a split gate*, **structure-selected first** —
  colocating each test with its subject and adding a manifest per release unit and component, its cost those
  moves — and a domain map with checked tags only for what the folders cannot carry, its cost the map, the
  tags and the checks on both; a gate queue's machine-wide slot so full runs stop contending is the cheaper
  alternative after it.
- **The recommendation for `Gate share` is the `Prune candidates` first, then what the project itself adds
  to the cadence `skills/procedures/config-keys.md` sets for `gate` and `fullGate`** — a rule or CI job
  running the full suite per change, no `targetedTest`; its alternatives are splitting the gate (structure-selected
  first, then the map, the tags and their checks), or leaving it (most of every arc spent waiting on runs).
- **The recommendation for `Catch-all-only files` is a map line per area plus a map check that fails on a
  product file matched only by a catch-all**; its alternatives are narrowing one area at a time (each area
  left runs the whole suite until its turn), or leaving it (every change there keeps running the whole suite).
- **The recommendation for `Misplaced tests` is a move of each into its subject's folder**, updating the map
  or exception list and the tags in the same change; its alternatives are tagging them where they stand (each
  tag one more claim to check), or leaving them (each selected only through the map).
- **The recommendation for a `Hotspot: <path>` item is the seam that stops every slice editing it** — a
  folder-discovered declaration where it is a central list, a split along its own seams otherwise; its
  alternatives are a Wave 0 seam hoisted per arc (paid again each arc), or leaving it (a merge conflict on
  every wave that touches it).
- **The recommendation for `Release-unit imports` and `Upward imports` is moving what is shared down a layer**
  — into a component, the core on a second consumer — or a descriptor the other unit publishes; its
  alternatives are declaring the dependency in the layering (each change to one unit then reaches the other),
  or leaving it.
- **The recommendation for a `Preflight: <what>` item, and for `Preflight cost`, is a preflight built from the
  gate's no-compile steps alone, cached by content as `skills/procedures/config-keys.md` describes**; its
  alternatives are a reason stated beside the step it leaves out (one more claim to keep true), or leaving it
  (every no-compile failure waiting on a build, or every commit paying one).
- **The recommendation for a `Baseline: <path>` item is a burn-down, one leaf per entry, each split along that
  file's own seams**; its alternatives are raising the limit (the debt is redefined, not paid), or leaving it
  (what each entry already costs, with no end).

**Write it with `gh api` and a body file**, by `skills/glossary/mechanics/gh-api-file-body.md`:

- Create: `gh api repos/{owner}/{repo}/issues -f "title=Setup debt" -F "body=@<file>" --jq '.number'`
- Update: `gh api -X PATCH repos/{owner}/{repo}/issues/<n> -F "body=@<file>"`, adding `-f state=open` where the
  issue was closed and the new body carries an unticked item, and `-f state=closed` where it was open and the new
  body carries none.

**Then refetch the body and confirm it is the markdown, not `@<file>`.**

⛔ **No AI attribution on the issue** — its title, its body and anything written onto it name the configured
git user alone: no trailer, line, footer or URL naming Claude, the assistant, the model, the harness, or the
session. The named forms and the named places are both instances rather than the extent, since an
enumeration of either is satisfied by every member it omits, so leave out anything you cannot rule out.

## 4. Report and route

**Report in chat, the shape line first, then the does-not-apply line, then the items most expensive first**: each item with its value and unit, its trend, its cost, the
recommendation and its alternatives, and its route. Then the issue's URL, and what this run added, updated
and ticked off.

| The item | Its route |
|---|---|
| Cheap — a tag, a map entry, a glob, a small script | `/pipeline:orchestrate` with the item as the plan in chat; the loop never reads this issue on its own |
| `Prune candidates` | `/pipeline:orchestrate` with the listed candidates as the plan in chat |
| A restructure — splitting the gate, colocating tests, adding manifests, bootstrapping the map, tagging the suite | `/pipeline:co-think` → `/pipeline:write-issue` as the project's own change, then `/pipeline:setup` so its `fullGate` ask declares the full gate once the partial one has landed |
| A monolith | `/pipeline:setup`, which splits it in its own PR |

**A calling pass gets that same report as its summary** and quotes it; it never re-measures. **Never a stop**:
the flow runs correctly on a full gate and a monolith, only dearer.

> **Setup health.** `<shape line>`; does not apply here: `<rows>`. `<n>` items on `<issue URL>` — `<added>` added, `<updated>` updated, `<ticked>` ticked off. Most expensive: `<name>` at `<value> <unit>` (`<trend>`) — recommend `<move>`, route `<command>`.
