# branching model

The **branching model** is a project's answer to one question: which branch does work land on, and what
happens to that branch afterwards. Three shapes cover the field.

- **`trunk`** — the integration branch (`skills/glossary/vocabulary/integration-branch.md`) is the
  repository's default branch. Work lands on it and is released from it; there is no branch above it.
- **`release`** — the integration branch is a long-lived `release/x.y.z`. Work lands there, and getting
  that branch OUT — into `main`, `dev`, or wherever a release goes — is a separate event.
- **`gitflow`** — the integration branch is `develop`. `release/*` and `hotfix/*` branches exist, and they
  carry releases rather than arcs.

**It is DECLARED, never inferred.** Nothing in a repository states it: a branch called `release/0.4.0` may
be a long-lived integration branch or a gitflow release branch, and the two want opposite handling. The
declaration lives in `.agents/worktree.json` as `branchingModel`, or in `.agents/workspace.json` for a
workspace whose members share one branch and one model, where the workspace's answer wins.

**Whether the integration branch is also the repository's DEFAULT branch is a separate fact, and it is not
the model.** Under `trunk` the two are the same branch by definition, but a `release` project commonly
makes its release branch the default branch as well, so the default branch cannot be read backwards as
evidence of the model. That inference is the specific mistake this term exists to prevent: it is correct in
one direction and wrong in the other, which makes it look reliable right up to the project where it is not.

**Only the epic branch (`skills/glossary/vocabulary/epic-branch.md`) sits above the integration branch, and
only within a single arc.** A `release/*` or `hotfix/*` branch under `gitflow` is not one — it is scaffolding
for a release, cut and merged on the release's schedule rather than an arc's.

**What each model puts OUT of scope is part of the definition.** This flow's terminal is always the
integration branch. Under `release` and `gitflow`, moving that branch onward is a release event the flow
does not perform; under `trunk` there is nothing further to move.
