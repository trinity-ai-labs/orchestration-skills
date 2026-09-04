# Reconciling — the checklist, the disposition, and where a fold goes

Reference for `skills/orchestrate/SKILL.md`. **Steps 3 and 4 of the loop are performed out of this file**: the checklist runs against the **merged** tree, then everything it produced goes through *Fold vs. file* and *Where folded work goes*, and *Rewriting the plan* says where the result is written.

## The reconcile checklist

Run all of them, every cycle, in this order. **Stated mechanically on purpose, so it is not a fresh judgement each time**: a cycle that skips a re-derived step produces exactly the output of one that found nothing.

**1. Coordinate drift.** Every path, symbol, table, route or key named in the remaining plan: does it still resolve against the merged tree? Check them; do not recall them. **A target that does not resolve is stale by definition, not a maybe**, and shape depth keeps the list short but **short is not empty**.

**2. Vocabulary drift — checked per SENSE, not per string.** For each rename the increment performed, write down the *senses* the old word carried and decide each separately: **a string match cannot tell two senses apart**, so a find-and-replace rewrites the surviving one and the next brief renames what was already correct.

**3. Revealed forced work.** What does the merged tree now force that **no remaining item owns**? A helper taking a type this arc deletes is forced work the compiler hands to whichever slice hits it first, and **a merged change to `.agents/worktree.json` is the same question with the compiler taken out of it** — provisioning forced *silently*, every gate green while worktrees are still cut from the pre-change file. That window closes only when the change reaches the **main checkout's working tree**, which holds the integration branch — so on an epic it is the epic → integration close-out, not the slice merge inside it, and every worktree cut before then is hand-patched.

**4. Falsified assumptions.** `/pipeline:decompose` writes `Assumes X (existing pattern in <file>); flag if wrong` into briefs; re-check every one still live against the merged tree, since **a falsified assumption is a plan defect fixed here, not an implementer's problem**.

**5. Deferred decisions — a deferral has no owner, so it renews itself in silence.** List every question the increment deliberately left open and re-ask each at the **new** horizon; **a deferral is neither an assumption nor a stale coordinate, so the items above cannot catch it**. The test is **does the merged tree still hold together with it open?** — where it does not it is forced work and gets a slice, and where it does, record that you re-asked.

**6. Derived state — every item above interrogates the PLAN; this one interrogates the TREE.** Every artifact whose correct contents are a function of the whole tree rather than one slice's files — a ratchet ledger, a regenerated backlog, a generated type, an unimported-exports manifest — gets **re-derived against the merged tip and compared with what is committed there**, by running the project's regenerator rather than reading the file and reasoning about it; a slice declares one in its `Derives` field.

**7. Scope drift — the items above read the PLAN and the TREE; this one the REQUEST, written in neither.** Compare **the arc's goal in the filer's own words**, quoted rather than recalled, against **what the remaining plan would deliver** if every item landed as written; it fires when the second cannot be stated as an instance of the first. **A fire binds the AGGREGATE, re-opens nothing, and HALTS rather than asking** — *Fold vs. file*'s verdicts stand, so report what the plan has become against what was asked and stop, because re-scoping is the user's.

**8. Follow-ups filed out of this arc — and this one reads the TRACKER, where a finding can sit looking handled.** Every issue filed **out of** this arc — the loop's own filings under *Fold vs. file*, and those its dispatchers and implementers filed under the same follow-up-ownership rule — goes back through *Fold vs. file* whenever its `Follows #<N>` or `Part of #<umbrella>` names a live arc. **Who filed it does not narrow this**, and **filing is how a finding is tracked, not how it is disposed of**: the tree may since have answered it.

**9. The seam map — this one reads the artifact the loop itself CARRIES between cycles.** Take the arc's contract-seam map, which *Rewriting the plan* keeps in the umbrella body, and ask of every seam what the increment did: **closed** it by landing both halves — strike it and say so, since a row that stops appearing is unreadable afterwards; **moved one half without the other**, a live break and forced work under *Revealed forced work*; or **opened** a new one. Then re-read the whole union with this cycle's seams added, not only the rows this increment touched. A seam row is *producer → consumer → the shape between them → what the consumer does with it*, and it is finished only once that last part is answered.

**10. What the increment's own agents said — the only item that reads a REPORT rather than an artifact.** Every item above interrogates the plan, the tree, the request, the tracker or the seam map, all of which outlive the run. The hand-backs do not: **an implementer's context dies with the implementer**, and the hand-back is the whole of what survives it. Read each one for the ambiguities it flagged, the follow-ups it filed, its per-doc verdicts — and above all **the review pass's `Rejected` list, which is by construction a list of things somebody noticed and chose not to do.** That list is routed up to the dispatcher deliberately and is consumed nowhere; item 8 cannot catch it, because a rejected finding was never filed. **Read the merged diffs beside it**: a straggler that looked proportionate inside one slice is often only visible once the slices are stacked, which is this seat's advantage and no implementer's.

**Write the outcome down even when it is empty** — a cycle that found nothing and a cycle where nobody ran the checklist produce identical plans. Each item then goes through *Fold vs. file*, which opens by establishing *why the thing is the way it is*: everything above produces findings, none of it explanations.

## Fold vs. file

**Establish why a thing is the way it is before you disposition it — this gates everything below.** Trace what looks wrong to what made it that way: the constraint it satisfies, the consumer it exists for, the commit that put it there. **If it has a valid reason and is idiomatic for its context, leave it and record that you checked**; only then fix, raise or file.

**One class of finding arrives with that tracing already known to be shallow — an issue carrying `Filed from behind a fence`.** Its premises were established by **reading** rather than by changing, its filer fenced out of the file. **Treat each claim as an unverified premise — re-ground it before it becomes a slice, and never inherit one as a premise for something else.** **The marker is a claim to check, not one to doubt.**

**Then the first question is not where the item goes — it is whether it is yours to settle at all.**

- **I can reason out an answer myself → settle it.** **This is the default, and most findings land here** — an existing pattern, a convention `AGENTS.md` states, a plainly obvious default. Write the answer and what it rests on into the cycle's record. **Settling means answering the question, not writing the code**; where it implies work, the placement test places that.
- **It genuinely needs the user → ask, with the reasoning already done** — a product or design decision the code and conventions cannot settle, the only class that reaches the user as a question, at the bar `skills/orchestrate/SKILL.md`'s *The decide-don't-ask bar* sets.
- **The scope is genuinely an arc in its own right → file it, and say it is worth talking through first.** **If this arc also cannot land without it, filing does not make it shippable** — report that as the plan defect it is.

**Only what survives reaches the placement test, where the original question decides: can the arc land without it?**

- **Forced** — the arc cannot compile, pass, or ship without it. **Fold it in** as a *named slice with its own wave*, sized and placed like any other.
- **Adjacent** — real work, worth doing, but the arc is correct without it **and it is genuinely an arc in its own right**. **File it and link it**, per `/pipeline:write-issue`, and track it as its own arc; never fold it. ⚠️ **This is the narrow verdict, not the convenient one.** *Adjacent* costs a whole unit of work — a worktree, a PR, a gate — where folding costs an edit, so the bar is that the item is genuinely too large or too unsettled to carry, not merely separable. **Say what you filed and why in the cycle's report**, since filing is the one disposition that leaves the loop's hands.

Run it in the arc's direction — "can it ship without this?" — never the item's: **filing something actually forced ships an arc that does not build.**

**An *Adjacent* verdict says the item gets filed; it does not say it needs a NEW number.** Before the create call, search what is already filed — keyed on the failure **shape** rather than the item's words, and over closed issues as well as open (`--state all`). An open issue already carrying the failure takes the observation as a comment; a closed one makes the item a **regression** only where the fix that closed it is present in the copy the failure was observed in — absent, it is version skew and nothing is filed, and where neither is established the item says so rather than picking.

**A verdict is final for the item; the sum is what gets re-examined** — the checklist's *Scope drift* binds the **aggregate** only, and its *Follow-ups filed out of this arc* re-asks the per-item question against a moved tree, so *Adjacent* is this cycle's disposition rather than a discharge.

**Three costs sit under this. The third is the one that decides most items and it runs the other way**: a filed item becomes **its own task, with its own worktree, its own PR and its own full gate**. Inside the arc that work is marginal — the tree is open, the context is loaded, the gate is running anyway. Outside it, it is a whole unit of work, and the gate is a real serialized cost this loop already sizes waves against. The other two are that an arc absorbing everything never terminates, and that **filing moves the reasoning from the run with the tree open to a human without it**, a channel the close-out's pipeline-finding question also feeds.

**And folding is not absorbing without scrutiny — it is routing INTO scrutiny.** A folded item becomes an item in the remaining plan, so the next cycle grounds it through `/pipeline:decompose`, whose own job is to validate the plan, fill what it can and escalate what it cannot. Filing removes it from that entirely: the conversation that would have happened at the next grounding never happens, and the item resurfaces later against a cold tree. So **fold is the default**, and the non-termination worry is answered by the fact that absorbed work still has to survive grounding, which can hand it back out.

**When they conflict, lean toward settling**, since non-termination is visible from inside the loop and backlog transfer is not; **settling is not absorbing**, producing a *decision* where folding produces a *slice*. **Whatever you file or ask carries the reasoning and a recommendation, not a fork.**

**A filed item leaves the loop's hands only by being handed to a person — the decide-don't-ask bar reached through the issue channel rather than the chat one, not a second class beside it.** That class has four shapes: a design decision the arc never discussed; a frozen-contract change, or anything else needing re-agreement first; an irreversible or destructive change; and work whose scope is the user's to size. **Everything outside them the loop carries, for as long as it runs**, and an item still *Adjacent* when the plan empties simply leaves as its own tracked arc — so the close-out says which of the two states, **handed over** or **left as its own arc**, a surviving follow-up is in.

Two riders:

- **"Filed" means filed — and *linked* is one act or two.** **The relation decides which: `Part of #<umbrella>` is containment and takes the body backlink AND the native `sub_issues` POST, while a bare `Follows #<N>` on a plain issue is provenance and takes the backlink alone.** The follow-up-ownership rule binds this loop as it binds an implementer — **a bullet in a report is not a follow-up** — and **the two-link case is this loop's default**. The native call is `skills/glossary/mechanics/sub-issue-link.md`.
- **A fold is a new slice, never a widening of a live one**, since growing a dispatched slice's scope mid-flight is indistinguishable from the divergence the dispatcher polls for.
- **That rule is about SCOPE, and reading it as *a live brief cannot be touched* is how a one-line correction turns into a killed agent.** A live slice whose brief states a wrong **fact** — a number, a path, a name — has not grown and is not diverging; it is working correctly to a premise that is wrong, and the answer is a message to the agent carrying the corrected value. Reserve the stop for the case this rule actually describes, where the scope itself has moved.

## Where folded work goes — merge surface outranks slice cohesion

One ordered criterion, ordered rather than balanced: **merge surface first, slice cohesion only as a tiebreaker between placements with the same merge surface.** Cohesion putting an item with the live slice that owns its module loses to a merge surface forty files wide.

**Churn discovered mid-arc goes in a serial wave — one slice, nothing else in flight.** Parallel slices fork from different bases, so a large-footprint change beside them merges textually clean and semantically wrong; and where the shared shape is a **runtime string** — a query key, a table name, a route, a config key — it does not fail to compile at all, splitting one cache entry into two while every gate stays green.

**Nothing folded ever joins a wave already dispatched, whatever its size** — those slices forked before the folded item existed, so their do-not-touch boundaries cannot name it. A small fold is fine in the *next* wave, never the live one.

## Rewriting the plan

**The umbrella (`skills/glossary/vocabulary/umbrella.md`) issue body carries the live remaining plan, rewritten every cycle** — state, not history, at the depth `skills/orchestrate/SKILL.md`'s *Two grounding depths* assigns, and `/pipeline:write-issue`'s forward-facing rule applies to every rewrite. **One comment per completed increment records what landed and what it invalidated**: comments the history, the body the state.

**The body carries one more piece of arc state, and the loop is the only pass positioned to hold it: the arc's contract-seam map, a running union rather than a per-cycle re-derivation.** Seed it from the issue body's `Seams` field, grow it with each cycle's decomposition, keep it in the **body** beside the plan, never assembled from the comment thread; a closed seam leaves it and *The seam map* records why.

Read the issue with `gh issue view <N> --comments`; write the rewritten body and each increment comment through the `gh api` REST endpoints, passing a body read from a file with `--field`, never `--raw-field` — only `--field` expands a leading `@` into the file's contents, and the raw form stores the path and **exits 0 with a comment URL**.

**In-chat, with no issue,** the plan and the seam map are **restated in full each cycle** rather than referred back to; past roughly two increments, file an umbrella.
