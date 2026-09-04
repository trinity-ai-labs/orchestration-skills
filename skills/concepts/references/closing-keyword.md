# closing keyword

A closing keyword is `Closes #<n>` / `Fixes #<n>` / `Resolves #<n>` in a pull request description, which
GitHub may act on when the PR merges.

**It is interpreted only when the pull request targets the repository's DEFAULT branch.** Targeting any
other branch, the keyword is ignored, no link is created, and merging the PR has no effect on the issue.

**The predicate is the PR's base against the repository's default branch — not "a release or epic branch".**
Those stand in for it only where they are different branches from the default one. A project whose
integration branch simply *is* the default branch has nothing between a PR and that branch, so the keyword
is **live** there.

**Where the base is not the default branch, the keyword does not fire later either.** It belongs to a pull
request whose base was never the default branch, and nothing re-evaluates it when that branch eventually
merges onward.

**A closing keyword in a COMMIT MESSAGE is a different mechanism**: it acts when the commit reaches the
default branch, which can be much later.
