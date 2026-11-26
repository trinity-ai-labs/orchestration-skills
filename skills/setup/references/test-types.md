# The test types per area

Reference for Step 1 of `/pipeline:setup`, *The test types per area*. **Open it on onboarding, and on a
reconcile where the project's guidance holds no test-type table or an area has no row in it.**

**The test-type table is the project's record of which kind of test brings value in which area** — what every
test written there is held to by the project's *Test policy* (`skills/procedures/code-shape.md`). It lives in
the project's tests chapter: the testing chapter it already has, or `.agents/rules/tests.md` routed from its
root `AGENTS.md` where it has none, placed by `skills/procedures/agent-guidance-layout.md`'s *Placing a line*
— never a second chapter beside an existing one — **its router row naming the topic as adding, changing or
judging a test**, so every seat that does one opens it. **It is a coding convention, never config: no key in
`.agents/worktree.json` holds it.**

## Its shape — one row per area, five columns

| Column | Holds |
|---|---|
| **area** | a release unit or a domain, named by its folder |
| **must be right** | what is guarded from day one with no recurrence needed: by default, wherever the area has them, the money layer (payments, purchases, licence claiming), auth, sessions and authorization, security and signing, redaction and secrets, data integrity and migrations, sync and concurrency, and parsers — then what the owner names, such as saved state or the audio thread; `none` where nothing is |
| **test type** | the kind that brings value there, at its seam and with its bounds: unit at a DSP seam, at one rate and block size with no long render; end-to-end in one browser for auth and checkout; end-to-end on the real artifact for an installer; in an area checked by hand, at most a few high-value checks such as *does it render*, or none |
| **checked by hand** | `yes` or `no` — by the owner, and by whoever runs the product while building it; `unasked`, read as `no`, until the owner answers |
| **never committed** | what no test in that area may be: on-screen checks (*is each button here, does it light up*), sweeps, long renders, measurements — a kept answer being data instead, by `skills/procedures/code-shape.md`'s *The measurement cache* |

## Drafting it — in order

1. **Name the areas off the code shape Step 1 read** — the release units, then the domains, by folder; one
   row each.
2. **Draft `must be right` from the code**: search for the default set's code, and put each find in its
   area's row as a candidate naming the file it came from.
3. **Ask the owner, flat, over the listed areas: which do they check by hand, and what else must be right from
   day one?** Their answers go into the rows as given; with nobody to ask, `checked by hand` reads `unasked`,
   never a guessed `yes`.
4. **Draft each `test type` from the area's seam** — the cheapest level that exercises the boundary a caller or
   a user crosses, end-to-end only where a user crosses auth, money or an installer — read beside the tests
   the area already has.
5. **Draft `never committed`**: measurements, and sweeps outside `fullGate`, in every area; on-screen checks
   too in a hand-checked one.
6. **Show the owner the drafted table and land their corrections** in the reviewable PR beside the config,
   never a commit straight to the integration branch.

**On a reconcile, draft only the missing rows** and leave every existing row as the owner wrote it, since a
row's wording is their decision.
