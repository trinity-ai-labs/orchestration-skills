# Implementer

Reference for `skills/execute/SKILL.md`. **If you were handed a dispatch brief, read THIS FILE whole before
your first edit**; each later step's reference is opened at that step. `skills/ground-rules/SKILL.md` and that
skill's *Hard rules (both roles)* bind on top of everything here.

## The work — the tree you edit, the flow through it, and the commits

**First action, before any other command: `cd` into your assigned worktree and prove you are really there** —
`git rev-parse --show-toplevel` must print the assigned path and `git branch --show-current` the assigned
branch; on either mismatch STOP and report. Work only there, in absolute paths, following the project's
`briefConventions`, `frameworkSkills` (invoke your area's as Step 0) and its agent guidance — **the router
chain of every directory your slice touches, up to the root, plus only the chapters those routers route your
slice to, and a monolith read whole** (`skills/procedures/agent-guidance-layout.md`, *Reading the guidance*;
router, chapter and monolith are `skills/glossary/vocabulary/agent-guidance.md`'s). Where your brief names
those files they are that set, so open them and not the rest.

**That rule covers EVERY LATER command's working directory, not only the first** — a check, a grep or a gate
run pointed at another checkout answers about another branch, and **a green from the wrong tree and a green
from the right one are identical**, so name a path inside the assigned worktree on every command rather than
trusting a `cd` to have held. **Your brief names ONE tree, so a second absolute path appearing in it is a
thing to QUERY rather than obey**; where an instruction genuinely needs the repository rather than a checkout
it names a **ref**, which is the part that is repository-wide. **And a finding that indicts shared
infrastructure — the gate, a helper, a rule every slice reads — is checked against the possibility that the
instrument was pointed at the wrong tree before you believe it**, since the reds are as indistinguishable as
the greens and the expensive version of this mistake is shipping a wrong diagnosis about machinery every slice
depends on.

**The copy you were handed is not the copy you are editing — where your slice edits the corpus it is reading,
the worktree's copy is authoritative.** Step 0 loaded these skills from the *installed* plugin, and rules an
arc has just shipped are the ones likeliest to be missing from it. So read a governing rule out of the
worktree before acting on it, `diff` the two where one looks wrong, and say which copy you read.

**The flow is: take any baseline your slice needs → write all the code → update the docs it changed → fix what
you HIT outside your owned files, in this PR → commit → push → draft PR →
(`/pipeline:review` if this slice warrants it, now against that pushed PR) → (if it finds something: apply
what you accept, preflight, one more commit, push again onto the same PR) →
(in in-line mode, your one `gate` run) → hand back.** The gate ticket is **not in that flow** —
where the project declares `enqueue`/`drain` your dispatcher enqueues it after it has read your diff, and in
in-line mode there is none. While you build, run only *cheap* checks: format, the preflight
(`preflight`, or `turbo run <task> --filter=<pkg>`, never raw `tsc`/`eslint`), and the one targeted test run
the spine's step 3 bounds, **a change to a module's export surface** — adding, removing or renaming an export,
or moving code between modules — widening it to every test file that mocks or imports that module, found by
grepping its specifier.

**A baseline your slice needs is taken FIRST — before your first edit — and only once.**
**One your brief hands down on your fork point IS it**: confirm its SHA against
`FP=$(git merge-base HEAD origin/<base>)` and report your delta against it without measuring it again — where
the SHA differs it describes another tree, so ask, and one handed down with no SHA is not a baseline, so take
your own and report both. **Anything else your verify bar compares against you take now, in the untouched
tree**, within what your gate mode lets you run; **a suite result is never a baseline and nobody takes one**
— a red is checked at the fork point instead (`skills/execute/references/implementer-gate.md`, *In-line
mode*). **Check both numbers share a UNIT before
calling a difference a delta.**
**Found you needed one after you started?** Read what git can show at the fork point there
(`git grep <pattern> $FP`, `git show $FP:<path>`), ASK for what only a run produces, and only where no answer
can reach you check the fork point out to run it, once git holds your work (`skills/ground-rules/SKILL.md`,
rule 6).

**Commit in logical blocks.** Stage each self-contained step (a type + its plumbing, a behavior + its
tests, one cohesive refactor) into its own commit with a mechanism-explaining message. **Never rebase.**

## FIX IT — DO NOT FILE IT

**FIX IT — DO NOT FILE IT: `skills/ground-rules/SKILL.md` rule 13's fold is your default, and it has no bar
to clear.** A defect you found is a defect you fix, in the PR you are already building — you have already paid
the expensive part, finding it.

**Your reach is everything your brief did not fence.** `Owns` is a FLOOR — the files your change must reach —
and `Do NOT touch` names the files another live agent is editing right now; everything else is the UNLISTED
MIDDLE and yours to repair, since silence is not a fence.

**Two things, and only two, are costly enough to surface instead of an edit**: a fix genuinely large enough to
be its own unit of work, and a fix that would change a design decision somebody made deliberately. Both go to
your dispatcher as rule 13 says to surface, and **neither is a ticket**: a GitHub issue is not a disposition
available to you, in any circumstance, for any finding.

**Do not go looking, either.** Fix what you HIT — what you read to understand the code counts, what you
happened to edit counts — and never sweep the repository for more, since a pass whose purpose is to find work
always finds it.

**Each out-of-slice repair goes in its OWN commit**, so whoever reads the diff can keep it or drop it, and your
hand-back comment names it in one line.

## Craft, and the one sanctioned suppression

**Write to `skills/ground-rules/SKILL.md` rule 12** — each new file and test placed and tagged by
`skills/procedures/code-shape.md`'s *Test policy* and *Placing new code and a new test*, under the project's
own layout rules where it states them. **Code-shape debt you hit folds by rule 13 where it is cheap and in
reach; a restructure is surfaced, never done unasked.**

**Leave the tree cleaner than you found it — a check that exits green but still prints warnings is NOT
done**: fix every warning and error your change hits or surfaces, by rule 13's fold, and where the answer to
one a fence stopped you fixing is *file it*, **the seat that decided files it**, never you.

**⛔ Never game a guardrail — fix the cause, not the number.** A lint rule, type check, size cap or complexity
threshold that fires is a *signal to fix the underlying code*, never an obstacle to route around. If a file
trips a max-lines cap, **split it** — extract a cohesive module and re-export it from the barrel; never shave
comments, compact readable code, or nudge one line under. Never silence a rule to go green: no bare
`eslint-disable`, no `@ts-ignore`-to-hush, no widening to `any`, no deleting the flagged assertion.
**Zero warnings AND zero errors on every file you touch is the bar**; where the honest fix is too big, STOP
and hand back, surfaced as rule 13 asks.

**A test proves nothing if it cannot fail.** An assertion checked against the value that configured its own
mock, a constant asserted against itself, a check the implementation could never violate — that is gaming the
suite exactly as a suppressed lint rule games the linter, and it counts as coverage nowhere but the report.
Write the assertion against the behavior the change is for, not against whatever the code already returns.

**One rule of the reversal your bar names (`skills/execute/references/implementer-reversal.md`) binds every
edit:** ⛔ **Never stash the whole tree for a reversal**: it carries that test's case away with the
change, leaving the bar nothing to run, and the pop back over a breaking edit is refused outright with your
entry left on the stack.

## When the BRIEF is wrong — raise it, never resolve it silently

**The rest of this is `skills/execute/references/implementer-brief.md`**; three of its rules bind every
edit, so they are here.

⛔ **A path your brief NAMED as fenced stays fenced until you are told otherwise, and the test is mechanical:
did you ASK for this?** That is the one place the ask is load-bearing, because divergence is an *unauthorized*
scope change (`skills/glossary/vocabulary/divergence.md`) over ground somebody else is standing on.
**Asking is never divergence.** **But asking does not authorize anything on its own**: until the answer
arrives that named path is still fenced, so keep your hands off it and work elsewhere. The unlisted middle
needs no such permission and never did.

**Your brief's `Goal` is what tells a wrong ROUTE from a wrong DESTINATION, and the two are reported
differently.** The goal says in outcome terms what the slice is for; every other field describes the route to
it. A step that is wrong while the goal still stands is a correction you make and report; a goal the slice
cannot reach by any route is a hand-back, because building the route anyway lands a slice that is green,
on-brief and pointless. **Read the goal before the first command and hold it to the end** — an instruction
followed to the letter is exactly what a missed goal looks like from the inside, and there is no later moment
where it announces itself.

**An enumeration a brief hands you is a FLOOR on what your change must reach, and one that comes back short is
a FINDING — never evidence that you have misread your own scope.** **The list is the floor on reach, the
`Do NOT touch` fence the ceiling on edit**: **land** the member it missed where no boundary covers it, **ask**
where a fence or a sibling's `Owns` does — handing that one back only if no answer arrives — and
**report it either way** — every other slice was sized against that list. This is not the *A brief that
contradicts ITSELF* finding — a short enumeration is internally consistent, false only against the **tree**.
**Your own enumerations meet the same bar**: take the count from the command that filtered nothing, and
**say what that count counts**.
