# Implementer — queue and remote modes

Reference for `skills/execute/SKILL.md` → *Implementer*, step 2. **Read it when the project declares `enqueue`
and `drain`, or when your brief puts you in remote mode.**

**Who runs `gate`, and where, is your gate mode's to say** — the project's `enqueue`/`drain` and its
`gatePreference` beside whether its CI runs `gate` on pull requests decide it, never self-granted, never inferred — **and
a declared `fullGate` is never yours in any mode**, its runs being your dispatcher's:

- **In queue mode (the project declares `enqueue` and `drain`) and in remote mode (the PR's own CI is its
  gate) you do NOT run `gate`, and the ban is on the WORK, not the command name.** Never run the full suite or any
  whole-package test run **by any invocation** — not `gate`, not `turbo run test`, not a raw `vitest` sweep,
  not a package `test` script — and **backgrounding it is still running it**. Never wait on a gate either: in
  queue mode the ticket is your dispatcher's, raised after it reads your diff, and in remote mode the CI your
  push triggers is your dispatcher's to read.
- **Your half is the same in both:** run `preflight` on the head you push, where no hook covering that head
  does, push, open a **draft** PR and hand back. **You post no gate comment** — the runner comments a queued
  verdict, and in remote mode the PR's CI checks at its head ARE the verdict — and you start no CI run by
  hand: no re-run, no `gh workflow run`, no empty commit to retrigger one.
