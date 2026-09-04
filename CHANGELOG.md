# Changelog

Versions are the `version` field in `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`, which must agree — the repo's gate fails when they do not. Because that field is set, an installed plugin only picks up changes when it **changes** — pushing to `main` alone ships nothing. CI enforces the bump.

## 4.9.1

- **Three places still said `merge-pr` reads `epicMerge`, full stop.** It reads `branchingModel` as well as of 4.9.0, and — a first for this helper — reads it from a workspace's `.agents/workspace.json` when there is one, which is the only key it looks for outside the repo's own config. A reader onboarding a project or reasoning about the config-read window would have had the wrong list. Documentation only; no behaviour changes.

## 4.10.0

- **A project declares where its work lands, and nothing infers it.** `integrationBranch` — a literal branch name — replaces `branchingModel`, which shipped one release earlier and is **retired**. That key existed to *resolve* the integration branch from a model (`trunk` / `release` / `gitflow`); a declared literal resolves it exactly, so the models, the `release/*` listing and every read of the repository's default branch go with it. **This flow ends at the integration branch** — `main` where work lands there, the live release branch, or `develop` — and what happens to that branch afterwards was never in scope, so nothing here models it.
- **The default branch is a DIFFERENT fact and neither can be read off the other.** A project whose work lands on its default branch and one whose default branch is a separate long-lived branch are both ordinary. Worse, a local `origin/HEAD` records the default at clone time and does not track the remote, so the inference fails without erroring.
- **Correcting 4.9.0: `epicMerge=squash` was NOT "unreachable everywhere".** That claim came from reading a stale local `origin/HEAD` as the default branch. A release-branch project whose default branch is a separate long-lived branch always satisfied the old test. The option was unreachable only where work lands on the repository's default branch — which is what the issue said before the "correction".
- **The squash boundary is one comparison: is the head the integration branch?** An epic buffer sits above it and is never it. That is the *definition* of a buffer rather than a guard, and a declared branch this repository does not have reads as none declared, so a typo cannot make the comparison a tautology.
- **A retired key is announced where it was declared.** `merge-pr` notes on stderr that `branchingModel` is no longer read and names its replacement, checking the workspace manifest as well as the repo's own config — the risk being guarded is silence, and a version number does not break silence.
- **A workspace's `integrationBranch` is now DECLARED and belongs under review.** It named the branch every member's work lands on while being documented as regenerated per machine from whatever branch each checkout happened to be on, which gives two engineers different merges for the same repos.
- **Undeclared, every pass behaves exactly as before** — `merge-pr` keeps the base-versus-default test — which is what keeps this minor.
- **Both ports were compared rather than trusted.** The parity check reads surface only, so it cannot see two implementations disagreeing on a predicate; one shared fixture of 9 rows was fed to bash and PowerShell, and they agree on every row.

## 4.9.1

- **Three places still said `merge-pr` reads `epicMerge`, full stop.** It reads `branchingModel` as well as of 4.9.0, and — a first for this helper — reads it from a workspace's `.agents/workspace.json` when there is one, which is the only key it looks for outside the repo's own config. A reader onboarding a project or reasoning about the config-read window would have had the wrong list. Documentation only; no behaviour changes.

## 4.10.0

- **A project declares where its work lands, and nothing infers it.** `integrationBranch` — a literal branch name — replaces `branchingModel`, which shipped one release earlier and is **retired**. That key existed to *resolve* the integration branch from a model (`trunk` / `release` / `gitflow`); a declared literal resolves it exactly, so the models, the `release/*` listing, the shipped-versus-ahead predicate and every read of the repository's default branch all go with it. A config still declaring the retired key gets a note on stderr from `merge-pr` naming its replacement, because the risk being guarded is silence and a version number does not break silence.
- **The default branch is a DIFFERENT fact and neither can be read off the other.** A project whose work lands on its default branch and one whose default branch is a release branch it never works on are both ordinary. Worse, a local `origin/HEAD` records the default at clone time and does not track the remote, so the inference fails without erroring.
- **Correcting 4.9.0: `epicMerge=squash` was NOT "unreachable everywhere".** That claim came from reading a stale local `origin/HEAD` as the default branch. A release-branch project whose default branch is a separate long-lived branch always satisfied the old test, and the squash worked there. The option was unreachable only where work lands on the repository's default branch — which is what the issue said before the "correction".
- **`setup-worktree` gains the half `branchingModel` never had: what an arc forks FROM.** It refuses a `<base>` that does not CONTAIN the declared integration branch — one ancestry test, no new argument, no branch-name matching. An epic branch cut from the integration branch contains it; the integration branch contains itself; a branch the project has moved past does not, and neither does a commit behind the tip. `setup-workspace` delegates per member, so a workspace gets the check with each member's own config.
- **The squash boundary is now one comparison: is the head the integration branch?** An epic buffer sits above it and is never it. `release/0.4.0 -> dev` is still refused in a release project — because the head IS the integration branch, not because a proxy happened to agree.
- **Undeclared, every pass behaves exactly as before**, which is what keeps this minor: `setup-worktree` checks nothing and `merge-pr` keeps the base-versus-default test.
- **Both ports were compared rather than trusted.** The parity check reads surface only, so it cannot see two ports disagreeing on a predicate. One fixture each for the squash boundary (9 rows) and the base check (5 rows), fed to bash and PowerShell; they agree on every row.

## 4.9.0

- **No project declared its branching model, so every rule that needed it guessed — with a different proxy each time.** `merge-pr` asked whether the PR's base was the repository's default branch; `decompose`'s grounding ran `git branch --list 'release/*'`; the same file told slices to target the integration branch "never `main`". Three guesses at one unstated fact, each wrong somewhere, and the third was flatly false for the repository that ships it. `branchingModel` — `"trunk"`, `"release"` or `"gitflow"` — is now declared in `.agents/worktree.json`, or once in `.agents/workspace.json` for members that share one branch and one model.
- **BEHAVIOUR CHANGE: a project that declares `branchingModel` and `epicMerge: "squash"` now gets a squash where it previously got a merge commit.** The old test — the PR's base is not the repository's default branch — is a statement about the project's *model* standing in for a question about the branch's *level*, and the two coincide only where the integration branch is not also the default branch. That is the uncommon case: a release-branch project routinely makes `release/x.y.z` its default branch too, so **the option was unreachable in every project available to check, not only trunk-based ones**. It had been documented as a deliberately-accepted cost for an unusual shape; it was the universal outcome. **Declaring nothing changes nothing** — undeclared, both the old inference and the old squash test stand byte-for-byte, which is what makes this a minor release.
- **The squash now tests the head branch's LEVEL, and refuses a `release/*` or `hotfix/*` head under every model.** Under `gitflow` those are release branches by definition; under the other two the refusal is a belt against a project that has declared the wrong model, where a `release/0.4.0 → main` close-out would otherwise clear every test and collapse the whole branch. It is the one place a branch *name* is consulted and it only ever refuses — the declared model is the key, and a missed squash is the cosmetic half of the asymmetry this path is built on.
- **A workspace showed why the proxy could not be repaired in place.** One workspace, five members, one branch name: that branch is the default branch in four of them and not in the fifth. Under the old predicate the same close-out squashes in one member and merges in the other four — one arc, opposite histories, decided by a per-repository setting nobody configured for this purpose.
- **In `release` and `gitflow` nothing consults the default branch any more**, which is what makes the closing-keyword rules readable again: those genuinely turn on the default branch, and they are untouched.
- **The variable both `merge-pr` ports called `INTEGRATION` held `baseRefName`** — the conflation this release is about, expressed in code. It is `BASE_BRANCH` / `$BaseBranch` now, with the resolved integration branch a separate value.
- **The two ports were verified against one another rather than trusted.** The parity check compares surface only — sibling existence, usage line, contract env vars, ASCII, trailing newline — so it cannot see two ports disagreeing on a predicate. Both were run against one 17-row table covering all three models, the undeclared fallback, stacked epics, and a deliberate mis-declaration; they agree on every row.
- **`setup` gains a third reconcile arrow: the config against the PLUGIN.** It could already compare a config against its repo and a queue against the reference; neither notices that this plugin has started reading a key the config predates, so an optional key with a fallback reached nobody already running. The delta is a set difference over `examples/worktree.json` — the one machine-readable copy of the key set, and the one the gate already parses.
- **That arrow is cheap enough to have a trigger, which is the whole difference.** Comparing against the repo means re-deriving every script, so it stays asked-for; comparing against the plugin is a comparison of key names, so `/pipeline:orchestrate`'s config precondition now reports it at the one moment a config may safely change — between arcs, before any worktree is live. It **reports and routes, never stops**: every such key ships with a working fallback, and halting an arc over a value that has one costs more than it saves.
- **`branching model` joins the glossary**, with the inference it exists to forbid stated in it: the integration branch being the default branch is correct in one direction and wrong in the other, which is what makes it look reliable right up to the project where it is not.

## 4.8.0

- **Shared concepts have one home.** The passes are separate on purpose — a reader acts from one and should not open another to know what to do — but the *vocabulary* is shared, so a term four passes used was defined by four passes. `skills/glossary/` is where a definition lives now, as an index plus one entry per term, cited directly from wherever the term is used. **How a stance ACTS on a concept stays in that stance**: what `decompose` does about an epic branch, what `execute` does, what `orchestrate` does are three different things, all three correct, and none of them moved.
- **The drift was already real, not hypothetical.** `epic branch` had three near-verbatim definitions and two had already diverged — one said *an epic's **work** forks from and PRs into… the **arc** half-finished*, another *an epic's **slices** fork from and PR into… the **epic** half-finished*. Nothing in the corpus could have made them agree, because each copy was internally consistent and no check compares copies.
- **A "term" includes a FACT, not only a noun** — and the facts were the larger half. How `gh` treats `-F` versus `-f`, that `sub_issue_id` takes a database id whose wrong forms both read as a missing endpoint, that a closing keyword fires only where the PR targets the default branch, that a branch's leaf is load-bearing and its prefix is not: each is one fact every pass needs identically and none owns. Six entries; the `sub_issue_id` fact alone had four seats.
- **`no-cross-skill-citations` was narrowed rather than holed.** The map is the one legal cross-skill target **and only as a target** — an entry citing a pass fails exactly as any other cross-skill citation does, so the ban still holds in the direction that grew the 96-reference web, and no-cycles is enforced for free. Proved by reversal both ways.
- **A new check ties the map to the tree**, because a map of definitions that has itself gone stale is the disease one level up. Every entry must be indexed, cited by at least one pass, and free of instruction — an entry never addresses the reader, which is the map's core rule made mechanical after shipping as unenforced prose. A modal-word ban was tried and rejected: *decided by dependency, never by understanding* is a fact, and a guard that reds on correct work is one everyone waves through.
- **co-think prices a constraint before it narrows a design.** *We can't do X because Y* is a claim about **cost**, not possibility, and an unpriced one removes an option with nothing left to show it was removed — the user cannot object to an approach they were never shown. The closing rule already licensed changing a mechanism; it never asked what changing it would cost, or said that cost is owed to the user at the moment the mechanism is about to decide the shape for them.
- **The glossary splits by who owns the truth: `vocabulary/` and `mechanics/`.** A word this pipeline invented is ours to define and goes wrong by **drifting** — two copies worded differently, both looking right. A fact about git, GitHub or `gh` is true whether or not this pipeline exists, so it goes wrong by going **stale**, when the tool changes and nobody here touches a file. A citation naming `mechanics/` tells its reader which risk it carries before they open it, which is the one thing a marker inside the file cannot do.
- **An unlinked mention is now a gate failure, because it is where a second definition starts.** An entry naming another entry's term must link it; the term set is derived from the entry filenames, so it grows with the glossary rather than going stale against a list. It found two on its first run — `epic branch` named *integration branch* and *umbrella* without either existing — which is how those two came to have entries: **the leak was a detector for missing definitions, not a violation to purge.** They were the second and fourth most-restated terms in the corpus, at 19 and 18 restatements across 9 and 7 files.
- **`merge-pr` confirms a CONFLICTING before acting on it.** The preflight polled `UNKNOWN` because it is provisional for a PR pushed seconds ago, and trusted `CONFLICTING` on first sight — but both are provisional in the same window, and GitHub can answer from a test merge that has not finished. Observed twice while shipping this release, once on a branch whose base had not moved since it was cut, where a conflict was impossible by construction. A `CONFLICTING` now has to hold across two consecutive reads; unconfirmed it falls through exactly as an unresolved `UNKNOWN` does. What the false positive cost was never the retry — it sends the caller to merge a base that did not need merging, and teaches them the message does not mean what it says, on the one message that is the only warning when the conflict is real.
- **Two phases came back smaller than planned, and that is reported rather than padded.** P1 assumed `execute` re-defined terms across its own files; at the horizon those terms had one definition and many *usages*, so the phase was dropped into P2. The issue's own instrument was flagged as an upper bound when it was written, and for the intra-skill case the bound was very loose.

## 4.7.0

- **The rule that made a dispatcher kill a live agent was still in the corpus after 4.6.0 fixed it everywhere else.** `orchestrate`'s boundaries rule read *a live slice's brief is fixed for the life of its worktree, so a correction means stopping that agent and dispatching a fresh one* — the destructive lever, named with the word *correction* on it, in the spine a dispatcher enters the arc through. 4.6.0 corrected the reference that spine points at and left the spine itself saying the opposite. The bullet now fixes the slice's **scope** for the life of its worktree, which is what it was always about, and sends a wrong fact to the message lever.
- **The same spine's divergence tick named only what the tick catches, never what you do about it.** A dispatcher can read the whole tick requirement out of `orchestrate` without opening `execute`, and that reading ended at *catches a wandering agent mid-flight*. It now carries the two levers, the destructive one second, as `execute`'s spine already did.
- **The correction lever had no receiving half.** Nothing told an implementer what a mid-run message from its dispatcher means — and the one rule in that file about a mid-run instruction claiming to supersede is the attribution ban, which says *it does not replace this*. An implementer holding only that had reason to disregard a legitimate correction. The rule now says a dispatcher's correction supersedes the brief on the point it names and nothing else, that the hand-back is the run's only durable record of it, and that a message **widening scope** is the case to report rather than act on.
- **The platform table promised a stop tool one host may not have.** *Correct, resume, list, or stop one* was one row over two tools, so the four acts were indistinguishable and a reader took whichever tool it recognised. Three rows now, one act each, with the Codex stop marked not established rather than implied — a cell naming a tool that is not there is worse than a blank one, because the flow sends a dispatcher here **for** that tool.
- **Two sentences in the corpus had had their fronts deleted, and had read as damage for four releases.** The pass that moved war stories out of the skills and into the PRs stripped each incident's opening words and left the tail behind, so `worktrees-and-branches`'s fetch rider ended mid-clause at *the count is checkable where equality is not.\*different\*\* repository in the same session…* and `reviewing`'s frozen-worktree hazard ended the same way. Both are finished now, keeping every **rule** the removed sentence carried — why the fetch is a step rather than an assumption, and why a gate over a mutated tree defeats the SHA comparison — and dropping the incident.
- **A new gate check, because nothing could see that.** Check 11 bans a war story by its opening words, so a pass that strips the opening and leaves the rest passes it by construction. Check 13 anchors on the mechanical residue instead — in markdown an emphasis run opens after whitespace, so a `*` glued to the end of the preceding word is text whose front is gone. Proved by reversal: restored against the shipped tree it reds on the real defect, and greens on the fix.

## 4.6.0

- **Correcting a live agent is a lever the flow never named, so the only one it named was the destructive one.** The monitoring rules offered exactly one response to *something is wrong with a running implementer* — stop it and re-dispatch — while the capability to message a live agent sat in the platform table labelled only *resume, list, or stop*. Faced with a brief carrying one wrong number, a dispatcher reaching for the documented move kills an agent that was otherwise on track.
- **The test is what actually changed.** A wrong **fact** — a number, a path, a name, a bar set at the wrong value — is a *correction*, and it goes to the live agent as one message carrying the old value, the new one and why. A changed **scope** — different files, a moved boundary, a slice to re-cut — is the only thing warranting a stop, because that is a brief the agent can no longer be working to.
- **A stop is not the safe default it feels like.** Killing an implementer discards everything it has established — files read, consumers resolved, questions settled — and the successor re-pays all of it. The loss is invisible, because nothing reports what an agent knew at the moment it was killed.
- **The misreading this closes is a real rule applied to the wrong object.** *Once worktrees are live the config is frozen; drift is stop-and-report, never repair* is about shared mutable state other sessions cut worktrees from. A brief is neither shared nor re-read, so nothing carries that rule across — but *once live, never repair* is memorable enough to get applied to one anyway. The reconcile pass's *a fold is a new slice, never a widening of a live one* takes the same treatment: it is about scope, and it is not a ban on correcting a premise.
- **What a message loses against a re-dispatch, and how to get it back.** A fresh brief is durable by construction; a message dies with the agent's context. So the correction is written onto the issue or PR the brief points at, as a comment that explicitly supersedes what it replaces, with the live agent pointed at it.
- **The infra-stall rule already had the principle** — *one resume to the SAME agent; never a redispatch* — scoped to one case. It now says it is the same preference, in the case where it is least ambiguous.

## 4.5.0

- **A slice carries a `Goal`, and it is a carry rather than a new field.** An item *beyond* the horizon already stated one — shape depth carries goal, area and dependency — and promoting it to slice depth grounded everything else and dropped the goal, so the version of that item which actually reached an implementer was the first in the whole arc with no statement of what it was for. `Goal` now sits beside `Verify` in the slice fields, in the emit template, and in all three places that enumerate what slice depth carries.
- **The split is who can check it: `Verify` is run by a RUNNER, `Goal` is read by a READER.** A verify bar is mechanical and falsifiable; a goal needs judgment. The closing check gains a fifth pair testing exactly that seam — where one sentence would satisfy both, the goal is a restatement of the bar and the field has not been written yet.
- **The rule this exists to serve finally has an artifact.** *A green gate cannot tell whether the agent solved the right problem* has been in the slicing reference all along with nothing to judge against; it now names the goal as the thing a reader holds beside the diff.
- **Three readers, added in the order they see the work.** The implementer learns what its literal instructions are *for*, which is what distinguishes a wrong route — a correction it makes and reports — from a wrong destination, which is a hand-back. The inline review pass gains a sixth lens, **first** in the order, because every other lens asks whether the code is good and none asks whether it achieved anything. The dispatcher's PR read anchors its right-problem judgement to the goal and to the review pass's verdict on it, which reaches that reader only through the report — so the report grew a `Goal` line to carry it.
- **Neither reader may infer a goal that is missing.** A goal reconstructed from the brief is the brief scored against itself: it passes by construction and afterwards is indistinguishable from one that was checked. Both passes say so instead.
- **`execute`'s spine stops routing a one-slice arc into the loop.** Its *one increment* paragraph still carried the pre-split carve-out sending an arc that turns out to be one increment through `/pipeline:orchestrate`. It now states the same entry rule the loop does: an epic enters the loop, work the issue settles as one slice is grounded by `/pipeline:decompose` and completes here — so a whole single-slice issue does finish through this pass. The verdict is written in the issue and neither pass derives it twice.
- **Two leftovers from the same split.** `review`'s description named an `orchestrate` brief as the entry condition for dispatched work, which the single-slice path never produces — it now names the brief you were dispatched with, whichever pass wrote it. And the closing docs slice is last in the arc's **phase** map, the wave map having stopped being the arc-wide artifact in 4.4.0.

## 4.4.0

- **One altitude per pass, and two paths out of the issue.** Arc-shaping sat in two passes with colliding vocabulary and no owner. `write-issue` now plans the arc — the phase map to the arc's end, how a phase is sized, and the epic-versus-one-slice verdict — and `decompose` is the pre-execution grounding pass that runs on **both** paths: directly between `write-issue` and `execute` on one slice, once per cycle inside `orchestrate` on an epic. The issue is deliberately big-picture either way, and grounding it for an executor is what enriches it.
- **The arc-wide map has one producer.** It leaves `decompose`'s slicing reference for `skills/write-issue/references/arc-planning.md`, a new reference of `write-issue`'s own — the artifact a human reviews before a worktree exists. `decompose` carries the phase order forward and lays its waves out inside it.
- **The epic verdict is decided where the phases are set.** The two rules — is a partial state broken, and what N merges cost — move to `write-issue` with it. The branch's *mechanics* stay with `execute`, and `decompose` reports a contradiction onto the issue rather than answering the question a second time.
- **The sizing economics split rather than move.** Coarse half up: a phase boundary is where the branch is independently shippable, fewest phases that expose the real sequencing, never split for tidiness — and, since that pass is project-agnostic, the cost is **read from the repo's own config** rather than assumed. Fine half stays: slice count inside one phase, against a serialized gate and N reviews.
- **Neither pass claims unqualified grounding any more.** `write-issue` grounds what the arc rests on — the modules, the seams, the deliverables, whether the surface exists; `decompose` re-derives at the depth an executor acts on. What read as rework is a second altitude.
- **Three deletions.** The arc-wide map from the slicing reference; the loop's *a one-increment arc runs one cycle* carve-out, which had nothing left to except once one slice stopped reaching the loop; and `write-issue`'s *you do not slice into dispatchable waves*, eleven lines above the waves it emitted — replaced by the true boundary, **it sets the phases and does not ground them**.
- **`co-think` answers a request for judgment.** *What do you think*, *what do you suggest*, *what would you do*, *does this make sense*, *is this the right approach* — a family its build-shaped triggers never covered, and one that only reaches it now that `write-issue`'s claim is narrower.
- **The README stops explaining the citation check by a practice the gate fails on.** Check 8 exists because a skill points at **its own** references constantly; pointing at another skill is check 12's business and is a failure, not the rationale. The same section's account of check 9 described a repository-qualification escape that no longer exists — it fails on any tracker number in shipped prose.

## 4.3.0

- **The front door stops losing the routing race.** `/pipeline:write-issue` advertised *turn an idea or a rough plan into a grounded issue* — the whole front half of the pipeline, idea in and issue out — so `/pipeline:co-think`'s scope was a proper subset of it, and a request to *plan* or *think through* unshaped work matched the wrong pass on a true description. `write-issue` now advertises the input it actually wants, a shape already settled, which makes the two descriptions disjoint rather than nested. The fix is subtractive: no trigger word was added to the front door, because no set of phrases beats a superset.
- **A `description` carries a positive claim and no disclaimers.** A description is matcher input, so a negation inside one does not subtract — it adds the vocabulary it disclaims. Every *you do NOT* / *never* / *is X's job* clause leaves the frontmatter of `decompose`, `execute`, `orchestrate`, `review` and `write-issue` and is stated in the body, where it is read after loading and can bind. No guard was dropped.
- **The upstream guard nobody had.** Every pass declined to do the *next* pass's job and not one declined the *previous* pass's, which is the direction this failure ran. `write-issue` now hands back to `co-think` where the shape is not already settled.
- **`co-think` shapes toward the goal, not around the mechanisms it finds.** A closing rule: a check, a ceiling, a pipeline step or an existing pattern is an answer to an older goal and may be changed or deleted. With it, four moves at the actions they fire at — the goal written down as one testable sentence and the plan scored against it, at classification; forced work separated from sequenced work and settled first, at scoping; a flip condition named and the recommendation proceeded on anyway, since a recommendation plus a fork is still a fork; and *restate, commit, go* as how a pass resumes after a correction.
- **The last host literals leave shipped prose.** The self-paced timer, the stop-an-agent tool and the read-only search agent are named as capabilities. `orchestrate`, `decompose` and `write-issue` state them self-containedly, since a skill may not cite another skill; `execute`'s own files point at `skills/execute/references/platforms.md`, which stays the one place a host's tools are named.
- **`orchestrate` stops restating a ceiling that no longer exists.** Its close-out seat described a corpus total under a ratchet; it now names the per-file and per-sub-skill ceilings, and that extraction settles only the per-file half.

## 4.2.0

- **The plugin installs and runs on Codex as well as Claude Code.** A second manifest, `.codex-plugin/plugin.json`, sits beside the Claude Code one; the `skills/` tree is shared and unchanged in shape. `.agents/plugins/marketplace.json` makes the repository its own Codex marketplace, so `codex plugin marketplace add` then `codex plugin add pipeline@trinity-ai-labs` installs it.
- **Skill prose names capabilities, not one host's tools.** The sub-agent tool, backgrounding a dispatch, the banned auto-provisioner, invoking a skill and the model tier are all stated vendor-neutrally; `skills/decompose` now emits a **standard tier** / **top tier** rather than a model id. The concrete mappings — tools, models, manifests, and the `reasoning_effort` that must ride with every Codex spawn — live in one new reference, `skills/execute/references/platforms.md`.
- **Helper resolution is per-host, and that is the load-bearing difference.** Claude Code puts an enabled plugin's `bin/` on PATH, so helpers are bare commands; Codex installs the same `bin/` but puts nothing on PATH, so they are called by absolute path from the installed plugin root. Stated at every seat that invokes one.
- **Check 2 validates both manifests and asserts they agree on `version`.** Each host pins an install to its own manifest's string, so one bumped alone ships a different release to each. It also enforces Codex's 13-key top-level allowlist, where a field copied across out of symmetry is a failed install rather than a harmless extra.
- **Corpus 52,709 → 52,624 words**, ratchet lowered to match. Going vendor-neutral paid for the new reference: the `.sh`/`.ps1` extension rule folded into it, and `worktrees-and-branches.md`'s config-lookup paragraph went 605 → 328 words with every rule kept.

## 4.1.0

- **`/pipeline:co-think` — a front door, and the pass nothing owned.** Every other pass is downstream of a decision none of them makes: is this the right shape of work? It classifies the request out loud so you can override it — spike, bounded or architectural, doubt taking the heavier one and the ratchet one-way — checks scope before refining detail, asks one question per message, takes a bug to a root cause before classifying it, shapes an arc's epics, sequence, seams and blast radius, and routes. 1,299 words.
- **The README stops presenting seven skills as peers.** Two tables now — what you type, and what the loop invokes — because `orchestrate` encompasses `decompose` and `execute` and the flat list hid it.
- **The corpus ratchet gains the exception it was missing.** It read *never raised to fit new prose*, which forbids the pipeline ever gaining a stage; it now forbids raising it for prose added to an **existing** file, and a whole new pass raises it deliberately, in the release that adds it. 51,376 → 52,709.
- **Check 10 counts files that are not staged yet.** It used `git ls-files`, so a brand-new skill — the exact case a ceiling exists to weigh — was invisible until `git add`, printing a false green on the run an author actually reads.

## 4.0.0

- **Every skill is now an ordered list of actions.** Each action names the reference that says how and carries the rules that fire at that action; the topic tables and the detached blocks of hard rules are gone. `execute` 2,483 → 1,618 words with ten references grouped into six; `decompose` 8,250 → 1,537 plus three; `orchestrate` 4,836 → 2,533 plus one.
- **A skill no longer cites another skill.** All 96 cross-skill references are deleted, not repointed — each is now the rule stated where its reader acts, or nothing. Nineteen of them were `§N` citations that had silently drifted onto real sections carrying different arguments.
- **War stories, and their links, live in the PR that fixes them.** 25 failure-narrative paragraphs and every issue number leave shipped prose. `AGENTS.md` 7,885 → 2,580 words: its every-seat rule goes from 2,891 words to 69, and its anti-restatement convention — the thing that grew the citation web — is inverted to *state a rule where its reader acts.*
- **Four checks enforce it.** `scripts/check.sh` 1,054 → ~680 lines: no issue numbers (9), the per-file ceiling and corpus ratchet (10), no war stories (11), no skill cites another skill (12). Check 4 now scans every tracked `skills/` doc rather than only the spines.
- **A tenth gate-queue invariant: refuse to gate a worktree carrying uncommitted tracked changes**, settling the ticket *refused* rather than red. A refusal is delivered like any verdict — settling it silently leaves a bare PR, which tells a dispatcher to re-enqueue against a still-dirty tree.
- **`bin/` helpers answer a failed `git` call the same way in both ports** — exit 1 with a helper-owned message, in 14 call sites across three helpers. One of them printed `HEAD: ` with an empty sha and exited 0.

*The shipped corpus is 121,280 → 51,376 words across the day, a 58% cut, and the whole repo went from roughly 220,000 words to 74,000.*

## 3.61.0

- `CHANGELOG.md` is a changelog again: 98,922 → 8,991 words, one to three lines per release. All 108 release headings survive in order; every issue and PR link is kept, and the reasoning lives there rather than in this file. It was nearly twice the size of the product it describes.

## 3.60.0

- `skills/review/SKILL.md` drops a machine-local line-count measurement and keeps the claim it was supporting ([#285](https://github.com/trinity-ai-labs/orchestration-skills/issues/285)). Corpus 53,658 → 53,590 words.

## 3.59.0

- `/simplify` is gone from shipped prose; the quality pass is named positively as `/pipeline:review`.
- Every sub-agent this flow spawns is a fresh agent and never a fork, stated at all six seats that spawn one. Corpus 53,762 → 53,658 words.

## 3.58.0

- Wave 2 of the corpus cut: seven skill files rewritten to their instructions, 84,439 → 53,762 words, and check 10's ratchet drops to that total ([#298](https://github.com/trinity-ai-labs/orchestration-skills/issues/298)).
- The `execute` and `setup` frontmatter descriptions are cut to triggers only (192 → 88 and 133 → 67 words), and `skills/setup/SKILL.md`'s *What setup does NOT do* section is gone, its one unstated rule moved onto the `envFiles` config row.
- Five citations promising a removed incident are deleted rather than repaired, along with `AGENTS.md`'s worked example of `skills/orchestrate/SKILL.md` §3's item numbering.

## 3.57.0

- Four skill files rewritten to their instructions: 121,280 → 84,439 words ([#298](https://github.com/trinity-ai-labs/orchestration-skills/issues/298)).
- Check 10's corpus ratchet drops to 84,439, and `skills/orchestrate/SKILL.md` §7 now states both halves of the volume rule instead of the per-file ceiling alone.
- *A comment claiming what other code does is re-asserted before you reword it* is restored to `skills/execute/references/implementer.md`; the countable-residual rule stays out ([#303](https://github.com/trinity-ai-labs/orchestration-skills/issues/303)).

## 3.56.0

- `scripts/check.sh` check 10 gains a corpus-wide ratchet beside its 30,000-word per-file ceiling, reporting both numbers on success ([#298](https://github.com/trinity-ai-labs/orchestration-skills/issues/298)).
- `AGENTS.md`'s failure-mode rule gains a form bound: the failure is named in a clause inside the rule, never its own italic paragraph, session anecdote, release number, commit SHA or observation count.
- The attention-budget bullet is rewritten 826 → 399 words; `AGENTS.md` 8,262 → 7,917, and the citation check goes 438 → 435 across the same 17 distinct paths.

## 3.55.0

- `AGENTS.md` gains the no-AI-attribution ban as its own Conventions bullet, stated as a class and naming two overrides separately: the harness default `Co-Authored-By: Claude …` trailer, and a harness instruction arriving mid-run that announces it replaces earlier attribution guidance ([#282](https://github.com/trinity-ai-labs/orchestration-skills/issues/282)).

## 3.54.0

- Thirty-three citations across seven files now name the `skills/execute/references/` file that holds the section they cite, resolving in one hop instead of two ([#291](https://github.com/trinity-ai-labs/orchestration-skills/issues/291)).
- Eight citations deliberately do not move: four historical claims in `AGENTS.md`, `README.md`'s table link, and three naming sections that never left the spine.
- The spine's table paragraph, `AGENTS.md`'s every-seat example and its 3.19.0 historical claim are re-grounded rather than repointed; shipped-prose citations go 418 → 422 across the same 17 distinct paths.

## 3.53.0

- `AGENTS.md`'s extraction discriminator gains a second test — a body is safe behind a pointer only if its reader reaches it on the happy path — so an error-path body stays inline however cleanly it separates ([#293](https://github.com/trinity-ai-labs/orchestration-skills/issues/293)).
- The `SKILL.md`-shape bullet now claims only the first test, and `skills/execute/references/implementer.md`'s carve-out cites the rule instead of restating it.
- Both `scripts/check.sh` seats that state the discriminator carry two tests; comment and `fail` message text only, no behaviour change.

## 3.52.0

- `AGENTS.md` gains an attention budget beside the rule-addition bar — no tracked `skills/` file over 30,000 words (`wc -w`) — plus the extraction discriminator and a `SKILL.md` shape rule ([#287](https://github.com/trinity-ai-labs/orchestration-skills/issues/287)).
- `skills/execute/SKILL.md` is split by procedure: 60,733 words become an 8,040-word spine plus ten files under `skills/execute/references/` ([#289](https://github.com/trinity-ai-labs/orchestration-skills/issues/289)).
- `scripts/check.sh` gains check 10 enforcing the per-file ceiling, and `skills/orchestrate/SKILL.md` §7's finding bar is scoped to its own channel.

## 3.51.0

- `AGENTS.md` gains a count convention beside the two citation ones: name the unit or the command, prefer the count of the thing being counted, and name the baseline of any comparison ([#272](https://github.com/trinity-ai-labs/orchestration-skills/issues/272)).
- The every-seat rule's written count is stated to be a count of seats, and its keying half now names same-wording-different-casing as the cheapest way a sweep misses one ([#259](https://github.com/trinity-ai-labs/orchestration-skills/issues/259)).
- The measured-value tie-break gains the author's obligation to measure in the tree the brief describes, and both tie-break seats now say what the number counts ([#275](https://github.com/trinity-ai-labs/orchestration-skills/issues/275)); three shipped seats stop stating a count of the observer's own plugin cache, keeping the claims those numbers supported.

## 3.50.0

- `skills/execute/SKILL.md`'s *The PR review loop* now reads the PR body and the commit messages for attribution before the ready flip, keyed on the class, and names the epic → integration close-out explicitly ([#264](https://github.com/trinity-ai-labs/orchestration-skills/issues/264)).
- The every-seat rule gains the reviewer's half beside the author's: `AGENTS.md` has the reviewer read the enumeration against the diff ([#270](https://github.com/trinity-ai-labs/orchestration-skills/issues/270)), and the review loop now reads `skills/review/SKILL.md`'s `Rejected` list.
- The pasted handoff block stops restating the hand-back's contents and cites the **Hand back** step instead ([#276](https://github.com/trinity-ai-labs/orchestration-skills/issues/276)); a check for the attribution ban was considered and filed rather than built.

## 3.49.0

- The frozen-worktree rule leads with the ticket's existence rather than with whether a gate is observably running — a ticket in any non-terminal state freezes the tree — at both seats plus `skills/setup/references/gate-queue.md`'s heading ([#230](https://github.com/trinity-ai-labs/orchestration-skills/issues/230)).
- A seam map row now asks what the consuming side *does* with a value, not only that it reads one; `skills/write-issue/SKILL.md`'s `Seams` field takes it too ([#210](https://github.com/trinity-ai-labs/orchestration-skills/issues/210)).
- Two further seats landed beyond the brief's enumeration: `skills/execute/SKILL.md`'s cross-slice seam review, and the epic worktree's every-tick `install`.

## 3.48.0

- `skills/decompose/SKILL.md`'s `Derives` writes its two slice-facing clauses into the emitted entry beside the path, and `skills/execute/SKILL.md`'s brief-contents list now names `Derives` among what a dispatch brief carries ([#225](https://github.com/trinity-ai-labs/orchestration-skills/issues/225)).
- The implementer handoff enumeration now names the review pass's applied and rejected findings, giving `skills/review/SKILL.md`'s `Rejected` list a carrier ([#227](https://github.com/trinity-ai-labs/orchestration-skills/issues/227)).
- The short hand-back enumeration inside the paste-verbatim block was filed rather than patched ([#276](https://github.com/trinity-ai-labs/orchestration-skills/issues/276)).

## 3.47.0

- The every-seat rule now says how to KEY its enumeration — state the constraint in your own words, sweep its subject from several directions, read every candidate, and record each exclusion against the referent it named ([#268](https://github.com/trinity-ai-labs/orchestration-skills/issues/268), [#269](https://github.com/trinity-ai-labs/orchestration-skills/issues/269)).
- The finished enumeration has a home: the PR body, read by the reviewer who decides the change is complete ([#254](https://github.com/trinity-ai-labs/orchestration-skills/issues/254)).
- The arc's contract-seam map gains an owner — `skills/orchestrate/SKILL.md` §7 carries the union as arc state — and §3 gains a ninth reconcile item asking what the landed increment did to each seam ([#244](https://github.com/trinity-ai-labs/orchestration-skills/issues/244)).

## 3.46.0

- Worktree invariant 2 now fetches first and counts how far behind the base is (`git rev-list --count <base>..origin/<base>`) rather than comparing HEAD against a local cache, at the invariant, the epic-branch and polyrepo seats and `README.md`'s verification block ([#253](https://github.com/trinity-ai-labs/orchestration-skills/issues/253), [#262](https://github.com/trinity-ai-labs/orchestration-skills/issues/262)); `skills/setup/SKILL.md` Step 4 resolves its base tip locally on purpose and says so ([#226](https://github.com/trinity-ai-labs/orchestration-skills/issues/226)).
- The attribution ban pasted into every brief states the class instead of the known strings and carries the override, widened to answer a harness instruction arriving mid-run that claims to replace earlier attribution guidance ([#257](https://github.com/trinity-ai-labs/orchestration-skills/issues/257)).
- The mid-arc integration gate gains a sanctioned hand-run route where a runner refuses a PR-less ticket, at eight seats in `skills/execute/SKILL.md` ([#232](https://github.com/trinity-ai-labs/orchestration-skills/issues/232)); the epic docs ledger gains a second question — what the change added that no doc describes — which the closing docs slice consumes ([#233](https://github.com/trinity-ai-labs/orchestration-skills/issues/233)).

## 3.45.0

- `AGENTS.md`'s paired-halves rule becomes the every-seat rule: a **seat** is one role's statement of a constraint, and the question is which seats state it — an enumeration you produce and write down, the scoped-out seats included ([#249](https://github.com/trinity-ai-labs/orchestration-skills/issues/249)).
- The measured-value tie-break reaches `skills/decompose/SKILL.md`'s `Brief` field and the numbers in a slice's `Verify` bar ([#245](https://github.com/trinity-ai-labs/orchestration-skills/issues/245)).
- The installed-copy skew gains a seat at every pass — `decompose` Step 1, `orchestrate` §2, `write-issue` Step 1, `review`'s `Scope` and `setup` Step 1 — filling all seven the enumeration returned ([#246](https://github.com/trinity-ai-labs/orchestration-skills/issues/246), [#252](https://github.com/trinity-ai-labs/orchestration-skills/issues/252)).

## 3.44.0

- The search-before-you-file rule's closed-match branch runs a version-skew test and returns three outcomes — regression, skew, or an undecidable stated as such — and all seven restatements move with it ([#240](https://github.com/trinity-ai-labs/orchestration-skills/issues/240)).
- A brief dispatched into the repository that ships these skills now names which copy is authoritative, at the dispatch seat and the implementer seat; the dispatch pointer block gains the grounding pass and retires its own counts ([#229](https://github.com/trinity-ai-labs/orchestration-skills/issues/229), [#239](https://github.com/trinity-ai-labs/orchestration-skills/issues/239)).
- A handed-down measured value carries its tie-break at both seats ([#222](https://github.com/trinity-ai-labs/orchestration-skills/issues/222)), and the ledger-watch example is rewritten to arm under zsh — a file-based seen set and `find` in place of an array subscript and a bare glob ([#231](https://github.com/trinity-ai-labs/orchestration-skills/issues/231)).

## 3.43.0

- `AGENTS.md` gains the paired-halves rule: a constraint with a planner-facing half and an actor-facing half is one change, not two ([#215](https://github.com/trinity-ai-labs/orchestration-skills/issues/215)).
- The sweep that rule demands fixes three broken pairs — the closing-keyword rule's implementer half (`Refs #<n>`, never a closing keyword), the property-vs-instrument rule's implementer half, and the epic-branch leaf-collision half in `skills/decompose/SKILL.md` ([#224](https://github.com/trinity-ai-labs/orchestration-skills/issues/224)).
- `scripts/check.sh` gains a ninth check requiring a tracker coordinate in shipped `skills/` prose to name the tracker it resolves in, with the governed passage cut at list markers rather than at blank lines ([#236](https://github.com/trinity-ai-labs/orchestration-skills/issues/236), [#235](https://github.com/trinity-ai-labs/orchestration-skills/issues/235)); `.github/workflows/ci.yml` and `README.md` stop enumerating the gate's checks.

## 3.42.0

- Each dispatched implementer gets a scratchpad of its own, provisioned by the dispatcher and named in the brief, with a kill-by-exact-pid caution beside it ([#211](https://github.com/trinity-ai-labs/orchestration-skills/issues/211), [#217](https://github.com/trinity-ai-labs/orchestration-skills/issues/217)).
- In in-line gate mode the verdict comment is stated not to be the hand-back, where the mode is set and at the merge step ([#212](https://github.com/trinity-ai-labs/orchestration-skills/issues/212)).
- A finding is checked against what is already filed before it is filed: a search section ahead of `skills/write-issue/SKILL.md` Step 1, keyed on failure shape, covering closed issues, with three outcomes — and `README.md`'s upstream-filing disclosure and `skills/setup/SKILL.md`'s consent ask widen to cover the comment outcome ([#216](https://github.com/trinity-ai-labs/orchestration-skills/issues/216)).

## 3.41.0

- `setup-worktree` verifies its own output in new-branch mode: unless the resolved base tip is an **ancestor** of the worktree's HEAD it writes both shas to stderr, exits `1` and prints no `READY:` line, on both ports, with `--existing` a stated carve-out ([#189](https://github.com/trinity-ai-labs/orchestration-skills/issues/189)).
- Four `.ps1` headers stop claiming the parity check keeps the two ports from drifting quietly, and the `Invoke-Expression` exit-code divergence is documented at its suppression rather than fixed ([#203](https://github.com/trinity-ai-labs/orchestration-skills/issues/203), [#201](https://github.com/trinity-ai-labs/orchestration-skills/issues/201)).
- A verify bar that ships a command now states its property in words and is checked against the case the slice is expected to produce ([#205](https://github.com/trinity-ai-labs/orchestration-skills/issues/205)); an issue filed from behind a fence carries `Filed from behind a fence: <path>` on its own line, `skills/orchestrate/SKILL.md` §4 keys on it, and `Do NOT touch` says which findings a slice may correct inside the fence ([#193](https://github.com/trinity-ai-labs/orchestration-skills/issues/193)).

## 3.40.0

- `skills/write-issue/SKILL.md` and `skills/decompose/SKILL.md` resolve a `§N` or any named section by opening it and reading what it argues, never by searching for the word the claim turns on ([#190](https://github.com/trinity-ai-labs/orchestration-skills/issues/190), [#187](https://github.com/trinity-ai-labs/orchestration-skills/issues/187)).
- The falsification sweep asks what **writes** an artifact as well as what reads it ([#195](https://github.com/trinity-ai-labs/orchestration-skills/issues/195), [#194](https://github.com/trinity-ai-labs/orchestration-skills/issues/194)), and `skills/setup/SKILL.md` gains the `upstreamFindings` consent ask plus an *Already configured? Reconcile the config against the repo* path that reports a per-key verdict and never rewrites ([#186](https://github.com/trinity-ai-labs/orchestration-skills/issues/186)).
- Both `bin/setup-worktree` ports print a byte-identical install-failure message naming the worktree and exit `1` ([#183](https://github.com/trinity-ai-labs/orchestration-skills/issues/183)), and `scripts/check.sh` check 2 requires `repository` in the manifest ([#197](https://github.com/trinity-ai-labs/orchestration-skills/issues/197)).

## 3.39.0

- `skills/orchestrate/SKILL.md` §7 gains a carve-out: where the resolved filing target is the repository the arc is already running in, the finding is filed and `upstreamFindings` does not apply ([#191](https://github.com/trinity-ai-labs/orchestration-skills/issues/191), correcting [#187](https://github.com/trinity-ai-labs/orchestration-skills/issues/187)).
- The test compares `.claude-plugin/plugin.json`'s `repository` against the running repository's origin by owner and name rather than as URL strings, and the genericising leak guard is explicitly untouched.
- All five seats that state or withhold the key agree — §7, `skills/execute/SKILL.md`'s key list and `README.md`'s three — while this repository's own `.agents/worktree.json` and `examples/worktree.json` are deliberately unchanged.

## 3.38.0

- §7's close-out has exactly three answers — **filed**, **none found**, **not enabled here** — and resolves its filing target from `.claude-plugin/plugin.json`'s `repository` field rather than from memory ([#187](https://github.com/trinity-ai-labs/orchestration-skills/issues/187)).
- `upstreamFindings` is a per-project opt-in whose absence is a no, documented in `skills/execute/SKILL.md`'s key list and `README.md` and shipped as an explicit `false` in `examples/worktree.json`.
- Genericising is a leak guard that binds regardless of the opt-in, `README.md` gains a disclosure section above `## Install`, and the finding-quality directive folds into §7 inline with no renumbering.

## 3.37.0

- `skills/orchestrate/SKILL.md` §2 gains *Before the loop: the config precondition*, and `skills/decompose/SKILL.md`'s config bullet stops giving the opposite instruction ([#182](https://github.com/trinity-ai-labs/orchestration-skills/issues/182)).
- The boundary is dispatch: before anything is dispatched the loop owns the config, and once worktrees are live it is frozen for the arc and drift is stop-and-report.
- The precondition announces, explains, asks for the values `setup` cannot ground, invokes it, and ends by handing over a PR the loop does not merge.

## 3.36.0

- `skills/decompose/SKILL.md`'s `Brief` bullet gains a conditioned clause — where the prose you are briefing about ships to other repos, cite it by path — leaving `AGENTS.md` and the shipped skills' bare mentions untouched ([#179](https://github.com/trinity-ai-labs/orchestration-skills/issues/179)).

## 3.35.0

- `AGENTS.md`'s citation convention gains the instruct/cite split: instruct with a bare filename freely, cite only by a `skills/…/SKILL.md` path ([#179](https://github.com/trinity-ai-labs/orchestration-skills/issues/179)).
- The 31 bare mentions a sweep found across the shipped skills are left in place, and `skills/execute/SKILL.md` is assessed as not affected.

## 3.34.0

- `skills/orchestrate/SKILL.md` §2 states where the divergence tick is required that `ScheduleWakeup` is accepted outside `/loop` mode, and its guard leads with the class rule and answers both known readings ([#178](https://github.com/trinity-ai-labs/orchestration-skills/issues/178)).
- `skills/execute/SKILL.md`'s *Gate the integrated whole* runs the project's `install` in the main checkout unconditionally before the gate, and the stale-install rule's epic-worktree uniqueness claim is corrected.

## 3.33.0

- `skills/execute/SKILL.md`'s *Worktree creation* ⚠️ tells the two merges apart: the config-read window closes at the **epic → integration** close-out, not at a slice merge ([#176](https://github.com/trinity-ai-labs/orchestration-skills/issues/176)).
- A new ⚠️ beside invariant 2 makes hand-applying an unmerged config change a standing dispatcher obligation for every worktree cut for the rest of the arc, and says it goes in the brief.
- `skills/orchestrate/SKILL.md` §3 item 3 gains a clause for the silently-forced config case, and `skills/setup/SKILL.md` and `README.md` are narrowed to *until the change reaches that copy*.

## 3.32.0

- `skills/orchestrate/SKILL.md` §3 gains item 8, a reconcile item putting every still-live follow-up filed out of the arc back through §4 each cycle ([#174](https://github.com/trinity-ai-labs/orchestration-skills/issues/174)).
- §4 gains the hand-over bar that closes it, and §7 makes the arc record on the issue which state it left each follow-up in.

## 3.31.0

- The native `sub_issues` link is argued from `skills/decompose/SKILL.md` Step 1's `/parent` call rather than from an empty checklist, and `skills/write-issue/SKILL.md` stops restating the link form and points at the authoritative copy ([#165](https://github.com/trinity-ai-labs/orchestration-skills/issues/165)).
- Two *third carve-out* pointers and three *the three carve-outs* citations now name it as **the coordinate carve-out** ([#167](https://github.com/trinity-ai-labs/orchestration-skills/issues/167)).
- `sharedResources` stops being called the only value the setup pass must ask for, at all three seats that said so ([#170](https://github.com/trinity-ai-labs/orchestration-skills/issues/170)).

## 3.30.0

- `AGENTS.md`'s citation convention separates an item's own label from a position within a list — `invariant 8`, `§3` and `Step 4` stay, *the third bullet* stays banned — and says that coining a name for an unnamed referent is authoring rather than citing ([#156](https://github.com/trinity-ai-labs/orchestration-skills/issues/156)).
- `skills/orchestrate/SKILL.md` §4's rider restates the widened follow-up link rule — both links under `Part of #<umbrella>`, the backlink alone for a bare `Follows #<N>` ([#157](https://github.com/trinity-ai-labs/orchestration-skills/issues/157)) — and the enumeration rule reaches the implementer at both ends: a handed-down list is a floor on reach, the `Do NOT touch` fence the ceiling on edit ([#160](https://github.com/trinity-ai-labs/orchestration-skills/issues/160), [#141](https://github.com/trinity-ai-labs/orchestration-skills/issues/141)).
- The adjacent-fact test keeps exactly one move, fix both halves ([#161](https://github.com/trinity-ai-labs/orchestration-skills/issues/161)), and a `reclaim` key naming the project's own `{report, drop}` commands lands with the `rev-parse` path rule and the resource-marking requirement ([#134](https://github.com/trinity-ai-labs/orchestration-skills/issues/134), [#170](https://github.com/trinity-ai-labs/orchestration-skills/issues/170)).

## 3.29.0

- The falsification sweep reads the callers of the site a slice changes, and the test files that come back go in `Owns` with their disposition written down ([#137](https://github.com/trinity-ai-labs/orchestration-skills/issues/137)).
- `Derives` gains the sweep that fills it, so an empty field is a claim rather than a default ([#143](https://github.com/trinity-ai-labs/orchestration-skills/issues/143)); an enumeration is a claim whose count comes from the command that filtered nothing, and `2>/dev/null` on a search is banned ([#141](https://github.com/trinity-ai-labs/orchestration-skills/issues/141)).
- The Implementer section states the native `sub_issues` call in full with its database-id trap ([#140](https://github.com/trinity-ai-labs/orchestration-skills/issues/140)), the identifier swap settles strict beside a separate adjacent-fact obligation ([#142](https://github.com/trinity-ai-labs/orchestration-skills/issues/142)), and the pointers already past the adjacency line name their referent ([#151](https://github.com/trinity-ai-labs/orchestration-skills/issues/151)).

## 3.28.0

- `/pipeline:setup`'s Step 4 queue check gains a sub-step that enqueues a PR-less ticket and reads what comes back, with two legible outcomes both counting as a pass ([#128](https://github.com/trinity-ai-labs/orchestration-skills/issues/128)).
- A ticket's gate mode is re-derived after a base merge from `git diff --name-only $(git merge-base HEAD origin/<base>) HEAD`, with the fork point recomputed after the merge rather than carried forward ([#115](https://github.com/trinity-ai-labs/orchestration-skills/issues/115)).
- `AGENTS.md`'s citation convention reaches positions as well as counts — a citation names its referent, never a count of it and never its position — with adjacency as the distance line ([#147](https://github.com/trinity-ai-labs/orchestration-skills/issues/147)), and `README.md`'s account of the queue verification drops its count.

## 3.27.0

- The two counts of *Merge & cleanup*'s close-out steps are de-ordinalised rather than corrected, and the relationship they stood in for is stated instead ([#144](https://github.com/trinity-ai-labs/orchestration-skills/issues/144)).
- The hand-close timing predicate is stated once, in the clause that already asserted the timing: which issues you close here turns on what this PR settled.
- The pointer resolving an arc-level close to the per-merge step now names §7's termination check, `README.md` says REST rather than `gh issue close` ([#138](https://github.com/trinity-ai-labs/orchestration-skills/issues/138)), and the positional-pointer gap is filed ([#147](https://github.com/trinity-ai-labs/orchestration-skills/issues/147)).

## 3.26.0

- `AGENTS.md` gains the ranked convention for citing a numbered list: an item cites only what precedes it; failing that, de-ordinalise a remote citation; and only where a remote count cannot be removed, declare one site authoritative ([#136](https://github.com/trinity-ai-labs/orchestration-skills/issues/136)).
- The paste-verbatim count is stated once beside its own list and deleted from both remote sites, overturning 3.19.0's declare-one-authoritative decision.
- `README.md`'s reconcile gloss is marked as a sample, no checker is added, and one more live instance is filed rather than fixed ([#144](https://github.com/trinity-ai-labs/orchestration-skills/issues/144)).

## 3.25.0

- *The epic branch* → *Mechanics* gains a bullet on what an epic does to the tracker: a slice PR based on the epic branch has an inert closing keyword, so the fifth close-out step is the whole mechanism ([#131](https://github.com/trinity-ai-labs/orchestration-skills/issues/131)).
- *Worktree creation* states which copy of `.agents/worktree.json` the helper reads — `<main checkout>/.agents/worktree.json` as a file on disk — and why both obvious ways round the config-read window fail, with a shorter copy in `/pipeline:setup`'s Step 5.
- `README.md`'s *Per-project config* and epic-branch paragraphs take both halves.

## 3.24.0

- `skills/orchestrate/SKILL.md` §3 gains a seventh reconcile item comparing the arc's goal in the filer's own words against what the remaining plan would deliver ([#123](https://github.com/trinity-ai-labs/orchestration-skills/issues/123)).
- A `no` halts and reports rather than escalating: §4 gains the level boundary, §7's termination stops reading as two-valued, and §9 gains one clause.
- The intro's *Run all six* is de-ordinalised, and `README.md`'s autonomy-contract line and reconcile paragraph take the new halt.

## 3.23.0

- `.agents/worktree.json` gains `sharedResources` — `{resource, isolatedBy}` entries, or an explicit `null` for one that stays shared — with three states in which absence means nobody asked ([#129](https://github.com/trinity-ai-labs/orchestration-skills/issues/129)).
- `/pipeline:setup` asks the maintainer for it, falsifies the answer with a concurrent gate, and gains **No provisioning** as a hard boundary; `skills/decompose/SKILL.md`'s *Sizing* prices it in correctness rather than in gate time.
- `skills/execute/SKILL.md`'s *Reading a gate result* gains the across-gates read, the unowned teardown leak is named and left open, and this repository's own `.agents/worktree.json` gains `"sharedResources": []`.

## 3.22.0

- `skills/decompose/SKILL.md` Step 3's closing check gains a fourth pair testing whether a `Brief`'s *derive X from Y* is reachable from where the slice will run, with the count moved in three files ([#124](https://github.com/trinity-ai-labs/orchestration-skills/issues/124)).
- Step 1's research bullet now says it establishes a coordinate's existence in the tree and nothing about reachability, and `skills/execute/SKILL.md`'s *A brief that contradicts ITSELF* names transcription as the silent move.
- `skills/write-issue/SKILL.md`'s `Verify` bullet gains the matching fourth mapped check.

## 3.21.1

- `remove-worktree` resolves a workspace member's worktree at `$WORKTREE_HOME/<workspace>/<leaf>/<repo>` as well as the bare layout on both ports, and a derived path that resolves to nothing is checked against git's worktree registry and fails rather than reporting a clean no-op ([#126](https://github.com/trinity-ai-labs/orchestration-skills/issues/126)).
- `merge-pr` hands the teardown the absolute path git printed instead of a branch name, keeping the branch name only as the fallback.
- The `.sh` port's absolute-path prune now matches the `.ps1`, `scripts/check.sh`'s parity check gains a per-file assertion that a helper consuming `WORKTREE_HOME` must read `.agents/workspace.json`, and `README.md` carries both layouts.

## 3.21.0

- The epic → integration close-out PR opens as a **draft** first and its gate is enqueued against it, with the precondition restated over the merge rather than over the open ([#122](https://github.com/trinity-ai-labs/orchestration-skills/issues/122), [#121](https://github.com/trinity-ai-labs/orchestration-skills/issues/121)).
- `prNumber`/`prUrl` become optional at enqueue so the mid-arc integration gate goes in as a PR-less ticket, recorded in `skills/setup/references/gate-queue.md` as undeliverable-by-construction across invariants 7 and 8, with a runner predating the change obliged to reject one.
- *Reading a gate result*'s two counts are stated separately — no durable record 3 → 1, no PR comment 3 → 2 — and `README.md` gains two clauses.

## 3.20.0

- `skills/execute/SKILL.md` gains *Wait on your own tickets settling*: one persistent `Monitor` over the queue's `done/` ledger, armed once per wave, keyed on the wave's branches and deduped on the ticket file with the seen-set primed before the loop ([#121](https://github.com/trinity-ai-labs/orchestration-skills/issues/121)).
- It scopes on the enqueue-time fields only, emits on SETTLED rather than on a verdict, stays off the divergence tick, and is dispatcher-only.
- The `⛔ Implementers never run the full suite` hard rule gains the queueless carve-out its two companions already carried, and `README.md`'s hard-rules line names the queueless default.

## 3.19.2

- Check 8's pattern admits any `.md` under `skills/`, so a reference doc cited by path is covered by the same rule as a `SKILL.md` ([#118](https://github.com/trinity-ai-labs/orchestration-skills/issues/118), [#117](https://github.com/trinity-ai-labs/orchestration-skills/issues/117)).
- The widened block comment carries no citation count at all — the `ok` line prints the live one — and `README.md`'s description of the check moves with it.

## 3.19.1

- `scripts/check.sh` gains check 8: every `skills/<name>/SKILL.md` path cited in a tracked `.md` is tested against the tree, failing closed with the file and line of every citing site ([#117](https://github.com/trinity-ai-labs/orchestration-skills/issues/117), [#114](https://github.com/trinity-ai-labs/orchestration-skills/issues/114)).
- It scans every tracked `*.md` — 73 citations, all resolving — is scoped to git-tracked files, and leaves the placeholder form `skills/<slug>/SKILL.md` unmatched.
- Prose section references are deliberately out of scope, the `skills/setup/references/gate-queue.md` residual is filed as [#118](https://github.com/trinity-ai-labs/orchestration-skills/issues/118) rather than folded in, and `README.md`'s *Adding a skill* names the check.

## 3.19.0

- The no-backgrounding rule is restated over the **handoff** — never background a check or command and end your turn on it — beside the existing ban, in `skills/execute/SKILL.md`'s Implementer section and in `skills/review/SKILL.md` ([#114](https://github.com/trinity-ai-labs/orchestration-skills/issues/114)).
- It is scoped to checks and commands and explicitly not to sub-agents, and reaches every brief as a sixth paste-verbatim item.
- The dispatcher's escalation conjunct is narrowed to a wait on **sub-agents it spawned**, and the paste-item count reads six in both places that state it.

## 3.18.2

- *Gate the integrated whole* gains the rule that a pipeline's exit status is its last command's, so a hand-run gate is captured as `gate > gate.log 2>&1; echo "EXIT=$?"` and never piped ([#105](https://github.com/trinity-ai-labs/orchestration-skills/issues/105)).
- *Reading a gate result* states that all of it is about a verdict a runner posted and hands the direct-run case forward, and the override-mode implementer seat takes a pointer.
- `set -o pipefail` is named and rejected in place rather than left as the obvious improvement.

## 3.18.1

- `skills/decompose/SKILL.md`'s `Verify` field requires a bar asserting a negative to name what it is measured against, defaults that to the fork point, and requires the bar to say so where the honest claim is narrower than its phrasing ([#111](https://github.com/trinity-ai-labs/orchestration-skills/issues/111)).
- `skills/execute/SKILL.md`'s Implementer section takes the same rule from the end that runs the check: diff against `git merge-base HEAD origin/<base>`, never your own last commit and never `HEAD`.
- A sweep that names its domain is stated as the well-formed exception, and `skills/write-issue/SKILL.md`'s `Verify` bullet takes a one-sentence pointer.

## 3.18.0

- A project may declare `"epicMerge": "squash"` in `<repo>/.agents/worktree.json`, collapsing an epic branch to one commit as it merges back into the integration branch it was cut from; the default is `merge`, and every unreadable or unrecognised value lands there ([#99](https://github.com/trinity-ai-labs/orchestration-skills/issues/99)).
- It reaches that one merge, tested by relationship rather than by branch name, and only where the PR's base is not the repository's default branch ([#107](https://github.com/trinity-ai-labs/orchestration-skills/issues/107)); the squash path withholds `--delete-branch` until `git diff --quiet <gated epic tip> <squash commit>` comes back empty.
- All three unconditional never-squash statements in `skills/execute/SKILL.md` and `README.md`'s three become conditional and point at *The epic branch* → *Mechanics*, and both ports compare the key, the value and the branch names case-sensitively.

## 3.17.1

- `setup-worktree` reads the branch back off the tree and refuses when it is not the one asked for, covering `--existing` too, on both ports ([#103](https://github.com/trinity-ai-labs/orchestration-skills/issues/103)).
- The refusal names both branches, the shared leaf, why `git worktree add` was skipped, and `git worktree list` as what shows which leaves are taken.
- *Mechanics* says a `READY:` line is not by itself evidence the branch was created, and `README.md`'s *with no error* claim is corrected.

## 3.17.0

- *Docs land at the end* gains a third carve-out split on a mechanical test: where a checker can tell a reference is stale without reading the sentence around it, the slice that broke it fixes it in its own PR ([#101](https://github.com/trinity-ai-labs/orchestration-skills/issues/101)).
- The boundary is stated as loudly — the sentence containing the path stays in the ledger, and repointing a coordinate is no licence to rewrite the paragraph around it.
- `skills/decompose/SKILL.md` Step 1 gains a greppable second falsification question, `Owns` carries three dispositions where it carried two, and five further sites point at the one copy of the argument.

## 3.16.1

- *Merge & cleanup* stops claiming a closing keyword is always inert here: the predicate is the PR's base against the repository's **default** branch, and `skills/orchestrate/SKILL.md` §7 and `skills/decompose/SKILL.md`'s *Cross-reference, don't auto-close* stop restating the false universal ([#94](https://github.com/trinity-ai-labs/orchestration-skills/issues/94), [#98](https://github.com/trinity-ai-labs/orchestration-skills/issues/98)).
- The dispatch block points at `skills/decompose/SKILL.md` Step 3's closing check, so a dispatcher writing its own brief is bound by it ([#97](https://github.com/trinity-ai-labs/orchestration-skills/issues/97)).
- `README.md`'s close-out bullet states the default-branch predicate in both directions, including the stray-keyword hazard.

## 3.16.0

- `skills/execute/SKILL.md`'s Rule 2 cuts an epic branch for multi-slice work, full stop — the *dispatched in parallel* qualifier is gone ([#95](https://github.com/trinity-ai-labs/orchestration-skills/issues/95)).
- Two of the rule's four costs are marked as zero for a sequentially-dispatched arc, and a fifth is added: in a project where shipped content must move a version, N slices merging into the integration branch is N releases for one arc.
- `skills/decompose/SKILL.md` gives up its four-cost summary and points at *Two rules reach for one*, and `README.md`'s epic-branch paragraph and `skills/write-issue/SKILL.md`'s epic-branch path drop the qualifier.

## 3.15.0

- The epic worktree re-runs the project's `install` unconditionally on every cadence tick, deferred only while a ticket is in flight, and *Mechanics* makes a module-resolution failure there a stale install until proven otherwise ([#89](https://github.com/trinity-ai-labs/orchestration-skills/issues/89)).
- `skills/decompose/SKILL.md` Step 3 gains a closing check reconciling three named pairs of a brief's fields — the fence against the verify bar, a content requirement against a style constraint, and any requirement against the vocabulary the target actually has ([#86](https://github.com/trinity-ai-labs/orchestration-skills/issues/86)).
- `skills/write-issue/SKILL.md`'s `Verify` bullet maps the same pairs onto an issue's own sections, and `README.md` and `skills/setup/SKILL.md` stop describing `install` as a create-time-only key.

## 3.14.3

- `skills/orchestrate/SKILL.md` §2 names grounding as the step a single-slice arc does not trim, and binds *Ground* to Step 1's `/pipeline:decompose` invocation ([#87](https://github.com/trinity-ai-labs/orchestration-skills/issues/87)).
- `skills/decompose/SKILL.md`'s `Brief` bullet calls a fact lifted from a dependency's documentation or generated output an input to grounding rather than a grounded coordinate.

## 3.14.2

- `skills/decompose/SKILL.md`'s `Verify` field names the executor: a whole-package or whole-suite check is the runner's to execute, and a bar naming the gate is fixing the ticket's **gate mode** rather than issuing a command ([#84](https://github.com/trinity-ai-labs/orchestration-skills/issues/84)).
- The single targeted test file is the one check the bar may state as a command line, and the cached-runner routing rule gains a clause saying it routes for whoever runs it.

## 3.14.1

- `skills/orchestrate/SKILL.md` §7 collapses *record* into *file*: a finding that clears the bar becomes an artifact with a number, pointing at §4's *"Filed" means filed* rider rather than stating a parallel disposition procedure.
- *None found* stays a sentence in the close-out with no artifact, and the finding bar itself does not move.

## 3.14.0

- `skills/orchestrate/SKILL.md` §4 opens with a new first question — can I reason out an answer myself, or do I genuinely need the user? — with three outcomes, settle, ask and file; the forced/adjacent test now decides placement only ([#81](https://github.com/trinity-ai-labs/orchestration-skills/issues/81)).
- The guard paragraph names both costs and says which way to lean when they conflict: toward settling.
- *Investigate before you disposition* is stated once in §4 as the gate on all of it, §6 gains the loop's second channel to the user, and `skills/decompose/SKILL.md` Step 2, `skills/review/SKILL.md` and `skills/write-issue/SKILL.md` point at §4 rather than carrying a second copy.

## 3.13.0

- The Step 0 line every implementer brief opens with names `pipeline:execute` rather than `pipeline:orchestrate`, corrected at three seats including the bare *Step 0 skills* form, and the fix carries a rule: a section named apart from the skill that holds it is a claim nothing can check ([#72](https://github.com/trinity-ai-labs/orchestration-skills/issues/72)).
- `skills/setup/SKILL.md` Step 4 verifies invariant 9's blocked-acquire announcement by enqueuing two tickets and starting a second drain while the first gates, reading the holder off that runner's output ([#71](https://github.com/trinity-ai-labs/orchestration-skills/issues/71)).
- `skills/orchestrate/SKILL.md` §2's divergence tick gains a rider — handles, never conclusions — and §9's heading becomes *What orchestrate does NOT do* ([#75](https://github.com/trinity-ai-labs/orchestration-skills/issues/75)).

## 3.12.1

- All four `.ps1` helpers set `$PSNativeCommandUseErrorActionPreference = $false` beside `$ErrorActionPreference = 'Stop'`, keeping the `$LASTEXITCODE` checks below reachable when a caller's session turns that switch on ([#77](https://github.com/trinity-ai-labs/orchestration-skills/issues/77)).
- Their comments state what the script sets rather than what PowerShell does, and `AGENTS.md` gains the general convention: a `.ps1` helper declares the session state it relies on rather than inheriting it.
- *The epic branch*'s close-out names the epic → integration PR as the one PR in the flow with no implementer behind it, and `README.md`'s *Where the review approval lives* gains the same exception ([#78](https://github.com/trinity-ai-labs/orchestration-skills/issues/78)).

## 3.12.0

- The main checkout holds the integration branch and nothing else: an epic branch gets its own worktree, cut with `setup-worktree.sh <epic-branch> <integration-branch>`, and the switch/push/switch-back ceremony is deleted.
- Three failure modes the new layout introduces get their own rules — the epic branch's leaf must be unique across the epic, the epic worktree is a merge point rather than a workspace, and a conflicted tick is resolved before you walk away from it.
- `merge-pr.sh` and `merge-pr.ps1` gain a third sync path that fast-forwards a base checked out in a linked worktree, with the divergence check hoisted to cover both off-base paths and the holding worktree re-resolved every round; *Mechanics*' claim that an epic branch's name is read by nothing splits into prefix and leaf.

## 3.11.0

- `skills/setup/references/gate-queue.md` invariant 9 gains the obligation on the other side of the flag: a runner that does not implement `--status` must reject the unrecognised flag and exit without claiming anything ([#73](https://github.com/trinity-ai-labs/orchestration-skills/issues/73)).
- `skills/execute/SKILL.md`'s drain rider gains a bullet separating *is the queue contended?* from *is this gate advancing?* — `--status` answers only the first, and movement is read off the gate's live children in the ticket's own worktree.
- `/pipeline:setup` gains its one presence trigger: Step 3 reconciles an existing queue against the reference and reports a per-invariant delta read from the code while rewriting nothing, and Step 4 exercises `drain --status`.

## 3.10.0

- `skills/setup/references/gate-queue.md` gains a ninth invariant, **Contention is announced**: on a failed slot acquire the runner prints who holds it, what that holder is gating and since when, and a read-only `--status` mode reports queue depth, in-flight claims and the slot holder while claiming and gating nothing.
- A refusal on a held slot is named and rejected, on the cross-session case and on invariant 4's PID-liveness window.
- `skills/execute/SKILL.md`'s concurrent-drain bullet keeps its safety guarantee and stops implying a second drain is useful: one drain per tick, and `drain --status` when the question is about state.

## 3.9.0

- `skills/decompose/SKILL.md` Step 1 gains the read-UP step — `gh api …/issues/<N>/parent`, falling back to the child's timeline disambiguated by the umbrella's own tracked checklist line — with `skills/orchestrate/SKILL.md` Step 1 pointing at it.
- `skills/write-issue/SKILL.md` Step 4's *Umbrella linking* becomes the authority: the checklist line and the body backlink are the two directions of one link, and only the backlink is readable from the child.
- The native `sub_issues` link is unhedged and *GitHub write mechanics* carries the exact call, its database-id trap, and why the id needs `-F` rather than `-f`.

## 3.8.0

- `skills/execute/SKILL.md` → *First: which role are you?* states that invoking `/pipeline:orchestrate` or `/pipeline:execute` answers the harness's "do not call the Agent tool unless the user requested it" guard, with the tell stated mechanically: a reading that makes the command the user just invoked inoperable is the wrong reading.
- What the invocation authorizes is bounded to exactly the sub-agents the pass declares it uses, with four short riders pointing back rather than a per-pass roster.
- `skills/review/SKILL.md` §1's outright ban is left untouched, and the canonical statement is worded so it cannot reach into it.

## 3.7.1

- `merge-pr` and `remove-worktree` refuse on either of two signals — the running script's own resolved directory, or the process's working directory, inside the tree about to be removed — on both ports, comparing physical paths anchored on the separator and excluding the main checkout.
- `merge-pr` reads the doomed tree from `git worktree list` rather than re-deriving a layout, and refuses rather than re-execing from a safe directory.
- `remove-worktree.sh`'s `die` uses the `printf '%b'` form, so its one multi-line message no longer prints `\n` verbatim.

## 3.7.0

- `skills/decompose/SKILL.md`'s `Do NOT touch` gains two mechanical rules: a fence covers behaviour and a directory glob does not imply the tests under it, and where a verify bar asserts something about a module the slice does not own, the fence says which way that module's tests go.
- The `Verify` field names the instrument alongside the property — the entry point the production caller actually reaches — and requires a consumer-side reversal beside the producer-side one.
- `skills/execute/SKILL.md` gains the implementer's half of a self-contradicting brief, and its PR review loop tells a dispatcher to read a shared dependency at the level production reaches it.

## 3.6.0

- `skills/orchestrate/SKILL.md` §7's close-out must answer in writing whether the arc surfaced a defect or gap in the pipeline itself, with *none found* valid and cheap and the bar staying an observed failure the finding can name.
- It is asked per arc, and `skills/execute/SKILL.md`'s close-out sequence carries a pointer so a directly-invoked dispatcher is bound too.

## 3.5.0

- Closing the issues the work resolved becomes a named fifth step in the helper paragraph, performed over REST rather than `gh issue close`, and `skills/orchestrate/SKILL.md` §7 gains the arc-level form.
- `skills/decompose/SKILL.md`'s `Brief` points at the source rather than at the dispatcher's conclusion about it, and `skills/execute/SKILL.md` states that following the code and reporting the contradiction is the job.
- A partial fix has to leave a countable residual — a named cast, a listed exception carrying its reason, or a ledger entry — never a widened type or a general suppression.

## 3.4.0

- A comment your change rewrites or relocates is a claim you are re-asserting: open the code it describes before rewording it, and treat a false claim as a finding to report and file rather than as a wording bug.
- The divergence check now says lines-changed carries no signal about magnitude in a repo whose unit of change is a paragraph.

## 3.3.0

- Parked work goes under an agent's own named ref — `git stash create` plus `git update-ref refs/pipeline-stash/<branch-leaf>/<epoch>`, restored with `git stash apply --index` — with the shared stack kept as the fallback.
- `refs/worktree/*` is named and rejected: a sibling's per-worktree refs sit outside the invoking worktree's root set, so a gc there deletes the object.
- Two `git stash create` caveats are stated — no untracked capture, `-u` silently ignored, and `git stash pop` refusing a named ref — and the dispatcher's tick sweeps both namespaces.

## 3.2.0

- The argument-less `git stash pop` is banned outright, with every `pop`, `apply` and `drop` carrying an explicit ref re-matched one command earlier.
- The ban is restated at the two places an agent reaches for a stash: holding a slice uncommitted for the review pass, and resolving a merge conflict.

## 3.1.0

- `skills/decompose/SKILL.md` gains a `Derives` field for artifacts whose correct contents are a function of the whole tree, and `skills/orchestrate/SKILL.md`'s reconcile checklist gains a sixth item that re-derives the tree's own derived state.
- `Owns` may not carry an unevaluated predicate; the falsification question widens past docs to enforcement artifacts with *find every declaration, not the first*; docs inside an epic become falsification-ledger entries consumed by one closing docs slice; and scaffolding is planned together with its teardown.
- The `Verify` bar requires a named fail-before reversal, the model-tier list gains a better predictor — does the slice touch something declared or enforced in more than one place? — and the gate-cost sizing gains the epic case where diff-review capacity is the bound.

## 3.0.1

- `skills/orchestrate/SKILL.md` §2 states the divergence tick's load-bearing minimum itself — poll every ~10 minutes, completion notifications are not the mechanism — keeps the pointer for the detail, and names the `ScheduleWakeup` rationalization.
- §2's per-minute cadence is corrected to `skills/execute/SKILL.md`'s ~10 minutes.

## 3.0.0

- **Breaking: `/pipeline:execute` and `/pipeline:orchestrate` exchange meanings.** The arc loop is now `/pipeline:orchestrate`; the per-increment worktree playbook it drives each cycle is now `/pipeline:execute`.
- The public surface is two commands, `/pipeline:write-issue` → `/pipeline:orchestrate`, and `decompose`, `execute` and `review` describe themselves as reached from the loop rather than as places an arc starts.
- The increment coordinator's role word becomes `DISPATCHER` at all 94 occurrences.

## 2.3.0

- Arming the divergence tick becomes part of dispatching: `skills/execute/SKILL.md`'s step 2 is not finished until the timer is set.
- An alarm is confirmed against the fork point before anyone reaches for `TaskStop`, whatever channel it arrived on, and the gate drain is sized to the fan-out and never stands in for the divergence check.
- The reconcile checklist grows a fifth item for deferred decisions, and `AGENTS.md`'s hand-back rule gains the authorized-merge path a maintainer's "ship it" opens.

## 2.2.1

- An epic branch's name carries no mechanical meaning while `transient-red/<epic-slug>`'s spelling is the contract, and the two are stated together where the branch is cut.
- A detector never keys on a branch-name prefix; it answers with a dedicated ref of its own.
- `skills/decompose/SKILL.md`'s breakdown header takes the real epic branch name rather than a `feat/<epic-leaf>` template.

## 2.2.0

- Opening the transient-red window is a step: an epic branch cut under Rule 1's primary trigger gets `transient-red/<epic-slug>` cut and pushed beside it, and deleted with the epic branch at close-out.
- Two near-miss keys are named and rejected — the epic branch itself, and `integration/*`.
- Once per epic, the detector is confirmed to fire from inside the first slice's worktree before the first slice is dispatched.

## 2.1.0

- `skills/write-issue/SKILL.md` grounds to establish that the plan is true rather than to produce a to-do list: ground with `file:line`, write down the module and the file.
- `Targets` becomes `Surface` — where the work lands and what it touches, no line numbers and nothing phrased as a sequence — and the KEEP/STRIP list, frontmatter description, follow-up section and hard boundaries move with it.
- `skills/execute/SKILL.md`'s reconcile item 1 stops claiming the post-horizon list names no coordinates and adds *short is not empty*, and `README.md`'s `write-issue` row names the sections a body carries.

## 2.0.1

- `docsBranchPrefix` is removed from `skills/decompose/SKILL.md`'s title/branch-name bullet and per-project-config list and from `skills/orchestrate/SKILL.md`'s per-project-specifics sentence.
- A docs-only slice is flagged for the ticket-scoped `--mode docs` gate instead.

## 2.0.0

- **Breaking: the pipeline is two commands, `/pipeline:write-issue` → `/pipeline:execute`**, and the arc-level trigger vocabulary moves to the new `execute` skill.
- Grounding splits at a horizon: slice depth inside it — owned files, do-not-touch boundaries, depends-on, framework skill, model tier, brief, verify bar — and shape depth outside it, with reaching the horizon the only thing that promotes an item.
- A four-item reconcile checklist runs against the merged tree and is written down even when empty, fold-vs-file is decided by *can the arc land without this?*, a folded item's placement is decided by merge surface first, and a slice renaming an identifier that crosses a string boundary carries a bare-string sweep in its verify bar.

## 1.18.0

- Agents stash with `git stash push -m "pipeline-stash/<branch-leaf>/<epoch>: <purpose>"` and re-match the marker immediately before every pop, apply or drop, treating zero or two-plus matches as a stop-and-report.
- `git stash clear` and dropping an entry you did not create are banned, a WIP commit on your own branch is preferred, and the orchestrator's tick gains the matching sweep.
- An agent owns its follow-ups: each becomes a real issue via `/pipeline:write-issue`, linked, decomposed if it is more than one slice and folded into the orchestration, inheriting the arc's branch level — and the stuck-hand-back and missing-input paragraphs gain the mechanical test, if you can still act on it, it is not a blocker.

## 1.17.0

- `skills/write-issue/SKILL.md` asks by name for the two facts `decompose` needs — whether the branch is shippable at each phase boundary, and the producer → consumer seams the plan creates — and is forbidden to write "use an epic branch" into an issue body.
- An umbrella is a tracking shape and an epic branch is a branch lifecycle; both skills state that a skill's decision procedure never overrides a stated instruction, and `decompose` must reconcile the epic-branch answer against the seam map it just emitted.
- The epic-branch trigger gains a second rule: multi-slice work dispatched in parallel defaults to an epic branch, keyed on fan-out across one change rather than on a threshold.

## 1.16.0

- `/pipeline:review` ships: one agent reading its own uncommitted diff for reuse, simplification, efficiency, altitude and correctness in one ordered pass, spawning nothing, committing nothing and pushing nothing.
- Verification is the project's own `scopedCheck`, read from `.agents/worktree.json`, plus at most a single targeted test file.
- The standing rule that an implementer waiting on review agents is self-suspended inverts into an alarm that sends the orchestrator to look at the worktree.

## 1.15.0

- `skills/decompose/SKILL.md`'s frontmatter description leads with ground/validate/slice, names validating the plan against what the code does as a deliverable in its own right, and gains a fourth trigger for work that is plainly one slice.
- The body is deliberately untouched, and two restating clauses come out to pay for the additions.

## 1.14.0

- The integration gate becomes conditional on `git diff --name-only <merge>^2 <merge>` after each merge: non-empty means the merge produced content no gate has seen and gets one run, empty means the pre-merge gate already ran that tree.
- An empty answer proves the tree was run and not that the run was green, and it governs re-running the suite only — merged code is still read by hand wherever two or more slices touched one structure.
- The integration branch is merged into the epic one final time before the close-out gate, giving the mandatory per-tick merge a second reason to exist.

## 1.13.0

- `merge-pr` syncs the PR's base by ref — `git -C <main> fetch origin` then `git -C <main> branch -f <base> origin/<base>` — whenever the base is not the checked-out branch, only ever forward; a diverged local base is refused with the reconcile command, and a base held by a linked worktree is reported by path.
- The helper records the main checkout's branch and HEAD before it touches anything, re-checks the branch before every advance inside the retry loop, and exits non-zero naming what moved.
- Both ports carry the same two paths, messages and exit codes, and the skill's claim that the helper parks the checkout on the base is corrected.

## 1.12.0

- The **epic branch** ships: a convergence branch cut from the integration branch that a multi-slice epic's slices fork from and PR into, gated as a whole, then merged back in one ordinary PR — and the transient red and the gate-the-integrated-whole rule move onto it.
- The trigger is one question — does any intermediate state leave the integration branch in a condition you would not ship? — with slice count and a busy integration branch marked contributing but never sufficient.
- `decompose` answers the epic-branch question in every breakdown and `orchestrate` holds the lifecycle, with the mandatory `integration → epic` merge riding the existing tick; no helper changes were needed.

## 1.11.0

- `merge-pr` preflights GitHub's mergeability before touching anything: `CONFLICTING` stops non-zero with the worktree intact and the PR still a draft, and `UNKNOWN` polls a few times before falling through.
- It restores the draft flag when the merge fails anyway, and only where this run is what set it.
- `setup-worktree --existing <branch>` attaches a worktree to a branch that already exists — taking no base, and never inferred — and both modes print `HEAD: <sha>` beside `READY: <path>`.

## 1.10.0

- `decompose` emits a second map beside the file-based conflict map — producer → consumer → the shape between them — calling out the two seams a file map structurally cannot see.
- `orchestrate` diffs both halves of a flagged contract seam against each other before merging either.
- The stuck-hand-back rule gains the missing-input case, and documentation of a changing model becomes a sequencing constraint with its own stated exemption.

## 1.9.5

- `orchestrate`'s no-suppressions rule gains the documented-exception carve-out: a suppression you add is permitted only when all four conditions hold — narrowest scope the tool allows, a written justification through the tool's own mechanism, that justification saying why the flagged construct is correct there, and a call-out in the hand-back report.
- The conditions test a suppression you introduce and never one you inherited, and the carve-out is defined once in the Implementer section with the Hard rules copy pointing at it.
- `AGENTS.md` states this repo's own position and names the shipped `PSAvoidUsingInvokeExpression` suppression as load-bearing and not precedent.

## 1.9.4

- 1.9.3's Troubleshooting *Cause 1* is retracted and rewritten to the real mechanism: the GitHub `owner/repo` shorthand source clones over SSH by default, and `trinity-ai-labs/claude-plugins` now declares all three plugins via an explicit `url` source.
- The `insteadOf` diagnosis and its `git config` fix commands are deleted rather than kept as a possible other cause, and `README.md` gains a note for plugin authors preferring an explicit `url` source.

## 1.9.3

- `README.md` gains a Troubleshooting section keyed by error text for the three git errors that can block a Windows install.
- Five stale mentions of which CI job lints `bin/*.ps1` now name the `check` job on `ubuntu-latest`.

## 1.9.2

- The four `bin/` helpers ship in PowerShell as well as bash on the same frozen contract, and `WORKTREE_HOME` defaults to `%LOCALAPPDATA%\wt` on Windows in both shells.
- `scripts/check.sh` enforces the parity mechanically — every `bin/<name>.sh` has a `.ps1` sibling and vice versa, agreeing on the runtime usage line and the contract environment variables, with every `.ps1` printable ASCII terminated by LF — and PSScriptAnalyzer reports `SKIP` rather than `ok` when `pwsh` is absent.
- CI gains a `windows-latest` job running the helpers end to end in Git Bash and Windows PowerShell 5.1, and `README.md`, `orchestrate` and `setup` take the real support matrix and the shell-selection rule.

## 1.9.1

- Each bash helper carries a `norm_path()` and routes every value later compared, grepped or prefix-matched through it at the point of production.
- `setup-worktree.sh`'s idempotency guard compares normalized paths from `git worktree list --porcelain` for exact equality, `setup-workspace.sh`'s manifest walk loops to a fixed point, `remove-worktree.sh` accepts `[A-Za-z]:[\\/]` as absolute and gains a `Get-CimInstance` / `taskkill` process scan, and both JSON readers pick an interpreter by running it.
- `setup-worktree.sh` reports an env file copied instead of symlinked, `WORKTREE_HOME` defaults to `%LOCALAPPDATA%/wt` on Windows, and the docs qualify `~/.worktrees` and `~/.zshenv` per platform.

## 1.9.0

- `.gitattributes` pins `bin/*.sh` and `bin/*.ps1` to LF.
- `bin/merge-pr.sh` resolves `remove-worktree.sh` as a sibling via `HERE` rather than under `$WORKTREE_HOME`, and its wrong-repo guard recognises both worktree layouts.
- `AGENTS.md` now exists, carrying this repo's conventions out of `.agents/worktree.json`'s `briefConventions` field verbatim, plus two new sections: the frozen helper contract and the `bin/` parity rule.

## 1.8.2

- `setup`'s bootstrap exception is narrowed: a bare worktree is only fatal where the project has an install step, so a zero-dependency repo lands its config through a normal PR.
- This repo gains `.agents/worktree.json`, declaring no `install` and no `envFiles`, with `gate` and `scopedCheck` the same command and no queue.
- There is one gate, `scripts/check.sh`, which CI runs; `.agents/` and `scripts/` are exempt from the version-bump guard, and two stale statements about this repo in `setup` and `orchestrate` are corrected.

## 1.8.1

- The `orchestration-skills`-repo exemption from worktree/PR ceremony is withdrawn: this repo, `market-skills` and `framework-skills` are PR-only, docs and CHANGELOG included, stated as its own hard-rules bullet.

## 1.8.0

- Docs become a slice's responsibility at three seats: `decompose` names the docs each slice falsifies in its `Owns` list, `orchestrate` carries the docs rule as a fifth paste-verbatim brief item, and the implementer's hand-back reports a per-doc verdict.
- The rule that makes it work is to search by the behaviour and never by the vocabulary the change introduces: ask what a reader currently believes, then read the candidate docs rather than grepping them.
- Scoping a doc out has to be recorded as an explicit not-affected-because, which is what lets an implementer overturn it when the diff disagrees.

## 1.7.1

- `decompose`'s three `gh api` write examples use `-F body=@<file>` rather than `-f`, carrying the reason and a verify-after refetch, and CI fails a skill that prescribes `-f` with an `@file` value.
- The gate queue root moves to `~/.gate-queue/<project>/` while the slot stays in the OS temp dir, with the reference stating why.
- A retention invariant bounds `done/` keyed on delivery rather than age, the failing tail is scoped to a red verdict, and the queue layout diagram shows `done/` as `<name>.json.<runnerPid>`.

## 1.6.0

- `draft → ready` means an orchestrator read this diff and is merging it, and `bin/merge-pr.sh` performs the flip one line above `gh pr merge`.
- The gate comments its verdict in both directions and never touches the draft flag, so a PR is gated iff it carries a gate comment.
- Override gate mode keeps who runs the gate and loses who says the diff was read; 1.5.0's delivery rule is revised to *a verdict is delivered exactly when its comment lands*.

## 1.5.1

- The marketplace catalogue moves to [`trinity-ai-labs/claude-plugins`](https://github.com/trinity-ai-labs/claude-plugins), which ships no plugin of its own; the marketplace name is unchanged, so only the `marketplace add` line moves.

## 1.5.0

- A gate verdict is recorded on the ticket — outcome, exit code, failing tail, the gated SHA and whether delivery succeeded — before it is reported, so `done/` is a ledger.
- Drain reconciles before it claims, re-posting decided-but-undelivered verdicts without re-gating, refusing a re-post once the PR's head has moved off the gated SHA, and capping retries.
- `orchestrate` gains the reading for a draft PR with no gate comment as a third state, neither green nor red.

## 1.4.0

- `setup` onboards a polyrepo workspace and treats the workspace manifest as a derived artifact regenerated by running setup at the root rather than something to track.
- Each field is pinned to a tracked source, and inferring a contract from resemblance is forbidden outright.

## 1.3.0

- A cross-repo contract declares its `owner` and `consumers`, and a task that includes the owner automatically includes them; excluding a consumer while the owner is in the task is refused outright.
- `--dry-run` prints the resolved member set without cutting anything.

## 1.2.0

- Polyrepo workspaces: a containing folder of sibling repos declares `.agents/workspace.json`, and `setup-workspace.sh <branch> [repo…]` cuts one worktree per member into `~/.worktrees/<workspace>/<leaf>/<repo>`, with members selectable by name, by `--exclude`, or by a manifest `"default": false`.
- Worktrees for a repo inside a workspace are namespaced under it.
- Fixed: `setup-worktree.sh` created its directory from the old flat path, leaving stray empty dirs when the real destination was elsewhere.

## 1.1.0

- The marketplace carries a second plugin, [`frameworks`](https://github.com/trinity-ai-labs/framework-skills) — the Effect v3 and SolidJS reference skills.
- `orchestrate` and `decompose` name those skills by their namespaced ids (`frameworks:effect-v3`, `frameworks:solid`).

## 1.0.1

- Marketplace install documented as the primary path, with the skills-directory clone demoted to a development convenience.
- `CHANGELOG.md`, plus a CI job that fails when plugin content changes without a version bump.

## 1.0.0

- First release as a Claude Code plugin: four skills — `setup`, `write-issue`, `decompose`, `orchestrate` — namespaced `/pipeline:*`.
- `bin/` on PATH: `setup-worktree.sh`, `merge-pr.sh` and `remove-worktree.sh` are bare commands while the plugin is enabled, replacing the old `install.sh` symlink dance.
- Per-project config moves into each repo at `.agents/worktree.json`, declarative rather than sourced bash, with tiering from no flow at all through worktrees plus a single check to the full gate-and-queue.

