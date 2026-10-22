# Code shape — reading it, its signals, the test policy, placing a file, pruning, a missing tool, a split gate

Entry in `skills/procedures/SKILL.md`. **Procedures over one shape, the folder as the unit** — domain, core,
component, release unit, central list, domain map, exception list, domain tag, shared spine, split gate,
moves the boundary, seam test, guard, probe and setup debt are defined in
`skills/glossary/vocabulary/code-shape.md`, and every
step below uses those words in exactly that sense. `skills/ground-rules/SKILL.md` rule 12 is the rule they
serve. The steps are the same whoever runs them.

**Nothing here says when to run one or what to do with the answer.** Whether a signal is reported, folded or
recommended against differs by seat and is written where each seat acts.

## Reading a project's code shape

1. **Read its agent guidance for the work** (`skills/procedures/agent-guidance-layout.md`, *Reading the
   guidance*) and take from it every declared layout and testing rule, **its declared layering above all** —
   which folders are release units, which are components, and where the core sits. Those win over every
   default below.
2. **Find the manifests each release unit and component declares itself in** — a package, app or plugin
   manifest per folder, found by a glob — and the import or build graph between them. **Where the guidance
   declares no layering, name it from those manifests and mark it inferred**; several manifests, a version per
   product, several app or plugin targets or tags per product are the signs of more than one release unit.
3. **Find its domain map, if it keeps one** — a file mapping path globs to domains. Note its matching order
   and whether anything checks it, and **whether a gate selects by it or by structure** — where selection
   comes from structure, the map is an exception list.
4. **Find its test-tag form** — how a test names its domain: an annotation, a tag option, a naming
   convention, a registered list. None found is an answer: the tests carry no domain.
5. **Where no map exists, name the domains from the folder level at which the project divides by domain**,
   and mark the list inferred.

## The signals, and how to take each

Take each on the fly with the project's own tooling — its tracked-file listing, its test tool's listing mode,
a search over import lines — and **state the unit beside every figure**, since a count of files, of tests and
of import lines answer different questions. **Nothing here runs the suite**: a timing comes from the latest
gate or CI output only, and a figure with no such output is *not taken*.

**A row is taken only where its precondition holds**, and a row whose precondition is absent is neither a value
nor an item: *Map coverage* needs a test suite beyond the gate's own checks, a map having nothing to select
without one; *Shared-spine share*, *Catch-all-only files*, *Folder disagreement* and *Map size* need a domain
map; *Cross-domain tests*, *Untested domains*, *Untagged tests*, *Misplaced tests*, *Selectable share*, *Tag
count*, *Tests per domain*, *Minutes per domain* and *Sweep multiplicity* need a test suite beyond the gate's own
checks; *Release-unit imports* needs two or more release units; *Upward imports* needs a declared or shown
layering; *Whole-suite fallbacks* needs a split gate; *Preflight cost* needs a declared `preflight` distinct
from `gate`.

| Signal | What it measures | How to take it | Unit | What it costs |
|---|---|---|---|---|
| Map coverage | tracked files any domain glob matches, and the unmapped rest | match every tracked file against the map; list the files no glob matches | files, and their share of tracked files; the unmapped listed | every unmapped file a change touches forces a full run |
| Shared-spine share | tracked files mapped to every domain | count the files the map assigns to every domain; not taken where selection comes from structure, which selects what a shared file reaches | files, and their share of tracked files | every change touching one runs the whole suite |
| Catch-all-only files | tracked files whose only matching glob is a catch-all — a glob spanning a whole product or package tree and mapped to every domain — apart from the spine files the project names as deliberately shared | match the map with the catch-all globs set aside and list, by area, the files a catch-all matched that then match nothing, leaving out the named spine files | files, and their share of tracked files; listed by area | every change to one runs the whole suite, though it affects one area |
| Folder disagreement | files whose mapped domain differs from their folder's | compare each file's map entry with the folder at the domain level | files, listed | a change there is gated as a domain it does not live in |
| Cross-domain tests | tests whose imports or calls reach several domains | map each test file's import targets to domains and count the distinct domains | test files, each with its domain count | each runs in the gate of every domain it reaches |
| Untested domains | domains no tagged test asserts about | domains minus those any tag names or any test sits in the folder of — a domain folder counting as its tag | domains, listed | a change there selects no test of its own |
| Untagged tests | tests carrying no domain tag | tests minus tagged tests and tests in their subject's domain folder, which names their domain | test files, and their share of all test files | no domain filter can select them |
| Wrong-way imports | imports crossing domains or components other than through the core or shared code | map each import line's source and target to domains and components | import lines, listed | a change in either domain reaches the other |
| Release-unit imports | imports from one release unit into another | map each import line's source and target to the release unit whose manifest's folder holds it | import lines, listed | a change to either unit reaches the other's gate and its release |
| Upward imports | imports pointing up a layer — the core into a component or a release unit, a component into a release unit — or against the project's declared layering | map each import line's source and target to its layer | import lines, listed | a change to the higher layer reaches everything built on the lower, and the core stops being thin |
| Misplaced tests | tests whose subject lives in another folder | map each test file's import or call targets to their folder — its subject's folder being the one most of them sit in — and list the tests outside it | test files, and their share of all test files; listed | a change to the subject selects the test only through a map entry or a tag, never by its folder |
| Hotspots | files touched by a large share of recent merged PRs | count, per file, the merged PRs touching it among the last 50 merged into the integration branch, from git's history, leaving out the project's declared `bumpFiles` and `changelog`, which every release touches by design | PRs out of the last 50, per file, with that share; files at 10 or more listed | every slice touching one conflicts with its siblings at merge, and one there is often a central list or a core file changing too often |
| Full-gate cost | what one full run of the suite costs | read the last few runs from the project's own gate or CI output, a completed tip audit's minutes, from its ticket's `startedAt` and `settledAt`, included | minutes per run, and test count | spent by every change where nothing narrows the gate, and where `fullGate` narrows it by each release, on-demand run and boundary move; past 10 minutes a run it is debt either way |
| Preflight cost | what one preflight run costs on a one-file edit | read the preflight's own timing from the latest gate or CI output, the gate running it first, or take the one-file-edit time a calling pass measured and handed in; never run it | seconds per run, on a one-file edit | paid before every commit and at the head of every gate run; past 60 seconds on a one-file edit it is debt |
| Gate-minute slope | how fast the full-gate cost is growing | fit the full-gate minutes of the dated runs *Full-gate cost* reads, over at least four weeks of them, reading CI or gate-log history where the ledger is shorter; not taken with less | minutes per run per week, and days left before the 10-minute threshold at that rate — none on a flat or falling slope, which projects no breach | how soon every change, or every `fullGate` run, pays a run past the threshold |
| Whole-suite fallbacks | scoped plans a split gate widened to the whole suite | count the runs whose printed plan names a fallback, over the gate runs in CI output or gate logs | runs, and their share of split-gate runs | each paid a whole-suite run for a change a scoped run would have covered, and a rising share says selection is losing ground |
| Gate share | the share of an arc's wall-clock spent in gate and test runs | the minutes in gate and test runs over the last arc divided by that arc's wall-clock, both read from the gate ledger, CI timestamps or gate logs, tip audits left out since nothing waits on one | percent, beside both minute counts | every point of it is the arc waiting on a run; above 50% the tests are most of the arc |
| Selectable share | tests a domain filter can pick | tagged tests whose tag is checked, plus, where selection comes from structure, tests in their subject's folder | test files, and their share of all test files | the rest runs on every change |
| Map size | how much selection the folders cannot express | count the domain map's entries, or the exception list's once selection comes from structure | entries, with the trend since the last run | every entry is selection kept by hand, and one added per product is a central list |
| Tag count | how many tests carry a domain tag | count the test files carrying one | test files, with the trend since the last run | every tag is a claim something must check; where tests sit in their subject's folder the count shrinks |
| Tests per domain | how many tests assert about each domain | count the tests per domain tag, or per domain folder where tests carry no tag | tests, per domain | each runs on every change its domain's gate selects |
| Minutes per domain | what each domain's tests cost per run | sum the per-test or per-file timings the project's own gate prints, grouped by domain | minutes per run, per domain | paid by every change that selects that domain |
| Sweep multiplicity | how many times a loop runs each case written once — unit × theme × size × engine and the like | for each parameterised loop, the cases it runs divided by the cases written in it; past 200 test files, a sample of 200, stated as a sample | cases run per case written, per loop, with its file | every written case in the loop costs that many runs on every gate |

## Test policy

Whether a permanent test should exist at all — a guard or a probe, both defined in
`skills/glossary/vocabulary/code-shape.md`.

- **A test lives in its subject's folder** — a component's unit, integration and browser tests all in that
  component's folder — so the folders a change touches select it, and a tag carries only what the folder cannot
  say. **A sweep that samples across every unit is a sign the tests live away from their subject**, and the
  move is to colocate them.
- **Extend an existing test that fails on the bug before adding a new one** — the fix's test, extended or new,
  is new only where no existing test can carry the case.
- **A bug earns a guard only when all three hold: it is easy to reintroduce, it would slip by unnoticed, and
  it is costly if shipped** — otherwise the fix plus a probe is the proof.
- **One representative unit, theme, size or browser engine by default** — the engine a case runs in is a
  sweep axis like the others, so the other engines run on demand or at release; a sweep across every
  combination needs a written reason beside it, and runs only in `fullGate` where the project declares one;
  without `fullGate` it runs on every gate, which that reason must justify.
- **A test that cannot fail is deleted** — an assertion against the value that configured its own mock, a
  constant asserted against itself, a check the implementation could never violate.
- **A test that costs more to run than its bug would cost to ship is deleted.**

## Placing new code and a new test — in order

Stop at the first answer that places it.

1. **Does the project's own guidance place it?** Yes → there.
2. **Which layer, before which domain?** → code only one release unit needs stays in that release unit; a
   self-contained piece tested on its own goes in a component; new shared code goes in a component before the
   core, and moves to the core only when a second component needs it — never a component importing another,
   and never a release unit importing another.
3. **Which one domain's behaviour does it change?** → that domain's folder within that layer, beside the code
   there it most resembles.
4. **Is it used by two or more domains and owned by none, in a project that declares no layering?** → shared
   code, in the project's shared location, where it widens the shared spine.
5. **Is it a new release unit or component, or would placing it take an edit to a central list to be picked
   up?** → declare it in a manifest in its own folder, found by a glob; where the project offers only the
   list, edit it.
6. **Run the deletion test on any new module** — imagine deleting it: where its complexity vanishes it was a
   pass-through and the code belongs in its caller; where it reappears across several callers, the module
   earns its place.
7. **Add an interface only where two adapters vary across it** — a production implementation and a test
   fake, say. One adapter is no variation point yet, so no interface goes in for it.

**Then its test:**

1. **Put it in its subject's folder.**
2. **Find the seam** — the narrowest boundary a caller or a user crosses that exercises the behaviour: a
   route, a command, a module's public interface. Test there, at the cheapest level that exercises it.
3. **A unit test only for logic with real branches inside one module.**
4. **Tag it with its domain in the project's form where its folder cannot say it**, and where tags are checked from evidence, confirm what
   the test imports or calls points at that domain.

## Pruning

The candidates for deletion, merge or a move, each listed with its file, its cost in the unit named and the reason it
qualifies under the *Test policy*:

- **The slowest tests or specs** — minutes per run, from the gate or CI output.
- **The loops with the highest sweep multiplicity** — cases run per case written.
- **Same-shaped files repeated per unit, theme or product** — merge candidates for one table-driven test,
  counted in files.
- **Probes committed as permanent cases** — test files.
- **Tests that cannot fail** — test files.
- **Misplaced tests** — move candidates into their subject's folder, in test files; a move deletes nothing.

**A deletion or a move updates the domain map or exception list and the test tags in the same change**, so the map's own check stays green.

## Recognising a missing tool

1. **A signal above, or any other check, worked out by hand more than once** — across slices, arcs or passes
   — is a missing tool.
2. **The tool that replaces it is a script in the project's repository** that prints the signal with its
   unit and exits non-zero on the condition it guards.
3. **It carries its own check** — a fixture it must fail on — so a tool that silently stops matching goes red
   rather than green.
4. **The project's gate runs it when the change touches that tool** — its script, fixtures or map — never a
   brief.

## The shape of a split gate

The properties a split gate (`skills/glossary/vocabulary/code-shape.md`) needs to be safe — properties, not a
tool.

1. **Selection from structure first** — the folders a change touches plus the release units built from
   them, found from the manifests and the import or build graph, which makes the gate structure-selected.
   **The domain map is then an exception list** for what folders and imports cannot express, its own check
   failing on a glob matching nothing and an entry the structure already expresses.
2. **Where the folders cannot carry selection, a domain map covering every tracked file**, first matching glob
   wins, **whose own check fails on an unmapped file, an unused domain, a glob matching nothing, and a product
   file matched only by a catch-all** spanning a whole product or package tree and mapped to every domain — a
   spine file the project names as deliberately shared being the one exception.
3. **Tests in their subject's folder, tagged only for what the folder cannot say, and the tags checked** —
   against the map, or against what each test imports or calls.
4. **A changed-files gate that runs the union of what the changed files select, prints its reach — the release
   units or domains it selected and why — and falls back to the full suite, loudly, on any file neither the
   structure nor the map places or any change that moves the boundary** — printing why — so its failure is
   always running too much, never too little. **Its changed files are diffed against the integration branch the
   change will merge into, named explicitly, never the branch's own remote-tracking ref** — a branch is never
   its own base, and item 8's re-gate over a fix round's delta is the one exception — **and an empty plan on
   a branch with commits beyond that base fails loudly**, never a green over zero tests. **It runs one
   representative per sweep; a sweep runs only under `fullGate`.**
5. **The full gate moved to on-demand runs, a release, an epic's close-out where the epic moved the
   boundary, and a queued project's tip audit, never dropped** — the project's `fullGate`
   (`skills/procedures/config-keys.md`), with the partial gate as its `gate`, and **run cold: it reads no cache
   and no green store**.
6. **Optionally, a green cache** keyed on a hash of a release unit's or a domain's inputs — its files, the core
   or the shared spine and the toolchain — skipping one whose key last passed.
7. **A map derived from evidence under-approximates** (the glossary entry says why), so what it misses is
   caught by the full gate on demand, before a release and at a boundary-moving close-out, and between those
   by the tip audit (`skills/glossary/vocabulary/tip-audit.md`) where the project has a queue, every other
   change resting on the split gate alone.
8. **A re-gate after a fix round on a head that gated green runs the split gate over the delta since that
   head**, with the same loud fallback, and its verdict names both heads.
