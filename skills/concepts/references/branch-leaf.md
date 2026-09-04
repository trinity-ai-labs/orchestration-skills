# branch leaf

A branch's **leaf** is the segment of its name after the last `/` — `feat/toasts-top-right` has the leaf
`toasts-top-right`.

**The leaf is mechanically load-bearing and the prefix is not.** A worktree's directory is derived from
the leaf, so two branches whose names end in the same segment resolve to the same directory even when
their full names differ — `epic/checkout-flow` and `feat/checkout-flow` collide. The prefix (`feat/`,
`fix/`, `docs/`, `epic/`) is read by nothing and carries no behaviour.

**A leaf collision is refused rather than silently shared**, so it surfaces as a helper declining to hand
back a worktree rather than as two branches quietly sharing one tree.
