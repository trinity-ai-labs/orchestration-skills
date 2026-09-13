# The worktree helpers

Entry in `skills/procedures/SKILL.md`. **The command-line contract of the helpers this plugin ships, and
it is FROZEN** — the arguments, the recovery form, what a run creates, what it prints, and what it
refuses. Read it before you run one, and before you accept a tree somebody else ran one to make.

**Nothing here says when to cut a tree or what to do with the result.** That differs by seat and is
written where each seat acts.

## `setup-worktree` — creating a tree

**`setup-worktree.sh <branch> <base>`, both required.** It ships in this plugin's `bin/`, alongside its
siblings `merge-pr.sh` / `remove-worktree.sh`; **whether it resolves as a bare command or needs an
absolute path is per-host, and so is the extension — `skills/procedures/host-tools.md` settles both.** It
auto-detects the project and reads that project's `.agents/worktree.json`, so it works the same for any
repo.

Run it from **anywhere inside the target repo** — the root, a subdirectory, a monorepo subpackage, or
even a linked worktree, since it walks up to the repo's common gitdir. If cwd is not inside the repo,
prefix `REPO=/path/to/repo`.

- `<branch>` = full name of the branch to create (any prefix: `feat/…`, `fix/…`, `refactor/…`,
  `docs/…`); the worktree directory is named after the segment past the last slash
  (`feat/toasts-top-right` → `toasts-top-right`).
- `<base>` = the branch to fork from, with **no default**, since an integration branch rolls over often
  and a hardcoded default just goes stale. It errors early with a `git fetch` hint if `<base>` is not a
  local ref yet.

**It creates the worktree at `$WORKTREE_HOME/<project>/<branch-leaf>`, symlinks the config's `envFiles`,
and runs `install`** (`skills/procedures/config-keys.md` carries what those keys mean). Every branch is
treated the same, docs included: a worktree always gets its own install, so it is always self-contained
and can face any check the project has.

`WORKTREE_HOME` defaults to `~/.worktrees`, **except on Windows, where it defaults to
`%LOCALAPPDATA%\wt`** — a worktree path there carries a whole dependency tree
(`…/<repo>/node_modules/.pnpm/<pkg>@<version>/…`), and from `~/.worktrees` that routinely exceeds
Windows' 260-character `MAX_PATH`, which surfaces as an install failing on some deeply nested filename
rather than on the length. Setting `WORKTREE_HOME` yourself still overrides it everywhere. Two more
Windows-only notes worth knowing before you read a worktree's stderr as a code bug: `setup-worktree.sh`
warns when `git config core.longpaths` is unset (the same `MAX_PATH` ceiling, from git's side), and it
warns when an env file was **copied** rather than symlinked — Git Bash's `ln -s` silently copies unless
Windows Developer Mode is on, and a copy is a snapshot, so later edits in the main checkout stop
reaching the worktree.

## The two lines it prints, and the refusals behind them

**A successful run finishes by printing two lines on stdout — `READY: <path>` and then `HEAD: <sha>`, the
commit the tree actually landed on.** In the new-branch mode it will not print them at all unless the
tree it is handing back **contains** `<base>`.

⚠️ **That containment refusal is WEAKER than an equality comparison against a freshly fetched remote
tip, in both what it compares and what it compares against, so it does not discharge one.**
**Ancestor, not equal:** a tree carrying commits on top of the base passes, because a caller re-attaching
to a tree that has legitimately advanced must not be refused. **The main checkout, not `origin`:** a
local base branch that is itself behind the remote is an ancestor of everything cut from it, so a stale
base passes here. A tree in either state prints an entirely ordinary `READY:`/`HEAD:` pair.

⚠️ **A `READY:` line also warrants that the install SUCCEEDED — so its absence after a failed one is the
refusal, not an omission.** Both ports fail the same way and say the same thing: a message naming the
worktree, stating that the tree was created and is being **left standing** so it can be diagnosed, that
its install did not complete, and that re-running the same command reuses the tree and retries the
install — then exit 1, with no `READY:` line at all. Read a missing `READY:` as an instruction not to
dispatch into that tree, and re-run rather than reaching in by hand.

**And a `READY:` line is not by itself evidence the branch was created — the branch read-back is.** Where
the target directory is already occupied by a tree standing on another branch, the helper reads the
branch back, finds the other one, and refuses with no `READY:` line and a non-zero exit. Two branches
whose leaf segment is the same resolve to the same directory, which is how that collision arises.

## `--existing` — attaching a tree to a branch that already has one gone

**`setup-worktree.sh --existing <branch>`** attaches a worktree to a branch that already exists, instead
of creating one. Reach for it when a **branch outlived its tree**: a `merge-pr.sh` that failed at the
merge after tearing the worktree down, a tree removed by hand or lost to a cleanup, a branch to pick
back up after its close-out was interrupted. It takes **no base** — an existing branch's base is whatever
it already forked from, so there is nothing for a second argument to mean. If only `origin/<branch>`
survives (the local branch is deleted on every successful merge), it recreates a local branch tracking
the remote and attaches to that; if the branch does not exist at all it **stops** rather than creating
one, because the fallback would silently fork off whatever HEAD it found. Everything downstream is
identical to a fresh worktree — env symlinks, the config's `env`, a real install — so a re-attached tree
can face the gate like any other.

⚠️ **It is a flag, never an inference — do not reach for it just because the branch exists.** Attaching
to a pre-existing branch when you meant to fork off `<base>` is the stale-base seeding this contract
warns about hardest, and it arrives silently: the tree is real, the install is real, and only its HEAD is
wrong. Use the two-argument form for new work, always. **`--existing` takes no base, so the containment
refusal above does not run there at all** — the branch read-back still does.

## Every helper resolves its target repo from your CWD

⚠️ **Running `merge-pr.sh <n>` while your shell sits in a *different* repo's checkout operates on THAT
repo** — switching an unrelated main checkout off its integration branch onto the default branch and
attempting to merge *that repo's* PR `<n>`, same number, wrong project, with every signal reading clean.
When working across multiple repos, `cd` into the target repo immediately before EVERY helper
invocation, and treat an unexpected "behind by thousands of commits" line in helper output as a
wrong-repo alarm: stop and verify before anything else runs.

`merge-pr.sh` also self-guards: it refuses when the PR's head branch is unknown to the resolved repo;
when an already-merged PR has no worktree or local branch left to close out — `MERGE_PR_FORCE=1`
overrides that one; and when the copy being run, or the directory it is being run from, is **inside the
worktree the close-out has to tear down**, because that teardown kills every process rooted in the tree
and the close-out would be one of them. So the directory to stand in is the **main checkout**, never the
PR's own worktree, and `cd`-ing into a worktree to merge its PR is the shape that gets refused.
`remove-worktree.sh` refuses the same two shapes for the same reason.

## The main checkout is the one piece of shared mutable state

⚠️ **A branch you did not touch that has moved is an alarm, not a curiosity.** Every worktree is isolated
by construction; the main checkout is not, and in a multi-session shop several sessions reach into the
same one. So `merge-pr.sh` never switches it: a base branch that is not the checked-out one is synced
without touching the checkout at all — fast-forwarded inside whatever linked worktree is standing on it,
or moved by **ref** (`fetch` + `branch -f`) when none is — and the helper fails loudly if the checkout is
on a different branch, or a different commit, than when it started: a close-out that switches the
checkout while another session switches it back mid-sync leaves the local base branch pointing at some
other branch's merge commit, commits of unrelated work and all, while `origin/<branch>` advances
independently; nothing is pushed, so there is no remote damage and no signal either, until the next
worktree cut from that branch forks off a poisoned base. Treat any report that the checkout moved, or any
local branch pointing somewhere you never merged, as a **stop**: re-point it at `origin/<branch>` and
verify before anything else runs.

## The config it reads is the MAIN checkout's working copy, as a file on disk

**Which is why a change to that config cannot be exercised by the tree it is written in.** The helper
resolves the main checkout from the repo's common gitdir, so it finds the same one from any cwd — the
root, a subdirectory, a linked worktree, or an explicit `REPO=` — then reads
`<main checkout>/.agents/worktree.json` out of that tree. **No ref enters the lookup, `<base>`
included**; `merge-pr` reads `epicMerge` and `integrationBranch` from the same copy, and a workspace's
`integrationBranch` from the manifest beside it. So a change adding an `envFiles` entry, altering
`install`, or introducing a new key is provisioned from the **pre-change** config, as is every worktree
cut anywhere while that change is unmerged.

**Two routes look like they get round that and neither does.** Reading the config from the branch being
cut changes nothing — at cut time the new branch equals its base, and provisioning necessarily precedes
the work that changes provisioning. Cutting a **second** worktree once the branch is pushed changes
nothing either: the lookup consults no ref, so a fetch moves nothing it reads. **The window closes at the
merge that reaches the tree the helper reads** — where the change lands through an intermediate branch,
that is the merge of the intermediate branch and not the one inside it, so every tree cut in between is
provisioned the old way.

⛔ **Editing the main checkout's working tree so the helper sees the change early is REJECTED.** It is the
one thing that would work, and it writes to the shared mutable state above, provisioning another
session's worktree from an unmerged config with nothing anywhere to tell it.
