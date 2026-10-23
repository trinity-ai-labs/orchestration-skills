# Implementer — the docs your change made stale

Reference for `skills/execute/SKILL.md` → *Implementer*, step 4. **Read it before you touch a doc.** On a slice
of an epic, `skills/execute/references/implementer-epic.md` inverts the last step.

**Docs are part of the change, not a follow-up.** Write down the user-visible behavior your change adds,
removes or alters, then bring the docs describing *that behavior* in line.
**Search by the behavior, not by the vocabulary you introduced**: user-facing prose carries none of your new
identifiers, so grepping your terms comes back empty and reads as "nothing to update".
**Where the project declares `docsPaths`, that is where to look and what makes each tree stale**
(`skills/procedures/config-keys.md`), so *not affected* becomes a judgement against a stated condition rather
than a sentence you compose. Docs go in their own commit, each with a one-line verdict in your hand-back comment.

**A convention your slice adds or changes is agent guidance, and the guidance test decides where it goes**
(`skills/procedures/agent-guidance-layout.md`, *Placing a line*) — a router's *Always*, or the one chapter for
its topic, created with its router row where neither exists yet. **Adding to a monolith moves that topic out
into its chapter in this same PR**, so the file gets more router-shaped with every slice that touches it and
never longer; **a `CLAUDE.md` your slice touches that holds content is reduced to the pointer line**, its
content placed by the same test. The rest of a monolith is not yours to split — fix what you hit, never what
you can find.

**A comment claiming what OTHER code does is re-asserted before you reword it.** Every defect the checks here
catch is a disagreement between two artifacts a tool can compare; this one is prose against behaviour, and
nothing scans it. So open that code and confirm the claim first. A claim that turns out false is a finding, surfaced as
`skills/ground-rules/SKILL.md` rule 13 asks and fixed only where which side is right is established — never
something to quietly correct into accurate prose, which documents a bug as the design and
removes the last thing that would have led anyone to look.
