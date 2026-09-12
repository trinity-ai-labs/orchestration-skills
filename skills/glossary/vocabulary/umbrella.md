# umbrella

An **umbrella** is one issue that tracks several others: its body carries the overview and a checklist
whose lines stand for the remaining work, each either linking a child or naming an item that has no child
yet, and each child carries a backlink to it. It is a **tracking shape** — a fact about the
issue tracker, and nothing else.

**An umbrella and its children are a TWO-LEVEL TREE, and the children are LEAVES: one child = one slice =
one worktree = one PR.** That mapping is a constraint rather than a default — there is no *usually* and no
*unless the work turns out large* — and it is what makes the thing a cycle lands and the thing the tracker
holds the same object, so a checklist line ticks as work lands rather than standing still while it does.

**Its shape is fixed where the issues are authored**: the tree has exactly two levels, and nothing below
that point adds one. A leaf whose work turns out to exceed one PR is a defect in how the tree was cut,
not a leaf with parts; N leaves whose work turns out to be one PR's worth of one change are the same
defect at the other end.

**An umbrella is not an epic branch, and having one settles nothing about the other.** The branch is a
lifecycle in git (`skills/glossary/vocabulary/epic-branch.md`); the umbrella is a shape in the tracker.
The word "epic" is used for both, which is exactly why they are separate entries: work can have either,
both or neither.

**The checklist and the native parent/child relationship are two different artifacts**, not one rendered
two ways — see `skills/glossary/mechanics/sub-issue-link.md`. A child linked one way and not the other is
a normal state, and an agent arriving at a child sees only what that child's own body carries.

**Its body is state rather than history**: it holds what remains, rewritten as work lands, while the
comment thread holds what happened.
