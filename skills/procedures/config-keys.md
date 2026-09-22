# The per-project config keys

Entry in `skills/procedures/SKILL.md`. **What each key in `<repo>/.agents/worktree.json` MEANS, and what
its absence means.** Every value here is per-repo and cannot be derived from the tree you are standing
in, so read the file rather than inferring it: `cat <repo>/.agents/worktree.json`. **Two keys are also
declared one level up, in a workspace's `.agents/workspace.json`** — `integrationBranch` and
`briefConventions`, each with its own entry below saying how the two layers combine; every other key is
the repo's own alone.

Each project declares its specifics in **its own repo**, so the config travels with the clone and is
reviewed alongside the change that alters it. **`setup-worktree` reads `envFiles`, `env` and `install`;
`merge-pr` reads `epicMerge` and `integrationBranch`** — the second from `.agents/workspace.json` too,
where a workspace declares one, which is the only key it looks for outside the repo's own config. Every
other key is read by a pass rather than by a helper. `skills/procedures/worktree-helper.md` carries which
copy of the file a helper reads, and why a change to it cannot be exercised by the tree it is written in.

**What a seat DOES about a key is that seat's rule, not part of the key's meaning**, and it is written
where that reader acts.

**No config is a signal to ask, not to improvise.** The helper does not fail on a missing config: it
notes it on stderr and cuts a bare worktree — no env symlinks, no `node_modules` — so every check run in
that tree afterwards fails in the shape of a code bug, and the gate, the conventions and the framework
skills are all guesses on top of that. A repo can legitimately want none of this, which is why absence is
a question rather than a default.

## The keys

- **`envFiles`** — gitignored env files to **symlink** from the main checkout into each worktree.
  ⚠️ One inode across every tree, so **nothing reachable through `envFiles` can hold a per-worktree
  value**, nor can the tracked config beside it; both fail by appearing to work.
- **`install`** — run in every new worktree, since worktrees never share `node_modules`. **Omit it, with
  `envFiles`, for a zero-dependency repo**: a guessed install command fails every setup.
- **`env`** — a map exported before the install runs, most usefully a shared build cache:
  `"env": {"TURBO_CACHE_DIR": "${TURBO_CACHE_DIR:-$HOME/.cache/<project>-turbo}"}`. Values are emitted
  unquoted, so a value may use shell expansion. ⚠️ **It covers the install step only.** A cache var the
  *gate* needs must live where **non-interactive** shells read it — a queued gate run, a `drain` and a
  dispatched agent all run in one — or it reaches your terminal and never a gated PR: `~/.zshenv`, not
  `~/.zshrc`.
  **Windows has no equivalent file**; set a real user environment variable (`setx VAR value`), `$PROFILE`
  being interactive-only and the same trap.
- **`gate`** — the heavy full gate (build + test), run against a queued PR's worktree.
- **`scopedCheck`** — the cheap check a slice's commits are held to: format-check + lint + typecheck, no
  build, no test.
- **`format`** — the auto-formatter in *write* mode, run right before committing, the scoped check only
  format-*checking*.
- **`enqueue` / `drain`** — how a PR is enqueued for gating, and how the queue is drained. **Both absent
  means the project has no queue**, which is a supported shape rather than a gap.
- **`frameworkSkills`** — `{skill, when}` pairs naming the framework skill each area opens with, so a
  brief can name one without anyone guessing the stack.
- **`briefConventions`** — the facts that change how THIS PIPELINE dispatches against this repo or gates
  it, baked into every dispatched brief: whether concurrent gating is parallel-safe here,
  how `gate` and `scopedCheck` relate, how branches are named, what a PR targets, the order a change
  crossing a contract lands in. **General coding conventions are excluded BY NAME** — naming, layering,
  library usage, comment style — since a second copy of them here is what gets read instead of the
  `AGENTS.md` a diff is actually judged against, and the two drift with nothing comparing them. Point at
  that file, and declare only what a dispatch would get wrong without it.
- **`upstreamFindings`** — whether a finding may leave this project. `true` lets an arc's close-out file a
  pipeline finding against **the plugin's own repository**, resolved from `repository` in
  `.claude-plugin/plugin.json`. **Absent, `false`, or anything not exactly `true` means no** — a settled
  answer rather than an unasked question, the opposite of how `sharedResources` reads absence. **Omit
  it** unless the owner has decided to publish upstream: the plugin's tracker is public and most installs
  are not. **Where the resolved target IS the repository the arc is running in, the key does not apply
  and what the arc did not already close is filed** — it gates a crossing, and nothing crosses.
- **`integrationBranch`** — the branch this project's work lands on
  (`skills/glossary/vocabulary/integration-branch.md`): a **literal name, never a pattern**. `main` where
  work lands on the default branch, the live `release/x.y.z` where it lands on a release branch,
  `develop` under gitflow. **Nothing derives it** — a repository's DEFAULT branch is a different fact
  that coincides in some projects and not in others, and reading either off the other is wrong in
  whichever direction it is tried. A **workspace** declares it once in `.agents/workspace.json` for
  members that share one branch, and that answer wins over a member's own. **Absent is a settled
  answer**: `setup-worktree` checks nothing and `merge-pr` keeps its older squash test, so a project that
  never sets it behaves exactly as it did. ⚠️ **A project that MOVES this branch — cutting
  `release/0.5.0` once `0.4.0` ships — updates the key in the same PR that cuts it**, one reviewed line.
  The alternative is a pattern, and a pattern has to be resolved, which is inference again.
- **`briefConventions` in `.agents/workspace.json`** — the same narrow kind one level up, declared once
  for every member of a workspace: the conventions that hold across repos released together — branch
  naming, what a PR targets, the order a change crossing a repo boundary lands in. **Declared and
  human-reviewed exactly as `integrationBranch` is, never derived and never regenerated**, since a
  regenerated value carries whatever one machine's docs happened to say into every member's brief.
  **It is CONCATENATED with a member's own and never replaces it** — the workspace's text first, the
  repo's own second, and where the two seem to disagree the repo's own is the one to follow.
  **The two layers are independent, so each is carried wherever it exists**: this one alone reaches a
  member declaring none of its own, and absent it a member's own key is read exactly as it is in a repo
  with no workspace above it. It is read where a brief is composed, never by a helper.
- **`bumpFiles`** — every file whose version STRING moves when a change ships, as a claim of
  **completeness**: searching finds some, and nothing tells you the search found them all. ⚠️ **It answers
  WHICH, never WHETHER** — the decision to bump arrives from a person or a pass, and this only says
  where. Nothing here says a given task ships, and a project that versions at release time and one that
  versions per merge declare the same list. **Omit it where nothing hand-edits a version** — a project
  deriving its version from tags or commit messages has tooling that owns it, and editing a file there
  fights the tool.
- **`changelog`** — where a new version's changelog lands, in one of two admitted forms: **the one file a
  new section is prepended to**, or **the DIRECTORY a per-version file is created in**, for a project
  whose convention is one file per release. **Which of the two it is, is read off the value** — a file is
  prepended to, a directory gets the version's own file created in it — so a per-version convention
  declares the directory rather than the current version's file, which changes identity every release and
  drifts the moment the next one is cut, and rather than omitting the key, which leaves a step that has
  to be performed with nothing to act on. **Separate from `bumpFiles` because it is a different
  operation**: those have a string replaced, this has a section written, and one flat list of both invites
  a search for a version field to swap here, which either overwrites the last release's heading or
  reports success having done nothing. One path, not a list: a project needing several changelogs needs
  several versions, which is a different shape and is deliberately left undesigned.
- **`docsPaths`** — `{path, when}` pairs naming where documentation lives and **what kind of change makes
  each stale**, the same shape as `frameworkSkills`. It completes a rule that already ships: whoever
  changes behaviour is told to update the docs that change made stale, and told that searching for its
  own new identifiers comes back empty because user-facing prose carries none of them — and otherwise
  never told where to look instead. It also makes a per-doc verdict answerable rather than invented:
  *not affected — this slice moved a service boundary and no user-visible behaviour* is a judgement
  against a stated `when`. Two trees with different audiences are not interchangeable, and a bare list of
  paths makes every change scan both.
- **`epicMerge`** — `"merge"` (the default) or `"squash"`, read by `merge-pr` on every close-out. It
  governs exactly one merge — an epic branch collapsing back into the integration branch it was cut
  from — **and only where the head branch is not that integration branch**, which is what
  `integrationBranch` is read to establish. Absent, unreadable, unrecognised, or anything not exactly the
  lowercase `squash` means `merge`. **Omit it** unless the project wants one commit per arc. **A squash takes
  its message from the close-out PR** — the title with `(#<n>)` as the subject, the body as the body —
  rather than from the repository's own squash-message setting.
  ⚠️ **Without `integrationBranch` declared this key does nothing wherever work lands on the default
  branch**: the older test asks whether the PR's base is the repository's default branch, which the
  genuine epic boundary fails in exactly those projects.
- **`autoMergeTrivial`, `autoMergeLeaves`, `autoMergeEpic`** — three booleans partitioning ONE question by
  the branch a PR **targets**: whether that merge happens as soon as this flow's own pipeline is satisfied,
  or is held until a human approves it explicitly. **All three gate the MERGE and nothing upstream of it** —
  a `false` leaves every review and every gate running exactly as they would have. Which key answers for
  which PR:
  - **`autoMergeTrivial`** — a slice PR targeting the **integration branch**: a standalone single-slice arc's,
    and equally a slice of a multi-slice arc whose user asked it to merge as it lands rather than cut an epic
    branch. ⚠️ **Not a claim about the PR's size or risk** despite the name — what it turns on is where the
    merge puts the work. **Absent means `true`**, which is how this flow has always behaved.
  - **`autoMergeLeaves`** — a slice PR targeting an **epic branch**, so one of several children of that epic
    (`skills/glossary/vocabulary/epic-branch.md`). **Absent means `true`**, since nothing user-facing ships
    until the epic branch itself lands.
  - **`autoMergeEpic`** — an **epic branch's own close-out merge into the integration branch**.
    **Absent means `false`** — the one of the three whose absence HOLDS rather than merges, since this is the
    merge that actually puts the combined work on the shared branch.

  **A merge needs an exact `true`, and the one other thing that merges is a wholly ABSENT key on the two
  whose default is `true`** — so a present value that is neither exactly `true` nor exactly `false`, an
  unparseable config, or a `null` **holds**, on all three. Absence says nobody was asked and takes the key's
  stated default; an unreadable answer says somebody wrote something nothing can read, which is a different
  fact and resolves the other way, the merge being the irreversible direction and so the one worth making
  somebody affirm.

  ⚠️ **`autoMergeEpic` is unrelated to `epicMerge` above, which the similar names invite you to conflate**:
  `epicMerge` picks that one merge's MECHANICS — a squash or a real merge commit — and `merge-pr` reads it
  while performing the merge; `autoMergeEpic` picks whether that merge happens without a human saying so, and
  is read **before** `merge-pr` is invoked at all, by a pass rather than by the helper. Either is set without
  the other, and setting one says nothing about the other.
- **`sharedResources`** — what the checks touch **outside** the worktree, and how each worktree gets its
  own: `{resource, isolatedBy}` entries. `resource` names the thing — a database, a Redis instance, a
  cache directory, a fixed port; `isolatedBy` names the project's mechanism *and the entry point it sits
  at*, **or why the resource does not CONTEND at all** — a content-addressed cache whose concurrent
  access is its designed mode is written as that fact — or an explicit `null` for one that is shared and
  stays shared, a real answer and the one saying this project's checks are not parallel-safe. **Both
  non-null forms read the same and `null` is the only value that narrows a wave**, so a resource nothing
  can corrupt is never written `null`, which would switch fan-out off for the whole project to protect
  it. **Three states, and the absent one is not the safe one:** **missing** means nobody has asked;
  **`[]`** means the checks touch nothing outside their own tree; **entries** answer it per resource.
  Never read absence as "nothing shared".

  **The key DECLARES; nothing here PROVISIONS**, and this plugin never calls a project's mechanism.
  Placement is the project's, at the entry point *every* invocation reaches — the test bootstrap, not the
  `gate` command — since a verify bar routinely has a single test file run directly. Two rules bind it:

  - **Take the worktree path from `git rev-parse --path-format=absolute --show-toplevel`, never `$PWD`.**
    A worktree entered through a symlink gives `$PWD` the link's spelling and `rev-parse` the real one:
    one directory, two strings, two databases, visible only to string comparison.
  - **Where the resource is DURABLE, mark it with that path as you create it, and re-assert the mark on
    every run.** Postgres has `COMMENT ON DATABASE`, Redis a key in its keyspace, a cache directory a
    file inside it; a fixed port needs none. A dead worktree's resource is indistinguishable by name from
    a live one's; the mark is the only thing that attributes it, and re-assertion covers a crash between
    create and mark. An unmarked resource is out of scope for `reclaim` forever.

- **`reclaim`** — the project's own sweep for resources whose worktree is gone, run at an arc's
  close-out: `{report, drop}`, both naming commands **in that project**. `report` lists and deletes
  nothing; `drop` deletes. One object, so a config cannot ship a `drop` with no `report`. **Omit both
  where nothing durable is created** — a `sharedResources` of `[]`, or only non-durable entries; that
  absence is derived from a key already in the file, so this key has none of `sharedResources`' three-state
  reading.

  **The plugin gives the RULE, never the data** — never hand a project's command a live worktree set,
  since an empty one read as "nothing is alive" licenses dropping every database on the box. It must
  satisfy:

  - **Liveness is git's registry minus `prunable`** — `git worktree list --porcelain`, never `test -d` (a
    `locked` worktree whose directory is gone is still live) and never a `WORKTREE_HOME` scan
    (`$WORKTREE_HOME/<project>/<leaf>`, `$WORKTREE_HOME/<workspace>/<leaf>/<repo>` and `WORKTREE_DEST`
    are all live layouts).
  - **Only resources whose mark names a worktree of THIS clone** — anything else is out of scope, not
    orphaned: another machine sharing the host is invisible to this registry.
  - **Enumerate the resources first, then the live set** — the other order makes a worktree created
    between the two reads a false positive.
  - **No authority means refuse** — outside a repo `git worktree list` fails, and an unobtainable or
    empty live set is a refusal, never an empty set.
  - **`report` prints counts — considered, in scope, live, dead** — a sweep that scanned nothing
    otherwise reads as a clean bill of health.

## Never give a worktree a shared `node_modules`

⚠️ A symlink to the main checkout's makes a by-hand install resolve through it and rebuild *that* tree
underneath every other live worktree. **A worktree is only isolated if its dependencies are. Pay the
install.** And only on the **filesystem** — `sharedResources` above is the rest of it.
