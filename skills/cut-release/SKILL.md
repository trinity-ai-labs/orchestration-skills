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

**Why it exists: cutting a release branch is the one moment nothing in this pipeline was present for.** So `integrationBranch` went stale, the version moved invisibly, and the flow could only notice the damage afterwards. Owning that moment is the whole job.

⛔ **The repository side, and nothing past it.** Bump the declared files, open the changelog section, cut the branch, move the config. **No tags, no publishing, no deploys, no announcements, no CI triggers** — those are per-project and belong to whoever owns the release, and a pass reaching for them is a pass inventing policy it cannot know.

---

## 0. Refuse while any worktree is live

**The config is frozen once worktrees exist** (`skills/execute/references/per-project-config.md`), and this pass changes `integrationBranch` — the value every one of those trees was cut against. Read `git worktree list --porcelain`, and where any tree other than the main checkout is standing, **stop and say which**. Finish or tear down the arc first.

**This is a hard stop rather than a warning**, because the damage is silent: a live slice keeps gating and merging against a branch the project has just moved past, and every signal it produces reads clean.

## 1. Say where you are and what you are about to do — then wait

**Observe rather than configure.** The main checkout's current branch is what a release is cut *from*, and `git rev-parse --abbrev-ref HEAD` answers it. Read the project's config for `bumpFiles`, `changelog` and `integrationBranch`, and the current version out of the first `bumpFiles` entry.

Put all of it in one sentence and stop:

> *You are on `dev`, at version 0.4.0. I will cut `release/0.5.0` from it, bump `<the bumpFiles>`, open a `## 0.5.0` section in `<changelog>`, and point `integrationBranch` at the new branch — one commit, in its own worktree. Right?*

⛔ **Nothing below happens without that yes.** The version is a product decision, the branch name outlives the arc, and both are cheap to correct now and expensive later.

- **Where the project declares no `bumpFiles`** its version is not hand-edited — tooling owns it, or there is none — so say that and stop rather than editing a file the project's own tooling maintains.
- **Where `integrationBranch` already IS the branch you are standing on**, work lands where releases are cut and there is no branch to roll: this is a **version bump only**. Say so, and skip step 2.

## 2. Cut the branch, in a worktree

`setup-worktree <new-branch> <the branch you are standing on>`, and verify the four invariants as any dispatch would (`skills/execute/references/worktrees-and-branches.md`). **Never in the main checkout** — it is the one piece of shared mutable state here, and another session cutting a worktree reads whatever branch it is standing on.

## 3. One commit: the bump, the changelog, the config

In that worktree, and in this order, as a **single commit** — the version, its changelog section and the config that names the branch are one fact, and a reader landing on a commit carrying two of the three cannot tell which is authoritative.

1. **Every path in `bumpFiles`.** All of them: the key is a claim of completeness precisely because a repository can carry a version in more than one place and ship a different one to each consumer.
2. **A new section in `changelog`**, at the top, headed with the version. Written from what has landed since the last section — the merged history is the source, never recollection.
3. **`integrationBranch` in `.agents/worktree.json`**, or the workspace manifest where one declares it, pointed at the new branch. **In this same commit**: it is the field that stops the two facts drifting, so a commit that moves one without the other rebuilds the drift this pass exists to end.

⛔ **Whether the branch you cut FROM also moves its version is the project's habit, not this pass's policy — read it, then ask.** The previous rollover is in the history: find the last commit that moved these files and see whether the branch you are standing on carried a version change too. Do the same. **Where there is no previous rollover to read, ask once** and say you are asking because there is no precedent.

## 4. Hand it over

Push, open a **PR**, and stop. **You do not merge it** — same rule and the same reason as `/pipeline:setup`: this changes how every later worktree is provisioned, and the diff is the only review that fact gets.

**Say in the hand-back what nothing downstream can see**: which branch it was cut from, the version before and after, every file the bump touched, whether the base branch's version moved and on what evidence, and that `integrationBranch` moves **when this merges** — so until then every new worktree is still cut against the old branch.

> **Ready to review.** `<new-branch>` is cut and the bump is on it. Merge the PR, then bring the main checkout up to date before cutting any worktree, since the helper reads that working copy rather than the remote.
