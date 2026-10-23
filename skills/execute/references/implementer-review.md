# Implementer — the review pass

Reference for `skills/execute/SKILL.md` → *Implementer*, step 7. **Read it when your brief says to run
`/pipeline:review`.** The step's hard stops are on the spine; this is what they leave out.

**Whether you run `/pipeline:review` is the dispatcher's call, made per slice in your brief.** If it says run
it, commit in blocks as the work lands, push, and open your draft PR exactly as a slice running no pass
would, and only THEN run the pass — against that PR, whose diff is what it and its readers read. Before you
apply what you accept, surface first, by name, any behaviour a fix would remove or degrade (rule 13).
**Where the panel finds nothing to apply there is nothing more to do**: its review and dimension comments are
posted on your PR, your one commit round already stands, and you go straight to the hand-back.

**The fix round is the last one the pass causes** — the panel has already read the diff those fixes answer,
and their readers are your dispatcher's review of the diff and the gate.

**`/pipeline:review` hands each reviewer the slice's goal, the PR and its resolved base, the diff and its
dimension, and none of your *commit, push, PR, hand back* imperatives** — a fresh agent handed them carries
them out as surely as a fork. Every reviewer reports and does nothing else, so a commit, a push, a PR or a
review posted by a READER while it runs is a runaway to revert before you read a finding. **The pass itself
posts one review onto your PR and one comment beside it per dimension it dispatched**, which are the only
GitHub writes it is authorized to make and the only ones you should find there from it. A reviewer that
dispatched readers of its own re-sizes from inside the reader count the pass sized.

**A filing a reviewer performed leaves nothing in your tree**, so it is read off the tracker rather than off a
clean `git status`, the finding comes back into the pass's own flagged list, and the number goes under your
record's decisions needed by name.

**A pass that reports `Review: PARKED` leaves your record's verdict saying the pass parked**, or a dispatcher
reading a pushed branch and a draft PR reads a slice that stopped early as one that finished.

**Wait on sub-agents you spawned by ending your turn with no tool call, where your host re-invokes you as each
one reports — that is safe: it hands nothing back, and each report arrives as a new turn**
(`skills/procedures/host-tools.md`'s wait row says whether yours does, and what you can read to tell).
**Never make a call whose result you do not need just so your turn does not end** — the ban is on that
purpose, not a tool, so a host call that blocks until a child reports is the same wait where your host has
one. **Where it has NEITHER, ending your turn loses your hand-back, so hand back on what has landed and name
the children still out** rather than waiting silently on a re-invocation that is not coming — a blank row in
that table is this third branch until your own tool list says otherwise.
