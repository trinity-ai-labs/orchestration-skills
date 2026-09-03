# The gate queue, from the dispatcher's side

Reference for `skills/execute/SKILL.md` → *Dispatcher*. **Read it once your implementers have enqueued** — how the drain runs, and how you wait on your own tickets.

## Draining the gate queue
On each `ScheduleWakeup` tick (the *same* timer you already run for divergence), run `drain` (Trinity: `pnpm gate:drain`) from the main checkout. One pass re-delivers any verdict a previous pass decided but failed to post, then claims queued tickets and, for each, runs the full `gate` in that ticket's worktree **behind the slim machine-wide slot — one gate at a time** — then comments the verdict on the PR, a pass on green and the failing tail on red, and **leaves it draft either way**. It is a one-shot pass, so the tick re-invokes it.

**A wide fan-out stays safe because the slot, not the fan-out, decides how many gates run**, and implementers never gate at all.

- **Size the drain to the fan-out.** A lone slice enqueues once and hands back, and **that hand-back is a free notification** — drain on it, leaving the tick's drain to cover only an agent that dies between `enqueue` and handing back. Keep it on the tick either way, but never let it stand in for the divergence check: a tick read as "the drain timer" stops diffing worktrees.
- **A full drain can be long** — each ticket is one serialized gate — so bound a big queue with `drain --max N` per tick and background it. **Its completion is NOT a signal about your own tickets; never wait on it**: a pass loops until the *machine-wide* queue is empty, and your own ticket may be gated by another session's runner with no completion event of yours at all. The signal that IS yours is *Wait on your own tickets settling — one Monitor over the queue's ledger* below.
- **One drain per tick, never a second on top of a live one**, since a second buys nothing. Concurrent drains from *different* dispatchers are safe by construction, so don't coordinate, just drain. To read the queue's state rather than work it, that is `drain --status` (`skills/setup/references/gate-queue.md` invariant 9).
- **`--status` answers OWNERSHIP, never MOVEMENT — and on a runner scaffolded before invariant 9 it does not fail, it DRAINS.** It gives queue depth, who holds the slot, and which runner claimed which ticket; for **movement**, read the gate's child processes in that worktree — a clock cannot tell a gating runner from one blocked on a slot. An older runner passes the unrecognised flag straight through to a drain, so **read a `--status` whose output looks like a drain as evidence that it WAS one**; the portable instrument is `ls` over `<queue-root>/<project>/queue` and `.../processing`, which claims nothing.
- **Don't hand-run `gate` on top of a live drain** — a concurrent gate re-creates the saturation the slot prevents. Both gates a dispatcher used to launch itself are enqueued now (*Gate the integrated whole*). ⚠️ **Except on a runner predating the PR-less ticket, which refuses it** (*Gate the integrated whole* → *A runner scaffolded before the PR-less ticket REJECTS it*): the mid-arc gate is hand-run there, so run it when nothing is draining — established by **reading the queue directory**, never `--status`, itself a drain on that vintage.
- **A worktree whose ticket has not SETTLED is FROZEN — don't mutate it, don't remove it. The test is the ticket's EXISTENCE, in `queue/` as much as `processing/`, never whether a gate is observably running.** A claim is an atomic rename landing between your check and your agent's first edit, and **queued-and-unclaimed is the NORMAL state**, where a slice sits the moment its implementer hands back — so checking `processing/` is not checking anything. A tree changed mid-gate is judged against a HEAD no gate saw, under a SHA that may still match the PR's. Wait for the verdict comment, either direction, or the ticket's arrival in `done/` when there is no PR.
- **A red ticket is dispatcher feedback, not lost work.** The PR stays draft with the failure commented: read it and dispatch a fix agent into that same worktree, which re-pushes and re-enqueues — safe precisely because the ticket has resolved.
- **A PR with NO gate comment has not been gated — never treat it as red.** A pass comment is green, a failure comment is red, and no comment means the gate never reported — so **a bare PR licenses a question, never an inference**, with no failure to fix and no fix agent to dispatch. A queue that records its verdicts (invariant 7) reconciles undelivered ones before claiming anything, so **run the drain and look again**; still bare after that, re-enqueue.
- **Reconcile the local integration branch on every tick.** A dropped sync leaves it behind the remote and the next worktree forks off a stale HEAD. One anchored fast-forward, idempotent and near-instant: `git -C <main-checkout> fetch origin && git -C <main-checkout> pull --prune --ff-only`.
- **Sweep for outstanding parked work on the same tick — both places it can be**, the named ref first since it is authoritative:
  ```sh
  git for-each-ref --format='%(refname) %(contents:subject)' refs/pipeline-stash
  git stash list --format='%gd %gs' | grep -F 'pipeline-stash/'
  ```
  **Run either against the main checkout and it covers every live worktree at once**: both namespaces live in the repo's common gitdir, not in a tree (*Hard rules* has the park/restore commands and the marker format). While agents are live a hit is context for the divergence check. **When the fleet is quiet a hit is a defect to chase, not noise** — an implementer ended its turn with work its teardown will not carry.
- **Running an epic branch? Merge the integration branch into it on this same tick, in the epic's own worktree.** Nothing to do when there is none. When there is one:
  ```
  git -C <epic-worktree> fetch origin
  git -C <epic-worktree> merge origin/<integration-branch>
  git -C <epic-worktree> push origin <epic-branch>
  ( cd <epic-worktree> && <install> )
  ```
  Merge, never rebase — the mandatory mitigation for the epic branch's deferred, concentrated conflicts (*The epic branch*), cheap only while the slice authors are live to resolve them. **The push is what puts the merged base where the slice worktrees fetch it from.** Resolve a conflict, commit, and push before you walk away.

  **That fourth line is the project's own `install` (*Per-project config*), and it runs UNCONDITIONALLY** — a no-op where a project declares none. The epic worktree's dependencies fall behind the branch it holds, and the gate then reds on module resolution with no code defect. **Never condition it on the cadence merge's own diff**: a new package arrives through a *slice close-out*, whose fast-forward here sets `ORIG_HEAD` too. **The frozen rule above defers it**, since an install rewrites dependencies wholesale: a tree with an outstanding ticket installs next tick.

## Wait on your own tickets settling — one Monitor over the queue's ledger
The signal that belongs to you is **one persistent `Monitor`, armed once per wave, polling the gate queue's `done/` ledger and emitting one line per settlement belonging to that wave.** Arm it in the same breath as the dispatch, beside the divergence tick.

**The wave is the unit — not the ticket.** A fix agent re-pushes and **re-enqueues**, so anything keyed to the tickets live at arm time is stale the moment the wave moves. Key on the wave's **branches**, the set the divergence tick already carries, and every re-enqueue is covered for free.

**Scope on the fields the ticket is guaranteed to carry, and emit on SETTLED rather than on a verdict.** `skills/setup/references/gate-queue.md` pins the enqueue shape as `{ branch, worktreePath, prNumber, prUrl, mode }`, while the verdict facts invariant 7 requires are *facts the ticket carries*, spelled as each runner picks. Read `branch`, plus `prNumber` for the handle it prints, and nothing else: a watch that never fires is indistinguishable from a wave that has not settled.

**Watch the ledger, not the PR.** Invariant 7 has the runner record the verdict *before* it attempts to post, so a failed post leaves a settled ticket whose comment never landed. A watch on the comment sleeps through that; one on the ledger wakes on it, and waking is what runs the reconciling drain. *A PR with NO gate comment has not been gated* is the reading to apply once awake.

**The shape** — poll the ledger, remember what you reported, print one line per new arrival in the wave:

```sh
DONE="<queue-root>/<project>/done"        # the ledger; gate-queue.md has its layout
SEEN=$(mktemp)                            # one ticket path per line
find "$DONE" -name '*.json.*' > "$SEEN"   # prime: what is there is history
while true; do
  find "$DONE" -name '*.json.*' | while IFS= read -r t; do
    if grep -qxF "$t" "$SEEN"; then continue; fi
    b=$(jq -r '.branch' "$t" 2>/dev/null)   # unreadable now; retried next pass
    if [ -z "$b" ]; then continue; fi
    echo "$t" >> "$SEEN"
    case "$b" in
      feat/slice-a|feat/slice-b)            # this wave's branches, as enqueued
        echo "settled: $b  PR $(jq -r '.prNumber // "none"' "$t")" ;;
    esac
  done
  sleep 5
done
```

Two things in that shape fail at arm time in **zsh**, the shell a `Monitor` runs in on macOS, leaving a dead watch indistinguishable from a quiet queue. **The seen set is a FILE, never a shell string the loop appends to**: a `[` right after a parameter expansion opens an array subscript, so a string accumulator has the shell evaluate a ticket path as a math expression — and a file survives the pipe's subshell, where a variable's writes would not. **Enumerate with `find`, never a bare glob**: zsh's `nomatch` makes an unmatched `"$DONE"/*.json.*` fatal, killing a watch armed while `done/` is empty.

**Prime the seen set before the loop**: `done/` is a durable ledger, and an unprimed watch replays the whole archive as this wave's news. **Dedupe on the ticket file, never on the branch**: a branch that goes red, takes a fix and re-enqueues settles twice, and the second is what you want. (Read the JSON, not the filename — the claim suffix is a runner's PID.) And **read the ticket before you mark it seen**, since one caught mid-write is unreadable for a pass and marking it first retires it unreported.

**A few seconds is the right interval, and it is not the tick's question**: each poll is a directory listing plus a small JSON read, where the ~10-minute cadence in *Dispatch in the background, then monitor for divergence* is for reading **worktrees**. **Do not put this on that tick or give it that period.**

**Silence from this watch means nothing settled — never that the wave is healthy.** It fires on arrival in `done/` in both directions, since a red settles exactly as a green does. What it cannot see is a ticket that never settles: **a runner that dies mid-gate has its ticket reclaimed back to `queue/` (invariant 2) and re-gated later** — not a settlement, so no event. It is a wake-up, not a liveness check: the divergence tick notices a wave that stopped moving, and the queue directory says where a ticket is.

**⛔ This is a DISPATCHER instrument, and an implementer must never arm one**; it softens the Implementer section's *Never background a check and end your turn on it* by nothing. An implementer has a **durable handoff**, push → draft PR → enqueue, so the wait is unnecessary there and the ticket is by design somebody else's to watch; a dispatcher has no handoff to end on and holds the merge decision the settlement feeds.

**Tear it down at close-out with `TaskStop`.** The queue cannot tell you when your wave is over: a red settles too, and the wave ends when you merge, which nothing on disk can see. So the watch has no exit condition of its own and `persistent: true` is right. One left armed past its wave goes quiet, indistinguishable from a wave with nothing settling.
