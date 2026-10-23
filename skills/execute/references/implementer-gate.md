# Implementer — the in-line gate

Reference for `skills/execute/SKILL.md` → *Implementer*, step 8. **Read it before you run `gate` in in-line
mode.**

**Who runs `gate` is your gate mode's to say, and the project's `enqueue`/`drain` decide it** — never
self-granted, never inferred — **and a declared `fullGate` is never yours in either mode**, its runs being
your dispatcher's:

- **In-line mode — the project declares neither, or your brief or the dispatching user EXPLICITLY puts this slice
  there (override mode):** once your draft PR is open and any review pass your brief asked for has reported and
  had its findings committed, run `gate` a single time — backgrounded with your turn ended on it where your host
  re-invokes you on its exit, in the foreground otherwise (*Never end your turn on a check that cannot wake you*
  below) — and comment the result on it. That one run is the only gate run you make, and every other stays
  banned, **the ban being on the WORK, not the command name**: never the full suite or any whole-package test run
  **by any invocation** — not `gate` again, not `turbo run test`, not a raw `vitest` sweep, not a package `test`
  script — and **backgrounding it is still running it**. **Capture that gate's own exit status, never a
  pipeline's** — `gate > gate.log 2>&1; echo "EXIT=$?"`, then read the log — and quote the `EXIT=` line, this
  flow's only evidence a gate ran. **A red is checked at your fork point before you comment it**: with your work
  committed and pushed, check `$FP` out, re-run only the failing tests by name through the targeted run, check
  your branch back out, and split the verdict's failures into those that pass there or are absent there — yours —
  and those that fail there too.

**In either gate mode you never enqueue, never mark your own PR ready, on any result** (that flag is the dispatcher's
signature that it read your diff), **and never merge it**.

**Lead that comment with the revision you gated — the SHA `gate` just ran against, named first — and label
every other SHA it carries, the fork point included, rather than leaving a reader to guess which one you mean.**
*Review BEFORE you drain, never after* compares the SHA the comment names against the PR's head; an unlabeled
fork point in that slot is a commit the head will never match, and reads exactly like a verdict that predates
the last push when nothing did. A `Gated-At: <sha>` trailer says the same thing in a form a machine could
parse — worth adopting, never required, and nothing in this flow reads one back.

**Post that comment with `gh-post.sh comment pr <n> --key gate-verdict/<leaf> --body-file <file>`** — a
re-gate edits the one verdict in place (`skills/procedures/github-writes.md`), so no stale verdict is left to
tidy. **Remove no comment from that PR**: your dispatcher's **fence grant** and posted review, and **your own
review pass's review and dimension comments**, sit there under the same account, and a grant gone leaves your
diff editing outside the brief's fence with nothing on the PR explaining why, while a panel review gone reads
to your dispatcher exactly like a slice that ran no pass at all.

**Never end your turn on a check that cannot wake you — a rule about checks and commands, and not about the
sub-agents you spawned**, which `skills/execute/references/implementer-review.md` covers. This is keyed to the
HANDOFF, not the run, so it reaches the checks you ARE allowed to run: the stall does not care which one it was,
only that the turn ended and the handoff never happened. **Where `skills/procedures/host-tools.md` says a
backgrounded command's exit re-invokes you, run a long check with the shell tool's background flag and end your
turn; its completion resumes you.** **Otherwise run it in the foreground, raising the call's timeout to its
limit, and end your turn only at the hand-back** — there a turn you end on a running command IS your hand-back,
with no verdict in it; past the limit, host-tools' detach-and-poll fallback applies only where your host keeps a
detached command alive.