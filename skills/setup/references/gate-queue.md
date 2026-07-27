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

Under the OS temp dir, per-user, shared across every worktree of the project:

```
<tmp>/<project>-gate-queue/
  queue/       <timestamp>-<pid>.json      awaiting a runner
  processing/  <name>.json.<runnerPid>     claimed, gate in flight
  done/        <name>.json                 resolved (green or red)
```

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

## The worktree is frozen while its ticket is in flight

The runner gates *inside the ticket's worktree*. Anything that mutates that tree mid-gate makes the verdict meaningless — the gate tests a tree that no longer exists, then reports against whatever HEAD is current when it finishes.

This has actually happened: a fix agent committed at 22:34:37 and a ~2m20s gate posted `✓ passed` at 22:34:38, flipping the PR **ready** — green, against code no gate had ever seen. Since `draft=false` is the signal the workflow reads as "gated", trusting it would have merged untested code.

So: don't edit, and don't remove, a worktree whose ticket is in `queue/` or `processing/`. Wait for it to resolve. Document this where the project's contributors will see it.

## Reporting

On green, flip the PR ready. On red, comment the failing tail and **leave it draft**. Draft-ness is the durable signal that a PR has not passed — which is why an implementer opening a PR without `--draft` is a real bug: it produces a non-draft PR that was never gated.

A red ticket is orchestrator feedback, not lost work: the PR stays draft with the failure visible, a fix agent re-pushes, and it re-enqueues.

**Write the verdict onto the ticket before the report is attempted, and only then move it to `done/`.** Everything above this section is about surviving process death and filesystem races; the report is the one step that depends on a machine you do not control. If the verdict lives only in the reporting call, a network blip destroys it — the gate ran, the result is gone, and recovering it means gating again.

It also collapses states that must stay distinguishable. "Ticket in `done/`, no comment" is produced by a failed post, by a gate that was skipped because its worktree had vanished, and by an exception mid-pass. Those need different responses, and a ticket that records only that it was processed can answer none of them. Worse, the green case is silent in both directions: `pr ready` fails too, so a PR that passed sits in draft looking exactly like one that never ran.

So the ticket carries the outcome, the exit code, the failing tail, the SHA that was gated, and whether the report was delivered. `done/` becomes a ledger rather than a record that something happened, and delivery becomes a retryable step instead of the only copy.

**Reconcile at the head of every pass.** Before claiming anything, scan `done/` for verdicts never delivered and post them. This costs nothing when there is nothing held, and it never re-runs a gate — the verdict is already known.

Two rules keep the retry honest:

- **Refuse a verdict whose PR has moved off the gated SHA.** The result describes a tree the PR no longer carries, and posting it is the same false-report as gating a mutated worktree — a green flipping a PR ready on code no gate saw. Abandon it and say so; the slice needs re-enqueueing, not a stale verdict.
- **Cap the retries.** A PR deleted out from under the queue, or a permanently rejected token, must not make every future pass re-attempt a doomed post. After the cap, leave it flagged for a human.

A green counts as delivered only when the ready-flip **and** the comment both succeed. A PR left in draft reads as ungated whatever the comment says.

## What varies per project

Only these. Everything above is generic:

- the gate command, and any lighter mode's command
- the package manager used to invoke them
- how the PR is flipped (`gh` for GitHub; something else elsewhere)
- the queue directory name

Keep them read from `.agents/worktree.json` rather than hardcoded, so the project's own config stays the single source of truth.
