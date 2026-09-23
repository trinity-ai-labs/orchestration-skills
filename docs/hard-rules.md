## The hard rules (the agent follows these; good to know)

**The ones that read the same at every seat live in one file every pass has its reader open first —
[`skills/ground-rules/SKILL.md`](../skills/ground-rules/SKILL.md), the never-a-fork ban first.** The rest of
this page is the per-stance half, which is restated in whichever pass acts on it.

- **⛔ Never a fork — every sub-agent is spawned FRESH, and a dispatched READER dispatches nothing at all.** A
  fork inherits the whole conversation of whoever spawned it and executes that agent's brief — *commit, push,
  open a PR, enqueue* — before it gets its turn back, and the deepest seat is the worst one: a review pass's
  readers run beside a live implementer that still holds its worktree and its open PR, so neither the
  reviewers nor anything under them is ever a fork. A reader that spawns children reports findings nobody in the chain established, and re-sizes
  from inside the reader count the pass chose.
- **⛔ Every sub-agent's model tier is stated at the spawn, never inherited.** A host handed no model gives the
  child the **parent's** model, so one top-tier agent spawning readers spawns top-tier readers and a wide
  fan-out multiplies a tier nobody chose — which makes this the sibling of the never-a-fork ban above, that
  one on the spawn *mechanism* because the child inherits the conversation and this one on a spawn *parameter*
  because the child inherits the model. The tier matches the **child's** work rather than the parent's: a
  reader over one dimension of a diff, a searcher on one subsystem, a mechanical rename are standard tier
  whatever the parent is doing, and a genuinely hard child still gets the top tier, since what is banned is
  the silent inheritance rather than the spend. **Which seat DECIDES a slice's tier is settled with it.** The
  grounding pass owns it — it is the seat that read the code, and the tier is already one of the fields it
  emits — and writes one line of why; the dispatcher **resolves** that tier onto a host model and names it in
  every spawn, may **raise** it on what the grounding could not see, with its reason beside it and nobody's
  permission, and may **lower** it only with a written reason in the brief, since the cheaper reading is
  always the defensible one and a silent downgrade leaves no artifact at all — the hand-back names no tier and
  the diff carries none. The same pass's brief also **recommends** whether a slice warrants a review pass, on
  the same reading, which the dispatcher may override with a reason of its own; it is a recommendation rather
  than a tenth slice field, and a one-liner or a mechanical rename still comes out as *no pass*.
  **The wave's WIDTH is the third of that shape**: the grounding pass recommends how many ready issues go out
  together and states the evidence only it holds — which are the same mechanical change, which have an
  ordering between them, which share a contract seam or a fence, which owned paths overlap — and the
  dispatcher decides it against what grounding cannot see, the gate queue, which slices are already live and
  what the host can take, writing its reason beside a departure, since a wave widened past what grounding
  argued for with nothing recording why bills the difference as a suite reddening under concurrent
  implementers that passes on a quiet machine; a recommendation rather than a tenth slice field again, a width
  being a property of the wave rather than of any slice in it. **All three are one principle and it is worth
  reading as one: the pass that reads the code RECOMMENDS, and the seat that holds the machine DECIDES** —
  what changes between them is only which facts each seat is the one holding.
- **A dispatched agent runs every check and command in the foreground and ends its turn only at its
  hand-back — a command it started is never something it waits on by ending the turn.** A detached command's
  exit re-invokes nothing the way a child's report does, so a turn ended on one IS the agent's hand-back, with
  no verdict in it. Where a check outlasts one tool call the agent raises that call's timeout to its limit
  and, past it, detaches the check with its exit status written into its own log and polls that log in the
  same turn until the exit line appears
  ([`skills/procedures/host-tools.md`](../skills/procedures/host-tools.md) has the form). This rule is about
  commands, not the sub-agents the agent spawned — waiting on those is the one thing an ended turn safely
  does, which is the next rule — and a dispatcher's detached drain is neither, since its turn ends on a tick
  and hands nothing back.
- **An agent waiting on sub-agents it dispatched ends its turn with no tool call wherever its host re-invokes
  it as each child reports — that is safe, since the ended turn hands nothing back and each report arrives as
  a new turn.** It never makes a call whose result it does not need just so its turn does not end: the ban is
  on that purpose rather than any tool, since such a call is a paid round trip that learns nothing, while a
  host call that blocks until a child reports, or a tick or watch a pass requires, returns something the
  agent acts on and is not one of these. **Where a host gives neither that re-invocation nor such a blocking
  call, there is a third branch**: ending the turn loses the handoff with nothing coming to restore it, so
  the agent hands back on what has landed and names which children are still out rather than waiting
  silently.
- **A review reader the host refuses because too many agents are already running has not gone out yet — it
  has not failed.** The review pass spawns it again once its own readers free their slots, and where none of
  them is still out it PARKS rather than dropping the dimension: tree untouched, no finding applied, nothing
  posted onto the PR, and a hand-back reading `Review: PARKED` with the dimensions still to go. **By then the
  tree carries the FINISHED shape** — commits past the fork point, a pushed branch, a draft PR open — since
  the pass runs against that PR, so the marker in the report is the only thing telling a parked slice from
  one that is done, and an open PR is never itself the evidence one is. The dispatcher reads that
  report rather than the tree, and resumes parked slices on capacity — the
  next hand-back or tick, one parked slice per event, in the order they parked. Nobody reads a refused
  dimension in its place: the author is the party worst placed to ask what its own diff could lose.
- **Never ground beyond the horizon.** Only the increment about to be dispatched gets real paths, owned files,
  boundaries and a model tier; everything past it stays at shape depth until the horizon reaches it. Grounding
  more of the arc is indistinguishable from grounding it better right up until a wave lands and moves the
  paths — and then nothing errors.
- **Never add a level to the plan's tree of tasks.** The tree is two levels — an umbrella and its sub-issues,
  the children being leaves — cut once where the issues are authored, and
  **one sub-issue is one slice is one worktree is one PR**, a constraint rather than a default. The grounding
  pass walks to the ready leaves and grounds them; it never cuts one issue into several, because a cycle that
  lands pieces of an issue moves real work past a checklist line that cannot tick, leaving churn as the only
  countable thing. An issue too big to be one PR is reported back to the plan, which gains another child
  authored at issue altitude — and N ready leaves that turn out to be one PR's worth of one change go back the
  same way, the answer being one leaf re-authored at that altitude rather than a merge the grounding pass
  performs, since one slice spanning two tracked items ticks both lines at once, so neither item's `Verify`
  was ever scored on its own and the board cannot say what was reviewed — the same parting of the unit the
  board holds from the unit that lands, from the other side.
- **A brief names ONE tree, and the rule covers every command rather than only the first.** Every path in a
  dispatch brief is inside the assigned worktree or relative to it; where an instruction genuinely needs the
  repository rather than a checkout it names the **ref**, the part that is actually repository-wide. A second
  absolute path is a checkout of its own, so a check run there answers about another branch — and a green from
  the wrong tree is identical to a green from the right one, which is also why a finding indicting shared
  machinery is tested against a mis-pointed instrument before it is believed.
- **Never** use a harness parameter or any auto worktree provisioner that makes the worktree for you — they
  seed worktrees at a **stale base** and put them in the wrong place. Only `setup-worktree.sh` makes
  worktrees.
- **The integrated whole is gated in a tree only the dispatcher writes to, and never in the main checkout** —
  in either gate mode, whether the dispatcher runs that gate or a runner does, since every session's close-out
  fast-forwards the main checkout, so nobody can hold it frozen for a gate, and whatever a project keys on the
  checkout path — a per-tree test database, a cache, a generated artifact — is shared by every agent gating
  there at once, so two gates that overlap there corrupt each other's runs in both directions and neither
  failure output names the cause. Where an epic branch holds the merges, that tree is the epic's own worktree,
  installed immediately before that gate or its enqueue because `merge-pr.sh` fast-forwards it on every slice
  close-out without installing, and held still while its ticket is outstanding. Where the merges landed on the
  integration branch itself, the dispatcher cuts a throwaway tree from its tip with `setup-worktree.sh`, gates
  there — by hand, or as the PR-less ticket's worktree — and once the verdict is in, which for a ticket means
  once it has settled, removes the tree with `remove-worktree.sh` and deletes its branch, which was never
  pushed and carries no commit: a derived artifact regenerated there goes back as a fix instead.
- **Always verify HEAD before dispatching an agent into a worktree, and fetch first — the fetch is part of the
  check, not preparation for it.** The helper prints what it made — `READY: <path>`, then `HEAD: <sha>` — and,
  when it is forking a new branch, withholds both unless the tree it is about to hand back *contains* the
  base. That refusal is a weaker comparison and does not retire this one:
  ```bash
  git fetch origin                                            # origin/… is a local cache — without this you compare a stale pair
  git rev-parse origin/release/0.4.0                          # the HEAD: line must match this
  git rev-list --count release/0.4.0..origin/release/0.4.0    # …and this must be 0
  ```
  A remote-tracking ref is what the remote looked like at *that clone's* last fetch, and reading one contacts
  nothing — so in a checkout that has not fetched, the local base and `origin/<base>` hold the same commit for
  the same reason, the comparison is true, and it passes in exactly the case it exists to fail; one worktree
  that passed the `rev-parse` comparison unfetched was 2,392 commits behind its real base tip, on a checkout
  whose last fetch was seventeen days old. Fetch in the repository you are verifying — a fetch in some other
  repo you touched earlier in the session moves nothing here, and in a polyrepo workspace that means once per
  member, since remote-tracking refs are per-repository. The count is the half equality cannot give you: it
  answers *how far behind is the base I just forked from*, where two refs that go stale together answer
  nothing. The helper's own refusal asks whether the base tip is an **ancestor** of the tree's HEAD and
  resolves that tip in your **main checkout**, so a tree carrying its own commits on top of the base passes
  there — the legitimate re-attach it must not refuse — and so does a base branch that is itself behind
  `origin`, an ancestor of everything cut from it. `--existing` takes no base, so that refusal does not run
  there at all and this comparison is the only one covering a re-attached tree. Compare the sha, not the
  `READY: … off <base>` text: that says what was asked for, and this check exists for the case where what you
  got is something else.
- **Real merge commits are the default everywhere, and `"epicMerge": "squash"` is a project-declared
  alternative at exactly one boundary.** That boundary is an epic branch collapsing back into the integration
  branch it was cut from — scaffolding, cut for one arc and deleted at its end, so a project may prefer one
  commit per arc to N slice merges plus a merge commit. It is declared in the repo's own config
  ([Per-project config](per-project-config.md#per-project-config)) and read from the **main checkout's** copy,
  never decided by whoever runs the close-out; every other merge in the flow is a real merge commit with no
  opt-out. **Declaring `integrationBranch` is what makes that squash reachable, not what blocks it.**
  Declared, the boundary test `merge-pr.sh` runs is a single question about the **head** branch — is it the
  integration branch? — and an epic close-out's head is not, so it qualifies even where the integration branch
  is also the repository's **default** branch. The default branch is consulted *only* as the fallback for a
  project that declares no `integrationBranch`, and it is that fallback, not the rule, that declines the
  genuine epic boundary wherever work lands on the default branch.
- **Never rebase.** No boundary, no exception, and no key to declare one. A branch that has fallen behind
  takes its base merged *in*; conflicts are resolved at merge time, in the worktree, while both sides are
  still there to read.
- **Branch from the branch the work converges on, not `main`.** That is the epic branch, which an arc of more
  than one slice cuts by default, or the integration branch — for a one-slice arc, and for a multi-slice arc
  whose user asked it to merge each slice as it lands, an instruction that covers that arc and not the next.
  A PR targets the same branch its worktree came from.
- **Implementers never enqueue a gate, never mark their own PRs ready, and never merge their own PRs — and
  whether they run the full gate is the project's `enqueue`/`drain` to say**
  ([Per-project config](per-project-config.md#per-project-config)). **Where the project declares both —
  queue mode —** an implementer never runs it: it pushes, opens a draft PR and hands back; the dispatcher then
  posts the verdict it formed onto the PR as a review on each round of that loop, and **enqueues only once it
  is satisfied with the code**, a runner gating it and commenting its own verdict before the dispatcher marks
  it ready and merges. Holding the ticket back until then is what keeps a gate off a tree a fix round is about
  to rewrite, nothing being able to take a ticket back, and it is the shape an epic's close-out has always
  had — draft PR first, gate enqueued against it. **Where it declares neither — in-line mode, which a
  dispatcher can also put a single slice in — the implementer runs the gate once itself and comments the
  result on its draft PR, and no ticket exists at any point.** The implementer's half reads the same in both:
  still a draft, still never its own merge. The dispatcher's does not — in-line, the verdict comment arrives
  *before* the hand-back rather than after it, so it is not the signal that the implementer is done, and
  *Where the review approval lives* in [The mental model](mental-model.md#the-mental-model) is where that is
  argued.
  **A comment an implementer removes from that PR, it removes by IDENTITY** — reading the comment and naming
  its id, and leaving one it cannot establish it wrote — since one account authors every party's comments
  there, so `author.login` separates none of them and a positional test like *the verdict before the current
  one* takes the dispatcher's own fence grant as readily as a stale verdict; tidying a superseded verdict
  stays wanted, and the dispatcher reads each grant back off the PR rather than trusting a write it made
  earlier to have survived.
- **Every commit is held to the project's scoped check, and whether a pre-commit hook does that is read off
  the repository rather than declared** — where a hook runs the scoped check the hook holds commits to it,
  and where none does the implementer runs the scoped check itself before each commit. There is no config key
  for it, since the hook's presence is something any pass can observe.
- **A fence is a ceiling on what a slice may EDIT, never a wall on what it may RAISE.** An implementer that
  finds something wrong in a file its brief fenced off asks its dispatcher while both are still alive, and it
  **fixes what it HIT while doing its slice rather than going looking for more** — the unlisted middle between
  its `Owns` and its fences is its to repair, and it never sweeps the repository for work. What a fence stops
  it from fixing it raises **before it pushes**, that being also where it reports a
  **shared documentation page it discovers it must write**, since a wave's owned files name the docs grounding
  could foresee and the page a slice finds only once it sees what its change did is the one no list contained,
  which is the one boundary every slice crosses exactly once and the last moment before the PR and the gate
  ticket exist, so an answer arriving before it is an edit in a tree still open where one arriving after it is
  a fix agent dispatched back into that worktree. Asking is the default rather than a last resort, and beside
  fixing it is the ONLY disposition that seat has: an ask is one message and a receipt where a filing is a
  whole unit of work with its own worktree, PR and gate that moves the reasoning out of the run still holding
  the files open. So **filing is a verdict the dispatcher returns rather than a disposition the implementer
  reaches for — and the implementer opens no issue in any circumstance, the no-dispatcher-live case included,
  where the finding goes in its hand-back instead**, and the dispatcher absorbs the question because it alone
  holds the sibling map and the wave. **The reviewers an implementer's quality pass dispatches have no filing
  disposition either, and every one of those briefs says so with the reason beside it** — a reader whose whole
  deliverable is a report spends that same unit of work on what one line of that report settles, and a ban
  written only at the seat describing the briefs reaches no reviewer at all. A filing from either of them
  leaves nothing in the worktree, so it is caught on the tracker rather than on a clean `git status`.
  **The ask is the implementer's and the grant is the dispatcher's** — no
  slice widens its own fence, since a live slice that grows is indistinguishable from one diverging unless the
  party running the divergence check is the one that granted the growth, and the grant is written where a
  later reader finds it rather than dying with the run as a message would — on the issue behind it while no PR
  is open yet, and onto that slice's PR before the dispatcher reviews the diff, since the issue is not the
  surface the diff is read on. **Both halves are owed at once and only one of them announces itself**: the
  granted path — every path an enumerated grant resolved to — joins the next tick's on-scope set, where
  forgetting one raises a false divergence alarm, while the PR comment simply goes missing at the reviewer.
  **A grant that lands after the slice's review pass has closed produces an edit whose only reader is the
  dispatcher's read of the diff**, so the hand-back reports, for each grant on a slice that ran a pass,
  whether it acted before that pass ran or after it reported. **And one the slice already worked under before
  that pass supersedes the brief's fence for the reviewers too** — those paths are in bounds for them and are
  stated in each reviewer's brief, since a reviewer left to infer it meets the granted edit inside the diff
  and outside its own stated bounds, and either flags it as drift or skips it as another slice's business.
- **Git holds an agent's work before its tree moves, and a stash is restored by its marker, never popped
  blind.** Before anything that clears or moves a working tree — checking out another commit, `reset --hard`,
  `checkout -- .`, `clean` — the work becomes a git object: a commit where it is ready, a stash where it is
  not, and never a patch or a moved file outside git, where no sweep can see it and one `rm` loses it; and no
  reset takes a branch below the commit it forked from. Agents push with a marker —
  `git stash push -u -m "pipeline-stash/<branch-leaf>/<epoch>: <why>"` — and restore only the entry that
  marker names, resolved in the same invocation that pops it, since the stash stack is
  **repo-global and addressed by position**: the main checkout and every worktree push onto and pop off the
  same one, and `stash@{n}` renumbers whenever anything anywhere pushes or drops, so a bare pop in one
  worktree applies *and drops* whatever happens to be on top, another agent's work or the human's. Zero
  matches or several is a stop; never an argument-less `git stash pop`, `apply` or `drop`; `git stash clear`
  is banned outright.
- **A reversal is RUN rather than read off the diff, and a reader never runs one.** A verify bar that proves
  a new test fails against the pre-change code has some seat move a tree to do it, so the bar states how
  rather than leaving the means to whatever is quickest. The shape is decided by the reversal needing the
  new test standing while the code under it is pre-change: commit the work, make the breaking edit, run the
  one targeted test, then restore it — or stash the production file alone under the agent's own marker,
  where that push is itself the break and its pop restores; never the whole tree, which carries the new test
  away with the change. Or the reversal runs against the slice's fork point, where the pre-change code is
  already a commit and no tree moves at all. **A review pass's readers sit outside that entirely** — they
  read one tree concurrently while the agent that wrote it still holds it, so a reader asks that agent for
  the reversal it already ran or reports that none was run, and "confirmed by reading the diff" is recorded
  as a reversal that did not happen rather than as a bar met.
- **An agent owns its follow-ups, and filing one looks first.** Work a change reveals but doesn't land is
  filed and folded into the run — not a bullet in a hand-back for you to triage.
  **Which of the two it is turns on the arc's GOAL, never on whether the branch still builds and never on the
  item's size**: work the goal is not true without is folded in however large it is, since a filing that
  leaves the goal unmet closes the arc green with the work it was filed for still outstanding, and
  forced-and-large is a plan defect reported as one rather than a filing. Filing searches the tracker by the
  *shape* of the failure first, open issues and closed alike, because the number may already exist: an open
  issue already carrying that failure takes the observation as a comment — which is what promotes an issue
  deliberately held for a second sighting — and a closed one makes the item a regression only where the fix
  that closed it is actually present in the copy the agent read, since otherwise the agent is running an older
  version and the observation is skew rather than a defect, so nothing is filed; where it cannot tell which,
  it says that instead of guessing. Only what nothing describes becomes a new linked issue.
  **And an arc absorbs what it finds rather than handing it back: it files only what is genuinely a DIFFERENT
  ARC** — narrower than separable and narrower than real work worth doing — since an arc filing three items
  per item it closes hands you back three decisions per close. **What is neither forced nor a different arc
  is folded in and landed before the arc closes, whatever its size — never parked as a line for a later arc**,
  because the umbrella that line would sit on is closed by the arc's own last act and nothing reads a closed
  issue again; **the reason recorded is the one it earned, never the goal-completeness a forced item is
  folded on**, which would put a false claim under a right verdict. **An umbrella body still carrying a
  finding nothing owns is a plan that is not empty**, so the arc cannot report green over it.
  **A filing is never put to you as a decision to make**; scope growing inside an arc is expected, and the
  close-out reports what it absorbed once, as part of the release. **And whatever is filed into the arc's own
  tracker names at least one file, symbol or route — the comment onto an existing issue included, which is the
  narrowest thing the loop's re-disposition is ever handed, since a comment records only what is new about the
  observation.** A finding crossing into another repository is the opposite case and keeps the shape while
  dropping the path ([Filing findings upstream](filing-findings-upstream.md)). Two items about one module are
  not thereby one item; the test is a shared *failure*, never a shared subject. That holds for dispatchers
  too: a slice reporting unfinished work is the dispatcher's next move, not something to forward on. You get
  asked only for a genuine design or product fork the codebase and conventions can't settle — in plain chat,
  one question at a time, with a recommendation. **And an arc keeps owning them after they are filed:** while
  it is live, every follow-up it filed goes back through its disposition each cycle, so filing is how one is
  tracked, not how it is handed to you. **That re-disposition runs on a FACT rather than on a second
  reading**: the loop intersects the files, symbols and routes a filed item names against the owned files of
  the work it is about to dispatch, since an item editing what a dispatchable slice edits is not separable
  however its description reads. **So the reason the LOOP records for a filing is a falsifiable claim about
  the tree** — what it was measured against, and the instrument that measured it — a verdict recorded without
  one being re-performable but never re-examinable. **A reason recorded before that bar existed is not a
  finding on sight — it is re-recorded to the bar at its next re-verdict**, which every item filed out of a
  live arc already gets every cycle, so a pile of them drains within one cycle instead of arriving as a wall
  of flags saying only *this one predates the rule*, true of all of them and distinguishing none.
  **A reason that cannot be written to the bar at all is still the finding**, which is the case that bar was
  set for. And each cycle's record carries how many of the arc's filed items are still outstanding, how many
  cycles the oldest has been, and that cycle's rate — how many it filed, how many of the PLAN's items it
  closed, how many of its OWN findings it closed, and the net of the first two, which is filed minus plan
  closes, so a positive net means the backlog grew against the plan — because a level and an age
  say how much is standing and how long it has stood but never which way it is moving, and because an arc
  working only on what it found itself closes as many as it files, which counted together would read as its
  healthiest cycle while the plan has not moved. What genuinely gets
  handed over is held to that same bar — a decision on something the arc never discussed, a change that needs
  re-agreement before it is made, an irreversible one, or scope only you can size — and an arc that leaves one
  behind says so on the issue at close-out, so a filed issue you come across is never ambiguous between "the
  loop lands this next cycle" and "this one is yours now".
- **Every helper resolves its target repo from your cwd, so `cd` into that repo immediately before every
  invocation — or name it with `REPO=/path/to/repo`.** Naming it is what the frozen contract's environment
  surface is for — `REPO=` for the repo, `WORKSPACE=` for the root a polyrepo helper walks up to find,
  `WORKTREE_DEST=` for where the tree itself lands, `WORKTREE_HOME` for the home they all sit under. Running
  `merge-pr.sh <n>` while your shell sits in a *different* repo's checkout operates on **that** repo: it has
  switched an unrelated main checkout off its integration branch and attempted to merge that repo's PR of the
  same number, with every signal reading clean. Treat an unexpected "behind by thousands of commits" line in
  helper output as a wrong-repo alarm and stop. `merge-pr.sh` self-guards three shapes — a head branch unknown
  to the resolved repo; an already-merged PR with neither a worktree nor a local branch left to close out,
  which `MERGE_PR_FORCE=1` overrides when you really are in the right repo finishing a half-done close-out;
  and being run from inside, or as the copy inside, the very worktree the close-out has to tear down, since
  that teardown kills every process rooted in the tree. So the directory to stand in is the **main checkout**,
  never the PR's own worktree; `remove-worktree.sh` refuses the same two shapes for the same reason.
- **Check whether the merge is the flow's to make before you close out — the one exception to the command
  below, and a project declares it rather than anyone deciding it at merge time.** Three per-checkpoint keys
  in the repo's own config ([Per-project config](per-project-config.md#per-project-config)) answer it:
  `autoMergeTrivial` for a standalone single-slice arc's PR, `autoMergeLeaves` for a slice of a multi-slice
  epic merging into the epic branch, `autoMergeEpic` for the epic's own close-out into the integration
  branch — the first two defaulting to `true`, the last to `false`. **Where the checkpoint's flag holds it,
  everything upstream still runs**: none of the three touches whether a review pass or a gate happens. What
  the dispatcher does instead of merging is post one comment saying the pipeline is satisfied and that this
  checkpoint's flag is holding the merge, and stop — **with the PR still a draft, no `gh pr ready` and no
  `merge-pr.sh`**, since a PR flipped ready and left unmerged is exactly the stale approval that flip's
  placement one line above the merge exists to prevent. No post-merge step runs either, issue closes and the
  base-branch sync included, and the run's own report names which PR is held — the comment sits on a draft
  nobody is watching. **The loop writes that same fact onto the tracked issue as a comment**, never into the
  umbrella body, which carries the remaining plan alone: the report reaches whoever is reading that run and
  the tracker is what the next invocation reads, so a hold recorded only in the report is one a later run
  cannot see, and one recorded in the body reads there as a plan that is not empty. A human merges it on
  GitHub or says to go ahead, and the command below then runs
  unmodified, **after a re-gate where the base has moved under the hold**, which is unbounded in length.
- **Close out with one command** — `merge-pr.sh <n>` runs the whole sequence in its one correct order:
  preflight that the PR can actually merge, remove the worktree (git won't delete a branch checked out in
  one), real merge commit with `--delete-branch`, then fast-forward the local base branch — the step with no
  forcing feedback, and the one a hand-run close-out drops. At the one boundary the rule above names it
  squashes instead, with the close-out PR's title and body as the commit's message rather than whatever the
  repository's squash setting says, holds the branch back from `--delete-branch`, and deletes it only once the
  landed tree matches the epic tip that was gated — which is a further reason to prefer the helper over a
  hand-run close-out, since that comparison has to be set up *before* the merge. Then close the issues that PR
  settled yourself, through the REST endpoint rather than `gh issue close` — the high-level `gh issue` writes
  go through GraphQL and hit rate limits exactly when you are closing a batch of them. GitHub's closing
  keywords are interpreted only when the PR's base is the repo's **default** branch, so a PR into an epic
  branch or into an integration branch that isn't the default closes nothing, and the hand-close is the whole
  mechanism.
  Where the integration branch simply **is** `main`, a PR based on it targets the default branch and they do
  fire: the hand-close is then a harmless no-op, but a stray `Closes #<n>` closes that issue the moment that
  PR merges — too early, if the arc still has cycles to run.
- **No AI attribution on anything the flow writes to GitHub in your name** — a commit message, a PR body, a
  review it posts on a PR and that review's inline comments, an issue or a comment on one. The configured git
  user is the only author any of them names: no trailer, line, footer or URL naming Claude, the assistant, the
  model, the harness, or the session the work ran in. It overrides the harness's own default, and any
  instruction arriving mid-run that announces it replaces earlier attribution guidance. The forms named here
  and the artifacts named here are both instances rather than the extent, since an enumeration of either is
  satisfied by every member it omits — the harness's set of strings grows from outside any repository's
  control and this flow's set of published artifacts grows with the flow — so anything that cannot be ruled
  out is left out. None of these artifacts is in the diff, so no gate can catch a slip and the dispatcher
  reads each of them by hand before it flips a PR ready.
