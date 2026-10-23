# Implementer — queue mode

Reference for `skills/execute/SKILL.md` → *Implementer*, step 2. **Read it when the project declares `enqueue`
and `drain`.**

**Who runs `gate` is your gate mode's to say, and the project's `enqueue`/`drain` decide it** — never
self-granted, never inferred — **and a declared `fullGate` is never yours in either mode**, its runs being
your dispatcher's:

- **Queue mode — the project declares `enqueue` and `drain`: you do NOT run `gate`, and the ban is on
  the WORK, not the command name.** Never run the full suite or any whole-package test run
  **by any invocation** — not `gate`, not `turbo run test`, not a raw `vitest` sweep, not a package `test`
  script — and **backgrounding it is still running it**. Never wait on a gate either: the ticket is your
  dispatcher's, raised after it reads your diff.

- **Queue mode — both declared:** the implementer runs `preflight`, pushes, opens a **draft** PR and hands
  back; **the dispatcher enqueues that ticket once it has read the diff**, and a runner drains it, gates it
  and comments the verdict.
