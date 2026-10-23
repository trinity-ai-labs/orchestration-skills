# Implementer — hand back

Reference for `skills/execute/SKILL.md` → *Implementer*, step 8. **Read it before you hand back, in either gate
mode.**

4. **Hand back — a short record, with the detail in ONE comment on your PR.** The record's fields are
   `skills/glossary/vocabulary/hand-back-record.md`'s, and the record carries nothing else, since your
   dispatcher holds every slice's record across a long arc and reads the detail where it lives.
   **First post the hand-back comment** —
   `gh-post.sh comment pr <n> --key handback/<leaf> --body-file <file>`, which a later hand-back on the same
   PR edits in place — carrying every line this reference sends to "your hand-back comment":
   - **tests touched**, and any reversal you did not run;
   - **the per-doc verdict** — each doc updated or not-affected-because, never a bare "docs reviewed" — and on
     an epic slice the ledger's entries;
   - **every question you asked and what came back**, an answer's ground included;
   - **every grant you acted on**: where it was written down, or plainly that nothing was or that only the
     issue carries it, since your comment is then its only record on the PR — and, where the slice ran a
     pass, whether you acted on it BEFORE that pass ran or AFTER it reported, since only the second produces
     an edit no reviewer read;
   - **every correction**: what you were told and what you did about it;
   - **each out-of-slice repair**, one line naming its commit; **each suppression you added**; **each test
     file you took inside a fence**;
   - where you are stuck, **your worktree state and the error**.
   **The review pass's applied and rejected findings are already on the PR** — its review and the dimension
   comments beside it — so the comment restates none of them.
   **Then hand back the record**, every field the entry names filled: its decisions needed each surfaced as
   rule 13 asks, a reviewer's filing by its number among them, and under *Carried elsewhere* the hand-back
   comment's URL, the gate-verdict comment's, the review's and each
   dimension comment's, and **any stash of yours still on the stack** by its marker and restore command.
   **Where no PR could be opened, the detail rides in the record itself**, since there is no PR to carry the
   comment. Do NOT wait for the gate.

**Before you report a NEGATIVE from your verify bar, measure it against the FORK POINT — never your own last
commit, and never `HEAD`.** *X is unchanged*, *no new Y*, *that grep comes back empty* are claims about a
difference, worth as much as their base: `git merge-base HEAD origin/<base>`. Your previous commit sits
**inside** the change you assert about, so a claim checked against it is true whatever the work did.
**Where the honest answer is narrower than the bar's phrasing, report the narrow one.**

**A verify bar's command is an INSTRUMENT and the sentence beside it is a PROPERTY — a command that could not
have fired is a finding, not a pass.** An instrument **narrower** than its property fails a correct slice and
you find out, because you are stuck; one **wider**, or with **no instances** on the files it names, comes back
green carrying no information. So where the command could not have gone red on your tree,
**report that it could not fire, and name the property it stood for**.
