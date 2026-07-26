#!/usr/bin/env bash
# Install the orchestration-skills pipeline on this machine.
#
#   ./install.sh            # symlink (default) — repo IS the live tools, edits propagate instantly
#   ./install.sh --copy     # copy instead — edit the repo, re-run to sync
#
# Symlinks the repo's pieces into the locations Claude Code + the helper expect:
#   bin/*.sh     -> ~/.worktrees/*.sh
#   config/*.sh  -> ~/.worktrees/config/*.sh
#   skills/*     -> ~/.claude/skills/*   (Claude Code)
#                -> ~/.agents/skills/*   (generic ~/.agents convention)
#
# The three skills install as a set, always. They are one pipeline
# (write-issue -> decompose -> orchestrate) and they reach into each other's
# ground: decompose and orchestrate both read the per-project config this script
# drops at ~/.worktrees/config/<project>.sh, and each skill's handoff names the
# next one by slash-command. A partial install leaves a skill pointing at files
# that aren't there.
#
# Symlinks (not copies) mean `git pull` in this repo updates your live tools.
# The script is idempotent: it wipes whatever is at each destination and
# re-links, so a stale or half-broken install is cleaned out every time.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_HOME="${WORKTREE_HOME:-$HOME/.worktrees}"
# Install the skills into every agent skills home: Claude Code and the generic
# ~/.agents convention. Add more here and they all stay in sync.
SKILL_HOMES=(
  "${CLAUDE_SKILLS_HOME:-$HOME/.claude/skills}"
  "${AGENTS_SKILLS_HOME:-$HOME/.agents/skills}"
)
MODE="symlink"
[ "${1:-}" = "--copy" ] && MODE="copy"

link() { # link <src> <dest>
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  # Clear whatever's already at dest first. A real file/dir left by a prior
  # `--copy` install (or a hand setup) would otherwise make `ln -sfn` nest the
  # new symlink *inside* the existing directory instead of replacing it — a
  # silent broken install. (Plain `if` so `set -e` doesn't trip on a no-op.)
  if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf "$dest"; fi
  if [ "$MODE" = "copy" ]; then
    cp -R "$src" "$dest"
  else
    ln -sfn "$src" "$dest"
  fi
  echo "  $dest -> $src"
}

echo "Installing orchestration-skills ($MODE) from $REPO"

# 1. Helper scripts
for script in "$REPO"/bin/*.sh; do
  [ -e "$script" ] || continue
  chmod +x "$script"
  link "$script" "$WORKTREE_HOME/$(basename "$script")"
done

# 2. Per-project configs (one symlink per file so you can add your own later)
mkdir -p "$WORKTREE_HOME/config"
for cfg in "$REPO"/config/*.sh; do
  [ -e "$cfg" ] || continue
  link "$cfg" "$WORKTREE_HOME/config/$(basename "$cfg")"
done

# 3. Every skill — into every skill home
for home in "${SKILL_HOMES[@]}"; do
  for skill in "$REPO"/skills/*/; do
    link "${skill%/}" "$home/$(basename "$skill")"
  done
done

echo
echo "Done. Sanity check:"
echo "  ls -la $WORKTREE_HOME/setup-worktree.sh"
for home in "${SKILL_HOMES[@]}"; do
  echo "  ls -la $home/write-issue $home/decompose $home/orchestrate"
done
echo
echo "Next: open Claude Code in your repo and try  /write-issue  — see README.md."
