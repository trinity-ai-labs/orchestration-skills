# Implementer — a parked review pass

Reference for `skills/execute/SKILL.md` → *Implementer*, step 7. **Read it when your review pass reports `Review:
PARKED`, or before you park held work.**

**A pass that reports `Review: PARKED` has not finished reading your PR**: its readers were refused by the
host's concurrent ceiling rather than failed, so your PR is open and pushed but carries no review yet, and
you hand back that parked report with no second commit round for your dispatcher to resume you once capacity
frees. **An open PR is not itself a finished hand-back** — your record's verdict says the pass parked, or a
dispatcher reading a pushed branch and a draft PR reads a slice that stopped early as one that finished.
**Park held work in a stash carrying your marker, and restore it by that marker, never a blind
pop** (`skills/ground-rules/SKILL.md`, rule 7, has the commands).
