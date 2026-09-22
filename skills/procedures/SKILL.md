---
name: procedures
description: >-
  The steps this pipeline OWNS, stated once: the worktree helpers' command-line contract, the meaning of
  every key a project declares, and the host tool that spawns, times, watches and stops an agent. Open
  an entry whenever you are about to run one of those — before you call a helper, before you read a
  project's config, before you spawn or time or stop an agent — and whenever a pass cites one at the step
  you have reached. Every pass may cite these entries and they cite nothing back. An entry carries a
  PROCEDURE whose steps are identical at every seat — the command and its flags, the order they run in,
  the meaning of the values it reads, the host tool that runs it, and what to verify once it has. What a
  seat DOES about the result is a rule, and it is restated where its reader acts.
argument-hint: "[none — open the entry your task names, not the set]"
---

# Procedures

**This is an index, not a pass.** Nothing here tells anyone what to build or when. It is the steps this
pipeline owns and every seat runs identically, written down once so that N hand-maintained copies of one
cannot drift apart with nothing able to make them agree. **What this pipeline does NOT own — how git,
GitHub and the `gh` CLI behave, true whether or not this pipeline exists — is the concept map's
`mechanics/` instead**, and that prose goes wrong by going stale where this goes wrong by drifting.

## The entries

| Entry | What it carries |
|---|---|
| `skills/procedures/worktree-helper.md` | `setup-worktree` and its siblings: the arguments, the recovery form, what a run creates, the two lines it prints, and what it refuses rather than reporting a false success |
| `skills/procedures/config-keys.md` | Every key in `<repo>/.agents/worktree.json`, and the two a workspace declares in `.agents/workspace.json` — what each one means, and what its absence means |
| `skills/procedures/host-tools.md` | The host tool behind each capability this flow needs, the tier-to-model table, and the two questions to answer before calling a helper |

## The admission test, and what it keeps out

**An entry here carries a PROCEDURE whose STEPS are identical at every seat** — the command and its
flags, the order they run in, the meaning of the values it reads, the host tool that runs it, and what
to verify once it has. A frozen command surface is the clearest case: the flags do not change according
to who typed them.

⛔ **An ordinary RULE is not admitted, however inconvenient restating it is.** The test is one question
asked of each sentence: **would two seats do anything different with this?** If yes it is a rule — it
belongs where its reader acts, and two of them written at one address means one of those readers is
reading past a rule that is not theirs. Moving such a rule in here would not remove a duplicate; it
would hand a rule with one reader a second one. So an entry states what a command does and what a key
means, and never who runs it, when, or what to conclude from the answer.

⛔ **No entry NAMES A SEAT, and the gate fails one that does.** A seat's name appearing in an entry is
the mechanical tell that the sentence around it is a stance rather than a mechanism, so it is also the
test above with a grep behind it. **Second person is right here and is not the tell** — a procedure
legitimately says *run this, then read that*, and an entry that could not address whoever is running
the command would be no procedure at all.

**These entries are cited and never cite back.** An entry may point at another entry here, at
`skills/glossary/SKILL.md`'s definitions and at `skills/ground-rules/SKILL.md`. It may not reach into a
pass: a shared home that reads a pass's policy has adopted that pass's stance, and the gate fails it in
that direction exactly as it fails any other cross-skill citation.
