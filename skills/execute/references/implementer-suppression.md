# Implementer — the one sanctioned suppression

Reference for `skills/execute/SKILL.md` → *Implementer*, step 3. **Read it before you add a suppression.**

**The one carve-out — a DOCUMENTED suppression, for when the flagged construct IS the intended behavior.** It
is never "the check is wrong": the rule points at the feature, so no cause exists to fix. (This plugin's
`bin/setup-worktree.ps1` suppresses `PSAvoidUsingInvokeExpression` on one function: a project's `install`
value is a command *line* needing **interpretation**.) A suppression you ADD is permitted then, ONLY when
**all four** hold:

- **Narrowest scope the tool allows** — one function, or one line. Never file-wide, and never a settings-file
  exclusion switching the rule off repo-wide.
- **A written justification in place, through the tool's own mechanism** where one exists —
  `SuppressMessageAttribute`'s `Justification=`, a `// eslint-disable-next-line <rule> -- <reason>` — never a
  bare disable comment. This is the load-bearing one: it puts a claim in front of a reviewer who can reject
  it.
- **The justification says why the flagged construct is correct HERE** — what the code does and why that is
  wanted. "Noisy rule" and "false positive" are the claim this carve-out refuses: if you cannot write the
  sentence without arguing with the check, you have the fix you were avoiding.
- **You call it out in your hand-back comment** — file, rule, one-line reason. One nobody flagged is one nobody
  reviewed, and gets bounced.

**An EXISTING suppression is not yours to re-justify, and not yours to delete for compliance** — the four
conditions test one you ADD. If you think one fails, say so and leave it.
