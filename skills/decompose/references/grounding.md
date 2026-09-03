# Grounding the horizon

Reference for `skills/decompose/SKILL.md`, action 1. A breakdown built from the plan text alone names files that don't exist and misses the real coupling. **Ground every horizon slice in the actual code first — and stop at the horizon**: a coordinate grounded now and executed three waves later names a path an earlier wave moved, with nothing erroring, so the implementer builds against the nearest plausible thing instead.

## Read the plan, then read UP from it

- **Read the source plan fully — the whole arc, then ground only its front.** For a GH issue: `gh issue view <N> --comments` — body **and** discussion, since constraints often live in comments; for an in-chat plan, or an arc handed to you by the loop, re-read what was laid out.
- **Re-derive the citations the plan carries — a SECTION citation most of all, because nothing further down the flow will.** A stale path fails to resolve; a stale section citation **resolves perfectly**, to a real section not carrying the argument attributed to it. **Open the section and read what it argues**, never search for the word the claim turns on — that word is usually there in an unrelated sense, so the search reads as confirmation. Send one that does not hold to action 2.
- **Read UP before you read DEEP — on the GitHub path, establish whether the issue is a sub-issue of an umbrella and read the parent FIRST**, since a child issue reads as complete and gives no sign it was written inside a frame. Two steps, in order:
  1. **`gh api repos/{owner}/{repo}/issues/<N>/parent --jq .number`** — definitive when the umbrella used native sub-issue links. With no native parent it returns **HTTP 404 `No parent issue found`** and `gh` **exits non-zero**: the endpoint answering, not failing, so branch on the exit status rather than chaining with `&&`.
  2. **When it 404s, fall back to the timeline**, which finds a markdown-only umbrella step 1 structurally cannot see:
     ```
     gh api repos/{owner}/{repo}/issues/<N>/timeline --paginate \
       --jq '.[]|select(.event=="cross-referenced")|.source.issue.number' | sort -un
     ```
     **This returns a CANDIDATE SET, not the parent** — every issue and PR that ever cross-referenced this one, the umbrella in no way distinguished from the arc's sibling slices and PRs. Disambiguate rather than take the lowest or the first: **the umbrella is the candidate whose own body carries this issue in its tracked checklist**:
     ```
     gh issue view <candidate> --json body -q .body \
       | grep -qE "^[[:space:]]*-[[:space:]]*\[[ xX]\][[:space:]]*#<N>([^0-9]|$)"
     ```
     Use `([^0-9]|$)` rather than `\b`, for portability across BSD and GNU grep. That checklist line is the artifact `skills/decompose/references/emitting.md`'s *Umbrella + sub-issues* mandates writing at its first step.

  Then read the parent with `gh issue view <umbrella> --comments` **before** you ground the child: it carries the wave map, the epic-branch answer, the seam list and the constraints the child was written inside, none of it restated in the child.

## Anchor each horizon slice in the tree

- **Research the codebase to anchor each horizon slice** — **fresh** `Explore` agents in parallel, never forks, one per subsystem the **horizon** touches, for the real files, modules, patterns to copy and consumers a change ripples into; invoking this skill is what authorizes them, and it authorizes these read-only agents and nothing else. Don't research subsystems only a later wave touches. **This establishes only that a coordinate EXISTS in the tree, never that it is REACHABLE from where the slice needing it will live** — the closing check in `skills/decompose/references/slicing.md` tests the second.
- **Find what each horizon slice will falsify — docs first, then every other artifact that asserts something about the code — and put it in that slice's scope.**
  - **The docs come first, and you derive them from the behavior, never from a keyword grep**: user-facing prose carries none of your new identifiers by construction, so the empty grep reads as *nothing affected*. Ask what a reader of each doc believes and which beliefs this slice makes false, then **read** the candidates.
  - **Then the greppable complement: does this slice delete or move a file the docs cite by path?** A path names something the tree either has or does not, so `grep -rF '<path>' <doc-set>` answers it exactly.
  - **Then ask the same of everything else that asserts something about the code** — a guard-proof table row, a `package.json` script entry, a pre-commit chain entry, a test fixture, a CI job, a ledger entry — and **find every declaration, not the first**, since an enforcement chain is routinely declared in several places.
  - **And ask what PRODUCES the artifact, not only what reads it**: *asserts something about the code* describes a consumer, and a producer omitting a new field emits a valid artifact, so it never errors.
  - **And ask what the slice ADDS that no doc describes at all** — *what does this falsify?* asks about a difference, so a new gate, flag or endpoint on an undescribed surface returns *nothing*. Name the doc that **should** describe it, scoped as needing **new prose**.
  - **Scoping a doc OUT is a claim from the plan, not from the diff** — record an explicit not-affected-because so the implementer can overturn it. Beyond the horizon, record only that an item has docs to falsify and in which area.
  - **In an epic this bullet does not move — only the edit does.** Still name the docs slice by slice; the deliverable becomes an entry in the epic's **falsification ledger**, both kinds, consumed by a closing docs slice against the final tree — except the coordinate case, which ships with the slice that moved the path.
- **Then ask which existing assertions depend on the value produced at the site you are changing — and answer by reading that site's CALLERS, never by grepping**: the assertion that breaks names a shape that survives on the type and merely stops being populated there. Put the test files that come back in the slice's `Owns` with their disposition — *the assertion moves here*, not *build here*.
- **Then sweep for the artifacts a REGENERATOR owns, so `Derives` (`skills/decompose/references/slicing.md`) is filled from the repo rather than from memory.** Half is mechanical: a `package.json` script writing a file **into the tree** rather than a build directory; a checker with a `--write`/`--update` mode; a gate or pre-commit chain entry that regenerates something; a generated file `.gitignore` does **not** list. The other half is the falsification question pointed at checkers, which catches the generated file whose regenerator is a test.
- **Read `AGENTS.md` and the per-project config** (`<repo>/.agents/worktree.json`, the same config `/pipeline:execute` reads) for the **framework skills** per area, the **gate**, the **compat policy** and the style conventions, and bake them into each slice. **No config is a hard stop, not a note**: the helper cuts a *bare* worktree instead of failing — no env symlinks, no dependencies — so the implementer dispatched into it fails its checks for reasons shaped exactly like code defects. Say the project is not set up, and get it onboarded before you ground anything.
- **Grounding an arc inside the repository that SHIPS these skills? Your own rules are a coordinate too.** You were loaded from the installed plugin, not the tree you are grounding against, and the rules an arc has just shipped are the ones most likely missing from your copy. Read a governing rule out of that repo's own `skills/` before grounding by it; where one looks wrong, `diff` the copies and trust the tree. Say which copy you read your rules from, and **put the same sentence into the briefs you emit**: *the worktree's copy of these skills is authoritative — read the rule there, and where one looks wrong or missing, `diff` the installed copy against the worktree's and trust the worktree.*
- **Discover the integration branch**, don't assume it: `git branch --list 'release/*'` / the current branch. Slices target the active integration branch, never `main`, never a hardcoded version — or the **epic branch** if the wave map in `skills/decompose/references/slicing.md` warrants one, which is cut from it.

## An enumeration is a claim

`skills/decompose/SKILL.md` carries the rule; these are the mechanics that produce a count you can stand behind. Nothing downstream recovers a short one: a truncated enumeration names real files in the right format and reconciles with every other field, so the closing check in `skills/decompose/references/slicing.md` reads it as sound — that check compares a brief's fields against **each other**, and this one is wrong against the **tree**. A truncated list, a suppressed error and a search that never ran are byte-identical to a clean empty result. So:

- **Count first and print untruncated** — `… | wc -l`, then the set itself with nothing between it and you — and **write the number beside the list in the slice**. Never `head`/`tail` the set.
- **Say what the number counts, because `wc -l` on its own does not**: fed a `grep` it counts **matching lines**, fed `grep -o` **occurrences**, fed a file list **members**. The number in the slice counts **the thing being enumerated** — consumers, call sites, declarations, files — with the sweep's own count beside it, named with its command; otherwise an implementer who re-measures cannot tell a short list from a different instrument.
- **A count offered as evidence names its baseline too**: two counts of one quantity against two trees are not comparable however fixed the unit.
- **Read the exit status and the stderr before you write *no consumers*.** A suppressed error is indistinguishable from a clean no-match, which is why `2>/dev/null` is *banned* on a search; so is a search that never ran — a rejected regex, a glob the shell ate, a printer truncating each line before the match.
- **Exclude the query from its own answer** wherever the command can see itself, as a process match on its own command line does.

**`Owns` (`skills/decompose/references/slicing.md`) carries this failure inverted** — a brief that kept a query's cardinality and threw away its members (*40 references, find them, they are yours*); the list and the count ship together.
