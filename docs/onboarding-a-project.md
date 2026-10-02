## Onboarding a new project

Run **`/pipeline:setup`** in that repo. It grounds the commands in the repo's real lockfile, scripts, and CI,
writes `.agents/worktree.json`, and scaffolds a durable gate queue *into that repo* if the project wants one —
the plugin carries the knowledge, the project owns the code, so each queue can evolve independently.

**What it cannot ground, it asks you** — and everything it asks belongs to one class: the values no file in
your repo could contain, so expect to be asked and read no list of them as closed.
**What your checks touch that lives outside the worktree** — a database, a Redis instance, a cache directory,
a fixed port — and what gives each worktree its own: that becomes `sharedResources`, and "nothing" is an
answer worth recording rather than a key to leave out. **Where that answer was not "nothing", the follow-on:
what drops what the isolation creates, once the worktree is gone?** Nothing in this plugin does —
`remove-worktree` takes the tree and knows nothing the tree made — so where you already have a sweep, its two
commands become `reclaim`; where you do not, setup hands the gap back rather than writing one for you.
**And one that is not a fact about your repo at all — consent:** may a run that finds a defect in *the
pipeline itself* write it into this plugin's own public repository — opening an issue about it, or commenting
on one already describing that failure? That is `upstreamFindings`
([Filing findings upstream](filing-findings-upstream.md#filing-findings-upstream-off-by-default)), it is put
flat with no case made for it, and only an explicit yes writes anything.

**It also checks the shape of your agent guidance, and says so first when it is a mess.** The layout it looks
for: at each directory that carries guidance an `AGENTS.md` that is a *router* — what the directory is, the
rules true for every change there, its commands, and a table routing each topic to a *rule chapter* under
`.agents/rules/` — with every `CLAUDE.md` reduced to the one line `See [AGENTS.md](AGENTS.md).`, so an agent
loads the routers for where it works and only the chapter for what it is doing. Guidance is a *monolith* by
its shape, never its length: topic rules written straight into a router, a description of the code (a stack
list, a schema or route inventory, an architecture tour) in guidance at all, a `CLAUDE.md` holding content,
or one rule stated in two places. Found one, setup leads with it — every agent the pipeline dispatches loads
all of it on every slice — and splits it in its own PR beside the config, listing every line it dropped
rather than moved so you can object to each. `/pipeline:orchestrate` runs the same check before an arc and
puts a monolith at the top of its report, pointing back here; it never stops over one and never edits your
guidance itself. No config key controls any of this.

It verifies by cutting a real worktree and round-tripping a ticket, then tears the worktree down. Where you
named an isolation mechanism it cuts a **second** worktree and runs the real gate in both at once, because two
runs colliding is not observable in one run, and then reverses the mechanism to confirm the collision
reproduces — an entry that instead names why the resource does not contend has no mechanism to reverse, so
there the overlap alone is what it can report. Where you declared a `reclaim` it runs the report on **both**
sides of the teardown, since a sweep that calls everything dead and a correct one are the same output on a box
with one worktree. Where it scaffolded a queue the verification goes past that happy path too, because a round
trip comes back green whether or not the queue holds up where a dispatcher later leans on it: it also asks the
queue for its state read-only and confirms that asking moved nothing, puts two drains in contention to confirm
the blocked one says who holds the slot rather than sitting silent, and enqueues a ticket with no PR to
confirm the runner either settles it with the verdict on the ticket or refuses it outright rather than
spending a full gate on a verdict it can never deliver. Both answers are correct and they are not
interchangeable downstream: a runner that refuses is one scaffolded before that ticket shape, and the
dispatcher's mid-arc integration gate is then hand-run in a project that otherwise has a working queue — which
is the one case every "where the project has no queue" fallback in the flow structurally cannot cover, so the
check reports which of the two it got rather than just that the queue held.

To do it by hand instead: add `.agents/worktree.json` to that repo, declaring the keys in
[Per-project config](per-project-config.md#per-project-config), and commit it. Read the repo's agent guidance,
its package scripts, and its CI to fill in the commands rather than guessing.

**Onboarding is not the only job this command has — an artifact that is already there may be *behind*, and run
again it reconciles rather than onboards.** A config is ground once, on the day the repo was onboarded, and
nothing re-establishes it afterwards: CI renames the gate script, a lockfile changes package manager, an
`envFiles` entry is deleted, the suite starts touching a service nothing declares — and the file goes on
saying what was true that day. Run `/pipeline:setup` again and it re-grounds the repo as it stands now and
hands back a **per-key delta**: *agrees*; *drifted*, saying what the repo now says rather than only that it
differs; or *declared but unverified*, for the values no file can confirm — the ones you were asked for, which
stay yours. **The delta runs the other way too: a key the config declares that this plugin no longer reads is
named as such**, since a value set there governs nothing while looking set, and where the plugin renamed that
key the report names its replacement — no old name is honoured as an alias, so the rename is yours to make.
`/pipeline:orchestrate` names the same keys in its dispatch report before an arc, and edits nothing. A gate
queue scaffolded against an older spec gets the same treatment one level over, as a
per-invariant delta against the reference, and the agent guidance gets its shape checked again, a monolith
reported first and split in its own PR exactly as on onboarding. For the config and the queue it **reports
and never rewrites**, for one reason that covers both: a divergence can be deliberate, an overwrite cannot tell a deliberate one from a stale one, and
so it would destroy both. **Run it between arcs, never inside one** — once worktrees are live the config is
frozen for the arc, so a mid-arc delta is measured against the very file every live worktree was already
provisioned from, and acting on it writes to the one piece of shared state another session may be cutting a
worktree from at that moment. Nothing detects staleness for you and nothing tries to: establishing it *is* the
reconcile, so this is a pass you ask for — after a check fails on a command the repo no longer has, after the
helper cannot find an env file, after a red that only appears when two worktrees run at once.

A repo with no config still cuts a worktree — but a **bare** one, with no env symlinks and no install. Where
the project has an install step that worktree is unusable: it has no `node_modules`, so every check inside it
fails for reasons that read as code bugs, and the run burns before anyone reads the stderr warning. Don't
dispatch into it. For a **zero-dependency** repo a bare worktree is the only kind there is and it works fine —
this repo is one, and its own config landed through a normal PR — but you still want the config, because
without it the gate and the conventions are things a dispatcher has to guess, and a guessed gate passes while
testing nothing.
