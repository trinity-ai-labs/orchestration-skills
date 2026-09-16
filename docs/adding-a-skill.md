## Adding a skill

Drop `skills/<slug>/SKILL.md` in and it loads on both hosts — no manifest edit needed either way: Claude Code
discovers `skills/` on its own, and the Codex manifest points at the whole tree. The repo's gate enforces the
two things that make a skill actually load: frontmatter carrying `name`, `description`, and `argument-hint`;
and `name` matching the directory, since Claude Code registers the slash-command from the directory name.
(`argument-hint` is not a Codex key, but it lives in frontmatter rather than a manifest, so it is simply
ignored there.)

Run it before you push — it is the same command CI runs, so there is no second copy to drift:

```bash
sh scripts/check.sh
```

**The gate names every check as it runs it, and that output is the list.** What follows describes the ones
worth understanding before you push and does not claim to be all of them; the authoritative enumeration lives
in `scripts/check.sh`'s own numbered header, beside the code it describes, where an author adding a check has
it in view. A copy anywhere else goes stale the day a check is added and reads exactly as authoritative as a
current one — which this repo has now watched happen to itself: when a ninth check landed, both enumerations
sitting *beside* the code moved with it and both *remote* ones, a CI step name and this section, silently did
not.

Alongside shellcheck, the manifest, and the skill frontmatter, it also holds `bin/` to the parity rule — on
surface facts, which is the whole of what a checker can compare here: that every `<name>.sh` has a
`<name>.ps1` sibling and vice versa, that the two agree on their usage line and on the contract environment
variables they read, that a helper resolving paths under `WORKTREE_HOME` reads `.agents/workspace.json` at all
— the one thing asserted of each sibling *alone*, because comparing the pair is structurally blind to an
omission they share — and that every `.ps1` is printable ASCII terminated by LF, since Windows PowerShell 5.1
decodes a BOM-less file as the system ANSI codepage, so one stray em-dash corrupts it and the parse error
lands nowhere near the character that caused it.

**Most semantics are out of that check's reach**, so two ports can pass every surface comparison and still
behave differently on the same input — until 3.40.0 a failed install exited with the install tool's own status
in bash and `1` in PowerShell, and nothing in the check could see it. The exception is `scripts/port-cases/`:
one table of inputs asked of **both** implementations and compared, so a predicate written twice cannot
diverge quietly, and a renamed predicate fails there rather than skipping — a silent rename is how the pair
would stop being compared while the check kept reporting ok. What actually holds the pair together is the
frozen contract in [AGENTS.md](../AGENTS.md) and the review of every change to it; the check catches the drift
that shows on the surface.

The gate also checks that every `skills/` path to a `.md` file cited in a tracked `.md` still resolves in the
tree — a `SKILL.md` and a reference doc alike, since the two are the same coordinate with the same failure
mode and the check follows the corpus rather than enumerating one filename. A skill points at its own
references constantly — a spine names the file carrying each action's *how* — so a rename or a deletion inside
a skill leaves a citation pointing at nothing, and a dead path reads exactly as authoritative as a live one,
which is how one wrong reference sat in a dispatch instruction across seven releases and reached two live
briefs. Pointing at *another* skill is a different matter and a different check: check 12 fails the gate on
it, because a skill that has to reach into another one to explain itself is not finished — state what your
reader needs where they act. Path citations only, deliberately: a reference by prose phrase is left to review,
because italics carry emphasis everywhere in this corpus and not just around section names, so a pattern over
them would be mostly false positives and a noisy check is one the next author routes around. And
path-*shaped*: the pattern is anchored on `skills/`, so a bare filename is out of reach on purpose — these
docs write `README.md` and `AGENTS.md` in running prose constantly, naming no directory and usually not even
this repo, so matching those would red the gate on every other project's README mentioned in passing.

**A markdown link is the other half of that check, and it is resolved differently on purpose.** A bare
`skills/…` path in prose resolves from the repository ROOT, because that is where a reader told to open it
stands; a `](…)` link target resolves from the directory of the **citing file**, because that is where a
renderer resolves it. Testing a link from the root cannot tell a correct `../skills/<slug>/SKILL.md` from a
`skills/<slug>/SKILL.md` written inside `docs/` — both exist from the root, only one renders — which is how a
`](examples/worktree.json)` moved into `docs/` came to point at nothing while the gate stayed green, and why
any cross-directory relative link that is not a `skills/*.md` path was invisible before. External URLs and
`#fragments` are deliberately out of scope: nothing here can reach the first, and checking the second means
reimplementing every renderer's slug rules.

**A tracker coordinate is the sibling coordinate class, and it is answered rather than validated.** A bare
`#123` has nothing in the tree to resolve against — a number is a valid string in every repository — so where
a path is checked by *does it resolve*, this one is not checked at all: check 9 fails the gate on **any**
`#<number>` in a tracked `skills/` doc, code spans and fenced blocks aside. A tracker coordinate in a skill is
an instruction to go read an issue mid-task, and the reference, with the reasoning behind it, belongs in the
PR that makes the change. Scoped to `skills/` because that is what ships: read from someone else's checkout a
bare number resolves against **their** tracker, where it is some unrelated issue, while `AGENTS.md`,
`README.md`, these `docs/` pages and `CHANGELOG.md` are only ever read as this repository's own and a number
in them is already right.

**A skill cites its own references and three shared homes, and nothing else.** Each home is admitted on a
property naming what has no per-seat form to restate, which is the same argument about what N hand-maintained
copies cannot keep honest: `skills/glossary/` holds a **DEFINITION** — what a thing is, identical for every
pass and owned by none; `skills/ground-rules/SKILL.md` holds a **RULE whose STATEMENT is identical at every
seat**; and `skills/procedures/` holds a **PROCEDURE whose STEPS are identical at every seat** — a command and
its flags, the order they run in, the meaning of the values it reads, the host tool that runs it, and what to
verify once it has. An ordinary rule is none of the three and does not become citable because restating it is
inconvenient: where two seats would do different things with it, it stays written at both. Everything else is
restated where its reader acts, and check 12 fails it — including any of those three reaching back into a
pass, since the ban still holds in the direction that grew the web. **Every pass opens with a line having its
reader read `skills/ground-rules/SKILL.md` before acting on anything in the file**, since a rule every seat is
held to reaches only the seats that read it — and nothing checks that the line is there, so a new pass carries
it by hand.

**Check 12 compares the cited target as a WHOLE PATH SEGMENT by equality, and that is load-bearing rather than
incidental.** A prefix match, a glob or a `case` pattern would admit `skills/ground/` — a pass — as a citable
target for free, because its directory name is a prefix of `skills/ground-rules/`, and the check could then no
longer say that a pass may not be cited. Nothing goes red on that mistake; the corpus simply becomes citable.
A fourth home arrives the same way or not at all.

**Check 17 is what keeps the newest home from becoming a dumping ground, and it is check 14's sibling.** It
holds every `.md` under `skills/procedures/` that git tracks **or that is untracked and not ignored** — the
spine included — to three properties. That second half is load-bearing rather than incidental, for the reason
check 10 gives for the same flag: a home that is NEW is exactly what the check exists to weigh, and
tracked-only it would be invisible until `git add`, which is a false green on the very change that creates it.
The properties: no entry NAMES A SEAT, since a seat's name appearing in one is the mechanical tell that the
prose around it is what a single stance does, and moving such a rule into a shared home hands a rule with one
reader a second one rather than removing a duplicate; every entry has a row in the spine, because check 8
catches a row pointing at a missing entry and the reverse is silent; and every entry is cited by at least one
file outside the home, because an extracted procedure nothing points at leaves no dangling path for check 8 to
find. **The seat set is the whole pipeline's** — dispatcher, implementer, reviewer, searcher and runner —
rather than the two obvious names, which would have missed a `runner` and a `searcher` sitting green inside
this home's own first draft; and because an enumerated ban is satisfied by every form it omits, that list is
the floor and a new entry is adjudicated against the property. **Second person is deliberately NOT banned
there**, which is the one place this guard differs from the glossary's: that one bans `you`/`your` because a
definition describes a thing, while a procedure legitimately says *run this, then verify that*, so importing
the ban would fail every procedure ever written.

**Check 12's cost is paid back by one more check, and that one leaves markers in the prose you are editing.**
Because no skill may cite another, every copy of the slice-field enumeration is internally consistent and
structurally unable to point at its siblings, so two copies disagreeing is out of reach of every other check
here; the gate answers that by deriving the canonical field set from the glossary entry that declares itself
canonical and holding each enumerating passage to it. It locates those passages by `gate-anchor:enum-N:begin`
/ `:end` sentinel comments written beside them — `git grep gate-anchor` lists every one — and
**a sentinel that goes missing FAILS the gate rather than skipping the passage it delimited**, since a passage
quietly dropping out of the comparison while the check keeps printing `ok` is the entire failure the pair is
there to prevent. Leave them where they sit: they carry no meaning of their own and deliberately name no unit
this corpus renames, which is why they are sentinels rather than phrases lifted out of the surrounding prose —
anchors cut from the prose had to be reworded by every rename that touched it, and the cheap way out of that
is leaving a stale label in shipped text to keep the gate green.

**The war-story ban is the one prose rule stated as a PROPERTY, and its check says so.** The rule is
[AGENTS.md](../AGENTS.md)'s: name the failure a rule prevents in a clause that shares its sentence with the
action, never in a sentence or a paragraph of its own. Check 11 matches a handful of phrasings that perform
that promotion, and it is a **backstop** rather than the rule — an enumerated ban is satisfied by every form
it omits, so a green says those phrasings are absent and never that the property holds, and adding phrasings
is not how it improves, since the next war story is written in the next shape. Its scope is every tracked
`*.md` **except** `CHANGELOG.md`, because the property governs wherever this repo states or applies a rule: a
`skills/`-only scope left the file that STATES the rule outside the reach of the check enforcing it, and
`docs/` is where prose extracted out of `skills/` now lands. `CHANGELOG.md` is exempt by the rule's own logic
— the ban does not delete an incident, it relocates it to the change that fixed it, and a release entry is one
of the two places it points to.

Those checks need nothing installed, so they always run.

The one step that needs an optional tool is PSScriptAnalyzer, which needs `pwsh`. When `pwsh` or the module is
missing it prints **`SKIP`**, never `ok` — a check that could not run must not read as green — and CI's
`check` job (`ubuntu-latest`) is where it actually lints, since that runner ships both `pwsh` and
PSScriptAnalyzer preinstalled. `pwsh` is deliberately *not* on the gate's required-tool list: this repo is
zero-dependency by design, and a gate that needs an install is a gate nobody can run before pushing.

Before publishing, also run the authoritative validator — the same one the community-marketplace review runs:

```bash
claude plugin validate . --strict
```
