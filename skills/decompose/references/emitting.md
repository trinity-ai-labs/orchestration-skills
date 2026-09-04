# Emitting the breakdown

Reference for `skills/decompose/SKILL.md`, action 4. In chat, or back onto the issue.

## In-chat path — output format

Lead with the parallelization plan (waves + critical path), then the horizon's slices at slice depth, then the remainder at shape depth. **The phase order in it comes from the issue; what you produce is the horizon's wave and its slices.** Use this shape (the arc here is mid-flight, Wave 0 already merged; on a first cycle the horizon is usually Wave 0 alone and every later wave is shape):

```
## Decomposition: <plan title>
Integration branch: <the project's declared integrationBranch>   ·   Epic branch: <epic-branch>, per the issue's verdict (or: none — one slice)
Horizon: Wave 1 — Slices 2, 3, 4

### Parallelization plan (the issue's phase order carried forward — dependency shape, not grounding)
- Wave 0 (landed): Slice 1
- Wave 1 — THE HORIZON, grounded below, dispatch now: Slices 2, 3, 4
- Wave 2 (after W1 — shape depth, grounded next cycle): Slice 5
- Wave 3 (last — the closing docs slice; consumes the falsification ledger, and derives from what the epic added): Slice 6
- Transient-red: Slices 2–4 run against the W0 schema change (gate read per execute's transient-red rules)
- Epic branch: yes, per the issue — the W0 schema change leaves the branch half-migrated until Slices 2-4 land; slices fork from and PR into it
- Conflicts to merge-resolve: Slice 3 & 4 both edit src/routes/registry.ts
- Critical path: Slice 1 → Slice 4 → Slice 5 → Slice 6

### Horizon — SLICE DEPTH (grounded against the tree as it stands right now)

#### Slice 2 — <title>
- Branch: `feat/<leaf>`   ·   Wave: 1   ·   Depends on: Slice 1 (merged)   ·   Model: top tier (subtle migration)
- Skill to invoke first: effect
- Goal: a retention window a user sets is still honoured after a restart
- Owns: sidecar/services/foo.ts   ·   docs/foo.md: repoint the moved path (coordinate fix, ships here); §"Retention" prose → ledger entry; the new eviction hook has no prose anywhere → ledger entry marked needs-new-prose
- Do NOT touch: any UI under app/ (Wave 2 owns those)
- Derives: reports/unimported.json — regenerated from the whole tree; report the delta, don't hand-edit
- Brief: <2–5 sentences>
- Verify: <acceptance + tests, incl. the reversal that proves the new test fails pre-change>

#### Slice 3 — <title>
...

### Beyond the horizon — SHAPE DEPTH (deliberately not grounded: no file:line, no owned files, no boundaries, no model tier)

#### Slice 5 — <title>
- Wave: 2   ·   Depends on: Slices 2–4
- Goal: let a user pick the retention window the W0 schema change made storable
- Area: the settings UI
- Why it comes after: it renders the field Slice 2 adds, so its shape is not decided until Slice 2 merges

#### Slice 6 — the epic's closing docs slice
- Wave: 3   ·   Depends on: Slices 2–5
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

For the issue path, decide **comment** vs **umbrella + sub-issues**, then write, then end your turn by telling the user what you wrote (umbrella and sub-issue numbers, or the comment link) and the same **Horizon ready to dispatch** handoff.

### Comment (the default)

When the work is small-to-medium — a handful of slices that are clearly one release effort and don't each need independent tracking — **post the whole breakdown as a single comment** on the issue, carrying both depths and their labels exactly as the in-chat format does. The loop reads the comment and dispatches the horizon from it.

### Umbrella + sub-issues (when warranted)

When the work is **large and multi-area** — many slices, several waves, slices deserving independent assignment, review and closure — **convert the issue into an umbrella**:

1. **Rewrite the issue body** into an umbrella overview: the goal, the parallelization plan (waves, conflict map, critical path), and a **tracked checklist** linking each sub-issue (`- [ ] #<sub>`), which GitHub renders as progress.
2. **Create one sub-issue per horizon slice** (or per tightly-coupled cluster) carrying that slice's full brief — scope, do-not-touch, depends-on, skill-to-invoke, model hint, verify. Beyond the horizon, a slice gets a checklist line or a placeholder sub-issue and no brief. Title each with its wave (e.g. `[W1] <title>`) so the dispatch order is visible at a glance.
3. **Link them as native sub-issues — always, never an optional extra.** The relationship is a plain REST endpoint that is simply there and *GitHub write mechanics* below carries the exact call, so there is no availability to condition on. **The native link is also what makes the reader-side check in `skills/decompose/references/grounding.md` cheap**: its first step is one `/parent` call, which 404s on every child of a markdown-only umbrella and forces an arriving agent onto the timeline fallback. And *always* keep the `- [ ] #<sub>` checklist too — it is the index reviewers scan, and the artifact that fallback matches on.
4. Label the umbrella (`epic`/`umbrella` if such a label exists; create nothing exotic).

Warrant the umbrella; don't reflexively shard a 3-slice issue into 3 issues. Rule of thumb: **umbrella when slices span multiple waves AND multiple areas AND each is a PR someone would want to track on its own.**

**A sub-issue may exist ahead of the horizon; a grounded brief may not.** File a beyond-horizon slice as a placeholder when you want it tracked — title, wave, goal, area, depends-on — marked on its face as *shape depth, not yet grounded*; it gets its owned files, boundaries, model tier and verify bar when the horizon reaches it. A sub-issue reads as a brief at whatever depth it was written, so an ungrounded one gets dispatched from as though finished, and a prematurely grounded one hands an implementer coordinates an intervening wave has moved. The umbrella **body** is the live remaining plan, rewritten every cycle rather than appended to — state, not history — while one comment per completed increment records what landed.

### GitHub write mechanics (important)

- **Use `gh api` (REST), not `gh issue create`/`gh issue edit` for the writes** — the high-level `gh issue` write commands go through GraphQL and hit rate limits in batches; the REST endpoints don't. Read with `gh issue view` is fine.
- **Write the body to a file and reference it with `-F` (not `-f`)** — `skills/glossary/mechanics/gh-api-file-body.md` says why, and why the wrong one exits 0. **Verify after**: refetch the body and confirm it's the markdown, not the literal path.
  - Comment: `gh api repos/{owner}/{repo}/issues/<N>/comments -F "body=@<file>"` (a temp file also spares you quoting hell with long markdown).
  - New sub-issue: `gh api repos/{owner}/{repo}/issues -f "title=…" -F "body=@<file>"`, then capture the returned number. The title stays `-f` — a genuine literal; only the `@file` value needs `-F`.
  - Edit umbrella body: `gh api -X PATCH repos/{owner}/{repo}/issues/<N> -F "body=@<file>"`.
- **Native sub-issue link:** `skills/glossary/mechanics/sub-issue-link.md` carries the call, and the two ways of getting its id wrong that both read as a missing endpoint.
- **Cross-reference, don't auto-close.** Each sub carries `Part of #<umbrella>` in its body and the umbrella carries that sub in its `- [ ] #<sub>` checklist — both directions, every time — the backlink is a rule rather than a formatting nicety, because only it is readable from the child's own body, which is all an agent arriving there directly has. The dispatcher then closes each sub by hand as its PR merges, never a `Closes` keyword (`skills/glossary/mechanics/closing-keyword.md`): the hand-close is correct under both readings, a no-op when GitHub already did it.
