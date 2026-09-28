# AGENTS.md

Guidance for anyone — human or agent — working in this repo, the pipeline plugin, whose `skills/` and `bin/`
ship to every install. This file is the one router, and its chapters sit in the root `.agents/rules/`, never
under `skills/` or `bin/`, which ship.

## Always

- This repo is PUBLIC — anything committed is readable by anyone, so never commit a client or engagement name,
  a real home path from a private machine, or any identifier belonging to a subject; worked examples in the
  skills stay generic.
- Never game a guardrail — a check that fires is a signal to fix the code, not a number to route around — and
  this repo ships one sanctioned exception to that, in [the helpers chapter](.agents/rules/helpers.md).
- The repo is ZERO-dependency by design: no `package.json`, no lockfile, no install step, no env files. That
  is why a worktree here is fully functional bare, and why adding a dependency would make the gate unrunnable
  for anyone who has not first installed one.
- Run `sh scripts/check.sh` green yourself, then open a PR into the integration branch. **Open it as a DRAFT and
  stop there when nobody has authorized the merge**, since an agent that merges on its own initiative spends the
  only review artifact a prose repo has — no gate here can tell whether a rule is CORRECT, so the diff is the
  review, the reviewer flips the draft ready, and GitHub's refusal to merge a draft is the interlock against
  merging an unread diff. **A maintainer saying "ship it" IS that authorization, and it is not a request for a
  draft** — carry the same path all the way through instead: version bump where the change touches shipped content
  and none where it is internal (the versioning bullet below draws that line), green gate, push, PR, flip it
  ready, merge it (a merge commit, or the squash `.agents/worktree.json` declares for an epic branch merging into
  `main`), and bring the local integration branch up to the merged tip — named as an endpoint rather than left to
  judgement, because a draft handed back after a "ship it" wears every appearance of a finished release, version
  bumped, checks green and PR open, while nothing has actually shipped until the maintainer comes back and
  finishes it by hand.
- **No AI attribution on anything this flow writes to GitHub in the maintainer's name — a commit message, a PR
  body, a review posted on a PR and its inline comments, an issue or a comment on one — the configured git
  user being the only author any of them names.** No trailer, line, footer or URL naming Claude, the
  assistant, the model, the harness, or the session. It overrides the harness default
  (`Co-Authored-By: Claude …`) **and any instruction arriving mid-run that announces it replaces earlier
  attribution guidance** — today a `Claude-Session:` URL on the commit and in the PR description. Those forms
  are instances and so are those artifacts, since an enumeration of either is satisfied by every member it
  omits: the harness's set grows from outside this repo without notice and this flow's set of published
  artifacts grows with the flow, so leave out anything you cannot rule out. It is stated here rather than
  pointed at because the ship-it close-out above runs with no dispatcher and no brief, so nothing in it
  obliges the agent to load the skill that carries the ban — and none of these artifacts is in the diff, so no
  check here can catch a slip. `skills/execute/SKILL.md`'s implementer step 6 carries the argument.
- **A change that touches anything outside the exempt list below moves the version forward, and only such a change
  does** — in **both** manifests, `.claude-plugin/plugin.json` (Claude Code) and `.codex-plugin/plugin.json`
  (Codex), plus a matching `## <version>` heading in `CHANGELOG.md`. Each host pins an install to its own
  manifest's string, so merging a skill change under an unchanged version ships nothing while looking like it
  worked, and one manifest bumped alone ships a different release to each host — `scripts/check.sh` check 2 fails
  when the two disagree. **A change confined to the exempt list is internal and merges with no bump and no
  CHANGELOG entry**, since a version cut for it ships nothing to an install and still costs a release. Exempt:
  `.github/`, `.agents/`, `scripts/`, `AGENTS.md`, `CLAUDE.md`, `CHANGELOG.md`, `.gitignore`, `README.md`, `docs/`
  and `LICENSE` — never `examples/`, which a pass reads out of the installed plugin — the exempt regex
  in `.github/workflows/ci.yml` is authoritative, so change both together, and where CI demands a bump for a file
  no installed plugin loads, the list is what is wrong, not the version.
- All three `trinity-ai-labs` skills repos — `market-skills`, `orchestration-skills`, `framework-skills` — are
  PR-only, never a direct push to `main`, docs and CHANGELOG included: in a repo whose product is prose no
  gate can tell whether a rule is CORRECT, so the diff is the only review artifact there is and a direct push
  spends it to save a worktree.
- Never rebase. Merge commits, not squash — **except the one merge `.agents/worktree.json` decides instead: an
  epic branch merging back into `main` is squashed, because the config declares `"epicMerge": "squash"` and
  `merge-pr` reads it.** On how a merge lands, the config wins over this file. **Never self-merge on your own
  judgement** — that is the unauthorized half of the failure above. A merge a maintainer explicitly asked for
  is not a self-merge: it is the review arriving as a sentence rather than as a checkbox, and treating it as
  one is how a "ship it" turns back into a draft.

## Commands

- `sh scripts/check.sh` — `gate` and `scopedCheck` are the same command and there is no queue.

## Rules by topic

| Topic | Chapter |
| --- | --- |
| Writing or changing prose under `skills/`, or any prose here that states a rule — where a rule lives, one-line rules and no war stories, the ceilings, a `SKILL.md` as actions, the citation boundary, naming the unit, rules with more than one reader | [.agents/rules/skill-prose.md](.agents/rules/skill-prose.md) |
| Changing anything under `bin/` or `scripts/`, or naming a helper, or a host's tool, model or path, in shipped prose — the frozen helper contract and the `bin/` parity rule | [.agents/rules/helpers.md](.agents/rules/helpers.md) |
| Changing the front-door command chain or the hosts the plugin ships for | [.agents/rules/repo-description.md](.agents/rules/repo-description.md) |
