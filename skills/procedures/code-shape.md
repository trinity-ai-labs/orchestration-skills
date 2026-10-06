# Code shape — reading it, its signals, placing a file, a missing tool, a split gate

Entry in `skills/procedures/SKILL.md`. **Five procedures over one shape** — domain, domain map, domain tag,
shared spine, seam test and setup debt are defined in `skills/glossary/vocabulary/code-shape.md`, and every
step below uses those words in exactly that sense. `skills/ground-rules/SKILL.md` rule 12 is the rule they
serve. The steps are the same whoever runs them.

**Nothing here says when to run one or what to do with the answer.** Whether a signal is reported, folded or
recommended against differs by seat and is written where each seat acts.

## Reading a project's code shape

1. **Read its agent guidance for the work** (`skills/procedures/agent-guidance-layout.md`, *Reading the
   guidance*) and take from it every declared layout and testing rule. Those win over every default below.
2. **Find its domain map, if it keeps one** — a file mapping path globs to domains. Note its matching order
   and whether anything checks it.
3. **Find its test-tag form** — how a test names its domain: an annotation, a tag option, a naming
   convention, a registered list. None found is an answer: the tests carry no domain.
4. **Where no map exists, name the domains from the folder level at which the project divides by domain**,
   and mark the list inferred.

## The signals, and how to take each

Take each on the fly with the project's own tooling — its tracked-file listing, its test tool's listing mode,
a search over import lines — and **state the unit beside every figure**, since a count of files, of tests and
of import lines answer different questions.

| Signal | What it measures | How to take it | Unit | What it costs |
|---|---|---|---|---|
| Map coverage | tracked files any domain glob matches, and the unmapped rest | match every tracked file against the map; list the files no glob matches | files, and their share of tracked files; the unmapped listed | every unmapped file a change touches forces a full run |
| Shared-spine share | tracked files mapped to every domain | count the files the map assigns to every domain | files, and their share of tracked files | every change touching one runs the whole suite |
| Folder disagreement | files whose mapped domain differs from their folder's | compare each file's map entry with the folder at the domain level | files, listed | a change there is gated as a domain it does not live in |
| Cross-domain tests | tests whose imports or calls reach several domains | map each test file's import targets to domains and count the distinct domains | test files, each with its domain count | each runs in the gate of every domain it reaches |
| Untested domains | domains no tagged test asserts about | domains minus the domains named by any tag | domains, listed | a change there selects no test of its own |
| Untagged tests | tests carrying no domain tag | tests minus tagged tests | test files, and their share of all test files | no domain filter can select them |
| Wrong-way imports | imports crossing domains other than through shared code, or against the project's declared layering | map each import line's source and target to domains | import lines, listed | a change in either domain reaches the other |
| Full-gate cost | what one full run of the suite costs | time one run, or read the last few from the project's own build history | minutes per run, and test count | spent by every change where nothing narrows the gate |
| Selectable share | tests a domain filter can pick | tagged tests whose tag is checked | test files, and their share of all test files | the rest runs on every change |

## Placing new code and a new test — in order

Stop at the first answer that places it.

1. **Does the project's own guidance place it?** Yes → there.
2. **Which one domain's behaviour does it change?** → that domain's folder, beside the code there it most
   resembles.
3. **Is it used by two or more domains and owned by none?** → shared code, in the project's shared location,
   where it widens the shared spine.
4. **Would placing it take an edit to a central list to be picked up?** → use the form the folder picks up;
   where the project offers only the list, edit it.
5. **Run the deletion test on any new module** — imagine deleting it: where its complexity vanishes it was a
   pass-through and the code belongs in its caller; where it reappears across several callers, the module
   earns its place.
6. **Add an interface only where two adapters vary across it** — a production implementation and a test
   fake, say. One adapter is no variation point yet, so no interface goes in for it.

**Then its test:**

1. **Find the seam** — the narrowest boundary a caller or a user crosses that exercises the behaviour: a
   route, a command, a module's public interface. Test there.
2. **A unit test only for logic with real branches inside one module.**
3. **Tag it with its domain in the project's form**, and where tags are checked from evidence, confirm what
   the test imports or calls points at that domain.

## Recognising a missing tool

1. **A signal above, or any other check, worked out by hand more than once** — across slices, arcs or passes
   — is a missing tool.
2. **The tool that replaces it is a script in the project's repository** that prints the signal with its
   unit and exits non-zero on the condition it guards.
3. **It carries its own check** — a fixture it must fail on — so a tool that silently stops matching goes red
   rather than green.
4. **The project's gate runs it**, never a brief.

## The shape of a split gate

The properties a split gate (`skills/glossary/vocabulary/code-shape.md`) needs to be safe — properties, not a
tool.

1. **A domain map covering every tracked file**, first matching glob wins, **whose own check fails on an
   unmapped file, an unused domain and a glob matching nothing.**
2. **Tests tagged by domain, and the tags checked** — against the map, or against what each test imports or
   calls.
3. **A changed-files gate that runs the union of the changed files' domains, and falls back to the full
   suite, loudly, on any unmapped file or any shared-spine file** — printing why — so its failure is always
   running too much, never too little.
4. **The full gate moved to the integration points, never dropped** — the project's `fullGate`
   (`skills/procedures/config-keys.md`), with the partial gate as its `gate`.
5. **Optionally, a green cache** keyed on a hash of a domain's inputs — its files, the shared spine and the
   toolchain — skipping a domain whose key last passed.
6. **A map derived from evidence under-approximates** (the glossary entry says why), so it is safe only because
   the full gate still runs before anything ships.
7. **A re-gate after a fix round on a head that passed the full gate runs the split gate over the delta since
   that head**, with the same loud fallback, and its verdict names both heads — the one bounded exception to
   item 6, since the head that ships rests on the full run directly below it for every domain the delta left
   untouched, which is why the fallback on any shared-spine or unmapped file is what makes it safe.
