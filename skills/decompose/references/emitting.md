# Emitting the breakdown

Reference for `skills/decompose/SKILL.md`, action 4. In chat, or back onto the issue.

## In-chat path — output format

Lead with the parallelization plan (waves + critical path), then the horizon's slices at slice depth, then the remainder at shape depth. **The phase order in it comes from the issue; what you produce is which ready issues make up the horizon's wave, and each one's grounding.** **Every horizon entry is one ready sub-issue and carries its number**, since the unit that lands and the unit the tracker holds are the same object and an entry standing for no tracked item is one nothing can tick. Use this shape (the arc here is mid-flight, Wave 0 already merged; on a first cycle the horizon is usually Wave 0 alone and every later wave is shape):

```
## Decomposition: <plan title>
Integration branch: <the project's declared integrationBranch>   ·   Epic branch: <epic-branch>, per the issue's verdict (or: none — one slice)
Horizon: Wave 1 — the ready sub-issues B, C, D, one slice each

### Parallelization plan (the issue's phase order carried forward — dependency shape, not grounding)
- Wave 0 (landed): sub-issue A
- Wave 1 — THE HORIZON, grounded below, dispatch now: sub-issues B, C, D
- Wave 2 (after W1 — shape depth, grounded next cycle): leaf E
- Wave 3 (last — the closing docs slice; consumes the falsification ledger, and derives from what the epic added): leaf F
- Transient-red: B–D run against the W0 schema change (gate read per execute's transient-red rules)
- Epic branch: yes, per the issue — the W0 schema change leaves the branch half-migrated until B–D land; slices fork from and PR into it
- Conflicts to merge-resolve: C & D both add a route to src/routes/registry.ts — neither owns it
- Docs axis: epic, so the shared overview page is F's to write and B–D record ledger entries against it (off an epic this line names the one slice that owns it)
- Critical path: A → D → E → F

### Horizon — SLICE DEPTH (grounded against the tree as it stands right now)

#### Sub-issue B — <title>
- This slice IS that issue, ground whole; it is never cut into two
- Branch: `feat/<leaf>`   ·   Wave: 1   ·   Depends on: sub-issue A (merged)   ·   Model: top tier (subtle migration)
- Skill to invoke first: effect
- Goal: a retention window a user sets is still honoured after a restart
- Owns: sidecar/services/foo.ts   ·   docs/foo.md: repoint the moved path (coordinate fix, ships here); §"Retention" prose → ledger entry; the new eviction hook has no prose anywhere → ledger entry marked needs-new-prose
- Do NOT touch: any UI under app/ (Wave 2 owns those)
- Derives: reports/unimported.json — regenerated from the whole tree; report the delta, don't hand-edit
- Brief: <2–5 sentences>
- Verify: <acceptance + tests, incl. the reversal that proves the new test fails pre-change>

#### Sub-issue C — <title>
...

### Beyond the horizon — SHAPE DEPTH (deliberately not grounded: no file:line, no owned files, no boundaries, no model tier)

#### Leaf E — <title>   (a checklist line in the umbrella body; it takes its number when the horizon reaches it)
- Wave: 2   ·   Depends on: B–D
- Goal: let a user pick the retention window the W0 schema change made storable
- Area: the settings UI
- Why it comes after: it renders the field B adds, so its shape is not decided until B merges

#### Leaf F — the epic's closing docs slice
- Wave: 3   ·   Depends on: B–E
- Goal: answer every falsification-ledger entry — corrections and needs-new-prose alike — reconciled against what the epic added, written against the final tree
- Area: the user-facing doc set
- Why it comes after: each entry describes a state not final until the last slice merges
```

**An epic branch's prefix carries no mechanical meaning; its leaf does** (`skills/glossary/mechanics/branch-leaf.md`), so that slot takes the real branch name. **It should not read like a slice branch**, or it is indistinguishable in a PR list from the `feat/<leaf>` slices merging into it. **And its leaf must be one no slice branch you name reuses** — the likeliest collider is the closing docs slice. Check it every cycle against the slices you are grounding now.

End with the handoff line, and **which one depends on the path the issue is on, not on who invoked you** — verbatim intent:

> **Horizon ready to dispatch.** *(one slice)* `/pipeline:execute` takes it from here: a worktree, an implementer, the gate, a draft PR, review, merge. There is no remainder to reconcile and no loop to enter.
>
> **Horizon ready to dispatch.** *(an epic)* `/pipeline:orchestrate` takes it from here: it dispatches this increment through `/pipeline:execute` — a worktree per slice, implementers, gate, PR review, merge — then reconciles the remainder against the tree the increment actually produced and moves the horizon.

## Writing it back to GitHub

For the issue path, write the grounding back where its reader finds it, then end your turn by telling the user what you wrote (the comment links, and any sub-issue numbers a horizon leaf took) and the same **Horizon ready to dispatch** handoff.

### Comment — the default, and the whole shape a breakdown takes

**Post each ready issue's grounding as a comment on that issue**, carrying both depths and their labels exactly as the in-chat format does; on a single-issue plan that one comment is the whole breakdown. The loop reads the comments and dispatches the horizon from them.

### Writing onto a live umbrella — number the leaves, never add a level

⛔ **You never convert an issue into an umbrella and never cut one issue into several** (`skills/glossary/vocabulary/umbrella.md`): **an issue grounding shows cannot be one PR is reported back onto it as a plan defect**, the answer being another child authored at that altitude rather than a split you perform, however pragmatic cutting it here looks. **And you never merge several leaves into one**: N ready leaves grounding shows are one PR's worth of one change are reported back the same way, the answer being one leaf re-authored at that altitude, since a slice spanning two tracked items leaves a checklist line that cannot tick exactly as a cut leaf does.

What you do write onto a live umbrella is the cycle's grounding:

1. **Rewrite the umbrella body** into the live overview: the goal, the parallelization plan (waves, conflict map, docs axis, critical path), **the remainder at shape depth** — each beyond-horizon item's goal, area, depends-on and why-it-comes-after, exactly as the in-chat *Beyond the horizon* section above carries them — and a **tracked checklist**, which GitHub renders as progress. **A checklist line carries a number only where a sub-issue exists for it**: `- [ ] #<sub>` at the horizon, and a plain `- [ ] <title>` for a beyond-horizon item, which indexes that item's entry in the remainder rather than replacing it.
2. **Give each horizon leaf its number** — a checklist line the plan already carries takes its sub-issue as the horizon reaches it, carrying that slice's full brief: scope, do-not-touch, depends-on, skill-to-invoke, model hint, verify. **That is one number per leaf and never a number per piece of a leaf**, the leaf being the slice. **Beyond the horizon the default is a checklist line in the umbrella body and no brief**, and a placeholder sub-issue — which gets no brief either — is the exception on one test: the item needs what a line cannot carry, an assignee of its own or a close of its own. Title each with its wave (e.g. `[W1] <title>`) so the dispatch order is visible at a glance.
3. **Link them as native sub-issues — always, never an optional extra.** The relationship is a plain REST endpoint that is simply there and *GitHub write mechanics* below carries the exact call, so there is no availability to condition on. **The native link is also what makes the reader-side check in `skills/decompose/references/grounding.md` cheap**: its first step is one `/parent` call, which 404s on every child of a markdown-only umbrella and forces an arriving agent onto the timeline fallback. And *always* keep the `- [ ] #<sub>` checklist too — it is the index reviewers scan, and the artifact that fallback matches on.
4. Label the umbrella (`epic`/`umbrella` if such a label exists; create nothing exotic).

**Whether the work is one issue or an umbrella of children is not this pass's call at all** — it was answered where the issues were authored, so a three-slice reading of a single issue here is the report above rather than three issues you cut.

**A sub-issue may exist ahead of the horizon; a grounded brief may not.** File a beyond-horizon item as a placeholder sub-issue only in the exceptional case step 2 states, and write it at shape depth — title, wave, goal, area, depends-on, marked on its face as *shape depth, not yet grounded* — since a sub-issue reads as a brief at whatever depth it was written, so an ungrounded one gets dispatched from as though finished and a prematurely grounded one hands an implementer coordinates an intervening wave has moved; it gets its owned files, boundaries, model tier and verify bar when the horizon reaches it. **A beyond-horizon slice is ALREADY TRACKED, so *tracked* is not the test and a number bought for tracking alone buys nothing**: the umbrella **body** (`skills/glossary/vocabulary/umbrella.md`) is the live remaining plan, rewritten every cycle rather than appended to — state, not history — and re-read every cycle by whatever is running the arc, while one comment per completed increment records what landed. **The rule is *not yet*, never *never*, and the moment the number arrives is the one stated above** — one sub-issue per horizon slice carrying that slice's full brief, which an item folded back into the plan takes like any other once the horizon reaches it.

### GitHub write mechanics (important)

- **Use `gh api` (REST), not `gh issue create`/`gh issue edit` for the writes** — the high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't. Read with `gh issue view` is fine.
- ⛔ **No AI attribution on anything this flow writes to GitHub in the maintainer's name** — the issue body, its title, and every comment on it name the configured git user alone: no trailer, line, footer or URL naming Claude, the assistant, the model, the harness, or the session. The named forms and the named artifacts are both instances rather than the extent, since an enumeration of either is satisfied by every member it omits, so leave out anything you cannot rule out.
- **Write the body to a file and reference it with `-F` (not `-f`)** — `skills/glossary/mechanics/gh-api-file-body.md` says why, and why the wrong one exits 0. **Verify after**: refetch the body and confirm it's the markdown, not the literal path.
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"` (a temp file also spares you quoting hell with long markdown).
  - New sub-issue: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>"`, then capture the returned number. The title stays `-f` — a genuine literal; only the `@file` value needs `-F`.
  - Edit umbrella body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`.
- **Native sub-issue link:** `skills/glossary/mechanics/sub-issue-link.md` carries the call, and the two ways of getting its id wrong that both read as a missing endpoint.
- **Cross-reference, don't auto-close.** Each sub carries `Part of #<umbrella>` in its body and the umbrella carries that sub in its `- [ ] #<sub>` checklist — both directions, every time — the backlink is a rule rather than a formatting nicety, because only it is readable from the child's own body, which is all an agent arriving there directly has. The dispatcher then closes each sub by hand as its PR merges, never a `Closes` keyword (`skills/glossary/mechanics/closing-keyword.md`): the hand-close is correct under both readings, a no-op when GitHub already did it.
