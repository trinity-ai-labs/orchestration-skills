# Review — the tests lens

Reference for `skills/review/SKILL.md`, step 2: the tests lens's brief. Its findings bind and close by class,
as `skills/procedures/code-shape.md`'s *Test policy* says, so each one names the clause it rests on.

**Judge every test the diff adds or changes against `skills/procedures/code-shape.md`'s *Test policy*, and
start each added test marked for deletion**. Report each finding with the deletion, merge or move on demand
(`skills/glossary/vocabulary/on-demand.md`, by `skills/procedures/code-shape.md`'s *Pruning*) you propose:

- **A test the policy does not admit** — name the clause it fails.
- **A test whose justification is missing or does not hold** — the three items the policy asks of a guard, read
  from the PR body, where each added test's justification is written before this pass runs — a merged
  slice's from that slice's PR body and its `handback/<leaf>` comment; a guard claiming
  recurrence is checked against the history (`git log -S` or `-G` on the behaviour it pins), and one claiming
  the owner's ask names where that ask is written — an item its area's row lists under *must be right* being
  that ask, unless this diff added or changed that row.
- **A test of another type than its area's row names, or of a kind that row never commits** — name the row,
  read from the project's test-type table (`skills/glossary/vocabulary/test-types.md`). A guard earned by
  recurrence or the owner's ask is not this finding over the row's `never committed` cell (*Test policy*,
  *Earning a guard*).
- **A guard the diff rewrote to match a change that tripped it**, with no answer from the owner on record.
- **A committed re-measurement** — a measurement every gate re-runs to ask what it measured last time — its
  remedy `skills/procedures/code-shape.md`'s *The measurement cache*. **A test that reads a stored answer and
  re-measures nothing is not this finding.**
- **A test that duplicates one already in the suite** — name the existing test that carries the case, or
  would with one more case.

**At a review checkpoint or a close-out, re-judge only seam-level duplicates — tests from different slices
carrying one case — and tests of another type than their row names**, never a test a slice's own tests lens
already settled.

**A deletion you propose names the domain-map entries and test tags the same change updates**, so the map's
own check stays green.

**Not a test that cannot fail** — that is the Correctness reviewer's finding.
