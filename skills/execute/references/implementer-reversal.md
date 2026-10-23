# Implementer — the reversal

Reference for `skills/execute/SKILL.md` → *Implementer*, step 3. **Read it before you make the reversal your
verify bar names.** Its one rule that binds every edit — never stash the whole tree for a reversal — is on
`skills/execute/references/implementer.md`.

**PROVING it can fail — the reversal your bar names — MOVES your tree, so git holds that work before it
moves** (`skills/ground-rules/SKILL.md`, rule 6), **or you arrive at the restore with no object to come back
to and take the quickest way out instead.** **What picks the shape is that a reversal needs the fix's test
STANDING while the code under it is pre-change**: commit the work, make the breaking edit, run that test by
the one targeted test run, then restore with `git checkout -- <file>` or from that commit; or, with nothing
commit-ready, push a marked stash of the PRODUCTION file alone — that push is itself the breaking edit, it
leaves that test in the tree, and popping that one entry by its marker puts the file back (rule 7 has the push
and the resolve). **Where your slice's fork point already carries the pre-change behaviour, run the
reversal against the FORK POINT and leave your tree where it stands.** ⚠️ **"Confirmed by reading the diff" is
an UNRUN reversal**, so where that is all you have, say in your hand-back comment that no reversal was run rather than
reporting the bar met — a diff shows what the change did, never what the test does when the change is taken
back out.
