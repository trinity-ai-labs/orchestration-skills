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
mid-change. Read the project's config where it has one for `gate` and `fullGate`
(`skills/procedures/config-keys.md`); with none, the gate is what CI runs before merge.

1. **Read the code shape** by `skills/procedures/code-shape.md`'s *Reading a project's code shape*.
2. **Take every signal in its table** with the project's own tooling, **each figure with its unit beside it**.
   One the tooling cannot take is reported as not taken, with what it would take, never estimated.
   **A signal is an item only where some change pays the table's *What it costs*** — an unmapped file, an
   untagged test, a full gate nothing narrows; one with nothing to pay is a value, not an item. No map at all
   is the `Map coverage` item, its value `no map`. **Where the project declares `fullGate`, its gate is
   already split**, so Full-gate cost is a value, not an item.
3. **Check the agent guidance's shape** by `skills/procedures/agent-guidance-layout.md`'s *Checking the
   shape*, or take the verdict a calling pass handed you rather than checking again. A monolith is the
   `Guidance: monolith` item, its value the count of marks, each mark with its file.
4. **Name the three items no table row carries**:
   - **A missing tool** — a signal this run took by hand that the issue already carries a value for has now
     been worked out by hand twice (`skills/procedures/code-shape.md`, *Recognising a missing tool*), so it is
     an item naming the signal.
   - **A central list** — a file every domain edits to register a unit, a route or a test, where the folder
     could pick it up instead; an item naming its path.
   - **A baseline** — a file that grandfathers existing violations of a ratchet or an allowlist (file size,
     lint, guidance), so each may shrink but never grow; the item `Baseline: <path>`, its value the count of
     entries with each one's size in the unit the baseline records, ticked off only when the baseline is empty.
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
signal as the table names it, `Guidance: monolith`, `Missing tool: <signal>`, `Central list: <path>` or
`Baseline: <path>`
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
- **The recommendation for a full-suite gate with no domain map or no checked tags is to split the gate**, by
  `skills/procedures/code-shape.md`'s *The shape of a split gate*; its alternatives are the map alone, the
  tags alone, or a gate queue's machine-wide slot so full runs stop contending.
- **The recommendation for `Catch-all-only files` is a map line per area plus a map check that fails on a
  product file matched only by a catch-all**; its alternatives are narrowing one area at a time (each area
  left runs the whole suite until its turn), or leaving it (every change there keeps running the whole suite).
- **The recommendation for a `Baseline: <path>` item is a burn-down, one leaf per entry, each split along that
  file's own seams**; its alternatives are raising the limit (the debt is redefined, not paid), or leaving it
  (what each entry already costs, with no end).

**Write it with `gh api` and a body file**, by `skills/glossary/mechanics/gh-api-file-body.md`:

- Create: `gh api repos/{owner}/{repo}/issues -f "title=Setup debt" -F "body=@<file>" --jq '.number'`
- Update: `gh api -X PATCH repos/{owner}/{repo}/issues/<n> -F "body=@<file>"`, adding `-f state=open` where the
  issue was closed and the new body carries an unticked item.

**Then refetch the body and confirm it is the markdown, not `@<file>`.**

⛔ **No AI attribution on the issue** — its title, its body and anything written onto it name the configured
git user alone: no trailer, line, footer or URL naming Claude, the assistant, the model, the harness, or the
session. The named forms and the named places are both instances rather than the extent, since an
enumeration of either is satisfied by every member it omits, so leave out anything you cannot rule out.

## 4. Report and route

**Report in chat, most expensive first**: each item with its value and unit, its trend, its cost, the
recommendation and its alternatives, and its route. Then the issue's URL, and what this run added, updated
and ticked off.

| The item | Its route |
|---|---|
| Cheap — a tag, a map entry, a glob, a small script | `/pipeline:orchestrate` with the item as the plan in chat; the loop never reads this issue on its own |
| A restructure — splitting the gate, bootstrapping the map, tagging the suite | `/pipeline:co-think` → `/pipeline:write-issue` as the project's own change, then `/pipeline:setup` so its `fullGate` ask declares the full gate once the partial one has landed |
| A monolith | `/pipeline:setup`, which splits it in its own PR |

**A calling pass gets that same report as its summary** and quotes it; it never re-measures. **Never a stop**:
the flow runs correctly on a full gate and a monolith, only dearer.

> **Setup health.** `<n>` items on `<issue URL>` — `<added>` added, `<updated>` updated, `<ticked>` ticked off. Most expensive: `<name>` at `<value> <unit>` (`<trend>`) — recommend `<move>`, route `<command>`.
