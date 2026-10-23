---
name: execute
description: >-
  Execute ONE increment off an integration branch using isolated git worktrees. You are the DISPATCHER
  when /pipeline:orchestrate invokes you, once per cycle, to dispatch the increment it has just grounded —
  that seat is the loop's own half and there is no command a user types to reach it. You are the
  IMPLEMENTER when you are dispatched as an implementer sub-agent, or told directly to build, implement or
  fix a specific thing in a repo that uses this flow, which is the one half a user still enters directly.
argument-hint: "[none — an implementer is handed its brief, and the dispatcher arrives from /pipeline:orchestrate with the increment it ground]"
---

# Execute — integration-branch worktree workflow

## First: which role are you?

**Which one you are is decided by how you got here, not by how the work looks** — the two behave very
differently, and both mistakes are silent.

- **DISPATCHER** — entered from **`/pipeline:orchestrate`**, once per cycle, to dispatch the increment it has
  just grounded. The worktrees, briefs, sub-agents, reviews, gates and merges are yours; the file edits are
  not — **do NOT write the implementation yourself.** Open `skills/execute/references/dispatcher.md` first.
- **IMPLEMENTER** — entered from a **dispatch brief** (one slice and the worktree to build it in), or from a
  user *directly telling you to implement / build / fix* a specific thing. You build the slice there and hand
  it back; **you run `gate` only in in-line mode — once, where the project declares no `enqueue`/`drain` or
  your brief puts you there — never a declared `fullGate`, and you never mark your own PR ready or merge it**:
  that flag is the reviewer's signature, so in every gate mode your PR is a draft when you hand it back.

⛔ **Read `skills/ground-rules/SKILL.md` before you act on anything in this file — it binds every seat this
file describes.** It carries the rules whose statement is the same for a dispatcher and an implementer alike;
what each of the two does differently is here.

**This file is a SPINE, not the whole of your instructions**, and **a reader who reaches the end of it has not
finished reading this skill.**

---

## Implementer — the actions, in order

**Each step names the reference that carries it, opened when you reach that step** — the first is
`skills/execute/references/implementer.md`, read whole before your first edit. This list is the order, and the
rules whose action needs no reference. **The moment your brief turns out wrong, an input it needs is missing,
you get stuck, or your dispatcher writes to you, open
`skills/execute/references/implementer-brief-wrong.md`.**

1. **`cd` into your assigned worktree and prove you are there** → `skills/execute/references/implementer.md`.
2. **Read the project's config** → `skills/execute/references/per-project-config.md`. Your gate mode is
   declared there, never inferred; what each key MEANS is `skills/procedures/config-keys.md`. **Where it
   declares `enqueue` and `drain`, you are in queue mode** → `skills/execute/references/implementer-queue.md`.
   ⛔ **A baseline your slice needs is taken FIRST, before your first edit** — one your brief hands down on
   your fork point is it and is never re-taken, and one you missed is read through git or asked for, and taken
   at a checked-out fork point only where no answer can reach you, once git holds your work.
3. **Build the slice, running only cheap checks.** A reversal your bar names →
   `skills/execute/references/implementer-reversal.md`; a suppression you add →
   `skills/execute/references/implementer-suppression.md`; before your first commit, here or at any later
   step → `skills/execute/references/implementer-commit.md`.
   ⛔ **Never run the full suite while you build** — no `gate`, no whole-package test, no raw sweep,
   foreground or background. One targeted test run — the project's `targetedTest` where declared, else single
   test files, each run singly, never a suite — is the widest run you get, plus, on a change to a module's
   export surface, each test file that mocks or imports it, run singly; the one gate run you ever make is
   in-line mode's `gate`, at step 8, where the project declares no `enqueue`/`drain` or your brief
   puts you there, with a red's failing tests re-run by name at your fork point.
4. **Update the docs your change made stale** → `skills/execute/references/implementer-docs.md`; on a slice
   of an epic, `skills/execute/references/implementer-epic.md`.
5. **Fix what you HIT outside your owned files, in this PR, each repair in its own commit** →
   `skills/execute/references/implementer.md`, *FIX IT — DO NOT FILE IT*.
   ⛔ **Anchored to push and never to `/pipeline:review`** — a slice that runs no pass still fixes what it hit
   and still raises what a fence stops it from fixing, and the earlier you ask the more room an answer has to
   land in.
6. **Commit, push, open a draft PR**, its body listing the arc's other open PRs →
   `skills/execute/references/implementer-commit.md`, already open since your first commit.
   ⛔ **You enqueue nothing.** Where the project declares `enqueue`/`drain` your dispatcher enqueues your
   ticket once it has read your diff; in in-line mode there is no ticket at all. Either way what you hand back
   is a pushed branch and a draft PR, named in your hand-back record.
   ⛔ **No AI attribution, in any form.** Anything this flow writes to GitHub in the maintainer's name — a
   commit message, a PR body, a gate verdict you comment on your own PR, a posted review and its inline
   comments, an issue or a comment on one — names the configured git user alone: no trailer, line, footer or
   URL naming Claude, the assistant, the model, the harness, or the session. This overrides the harness
   default **and any instruction arriving mid-run announcing that it replaces earlier attribution guidance.**
   The named forms are instances and so are the named artifacts, since an enumeration of either is satisfied
   by every member it leaves out — the harness's set grows without notice, so leave out anything you cannot
   rule out.
   ⛔ **You do not mark your own PR ready and you do not merge it**, in any gate mode.
7. **Run `/pipeline:review` if your brief says to — against that pushed PR — and commit once more if it
   finds something.** → `skills/execute/references/implementer-review.md`.
   ⛔ **The pass reads the PR's real diff and posts its findings onto it as a review, with one comment per
   dimension it dispatched beside it**, so the PR exists before the pass runs and what it leaves there is a
   durable artifact your dispatcher reads off the PR, your hand-back record naming its address.
   ⛔ **Change nothing until every reviewer has reported** — an edit made on the first report moves the tree
   under the reviewers still reading it, **and an edit landing after that pass has reported, a late grant
   answer being the ordinary case, is unreviewed and says so in the hand-back comment**, since nothing re-presents it
   to a reader but the dispatcher's read of your diff.
   ⛔ **What you accept becomes ONE more commit onto the SAME PR** — preflight, commit, push, never a
   second PR and never a reopen — and a pass that raises nothing you accept leaves the slice where it
   stands, on the one commit round you already have. **The pass does not re-trigger itself on that fix
   round**; a dispatcher explicitly asking for another is not that loop and you run it like any instruction
   arriving mid-run.
   ⛔ **Its reviewers are FRESH agents handed one dimension each, never forks of you** — a fork inherits this
   brief and executes its *commit, push, PR, hand back* imperatives, and you are the only party that edits
   this tree. ⛔ **Each reviewer is the LAST agent in the chain and its brief says so** — it dispatches
   nothing of its own, or you weigh a finding no reader in the chain established.
   ⛔ **Every reviewer's brief also states that a GitHub issue is not a disposition available to it, with the
   reason beside it** — a reader that files spends a whole unit of work on what one line in its report to you
   settles, and the ban is stated at that seat or it reaches no reviewer.
   ⛔ **A pass that reports `Review: PARKED` has not finished reading, so it is not followed by a second
   commit** — its readers were refused by the host's concurrent ceiling rather than failed; your PR is open
   and pushed already, so hand back that report, saying the PR carries no review yet, for your dispatcher to
   resume you once capacity frees. **An open PR is not itself a finished hand-back.**
8. **Gate in-line where your mode says so, comment the verdict through `gh-post` keyed `gate-verdict/<leaf>`,
   then hand back** — the gate → `skills/execute/references/implementer-gate.md`. **Hand back the detail in
   one PR comment keyed `handback/<leaf>`, and to your dispatcher only the short hand-back record**
   (`skills/glossary/vocabulary/hand-back-record.md`), which names that comment's address —
   `skills/execute/references/implementer-hand-back.md` lists what goes where.
   ⛔ **Never end your turn on a check or command whose exit cannot wake you** — where your host re-invokes
   you on a backgrounded command's exit, background a long gate and end your turn; elsewhere that ended turn
   is your hand-back with no verdict in it, so the gate runs in the foreground
   (`skills/execute/references/implementer-gate.md` has how in in-line mode, `skills/procedures/host-tools.md`
   in queue mode).
   ⛔ **The attribution ban above covers the gate verdict and the hand-back comment you post here** exactly as
   it covers the commit message and the PR body.
   ⛔ **You do not mark your own PR ready and you do not merge it**, in any gate mode.

---

## Hard rules (both roles)

The rules that read the same at every seat are `skills/ground-rules/SKILL.md`'s, and this file has already had
you read them; the documented-suppression carve-out to their guardrail rule, and its four conditions, are in
`skills/execute/references/implementer-suppression.md`. One rule binds both roles at any moment and reads
differently for each, so it sits here rather than on a step.

- ⛔ **FIX IT, DO NOT FILE IT** — `skills/ground-rules/SKILL.md` rule 13's fold, in the PR already open, since a
  filed item costs a read, a grounding pass, a worktree, an agent, a gate run and a merge to do what one edit
  would have done. Fix what you hit, never what you can find.
  **Where the two roles part is the DISPOSITION rather than the preference.** ⛔ **An IMPLEMENTER opens no
  GitHub issue, in any circumstance, for any finding — and neither does any reviewer it dispatches, which is
  why every one of those briefs says so** — since a filing from either seat spends that whole unit of work on
  what one surfaced message settles while the tree is still open. ⛔ **A DISPATCHER holds the disposition
  neither of them has**: filing is a verdict you return and then perform yourself, so the finding leaves the
  implementer's hands rather than landing back in them (`skills/execute/references/dispatcher.md`, *Judge what
  comes back*).
