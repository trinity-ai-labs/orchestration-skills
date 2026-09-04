# epic branch

An **epic branch** is a convergence branch cut from the integration branch (`skills/glossary/vocabulary/integration-branch.md`). An epic's slices fork from it
and PR into it; once they have all landed it is gated as a whole and merged back in one PR. So the shared
branch never carries the epic half-finished — it sees the arc once, finished.

It is one optional level above that branch, and it holds one arc. Single-slice work never cuts
one, and a pass reads the same whether or not one exists.

**An epic branch is not an umbrella (`skills/glossary/vocabulary/umbrella.md`), and having one settles nothing about the other.** An umbrella is a
*tracking shape* — one issue holding a checklist of sub-issues, a fact about the tracker. An epic branch
is a *branch lifecycle* — a real ref that worktrees fork from and PRs target, a fact about git. The word
"epic" names both, which is the whole reason to say it here: an arc can have either, both or neither.
