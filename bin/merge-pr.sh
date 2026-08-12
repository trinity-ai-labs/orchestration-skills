#!/usr/bin/env bash
# Merge a reviewed PR and clean up — the atomic close-out of the worktree flow.
#
#   merge-pr.sh <pr-number>
#
# Run it from ANYWHERE inside the target repo (or set REPO=). It performs the
# whole "Merge & cleanup" sequence as ONE command, in the one correct order, so
# no load-bearing step can be dropped:
#
#   1. Resolve the MAIN checkout + the PR's base (integration) and head branch.
#   2. Preflight the PR's mergeability, BEFORE anything irreversible happens — the
#      two steps that follow cannot be undone by a later failure, and the step
#      that actually fails is the last one. A conflicting PR stops here with the
#      worktree intact and the PR still a draft.
#   3. Remove the head branch's worktree — git refuses to delete a branch that's
#      still checked out in a worktree, so `gh pr merge --delete-branch` would
#      error on the local-branch step if the worktree still existed. Done via
#      remove-worktree.sh, which kills processes rooted in the tree first.
#   4. Mark the PR ready — the orchestrator's review approval — and immediately
#      `gh pr merge --merge --delete-branch` it: a real merge commit (never
#      squash), deleting both the local and remote branch. A merge that fails
#      anyway puts the draft flag back before it exits.
#   5. Sync the MAIN checkout's local copy of the PR's base branch to the
#      just-merged tip — by ref when that branch is not the one checked out.
#   6. Verify the main checkout is still standing where it was when the run began.
#
# Step 5 is the whole reason this helper exists. `gh pr merge` advances the branch
# on the REMOTE; the local base branch in the main checkout does NOT move. Syncing
# it is a manual step with NO forcing feedback — every visible signal (`✓ Merged`,
# branch deleted, PR closed) says "done", so it's the step that gets silently
# skipped, and the miss only surfaces later when the NEXT worktree is cut from a
# stale HEAD. Worse, hand-run as `git checkout <base> && git pull` from inside a
# worktree, the checkout fails ("already used by worktree at …") and `&&` swallows
# the pull — so the sync silently never happens. This helper anchors every git call
# to the MAIN checkout with `git -C "$MAIN"`, independent of cwd, and only ever
# moves the branch FORWARD (the main checkout never carries direct commits, so a
# non-ff means something is wrong and should surface loudly, not merge-commit past).
#
# The main checkout is the one piece of global mutable state in a flow that is
# otherwise isolated per worktree, and several sessions share it — so step 5 never
# switches it. A base branch that is not the checked-out one is moved as a REF
# (`fetch` + `branch -f`), which needs no working tree, and step 6 then confirms
# nothing else moved the checkout meanwhile.
#
# Idempotent: if the PR is already merged, it skips the merge and still runs the
# worktree teardown + local sync, so a re-run finishes a half-done close-out.
set -euo pipefail

# --- Windows/MSYS path helpers -----------------------------------------------
# Under Git Bash on Windows `git` prints Windows-form paths (C:/Users/…) while
# anything derived from $HOME is MSYS-form (/c/Users/…). The filesystem accepts
# both, so a mismatch is never an error — only string comparison can see one,
# which makes every resulting failure silent. So every value that is later
# compared, grepped, or prefix-matched goes through norm_path at the point of
# production. Off Windows there is no cygpath and this is the identity function.
#
# Duplicated verbatim in each bin/*.sh rather than sourced: bin/ ships on a
# user's PATH under the parity rule that pairs every bin/<name>.sh with a
# bin/<name>.ps1, so a shared file would become a fifth helper owing a
# PowerShell sibling that has nothing to do — PowerShell has no MSYS form to
# convert — and sourcing would make each script resolve a sibling path at
# runtime, the exact bug class this script already shipped once.
norm_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

is_windows() {
  case "$(uname -s 2>/dev/null)" in
  MINGW* | MSYS* | CYGWIN*) return 0 ;;
  *) return 1 ;;
  esac
}

# On Windows the default home is %LOCALAPPDATA%/wt, not ~/.worktrees: a path like
# ~/.worktrees/<workspace>/<leaf>/<repo>/node_modules/.pnpm/<pkg>@<version>/… runs
# past MAX_PATH's 260 characters as a matter of routine, and the install then fails
# naming some deeply nested file rather than the length that actually broke it. An
# explicitly set WORKTREE_HOME still wins everywhere, unchanged.
#
# This has to agree with setup-worktree.sh's default exactly: the wrong-repo guard
# below decides "is there anything to close out here?" from whether a worktree
# exists under $WORKTREE_HOME, so a default that disagreed would look at an empty
# directory and refuse to close out a perfectly normal merged PR.
worktree_home_default() {
  if is_windows && [ -n "${LOCALAPPDATA:-}" ]; then
    printf '%s/wt\n' "$(norm_path "$LOCALAPPDATA")"
  else
    printf '%s/.worktrees\n' "$HOME"
  fi
}

WORKTREE_HOME="${WORKTREE_HOME:-$(worktree_home_default)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# printf '%b' rather than echo, so a message can carry the `\n` its recovery
# instructions need: bash's builtin echo prints those two characters verbatim, so a
# multi-line message written with it arrives as one line with a literal \n inside —
# and the PowerShell sibling, whose `\n` IS a newline, would then say something the
# bash side does not.
die() { printf 'merge-pr: error: %b\n' "$*" >&2; exit 1; }

if [ $# -lt 1 ]; then
  echo "usage: merge-pr.sh <pr-number>" >&2
  echo "  e.g. merge-pr.sh 2094" >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 1
fi

PR="$1"
REPO="${REPO:-$PWD}"

command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) not found on PATH"

# Resolve the MAIN working tree — same logic as setup-worktree.sh / remove-worktree.sh.
if ! COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  die "not inside a git repo: $REPO\n  run from inside the target repo, or set REPO=/path/to/repo"
fi
COMMON=$(norm_path "$COMMON")
MAIN=$(dirname "$COMMON")

# gh resolves the repo from cwd, so run every gh call from the MAIN checkout.
pr_field() { ( cd "$MAIN" && gh pr view "$PR" --json "$1" -q ".$1" ); }

# The path of the worktree that has $1 checked out, or empty if no worktree does.
# `git branch -f` refuses to move a branch that is checked out ANYWHERE, so the
# ref-only sync in step 4 has to know before it tries — and a linked worktree
# standing on the PR's base means a session is working there, which is a state to
# report rather than an error to force past.
worktree_holding() {
  git -C "$MAIN" worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
    /^worktree / { wt = substr($0, 10) }
    $0 == ref    { print wt; exit }
  '
}

STATE=$(pr_field state) || die "could not read PR #$PR (is the number right? is gh authed?)"
INTEGRATION=$(pr_field baseRefName)
HEAD_BRANCH=$(pr_field headRefName)
[ -n "$INTEGRATION" ] || die "PR #$PR has no base branch"

echo "merge-pr: PR #$PR  state=$STATE  base=$INTEGRATION  head=$HEAD_BRANCH  main=$MAIN"

# Where the main checkout stands BEFORE this run touches anything. Step 5 checks it
# is still here at the end: nothing in this helper switches the checkout, so any
# movement came from another session, and step 4's verification cannot see it —
# that check proves the BASE reached the merged tip and has no opinion about a
# DIFFERENT branch having moved instead, which is the half that corrupts.
# `--abbrev-ref HEAD` prints the literal "HEAD" on a detached checkout, which
# compares as its own value and needs no special case.
START_BRANCH=$(git -C "$MAIN" rev-parse --abbrev-ref HEAD)
START_HEAD=$(git -C "$MAIN" rev-parse HEAD)

# Stop the run if the main checkout is no longer on the branch it started on.
# Called before every advance in step 4 as well as over the finished run in step 5,
# because the on-base decision that picks step 4's path is made once and then used
# across a retry loop — and on that path `merge --ff-only` names no branch, so it
# moves WHATEVER is checked out at the moment it runs. A switch landing in between
# would fast-forward another session's branch toward this PR's base, which is the
# corruption this helper exists to prevent rather than to relocate.
assert_checkout_unmoved() {
  NOW_BRANCH=$(git -C "$MAIN" rev-parse --abbrev-ref HEAD)
  [ "$NOW_BRANCH" = "$START_BRANCH" ] || die "the main checkout $MAIN was on '$START_BRANCH' when this run started and is on '$NOW_BRANCH' now — this helper never switches it, so another process moved it mid-run. PR #$PR IS merged, but the local sync of '$INTEGRATION' may be incomplete: check where '$START_BRANCH' and '$NOW_BRANCH' point before cutting any worktree off either."
}

# --- 0. Wrong-repo guard ---------------------------------------------------------
# The repo is resolved from cwd/REPO, so a shell sitting in a DIFFERENT repo's
# checkout makes every step below operate on that repo — same-numbered PRs exist
# everywhere, so the gh calls above still "succeed" and nothing else would catch
# it. Verify PR #$PR actually belongs to this working set before touching anything.
LEAF="${HEAD_BRANCH##*/}"
PROJECT=$(basename "$MAIN")
# A workspace member's worktree lives at $WORKTREE_HOME/<workspace>/<slug>/<project>
# (setup-worktree.sh:68), not the bare $WORKTREE_HOME/<project>/<slug> layout used
# outside a workspace — so the existence check below must accept either, or it
# misfires "wrong repo" for every workspace member even when its worktree is
# exactly where setup-worktree.sh put it.
WORKSPACE_ROOT="$(dirname "$MAIN")"
WORKSPACE_WT=""
if [ -f "$WORKSPACE_ROOT/.agents/workspace.json" ]; then
  WORKSPACE_WT="$WORKTREE_HOME/$(basename "$WORKSPACE_ROOT")/$LEAF/$PROJECT"
fi
if [ "$STATE" = "MERGED" ]; then
  # Idempotent-rerun case: finishing a half-done close-out implies SOME local
  # residue — a worktree in either layout, or the local head branch. Neither
  # existing means there is nothing to close out here: almost certainly the
  # wrong repo.
  if [ ! -d "$WORKTREE_HOME/$PROJECT/$LEAF" ] \
     && { [ -z "$WORKSPACE_WT" ] || [ ! -d "$WORKSPACE_WT" ]; } \
     && ! git -C "$MAIN" show-ref --verify --quiet "refs/heads/$HEAD_BRANCH" \
     && [ "${MERGE_PR_FORCE:-}" != "1" ]; then
    die "PR #$PR is already MERGED and neither a worktree ($WORKTREE_HOME/$PROJECT/$LEAF${WORKSPACE_WT:+ or $WORKSPACE_WT}) nor a local branch '$HEAD_BRANCH' exists in $MAIN — nothing to close out here. WRONG REPO? cd into the intended repo and re-run (or MERGE_PR_FORCE=1 to run teardown+sync here anyway)."
  fi
else
  git -C "$MAIN" show-ref --verify --quiet "refs/heads/$HEAD_BRANCH" \
    || git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/$HEAD_BRANCH" \
    || { git -C "$MAIN" fetch --prune origin >/dev/null 2>&1 && git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/$HEAD_BRANCH"; } \
    || die "PR #$PR's head branch '$HEAD_BRANCH' is unknown in $MAIN (not local, not on origin) — WRONG REPO? The repo is resolved from cwd/REPO; cd into the intended repo and re-run."
fi

# --- 1. Mergeability preflight ---------------------------------------------------
# Everything past this point is irreversible, and the step that can actually fail —
# the merge — is the last one. A PR whose base moved under it fails there with
# "Pull Request has merge conflicts", by which point the worktree teardown has
# already removed the only tree the conflict could be resolved in and the review
# flag has already been flipped. So ask GitHub whether the merge is possible while
# nothing has been touched yet, and stop clean if it is not.
#
# `mergeable` is computed asynchronously: GitHub answers UNKNOWN while its test
# merge is still running, which is the ordinary answer for a PR pushed seconds ago.
# UNKNOWN means "not yet known" — neither CONFLICTING nor fine — so it is polled a
# few times and then FALLS THROUGH rather than blocking. Hard-failing on UNKNOWN
# would make this helper flaky on exactly the PRs that just arrived, and the merge
# in step 3 is a truthful authority for the case the poll could not resolve.
if [ "$STATE" != "MERGED" ]; then
  MERGEABLE=$(pr_field mergeable 2>/dev/null || true)
  for attempt in 1 2 3; do
    if [ "$MERGEABLE" = "MERGEABLE" ] || [ "$MERGEABLE" = "CONFLICTING" ]; then
      break
    fi
    echo "merge-pr: mergeability not computed yet (attempt $attempt/3) — waiting ..."
    sleep 2
    MERGEABLE=$(pr_field mergeable 2>/dev/null || true)
  done
  if [ "$MERGEABLE" = "CONFLICTING" ]; then
    # Name the worktree the caller has to resolve it in — setup-worktree.sh puts it
    # at one of exactly two paths, decided by whether this repo sits in a workspace.
    CONFLICT_WT="${WORKSPACE_WT:-$WORKTREE_HOME/$PROJECT/$LEAF}"
    die "PR #$PR conflicts with '$INTEGRATION' — nothing has been touched: the worktree is intact and the PR is still a draft.\n  Resolve it in the branch's own worktree, by merging the base IN (never rebase — these branches are never rewritten):\n    cd $CONFLICT_WT\n    git fetch origin && git merge origin/$INTEGRATION\n    <resolve, commit, push>\n  If that worktree is gone, re-attach one first: setup-worktree.sh --existing $HEAD_BRANCH\n  Then re-gate the PR and re-run: merge-pr.sh $PR"
  fi
fi

# --- 2. Remove the head branch's worktree --------------------------------------
# Before the merge, so `--delete-branch` can remove the local branch — the ordering
# git forces, and the reason step 1 exists: it is only safe to tear the tree down
# once the merge is known to be possible. remove-worktree.sh is idempotent (no-ops
# if the worktree is already gone) and derives the worktree path from the branch
# leaf against this same repo.
if [ -n "$HEAD_BRANCH" ]; then
  echo "merge-pr: tearing down worktree for $HEAD_BRANCH ..."
  REPO="$MAIN" "$HERE/remove-worktree.sh" "$HEAD_BRANCH"
fi

# --- 3. Merge (unless already merged) ------------------------------------------
if [ "$STATE" = "MERGED" ]; then
  echo "merge-pr: PR #$PR already merged — skipping merge, finishing the local sync."
else
  # `draft -> ready` is the orchestrator's review approval — the one thing in the
  # flow that says a human-in-the-loop read this diff, as opposed to a gate saying
  # the suite passed (the gate reports by PR comment and never touches this flag).
  # GitHub refuses to merge a draft, so the flip has to precede the merge; it sits
  # one line above it so `ready` can never be a stale badge, since the step-2
  # teardown kills processes rooted in the worktree and can take real time, and a
  # flip before that would leave a window where the PR reads as approved but is not
  # merged. `gh pr ready` on an already-ready PR is a no-op, so the flip itself is
  # unconditional and idempotent on re-run.
  #
  # `isDraft` is read anyway, and read HERE rather than with the fields at the top,
  # because it has one job: to say whether THIS run is what set the flag. Only then
  # may the failure path put it back — a PR that arrived already ready keeps the
  # state it came with rather than being pushed into a draft nobody asked for.
  WAS_DRAFT=$(pr_field isDraft 2>/dev/null || true)
  echo "merge-pr: marking PR #$PR ready (review approval) ..."
  ( cd "$MAIN" && gh pr ready "$PR" )
  echo "merge-pr: merging PR #$PR (real merge commit, deleting branch) ..."
  if ! ( cd "$MAIN" && gh pr merge "$PR" --merge --delete-branch ); then
    # The flag must not SURVIVE a merge that failed. A non-draft PR that is not
    # being merged right this second reads, everywhere else in this flow, as a diff
    # an orchestrator approved — so leaving it set would have the PR wearing a
    # review it never received. This matters most when step 1 answered UNKNOWN and
    # fell through: the conflict it could not rule out surfaces exactly here.
    DRAFT_NOTE="it was already non-draft before this run and is left that way"
    if [ "$WAS_DRAFT" = "true" ]; then
      if ( cd "$MAIN" && gh pr ready "$PR" --undo ); then
        DRAFT_NOTE="it is back to a draft"
      else
        DRAFT_NOTE="its draft flag could NOT be restored — put it back by hand: gh pr ready $PR --undo"
      fi
    fi
    die "merging PR #$PR failed — $DRAFT_NOTE, and its worktree has already been torn down (step 2).\n  Re-attach a tree to the branch, fix it there, and re-run:\n    setup-worktree.sh --existing $HEAD_BRANCH\n    cd <the READY: path it prints> && git fetch origin && git merge origin/$INTEGRATION\n    <resolve, commit, push>   (merge the base IN — never rebase)\n    merge-pr.sh $PR"
  fi
fi

# --- 4. Sync the local base branch in the MAIN checkout --------------------------
# Anchored to MAIN so it works regardless of the caller's cwd, and only ever moving
# the branch forward: the main checkout never carries direct commits (all work lands
# via PR merge on the remote), so a non-ff means an anomaly that should stop loudly.
#
# Which of the two paths runs is decided by whether the base is the branch the main
# checkout is standing on:
#
#   on it      -> `merge --ff-only`, exactly as before; no switch is needed and the
#                 working tree follows the branch it is already on.
#   not on it  -> move the REF (`fetch` + `branch -f`), which needs no working tree.
#
# The ref-only path is what makes a shared main checkout safe. Switching to the base
# opens a window in which another session's own switch lands, and everything after
# it then operates on whatever is checked out at that moment rather than on the base
# — observed: a slice PR based on an epic branch switched the checkout off the
# release branch, another session put it back mid-sync, and the local release branch
# was left pointing at the epic branch's merge commit, six commits of unrelated work,
# while origin/release had independently advanced. Not switching removes the window
# entirely, and leaves nothing to switch back afterwards.
ON_BASE=0
if [ "$START_BRANCH" = "$INTEGRATION" ]; then ON_BASE=1; fi

if [ "$ON_BASE" -eq 0 ]; then
  BASE_WT=$(worktree_holding "$INTEGRATION")
  [ -z "$BASE_WT" ] || die "'$INTEGRATION' is checked out in the worktree $BASE_WT, so its ref cannot be moved from here — git refuses to move a branch any worktree is standing on, and someone is standing on this one. PR #$PR IS merged; only the local sync is outstanding.\n  Finish it from that worktree:\n    git -C $BASE_WT pull --ff-only\n  Until then do NOT cut new worktrees off '$INTEGRATION' — the local ref is behind the merged tip."
fi

# `gh pr merge` returns before GitHub is guaranteed to serve the new tip, so a sync
# fired immediately can advance to nothing and silently leave the branch on the
# PRE-merge commit — while a `rev-parse` in the done-message still prints a sha and
# reads as "synced." That is the "said synced, wasn't" bug. So: poll-fetch until the
# remote actually carries the merge commit, advance each round, and VERIFY the local
# branch truly reached the merged tip. The message is never proof; the ref-equality
# check below is — and on failure we die loudly, never lie.
MERGE_OID=$( cd "$MAIN" && gh pr view "$PR" --json mergeCommit -q '.mergeCommit.oid' 2>/dev/null || true )
echo "merge-pr: syncing local '$INTEGRATION' to the merged tip ..."
synced=""
diverged=""
for attempt in 1 2 3 4 5 6; do
  git -C "$MAIN" fetch --prune origin >/dev/null 2>&1 || true
  assert_checkout_unmoved
  if [ "$ON_BASE" -eq 1 ]; then
    git -C "$MAIN" merge --ff-only "origin/$INTEGRATION" >/dev/null 2>&1 || true
  elif git -C "$MAIN" show-ref --verify --quiet "refs/heads/$INTEGRATION" \
    && ! git -C "$MAIN" merge-base --is-ancestor "$INTEGRATION" "origin/$INTEGRATION" 2>/dev/null; then
    # `branch -f` is a force move, so it is the one path here that could DISCARD
    # commits. The local branch carrying something the remote does not is a stable
    # condition — the remote only ever advances — so stop on it rather than retrying.
    diverged=1
    break
  else
    # Creates the branch when the main checkout has no local copy of it, which is
    # the ordinary state for an epic branch a session never checked out.
    git -C "$MAIN" branch -f "$INTEGRATION" "origin/$INTEGRATION" >/dev/null 2>&1 || true
  fi
  LOCAL=$(git -C "$MAIN" rev-parse --verify --quiet "refs/heads/$INTEGRATION" || true)
  REMOTE=$(git -C "$MAIN" rev-parse --verify --quiet "refs/remotes/origin/$INTEGRATION" || true)
  if [ -n "$LOCAL" ] && [ "$LOCAL" = "$REMOTE" ] && { [ -z "$MERGE_OID" ] || \
       git -C "$MAIN" merge-base --is-ancestor "$MERGE_OID" "$INTEGRATION" 2>/dev/null; }; then
    synced=1
    break
  fi
  echo "merge-pr: remote not serving the merge yet (attempt $attempt/6) — waiting ..."
  sleep 2
done
[ -z "$diverged" ] || die "local '$INTEGRATION' carries commits 'origin/$INTEGRATION' does not, so moving its ref would discard them — REFUSED, and the local branch is untouched. PR #$PR IS merged; only the local sync is outstanding.\n  Inspect what is on it and reconcile it by hand:\n    git -C $MAIN log --oneline origin/$INTEGRATION..$INTEGRATION\n  Until then do NOT cut new worktrees off '$INTEGRATION'."
[ -n "$synced" ] || die "local '$INTEGRATION' did NOT reach the merged tip (merge commit ${MERGE_OID:-unknown} still absent after retries) — SYNC FAILED; do NOT cut new worktrees off '$INTEGRATION' until this is resolved."

# --- 5. Verify the main checkout did not move under us ---------------------------
# Step 4's verification proves the BASE reached the merged tip. It has no opinion
# about a branch that moved INSTEAD — which is the half that actually corrupts, and
# is silent: every other signal reads as a successful close-out. Nothing here
# switches the checkout, so a branch or HEAD that differs from where the run started
# was moved by another process, and saying so is the difference between an immediate
# stop and a poisoned base the next worktree forks from.
assert_checkout_unmoved
# Only off the base: standing ON it, HEAD is the very ref step 4 verified against the
# merged tip, so comparing it to the start commit would assert nothing but that the
# sync happened. Off it, this run moved a DIFFERENT branch's ref and never touched
# the working tree, so any movement at all is another process's.
if [ "$ON_BASE" -eq 0 ]; then
  NOW_HEAD=$(git -C "$MAIN" rev-parse HEAD)
  [ "$NOW_HEAD" = "$START_HEAD" ] || die "the main checkout $MAIN is still on '$START_BRANCH' but its HEAD moved from $START_HEAD to $NOW_HEAD — this run only moved the ref of '$INTEGRATION', which is a different branch, so another process moved '$START_BRANCH' mid-run. Check where it points before cutting any worktree off it."
fi

echo "merge-pr: done — PR #$PR merged, worktree removed, local '$INTEGRATION' synced to $(git -C "$MAIN" rev-parse --short "$INTEGRATION"), main checkout still on '$START_BRANCH'."
