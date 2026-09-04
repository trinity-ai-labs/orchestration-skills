#!/usr/bin/env bash
# Create an isolated git worktree for a task, in a central per-project home.
#
#   setup-worktree.sh <branch> <base>       # fork a NEW branch off <base>
#   setup-worktree.sh --existing <branch>   # attach to a branch that ALREADY exists
#
# Run it from ANYWHERE inside the target repo — the repo root, a subdirectory, a
# monorepo subpackage, or even a linked worktree. It walks up to the repo's
# common gitdir, so it always resolves the right project. If cwd isn't inside a
# git repo, pass REPO=/path/to/repo.
#
# What it does, driven by the project's own config at <repo>/.agents/worktree.json:
#   - creates the worktree at  $WORKTREE_HOME/<project>/<branch-leaf>
#     (WORKTREE_HOME defaults to ~/.worktrees, or %LOCALAPPDATA%/wt on Windows —
#     the worktrees themselves stay out of the repo, since a worktree nested
#     inside its own repo confuses git)
#   - symlinks the project's gitignored env files (envFiles)
#   - exports the project's env (env) — e.g. a shared build-cache dir
#   - runs the project's install command (install) inside the worktree
#
# <branch>  full name of the new branch, e.g. feat/toasts-top-right (any prefix:
#           feat/ fix/ refactor/ chore/ docs/ …). The worktree dir is named after
#           the segment past the last slash.
# <base>    branch to fork from. REQUIRED, no default — integration branches roll
#           over often, so a hardcoded default just goes stale.
#
# --existing attaches a worktree to a branch that is already there — the recovery
# move when a branch outlives its tree (a merge that failed after the close-out
# tore the worktree down, a tree removed by hand). It takes NO base: an existing
# branch's base is whatever it already forked from, so a second argument would be
# a value this script has no way to honour. It is a MODE and never an inference —
# attaching merely because the branch happens to exist would silently reuse a
# branch a caller meant to fork fresh off <base>, and a branch that already exists
# is exactly the one that may sit behind the integration tip. The flag is what
# keeps "fork a new branch" and "attach to this one" two distinguishable requests.
#
# Both modes print the same two lines on stdout: "READY: <path>", then "HEAD:
# <sha>" — the worktree's resulting commit, which the caller compares against the
# base tip before dispatching an agent. It is a line rather than a claim inside
# the READY text so that the honest check and the lazy read are the same act.
#
# Neither line is printed unless the worktree is really on <branch>. The path is
# derived from the branch LEAF, so two branches sharing one resolve to the same
# directory and the second call is handed the first's tree with its branch never
# created; that is a case the HEAD comparison cannot catch, since the tree is
# standing on the base. Both modes therefore read the branch back off the tree and
# exit non-zero instead of reporting a success that isn't one.
#
# The same skipped `git worktree add` can also hand back a tree standing on the
# REQUESTED branch at a commit <base> has since moved past, which the branch
# read-back cannot see because the branch is the right one. So the new-branch mode
# additionally refuses unless <base>'s tip is an ANCESTOR of the worktree's HEAD —
# ancestry rather than equality, since a tree that has already committed work on
# top of <base> is a legitimate re-attach and its HEAD is a descendant. --existing
# takes no base, so it has nothing to resolve this against and is out of scope.
# The caller's own comparison is still owed and still catches what this cannot:
# this reads the base tip as the MAIN CHECKOUT has it, so a base that is itself
# behind origin passes here and fails there.
#
# Every branch gets the same treatment — env symlinks and a real install — so a
# worktree is always self-contained and can face any check the project has, a
# re-attached tree exactly as much as a fresh one.
#
# The config lives in the repo, so it travels with the clone and is reviewed
# alongside the code it describes. This script reads only `envFiles`, `env`, and
# `install`; the remaining keys (gate, scopedCheck, enqueue, drain,
# frameworkSkills, briefConventions) are read by the skills, not here. No config
# → a bare worktree (no env symlinks, no install).
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
# runtime, the exact bug class merge-pr.sh already shipped once.
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
worktree_home_default() {
  if is_windows && [ -n "${LOCALAPPDATA:-}" ]; then
    printf '%s/wt\n' "$(norm_path "$LOCALAPPDATA")"
  else
    printf '%s/.worktrees\n' "$HOME"
  fi
}

# --- git calls this script assumes will succeed --------------------------------
# Run one through here and its stdout lands in GIT_OUT; a non-zero exit is this
# script's own refusal instead of git's.
#
# Captured and tested rather than left to `set -e`, for the reason the install
# guard near the bottom gives and for the same two extras. Errexit does stop the
# script, but it stops it MUTE: git's own message is the only thing on stderr,
# with nothing saying which helper died or which worktree it was working on. And
# it exits with GIT's status — 128 for most git failures — where every other
# refusal in this file exits 1. Two ports returning different codes for the same
# input is the drift the frozen contract exists to prevent, and nothing catches
# it: the parity check reads surface shape, not semantics. The message and the
# code here are the PowerShell sibling's Get-GitOutput, word for word.
#
# The output goes to a variable rather than to stdout because `exit` inside a
# command substitution only exits the SUBSHELL. `X=$(git_out …)` would report the
# failure and then carry on running in the parent, and `echo "… $(git_out …)"`
# would not even stop there: the echo itself succeeds, so errexit never fires and
# the line prints with an empty value where the sha should be.
GIT_OUT=""
git_out() { # git_out <git-arg>… — sets GIT_OUT to git's stdout, or exits 1
  local status=0
  GIT_OUT=$(git "$@") || status=$?
  if [ "$status" -ne 0 ]; then
    echo "git $* failed (exit $status)" >&2
    exit 1
  fi
}

WORKTREE_HOME="${WORKTREE_HOME:-$(worktree_home_default)}"
CONFIG_REL=".agents/worktree.json"

usage() {
  echo "usage: setup-worktree.sh <branch> <base>  |  --existing <branch>" >&2
  echo "  e.g. setup-worktree.sh feat/toasts-top-right release/0.3.4" >&2
  echo "       setup-worktree.sh --existing feat/toasts-top-right" >&2
  echo "  --existing attaches to a branch that already exists and takes NO base —" >&2
  echo "  an existing branch's base is whatever it already forked from." >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 1
}

# The mode is decided by the flag alone, never by what happens to exist in the
# repo: see the header for why the two intents have to stay distinguishable.
EXISTING=0
BASE=""
case "${1:-}" in
--existing)
  EXISTING=1
  shift
  if [ $# -ne 1 ]; then
    echo "--existing takes exactly one argument: the branch to attach to." >&2
    usage
  fi
  BRANCH="$1"
  ;;
*)
  if [ $# -lt 2 ]; then usage; fi
  BRANCH="$1"
  BASE="$2"
  ;;
esac
REPO="${REPO:-$PWD}"

# Resolve the MAIN working tree. The common gitdir's parent is the repo root,
# whether cwd is the root, a subdir, a monorepo package, or a linked worktree.
if ! COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  echo "not inside a git repo: $REPO" >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 1
fi
COMMON=$(norm_path "$COMMON")
MAIN=$(dirname "$COMMON")
PROJECT=$(basename "$MAIN")
SLUG="${BRANCH##*/}"

# Windows' 260-character MAX_PATH is a per-API limit, not a filesystem one, and
# git opts out of it with core.longpaths. Without it a deep node_modules tree
# fails mid-install on a filename, which reads as a broken package rather than as
# a path-length ceiling — so say it up front, where it is still cheap to fix.
if is_windows && [ "$(git -C "$MAIN" config --get core.longpaths 2>/dev/null || true)" != "true" ]; then
  echo "warning: git core.longpaths is not enabled — deep dependency trees can fail" >&2
  echo "  to open files whose full path exceeds 260 characters, with an error that" >&2
  echo "  names the file rather than the length. Enable it once, globally:" >&2
  echo "    git config --global core.longpaths true" >&2
fi

# A repo inside a workspace (a containing folder of sibling repos, marked by
# .agents/workspace.json) gets its worktrees under the WORKSPACE's namespace, not
# its own. Bare repo names in a polyrepo are things like `api` and `client` —
# generic enough that two unrelated projects collide in a flat ~/.worktrees.
# setup-workspace.sh sets WORKTREE_DEST directly when it cuts a whole task.
if [ -n "${WORKTREE_DEST:-}" ]; then
  WT="$WORKTREE_DEST"
elif [ -f "$(dirname "$MAIN")/.agents/workspace.json" ]; then
  WT="$WORKTREE_HOME/$(basename "$(dirname "$MAIN")")/$SLUG/$PROJECT"
else
  WT="$WORKTREE_HOME/$PROJECT/$SLUG"
fi
# WORKTREE_HOME and WORKTREE_DEST are caller-supplied and may arrive in either
# form, so normalize the assembled path once, here, rather than at each use.
WT="$(norm_path "$WT")"

# Translate the JSON config into shell assignments. JSON has no shell, so this
# needs a parser. Everything it needs lives inside this one function on purpose:
# scripts/check.sh extracts it by name and runs it standalone to prove the
# shipped example config is one the REAL reader can consume, and a call out to a
# helper defined elsewhere in this file would break that extraction.
emit_config() { # emit_config <config-path>
  # Pick an interpreter by RUNNING each candidate, never by `command -v` alone.
  # On Windows `command -v python3` succeeds against the Microsoft Store's
  # python3.exe App Execution Alias — a stub that opens the Store and prints
  # nothing — so a command-v-only probe selects an "interpreter" whose empty
  # output the caller then eval's, yielding a bare worktree with no error at all.
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
  if [ "${#runner[@]}" -eq 0 ]; then
    echo "need a WORKING node or python on PATH to read $1" >&2
    exit 1
  fi
  if [ "${runner[0]}" = "node" ]; then
    # Read + parse rather than require(): require() resolves a bare relative path
    # as a module name, so it fails on exactly the paths a caller passes by hand.
    node -e '
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const q = (s) => "\x27" + String(s).replace(/\x27/g, "\x27\\\x27\x27") + "\x27";
      console.log("INSTALL_CMD=" + q(cfg.install || ""));
      console.log("ENV_FILES=(" + (cfg.envFiles || []).map(q).join(" ") + ")");
      for (const [k, v] of Object.entries(cfg.env || {})) console.log("export " + k + "=" + v);
    ' "$1"
  else
    "${runner[@]}" - "$1" <<'PY'
import json, shlex, sys
cfg = json.load(open(sys.argv[1]))
print("INSTALL_CMD=%s" % shlex.quote(cfg.get("install") or ""))
print("ENV_FILES=(%s)" % " ".join(shlex.quote(p) for p in cfg.get("envFiles") or []))
# Emitted UNQUOTED so a value may use shell expansion — `${VAR:-$HOME/...}` is how
# a project declares a cache dir that an already-set env var wins over.
for key, value in (cfg.get("env") or {}).items():
    print("export %s=%s" % (key, value))
PY
  fi
}

# Per-project config (optional). Defaults first so `set -u` is safe if it's absent.
ENV_FILES=()
INSTALL_CMD=""
CONFIG="$MAIN/$CONFIG_REL"
if [ -f "$CONFIG" ]; then
  # Captured before eval'ing so a reader that failed is a hard stop: eval'ing the
  # substitution inline would discard its exit status and silently proceed with
  # an empty config, which looks exactly like a repo that declared nothing.
  # Same trust level as INSTALL_CMD below, which is eval'd too: by the time you
  # are cutting a worktree you already run this repo's install and test commands.
  if ! CONFIG_SH="$(emit_config "$CONFIG")"; then
    echo "could not read $CONFIG" >&2
    exit 1
  fi
  eval "$CONFIG_SH"
else
  echo "note: no config at $CONFIG — creating a bare worktree (no env symlinks, no install)." >&2
  echo "  add $CONFIG_REL to '$PROJECT' to declare envFiles / install." >&2
fi

# --- The declared branching model, and the base it vouches for ----------------
# A project states which branch its work lands on (`branchingModel`: "trunk" |
# "release" | "gitflow"); undeclared, nothing here fires and this helper behaves
# exactly as it did. A workspace declares it once for members that share one
# branch and one model, and that answer wins.
#
# What it is used for here is NARROW on purpose. The caller passes <base>
# explicitly, so there is no guess for this helper to prevent and no licence to
# override an instruction with an inference. It refuses exactly one thing it can
# actually KNOW — a release-model project with one live release branch, handed a
# different one — and otherwise only says out loud what it can see, because the
# failure being guarded is not that a wrong branch was chosen but that nothing
# afterwards said which one it was.
read_scalar() { # read_scalar <json-path> <key>
  [ -f "$1" ] || return 0
  local -a runner=()
  local cand probe
  for cand in node python3 python py; do
    command -v "$cand" >/dev/null 2>&1 || continue
    case "$cand" in
    node) runner=(node); probe=$(node -e 'process.stdout.write("ok")' 2>/dev/null) || probe='' ;;
    py) runner=(py -3); probe=$(py -3 -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe='' ;;
    *) runner=("$cand"); probe=$("$cand" -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe='' ;;
    esac
    [ "$probe" = "ok" ] && break
    runner=()
  done
  [ "${#runner[@]}" -gt 0 ] || return 0
  if [ "${runner[0]}" = node ]; then
    node -e 'const fs=require("fs");try{const v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"))[process.argv[2]];if(typeof v==="string")process.stdout.write(v)}catch(e){}' "$1" "$2" 2>/dev/null || true
  else
    "${runner[@]}" -c 'import json,sys
try:
    v = json.load(open(sys.argv[1])).get(sys.argv[2])
except Exception:
    v = None
sys.stdout.write(v if isinstance(v, str) else "")' "$1" "$2" 2>/dev/null || true
  fi
}

BRANCHING_MODEL=""
WS_MANIFEST="$(dirname "$MAIN")/.agents/workspace.json"
[ ! -f "$WS_MANIFEST" ] || BRANCHING_MODEL="$(read_scalar "$WS_MANIFEST" branchingModel)"
[ -n "$BRANCHING_MODEL" ] || BRANCHING_MODEL="$(read_scalar "$CONFIG" branchingModel)"
case "$BRANCHING_MODEL" in
trunk | release | gitflow) ;;
*) BRANCHING_MODEL="" ;;
esac

# Held until AFTER the ref check below, because "this branch is the wrong one" is
# a worse message than "this branch does not exist" for a caller who fat-fingered
# a version, and the wrong one would mask the right one.
check_release_base() {
  [ "$EXISTING" -ne 1 ] || return 0
  [ "$BRANCHING_MODEL" = release ] || return 0
  case "$BASE" in
  release/*) ;;
  *) return 0 ;;
  esac

  # A release branch that has already landed on the default branch has SHIPPED,
  # and forking new work off it is the failure this guards: every check passes,
  # against a base the project moved past, and nothing downstream says so. The
  # base being the default branch itself is the ordinary release-model shape --
  # it is trivially its own ancestor -- so it is excluded first or this refuses
  # every legitimate cut in exactly the projects the model was declared for.
  local default_ref default_branch
  default_ref=$(git -C "$MAIN" symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null) || default_ref=""
  default_branch="${default_ref#refs/remotes/origin/}"
  [ -n "$default_branch" ] || return 0
  [ "$BASE" != "$default_branch" ] || return 0
  git -C "$MAIN" merge-base --is-ancestor "$BASE" "origin/$default_branch" 2>/dev/null || return 0

  echo "refusing: '$BASE' has already landed on '$default_branch' — it is a shipped release branch." >&2
  echo "  This project declares branchingModel=release, so a release branch that is fully merged" >&2
  echo "  into the default branch is one the project has moved past. Work cut from it is gated," >&2
  echo "  reviewed and merged against a base nobody is releasing from, and nothing downstream" >&2
  echo "  reports that." >&2
  echo "  Release branches still ahead of '$default_branch':" >&2
  git -C "$MAIN" for-each-ref --format='%(refname:short)' 'refs/heads/release/*' 2>/dev/null \
    | while IFS= read -r r; do
      [ -n "$r" ] || continue
      git -C "$MAIN" merge-base --is-ancestor "$r" "origin/$default_branch" 2>/dev/null || echo "    $r" >&2
    done
  echo "  Pass one of those, or --existing to re-attach to a branch already cut from '$BASE'." >&2
  exit 1
}

# Decide what `git worktree add` is asked for, and fail before creating anything if
# the ref it needs isn't there. Both modes fail with a fetch hint for the same
# reason: a ref that only exists on a remote nobody has fetched looks exactly like
# a ref that was never created.
ADD_ARGS=()
if [ "$EXISTING" -eq 1 ]; then
  if git -C "$MAIN" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    ADD_ARGS=("$WT" "$BRANCH")
  elif git -C "$MAIN" show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    # The local branch being gone while origin's remains is the NORMAL shape here,
    # not an edge: merge-pr deletes the local branch on a successful merge, and a
    # close-out interrupted partway leaves the same residue. Recreate it tracking
    # the remote so the attached tree pushes back where the branch already lives.
    echo "note: no local branch '$BRANCH' — creating one tracking origin/$BRANCH." >&2
    ADD_ARGS=(--track -b "$BRANCH" "$WT" "origin/$BRANCH")
  else
    # Never fall back to creating the branch. --existing means the caller believes
    # this branch is already there; if it isn't, the belief is wrong, and a branch
    # invented here would be forked off whatever HEAD happens to be — a stale base
    # with nothing anywhere to say so.
    echo "branch not found: $BRANCH (neither refs/heads nor origin/)" >&2
    echo "  --existing attaches to a branch that already exists; it never creates one." >&2
    echo "  try: git -C \"$MAIN\" fetch origin   (if the branch is only on the remote)" >&2
    echo "  to fork a NEW branch instead: setup-worktree.sh $BRANCH <base>" >&2
    exit 1
  fi
else
  # Fail early with a fetch hint if base isn't a known local ref (a freshly-cut
  # integration branch won't exist locally until you fetch it).
  if ! git -C "$MAIN" rev-parse --verify --quiet "$BASE" >/dev/null; then
    echo "base branch not found locally: $BASE" >&2
    echo "  try: git -C \"$MAIN\" fetch origin   (or pass origin/$BASE)" >&2
    exit 1
  fi
  check_release_base
  ADD_ARGS=(-b "$BRANCH" "$WT" "$BASE")
fi

mkdir -p "$(dirname "$WT")"

# git prints Windows-form paths in `worktree list` while $WT is MSYS-form, so the
# substring match this used to be never matched on Windows and the idempotency
# guard failed OPEN: a re-run fell through to `git worktree add`, which then died
# with "already exists". Comparing NORMALIZED paths for exact equality fixes that
# and a second, quieter bug the substring match had on every platform — a leaf
# that is a prefix of another registered worktree matched it.
worktree_registered() { # worktree_registered <abs-path>
  local want="$1" line
  # Read through git_out rather than straight from a process substitution: a
  # failed listing there produces no lines and reads as "no worktree here", which
  # sends the run on to `git worktree add` against a path that may well hold one.
  # The registry either answers or the run stops, exactly as the sibling does.
  git_out -C "$MAIN" worktree list --porcelain
  while IFS= read -r line; do
    case "$line" in
    "worktree "*) ;;
    *) continue ;;
    esac
    if [ "$(norm_path "${line#worktree }")" = "$want" ]; then
      return 0
    fi
  done <<<"$GIT_OUT"
  return 1
}

if worktree_registered "$WT"; then
  echo "worktree already exists: $WT"
else
  # Checked by hand for the reason git_out gives, and inline rather than through
  # it because this call's output is the caller's to see, not ours to capture.
  ADD_STATUS=0
  git -C "$MAIN" worktree add "${ADD_ARGS[@]}" || ADD_STATUS=$?
  if [ "$ADD_STATUS" -ne 0 ]; then
    echo "git worktree add failed (exit $ADD_STATUS)" >&2
    exit 1
  fi
fi

# The tree that exists now may not be on the branch that was asked for, and every
# signal after this point is byte-identical to a success if it isn't. $WT is
# derived from the branch LEAF, so two branches sharing a leaf resolve to one
# directory; the guard above finds the first one's worktree already registered
# there and skips `git worktree add`, so the requested branch is never created —
# and the caller's one mandated check cannot see it, because comparing the printed
# HEAD against the base tip MATCHES when the tree is standing on the base itself.
# So read back what the tree is really on and refuse rather than print READY.
#
# Keyed on the observed branch, never on a name pattern: no branch prefix carries
# meaning to any helper here, so any two branches sharing a leaf collide whatever
# they are called. It covers --existing too, where the same comparison confirms
# the tree handed back is on the branch the caller asked to attach to.
# `--abbrev-ref HEAD` prints the literal "HEAD" on a detached checkout, which
# compares as its own value and needs no special case.
git_out -C "$WT" rev-parse --abbrev-ref HEAD
ON_BRANCH="$GIT_OUT"
if [ "$ON_BRANCH" != "$BRANCH" ]; then
  # What the skipped `git worktree add` would have done differs by mode. --existing
  # is only ever asked for a branch that already exists — the arms above stop or
  # track origin rather than invent one — so "never created" would be a plainly
  # false claim there about a branch the caller can go and look at.
  if [ "$EXISTING" -eq 1 ]; then
    MISSED="'$BRANCH' was never checked out here"
  else
    MISSED="'$BRANCH' was never created"
  fi
  echo "refusing: $WT is on '$ON_BRANCH', not the requested '$BRANCH'." >&2
  echo "  The worktree path is derived from the branch leaf, so it is shared by every branch whose leaf is '$SLUG'." >&2
  echo "  One of them already had a worktree registered here, so 'git worktree add' was skipped and $MISSED." >&2
  echo "  Give '$BRANCH' a leaf no live worktree is holding, or free this one first:" >&2
  echo "    git -C \"$MAIN\" worktree list" >&2
  exit 1
fi

# The branch is right; the commit under it may still not be. The idempotency guard
# skips `git worktree add` for any worktree already registered at this path — and
# the refusal above is keyed on the branch NAME alone, so a tree cut off <base>
# some time ago, on exactly the branch asked for, passes it while <base> has moved
# on underneath. That tree is stale, and every signal after this point is
# byte-identical to a fresh cut.
#
# ANCESTRY, not equality: a caller re-attaching to a tree that has already
# committed work on top of <base> must still pass, and its HEAD is a descendant of
# the base tip rather than a match. Equality would refuse exactly that case.
#
# --existing takes no base, so there is nothing to resolve this comparison
# against; the check is confined to the new-branch mode by construction rather
# than left out of it by omission.
if [ "$EXISTING" -eq 0 ]; then
  # Resolved here rather than reused from the pre-add check: the base tip that
  # matters is the one standing when the tree is handed back.
  git_out -C "$MAIN" rev-parse --verify "$BASE^{commit}"
  BASE_TIP="$GIT_OUT"
  git_out -C "$WT" rev-parse HEAD
  WT_HEAD="$GIT_OUT"
  if ! git -C "$MAIN" merge-base --is-ancestor "$BASE_TIP" "$WT_HEAD"; then
    echo "refusing: $WT does not contain '$BASE'." >&2
    echo "  base tip:      $BASE_TIP" >&2
    echo "  worktree HEAD: $WT_HEAD" >&2
    echo "  A worktree was already registered at this path, so 'git worktree add' was skipped." >&2
    echo "  The tree was handed back as it stood, at a commit '$BASE' has since moved past." >&2
    echo "  Bring the tree up to '$BASE', or free the path so a fresh one can be cut:" >&2
    echo "    git -C \"$WT\" merge $BASE" >&2
    echo "    git -C \"$MAIN\" worktree list" >&2
    exit 1
  fi
fi

# Symlink the project's gitignored env files (tests/build read these). Guarded
# for bash 3.2, where expanding an empty array under `set -u` errors.
if [ "${#ENV_FILES[@]}" -gt 0 ]; then
  COPIED=()
  for rel in "${ENV_FILES[@]}"; do
    if [ -e "$MAIN/$rel" ]; then
      mkdir -p "$WT/$(dirname "$rel")"
      ln -sf "$MAIN/$rel" "$WT/$rel"
      # Git Bash COPIES instead of linking unless Windows Developer Mode is on
      # (an unprivileged process cannot create a symlink otherwise), and `ln`
      # exits 0 either way. A copy is a point-in-time snapshot, so a later edit
      # to the main checkout's env file stops reaching the worktree — which
      # surfaces much later as a test reading a stale value, with nothing
      # pointing back at setup. Say it here, while the cause is still obvious.
      [ -L "$WT/$rel" ] || COPIED+=("$rel")
    fi
  done
  if [ "${#COPIED[@]}" -gt 0 ]; then
    echo "warning: copied instead of symlinked: ${COPIED[*]}" >&2
    echo "  these are snapshots — later edits to $MAIN's copies will NOT reach this" >&2
    echo "  worktree. Enable Windows Developer Mode (Settings > System > For developers)" >&2
    echo "  so real symlinks can be created, then re-run this script." >&2
  fi
fi

# Materialize node_modules / deps (worktrees don't share them; the gate needs them).
if [ -n "$INSTALL_CMD" ]; then
  # corepack-shimmed package managers (e.g. pnpm) provision the pinned version on
  # first use and, by default, block on a [Y/n] download prompt — which has nowhere
  # to go in this non-interactive install and hangs/fails the cold-cache run. Auto-
  # accept so the first worktree setup warms the cache instead of stalling. Harmless
  # when INSTALL_CMD doesn't go through corepack.
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  # Captured and tested rather than left to `set -e`, for the reason the config
  # reader above gives — and for two more that are specific to here. `set -e`
  # does stop the script before READY:, but it stops it MUTE: the only thing on
  # stderr is the install tool's own output, so a caller is left reading npm's
  # noise with nothing saying which worktree it belongs to, or that a tree was
  # created and is still standing. And it exits with the INSTALL's status — 7
  # for a tool that returns 7 — where every other refusal here, and the
  # PowerShell sibling's failed-install path, exits 1. Two ports returning
  # different codes for the same input is the drift the frozen contract exists
  # to prevent, and nothing catches it: the parity check reads surface shape,
  # not semantics.
  #
  # Guarding the subshell also stops `set -e` from aborting a multi-command
  # install line partway, so `a; b` now means what the shell says it means and
  # its status is b's. That is what the sibling has always done — PowerShell has
  # no errexit for native commands, and $PSNativeCommandUseErrorActionPreference
  # is pinned $false — so the two agree on `;` lines now, where before they did
  # not. `a && b` is unaffected either way.
  INSTALL_STATUS=0
  ( cd "$WT" && eval "$INSTALL_CMD" ) || INSTALL_STATUS=$?
  if [ "$INSTALL_STATUS" -ne 0 ]; then
    # "did not complete" rather than "has no deps": an install that died partway
    # leaves a PARTIAL dependency tree, which is the worse of the two states —
    # a bare tree is obviously bare, a half-populated one looks provisioned and
    # fails selectively — so the message must not promise the tidier one.
    echo "install failed (exit $INSTALL_STATUS): $INSTALL_CMD" >&2
    echo "  in worktree: $WT" >&2
    echo "  the tree was created and is LEFT IN PLACE so you can diagnose it, but its" >&2
    echo "  install did not complete: no READY: line is printed, and nothing should be" >&2
    echo "  dispatched into it. Re-run the same command once the install is fixed - the" >&2
    echo "  worktree is reused and the install retried." >&2
    exit 1
  fi
fi

if [ "$EXISTING" -eq 1 ]; then
  echo "READY: $WT (existing branch $BRANCH)"
else
  echo "READY: $WT (branch $BRANCH off $BASE)"
fi
# The tip the tree actually landed on, on its own line, because the caller's next
# obligation is to compare it against the base tip before dispatching an agent.
# Reading it back off the worktree rather than reporting what was asked for is the
# point: an attached branch, a re-run against an existing tree, and a fresh fork
# all report the commit that is really checked out.
# Resolved on its own line rather than inside the echo, because a command
# substitution that fails inside a successful `echo` takes the whole line down
# with it silently: errexit reads the echo's own status, which is 0, so the
# script would print "HEAD: " with nothing after it and exit 0 — a caller
# comparing that against the base tip is handed an empty string by a run that
# reported success. git_out makes the same failure a refusal.
git_out -C "$WT" rev-parse HEAD
echo "HEAD: $GIT_OUT"
