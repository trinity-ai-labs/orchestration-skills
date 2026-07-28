#!/usr/bin/env bash
# Create an isolated git worktree for a task, in a central per-project home.
#
#   setup-worktree.sh <branch> <base>
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
# Every branch gets the same treatment — env symlinks and a real install — so a
# worktree is always self-contained and can face any check the project has.
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

WORKTREE_HOME="${WORKTREE_HOME:-$(worktree_home_default)}"
CONFIG_REL=".agents/worktree.json"

if [ $# -lt 2 ]; then
  echo "usage: setup-worktree.sh <branch> <base>" >&2
  echo "  e.g. setup-worktree.sh feat/toasts-top-right release/0.3.4" >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 1
fi

BRANCH="$1"
BASE="$2"
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
# needs a parser: python3 first (present by default on macOS and every mainstream
# Linux), node as the fallback for images that ship node but not python.
emit_config() { # emit_config <config-path>
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$1" <<'PY'
import json, shlex, sys
cfg = json.load(open(sys.argv[1]))
print("INSTALL_CMD=%s" % shlex.quote(cfg.get("install") or ""))
print("ENV_FILES=(%s)" % " ".join(shlex.quote(p) for p in cfg.get("envFiles") or []))
# Emitted UNQUOTED so a value may use shell expansion — `${VAR:-$HOME/...}` is how
# a project declares a cache dir that an already-set env var wins over.
for key, value in (cfg.get("env") or {}).items():
    print("export %s=%s" % (key, value))
PY
  elif command -v node >/dev/null 2>&1; then
    node -e '
      const cfg = require(process.argv[1]);
      const q = (s) => "\x27" + String(s).replace(/\x27/g, "\x27\\\x27\x27") + "\x27";
      console.log("INSTALL_CMD=" + q(cfg.install || ""));
      console.log("ENV_FILES=(" + (cfg.envFiles || []).map(q).join(" ") + ")");
      for (const [k, v] of Object.entries(cfg.env || {})) console.log("export " + k + "=" + v);
    ' "$1"
  else
    echo "need python3 or node to read $1" >&2
    exit 1
  fi
}

# Per-project config (optional). Defaults first so `set -u` is safe if it's absent.
ENV_FILES=()
INSTALL_CMD=""
CONFIG="$MAIN/$CONFIG_REL"
if [ -f "$CONFIG" ]; then
  # Same trust level as INSTALL_CMD below, which is eval'd too: by the time you
  # are cutting a worktree you already run this repo's install and test commands.
  eval "$(emit_config "$CONFIG")"
else
  echo "note: no config at $CONFIG — creating a bare worktree (no env symlinks, no install)." >&2
  echo "  add $CONFIG_REL to '$PROJECT' to declare envFiles / install." >&2
fi

# Fail early with a fetch hint if base isn't a known local ref (a freshly-cut
# integration branch won't exist locally until you fetch it).
if ! git -C "$MAIN" rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "base branch not found locally: $BASE" >&2
  echo "  try: git -C \"$MAIN\" fetch origin   (or pass origin/$BASE)" >&2
  exit 1
fi

mkdir -p "$(dirname "$WT")"

if git -C "$MAIN" worktree list | grep -qF "$WT"; then
  echo "worktree already exists: $WT"
else
  git -C "$MAIN" worktree add -b "$BRANCH" "$WT" "$BASE"
fi

# Symlink the project's gitignored env files (tests/build read these). Guarded
# for bash 3.2, where expanding an empty array under `set -u` errors.
if [ "${#ENV_FILES[@]}" -gt 0 ]; then
  for rel in "${ENV_FILES[@]}"; do
    if [ -e "$MAIN/$rel" ]; then
      mkdir -p "$WT/$(dirname "$rel")"
      ln -sf "$MAIN/$rel" "$WT/$rel"
    fi
  done
fi

# Materialize node_modules / deps (worktrees don't share them; the gate needs them).
if [ -n "$INSTALL_CMD" ]; then
  # corepack-shimmed package managers (e.g. pnpm) provision the pinned version on
  # first use and, by default, block on a [Y/n] download prompt — which has nowhere
  # to go in this non-interactive install and hangs/fails the cold-cache run. Auto-
  # accept so the first worktree setup warms the cache instead of stalling. Harmless
  # when INSTALL_CMD doesn't go through corepack.
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
  ( cd "$WT" && eval "$INSTALL_CMD" )
fi

echo "READY: $WT (branch $BRANCH off $BASE)"
