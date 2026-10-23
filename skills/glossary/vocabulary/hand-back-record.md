# hand-back record

A **hand-back record** is the short report a dispatched seat returns to the seat that dispatched it when it
hands back: an implementer to its dispatcher, and a review pass to its caller. It carries six fields and
nothing else:

- **Verdict** — the one-line state the seat stopped in: done; blocked, with the decision it waits on; parked,
  as `Review: PARKED` with the dimensions still to go; goal unreachable by any route; or handed back with
  children still out, naming them. For a review pass it is also the goal verdict on the diff.
- **PR** — the pull request's number and URL, or that none could be opened.
- **Head SHA** — the PR's head commit at the moment of hand-back.
- **Gate result** — the gate's exit and the SHA it ran against, with the URL of the comment carrying its
  verdict, where the seat ran one; otherwise the preflight's result and why no gate ran there.
- **Decisions needed** — each question or finding the receiving seat has to settle, with the recommendation,
  the alternatives and what each costs; or `none`.
- **Carried elsewhere** — every other item the hand-back reaches, each with its address: a comment's URL, a
  review's URL, a stash's marker and restore command.

**Everything else lives at an address, not in the record.** For an implementer the main one is the
**hand-back comment**: one comment on its own PR, keyed `handback/<leaf>` with the branch leaf
(`skills/glossary/mechanics/branch-leaf.md`), holding the detail behind the record. For a review pass it is
the review it posted and the one comment per dimension beside it. The record names each of those addresses
under *Carried elsewhere*, so a detail dropped from the record keeps a durable home.

**A hand-back record is not an outcome record** (`skills/glossary/vocabulary/outcome-record.md`). The
hand-back record travels up from a dispatched seat while its PR is still open; the outcome record is
written by the dispatcher onto an issue when that issue closes.
