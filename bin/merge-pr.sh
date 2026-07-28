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
#   2. Remove the head branch's worktree FIRST — git refuses to delete a branch
#      that's still checked out in a worktree, so `gh pr merge --delete-branch`
#      would error on the local-branch step if the worktree still existed. Done
#      via remove-worktree.sh, which kills processes rooted in the tree first.
#   3. Mark the PR ready — the orchestrator's review approval — and immediately
#      `gh pr merge --merge --delete-branch` it: a real merge commit (never
#      squash), deleting both the local and remote branch.
#   4. Sync the MAIN checkout's local integration branch to the just-merged tip.
#
# Step 4 is the whole reason this helper exists. `gh pr merge` advances the branch
# on the REMOTE; the local integration branch in the main checkout does NOT move.
# Syncing it is a manual step with NO forcing feedback — every visible signal
# (`✓ Merged`, branch deleted, PR closed) says "done", so it's the step that gets
# silently skipped, and the miss only surfaces later when the NEXT worktree is cut
# from a stale HEAD. Worse, hand-run as `git checkout <integration> && git pull`
# from inside a worktree, the checkout fails ("already used by worktree at …") and
# `&&` swallows the pull — so the sync silently never happens. This helper anchors
# every git call to the MAIN checkout with `git -C "$MAIN"`, independent of cwd,
# and fast-forwards only (the main checkout never carries direct commits, so a
# non-ff means something is wrong and should surface loudly, not merge-commit past).
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

die() { echo "merge-pr: error: $*" >&2; exit 1; }

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

STATE=$(pr_field state) || die "could not read PR #$PR (is the number right? is gh authed?)"
INTEGRATION=$(pr_field baseRefName)
HEAD_BRANCH=$(pr_field headRefName)
[ -n "$INTEGRATION" ] || die "PR #$PR has no base branch"

echo "merge-pr: PR #$PR  state=$STATE  base=$INTEGRATION  head=$HEAD_BRANCH  main=$MAIN"

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

# --- 1. Remove the head branch's worktree FIRST --------------------------------
# So `--delete-branch` can remove the local branch. remove-worktree.sh is
# idempotent (no-ops if the worktree is already gone) and derives the worktree
# path from the branch leaf against this same repo.
if [ -n "$HEAD_BRANCH" ]; then
  echo "merge-pr: tearing down worktree for $HEAD_BRANCH ..."
  REPO="$MAIN" "$HERE/remove-worktree.sh" "$HEAD_BRANCH"
fi

# --- 2. Merge (unless already merged) ------------------------------------------
if [ "$STATE" = "MERGED" ]; then
  echo "merge-pr: PR #$PR already merged — skipping merge, finishing the local sync."
else
  # `draft -> ready` is the orchestrator's review approval — the one thing in the
  # flow that says a human-in-the-loop read this diff, as opposed to a gate saying
  # the suite passed (the gate reports by PR comment and never touches this flag).
  # It sits here, one line above the merge, so `ready` can never be a stale badge:
  # the step-1 teardown above kills processes rooted in the worktree and can take
  # real time, and a flip before it would leave a window where the PR reads as
  # approved but is not merged. Inside the not-yet-MERGED branch it is also
  # idempotent on re-run, and `gh pr ready` on an already-ready PR is a no-op, so
  # nothing needs to read `isDraft` first.
  echo "merge-pr: marking PR #$PR ready (review approval) ..."
  ( cd "$MAIN" && gh pr ready "$PR" )
  echo "merge-pr: merging PR #$PR (real merge commit, deleting branch) ..."
  ( cd "$MAIN" && gh pr merge "$PR" --merge --delete-branch )
fi

# --- 3. Sync the local integration branch in the MAIN checkout ------------------
# Anchored to MAIN so it works regardless of the caller's cwd. Fast-forward only:
# the main checkout never carries direct commits (all work lands via PR merge on
# the remote), so a non-ff pull means an anomaly that should stop us loudly.
CUR=$(git -C "$MAIN" rev-parse --abbrev-ref HEAD)
if [ "$CUR" != "$INTEGRATION" ]; then
  echo "merge-pr: main checkout is on '$CUR'; switching to '$INTEGRATION' ..."
  git -C "$MAIN" checkout "$INTEGRATION"
fi

# `gh pr merge` returns before GitHub is guaranteed to serve the new tip, so a pull
# fired immediately can fast-forward to nothing ("Already up to date") and silently
# leave the branch on the PRE-merge commit — while a `rev-parse HEAD` in the done-
# message still prints a sha and reads as "synced." That is the "said synced, wasn't"
# bug. So: poll-fetch until the remote actually carries the merge commit, fast-forward
# each round, and VERIFY the local branch truly reached the merged tip. The message is
# never proof; the ref-equality check below is — and on failure we die loudly, never lie.
MERGE_OID=$( cd "$MAIN" && gh pr view "$PR" --json mergeCommit -q '.mergeCommit.oid' 2>/dev/null || true )
echo "merge-pr: syncing local '$INTEGRATION' to the merged tip ..."
synced=""
for attempt in 1 2 3 4 5 6; do
  git -C "$MAIN" fetch --prune origin >/dev/null 2>&1 || true
  git -C "$MAIN" merge --ff-only "origin/$INTEGRATION" >/dev/null 2>&1 || true
  LOCAL=$(git -C "$MAIN" rev-parse "$INTEGRATION")
  REMOTE=$(git -C "$MAIN" rev-parse "origin/$INTEGRATION")
  if [ "$LOCAL" = "$REMOTE" ] && { [ -z "$MERGE_OID" ] || \
       git -C "$MAIN" merge-base --is-ancestor "$MERGE_OID" "$INTEGRATION" 2>/dev/null; }; then
    synced=1
    break
  fi
  echo "merge-pr: remote not serving the merge yet (attempt $attempt/6) — waiting ..."
  sleep 2
done
[ -n "$synced" ] || die "local '$INTEGRATION' did NOT reach the merged tip (merge commit ${MERGE_OID:-unknown} still absent after retries) — SYNC FAILED; do NOT cut new worktrees off '$INTEGRATION' until this is resolved."

echo "merge-pr: done — PR #$PR merged, worktree removed, local '$INTEGRATION' synced to $(git -C "$MAIN" rev-parse --short "$INTEGRATION")."
