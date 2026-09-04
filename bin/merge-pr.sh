#!/usr/bin/env bash
# Merge a reviewed PR and clean up — the atomic close-out of the worktree flow.
#
#   merge-pr.sh <pr-number>
#
# Run it from ANYWHERE inside the target repo (or set REPO=). It performs the
# whole "Merge & cleanup" sequence as ONE command, in the one correct order, so
# no load-bearing step can be dropped:
#
#   1. Resolve the MAIN checkout + the PR's base (integration) and head branch,
#      and decide which merge MODE this one boundary gets (see below).
#   2. Preflight the PR's mergeability, BEFORE anything irreversible happens — the
#      two steps that follow cannot be undone by a later failure, and the step
#      that actually fails is the last one. A conflicting PR stops here with the
#      worktree intact and the PR still a draft.
#   3. Remove the head branch's worktree — git refuses to delete a branch that's
#      still checked out in a worktree, so `gh pr merge --delete-branch` would
#      error on the local-branch step if the worktree still existed. Done via
#      remove-worktree.sh, which kills processes rooted in the tree first.
#   4. Mark the PR ready — the dispatcher's review approval — and immediately
#      `gh pr merge` it, deleting both the local and remote branch. A merge that
#      fails anyway puts the draft flag back before it exits.
#   5. Sync the local copy of the PR's base branch to the just-merged tip — in the
#      main checkout, in whatever linked worktree is standing on it, or by ref.
#   6. On the squash path ONLY: verify the merged tree against the epic tip that
#      was gated, and delete the branch once it matches.
#   7. Verify the main checkout is still standing where it was when the run began.
#
# The merge mode. Every merge here is a real merge commit, with exactly ONE
# exception a project may opt into: the epic buffer branch collapsing back into
# the integration branch it was cut from. That branch is scaffolding — it exists
# for one arc and is deleted at its end — so on a long-lived release branch a
# project may prefer one commit per arc to N slice merges plus a merge commit.
# It is declared up front in <repo>/.agents/worktree.json, never decided here:
#
#   { "epicMerge": "merge" }   // "merge" (the default) | "squash"
#
# Absent, unreadable, or anything but the exact string "squash" means "merge", so
# a typo cannot silently squash and no existing project changes behaviour. There
# is deliberately no argument, no environment variable and no flag for this: the
# helper CLI contract is frozen (AGENTS.md), and a per-merge switch is exactly the
# close-out-time history decision the config exists to prevent.
#
# Even under "squash" the boundary is one merge and one only, and TWO conditions
# have to hold for it. A slice -> epic merge stays a real merge commit with no
# opt-out (those merge commits are the epic's review record, and the integration
# gate's `^2` check reads their second parent), and single-slice work cuts no epic
# branch, so it has no buffer to collapse. What separates them is a RELATIONSHIP,
# never a branch name — no prefix is ever the key for anything in this flow — and
# the relationship IS the definition of an epic branch: it is the branch an epic's
# slices PR'd into. `gh pr list --base <head> --state merged` answers exactly that,
# and a slice branch and a single-slice branch both answer zero.
#
# That question alone would reach one merge it must never reach, because the branch
# work LANDS ON answers it too — every slice of every arc PR'd into it, so a
# long-lived `release/x.y.z` counts in the dozens. Under "squash" a
# `release/0.4.0 -> dev` close-out would therefore collapse the entire release
# branch, irreversibly, with the tree comparison passing and every signal reading
# clean. So the squash additionally requires that this head is NOT the branch work
# lands on, which is a question about the branch's LEVEL — and answering it needs
# one fact no repository carries: which branch that is.
#
#   { "integrationBranch": "main" }
#
# Declared, it settles directly: an epic branch sits ABOVE the integration branch, so
# a head that IS the integration branch is never a buffer to collapse. Nothing here
# is inferred from the repository's DEFAULT branch, which is a DIFFERENT fact — the
# two coincide in some projects and not in others, and reading either off the other
# is wrong in whichever direction it is tried.
#
# UNDECLARED, this helper falls back to what it did before: the PR's base is not the
# repository's default branch. That test stands in for the real question and holds
# only where the integration branch is not also the default branch, so undeclared it
# declines the genuine epic boundary in a project whose work lands on its default
# branch. Declaring the branch is what makes the option reachable there; the fallback
# exists so that upgrading changes no behaviour until a project does.
#
# Every way either question can fail to produce a usable answer — a network error,
# an empty response, a gh failure, a count of zero, a default branch that could not
# be determined, a declared model naming a branch this repo does not have, more than
# one live release branch — falls back to a real merge commit. A missed squash is
# cosmetic; a wrong squash is unrecoverable history.
#
# Before any of that it REFUSES to run when the copy being executed, or the directory
# it is being run from, sits inside the worktree step 3 tears down: that teardown
# kills every process rooted in the tree, and this process would be one of them. The
# guard below says why it refuses rather than re-execing from somewhere safe.
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
# switches it. A base branch that is not the checked-out one is advanced where it
# already lives: inside the linked worktree standing on it, or as a bare REF
# (`fetch` + `branch -f`) when none is. Step 7 then confirms nothing else moved the
# checkout meanwhile.
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

# A directory in PHYSICAL form: symlinks resolved, no trailing slash. The guard
# below decides whether two paths are the same tree by comparing them as strings,
# and one directory has more than one spelling — /tmp IS a symlink to /private/tmp
# on macOS, and git prints the resolved form while a caller's cwd carries whichever
# form they typed. Two spellings of one directory compare unequal, which makes a
# guard that silently never fires. A path that does not exist has nothing to
# resolve and comes back as it went in.
real_dir() { # real_dir <dir>
  (CDPATH='' cd -- "$1" 2>/dev/null && pwd -P) || printf '%s\n' "${1%/}"
}

# Is <candidate> the directory <tree>, or inside it? Anchored on the separator,
# exactly as remove-worktree.sh anchors its kill scan, so ".../1322-foo" cannot
# match ".../1322-foo-retry" — this decides a REFUSAL, and an over-eager match here
# would block a legitimate close-out rather than merely fail to prevent a bad one.
path_inside() { # path_inside <candidate-dir> <tree>
  case "$1" in
  "$2" | "$2"/*) return 0 ;;
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
CONFIG_REL=".agents/worktree.json"

# One scalar out of the project's own config, or nothing at all.
#
# Deliberately smaller than setup-worktree.sh's emit_config: that one hands back
# an array and an env map, so it has to emit shell for its caller to eval, while a
# single string travels out of a command substitution with no eval in the picture.
# What it copies verbatim is the INTERPRETER PROBE, because that part is not a
# convenience — on Windows `command -v python3` succeeds against the Microsoft
# Store's App Execution Alias, a stub that opens the Store and prints nothing, so
# a probe that only asks whether the name RESOLVES selects an "interpreter" whose
# empty output is indistinguishable from a config that declared nothing.
#
# Where setup-worktree.sh EXITS when nothing on PATH can parse JSON, this returns
# empty and the caller falls back to a real merge commit. That asymmetry is the
# point rather than leniency, and it comes from what the unreadable config costs
# each side. There, it yields a worktree with no env symlinks and no install — a
# broken tree wearing every appearance of a good one — so stopping is the only
# honest answer. Here it yields precisely today's behaviour, which is what every
# project that has never heard of this key already gets: the fallback IS the safe
# state, so an unreadable config costs a cosmetic miss, where refusing would break
# the close-out of every PR on a machine with neither node nor python over a key
# most projects never set.
read_config_scalar() { # read_config_scalar <config-path> <key>
  [ -f "$1" ] || return 0
  local -a runner=()
  local cand probe
  for cand in node python3 python py; do
    command -v "$cand" >/dev/null 2>&1 || continue
    case "$cand" in
    node)
      runner=(node)
      probe=$(node -e 'process.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    py)
      runner=(py -3)
      probe=$(py -3 -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    *)
      runner=("$cand")
      probe=$("$cand" -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    esac
    if [ "$probe" = "ok" ]; then break; fi
    runner=()
  done
  [ "${#runner[@]}" -gt 0 ] || return 0
  # A malformed config is swallowed here for the same reason a missing interpreter
  # is: the fallback is the non-destructive default, so there is nothing to warn
  # about that the merge itself will not already say plainly.
  if [ "${runner[0]}" = "node" ]; then
    node -e '
      const fs = require("fs");
      try {
        const value = JSON.parse(fs.readFileSync(process.argv[1], "utf8"))[process.argv[2]];
        if (typeof value === "string") process.stdout.write(value);
      } catch (err) { /* unreadable config reads as "not declared" */ }
    ' "$1" "$2" 2>/dev/null || true
  else
    "${runner[@]}" - "$1" "$2" 2>/dev/null <<'PY' || true
import json, sys
try:
    value = json.load(open(sys.argv[1])).get(sys.argv[2])
except Exception:
    value = None
if isinstance(value, str):
    sys.stdout.write(value)
PY
  fi
}

# --- The integration branch ------------------------------------------------------
# Work ends on the INTEGRATION branch: it is what worktrees are cut from, what slice
# PRs merge into, and what an epic branch collapses back onto. Which branch that is
# is the project's own fact and nothing here can derive it -- a repository's DEFAULT
# branch is a different fact that happens to coincide in some projects and not in
# others, and reading one off the other is wrong in whichever direction it is tried.
#
#   { "integrationBranch": "main" }
#
# A workspace declares it once for members that share one branch, and that answer
# wins. ABSENT, nothing keyed on it fires and this helper behaves exactly as before.
integration_branch() {
  local branch=""
  if [ -f "$WORKSPACE_ROOT/.agents/workspace.json" ]; then
    branch=$(read_config_scalar "$WORKSPACE_ROOT/.agents/workspace.json" integrationBranch)
  fi
  [ -n "$branch" ] || branch=$(read_config_scalar "$MAIN/$CONFIG_REL" integrationBranch)
  # A declared branch this repository does not have is a typo or a stale config, and
  # reading it anyway makes the comparison below a tautology that says yes to every
  # head. Unverifiable reads as undeclared, which is the direction this whole path
  # errs in.
  [ -z "$branch" ] || git -C "$MAIN" rev-parse --verify --quiet "$branch" >/dev/null 2>&1 || branch=""
  printf '%s' "$branch"
}

# Is this head a buffer the squash is allowed to collapse? One question, asked of
# the branch's LEVEL: an epic branch sits ABOVE the integration branch, so the head
# is never the integration branch itself. With none declared the older test stands,
# which is what leaves an undeclared project behaving exactly as it did.
#   squash_boundary_ok <integration-branch> <head> <base> <default-branch>
squash_boundary_ok() {
  local integration="$1" head="$2" base="$3" default="$4"
  if [ -n "$integration" ]; then
    [ "$head" != "$integration" ]
    return
  fi
  [ -n "$default" ] && [ "$base" != "$default" ]
}

# printf '%b' rather than echo, so a message can carry the `\n` its recovery
# instructions need: bash's builtin echo prints those two characters verbatim, so a
# multi-line message written with it arrives as one line with a literal \n inside —
# and the PowerShell sibling, whose `\n` IS a newline, would then say something the
# bash side does not.
die() { printf 'merge-pr: error: %b\n' "$*" >&2; exit 1; }

# Run a git call this helper assumes will succeed, putting its stdout in GIT_OUT.
#
# Left to `set -e` these stop the run MUTE and with GIT's status — 128 for most
# git failures — where every other refusal in this file exits 1 through die()
# with a message naming the helper. Two ports returning different codes for the
# same input is the drift the frozen contract exists to prevent, and nothing
# catches it: the parity check reads surface shape, not semantics. The message
# and the code here are the PowerShell sibling's Get-GitOutput, word for word.
#
# The output goes to a variable rather than to stdout because `exit` inside a
# command substitution only exits the SUBSHELL: `X=$(git_out …)` would report the
# failure and carry on running in the parent, and an interpolation inside a
# successful `echo` would not stop the run at all.
GIT_OUT=""
git_out() { # git_out <git-arg>… — sets GIT_OUT to git's stdout, or dies 1
  local status=0
  GIT_OUT=$(git "$@") || status=$?
  [ "$status" -eq 0 ] || die "git $* failed (exit $status)"
}

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
# `git branch -f` refuses to move a branch that is checked out ANYWHERE, so step 4
# has to know before it tries: a base standing in a linked worktree is advanced from
# inside that tree instead. Answering empty is not a failure — an epic branch whose
# worktree has been torn down is exactly that case, and the sync falls back to
# moving the ref.
worktree_holding() {
  git -C "$MAIN" worktree list --porcelain | awk -v ref="branch refs/heads/$1" '
    /^worktree / { wt = substr($0, 10) }
    $0 == ref    { print wt; exit }
  '
}

STATE=$(pr_field state) || die "could not read PR #$PR (is the number right? is gh authed?)"
BASE_BRANCH=$(pr_field baseRefName)
HEAD_BRANCH=$(pr_field headRefName)
[ -n "$BASE_BRANCH" ] || die "PR #$PR has no base branch"

echo "merge-pr: PR #$PR  state=$STATE  base=$BASE_BRANCH  head=$HEAD_BRANCH  main=$MAIN"

# A retired key is worse than an absent one: the project stated an intent and this
# version silently does not read it. Said HERE rather than left to a changelog,
# because the only reader who needs it is the one whose config has it, at the moment
# the merge is about to behave differently from what they declared.
RETIRED_IN=""
if [ -n "$(read_config_scalar "$WORKSPACE_ROOT/.agents/workspace.json" branchingModel)" ]; then
  RETIRED_IN=".agents/workspace.json"
elif [ -n "$(read_config_scalar "$MAIN/$CONFIG_REL" branchingModel)" ]; then
  RETIRED_IN="$CONFIG_REL"
fi
if [ -n "$RETIRED_IN" ]; then
  echo "merge-pr: note: $RETIRED_IN declares 'branchingModel', which this version no longer reads." >&2
  echo "  Declare 'integrationBranch' instead — the branch this project's work lands on." >&2
fi

# Where the main checkout stands BEFORE this run touches anything. Step 6 checks it
# is still here at the end: nothing in this helper switches the checkout, so any
# movement came from another session, and step 4's verification cannot see it —
# that check proves the BASE reached the merged tip and has no opinion about a
# DIFFERENT branch having moved instead, which is the half that corrupts.
# `--abbrev-ref HEAD` prints the literal "HEAD" on a detached checkout, which
# compares as its own value and needs no special case.
git_out -C "$MAIN" rev-parse --abbrev-ref HEAD
START_BRANCH="$GIT_OUT"
git_out -C "$MAIN" rev-parse HEAD
START_HEAD="$GIT_OUT"

# Stop the run if the main checkout is no longer on the branch it started on.
# Called before every advance in step 4 as well as over the finished run in step 6,
# because the on-base decision that picks step 4's path is made once and then used
# across a retry loop — and on that path `merge --ff-only` names no branch, so it
# moves WHATEVER is checked out at the moment it runs. A switch landing in between
# would fast-forward another session's branch toward this PR's base, which is the
# corruption this helper exists to prevent rather than to relocate.
assert_checkout_unmoved() {
  git_out -C "$MAIN" rev-parse --abbrev-ref HEAD
  NOW_BRANCH="$GIT_OUT"
  [ "$NOW_BRANCH" = "$START_BRANCH" ] || die "the main checkout $MAIN was on '$START_BRANCH' when this run started and is on '$NOW_BRANCH' now — this helper never switches it, so another process moved it mid-run. PR #$PR IS merged, but the local sync of '$BASE_BRANCH' may be incomplete: check where '$START_BRANCH' and '$NOW_BRANCH' point before cutting any worktree off either."
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

# --- Self-teardown guard ---------------------------------------------------------
# Step 2 hands the head branch's worktree to remove-worktree.sh, which kills every
# process rooted in that tree BEFORE removing it — found by lsof (open descriptors
# AND cwd) and by pgrep over the argv. Both of those find THIS process whenever
# merge-pr is running out of, or standing in, the very tree it is about to delete:
# by its script path, when the copy being executed is the one inside the worktree,
# and by its cwd, when the caller merely happens to be standing there. Either way
# the run is SIGTERMed in the middle of the teardown, and what that leaves is the
# worst shape a failure takes — the worktree gone, the PR NOT merged, and a
# transcript whose last lines are a teardown reporting success, because the orphaned
# child goes on printing after the process that would have merged is already dead.
#
# So refuse here, before the preflight and before anything has been touched.
# Refusing rather than re-execing a copy from somewhere safe: WHICH copy that would
# be is a guess — the installed one may be a different version, or absent entirely
# on the machine of someone whose checkout IS this repo — and silently running code
# the caller did not name is a poor trade on the one helper whose whole job is to be
# the final step.
#
# Both comparisons are string prefixes rather than a process scan, so they hold
# identically where the scan itself does not: under Git Bash neither lsof nor pgrep
# exists, and there the same overlap makes `git worktree remove` fail on files
# Windows has locked instead.
#
# Two forms of one answer, and they are not interchangeable. HEAD_WT keeps the path
# exactly as git printed it, because that is what step 2 HANDS to remove-worktree.sh
# — git matches its registry against what it recorded, and a resolved-through-symlink
# spelling of the same directory is a different string. DOOMED_WT is the physical
# form, because the guards below decide whether two paths are the same tree by
# comparing them, and one directory has more than one spelling.
#
# Step 2 reuses this value rather than asking again, and that is a correctness
# requirement rather than thrift: the guards below refuse the run when THIS process
# is rooted in the tree about to be torn down, so a second `worktree_holding` there
# could answer differently and the teardown would then be about a tree the guards
# never examined.
HEAD_WT=$(worktree_holding "$HEAD_BRANCH")
[ -z "$HEAD_WT" ] || HEAD_WT=$(norm_path "$HEAD_WT")
# A registration whose directory was deleted by hand still lists here. Handing that
# path over would send remove-worktree.sh down its absolute-path branch, where a
# missing directory it cannot resolve a repo from means it skips the prune that is
# the only thing left to do — so drop back to the branch name, which reaches it.
[ -z "$HEAD_WT" ] || [ -d "$HEAD_WT" ] || HEAD_WT=""
DOOMED_WT="$HEAD_WT"
[ -z "$DOOMED_WT" ] || DOOMED_WT=$(real_dir "$DOOMED_WT")
# The MAIN checkout is never what step 2 removes — a head branch that happens to be
# checked out there is not a tree this run will delete, and refusing on it would
# block a close-out launched from the one directory that is always safe. Blanking
# HEAD_WT with it is what keeps that true now that step 2 takes this path directly:
# the one path this run must never hand to a teardown is the main checkout's.
if [ "$DOOMED_WT" = "$(real_dir "$MAIN")" ]; then
  DOOMED_WT=""
  HEAD_WT=""
fi
if [ -n "$DOOMED_WT" ]; then
  if path_inside "$(real_dir "$HERE")" "$DOOMED_WT"; then
    die "this copy of merge-pr.sh lives at $HERE/merge-pr.sh, INSIDE the worktree this close-out has to tear down ($DOOMED_WT) — REFUSED, and nothing has been touched: the worktree is intact and PR #$PR is untouched.\n  The teardown kills every process rooted in that tree, and this one is rooted there: the run would be SIGTERMed mid-teardown, leaving the tree removed and the PR unmerged while the teardown printed a clean finish.\n  Run a copy that lives OUTSIDE that tree — bare off PATH is the installed one:\n    cd $MAIN\n    merge-pr.sh $PR"
  fi
  if path_inside "$(real_dir "$PWD")" "$DOOMED_WT"; then
    die "this run's working directory ($PWD) is INSIDE the worktree this close-out has to tear down ($DOOMED_WT) — REFUSED, and nothing has been touched: the worktree is intact and PR #$PR is untouched.\n  The teardown kills every process whose cwd is rooted in that tree, and this one's is: the run would be SIGTERMed mid-teardown, leaving the tree removed and the PR unmerged while the teardown printed a clean finish.\n  Re-run from outside that tree — the helper resolves the repo from cwd, so stand in the main checkout:\n    cd $MAIN\n    merge-pr.sh $PR"
  fi
fi

# --- Merge mode ------------------------------------------------------------------
# Three questions, all answered before anything irreversible happens, and ALL have
# to say yes for the squash path to be reachable. The order is a short-circuit: the
# config is a local file read, so a project that has not opted in never spends a
# gh call at all and behaves exactly as it does today.
#
#   1. Did the PROJECT declare it? Only the exact string "squash" counts. Absent,
#      unreadable, misspelled, or any other value is "merge".
#   2. Is this a boundary the squash is allowed to reach? The squashes are for an
#      epic buffer collapsing into the branch work lands on - never for that branch
#      itself moving on, which is a release event this flow does not perform. So the
#      question is the HEAD branch's LEVEL, and the declared integration branch
#      answers it: an epic branch sits above it, so a head that IS the integration
#      branch is never one.
#
#      Where the project declares none there is nothing to compare against and the
#      older test stands unchanged: a base that IS the repository's default branch
#      never squashes. That one reaches further than it means to, declining the
#      genuine epic boundary wherever work lands on the default branch, and
#      declaring the integration branch is how a project stops paying for it.
#   3. Is this the epic boundary? An epic branch is the branch an epic's slices
#      PR'd into, so asking GitHub how many merged PRs targeted the HEAD branch IS
#      the definition rather than a proxy for it. A slice branch and a single-slice
#      branch both answer 0, which is what keeps those two merges real without
#      needing a rule of their own.
#
# Every way questions 2 and 3 can fail to produce a usable answer - gh missing,
# unauthenticated, offline, rate-limited, a default branch that came back empty or
# unresolvable, a declared model naming a branch this repo does not have, more than
# one live release branch, a branch nobody PR'd into, a reply that is not a number -
# lands on "merge". The asymmetry is the whole design: a missed squash leaves a
# readable history that merely has more commits in it, while a wrong squash flattens
# an arc's commits off the integration branch irreversibly.
#
# The epic tip is captured HERE, before the merge, because the squash close-out
# below needs the commit that was gated in order to check what actually landed -
# and after the squash the PR no longer points at a branch that exists. Failing to
# capture it therefore
# falls back to "merge" as well: without that commit the squash path has no
# substitute for the ancestry check it breaks, and a squash whose result cannot be
# verified is exactly the unrecoverable case above.
MERGE_MODE="merge"
EPIC_TIP=""
if [ -n "$HEAD_BRANCH" ] && [ "$(read_config_scalar "$MAIN/$CONFIG_REL" epicMerge)" = "squash" ]; then
  INTEGRATION_BRANCH=$(integration_branch)
  # The repository's DEFAULT branch is only consulted where no integration branch is
  # declared -- it is the fallback's question, and asking it otherwise spends a gh
  # call on an answer nothing reads. gh (2.92) renders a null field as an empty line,
  # which is also what a failed call and a repository with no default branch produce,
  # while a raw `jq -r` prints the literal "null"; both are normalised to empty so a
  # single test covers them, and a branch genuinely named `null` is normalised with
  # them. On an answer that ambiguous, merge is the direction this path errs in.
  DEFAULT_BRANCH=""
  if [ -z "$INTEGRATION_BRANCH" ]; then
    DEFAULT_BRANCH=$( cd "$MAIN" && gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null ) || DEFAULT_BRANCH=""
    case "$DEFAULT_BRANCH" in
    '' | null) DEFAULT_BRANCH='' ;;
    esac
  fi

  BOUNDARY_OK=""
  if squash_boundary_ok "$INTEGRATION_BRANCH" "$HEAD_BRANCH" "$BASE_BRANCH" "$DEFAULT_BRANCH"; then
    BOUNDARY_OK=1
  elif [ -n "$INTEGRATION_BRANCH" ]; then
    echo "merge-pr: '$HEAD_BRANCH' IS this project's integration branch — a branch work lands on never collapses into one commit. Merging with a real merge commit."
  fi

  if [ -n "$BOUNDARY_OK" ]; then
    SLICE_PRS=$( cd "$MAIN" && gh pr list --base "$HEAD_BRANCH" --state merged --json number --jq 'length' 2>/dev/null ) || SLICE_PRS=""
    case "$SLICE_PRS" in
    '' | *[!0-9]*) SLICE_PRS=0 ;;
    esac
    if [ "$SLICE_PRS" -gt 0 ]; then
      EPIC_TIP=$( pr_field headRefOid 2>/dev/null || true )
      if [ -n "$EPIC_TIP" ]; then
        MERGE_MODE="squash"
        echo "merge-pr: '$HEAD_BRANCH' is an epic branch ($SLICE_PRS merged slice PR(s) targeted it) and this project declares epicMerge=squash — it collapses into one commit on '$BASE_BRANCH'."
      fi
    fi
  fi
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
  # CONFLICTING is provisional in exactly the same window as UNKNOWN, so it gets
  # the same treatment: confirmed across two consecutive reads before it is acted
  # on. Trusting the first one sends the caller to resolve a conflict that does not
  # exist — which costs a merge commit nobody needed, and teaches them that this
  # message does not mean what it says, on the one message that is the only warning
  # when the conflict IS real. An unconfirmed CONFLICTING falls through like an
  # unresolved UNKNOWN: step 3's merge is the truthful authority for both.
  MERGEABLE=$(pr_field mergeable 2>/dev/null || true)
  CONFLICT_READS=0
  for attempt in 1 2 3 4; do
    if [ "$MERGEABLE" = "MERGEABLE" ]; then
      break
    fi
    if [ "$MERGEABLE" = "CONFLICTING" ]; then
      CONFLICT_READS=$((CONFLICT_READS + 1))
      if [ "$CONFLICT_READS" -ge 2 ]; then
        break
      fi
      echo "merge-pr: GitHub reports CONFLICTING (read 1 of 2) — confirming, since a PR pushed seconds ago can answer from a test merge that has not finished ..."
    else
      CONFLICT_READS=0
      echo "merge-pr: mergeability not computed yet (attempt $attempt/4) — waiting ..."
    fi
    sleep 2
    MERGEABLE=$(pr_field mergeable 2>/dev/null || true)
  done
  if [ "$MERGEABLE" = "CONFLICTING" ] && [ "$CONFLICT_READS" -ge 2 ]; then
    # Name the worktree the caller has to resolve it in — setup-worktree.sh puts it
    # at one of exactly two paths, decided by whether this repo sits in a workspace.
    CONFLICT_WT="${WORKSPACE_WT:-$WORKTREE_HOME/$PROJECT/$LEAF}"
    die "PR #$PR conflicts with '$BASE_BRANCH' — nothing has been touched: the worktree is intact and the PR is still a draft.\n  Resolve it in the branch's own worktree, by merging the base IN (never rebase — these branches are never rewritten):\n    cd $CONFLICT_WT\n    git fetch origin && git merge origin/$BASE_BRANCH\n    <resolve, commit, push>\n  If that worktree is gone, re-attach one first: setup-worktree.sh --existing $HEAD_BRANCH\n  Then re-gate the PR and re-run: merge-pr.sh $PR"
  fi
fi

# --- 2. Remove the head branch's worktree --------------------------------------
# Before the merge, so `--delete-branch` can remove the local branch — the ordering
# git forces, and the reason step 1 exists: it is only safe to tear the tree down
# once the merge is known to be possible. remove-worktree.sh is idempotent, no-oping
# if the worktree is already gone.
#
# Hand over the PATH this run already resolved, not the branch name. HEAD_WT is
# git's own answer to "which worktree has this branch checked out", so it is right
# under every layout at once — the bare $WORKTREE_HOME/<project>/<leaf>, a workspace
# member's $WORKTREE_HOME/<workspace>/<leaf>/<repo>, and anywhere WORKTREE_DEST put
# one. Passing the branch made the callee re-derive from scratch what the caller
# was already holding, and that is exactly how the two got out of step: this helper
# knew about the workspace layout and remove-worktree did not, so a workspace
# member's teardown resolved a path that never existed, reported "already removed",
# exited 0, and the `--delete-branch` below then ran against a branch still checked
# out in a live worktree — the precise failure the remove-then-merge ordering exists
# to prevent.
#
# The branch name stays as the fallback for the case git has no answer to give: a
# worktree in detached HEAD, one whose branch was switched, or a tree already gone.
# There remove-worktree.sh's own (now workspace-aware) resolution takes over, which
# is why both halves of this fix were needed and neither substitutes for the other.
if [ -n "$HEAD_BRANCH" ]; then
  echo "merge-pr: tearing down worktree for $HEAD_BRANCH ..."
  REPO="$MAIN" "$HERE/remove-worktree.sh" "${HEAD_WT:-$HEAD_BRANCH}"
fi

# --- 3. Merge (unless already merged) ------------------------------------------
if [ "$STATE" = "MERGED" ]; then
  echo "merge-pr: PR #$PR already merged — skipping merge, finishing the local sync."
else
  # `draft -> ready` is the dispatcher's review approval — the one thing in the
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
  # The squash path deliberately does NOT pass --delete-branch. The branch has to
  # outlive the merge long enough for the squash close-out below to compare what
  # landed against the commit that was gated, because that comparison is what
  # replaces the ancestry guarantee a squash destroys — and a branch already
  # deleted by the same call that squashed it could not be kept if the comparison
  # came back wrong.
  if [ "$MERGE_MODE" = "squash" ]; then
    MERGE_ARGS=(--squash)
    echo "merge-pr: merging PR #$PR (squash — the epic buffer collapses to one commit; the branch is deleted once the tree check below passes) ..."
  else
    MERGE_ARGS=(--merge --delete-branch)
    echo "merge-pr: merging PR #$PR (real merge commit, deleting branch) ..."
  fi
  if ! ( cd "$MAIN" && gh pr merge "$PR" "${MERGE_ARGS[@]}" ); then
    # The flag must not SURVIVE a merge that failed. A non-draft PR that is not
    # being merged right this second reads, everywhere else in this flow, as a diff
    # a dispatcher approved — so leaving it set would have the PR wearing a
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
    die "merging PR #$PR failed — $DRAFT_NOTE, and its worktree has already been torn down (step 2).\n  Re-attach a tree to the branch, fix it there, and re-run:\n    setup-worktree.sh --existing $HEAD_BRANCH\n    cd <the READY: path it prints> && git fetch origin && git merge origin/$BASE_BRANCH\n    <resolve, commit, push>   (merge the base IN — never rebase)\n    merge-pr.sh $PR"
  fi
fi

# --- 4. Sync the local base branch in the MAIN checkout --------------------------
# Anchored to MAIN so it works regardless of the caller's cwd, and only ever moving
# the branch forward: the main checkout never carries direct commits (all work lands
# via PR merge on the remote), so a non-ff means an anomaly that should stop loudly.
#
# Which of the THREE paths runs is decided by where the base branch actually is:
#
#   the main checkout is standing on it
#              -> `merge --ff-only` there; no switch is needed and the working tree
#                 follows the branch it is already on.
#   a LINKED worktree is standing on it
#              -> `merge --ff-only` inside THAT worktree. This is the ordinary path,
#                 not an edge: an epic branch gets a worktree of its own, and every
#                 slice of that epic PRs into it, so every one of those close-outs
#                 finds the base checked out somewhere.
#   nothing is standing on it
#              -> move the REF (`fetch` + `branch -f`), which needs no working tree.
#
# `branch -f` is what forces the split: git refuses to move a branch any worktree is
# standing on, so a checked-out base has to be advanced from inside its own tree.
# `--ff-only` is why doing so is safe — it can only move the branch forward, never
# discard a commit, which is the same guarantee the on-base path already relies on.
#
# What none of the three does is SWITCH the main checkout. Switching to the base
# opens a window in which another session's own switch lands, and everything after
# it then operates on whatever is checked out at that moment rather than on the base
# — observed: a slice PR based on an epic branch switched the checkout off the
# release branch, another session put it back mid-sync, and the local release branch
# was left pointing at the epic branch's merge commit, six commits of unrelated work,
# while origin/release had independently advanced. Not switching removes the window
# entirely, and leaves nothing to switch back afterwards.
ON_BASE=0
BASE_WT=""
if [ "$START_BRANCH" = "$BASE_BRANCH" ]; then ON_BASE=1; fi

# `gh pr merge` returns before GitHub is guaranteed to serve the new tip, so a sync
# fired immediately can advance to nothing and silently leave the branch on the
# PRE-merge commit — while a `rev-parse` in the done-message still prints a sha and
# reads as "synced." That is the "said synced, wasn't" bug. So: poll-fetch until the
# remote actually carries the merge commit, advance each round, and VERIFY the local
# branch truly reached the merged tip. The message is never proof; the ref-equality
# check below is — and on failure we die loudly, never lie.
MERGE_OID=$( cd "$MAIN" && gh pr view "$PR" --json mergeCommit -q '.mergeCommit.oid' 2>/dev/null || true )
echo "merge-pr: syncing local '$BASE_BRANCH' to the merged tip ..."
synced=""
diverged=""
ff_failed=""
ff_out=""
for attempt in 1 2 3 4 5 6; do
  git -C "$MAIN" fetch --prune origin >/dev/null 2>&1 || true
  assert_checkout_unmoved
  if [ "$ON_BASE" -eq 1 ]; then
    git -C "$MAIN" merge --ff-only "origin/$BASE_BRANCH" >/dev/null 2>&1 || true
  elif git -C "$MAIN" show-ref --verify --quiet "refs/heads/$BASE_BRANCH" \
    && ! git -C "$MAIN" merge-base --is-ancestor "$BASE_BRANCH" "origin/$BASE_BRANCH" 2>/dev/null; then
    # Checked FIRST, so it covers both off-base paths rather than only the ref one.
    # It is the precise instrument for one of the two ways a sync can be blocked —
    # the local branch carrying commits the remote does not — and answering it here,
    # off the refs, is what lets the worktree path below attribute its own failure to
    # the OTHER cause instead of guessing between them. `branch -f` is a force move
    # and could DISCARD those commits; `merge --ff-only` could not, but would fail
    # with a message the caller then has to interpret. Either way it is a stable
    # condition — the remote only ever advances — so stop on it rather than retrying.
    diverged=1
    break
  else
    # Re-resolved EVERY round rather than once before the loop, because `merge` names
    # no branch: it moves whatever the tree it runs in has checked out. Asking which
    # tree holds the base immediately before merging in it is what keeps those two
    # the same tree, and it is the same question either way, so a stale answer buys
    # nothing. It also makes both ways the answer can change self-healing instead of
    # fatal: a worktree removed mid-run, or switched to another branch, simply stops
    # holding the base, and the sync falls through to moving the ref — which is what
    # is now correct for that state.
    BASE_WT=$(worktree_holding "$BASE_BRANCH")
    if [ -n "$BASE_WT" ]; then
      # A linked worktree is standing on the base, so its ref cannot be moved from
      # outside; advance it from inside that tree instead. Divergence was ruled out
      # above, so a failure here is the tree's STATE, not the refs' — keep git's own
      # message, which names the files that block the fast-forward and is the part a
      # caller cannot re-derive from "sync failed".
      if ! ff_out=$(git -C "$BASE_WT" merge --ff-only "origin/$BASE_BRANCH" 2>&1); then
        ff_failed=1
        break
      fi
    else
      # Creates the branch when the main checkout has no local copy of it, which is
      # the ordinary state for an epic branch whose own worktree has since been torn
      # down.
      git -C "$MAIN" branch -f "$BASE_BRANCH" "origin/$BASE_BRANCH" >/dev/null 2>&1 || true
    fi
  fi
  LOCAL=$(git -C "$MAIN" rev-parse --verify --quiet "refs/heads/$BASE_BRANCH" || true)
  REMOTE=$(git -C "$MAIN" rev-parse --verify --quiet "refs/remotes/origin/$BASE_BRANCH" || true)
  if [ -n "$LOCAL" ] && [ "$LOCAL" = "$REMOTE" ] && { [ -z "$MERGE_OID" ] || \
       git -C "$MAIN" merge-base --is-ancestor "$MERGE_OID" "$BASE_BRANCH" 2>/dev/null; }; then
    synced=1
    break
  fi
  echo "merge-pr: remote not serving the merge yet (attempt $attempt/6) — waiting ..."
  sleep 2
done
[ -z "$diverged" ] || die "local '$BASE_BRANCH' carries commits 'origin/$BASE_BRANCH' does not, so advancing it would discard them — REFUSED, and the local branch is untouched. PR #$PR IS merged; only the local sync is outstanding.\n  Inspect what is on it and reconcile it by hand:\n    git -C $MAIN log --oneline origin/$BASE_BRANCH..$BASE_BRANCH\n  Until then do NOT cut new worktrees off '$BASE_BRANCH'."
[ -z "$ff_failed" ] || die "could not fast-forward '$BASE_BRANCH' inside the worktree $BASE_WT, so the local branch is still behind the merged tip. PR #$PR IS merged; only the local sync is outstanding.\n  '$BASE_BRANCH' is NOT diverged — that was checked first — so what blocks it is the state of that working tree: uncommitted changes over a file the fast-forward touches, or a merge left unfinished in it. git said:\n    ${ff_out:-(no output)}\n  Clear that tree and finish the sync from inside it:\n    git -C $BASE_WT status\n    git -C $BASE_WT merge --ff-only origin/$BASE_BRANCH\n  Until then do NOT cut new worktrees off '$BASE_BRANCH' — the local ref is behind the merged tip."
[ -n "$synced" ] || die "local '$BASE_BRANCH' did NOT reach the merged tip (merge commit ${MERGE_OID:-unknown} still absent after retries) — SYNC FAILED; do NOT cut new worktrees off '$BASE_BRANCH' until this is resolved."

# --- 5. Squash close-out: verify the tree, THEN delete the branch ----------------
# Nothing to do on the merge path — `--delete-branch` already removed both copies
# of the branch, and the merge commit's second parent keeps the ancestry that
# `git branch -d` and the integration gate's `^2` check both read.
#
# On the squash path neither of those is true, and the two failures are one fact:
# the squash commit has no second parent, so the epic branch is NOT an ancestor of
# the new integration tip. `git branch -d` therefore reports it as not fully
# merged on EVERY squashed close-out, and the flow's standing rule — stop on that
# warning, never force past it — would halt every one of them if followed
# literally here.
#
# So the warning is not waved through; it is ANSWERED BY A DIFFERENT INSTRUMENT.
# It is a statement about ancestry, and squash breaks ancestry by construction, so
# on this path it is expected and carries no information. What has to be true
# instead is that what landed IS what was gated, and that is a question about
# TREES, which a squash preserves exactly:
#
#   git diff --quiet <epic tip before the merge> <the squash commit>
#
# Empty means the integration branch now holds, byte for byte, the tree the
# close-out gate ran on. That is a stronger property than `^2` ever gave, because
# it compares the trees directly instead of inferring coverage from parentage —
# and it only comes back empty when the close-out cadence was actually run, since
# the final `merge origin/<integration>` into the epic before gating is what makes
# those two trees equal. A skipped cadence surfaces here as a failed comparison
# rather than as a non-empty diff nobody looked at.
#
# Deleting only ever happens after that comparison passes. If it fails the branch
# survives untouched, which is the entire safety story on this path.
#
# Placed after the sync rather than beside the merge so that a failure here leaves
# every other part of the close-out finished: the merge is done and the local base
# branch is at the merged tip, so the only thing outstanding is a branch that still
# exists. Re-running the helper resumes from exactly here.
if [ "$MERGE_MODE" = "squash" ]; then
  HAS_REMOTE=0
  HAS_LOCAL=0
  if git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/$HEAD_BRANCH"; then HAS_REMOTE=1; fi
  if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$HEAD_BRANCH"; then HAS_LOCAL=1; fi
  if [ "$HAS_REMOTE" -eq 0 ] && [ "$HAS_LOCAL" -eq 0 ]; then
    echo "merge-pr: '$HEAD_BRANCH' is already gone locally and on origin — an earlier run finished the squash close-out."
  else
    echo "merge-pr: verifying the squashed tree against the epic tip that was gated ($(printf '%.12s' "$EPIC_TIP")) ..."
    # Both objects have to be READABLE before the comparison means anything: an
    # absent one makes `git diff` fail rather than answer, and a check that could
    # not run must never stand in for one that passed. The epic tip survives in
    # the local branch or in origin/<head> — neither is pruned yet, because this
    # path is exactly the one that did not delete the branch — and the squash
    # commit arrived with step 4's fetch, which already proved '$BASE_BRANCH'
    # carries it.
    VERIFY_FAILED=""
    if [ -z "$MERGE_OID" ]; then
      VERIFY_FAILED="GitHub has not reported the squash commit for PR #$PR yet, so there is nothing to compare the epic tip against"
    elif ! git -C "$MAIN" cat-file -e "$EPIC_TIP^{commit}" 2>/dev/null; then
      VERIFY_FAILED="the epic tip $EPIC_TIP is not an object this repo holds, so the comparison could not be made"
    elif ! git -C "$MAIN" cat-file -e "$MERGE_OID^{commit}" 2>/dev/null; then
      VERIFY_FAILED="the squash commit $MERGE_OID is not an object this repo holds, so the comparison could not be made"
    elif ! git -C "$MAIN" diff --quiet "$EPIC_TIP" "$MERGE_OID"; then
      VERIFY_FAILED="the tree on '$BASE_BRANCH' after the squash is NOT the tree that was gated"
    fi
    [ -z "$VERIFY_FAILED" ] || die "PR #$PR was squashed onto '$BASE_BRANCH', but $VERIFY_FAILED — so '$HEAD_BRANCH' has NOT been deleted and is intact, locally and on origin.\n  On this path that comparison REPLACES git's \"not fully merged\" warning: a squash breaks ancestry by construction, so the warning says nothing, and the tree check is the only thing standing between the delete and losing work. It did not pass, so nothing was deleted.\n  See for yourself:\n    git -C $MAIN diff $EPIC_TIP ${MERGE_OID:-<squash commit>}\n  The usual cause is the close-out cadence being skipped — '$BASE_BRANCH' moved while the epic ran and was never merged back INTO '$HEAD_BRANCH', so what landed is not what the close-out gate ran on.\n  Everything else is done: the merge is complete and local '$BASE_BRANCH' is synced. Re-running merge-pr.sh $PR resumes from this check."
    # `-D`, not `-d`. This is the one place in this flow where git's "not fully
    # merged" refusal is overridden, and that refusal is precisely the one the
    # standing rule says never to force past — so the two conditions below are
    # what make it correct HERE, and neither is context that carries anywhere
    # else. (Step 4's `branch -f` forces a different refusal entirely, with its
    # own divergence check standing in for it; nothing about this line applies
    # to it, and nothing about it applies to this line.)
    #
    #   - ONLY on this path. `-d` asks the ancestry question, which a squash
    #     answers "no" for a reason that has nothing to do with whether the work
    #     landed. On the merge path that same refusal would be REAL, and nothing
    #     there needs a force anyway — `gh pr merge --delete-branch` does the
    #     deleting and no `git branch -d` runs at all.
    #   - ONLY after the tree comparison PASSED. The `die` immediately above is
    #     not a formality standing between the check and the delete; it IS the
    #     guard `-d` would otherwise have been. Reached with the comparison
    #     failed, skipped, or moved below this point, `-D` deletes a branch whose
    #     work is not on the integration branch, and nothing anywhere records
    #     that it existed.
    #
    # So do not lift this line out of the block, do not move it above that `die`,
    # and do not cite it as precedent for forcing past any other guard. The tree
    # comparison is what earns the force, and it earns it exactly once, here.
    DELETE_FAILED=""
    if [ "$HAS_REMOTE" -eq 1 ]; then
      echo "merge-pr: tree matches — deleting '$HEAD_BRANCH' on origin ..."
      git -C "$MAIN" push origin --delete "$HEAD_BRANCH" >/dev/null 2>&1 \
        || DELETE_FAILED="git -C $MAIN push origin --delete $HEAD_BRANCH"
    fi
    if [ "$HAS_LOCAL" -eq 1 ]; then
      echo "merge-pr: tree matches — deleting local '$HEAD_BRANCH' ..."
      git -C "$MAIN" branch -D "$HEAD_BRANCH" >/dev/null 2>&1 \
        || DELETE_FAILED="${DELETE_FAILED:+$DELETE_FAILED\n    }git -C $MAIN branch -D $HEAD_BRANCH"
    fi
    [ -z "$DELETE_FAILED" ] || die "PR #$PR is squashed onto '$BASE_BRANCH' and the tree was VERIFIED against the gated epic tip, but deleting '$HEAD_BRANCH' failed.\n  Nothing is at risk — the work is on '$BASE_BRANCH' and the local sync is done; only the branch is left behind. Finish it by hand:\n    $DELETE_FAILED"
  fi
fi

# --- 6. Verify the main checkout did not move under us ---------------------------
# Step 4's verification proves the BASE reached the merged tip. It has no opinion
# about a branch that moved INSTEAD — which is the half that actually corrupts, and
# is silent: every other signal reads as a successful close-out. Nothing here
# switches the checkout, so a branch or HEAD that differs from where the run started
# was moved by another process, and saying so is the difference between an immediate
# stop and a poisoned base the next worktree forks from.
assert_checkout_unmoved
# Only off the base: standing ON it, HEAD is the very ref step 4 verified against the
# merged tip, so comparing it to the start commit would assert nothing but that the
# sync happened. Off it, step 4 advanced a DIFFERENT branch — by ref, or inside its
# own linked worktree — and never touched the MAIN checkout's working tree at all,
# so any movement here is another process's.
if [ "$ON_BASE" -eq 0 ]; then
  git_out -C "$MAIN" rev-parse HEAD
  NOW_HEAD="$GIT_OUT"
  [ "$NOW_HEAD" = "$START_HEAD" ] || die "the main checkout $MAIN is still on '$START_BRANCH' but its HEAD moved from $START_HEAD to $NOW_HEAD — this run only advanced '$BASE_BRANCH', which is a different branch, so another process moved '$START_BRANCH' mid-run. Check where it points before cutting any worktree off it."
fi

# Resolved on its own line rather than inside the echo, because a command
# substitution that fails inside a successful `echo` takes nothing down with it:
# errexit reads the echo's own status, which is 0, so the run would announce a
# close-out with an empty sha where the synced tip should be and exit 0.
git_out -C "$MAIN" rev-parse --short "$BASE_BRANCH"
echo "merge-pr: done — PR #$PR merged, worktree removed, local '$BASE_BRANCH' synced to $GIT_OUT, main checkout still on '$START_BRANCH'."
