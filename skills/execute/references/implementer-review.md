# Implementer — the review pass

Reference for `skills/execute/SKILL.md` → *Implementer*, step 7. **Read it when your brief says to run
`/pipeline:review`.** A pass that reports `Review: PARKED` is `skills/execute/references/implementer-park.md`.

**Whether you run `/pipeline:review` is the dispatcher's call, made per slice in your brief.** If it says run
it, commit in blocks as the work lands, push, and open your draft PR exactly as a slice running no pass
would, and only THEN run the pass — against that PR, whose diff is what it and its readers read. Wait until
every reviewer has reported before you change anything, apply what you accept — surfacing first, by name, any
behaviour a fix would remove or degrade (rule 13) — run the preflight over
what you applied, make **one more** commit, and push it onto the same PR, which is never closed and never
reopened. **Where the panel finds nothing to apply there is nothing more to do**: its review and dimension
comments are posted on your PR, your one commit round already stands, and you go straight to the hand-back.

**The pass does not re-trigger itself, and its second commit round is the last one it causes.** A fix round
you make on its findings is not a reason to run it again — the panel has already read the diff those fixes
answer, and their readers are your dispatcher's review of the diff and the gate. **A dispatcher that
explicitly asks for another pass on this PR is not that loop**, and you run it as you would any instruction
arriving mid-run.

⛔ **Never a quality pass that FORKS its reviewers, and never one that hands a reviewer this brief** — a fork
inherits it and carries out its *commit, push, PR, hand back* imperatives for you before you get your turn
back, and a fresh agent handed those same imperatives does it too. `/pipeline:review` dispatches one FRESH
reviewer per dimension, hands each the slice's goal, the PR and its resolved base, the diff and its dimension
and none of those imperatives, and stays the only party that edits your tree — every reviewer reports and
does nothing else, so a commit, a push, a PR or a review posted by a READER while it runs is a runaway to
revert before you read a finding. **The pass itself posts one review onto your PR and one comment beside it
per dimension it dispatched**, which are the only GitHub writes it is authorized to make and the only ones you
should find there from it.
**And every reviewer is the LAST agent in the chain — its brief says in as many words that it dispatches
nothing of its own**, or the reader count the pass sized is re-sized from inside it and you weigh findings
nobody in the chain established firsthand.

⛔ **Every one of those briefs also states that a GitHub issue is not a disposition available to that reviewer,
in any circumstance, for any finding, with the reason beside it** — a filing from a reader spends a whole unit
of work on what one line in its report settles, and the ban stated only here reaches no reviewer. **A filing a
reviewer performed leaves nothing in your tree**, so it is read off the tracker rather than off a clean
`git status`, the finding comes back into the pass's own flagged list, and the number goes under your record's decisions
needed by name.

**Wait on sub-agents you spawned by ending your turn with no tool call, where your host re-invokes you as each
one reports — that is safe: it hands nothing back, and each report arrives as a new turn**
(`skills/procedures/host-tools.md`'s wait row says whether yours does, and what you can read to tell).
**Never make a call whose result you do not need just so your turn does not end** — the ban is on that
purpose, not a tool, so a host call that blocks until a child reports is the same wait where your host has
one. **Where it has NEITHER, ending your turn loses your hand-back, so hand back on what has landed and name
the children still out** rather than waiting silently on a re-invocation that is not coming — a blank row in
that table is this third branch until your own tool list says otherwise.

3. **Run `/pipeline:review` where your brief says to — against THIS PR, by the number you just captured.**
   It reads that PR's diff and posts its findings onto it as a review, with one comment beside it per
   dimension it dispatched. Where it raises something you accept,
   apply it, run the preflight, make **one more** commit and push it onto the same PR — never a second PR
   and never a reopen. Where it raises nothing you accept, or reports `Review: PARKED`, there is no second
   commit round and you go straight to the hand-back.
