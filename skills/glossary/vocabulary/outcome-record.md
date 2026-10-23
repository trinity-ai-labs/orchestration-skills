# outcome record

An **outcome record** is the comment a dispatcher posts onto an issue as it closes that issue, keyed
`outcome/<n>/<pr>` with the issue's number and the PR that settled it. It is the issue's own account of what
happened to it, written so a reader landing on the closed issue learns that without opening a PR or a
transcript — **a record, not a pointer to one**.

It carries the PR that settled the issue, the merge commit and the base it landed on; the dispatcher's
verdict on the goal; whether the review pass ran, was skipped and why, or was left to a review checkpoint
(`skills/glossary/vocabulary/review-checkpoint.md`); the findings that pass rejected and flagged; links to the
PR's dimension comments, its reviews and its gate comment; and the other PRs that landed beside it. An
umbrella's (`skills/glossary/vocabulary/umbrella.md`) names the close-out PR and each leaf's PR.

**Each closing PR adds its own outcome record**, since the key carries the PR: an issue closed again by a later
PR gains a second record rather than having the first overwritten.

**An outcome record is not a hand-back record** (`skills/glossary/vocabulary/hand-back-record.md`). The
hand-back record travels up from a dispatched seat to its dispatcher while the PR is still open; the outcome
record is written onto the issue once the work has merged, and outlives every agent in the run.
