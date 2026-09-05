#!/usr/bin/env bash
# Cut one task's worktrees across a POLYREPO workspace.
#
#   setup-workspace.sh [--dry-run] <branch> [repo ...]
#   setup-workspace.sh [--dry-run] <branch> --exclude <repo,repo>
#
# A workspace is a containing folder of sibling repos — not itself a repo —
# marked by `.agents/workspace.json` at its root. Run this from anywhere inside
# the workspace (the root, or any member repo).
#
# It creates one worktree per named repo, laid out the same way the workspace is:
#
#   $WORKTREE_HOME/<workspace>/<branch-leaf>/<repo>/
#
# ($WORKTREE_HOME defaults to ~/.worktrees, or %LOCALAPPDATA%/wt on Windows.)
#
# Mirroring the layout is the point. A cross-repo task gets a single directory
# that looks exactly like the workspace, so relative paths between repos still
# resolve and both stacks can run side by side — which is what a feature
# spanning an API and its client actually needs.
#
# <branch>  the branch to create in EVERY named repo. One name across all of
#           them, so the PRs are obviously one change.
# [repo]    which members to cut. Name them explicitly when you know the task's
#           surface; each repo you skip is one install you don't pay for.
# --exclude the inverse: everything in the default set except these. Better when
#           a task touches most of the workspace and you want to drop one.
#
# With neither, you get the workspace's DEFAULT set: every member except those
# the manifest marks `"default": false`. That is for the member a workspace
# rarely touches together with the others — a marketing site alongside an app —
# so the common case stays cheap without anyone having to remember a flag.
#
# Each repo is provisioned by setup-worktree.sh, so it gets that repo's own
# .agents/worktree.json treatment: env symlinks, exported env, install.
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

WORKTREE_HOME="${WORKTREE_HOME:-$(worktree_home_default)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "setup-workspace: error: $*" >&2; exit 1; }

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi

[ $# -ge 1 ] || die "usage: setup-workspace.sh [--dry-run] <branch> [repo ... | --exclude <repo,repo>]"
BRANCH="$1"; shift
SLUG="${BRANCH##*/}"

# Find the workspace root by walking up for the manifest. Starting from a member
# repo is the common case — you are usually already inside one.
#
# The loop terminates on `dirname` reaching a fixed point, NOT on the string "/".
# A Windows-form start (C:/Users/…) bottoms out at "C:/", which is never equal to
# "/", so the old condition spun forever — an outright hang with no output, the
# worst failure shape in the whole set. Every root is its own parent, so this
# terminates from any starting form.
DIR="$(norm_path "${WORKSPACE:-$PWD}")"
while [ ! -f "$DIR/.agents/workspace.json" ]; do
  PARENT="$(dirname "$DIR")"
  [ "$PARENT" != "$DIR" ] || break
  DIR="$PARENT"
done
[ -f "$DIR/.agents/workspace.json" ] || die "no .agents/workspace.json above $PWD — not inside a workspace"
ROOT="$DIR"
WORKSPACE_NAME="$(basename "$ROOT")"
MANIFEST="$ROOT/.agents/workspace.json"

# Pick a JSON interpreter ONCE, by RUNNING each candidate rather than trusting
# `command -v`: on Windows `command -v python3` succeeds against the Microsoft
# Store's python3.exe App Execution Alias — a stub that opens the Store and
# prints nothing — so a command-v-only probe selects an "interpreter" that
# returns an empty manifest, and this script then reports a workspace with no
# members rather than a missing tool. node is in the list because a node-only
# machine used to fail here outright, while setup-worktree.sh, reading the same
# kind of file for the same flow, was perfectly happy with node.
JSON_CMD=()
pick_json_runner() {
  local cand probe
  for cand in node python3 python py; do
    command -v "$cand" >/dev/null 2>&1 || continue
    case "$cand" in
    node)
      JSON_CMD=(node)
      probe=$(node -e 'process.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    py)
      JSON_CMD=(py -3)
      probe=$(py -3 -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    *)
      JSON_CMD=("$cand")
      probe=$("$cand" -c 'import sys; sys.stdout.write("ok")' 2>/dev/null) || probe=''
      ;;
    esac
    if [ "$probe" = "ok" ]; then return 0; fi
    JSON_CMD=()
  done
  die "need a WORKING node or python on PATH to read $MANIFEST"
}
pick_json_runner

read_manifest() { # read_manifest <members|defaults|KEY>  → one value per line
  if [ "${JSON_CMD[0]}" = "node" ]; then
    "${JSON_CMD[@]}" -e '
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      const key = process.argv[2];
      if (key === "members" || key === "defaults") {
        for (const m of cfg.members || []) {
          const path = typeof m === "string" ? m : (m.path || "");
          const onByDefault = typeof m === "string" ? true : (m.default === undefined ? true : !!m.default);
          if (key === "members" || onByDefault) console.log(path);
        }
      } else {
        const v = cfg[key];
        console.log(typeof v === "string" ? v : "");
      }
    ' "$MANIFEST" "$1"
  else
    "${JSON_CMD[@]}" - "$MANIFEST" "$1" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
key = sys.argv[2]
if key in ("members", "defaults"):
    for m in cfg.get("members", []):
        path = m if isinstance(m, str) else m.get("path", "")
        on_by_default = True if isinstance(m, str) else m.get("default", True)
        if key == "members" or on_by_default:
            print(path)
else:
    v = cfg.get(key, "")
    print(v if isinstance(v, str) else "")
PY
  fi
}

read_contracts() { # → one "<owner><TAB><consumer> <consumer>…" line per contract
  if [ "${JSON_CMD[0]}" = "node" ]; then
    "${JSON_CMD[@]}" -e '
      const fs = require("fs");
      const cfg = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
      for (const c of cfg.crossRepoContracts || []) {
        if (c.owner) console.log(c.owner + "\t" + (c.consumers || []).join(" "));
      }
    ' "$MANIFEST"
  else
    "${JSON_CMD[@]}" - "$MANIFEST" <<'PY'
import json, sys
for c in json.load(open(sys.argv[1])).get("crossRepoContracts", []):
    owner = c.get("owner", "")
    if owner:
        print(owner + "\t" + " ".join(c.get("consumers", [])))
PY
  fi
}

contains() { # contains <needle> <haystack...>
  local n="$1"; shift
  for x in "$@"; do [ "$x" = "$n" ] && return 0; done
  return 1
}

BASE="$(read_manifest integrationBranch)"
[ -n "$BASE" ] || die "$MANIFEST declares no integrationBranch"

EXCLUDE=()
if [ "${1:-}" = "--exclude" ]; then
  [ $# -ge 2 ] || die "--exclude needs a comma-separated list"
  IFS=',' read -r -a EXCLUDE <<< "$2"
  shift 2
fi

ALL=(); DEFAULTS=()
while IFS= read -r line; do [ -n "$line" ] && ALL+=("$line"); done < <(read_manifest members)
while IFS= read -r line; do [ -n "$line" ] && DEFAULTS+=("$line"); done < <(read_manifest defaults)

if [ $# -gt 0 ]; then
  REPOS=("$@")
else
  REPOS=("${DEFAULTS[@]}")
fi

# Reject an unknown name rather than silently cutting a smaller task than asked
# for — a typo'd repo is the kind of thing you only notice three PRs later.
for r in "${REPOS[@]}" ${EXCLUDE[@]+"${EXCLUDE[@]}"}; do
  contains "$r" "${ALL[@]}" || die "'$r' is not a member of $WORKSPACE_NAME (members: ${ALL[*]})"
done

if [ "${#EXCLUDE[@]}" -gt 0 ]; then
  KEPT=()
  for r in "${REPOS[@]}"; do contains "$r" "${EXCLUDE[@]}" || KEPT+=("$r"); done
  REPOS=("${KEPT[@]}")
  echo "excluding:  ${EXCLUDE[*]}"
fi
[ "${#REPOS[@]}" -gt 0 ] || die "every member was excluded — nothing to do"

# Contract closure. A repo that OWNS a cross-repo contract cannot be changed
# alone: its consumers hold generated copies of what it produces, so a task that
# touches the owner without them can neither update nor verify the other side,
# and the drift only surfaces after both have merged. Pull the consumers in.
while IFS=$'\t' read -r owner consumers; do
  [ -n "$owner" ] || continue
  contains "$owner" "${REPOS[@]}" || continue
  for c in $consumers; do
    contains "$c" "${REPOS[@]}" && continue
    if contains "$c" ${EXCLUDE[@]+"${EXCLUDE[@]}"}; then
      die "'$c' consumes a contract owned by '$owner', which this task includes — it cannot be excluded.
  Either drop '$owner' from the task, or keep '$c' in it."
    fi
    REPOS+=("$c")
    echo "including:  $c (consumes a contract owned by $owner)"
  done
done < <(read_contracts)

echo "workspace: $WORKSPACE_NAME ($ROOT)"
echo "branch:    $BRANCH  off  $BASE"
echo "repos:     ${REPOS[*]}"
echo

TASK_DIR="$WORKTREE_HOME/$WORKSPACE_NAME/$SLUG"

if [ "$DRY_RUN" = "1" ]; then
  echo "would create: $TASK_DIR/{$(IFS=,; echo "${REPOS[*]}")}"
  exit 0
fi

mkdir -p "$TASK_DIR"

for repo in "${REPOS[@]}"; do
  src="$ROOT/$repo"
  [ -d "$src" ] || die "member '$repo' not found at $src"
  git -C "$src" rev-parse --git-dir >/dev/null 2>&1 || die "member '$repo' is not a git repo"

  # Verify the base exists here before creating anything: in a polyrepo the
  # integration branch is a convention, and one repo lagging behind is exactly
  # the case that would otherwise leave a half-built task directory.
  git -C "$src" rev-parse --verify --quiet "$BASE" >/dev/null \
    || die "member '$repo' has no local '$BASE' — run: git -C \"$src\" fetch origin"
done

for repo in "${REPOS[@]}"; do
  echo "─── $repo ───"
  WORKTREE_DEST="$TASK_DIR/$repo" REPO="$ROOT/$repo" "$HERE/setup-worktree.sh" "$BRANCH" "$BASE"
done

echo
echo "READY: $TASK_DIR"
echo "  $(ls -1 "$TASK_DIR" | tr '\n' ' ')"
echo
echo "Verify each HEAD before dispatching an agent — the helper does not:"
for repo in "${REPOS[@]}"; do
  echo "  git -C $TASK_DIR/$repo rev-parse HEAD   # must equal origin/$BASE in $repo"
done
