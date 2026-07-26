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
#   ~/.worktrees/<workspace>/<branch-leaf>/<repo>/
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

WORKTREE_HOME="${WORKTREE_HOME:-$HOME/.worktrees}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "setup-workspace: error: $*" >&2; exit 1; }

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then DRY_RUN=1; shift; fi

[ $# -ge 1 ] || die "usage: setup-workspace.sh [--dry-run] <branch> [repo ...]"
BRANCH="$1"; shift
SLUG="${BRANCH##*/}"

# Find the workspace root by walking up for the manifest. Starting from a member
# repo is the common case — you are usually already inside one.
DIR="${WORKSPACE:-$PWD}"
while [ "$DIR" != "/" ] && [ ! -f "$DIR/.agents/workspace.json" ]; do
  DIR="$(dirname "$DIR")"
done
[ -f "$DIR/.agents/workspace.json" ] || die "no .agents/workspace.json above $PWD — not inside a workspace"
ROOT="$DIR"
WORKSPACE_NAME="$(basename "$ROOT")"
MANIFEST="$ROOT/.agents/workspace.json"

read_manifest() { # read_manifest <members|defaults|KEY>  → one value per line
  python3 - "$MANIFEST" "$1" <<'PY'
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
done < <(python3 - "$MANIFEST" <<'PY'
import json, sys
for c in json.load(open(sys.argv[1])).get("crossRepoContracts", []):
    owner = c.get("owner", "")
    if owner:
        print(owner + "\t" + " ".join(c.get("consumers", [])))
PY
)

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
