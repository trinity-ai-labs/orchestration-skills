# Writing skill prose

Chapter of the root [AGENTS.md](../../AGENTS.md): the rules for writing or changing the prose under `skills/`, and
any prose in this repo that states a rule.

**State a rule where its reader acts, in as many places as there are readers — but a DEFINITION has one
home.** A skill that has to reach into another skill to explain a rule is not finished: restate what its
reader needs and stop. Two copies of a rule that drift is a smaller problem than a rule nobody reaches, and
every citation across skills is one more thing to keep true. **A definition is the opposite case and the line
is what the sentence CLAIMS**: what a thing *is* is identical for every pass and owned by none of them, so
copies drift with nothing able to make them agree; what a stance *does* about it differs per stance and is
restated. So a shared term is defined once in `skills/glossary/` and cited directly from wherever it is used,
and the rule built on it stays where its reader acts. **A GROUND RULE is the second edge, and it is the same
argument one level over**: a rule whose statement is identical at every seat has no per-seat form to restate,
which is the only thing that would keep N copies honest, so it is stated once in
`skills/ground-rules/SKILL.md`, which every pass has its reader open before acting — admitted on that test
alone, since a rule that reads differently at two seats belongs at those two seats.
**A PROCEDURE is the third edge and it is the same argument once more**: the steps do not change according to
who runs them — the command and its flags, the order they run in, the meaning of the values it reads, the host
tool that runs it, and what to verify once it has — so it is stated once in `skills/procedures/`, and what a
seat DOES about the result stays a rule and stays where its reader acts. `scripts/check.sh` check 12 permits
those three edges and still fails every other citation across skills, any of the three citing a pass included;
it compares the cited target as a whole path segment by equality, so a fourth cannot arrive by resembling one.

## Conventions

- **If you cannot state a rule in one line, it is not a rule yet**, and
  **a reader must be able to act on it without opening anything else.**
  **Name the failure a rule prevents in a clause that shares its sentence with the action, never in a sentence
  or a paragraph of its own.** That is the whole boundary, and it is a PROPERTY rather than a list of
  phrasings: a failure given its own grammatical home is a war story however it is worded, and one carried as
  a clause of an actionable rule is wanted however it is worded. The test is mechanical — read the sentence or
  paragraph the failure sits in and ask what the reader is to DO; a unit that carries no action has promoted
  the failure, and it comes out. `scripts/check.sh` check 11 catches a handful of phrasings that perform that
  promotion, and it is a **BACKSTOP that does not claim to be the rule**: an enumerated ban is satisfied by
  every form it omits, so a green there says those phrasings are absent and nothing more. Adjudicate against
  the property; where you cannot tell, leave it out. **Adding phrasings to that pattern is not how it
  improves** — the next war story is written in the next shape, and a longer list only makes the green look
  better. **The war story goes in the PR that fixes it — and so does the link to it.** A tracker coordinate in
  a skill is an instruction to go read an issue mid-task: obeyed it derails the run, ignored it leaves an
  agent acting on a rule it does not understand, and both are worse than the rule being absent. So a skill
  carries the rule and nothing else — no session anecdote, no release number, no commit SHA, no sighting
  count, and **no issue number**, which `scripts/check.sh` check 9 now fails on rather than validates.
- **Two ceilings, both `wc -w` over every `*.md` file under `skills/` that git lists as tracked OR
  untracked-and-not-ignored — a new skill not yet `git add`ed being exactly what these ceilings exist to weigh
  — enforced at `scripts/check.sh` check 10: no single file over 30,000 words, and no sub-skill — one
  `skills/<slug>/` spine plus its own references, counted as that whole DIRECTORY rather than as what any one
  agent loads, since an agent loads the spine plus whichever references it is sent to — over 50,000.** They
  are BACKSTOPS, not budgets: the pair catches runaway growth in what one read costs rather than rationing
  prose, and **the headroom is deliberately not stated as a fraction here** — it moves with every release that
  adds prose and check 10 prints each sub-skill's total on green, so a figure in this sentence would be a
  third copy of the rule with nothing measuring it. A change carrying either number over deletes, or splits a
  whole pass out, to make room. Extraction settles the per-file half alone; the sub-skill half counts the same
  words wherever they sit inside its directory. **There is no corpus-wide ceiling** — prose behind a pointer
  costs nothing until the pointer is followed.
- **A `SKILL.md` is an ordered list of ACTIONS.** Each action names the reference that says how and carries
  the rules that fire at that action. A rule goes in the reference where the reader cannot perform the action
  without opening it, and stays on the step where they can — nobody opens a file to write a commit message. A
  rule firing at no single action goes in one short closing block. `skills/execute/SKILL.md` is the worked
  example.
- **A skill cites its own references and three shared homes, and nothing else.** Unbounded cross-skill
  citation grew a web of references, a checker to validate it and a convention for writing it; state what your
  reader needs where they act instead. The three homes are the three edges above — `skills/glossary/`,
  `skills/ground-rules/` and `skills/procedures/` — each admitted on the property stated there. An ordinary rule
  is none of the three, and it does not become citable because restating it is inconvenient: where two seats
  would do different things with it, it stays written at both. All three are cited and never cite back. Where a
  shipped skill names one, use a `skills/…` path — the one form that resolves in the repo the prose is READ
  in, since a bare `README.md` or `AGENTS.md` in shipped prose names the reader's file, not ours.
- **Name the unit beside a number.** `grep -c` counts lines and `grep -o | wc -l` counts occurrences; both are
  true over one sweep and they diverge wherever a passage names its subject twice. A count a reader checks by
  looking needs nothing.

## Rules with more than one reader

A rule this corpus states to more than one role is one change, however many files that takes. Write it at
every seat, list those seats in the PR body, and say which candidates you looked at and left alone. Nothing
checks this — it is the author's job, and the reviewer reads the list against the diff rather than accepting
it.
