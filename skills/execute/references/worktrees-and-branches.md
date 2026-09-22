# Worktree creation (both roles depend on this being done right)

Reference for `skills/execute/SKILL.md`. **Read it before you create a worktree, and before you accept one you
were handed** — both roles depend on this being done right, and every failure it names is silent.

**The helper's own contract is `skills/procedures/worktree-helper.md`** — its arguments, the `--existing`
recovery form, what a run creates, the two lines it prints, what it refuses, and which copy of a project's
config it reads. Read it once; this file carries what a dispatch owes on top of it.

**⛔ HARD BAN — any harness parameter or auto-provisioner that makes the worktree FOR you is FORBIDDEN. Never
use it.** It puts the tree somewhere invariant 1 below rejects, and reseeds it at a STALE base far behind the
integration tip, so agents burn cycles re-basing or stale code leaks in silently. There is exactly ONE way to
make a worktree: the helper, then **verify HEAD yourself**, THEN dispatch a plain agent — no provisioner
parameter — pointed at that worktree path. `skills/procedures/host-tools.md` names that parameter on each
host.

⚠️ **A slice that CHANGES a project's config cannot exercise its own change, because the helper reads the MAIN
checkout's working copy** (`skills/procedures/worktree-helper.md` carries why, and why the two routes round it
do not work). **The remedy reaches one tree; the rest of the arc's trees are the DISPATCHER's, and applying
the change by hand in them is a standing obligation beside invariant 2 below.** *Apply the effect by hand in
your worktree* and *say so in your hand-back* are written to the implementer, and they are right for the tree
that implementer is standing in — which is the only tree they can reach. Every later worktree of the arc is
cut by **you**, after that slice merged, out of a main checkout that still does not carry the change. So while
an arc has an unmerged change to this config: **apply that change's effect by hand in every worktree you cut
for the rest of the arc, and say so in the brief you dispatch into it.** The saying-so is not a courtesy — the
implementer receiving that tree cannot tell a hand-symlinked env file from a helper-symlinked one, and has no
reason to look.

**The four invariants** (the helper covers 1, 3, 4 outright and part of 2 — the rest of step 2 is always on
you):
1. The worktree lives under `$WORKTREE_HOME/<project>/`, **never** under `.claude/worktrees`.
2. **Verify its HEAD == the base tip BEFORE dispatching any agent** — compare the `HEAD: <sha>` line the
   helper just printed against `git rev-parse origin/<base>` (e.g. `origin/release/x.x.x`), or re-read it
   yourself with `git -C <worktree> rev-parse HEAD`. **The helper makes a comparison of its own here, and it
   is a WEAKER one in both what it compares and what it compares against
   (`skills/procedures/worktree-helper.md`) — so this check is still owed on every dispatch**, and a tree in
   either state that comparison lets through prints an entirely ordinary `READY:`/`HEAD:` pair. A mismatch
   means STOP and fix the base; do not dispatch. Read the sha, never the `READY: … off <base>` text: that says
   what was *asked for*, and this invariant exists for the case where what you got is something else. (A
   re-attached `--existing` tree's commit is covered by this comparison and by nothing else.)

   ⚠️ **`origin/<base>` is a local cache, so FETCH FIRST — in the repository being verified — and the fetch is
   part of this check rather than preparation for it.** A remote-tracking ref is what the remote looked like
   at *that clone's* last fetch, and reading one contacts nothing; so in a checkout that has not fetched, the
   local base and `origin/<base>` hold the same commit for the same reason, the comparison above is true, and
   the invariant returns **PASS in exactly the case it exists to fail**. Run `git -C <repo> fetch origin`
   immediately before you compare, and run it in the repo you are verifying — a fetch in some *other*
   repository you touched earlier in the session moves nothing here. **Then name the freshness, not only the
   equality:** after the fetch, `git -C <repo> rev-list --count <base>..origin/<base>` answers *how far behind
   is the base I just forked from*, which is the question this invariant is actually asking, and anything but
   `0` is the same STOP. Equality cannot answer it, because it compares two refs that go stale together; the
   count is checkable where equality is not. **The fetch is a step rather than an assumption because the rule
   reads as though it had already gone to the remote** — *compare against `origin/<base>`* names one, and
   nothing in that phrase says the cache behind it is cold. **And the cost does not stop at the dispatch**:
   the same unfetched checkout is then read for facts about the project, where a stale working copy is
   indistinguishable from a current one.
3. Env files are symlinked into the worktree (they aren't carried over automatically).
4. Deps are installed (worktrees don't share `node_modules`, and the gate can't run without them).


---

## The epic branch


Reference for `skills/execute/SKILL.md`. **Read it when the arc is more than one slice** — when to cut it,
what it costs, where the docs go, the mechanics.

`skills/glossary/vocabulary/epic-branch.md` defines an **epic branch**. Single-slice work never cuts one, and
the rest of the playbook reads the same when there isn't one.

## Two rules reach for one

Either fires on its own, and Rule 2 fires on every arc of more than one slice, so an arc of one slice is the
only one that cuts nothing and merges straight into the integration branch.
**And where the user has stated which it is FOR THIS ARC, neither runs** — "do it as an epic" settles the
branch: read this file for the **mechanics**, cut it, point the slices at it; "merge each slice as it lands"
settles it the other way. A skill's decision procedure never overrides a stated instruction, and the
instruction covers the arc it was given for: the next arc starts from these two rules again unless the user
says otherwise for it.

**Rule 1 — the shippability trigger.** *Does any intermediate state leave the integration branch in a
condition you would not ship?* If yes, cut one, at any width from two slices up.

- **Primary — the epic is only correct as a whole.** A foundational change every consumer must follow: a
  NOT-NULL schema swap, a required interface field, a renamed module. Every state from the foundation landing
  to the last consumer migrating is unshippable — the shape *Transient-red window* describes, and this branch
  keeps that window off the shared branch. Still weigh it — consumers all landing the same afternoon may not
  be worth the branch.
- **Secondary — a contract seam.** `ground` emits a producer → consumer map; two halves of one contract
  landing separately leaves the branch wrong in between.

**Answer Rule 1 on every multi-slice arc anyway, because it decides which kind of branch you hold.** "Yes"
makes the epic **knowingly red** until its last consumer migrates, which opens the `transient-red/<epic-slug>`
window (*Mechanics*). "No" leaves a branch that is isolation and nothing else, strictly gated throughout, with
no window and no marker ref.

**Rule 2 — the multi-slice default. An arc of more than one slice cuts an epic branch by default**, whether or
not every intermediate state would ship — unrelated fixes grouped into one release included, since grouping
them is what makes them one arc. The condition is the ARC, never how you dispatch it: separate single-slice
arcs run side by side are each one slice and cut nothing. **Merging each slice into the integration branch
as it lands is the exception, taken only when the user asks for it for this arc**, since five costs land on
the shared branch whenever a multi-slice arc does:

- **Base churn** — every live slice's base moves under every other; an epic branch bounds that to its own
  slices.
- **The integration gate signal** — *Gate the integrated whole* reads the `^2` diff as non-empty whenever a
  sibling merged in between, so the shared branch routinely carries a tree no gate ran; an epic branch
  converges and gates once.
- **Revert granularity** — N merges to unpick from the branch everyone forks from, against one.
- **Cross-slice seam review** — *The PR review loop* wants both halves of a seam diffed against each other
  before either merges, far easier on a branch you control.
- **One arc, N releases** — where shipped content must move a version, every merge into the integration branch
  is a release, with the version file and changelog a hotspot every slice touches.

**`ground` recommends; you decide and act.** It produces the seam map, so it is the pass positioned to see
whether two halves must land together — Rule 1's question. A breakdown recommending nothing on a multi-slice
arc still gets an epic branch by Rule 2, since silence is not the user asking to merge as it goes, and one
saying *one slice* gets none.

## The cost

Conflicts do not disappear, they are deferred and concentrated: a collision a slice author would have resolved
small and fresh accumulates until the epic lands, then falls to whoever lands it.

**The mitigation is mandatory and rides the tick you already run.** On the same wakeup tick that drains the
gate queue and fast-forwards the local integration branch, merge that branch INTO the epic branch — merge,
never rebase; *Draining the gate queue* carries the commands. That bounds the drift and surfaces each
collision while its author is still live to resolve it; skipping the cadence is how the deferred conflict
becomes the concentrated one.

## Docs land at the end

**Docs describe an end state, and an epic's intermediate states are never shipped**, so a doc slice 1 rewrites
is rewritten by slice 3, and four slices patching one chapter conflict **semantically** — what the
merge-holder is least equipped to resolve. Deferring wholesale fails too:
**the implementer is the only party that knows what its change actually falsified**. So the two halves split:

- **The breakdown still names the docs each slice falsifies**, slice by slice, at grounding time, derived from
  the behaviour the slice changes and never from a grep.
- **The slice's deliverable is an entry in the epic's falsification ledger, not the edit** — *"this change
  makes paragraph Y of `<doc>` false"* — reported in the hand-back's per-doc verdict. That is the rule for
  prose describing behaviour; a **structural coordinate** the slice moved is fixed by the slice, under the
  carve-out below.
- **Two questions, not one — the second asks what the slice ADDED that no doc describes at all.** *What did
  this change make false?* asks about a **difference**, so a slice exposing a surface no doc ever described
  answers *nothing* — indistinguishable from a slice that touched no documented behaviour. Ask the second of
  the same diff, into the same ledger, marked **needing new prose**: *"this change adds `<surface>`, which no
  doc describes."*
- **The ledger is the epic's record, not a file in the tree** — that file is the shared hotspot this exists to
  avoid. Accumulate entries where the arc's state already lives: the per-increment comment on the umbrella
  issue, or the orchestration record when the arc has none.
- **One closing docs slice consumes the ledger — and derives its work from what the epic ADDED as well, never
  from the inherited entries alone.** Last in the arc's phase map, depending on every other slice, writing
  against the final tree; its brief tells it to derive rows from the arc's landed diff and **reconcile** them
  against the ledger.
- **Every entry names the file, symbol or route it is about, or says it is `unanchored`** — written into the
  entry by the slice that recorded it, which is the one seat that still knows what it meant, since whoever
  answers the ledger routes by that coordinate.
- **Where the closing docs work is split across parallel slices, every entry goes to exactly ONE of them, and
  one is named owner of every entry that routes to none.** *Check if it is yours*, handed to several, is a
  question nobody is assigned to answer: each can correctly conclude the entry is a sibling's, and all of
  them report clean over a mechanism documented nowhere.
- **The epic cannot close with a non-empty ledger.** Every entry is answered by the closing slice's PR, and
  the epic → integration PR does not open while any remains — a precondition over the **open**, where the
  close-out gate is one over the **merge**. **Test each entry against the merged tree by its identifying
  constants — a symbol, a lifetime, a limit — never by the ledger's own wording, and count the homes**: none
  is an entry still unanswered, one is answered, and two is one mechanism written into two pages, which every
  reader of either page takes for coverage.

**Three carve-outs.** A **docs-only slice** writes inline: its diff *is* the closing slice's work.
**Single-slice work has no end of an epic** — docs ship in the same PR as the behaviour. The third reaches
what neither can, a code slice mid-epic:

**A structural coordinate — a file path, or a route literal in the same clause as one — is fixed by the slice
that moves it. The test: if a checker can tell the reference is stale without reading the sentence, the slice
that broke it fixes it.** It is a **rename, not a rewrite**. **Prose describing behaviour still defers to the
closing docs slice, ledger and all.** Without it a slice whose deletions break a docs gate cannot pass without
an edit the rule forbids, and no ordering escapes that.

**A renamed IDENTIFIER lands on the prose side, settled by the test rather than by the nouns.** Nothing
resolves a bare identifier in prose against the tree: a symbol may be current API, superseded, or a
hypothetical, and telling those apart is the reading the test excludes. So an identifier your slice renamed
goes to the ledger — **the whole sentence, not the name on its own**. **Where a repo's docs gate does resolve
identifiers, the same test returns the other answer and the slice fixes it inline.**

⛔ **Repointing a coordinate is NOT licence to fix the paragraph around it.** Change the path and nothing else;
the sentence containing it, and the section containing that, stay in the ledger — a "while I'm here" rewrite
reintroduces the semantic conflict wearing a sanctioned edit.

⚠️ **Before you land an inline fix, read the sentence you just edited for a fact YOUR OWN change moved** — a
TTL, a limit, a default, an ordering — and **fix both halves; never land the half**, since a fresh coordinate
beside a stale number reads as evidence someone checked. **Reverting is not the other way to satisfy that**:
every edit this fires on is one a checker compelled, so undoing it hands the checker back what it reds on.

## Mechanics

- **It gets its own worktree**, because **the main checkout holds the integration branch and nothing else,
  ever**:
  ```
  setup-worktree.sh <epic-branch> <integration-branch>
  git -C <epic-worktree> push -u origin <epic-branch>
  ```
  The helper **never touches the main checkout**, and parking the epic branch there is rejected outright — one
  checkout, one HEAD, one epic. **Push it**, or `origin/<epic-branch>` does not exist: nothing for invariant 2
  to compare a slice's `HEAD:` against, no base for `gh pr create`.
- **⛔ The epic branch's leaf must be unique across the whole epic — no slice may reuse it.** The worktree path
  is `$WORKTREE_HOME/<project>/<branch-leaf>`, so `epic/checkout-flow` and a slice `feat/checkout-flow` land
  in the **same directory**. `setup-worktree.sh` refuses there — no `READY:` line, non-zero exit — because it
  reads the branch back and finds the epic's. Which generalises: **a `READY:` line is not by itself evidence
  the branch was created, the branch-back check is.** The likeliest collision is the epic's own
  **closing docs slice**, so pick a leaf it will not want.
- **The epic worktree is a merge point and a gate target, not a workspace — nobody codes in it**, and never
  carries uncommitted changes: the every-tick `merge origin/<integration-branch>` refuses to run over them,
  and `merge-pr.sh` fails mid-close-out when it fast-forwards the base **inside that worktree**.
  **Resolve a conflicted tick before you walk away** — resolve, commit, push.
  **The seat holding the merges already writes here — the conflicted tick above, a merge-reconcile commit, a
  regenerated derived artifact — and the close-out panel adds the one DISPATCHED writer: the fix agent its
  findings send in** (*Close-out is at most one gate plus one ordinary PR*). **Every one of them commits and
  pushes before walking away**, which is the whole of what this bullet asks, and no fresh worktree is cut for
  any of them.
- **A module-resolution failure in the epic worktree is a stale install until proven otherwise, not a defect
  in the merged code.** This tree outlives the merges landing in it, so its dependencies fall behind; the
  tick's install (*Draining the gate queue*) keeps it current. Ask whether one has run since the package
  arrived **before reading a line of the diff**, or that error's shape sends a fix agent against correct code.
- **Its *prefix* is free, its leaf is not, and the marker ref is the opposite of both.** Nothing reads an epic
  branch's prefix; it is identified by what forks from it and PRs into it.
  **`transient-red/<epic-slug>` is not free: its name IS the contract**, since the detector finds the window
  by that exact ref — a marker spelled otherwise is a window that never opens, silently.
- **Cut under Rule 1's primary trigger? Open the window in the same breath — the branch alone does not open
  it.** Commit-time tooling cannot read your breakdown, so declare it structurally from the epic's worktree:
  ```
  git -C <epic-worktree> branch transient-red/<epic-slug> <epic-branch>
  git -C <epic-worktree> push origin transient-red/<epic-slug>
  ```
  **It answers one question — is the window open — and never serves as a fork point:** a detector needing the
  branch's footprint takes its merge-base against the **epic branch**, since the static marker silently widens
  every slice's owned file set as the epic runs.
- **Slices fork from it and PR into it.** `setup-worktree.sh <slice-branch> <epic-branch>`, and invariant 2
  compares the printed `HEAD:` against `git rev-parse origin/<epic-branch>` rather than the integration tip —
  **fetch first and read the freshness count, because this is the base most likely to have moved.** It
  advances on every close-out and every tick, so a cached copy goes stale between waves you run yourself; each
  slice's brief names it as the PR base.
- **A follow-up the epic surfaced is part of the epic, so it lands on the epic branch** — its slice forks from
  and PRs into it like any other, linking to the arc's umbrella. Only once the epic has merged back does a
  still-open follow-up re-target the integration branch; routing one straight there bypasses the isolation the
  branch exists for.
- **Per-slice close-out needs no change** — `merge-pr.sh <n>` reads the base off the PR (`baseRefName`), so a
  slice PR based on the epic branch closes out identically, leaving the main checkout untouched. The one
  difference: the epic branch is checked out on every slice merge, so the helper fast-forwards it
  **inside that worktree** (`merge --ff-only`) instead of moving the ref from outside.
  **What decides whether that close-out runs at all is `autoMergeLeaves`, not `autoMergeEpic`** — a slice of
  this epic is a leaf and merges into this branch, while `autoMergeEpic` reaches only this branch's own merge
  into the integration branch below. Both readings, and what to do where either holds, are in
  *Merge & cleanup* and in the close-out bullet below respectively.
- **Hand-close the issues the work resolved — an epic withdraws the fallback for every slice at once.** A
  slice PR bases on the epic branch, not the repository's **default** branch, so its closing keyword is inert
  (*Merge & cleanup* carries the mechanics). **So while an epic runs the board is not the arc's progress
  record — the umbrella body is.** Catch the board up to what has merged, never ahead of it: the loop counts
  the tracker in its termination check, so an issue closed early is a false "done" in the artifact it
  terminates on.
- **A change to `.agents/worktree.json` has its config-read window end at THIS branch's close-out, not at the
  slice merge inside it.** That merge is not where the helper's lookup lands, so every worktree the arc cuts
  afterwards is provisioned the old way and you hand-apply. *Worktree creation* is the authoritative copy.
- **Close-out is at most one gate plus one ordinary PR, and the ledger has to be empty before either** (*Docs
  land at the end*). Once the last slice merges, merge the integration branch into the epic one final time
  **in the epic's own worktree**, then **open the epic → integration PR as a DRAFT, run one full
  `/pipeline:review` panel against it, land any fix round it earns, and only THEN enqueue the gate against
  it — in that order**, naming the epic worktree as the ticket's worktree. **Under `"epicMerge": "squash"` that PR's
  title and body become the arc's one surviving commit message** (*Mechanics*), so write them as that.

  **The PR opens BEFORE the gate, and the rule that looks like it forbids that does not.** *Gate the
  integrated whole* states its precondition over the **merge**: a draft PR puts nothing on the shared branch,
  GitHub refusing to merge one. Opening first gives the ticket something to attach to, so the close-out takes
  the shape every other PR has — draft, panel review, any fix round, enqueue, gate comment, posted review,
  merge — instead of being the one gate with no ticket, no log and no recorded verdict.

  **That panel step is `/pipeline:review` invoked against THIS PR by number, exactly as any other caller
  invokes it** — the pass reads a named PR's real diff and posts its findings back onto it as a review, and
  it runs here unaltered right through that post; **what differs is only who acts on the findings**, which is
  the next rule. **Ask it for every dimension it offers on this project — seven where the project states
  conventions worth a pass, six where it states none — and never a selection narrowed to what this diff looks
  like**, since every dimension already ran per slice against that slice's own diff in isolation and all that
  is left for this run is the one thing none of those could see: how the slices COMPOSE, the state they
  share, the interactions that exist only once they sit together. **It costs ONE flat panel per epic however
  many slices the arc held**, which is what parts it from running this pass twice anywhere else here: a
  second per-slice run multiplies by the slice count, while this is once, at the top, over the only diff
  nothing else reads whole.

  ⛔ **The caller here is the ORCHESTRATOR, which never writes code, so it applies nothing the panel raises
  itself.** **Where the panel raises something worth taking, dispatch a FIX AGENT into the epic branch's own
  worktree** — that tree already exists and IS the merge point, so never cut a fresh one for this and never
  open a second PR — and it applies what you accepted, runs the project's scoped check, commits, and pushes
  onto this SAME close-out PR. **Where the project declares `install`, run it in that tree before the fix
  agent's check** — that tree outlives every merge landing in it, and a stale install there presents as a
  module-resolution failure that reads as a defect in the merged code and sends the agent against code that
  is correct. **That is the one DISPATCHED exception to *nobody codes in the epic worktree* above**, and the
  fix agent commits and pushes for the reason every writer in that tree does: the gate ticket you raise next
  refuses a worktree carrying uncommitted tracked changes, and nothing takes a ticket back.

  **One panel run and at most one fix round, then carry straight on — this pass no more re-triggers itself
  here than it does on a slice.** That fix round's readers are the gate and your own read of the diff, both
  still ahead of the merge, so a second panel over the same diff buys a reading already scheduled.
  **Gate AFTER the fix round, never before it**, since a ticket raised first both burns a serialized gate on
  code you are about to replace and freezes the very worktree that fix agent has to write in, with nothing
  able to take a ticket back. Where the project declares **no queue**, gate the epic
  branch in its own worktree yourself and read its exit status.

  **Then one check stands between that green gate and the merge — `autoMergeEpic`
  (`skills/procedures/config-keys.md`), read here, after the gate and before the helper.**
  ⚠️ **Absent means `false`, and this is the one place in this file where a project that has declared
  nothing does NOT proceed** — the other two merge-automation keys default to `true` and this one defaults to
  holding, because this merge is the one that actually puts the arc's combined work on the shared branch.
  **Where it is `true`**, merge it with `merge-pr.sh` like any other — the one PR with no implementer behind
  it, so no hand-back to promote. **Where it is held**, post **one comment** on the close-out PR saying the
  pipeline is satisfied — ledger empty, panel review landed, any fix round in, gate green — and that
  `autoMergeEpic` is holding the merge, and stop there.
  ⛔ **That PR stays a DRAFT: never call `gh pr ready` on it and never call `merge-pr.sh`**, the ready flip
  living one line above the merge precisely so a PR can never sit around wearing a review it has outgrown
  (*Merge & cleanup*). Nothing after the merge runs either — the epic worktree stays up, the epic branch
  stays, the local integration branch is not synced, and the arc's issues stay open. **Say in your own report
  which PR is held and what approving it takes**, the comment being on a draft nobody is watching. The arc is
  not finished and says so: a close-out whose merge has not happened is not green, so the loop's termination
  check is unsatisfied.
  ⚠️ **One item on that list is NOT benign, and it is the `transient-red/<epic-slug>` marker**: left standing
  it relaxes the next unrelated slice's compile check for as long as the hold lasts (*Deleting the epic
  branch*), and a hold is unbounded — so on a knowingly-red epic, delete the marker when you post the holding
  comment rather than at the merge, and cut it again if the window has to reopen.
  ⚠️ **And re-run the close-out cadence when the approval finally arrives, before you invoke the helper.**
  `merge-pr.sh <n>` then runs completely unmodified, squash and all where the project declared one — but under
  `"epicMerge": "squash"` it compares the epic tip against the squash commit's tree and refuses to delete the
  branch when they differ (*Mechanics*), and those trees are equal only while the epic still contains
  everything the integration branch has. A hold of any length is exactly the window in which that stops being
  true, so merge the integration branch into the epic one more time, re-gate, and only then merge — which is
  the same ordering *Gate the integrated whole* already asks for, arriving late.
- **This closing merge is the ONE merge a project may collapse, and it is an option a project declares — never
  a judgement anyone makes at merge time.** Every other merge here is a real merge commit with no opt-out. A
  project on a long-lived release branch may prefer one commit per arc for this scaffolding branch, and says
  so with `"epicMerge": "squash"` in `<repo>/.agents/worktree.json` (`skills/procedures/config-keys.md`).
  `merge-pr` reads the key and picks the mode — nothing to pass it, no command-line route to the squash.
  **The default is `merge`, and stays `merge` for every project that has never heard of the key.**
  - **Under `"squash"` the squash still requires BOTH conditions, and every unanswerable question falls back
    to `merge`.** (1) The head branch is **not** the integration branch
    (`skills/glossary/vocabulary/integration-branch.md`), which the project declares rather than anything
    deriving — an epic branch sits above it and is never it — and (2) the head branch has merged PRs into it
    (`gh pr list --base <head> --state merged`) — which *is* the definition of an epic branch, and which a
    slice branch answers zero. gh absent, offline or rate-limited; a declared integration branch this
    repository does not have, which reads as none declared; a count of zero; an unparseable config; a value
    that is not exactly `squash` — all land on `merge`, and **both ports compare key, value and branch names
    CASE-SENSITIVELY**, so `"Squash"` and `"EpicMerge"` mean `merge` in either.
    **A missed squash is cosmetic, a wrong squash is unrecoverable history.**
  - **Condition (1) is why the integration branch has to be DECLARED: undeclared, the squash is unreachable
    wherever work lands on the repository's default branch.** The older test asks whether the PR's base is
    that default branch, which stands in for the real question — is this head the branch work lands on — and
    holds only where the two differ. Declaring it replaces the proxy with the fact; leaving it undeclared
    keeps the old behaviour exactly, which is what makes adopting it safe.
  - **What condition (1) protects is a merge this flow never performs**: an integration branch moving onward —
    `release/x.y.z → main`, say — is a release event outside this flow's scope, and condition (2) is true of
    an integration branch as well, so without (1) a hand-run close-out would irreversibly collapse the whole
    branch with every signal reading clean.
  - **The squash path does not pass `--delete-branch`, and git's "not fully merged" warning is answered by a
    different instrument rather than waved through.** A squash commit has no second parent, so the branch is
    never an ancestor of the new tip and the warning fires on **every** squashed close-out, carrying no
    information. What has to be true instead is that *what landed is what was gated* — a question about
    **trees**, which a squash preserves exactly. So `merge-pr` captures the epic tip **before** the merge and
    afterwards runs `git diff --quiet <epic tip> <squash commit>`. Empty ⇒ the integration branch holds, byte
    for byte, the tree the close-out gate ran on, **and only then is the branch deleted**, local and remote.
    Non-empty, or unanswerable, ⇒ the close-out **stops** with both copies intact, so re-running resumes from
    that check.
  - **The squash commit's message is the close-out PR's, passed explicitly — never the repository's squash
    setting.** `merge-pr` hands `gh pr merge` the PR's title with `(#<n>)` appended as the subject and the
    PR's body as the body, so the one commit that survives says what the reviewed PR says; left to the
    repository, GitHub's default setting concatenates every commit on the branch into that body, trailers
    included. **A PR whose title or body cannot be read falls back to `merge`**, like an epic tip that cannot
    be captured, since a squash whose message a remote setting decides is the defect this removes.
  - **What it costs: the arc's individual commits stop reaching the integration branch.** They survive on the
    epic branch until it is deleted and in each slice's PR, but `git blame` afterwards lands on the squash
    commit for every line the arc touched.
- **Deleting the epic branch is automatic on the merge path and earned on the squash path; the marker is left
  by hand either way.** The close-out PR has the epic branch as its **head**, so `merge-pr.sh` tears that
  worktree down and, on the merge path, `--delete-branch` removes the branch local and remote — the
  never-delete-past-git's-"not merged"-warning guard applying as to a slice branch. On the squash path that
  warning fires unconditionally, so the tree comparison above stands in its place. The slice branches are
  already gone, so all that is left is the `transient-red/<epic-slug>` marker —
  **delete it yourself, and the window closes with it**, or it outlives the epic and quietly relaxes the next
  unrelated slice's compile check.
