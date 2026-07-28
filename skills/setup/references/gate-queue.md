# Scaffolding a durable gate queue

Reference for Step 3 of `/pipeline:setup`. This describes a design proven in production across two repos. Author it *into the project* — the project owns and evolves it from there.

The whole point is that **no state is held in a process**. Every transition is a filesystem operation the OS makes atomic, so concurrent runners are safe, a killed runner loses nothing, and a machine reboot leaves a queue you can still read.

## Three scripts

| Script | Role |
|---|---|
| `enqueue-gate.mjs` | An implementer drops a durable ticket after pushing and opening its draft PR |
| `gate-runner.mjs` | A one-shot drain pass: claim → gate → report → repeat until empty, then **exit** |
| `gate-slot.mjs` | A machine-wide mutex so only one heavy gate runs at a time |

Wire them up as `gate:enqueue`, `gate:drain`, and (wrapping the gate itself) `gate`.

## Queue layout

Under the user's home, per-user, shared across every worktree of the project:

```
~/.gate-queue/<project>/
  queue/       <timestamp>-<pid>.json       awaiting a runner
  processing/  <name>.json.<runnerPid>      claimed, gate in flight
  done/        <name>.json.<runnerPid>      resolved (green or red)
```

**The root is durable storage, not scratch.** A resolved ticket holds a verdict that exists nowhere else until its comment lands on the PR (invariant 7), so the ledger is the only copy of every result the report has not yet delivered. Put it anywhere the system is licensed to reap — a scratch or temp area swept on the OS's own schedule — and the one artifact the design added to survive a failed post is handed to a reaper that has no idea anyone is still waiting to read it. A home-relative root follows the same rule the rest of the flow applies to `$WORKTREE_HOME` — pick a per-user location the OS does not sweep — and nothing sweeps `~`. (`$WORKTREE_HOME` itself resolves to `~/.worktrees`, or `%LOCALAPPDATA%\wt` on Windows, where a home-relative worktree path would run past `MAX_PATH`; the queue holds small JSON files at a fixed depth, so that pressure does not apply to it and the root stays home-relative everywhere.)

**`done/` keeps the claim suffix.** Settling a ticket is a rename out of `processing/`, and the claim suffix rides along — a resolved ticket is `<name>.json.<runnerPid>`, not `<name>.json`. Stripping it buys nothing, since the ticket's own contents say which runner resolved it and what the verdict was; a reader who codes to a bare `<name>.json` writes a normalization step that has no job. Read the ledger by parsing the JSON, never by pattern-matching the filename.

**The slot is the one piece that may live in the OS temp dir.** It is a mutex, not data: it holds no verdict, its holder-PID is liveness-checked so an abandoned one gets stolen rather than trusted, and it is held only for the minutes a gate actually runs — far inside the untouched-for-days threshold a reaper works on. Losing it to a sweep costs the next runner one `mkdir`. Moving it under the home dir for symmetry with the queue is a change with no correctness content: the rule above is about where verdicts live, not where locks live.

Ticket: `{ branch, worktreePath, prNumber, prUrl, mode }`. `mode` selects which gate runs — `default` for the full suite, or a lighter one (e.g. `docs`) for a prose-only slice.

**`mode` is a property of the ticket, set at enqueue — never inferred from the branch name.** A rename must not silently change how a PR is gated.

## The invariants that make it correct

Get these wrong and the failure mode is a **green gate against code no gate ever saw** — which is exactly the signal the workflow reads as "safe to merge".

**1. Claim by atomic rename, never by read-then-write.** To claim, `renameSync` the lexically-lowest `queue/` ticket to `processing/<name>.<pid>`. Rename is atomic: with several runners racing, exactly one wins and the losers get `ENOENT` and move on. Checking "is it unclaimed?" and then writing a claim is a race with a window, no matter how small.

**2. Reclaim dead claimants on every pass, before claiming.** Scan `processing/`; for each, extract the claimant PID from the suffix and test `process.kill(pid, 0)` — if it throws, that runner is gone. Rename the ticket back to `queue/`. This is why a runner dying mid-gate never wedges the queue. It is safe because **the gate is idempotent**: re-running it costs time and nothing else.

**3. The slot is a directory, and stealing it is also a rename.** `mkdirSync` of a fixed path is atomic — the OS lets exactly one caller create it. Write the holder's PID inside. To steal an abandoned slot, `rename` it away and *then* remove it, rather than `rm` + `mkdir`: the rename gives one thief the win, where the plain form lets two callers both believe they hold it.

**4. Grace-period the PID file.** There is a window between `mkdir` and the PID write where the directory exists but has no owner. Only treat a PID-less slot as abandoned after a grace period, or a runner will steal a slot from a healthy peer that was one instruction slower.

**5. The slot must be re-entrant for descendants.** The `gate` script itself runs inside the slot, and it may invoke something that also tries to acquire. Pass the holder down (an env var) so a descendant recognizes its own ancestor's slot instead of deadlocking waiting for it.

**6. A drain pass exits.** It is not a daemon. It drains what is queued and returns, so an orchestrator re-invokes it each tick and can bound it with `--max <n>`. A long-lived daemon reintroduces the process state this design exists to avoid.

**7. The report is a state transition too — a ticket is not done until its verdict is delivered.** The other six invariants make the queue survive a process dying. This one makes it survive the network: record the verdict on the ticket *before* attempting to report it, so a failed post is a reconciliation problem rather than an amnesia one. See *Reporting* below for what that costs and what it buys.

**8. Prune a ticket only when its verdict was delivered.** Invariant 7 turns `done/` into a ledger, and an unbounded ledger grows for the life of the project — but the bound is delivery, not age. A ticket flagged for a human — retries exhausted, or the head moved off the gated SHA (see *Reporting*) — still holds a verdict nobody has seen, and age is not evidence anyone looked at it; on a flagged ticket age is usually evidence that nobody has. `reported` alone is not the test either, and getting this backwards is the trap: an abandoned ticket keeps `reported: false` forever, so a prune that trusts age plus "not reported" deletes exactly the records that were escalated — the ones whose on-disk copy is the only copy — while sparing the delivered ones whose contents are already sitting on the PR. The predicate is `delivered && older than the retention window`; anything flagged stays where it is until a human resolves it, however old it gets.

Put the prune on the reconcile walk. That pass already reads every ticket in `done/` before claiming, so it has the delivery flags in hand and the sweep costs nothing beyond the unlink. Take the clock as an injectable dependency — a retention rule whose only clock is the wall clock can be tested only by waiting, so in practice it ships untested.

## The worktree is frozen while its ticket is in flight

The runner gates *inside the ticket's worktree*. Anything that mutates that tree mid-gate makes the verdict meaningless — the gate tests a tree that no longer exists, then reports against whatever HEAD is current when it finishes.

This has actually happened: a fix agent committed at 22:34:37 and a ~2m20s gate posted `✓ passed` at 22:34:38 — green, against code no gate had ever seen. The comment is the evidence an orchestrator reads before merging, so a green comment describing a tree that no longer exists is enough to get untested code merged.

So: don't edit, and don't remove, a worktree whose ticket is in `queue/` or `processing/`. Wait for it to resolve. Document this where the project's contributors will see it.

## Reporting

**The verdict is a PR comment, in both directions, and the PR stays draft either way.** Green posts a passing comment; red posts the failing tail. The comment is the only channel — the queue never touches the PR's draft flag, in either direction.

That is what makes the reading rule a single sentence: **a PR is gated iff it carries a gate comment.** Draft-ness carries a different meaning entirely — nobody has approved this yet — and the only thing that clears it is the orchestrator marking the PR ready as it merges, having read the diff. Keeping the two on separate channels is the point: a machine can attest that the suite passed, and only a reader can attest that the change is right.

An implementer opening a PR without `--draft` is therefore a real bug with a mechanical consequence: the PR arrives already carrying the flag that means "reviewed and merging", without a gate comment and without anyone having read it.

A red ticket is orchestrator feedback, not lost work: the failure is visible on the PR, a fix agent re-pushes, and it re-enqueues.

**Write the verdict onto the ticket before the report is attempted, and only then move it to `done/`.** Everything above this section is about surviving process death and filesystem races; the report is the one step that depends on a machine you do not control. If the verdict lives only in the reporting call, a network blip destroys it — the gate ran, the result is gone, and recovering it means gating again.

It also collapses states that must stay distinguishable. "Ticket in `done/`, no comment" is produced by a failed post, by a gate that was skipped because its worktree had vanished, and by an exception mid-pass. Those need different responses, and a ticket that records only that it was processed can answer none of them. And because the comment is the sole channel, a green whose post failed is byte-for-byte indistinguishable *on GitHub* from a gate that never ran — the ticket is the only place that difference survives.

So the ticket carries the outcome, the exit code, the failing tail, the SHA that was gated, and whether the report was delivered. `done/` becomes a ledger rather than a record that something happened, and delivery becomes a retryable step instead of the only copy.

**The failing tail belongs to a red verdict — compute it and store it only there.** A green comment is a single line that quotes nothing, so a tail captured on green is output that no comment will ever contain and no reader will ever open. It is also the largest field on the ticket, and greens are the common case, so a tail persisted on green is what makes the ledger big — the retention rule above then spends its whole budget on bytes that were never readable. Watch the implementation trap: if the routine that computes the tail also cleans up the task-runner's own run-summary scratch files, that cleanup has to be lifted out so it still runs when the tail is skipped. Otherwise every passing gate leaves its summaries behind, and the space saved on tails is spent on scratch instead.

**Reconcile at the head of every pass.** Before claiming anything, scan `done/` for verdicts never delivered and post them. This costs nothing when there is nothing held, and it never re-runs a gate — the verdict is already known.

Two rules keep the retry honest:

- **Refuse a verdict whose PR has moved off the gated SHA.** The result describes a tree the PR no longer carries, and posting it is the same false-report as gating a mutated worktree — a green comment vouching for code no gate saw. Abandon it and say so; the slice needs re-enqueueing, not a stale verdict.
- **Cap the retries.** A PR deleted out from under the queue, or a permanently rejected token, must not make every future pass re-attempt a doomed post. After the cap, leave it flagged for a human.

A verdict counts as delivered exactly when its comment lands on the PR. There is no second channel to fall back on, which is why the ticket holds the verdict and the reconcile keeps retrying until the comment is there.

## What varies per project

Only these. Everything above is generic:

- the gate command, and any lighter mode's command
- the package manager used to invoke them
- how the verdict is posted as a comment on the PR (`gh` for GitHub; something else elsewhere)
- the queue directory's *name*, and the retention window the prune applies

The queue root's **placement** is not on that list. It is home-relative and durable everywhere, because the ledger holds verdicts that exist nowhere else — that is a correctness requirement, not a preference a project gets to express.

Keep the varying pieces read from `.agents/worktree.json` rather than hardcoded, so the project's own config stays the single source of truth.
