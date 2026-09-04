# integration branch

The **integration branch** is the shared branch this flow works off: worktrees are cut from it, slice PRs
merge back into it, and it is the branch a release is cut from. In one project it is `main`; in another a
long-lived `release/x.y.z`; under gitflow, `develop`. **It is DECLARED by the project, never derived** —
nothing in a repository states it, and a project that rolls its release branch restates it when it rolls,
in the same change that cuts the new branch.

**The term names the shared branch and never anything else.** An epic branch
(`skills/glossary/vocabulary/epic-branch.md`) sits above it and is cut from it, and slice branches sit
below; neither is an integration branch, and reading the word loosely is how tooling ends up keyed on a
level of the hierarchy that was never meant.

**It is the branch whose state everyone else inherits**, which is what makes an unshippable intermediate
state on it expensive: every worktree cut while it is broken forks from a broken base, and nothing about
that announces itself.

**Whether it is also the repository's DEFAULT branch is a separate question with real consequences.** The
two coincide in some projects and not others, and several behaviours turn on the default branch rather
than on this one — see `skills/glossary/mechanics/closing-keyword.md`. **Neither can be read off the
other**, in either direction: a project whose work lands on its default branch and one whose default
branch is a release branch it does not work on are both ordinary, and a local ref recording the default
can be stale, so an inference from it is wrong without erroring.
