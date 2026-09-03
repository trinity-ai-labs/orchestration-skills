#!/usr/bin/env bash
# Safely tear down a git worktree — the deterministic inverse of setup-worktree.sh.
#
#   remove-worktree.sh <branch-leaf-or-path>
#
# Run it from ANYWHERE inside the target repo (or set REPO=). Given the branch
# leaf (the segment past the last slash, e.g. "1322-compose-env") or the full
# absolute worktree path, it:
#
#   1. Kills every process whose cwd or open files are rooted in the worktree
#      path — BEFORE removing the directory. This is the critical step: a plain
#      `git worktree remove` evicts the directory but does NOT signal any running
#      processes, so a wrap-up `pnpm gate` (the machine-wide-lock holder) that
#      was detached or backgrounded by the implementer agent survives as an
#      orphan, keeping the lock long after the branch is gone and starving the
#      next agent waiting in the queue. Killing first releases the lock cleanly.
#      On Windows it is even more load-bearing: the OS locks open files, so a
#      surviving process makes the removal in step 2 fail outright.
#
#   2. Runs `git worktree remove <path> --force` + `git worktree prune` to
#      unregister the worktree from git.
#
# Safety invariants:
#   - Only kills processes rooted at the EXACT absolute worktree path (trailing
#     slash anchored), so a leaf named "1322-foo" cannot match "1322-foo-retry".
#   - REFUSES outright when the running script, or the directory it is being run
#     from, is itself inside the target path: the scan below would find THIS
#     process and kill it mid-teardown, leaving the tree removed, the caller dead,
#     and whatever the caller was in the middle of (a merge, most of the time)
#     silently undone.
#   - Prints every candidate PID + command before killing; you can see exactly
#     what will be terminated.
#   - Escalates SIGTERM → SIGKILL with a brief pause so in-flight cleanup runs
#     where possible (node's process.on('exit') release path).
#   - Idempotent: if the path doesn't exist or no processes match, no-ops cleanly.
#   - But "the path I computed does not exist" and "the worktree I was asked to
#     remove is already gone" are DIFFERENT claims, and only the second one is a
#     clean no-op. When a leaf resolves to nothing, git's worktree registry is
#     consulted before the no-op is claimed: a registered worktree named for that
#     leaf sitting somewhere else means this run looked in the wrong place, and
#     that fails loudly rather than reporting a teardown that never happened.
#   - Exits non-zero with a descriptive message on real failure.
#   - Keeps the two PID namespaces STRICTLY separate. A Windows PID and an MSYS
#     PID are unrelated numbers from unrelated counters, so passing one to the
#     other's killer targets whatever unrelated process happens to hold that
#     number. POSIX PIDs go only to `kill`; Windows PIDs go only to `taskkill`.
#
# Caveats:
#   - On macOS/Linux, lsof enumerates processes with open fds/cwd under the
#     worktree. On Linux, /proc/<pid>/fd + /proc/<pid>/cwd could substitute.
#   - Under Git Bash on Windows neither lsof nor pgrep exists, so the scan uses
#     Win32_Process command lines via powershell.exe instead. There is no cheap
#     open-handle equivalent of `lsof +D` there (it needs Sysinternals
#     handle.exe), so that half is reported as SKIPPED rather than left to read
#     as "nothing found" — see the notice the script prints.
#   - Process detection is best-effort: a process that closed all fds pointing
#     into the worktree before removal would not be detected by lsof alone.
#     The lsof + argv scan (pkill) combination covers the common cases.
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
# exactly as the kill scan below anchors WT_PREFIX, so ".../1322-foo" cannot match
# ".../1322-foo-retry" — this decides a REFUSAL, and an over-eager match here would
# block a legitimate teardown rather than merely fail to prevent a bad one.
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
worktree_home_default() {
  if is_windows && [ -n "${LOCALAPPDATA:-}" ]; then
    printf '%s/wt\n' "$(norm_path "$LOCALAPPDATA")"
  else
    printf '%s/.worktrees\n' "$HOME"
  fi
}

# "Absolute" has two spellings under Git Bash. A Windows-form path (C:/… or C:\…)
# does not start with a slash, so a `== /*` test files it as a BRANCH LEAF and the
# script then resolves $WORKTREE_HOME/<project>/C:/… — a path that never exists,
# so the run reports "already removed" and exits 0 having removed nothing.
is_abs_path() { # is_abs_path <string>
  case "$1" in
  /*) return 0 ;;
  [A-Za-z]:[\\/]*) return 0 ;;
  *) return 1 ;;
  esac
}

WORKTREE_HOME="${WORKTREE_HOME:-$(worktree_home_default)}"

# printf '%b' rather than echo, so a message can carry the `\n` its recovery
# instructions need: bash's builtin echo prints those two characters verbatim, so a
# multi-line message written with it arrives as one line with a literal \n inside —
# and the PowerShell sibling, whose `\n` IS a newline, would then say something the
# bash side does not.
die() { printf 'remove-worktree: error: %b\n' "$*" >&2; exit 1; }

if [ $# -lt 1 ]; then
  echo "usage: remove-worktree.sh <branch-leaf-or-absolute-path>" >&2
  echo "  e.g. remove-worktree.sh 1322-compose-env" >&2
  echo "  e.g. remove-worktree.sh /Users/you/.worktrees/my-project/1322-compose-env" >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 1
fi

INPUT="$1"
REPO="${REPO:-$PWD}"

# --- Resolve the worktree path -------------------------------------------------
# If the input looks like an absolute path, trust it directly; otherwise treat
# it as a branch leaf and resolve it via the repo the caller is standing in.
# LEAF stays empty on the absolute-path branch: it is what the checks below use
# to tell "the caller NAMED this path" from "this script DERIVED it", and only a
# derived path can have been derived wrongly.
LEAF=""
if is_abs_path "$INPUT"; then
  WT="$INPUT"
else
  # Resolve the MAIN working tree — same logic as setup-worktree.sh.
  if ! COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    die "not inside a git repo: $REPO\n  run from inside the target repo, or set REPO=/path/to/repo"
  fi
  COMMON=$(norm_path "$COMMON")
  MAIN=$(dirname "$COMMON")
  PROJECT=$(basename "$MAIN")
  # setup-worktree.sh names the dir after the segment past the LAST slash
  # (e.g. `feat/1319-foo` → `1319-foo`), so derive the leaf the same way —
  # otherwise a full branch name resolves to a non-existent nested path.
  LEAF="${INPUT##*/}"
  WT="$WORKTREE_HOME/$PROJECT/$LEAF"
  # A repo inside a workspace (a containing folder of sibling repos, marked by
  # .agents/workspace.json) keeps its worktrees under the WORKSPACE's namespace
  # rather than its own — setup-worktree.sh puts them at
  # $WORKTREE_HOME/<workspace>/<leaf>/<repo>. Assembling only the bare layout
  # here resolved a path that never exists for every workspace member, so the run
  # printed "already removed" and exited 0 with the tree still standing — and
  # merge-pr, whose teardown step this is, then ran `--delete-branch` against a
  # branch still checked out in a live worktree.
  #
  # Accepting EITHER layout rather than switching outright, which is the same
  # answer merge-pr's wrong-repo guard already gives: a tree cut before its repo
  # moved into a workspace sits at the bare path, and a teardown that could no
  # longer see it would be this same bug pointing the other way.
  #
  # WORKTREE_DEST is deliberately NOT read here, even though setup-worktree.sh
  # branches on it first. It is a CREATION-time input — setup-workspace.sh sets it
  # to place a tree it is about to cut — and at teardown a caller already has a way
  # to name an exact path: pass it as the argument. Reading it would make one stale
  # export silently redirect every later `remove-worktree <leaf>` at a single fixed
  # path regardless of which leaf was asked for.
  WORKSPACE_ROOT="$(dirname "$MAIN")"
  if [ -f "$WORKSPACE_ROOT/.agents/workspace.json" ]; then
    WORKSPACE_WT="$WORKTREE_HOME/$(basename "$WORKSPACE_ROOT")/$LEAF/$PROJECT"
    if [ -d "$WORKSPACE_WT" ] || [ ! -d "$WT" ]; then
      WT="$WORKSPACE_WT"
    fi
  fi
fi

# Normalise the ASSEMBLED path, whichever branch produced it — both are
# caller-influenced (an absolute $INPUT, or a $WORKTREE_HOME that may have been
# exported in Windows form), and WT_PREFIX below is prefix-matched against
# process output, so a stray form here silently matches nothing.
WT="$(norm_path "$WT")"
WT="${WT%/}"

echo "remove-worktree: target path: $WT"

# --- Idempotent path-exists check ----------------------------------------------
if [ ! -d "$WT" ]; then
  echo "remove-worktree: path does not exist or already removed: $WT"
  # Still need to know which repo to prune. If we resolved from REPO above,
  # COMMON/MAIN are already set; otherwise derive it from REPO — NOT from $WT,
  # which this branch has just established is not a directory, so `git -C "$WT"`
  # could only ever fail. It did: the .sh printed "cannot find repo" and skipped
  # the prune on every absolute-path call, leaving the stale registration behind,
  # while the .ps1 fell back to REPO and pruned it. Same command, same input, two
  # results — the semantic drift the parity check compares surface shape too high
  # up to see, and which AGENTS.md therefore leaves to review.
  if is_abs_path "$INPUT"; then
    if COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
      MAIN=$(dirname "$(norm_path "$COMMON")")
    else
      echo "remove-worktree: cannot find repo for $WT — skipping prune" >&2
      exit 0
    fi
  fi

  # Idempotence is right and stays: re-running a close-out whose tree is genuinely
  # gone must succeed. What must NOT stay is the conflation — "nothing is at the
  # path I derived" and "the worktree I was asked to remove is already gone" are
  # different claims, and both printed the line above and exited 0. That is
  # precisely why the workspace-layout miss went unnoticed: a teardown that looked
  # in the wrong place is byte-identical to one with nothing left to do, so no
  # caller could tell them apart without parsing a message that says the same thing
  # either way. git's registry answers it — it is the authority on which worktrees
  # this repo has, whatever path they sit at — so ask before claiming the no-op.
  #
  # Only for a DERIVED path. An absolute one was named by the caller, so there is
  # no derivation to have got wrong and nothing here to second-guess.
  #
  # A candidate is a stray only if it is somewhere ELSE and actually on disk: a
  # registration left behind by a hand-deleted directory points at nothing, and
  # prune below is exactly its remedy rather than a wrong-path error.
  if [ -n "$LEAF" ]; then
    STRAY=""
    MAIN_REAL=$(real_dir "$MAIN")
    while IFS= read -r cand; do
      cand="$(norm_path "$cand")"
      [ -n "$cand" ] || continue
      # Both layouts this helper knows: <leaf> at the end (bare), and
      # <workspace>/<leaf>/<repo> (a workspace member) one segment up.
      CAND_PARENT="${cand%/*}"
      [ "${cand##*/}" = "$LEAF" ] || [ "${CAND_PARENT##*/}" = "$LEAF" ] || continue
      [ "$cand" != "$WT" ] || continue
      # Through real_dir, because this decides a REFUSAL and one directory has more
      # than one spelling — a raw string compare that misses would report the main
      # checkout as a stray and block a legitimate teardown.
      [ "$(real_dir "$cand")" != "$MAIN_REAL" ] || continue
      [ -d "$cand" ] || continue
      STRAY="$cand"
      break
    done < <(git -C "$MAIN" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    if [ -n "$STRAY" ]; then
      die "no worktree at $WT, but $MAIN has one REGISTERED at $STRAY whose directory is named '$LEAF' — this run resolved the wrong path and has removed nothing.\n  Tear it down by its absolute path instead:\n    remove-worktree.sh $STRAY"
    fi
  fi

  # Announced here rather than beside the message above, so a run that stops on the
  # stray check does not first claim it is about to prune and then not do it.
  echo "  running git worktree prune to clean stale refs..."
  # Checked by hand rather than left to `set -e`, here and at the teardown at the
  # bottom. Errexit does stop the run, but it stops it MUTE and with GIT's status
  # — 128 for most git failures — where every other refusal in this file exits 1
  # through die(). The PowerShell sibling has always checked $LASTEXITCODE at
  # each of these three calls and exited 1 with exactly this message; two ports
  # returning different codes for the same input is the drift the frozen contract
  # exists to prevent, and nothing catches it, because the parity check reads
  # surface shape rather than semantics.
  git -C "$MAIN" worktree prune || die "git worktree prune failed (exit $?)"
  echo "remove-worktree: done (path was already absent)."
  exit 0
fi

# --- Derive MAIN if we took the absolute-path branch ---------------------------
# We need MAIN for git worktree remove. The worktree itself is a git repo
# (its .git is a gitfile pointing back), so we can find COMMON from it.
if is_abs_path "$INPUT"; then
  if ! COMMON=$(git -C "$WT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    # Worktree exists but git can't see it (already unregistered?). Force-rm and exit.
    echo "remove-worktree: worktree dir exists but is not a git repo; removing directory only."
    rm -rf "$WT"
    exit 0
  fi
  MAIN=$(dirname "$(norm_path "$COMMON")")
fi

# --- Refuse to tear down the tree this process is running in --------------------
# The scan below finds processes by their open descriptors and cwd (lsof) and by
# their argv (pgrep), and it excludes exactly one PID: this script's own. That is
# not enough when the script IS inside the tree, because the caller is then rooted
# there too — the copy being executed lives in the doomed path, or the caller is
# simply standing in it, or both. The scan finds that caller and SIGTERMs it, this
# script goes on to remove the tree, and the caller dies mid-flight with whatever it
# was doing undone. It is worst through merge-pr, whose teardown step this is: the
# tree goes, the PR is never merged, and the transcript ends on these teardown lines
# reporting success, because this process outlives the one that would have reported
# the failure.
#
# Refusing rather than re-execing from somewhere safe: which copy to re-exec is a
# guess (the installed one may be a different version, or absent), and silently
# running code the caller did not name is worse than stopping with a message.
#
# Both comparisons are string prefixes rather than a process scan, so they hold
# identically where the scan is degraded: under Git Bash neither lsof nor pgrep
# exists, and there the same overlap makes the `git worktree remove` below fail on
# files Windows has locked instead.
SELF_DIR=$(real_dir "$(norm_path "$(dirname "${BASH_SOURCE[0]}")")")
WT_REAL=$(real_dir "$WT")
if path_inside "$SELF_DIR" "$WT_REAL"; then
  die "this copy of remove-worktree.sh lives at $SELF_DIR/remove-worktree.sh, INSIDE the worktree it was asked to remove ($WT) — REFUSED, and nothing has been killed or removed.\n  The scan below would find this process and whatever invoked it, kill them, and remove the tree out from under the run.\n  Run a copy that lives OUTSIDE that tree — bare off PATH is the installed one:\n    remove-worktree.sh $INPUT"
fi
if path_inside "$(real_dir "$PWD")" "$WT_REAL"; then
  die "this run's working directory ($PWD) is INSIDE the worktree it was asked to remove ($WT) — REFUSED, and nothing has been killed or removed.\n  The scan below matches on cwd, so it would find this process and whatever invoked it, kill them, and remove the tree out from under the run.\n  Re-run from outside that tree — the helper resolves the repo from cwd, so stand in the main checkout:\n    cd $MAIN\n    remove-worktree.sh $INPUT"
fi

# --- Kill processes rooted in the worktree FIRST --------------------------------
# Anchor on the exact path + a trailing slash so:
#   /path/to/1322-compose-env/   matches everything inside
#   /path/to/1322-compose-env    matches exactly the dir itself (lsof cwd)
#   /path/to/1322-compose-env-2/ does NOT match (different leaf)
WT_PREFIX="${WT}/"  # trailing slash anchor for substring matches

echo "remove-worktree: scanning for processes using $WT ..."

# Collect PIDs via complementary methods. The two namespaces are kept in SEPARATE
# arrays and never merged — see the safety invariant at the top of this file:
#   PIDS      POSIX/MSYS PIDs, from lsof and pgrep. Only these reach `kill`.
#   WIN_PROCS "<windows-pid><TAB><command line>", from Win32_Process. Only these
#             reach `taskkill`.
#
#   A) lsof: processes with open file descriptors or cwd pointing into the tree.
#   B) pgrep on the argv: catches processes that cd'd in and closed their fds
#      (e.g. a shell that eval'd a command and closed the script fd).
#   C) Win32_Process command lines: the Git-Bash-on-Windows stand-in for (B),
#      because neither lsof nor pgrep exists there. Both (A) and (B) are
#      `command -v`-guarded, so without (C) the scan on Windows finds exactly
#      zero processes, reports "no running processes found", and the removal
#      then fails on files the OS still has locked.
# Methods A/B are filtered to PIDs whose path starts with the exact WT_PREFIX
# (or equals WT for cwd). We deduplicate the union.

PIDS=()
WIN_PROCS=()

# Method A: lsof (macOS). -w suppresses warnings, +D recurses the directory.
# Filter to paths that start with WT (exact dir) or WT_PREFIX (inside the dir).
if command -v lsof >/dev/null 2>&1; then
  # +D is expensive on large node_modules trees; we pipe through awk to filter
  # for safety, matching the exact WT path or anything under it.
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && PIDS+=("$pid")
  done < <(
    lsof -w +D "$WT" 2>/dev/null \
      | awk -v wt="$WT" -v pfx="${WT_PREFIX}" '
          NR>1 {
            # Column 2 is the PID; column 9 is the NAME (path).
            pid=$2; path=$NF
            if (path == wt || index(path, pfx) == 1) print pid
          }
        ' \
      | sort -u
  )
fi

# Method B: pgrep on the exact path string in the command line.
# Anchor to the WT_PREFIX so "1322-foo" cannot match "1322-foo-retry".
# pgrep -f matches the full argv string.
if command -v pgrep >/dev/null 2>&1; then
  while IFS= read -r pid; do
    [[ -n "$pid" ]] && PIDS+=("$pid")
  done < <(
    pgrep -f "${WT_PREFIX}" 2>/dev/null || true
  )
fi

# Method C: Win32_Process, via whichever PowerShell is present.
#
# The needle is passed through the ENVIRONMENT rather than interpolated into the
# script text: it is a filesystem path, so quoting it into a PowerShell literal
# is a quoting problem with a real failure mode, and any `/`-leading argument on
# the command line risks MSYS' automatic path mangling on the way across.
# Both separator spellings are matched because a command line may carry either.
win_scan_procs() {
  local ps_exe='' cand wt_win needle_bs needle_fs self_winpid=0
  for cand in powershell.exe pwsh.exe pwsh; do
    if command -v "$cand" >/dev/null 2>&1; then
      ps_exe="$cand"
      break
    fi
  done
  [ -n "$ps_exe" ] || return 0
  command -v cygpath >/dev/null 2>&1 || return 0

  wt_win="$(cygpath -w "$WT" 2>/dev/null)" || return 0
  [ -n "$wt_win" ] || return 0
  needle_bs="$(printf '%s\\' "$wt_win" | tr '/' '\\' | tr '[:upper:]' '[:lower:]')"
  needle_fs="$(printf '%s/' "$wt_win" | tr '\\' '/' | tr '[:upper:]' '[:lower:]')"

  # Our own Windows PID, so the ancestor walk below can exclude this shell and
  # everything that launched it. `taskkill /T` kills a whole process TREE, so a
  # self-match — which happens the moment the caller passes an absolute path,
  # since that path is then in this script's own argv — would take down the
  # terminal, the agent session, or CI along with the worktree.
  if [ -r "/proc/$$/winpid" ]; then
    self_winpid="$(tr -d '[:space:]' <"/proc/$$/winpid")"
  fi

  MSYS_NO_PATHCONV=1 \
    WT_NEEDLE_BS="$needle_bs" \
    WT_NEEDLE_FS="$needle_fs" \
    WT_SELF_WINPID="$self_winpid" \
    "$ps_exe" -NoProfile -NonInteractive -Command '
      $ErrorActionPreference = "Stop"
      $a = $env:WT_NEEDLE_BS
      $b = $env:WT_NEEDLE_FS
      $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
      $byId = @{}
      foreach ($p in $procs) { $byId[[int]$p.ProcessId] = $p }
      $skip = New-Object "System.Collections.Generic.HashSet[int]"
      $cur = [int]$env:WT_SELF_WINPID
      while ($cur -ne 0 -and $byId.ContainsKey($cur) -and -not $skip.Contains($cur)) {
        [void]$skip.Add($cur)
        $cur = [int]$byId[$cur].ParentProcessId
      }
      foreach ($p in $procs) {
        if ($skip.Contains([int]$p.ProcessId)) { continue }
        if (-not $p.CommandLine) { continue }
        $c = $p.CommandLine.ToLower()
        if ($c.Contains($a) -or $c.Contains($b)) {
          "{0}`t{1}" -f $p.ProcessId, $p.CommandLine
        }
      }
    ' 2>/dev/null | tr -d '\r' || true
}

if is_windows; then
  while IFS= read -r line; do
    [ -n "$line" ] && WIN_PROCS+=("$line")
  done < <(win_scan_procs)

  # Say what did NOT run. `lsof +D` has no cheap Windows equivalent — enumerating
  # open handles needs Sysinternals handle.exe, which this script will not assume
  # is installed — so only the command-line scan above ran. Without saying so, a
  # process holding a file open without the path in its argv produces the same
  # silent "no processes found" as a genuinely idle worktree, and the difference
  # only surfaces as `git worktree remove` failing on a locked file.
  echo "remove-worktree: NOTE (Windows): open-handle enumeration is SKIPPED." >&2
  echo "  There is no built-in equivalent of 'lsof +D' (it needs Sysinternals" >&2
  echo "  handle.exe), so only the command-line scan ran. A process holding a file" >&2
  echo "  open inside the worktree without the path in its argv will not be found" >&2
  echo "  here — if the removal below fails on a locked file, that is why." >&2
fi

# Deduplicate and exclude self (this script's own PID)
SELF=$$
UNIQUE_PIDS=()
# macOS ships bash 3.2, which has no associative arrays — dedup the PID list by
# piping through `sort -un` and dropping our own PID, instead of a SEEN map.
# (Also guard the empty case: "${PIDS[@]}" under `set -u` is an error on 3.2.)
if [ "${#PIDS[@]}" -gt 0 ]; then
  while IFS= read -r pid; do
    [ -n "$pid" ] && UNIQUE_PIDS+=("$pid")
  done < <(printf '%s\n' "${PIDS[@]}" | grep -vx "$SELF" | sort -un)
fi

if [ "${#UNIQUE_PIDS[@]}" -eq 0 ] && [ "${#WIN_PROCS[@]}" -eq 0 ]; then
  echo "remove-worktree: no running processes found in $WT"
fi

if [ "${#UNIQUE_PIDS[@]}" -gt 0 ]; then
  echo "remove-worktree: found ${#UNIQUE_PIDS[@]} process(es) to terminate:"
  for pid in "${UNIQUE_PIDS[@]}"; do
    # Print PID + command for transparency
    cmd=$(ps -p "$pid" -o pid=,args= 2>/dev/null || echo "$pid  <already exited>")
    echo "  $cmd"
  done

  # SIGTERM first — gives node's process.on('exit') release() a chance to run,
  # which removes the lock directory cleanly rather than leaving a stale lockfile.
  echo "remove-worktree: sending SIGTERM ..."
  for pid in "${UNIQUE_PIDS[@]}"; do
    kill -TERM "$pid" 2>/dev/null || true
  done

  # Brief pause — enough for a clean SIGTERM handler to run and the lock dir to
  # be removed, but short enough to not stall the dispatcher.
  sleep 2

  # SIGKILL any survivors. A SIGKILL'd gate process will leave its slot dir
  # behind, but gate-slot.mjs's dead-holder detection (holderIsDead) steals the
  # stale slot on the next acquire, and gate-runner.mjs reclaims the killed
  # runner's in-flight ticket back onto the queue — so no manual cleanup is
  # required even in the SIGKILL path.
  SURVIVORS=()
  for pid in "${UNIQUE_PIDS[@]}"; do
    kill -0 "$pid" 2>/dev/null && SURVIVORS+=("$pid") || true
  done

  if [ "${#SURVIVORS[@]}" -gt 0 ]; then
    echo "remove-worktree: ${#SURVIVORS[@]} process(es) survived SIGTERM; sending SIGKILL ..."
    for pid in "${SURVIVORS[@]}"; do
      kill -KILL "$pid" 2>/dev/null || true
    done
    sleep 1
  else
    echo "remove-worktree: all processes exited cleanly after SIGTERM."
  fi
fi

if [ "${#WIN_PROCS[@]}" -gt 0 ]; then
  echo "remove-worktree: found ${#WIN_PROCS[@]} Windows process(es) to terminate:"
  for entry in "${WIN_PROCS[@]}"; do
    echo "  [win pid ${entry%%$'\t'*}]  ${entry#*$'\t'}"
  done
  # No SIGTERM analogue here, so no two-stage escalation: Windows' only graceful
  # signal is WM_CLOSE, which a console process such as a test runner does not
  # handle at all, and every second spent waiting for it is a second the file
  # stays locked. /T takes the whole process tree, because a package-manager
  # script's children are what actually hold the file handles.
  #
  # MSYS_NO_PATHCONV=1 because Git Bash rewrites any argument that starts with a
  # slash into a Windows path — without it, `/PID` arrives as
  # `C:/Program Files/Git/PID` and taskkill rejects the whole invocation.
  if ! command -v taskkill >/dev/null 2>&1; then
    echo "remove-worktree: taskkill not found on PATH — cannot terminate the Windows" >&2
    echo "  processes listed above; the removal below will likely fail on locked files." >&2
  else
    for entry in "${WIN_PROCS[@]}"; do
      MSYS_NO_PATHCONV=1 taskkill /PID "${entry%%$'\t'*}" /T /F >/dev/null 2>&1 || true
    done
    sleep 1
  fi
fi

# --- Remove the worktree -------------------------------------------------------
echo "remove-worktree: removing worktree $WT ..."
# Both checked by hand, for the reason the prune on the already-absent path above
# gives: errexit would exit with git's status where every refusal here exits 1.
git -C "$MAIN" worktree remove "$WT" --force || die "git worktree remove failed (exit $?)"
git -C "$MAIN" worktree prune || die "git worktree prune failed (exit $?)"
echo "remove-worktree: done — $WT removed."
