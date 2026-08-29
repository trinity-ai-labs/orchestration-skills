#!/usr/bin/env pwsh
# Safely tear down a git worktree - the deterministic inverse of setup-worktree.ps1.
#
#   remove-worktree.ps1 <branch-leaf-or-path>
#
# The PowerShell sibling of remove-worktree.sh, for a native Windows session with
# no bash at all: no WSL and no Git for Windows, where Claude Code hands the agent
# the PowerShell tool and the .sh helper is not runnable. Same argument, the same
# WORKTREE_HOME / REPO environment variables, and the same exit codes, because the
# pair is ONE CLI contract implemented twice; scripts/check.sh compares the usage
# lines and the consumed env-var sets on every run so the two cannot drift apart.
#
# ASCII only, no exceptions - see the note in setup-worktree.ps1 for why (5.1
# decodes a BOM-less file as the system ANSI codepage, and the resulting parse
# error points nowhere near the offending byte).
#
# Given the branch leaf (the segment past the last slash, e.g. "1322-compose-env")
# or the full absolute worktree path, it:
#
#   1. Kills every process whose command line is rooted in the worktree path -
#      BEFORE removing the directory. This is the critical step, and on Windows it
#      is critical for a second reason: `git worktree remove` evicts the directory
#      but does NOT signal any running process, so a wrap-up gate that was detached
#      or backgrounded survives as an orphan holding the machine-wide lock long
#      after the branch is gone - AND Windows refuses to delete a file another
#      process still has open, so the removal itself fails outright rather than
#      quietly leaving an orphan. Killing first fixes both.
#
#   2. Runs `git worktree remove <path> --force` + `git worktree prune` to
#      unregister the worktree from git.
#
# Safety invariants:
#   - Only kills processes rooted at the EXACT absolute worktree path (trailing
#     slash anchored), so a leaf named "1322-foo" cannot match "1322-foo-retry".
#   - REFUSES outright when the running script, or the directory it is being run
#     from, is itself inside the target path: the scan below would find THIS
#     process and kill it mid-teardown, and Windows would refuse the removal on a
#     file the run itself has locked - leaving the caller dead or the tree half
#     gone, and whatever the caller was in the middle of (a merge, most of the
#     time) silently undone.
#   - Prints every candidate PID + command line before killing; you can see exactly
#     what will be terminated.
#   - Escalates a graceful close to a forced kill with a brief pause between them,
#     so in-flight cleanup runs where possible (node's process.on('exit') release
#     path). Windows has no SIGTERM: `taskkill /T` without /F asks the process tree
#     to close, which is the closest equivalent, and `Stop-Process -Force` is the
#     SIGKILL end of the escalation.
#   - Idempotent: if the path doesn't exist or no processes match, no-ops cleanly.
#   - Exits non-zero with a descriptive message on real failure.
#
# Caveats:
#   - The scan is an argv scan only, via Get-CimInstance Win32_Process. Windows has
#     no cheap open-handle enumerator equivalent to `lsof +D`, which the bash
#     sibling uses as its second, complementary method - so a process that holds a
#     file open under the worktree without naming it on its command line is not
#     found here. That degradation is PRINTED rather than assumed, because a silent
#     half-scan reads exactly like a clean one right up until `git worktree remove`
#     fails on a locked file.
#   - Win32_Process is a Windows-only class. On a non-Windows PowerShell the scan is
#     skipped with a notice; that platform has bash, so remove-worktree.sh is the
#     helper actually reached for there.

# The analogue of `set -e`. Cmdlet failures only: Windows PowerShell 5.1 does not
# fold a native command's exit code into $ErrorActionPreference, so every git call
# below checks $LASTEXITCODE explicitly.
$ErrorActionPreference = 'Stop'

function Write-Stderr {
    param([Parameter(Mandatory = $true)] [string] $Message)
    [Console]::Error.WriteLine($Message)
}

function Exit-WithError {
    param(
        [Parameter(Mandatory = $true)] [string] $Message,
        [int] $Code = 1
    )
    Write-Stderr "remove-worktree: error: $Message"
    exit $Code
}

function Get-NormalPath {
    # Git prints Windows paths with forward slashes (C:/Users/...) while Join-Path
    # and $HOME produce backslashes. Both work for filesystem calls; neither works
    # for STRING comparison against the other, and the kill scope below is decided
    # by exactly such a comparison - a mismatch there silently kills nothing.
    param([string] $Path)
    if (-not $Path) { return '' }
    $p = $Path -replace '\\', '/'
    while ($p.Length -gt 1 -and $p.EndsWith('/') -and -not $p.EndsWith(':/')) {
        $p = $p.Substring(0, $p.Length - 1)
    }
    return $p
}

function Get-RealPath {
    # A directory as the filesystem itself spells it, normalised to forward slashes
    # with no trailing separator. The guard below decides whether two paths are the
    # same tree by comparing them as strings, and one directory has more than one
    # spelling - a link, a relative form, a different case. Two spellings of one
    # directory compare unequal, which makes a guard that silently never fires. A
    # path that does not exist has nothing to resolve and comes back as it went in.
    param([string] $Path)
    if (-not $Path) { return '' }
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($resolved) { return (Get-NormalPath $resolved.ProviderPath) }
    return (Get-NormalPath $Path)
}

function Test-PathInside {
    # Is $Candidate the directory $Tree, or inside it? Anchored on the separator,
    # exactly as the kill scan below anchors its prefixes, so ".../1322-foo" cannot
    # match ".../1322-foo-retry" - this decides a REFUSAL, and an over-eager match
    # here would block a legitimate teardown rather than merely fail to prevent a
    # bad one. Case-insensitive, because Windows paths are.
    param(
        [Parameter(Mandatory = $true)] [string] $Candidate,
        [Parameter(Mandatory = $true)] [string] $Tree
    )
    if (-not $Candidate -or -not $Tree) { return $false }
    if ($Candidate.Equals($Tree, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $Candidate.StartsWith("$Tree/", [StringComparison]::OrdinalIgnoreCase)
}

function Get-RepoRoot {
    # Resolve the MAIN working tree. The common gitdir's parent is the repo root,
    # whether the path given is the repo root, a subdir, or a linked worktree (a
    # worktree's .git is a gitfile pointing back at the main checkout). Returns an
    # empty string when the path is not inside a git repo at all, so the caller
    # prints its own message with the REPO hint rather than leaking git's.
    param([Parameter(Mandatory = $true)] [string] $Path)
    $out = & git -C $Path rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    $common = Get-NormalPath (($out | Out-String).Trim())
    return (Get-NormalPath (Split-Path -Path $common -Parent))
}

function Get-WorktreeHome {
    # WORKTREE_HOME wins whenever it is set. Otherwise the default is
    # platform-dependent, and it MUST match the bash sibling byte for byte: on
    # Windows that is %LOCALAPPDATA%\wt rather than ~/.worktrees, because
    # ~/.worktrees/<workspace>/<leaf>/<repo>/node_modules/.pnpm/... routinely runs
    # past MAX_PATH's 260 characters. Disagreeing here is not cosmetic - merge-pr
    # reads this location to decide whether a merged PR still has anything to close
    # out, so a worktree cut in one shell would be invisible to the other and the
    # close-out would refuse with a "wrong repo" error against a perfectly good tree.
    if ($env:WORKTREE_HOME) { return $env:WORKTREE_HOME }
    if ((Test-OnWindows) -and $env:LOCALAPPDATA) { return (Join-Path $env:LOCALAPPDATA 'wt') }
    return (Join-Path $HOME '.worktrees')
}

function Test-OnWindows {
    # $IsWindows only exists from PowerShell 6 on. Windows PowerShell 5.1 is
    # Windows-only by construction, so its absence IS the answer - reading the
    # variable directly under 5.1 would just yield $null and mis-report the host.
    if (Test-Path -LiteralPath 'Variable:IsWindows') { return [bool] (Get-Variable -Name 'IsWindows' -ValueOnly) }
    return $true
}

if ($args.Count -lt 1) {
    Write-Stderr "usage: remove-worktree.ps1 <branch-leaf-or-absolute-path>"
    Write-Stderr "  e.g. remove-worktree.ps1 1322-compose-env"
    Write-Stderr "  e.g. remove-worktree.ps1 C:/Users/you/.worktrees/my-project/1322-compose-env"
    Write-Stderr "  run from inside the target repo, or set REPO=/path/to/repo"
    exit 1
}

$Target = [string]$args[0]

$WorktreeHome = Get-NormalPath (Get-WorktreeHome)

$Repo = $env:REPO
if (-not $Repo) { $Repo = (Get-Location).Path }

# --- Resolve the worktree path -------------------------------------------------
# If the input looks like an absolute path, trust it directly; otherwise treat it
# as a branch leaf and resolve it via the repo the caller is standing in. Both the
# POSIX form (/Users/...) and the Windows forms (C:\... and C:/...) count as
# absolute here: reading `C:/Users/you/.worktrees/x` as a branch LEAF would resolve
# a target path that does not exist, and the run would then no-op while reporting
# success on a worktree it never touched.
$Main = ''
if ($Target -match '^(/|[A-Za-z]:[\\/])') {
    $Wt = Get-NormalPath $Target
} else {
    $Main = Get-RepoRoot -Path $Repo
    if (-not $Main) {
        Exit-WithError "not inside a git repo: $Repo`n  run from inside the target repo, or set REPO=/path/to/repo"
    }
    $Project = Split-Path -Path $Main -Leaf
    # setup-worktree.ps1 names the dir after the segment past the LAST slash
    # (e.g. `feat/1319-foo` -> `1319-foo`), so derive the leaf the same way -
    # otherwise a full branch name resolves to a non-existent nested path.
    $Leaf = $Target.Substring($Target.LastIndexOf('/') + 1)
    $Wt = "$WorktreeHome/$Project/$Leaf"
}

Write-Output "remove-worktree: target path: $Wt"

# --- Idempotent path-exists check ----------------------------------------------
if (-not (Test-Path -LiteralPath $Wt)) {
    Write-Output "remove-worktree: path does not exist or already removed: $Wt"
    Write-Output "  running git worktree prune to clean stale refs..."
    # Still need to know which repo to prune. If we resolved from REPO above, $Main
    # is already set; otherwise derive it from the nearest repo.
    if (-not $Main) {
        $Main = Get-RepoRoot -Path $Repo
        if (-not $Main) {
            Write-Stderr "remove-worktree: cannot find repo for $Wt - skipping prune"
            exit 0
        }
    }
    & git -C $Main worktree prune
    if ($LASTEXITCODE -ne 0) { Exit-WithError "git worktree prune failed (exit $LASTEXITCODE)" }
    Write-Output "remove-worktree: done (path was already absent)."
    exit 0
}

# --- Derive MAIN if we took the absolute-path branch ---------------------------
# We need MAIN for git worktree remove. The worktree itself is a git repo (its
# .git is a gitfile pointing back), so we can find COMMON from it.
if (-not $Main) {
    $Main = Get-RepoRoot -Path $Wt
    if (-not $Main) {
        # Worktree exists but git can't see it (already unregistered?). Force-rm and exit.
        Write-Output "remove-worktree: worktree dir exists but is not a git repo; removing directory only."
        Remove-Item -LiteralPath $Wt -Recurse -Force
        exit 0
    }
}

# --- Refuse to tear down the tree this process is running in --------------------
# The scan below finds processes by their command line and excludes exactly one PID:
# this script's own. That is not enough when the script IS inside the tree, because
# the caller is then rooted there too - the copy being executed lives in the doomed
# path, or the caller is simply standing in it, or both. Where the scan matches that
# caller it kills it, this script goes on to remove the tree, and the caller dies
# mid-flight with whatever it was doing undone; where it does not, Windows refuses
# to delete a directory a process is standing in or has a file open under, and the
# removal fails on a locked file. It is worst through merge-pr, whose teardown step
# this is: the tree goes, the PR is never merged, and the transcript ends on these
# teardown lines reporting success.
#
# Refusing rather than re-execing from somewhere safe: which copy to re-exec is a
# guess (the installed one may be a different version, or absent), and silently
# running code the caller did not name is worse than stopping with a message. The
# bash sibling refuses on the same two signals, because the pair is ONE contract
# implemented twice and a command that refuses in one shell and proceeds in the
# other is the drift the contract exists to prevent.
$SelfDir = Get-RealPath $PSScriptRoot
$WtReal = Get-RealPath $Wt
if (Test-PathInside -Candidate $SelfDir -Tree $WtReal) {
    Exit-WithError @"
this copy of remove-worktree.ps1 lives at $SelfDir/remove-worktree.ps1, INSIDE the worktree it was asked to remove ($Wt) - REFUSED, and nothing has been killed or removed.
  The scan below would find this process and whatever invoked it, kill them, and remove the tree out from under the run.
  Run a copy that lives OUTSIDE that tree - bare off PATH is the installed one:
    remove-worktree.ps1 $Target
"@
}
if (Test-PathInside -Candidate (Get-RealPath (Get-Location).Path) -Tree $WtReal) {
    Exit-WithError @"
this run's working directory ($((Get-Location).Path)) is INSIDE the worktree it was asked to remove ($Wt) - REFUSED, and nothing has been killed or removed.
  The scan below would find this process and whatever invoked it, kill them, and remove the tree out from under the run.
  Re-run from outside that tree - the helper resolves the repo from cwd, so stand in the main checkout:
    cd $Main
    remove-worktree.ps1 $Target
"@
}

# --- Kill processes rooted in the worktree FIRST --------------------------------
# Anchor on the exact path + a trailing separator so:
#   <wt>/                matches everything inside
#   <wt>                 matches exactly the dir itself
#   <wt>-2/              does NOT match (different leaf)
# A command line on Windows may spell the path either way round, so both separator
# forms are tested - matching only one would silently find nothing.
$WtPrefixFwd = "$Wt/"
$WtPrefixBack = ($Wt -replace '/', '\') + '\'

Write-Output "remove-worktree: scanning for processes using $Wt ..."

$targets = @()
if (Test-OnWindows) {
    # Win32_Process exposes each process's full command line, which is the Windows
    # analogue of the bash sibling's `pgrep -f` argv scan. There is no cheap
    # equivalent of its OTHER method (`lsof +D`, open file descriptors), so this is
    # a strictly narrower scan and that gap is printed below rather than implied.
    $self = $PID
    foreach ($proc in (Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue)) {
        if ($proc.ProcessId -eq $self) { continue }
        $cmd = [string]$proc.CommandLine
        if (-not $cmd) { continue }
        if ($cmd.IndexOf($WtPrefixFwd, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
            $cmd.IndexOf($WtPrefixBack, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $targets += $proc
        }
    }
    Write-Output "remove-worktree: note - argv scan only (Win32_Process). Windows has no cheap"
    Write-Output "  open-handle enumerator, so a process holding a file under the worktree without"
    Write-Output "  naming it on its command line is NOT found; if the removal below fails on a"
    Write-Output "  locked file, that is the gap."
} else {
    Write-Stderr "remove-worktree: note - process scan skipped: Win32_Process is Windows-only."
    Write-Stderr "  On this platform bash exists, so remove-worktree.sh does the full lsof + pgrep scan."
}

if ($targets.Count -eq 0) {
    Write-Output "remove-worktree: no running processes found in $Wt"
} else {
    Write-Output "remove-worktree: found $($targets.Count) process(es) to terminate:"
    foreach ($proc in $targets) {
        Write-Output "  $($proc.ProcessId)  $($proc.CommandLine)"
    }

    # Graceful first. Windows has no SIGTERM; `taskkill /T` without /F asks the
    # process and its children to close, which gives node's process.on('exit')
    # release path a chance to run and remove a lock directory cleanly rather than
    # leaving a stale lockfile behind.
    Write-Output "remove-worktree: asking the process tree(s) to close ..."
    foreach ($proc in $targets) {
        & taskkill /PID $proc.ProcessId /T *> $null
    }

    # Brief pause - enough for a clean shutdown handler to run and the lock dir to
    # be removed, but short enough not to stall the dispatcher.
    Start-Sleep -Seconds 2

    # Force-kill any survivors. A force-killed gate process leaves its slot dir
    # behind, but a queue's dead-holder detection steals the stale slot on the next
    # acquire and its runner reclaims the killed ticket back onto the queue - so no
    # manual cleanup is required even in the forced path.
    $survivors = @()
    foreach ($proc in $targets) {
        if (Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue) { $survivors += $proc }
    }
    if ($survivors.Count -gt 0) {
        Write-Output "remove-worktree: $($survivors.Count) process(es) survived the close request; forcing ..."
        foreach ($proc in $survivors) {
            Stop-Process -Id $proc.ProcessId -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Seconds 1
    } else {
        Write-Output "remove-worktree: all processes exited cleanly."
    }
}

# --- Remove the worktree -------------------------------------------------------
Write-Output "remove-worktree: removing worktree $Wt ..."
& git -C $Main worktree remove $Wt --force
if ($LASTEXITCODE -ne 0) { Exit-WithError "git worktree remove failed (exit $LASTEXITCODE)" }
& git -C $Main worktree prune
if ($LASTEXITCODE -ne 0) { Exit-WithError "git worktree prune failed (exit $LASTEXITCODE)" }
Write-Output "remove-worktree: done - $Wt removed."
