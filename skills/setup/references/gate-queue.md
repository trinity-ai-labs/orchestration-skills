# Scaffolding a durable gate queue

Reference for Step 3 of `/pipeline:setup`. Author it *into the project* — the project owns and evolves it from there.

**No state is held in a process.** Every transition is a filesystem operation the OS makes atomic, so concurrent runners are safe, a killed runner loses nothing, and a reboot leaves a readable queue.

## Three scripts

| Script | Role |
|---|---|
| `enqueue-gate.mjs` | Drops a durable ticket for one gate — an implementer's, after it opens its draft PR, or a dispatcher's on a tree with no PR |
| `gate-runner.mjs` | A one-shot drain pass: claim → gate → report → repeat until empty, then **exit** — plus a read-only `--status` mode (invariant 9) |
| `gate-slot.mjs` | A machine-wide mutex so only one heavy gate runs at a time |

Wire them up as `gate:enqueue`, `gate:drain`, and (wrapping the gate) `gate`.

## Queue layout

Per-user, under the user's home, shared across the project's worktrees:

```
~/.gate-queue/<project>/
  queue/       <timestamp>-<pid>.json       awaiting a runner
  processing/  <name>.json.<runnerPid>      claimed, gate in flight
  done/        <name>.json.<runnerPid>      resolved (green or red)
```

**The root is durable storage, not scratch.** Until its comment lands (invariant 7) a resolved ticket holds a verdict that exists nowhere else, so a temp root hands the ledger to the OS's own reaper. Home-relative everywhere: nothing sweeps `~`. The slot is the exception — a lock, not data — and may sit in the temp dir.

**`done/` keeps the claim suffix.** Settling is a rename out of `processing/` and the suffix rides along: a resolved ticket is `<name>.json.<runnerPid>`. Read the ledger by parsing the JSON, never by pattern-matching the filename.

### The ticket

`{ branch, worktreePath, mode }`, plus `prNumber` and `prUrl` **when the tree being gated has a PR**. `mode` selects the gate — `default` for the full suite, or a lighter one (e.g. `docs`) for a prose-only slice.

**`mode` is a property of the ticket, set at enqueue — never inferred from the branch name**, or a rename silently changes how a PR is gated.

**`prNumber`/`prUrl` are OPTIONAL, because a tree worth gating does not always have a PR.** The case is the dispatcher's mid-arc integration gate (`skills/execute/references/landing.md`), on a merged tree that exists *between* slice merges, before the epic → integration PR does. Such a ticket settles like any other and skips only the report, so its ledger entry is the verdict's only copy. Required fields leave that gate hand-run and unrecorded.

**Record the absence at enqueue as a fact ON the ticket — undeliverable by construction, never inferred from two missing fields.** Invariant 8's prune and *Reporting* both have to distinguish a ticket nobody will ever report from one whose report failed. It is not a fourth state: modelled as *delivery pending, forever* it fills the flagged pile with escalations nobody can act on.

**A runner scaffolded before this change must REJECT a PR-less enqueue and exit non-zero naming the missing fields.** This design is scaffolded into a project and evolves there, so a field becoming optional does not reach runners already deployed; accepting one silently spends a full serialized gate and files the result as a delivery failure only a human can clear. The fallback is then a hand-run gate, sanctioned at `skills/execute/references/landing.md`'s *A runner scaffolded before the PR-less ticket REJECTS it*.

**A consumer scopes on `branch` and treats `prNumber` as absent** — the PR fields are not on every ticket, so keying on one silently drops PR-less tickets. `skills/execute/references/dispatching.md`'s *Wait on your own tickets settling — one Monitor over the queue's ledger* is that consumer, and needs `branch` as its fallback handle.

## The invariants that make it correct

Get these wrong and the failure mode is a **green gate against code no gate ever saw**.

**1. Claim by atomic rename, never by read-then-write.** `renameSync` the lexically-lowest `queue/` ticket to `processing/<name>.<pid>`. Rename is atomic: several runners race, exactly one wins, and the losers get `ENOENT`.

**2. Reclaim dead claimants on every pass, before claiming.** Scan `processing/`, read each claimant PID from the suffix, and test `process.kill(pid, 0)`; if it throws, rename the ticket back to `queue/`. A runner dying mid-gate therefore never wedges the queue, and re-gating is safe because **the gate is idempotent**.

**3. The slot is a directory, and stealing it is also a rename.** `mkdirSync` of a fixed path is atomic: exactly one caller creates it. Write the holder's PID inside. To steal an abandoned slot, `rename` it away and *then* remove it — the rename gives one thief the win, where `rm` + `mkdir` lets two callers both hold it.

**4. Grace-period the PID file.** Between `mkdir` and the PID write the slot exists with no owner, so treat a PID-less slot as abandoned only after a grace period — otherwise a runner steals a healthy peer's slot.

**5. The slot must be re-entrant for descendants.** The `gate` script runs inside the slot and may invoke something that also acquires, so pass the holder down (an env var) — a descendant must recognize its ancestor's slot rather than deadlock on it.

**6. A drain pass exits.** It drains what is queued and returns, so a dispatcher re-invokes it each tick and bounds it with `--max <n>`; a daemon would reintroduce the process state this design avoids.

**7. The report is a state transition too — a ticket is not done until its verdict is delivered.** The other invariants survive a process dying; this one survives the network — so record the verdict on the ticket *before* attempting to report it, so a failed post is a reconciliation problem, not an amnesia one (*Reporting*).

It also makes `done/` the one place a **waiter** can watch: the verdict is on the ticket before the rename into it, so a dispatcher watches the ledger, not the PR, where the verdict arrives later and on a failed post not at all (`skills/execute/references/dispatching.md`'s *Wait on your own tickets settling*).

**8. Prune a ticket only when its verdict was delivered.** The ledger would otherwise grow unboundedly, but the bound is delivery, not age: a ticket flagged for a human — retries exhausted, or the head moved off the gated SHA (*Reporting*) — holds a verdict nobody has seen. `reported` alone inverts it, since an abandoned ticket keeps `reported: false` forever, so age plus "not reported" deletes exactly the escalated records whose on-disk copy is the only one. The predicate is `delivered && older than the retention window`; anything flagged stays until a human resolves it, so a just-settled ticket is still there when a waiter wakes.

**An undeliverable ticket counts as DELIVERED the moment it settles**, and prunes on the retention window like any other: `delivered` asks whether the verdict reached the reader it was owed to, and a PR-less ticket was owed no report. Take that from the enqueue-time flag, never from the absence of a comment — read as flagged, every mid-arc integration gate becomes a permanent ledger entry.

Put the prune on the reconcile walk, which already reads every ticket in `done/`, and take the clock as an injectable dependency — a wall-clock-only rule can be tested only by waiting.

**9. Contention is announced.** Claiming (invariant 1) and acquiring the slot (invariant 3) are separate steps, so a second runner claims immediately and *then* blocks — and from outside, blocking and gating look identical, both exiting at a time unrelated to when they started. On a failed acquire, print the holder before waiting: who holds it, what that holder is gating, and since when. Say there that **more runners never add throughput** — a pass loops until the queue is empty (invariant 6), so concurrency changes which process works, not when work finishes.

**Add a read-only `--status` mode** — queue depth, which tickets are claimed and by which runner, who holds the slot — that claims nothing and gates nothing. Both read state already on disk: the PID is in the slot, `processing/`'s claim suffix maps it to that runner's ticket (invariant 2's extraction), and the slot's timestamp (invariant 4's grace period reads the same one) says since when. The mode is the load-bearing half: the announcement only ever reaches the waiting runner's own stderr.

**A runner that does not implement `--status` must reject the unrecognised flag and exit without claiming anything — never fall through to a drain**, or the mode's absence is silent in projects scaffolded before it.

**A runner blocked on a held slot WAITS.** The queue is machine-wide, so the holder is routinely another session's runner; refusing would also decide off a PID liveness check inside the window invariant 4 documents as wrong. A wrong refusal drops a drain, where a wrong wait costs a sleeping process.

## The worktree is frozen from enqueue until the ticket settles

The runner gates *inside the ticket's worktree*, so mutating that tree mid-gate makes the verdict meaningless — the gate tests a tree that no longer exists, and its comment is what a dispatcher reads before merging. Don't edit, and don't remove, a worktree whose ticket is in `queue/` or `processing/`; document this where the project's contributors will see it.

## Reporting

**The verdict is a PR comment, in both directions, and the PR stays draft either way.** Green posts a passing comment; red posts the failing tail. Where the ticket has a PR that comment is the only channel, and the queue never touches the draft flag — which is what makes **a PR gated iff it carries a gate comment**; the ready flag is the dispatcher's, set as it merges.

**Write the verdict onto the ticket before the report is attempted, and only then move it to `done/`.** The report is the one step depending on a machine you do not control. It also keeps apart states that must stay distinguishable: "in `done/`, no comment" is produced by a failed post, by a gate skipped because its worktree had vanished, by an exception mid-pass, and — benignly — by a PR-less ticket. Only the enqueue-time undeliverable flag tells the last from the first; on GitHub they look identical.

So the ticket carries the outcome, the exit code, the failing tail, the SHA that was gated, and whether the report was delivered — which is what makes `done/` a ledger and delivery a retryable step.

**The failing tail belongs to a red verdict — compute it and store it only there.** Greens are the common case and the tail is the largest field, so tails on green spend invariant 8's retention budget on bytes no comment quotes. Implementation trap: where the routine computing the tail also cleans up the task-runner's run-summary scratch files, lift that out so it still runs when the tail is skipped.

**Reconcile at the head of every pass.** Before claiming, scan `done/` for undelivered verdicts and post them; this never re-runs a gate. Two rules keep the retry honest:

- **Refuse a verdict whose PR has moved off the gated SHA** — it describes a tree the PR no longer carries, so posting it is the same false report as gating a mutated worktree. The slice needs re-enqueueing.
- **Cap the retries**, or a deleted PR or rejected token makes every future pass re-attempt a doomed post; after the cap, leave it flagged for a human.

A verdict counts as delivered when its comment lands on the PR — or, on a PR-less ticket, the moment it settles: no post is owed.

## What varies per project

Only these. Everything above is generic:

- the gate command, and any lighter mode's command
- the package manager used to invoke them
- how the verdict is posted as a comment on the PR (`gh` for GitHub; something else elsewhere)
- the queue directory's *name*, and the retention window the prune applies

The queue root's **placement** is not on that list: home-relative and durable everywhere, for the reason under *Queue layout*.

Read the varying pieces from `.agents/worktree.json` rather than hardcoding them.
