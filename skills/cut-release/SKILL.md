---
name: cut-release
description: >-
  Cut the next release branch and move the version, in a worktree, as one reviewable change. Use when
  someone asks to CUT a release, start the next release cycle, roll the release branch, or bump the
  version — and when a pass reports that `integrationBranch` names a branch the main checkout is not
  standing on, which is what a rolled branch and a stale config look like. It does the repository side
  only: it never tags, publishes, deploys or announces.
argument-hint: "[the version to cut, e.g. 0.5.0 — omit and it will work one out and confirm]"
---

# cut-release — roll the version, and the branch if there is one

**A project pass, not an arc pass.** `/pipeline:setup` answers *how does this project build and gate*; this one answers *the version moved, and so did the branch work lands on*. Both run **beside** the arc rather than inside it, both work in their own worktree, and both **terminate at a reviewable change they do not merge**.

**Why it exists: cutting a release branch is the one moment nothing in this pipeline was present for.** So the config went stale, the version moved invisibly, and the flow could only notice the damage afterwards. Owning that moment is the whole job.

⛔ **The repository side, and nothing past it.** Bump the declared files, open the changelog section, cut the branch, move the config. **No tags, no publishing, no deploys, no announcements, no CI triggers** — those belong to whoever owns the release, and a pass reaching for them invents policy it cannot know.

---

## 0. Refuse while any worktree is live

**A project's config is frozen once worktrees exist**, because the helper that cuts them reads the main checkout's working copy and every live tree was provisioned from it. This pass rewrites `integrationBranch` — the value those trees were cut against — so read `git worktree list --porcelain`, and where any tree other than the main checkout is standing, **stop and say which**. Finish or tear down the arc first.

**A hard stop rather than a warning**, because the damage is silent: a live slice keeps gating and merging against a branch the project has just moved past, and every signal it produces reads clean.

## 1. Say where you are and what you are about to do — then wait

**Observe rather than configure.** The branch the main checkout is standing on is what a release is cut *from*; `git rev-parse --abbrev-ref HEAD` answers it. Read the project's config for `bumpFiles`, `changelog` and `integrationBranch`, and the current version out of the first `bumpFiles` entry.

Put it in one sentence and stop:

> *You are on `<branch>`, at version `<current>`. I will cut `<new-branch>` from it, bump `<the bumpFiles>`, open a `## <version>` section in `<changelog>`, and point `integrationBranch` at the new branch — one commit, in its own worktree. Right?*

⛔ **Nothing below happens without that yes.** The version is a product decision and the branch name outlives the arc; both are cheap to correct now and expensive later.

- **No `bumpFiles` declared** means nothing here hand-edits a version — tooling owns it, or the project does not version. Say so and stop, rather than editing a file the project's own tooling maintains.
- **Standing on the integration branch itself** means work lands where releases are cut, so there is no branch to roll: this is a **version bump only**. It still takes a worktree and still lands as a PR — take route B below.

## 2. Route A — there is a branch to cut

1. **Create the new branch and push it**, from the branch you are standing on. It is a branch pointer and nothing else yet.
2. **Cut a worktree off the NEW branch** for the bump, with `setup-worktree <a-branch-for-the-bump> <new-branch>`, and verify what it prints: the path is the one it reports, its `HEAD` matches the tip you asked for, and it is standing on the branch you asked for. **Never work in the main checkout** — it is the one piece of shared mutable state here, and another session cutting a worktree reads whatever branch it is standing on.
3. **The bump PRs into the new release branch** (step 4). That is the only valid base: the new branch is not merged into the old one, and never will be — it *replaces* it as the branch work lands on.

## 2b. Route B — version bump only

`setup-worktree <a-branch-for-the-bump> <the integration branch>`, same verification. **The bump PRs into the integration branch**, like any other change. There is no new branch, so `integrationBranch` does not move and step 3's third item does not apply.

## 3. One commit: the bump, the changelog, and the config where it moves

In that worktree, as a **single commit** — the version, its changelog section and the config naming the branch are one fact, and a reader landing on a commit carrying two of the three cannot tell which is authoritative.

1. **Every path in `bumpFiles`.** All of them: the key is a claim of completeness precisely because a repository can carry a version in more than one place and ship a different one to each consumer.
2. **A new section in `changelog`**, at the top, headed with the version, written from what has landed since the last section — the merged history is the source, never recollection.
3. **Route A only: `integrationBranch`**, in `.agents/worktree.json` or the workspace manifest that declares it, pointed at the new branch. **In this same commit**: it is the field that stops the two facts drifting, so moving one without the other rebuilds the drift this pass exists to end.

⛔ **Whether the branch you cut FROM also moves its version is the project's habit, not this pass's policy — read it, then ask.** Find the last commit that moved these files and see whether the branch you are standing on carried a version change too. Do the same. **Where there is no previous rollover to read, ask once**, and say you are asking because there is no precedent.

## 4. Hand it over

Push, open the PR against the base its route names, and stop. **You do not merge it** — this changes how every later worktree is provisioned, and the diff is the only review that fact gets.

**Say in the hand-back what nothing downstream can see**: the branch it was cut from, the version before and after, every file the bump touched, whether the base branch's version moved and on what evidence, and — on route A — that **the main checkout has to end up on the new branch**. That is not a detail: the main checkout holds the branch work lands on, the helper reads its working copy, and until it is switched every new worktree is still cut against the old branch with the old config.

> **Ready to review.** `<new-branch>` is cut and the bump is on `<bump-branch>`, PR'd into it. Merge that, then point the main checkout at `<new-branch>` — until you do, the helpers still read the old branch's config.
