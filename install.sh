#!/usr/bin/env bash
# Install the write-issue skill on this machine.
#
#   ./install.sh
#
# Symlinks the skill into every agent skills home Claude Code looks at:
#   skills/write-issue/  -> ~/.claude/skills/write-issue/  AND  ~/.agents/skills/write-issue/
#
# Symlinks (not copies) mean `git pull` in this repo updates your live skill.
# Pass --copy to copy instead (edit the originals in the repo, re-run to sync).
#
# write-issue is a PLANNING skill — it ships only the skill, no helper scripts or
# per-project config. It reads each repo's own AGENTS.md / conventions (like its
# siblings decompose and orchestrate) rather than hardcoding a project. It is the
# first leg of the write-issue -> decompose -> orchestrate pipeline.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Install the skill into every agent skills home: Claude Code and the generic
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

echo "Installing write-issue ($MODE) from $REPO"

# The write-issue skill — into every skill home
for home in "${SKILL_HOMES[@]}"; do
  link "$REPO/skills/write-issue" "$home/write-issue"
done

echo
echo "Done. Sanity check:"
for home in "${SKILL_HOMES[@]}"; do
  echo "  ls -la $home/write-issue"
done
echo
echo "Next: open Claude Code in your repo and try  /write-issue  — see README.md."
