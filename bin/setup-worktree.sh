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
#     (WORKTREE_HOME defaults to ~/.worktrees — the worktrees themselves stay out
#     of the repo, since a worktree nested inside its own repo confuses git)
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

WORKTREE_HOME="${WORKTREE_HOME:-$HOME/.worktrees}"
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
MAIN=$(dirname "$COMMON")
PROJECT=$(basename "$MAIN")
SLUG="${BRANCH##*/}"
WT="$WORKTREE_HOME/$PROJECT/$SLUG"

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

mkdir -p "$WORKTREE_HOME/$PROJECT"

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
