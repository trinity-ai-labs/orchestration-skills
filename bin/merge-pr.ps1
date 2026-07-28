#!/usr/bin/env pwsh
# Merge a reviewed PR and clean up - the atomic close-out of the worktree flow.
#
#   merge-pr.ps1 <pr-number>
#
# The PowerShell sibling of merge-pr.sh, for a native Windows session with no bash
# at all: no WSL and no Git for Windows, where Claude Code hands the agent the
# PowerShell tool and the .sh helper is not runnable. Same argument, the same
# WORKTREE_HOME / REPO / MERGE_PR_FORCE environment variables, and the same exit
# codes, because the pair is ONE CLI contract implemented twice; scripts/check.sh
# compares the usage lines and the consumed env-var sets on every run so the two
# cannot drift apart.
#
# ASCII only, no exceptions - see the note in setup-worktree.ps1 for why.
#
# Run it from ANYWHERE inside the target repo (or set REPO=). It performs the whole
# "Merge & cleanup" sequence as ONE command, in the one correct order, so no
# load-bearing step can be dropped:
#
#   1. Resolve the MAIN checkout + the PR's base (integration) and head branch.
#   2. Remove the head branch's worktree FIRST - git refuses to delete a branch
#      that's still checked out in a worktree, so `gh pr merge --delete-branch`
#      would error on the local-branch step if the worktree still existed. Done
#      via remove-worktree.ps1, which kills processes rooted in the tree first.
#   3. Mark the PR ready - the orchestrator's review approval - and immediately
#      `gh pr merge --merge --delete-branch` it: a real merge commit (never
#      squash), deleting both the local and remote branch.
#   4. Sync the MAIN checkout's local integration branch to the just-merged tip.
#
# Step 4 is the whole reason this helper exists. `gh pr merge` advances the branch
# on the REMOTE; the local integration branch in the main checkout does NOT move.
# Syncing it is a manual step with NO forcing feedback - every visible signal
# (Merged, branch deleted, PR closed) says "done", so it is the step that gets
# silently skipped, and the miss only surfaces later when the NEXT worktree is cut
# from a stale HEAD. This helper anchors every git call to the MAIN checkout with
# `git -C $Main`, independent of cwd, and fast-forwards only (the main checkout
# never carries direct commits, so a non-ff means something is wrong and should
# surface loudly, not merge-commit past).
#
# Idempotent: if the PR is already merged, it skips the merge and still runs the
# worktree teardown + local sync, so a re-run finishes a half-done close-out.

# The analogue of `set -e`. Cmdlet failures only: Windows PowerShell 5.1 does not
# fold a native command's exit code into $ErrorActionPreference, so every git / gh
# call below checks $LASTEXITCODE explicitly.
$ErrorActionPreference = 'Stop'

$Here = $PSScriptRoot

function Write-Stderr {
    param([Parameter(Mandatory = $true)] [string] $Message)
    [Console]::Error.WriteLine($Message)
}

function Exit-WithError {
    param(
        [Parameter(Mandatory = $true)] [string] $Message,
        [int] $Code = 1
    )
    Write-Stderr "merge-pr: error: $Message"
    exit $Code
}

function Get-NormalPath {
    # Git prints Windows paths with forward slashes while Join-Path produces
    # backslashes; the two never compare equal as strings, and the wrong-repo guard
    # below is decided by exactly such a comparison.
    param([string] $Path)
    if (-not $Path) { return '' }
    $p = $Path -replace '\\', '/'
    while ($p.Length -gt 1 -and $p.EndsWith('/') -and -not $p.EndsWith(':/')) {
        $p = $p.Substring(0, $p.Length - 1)
    }
    return $p
}

function Test-OnWindows {
    # $IsWindows only exists from PowerShell 6 on. Windows PowerShell 5.1 is
    # Windows-only by construction, so its absence IS the answer - reading the
    # variable directly under 5.1 would just yield $null and mis-report the host.
    if (Test-Path -LiteralPath 'Variable:IsWindows') { return [bool] (Get-Variable -Name 'IsWindows' -ValueOnly) }
    return $true
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

function Test-GitSuccess {
    param([Parameter(Mandatory = $true)] [string[]] $GitArgs)
    & git @GitArgs *> $null
    return ($LASTEXITCODE -eq 0)
}

function Get-GitOutput {
    param([Parameter(Mandatory = $true)] [string[]] $GitArgs)
    $out = & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError ("git " + ($GitArgs -join ' ') + " failed (exit $LASTEXITCODE)")
    }
    return (($out | Out-String).Trim())
}

function Get-RepoRoot {
    # Resolve the MAIN working tree. The common gitdir's parent is the repo root,
    # whether cwd is the root, a subdir, a monorepo package, or a linked worktree.
    # Returns an empty string when the path is not inside a git repo at all, so the
    # caller prints its own message with the REPO hint rather than leaking git's.
    param([Parameter(Mandatory = $true)] [string] $Path)
    $out = & git -C $Path rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    $common = Get-NormalPath (($out | Out-String).Trim())
    return (Get-NormalPath (Split-Path -Path $common -Parent))
}

if ($args.Count -lt 1) {
    Write-Stderr "usage: merge-pr.ps1 <pr-number>"
    Write-Stderr "  e.g. merge-pr.ps1 2094"
    Write-Stderr "  run from inside the target repo, or set REPO=/path/to/repo"
    exit 1
}

$Pr = [string]$args[0]

$WorktreeHome = Get-NormalPath (Get-WorktreeHome)

$Repo = $env:REPO
if (-not $Repo) { $Repo = (Get-Location).Path }

if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
    Exit-WithError "gh (GitHub CLI) not found on PATH"
}

# Same logic as setup-worktree.ps1 / remove-worktree.ps1. It is duplicated in each
# helper rather than factored into a shared module on purpose: bin/ is held to the
# parity rule (every .sh has a .ps1 sibling and vice versa), so a bin/common.ps1
# with no bash counterpart would fail the gate, and bin/ is on a user's PATH, where
# a file that is a library rather than a command does not belong.
$Main = Get-RepoRoot -Path $Repo
if (-not $Main) {
    Exit-WithError "not inside a git repo: $Repo`n  run from inside the target repo, or set REPO=/path/to/repo"
}

function Invoke-InMainCheckout {
    # gh resolves the repo from the current directory, so every gh call has to run
    # from the MAIN checkout - not from wherever the caller happened to stand, which
    # for an orchestrator is usually inside some other repo's worktree entirely, and
    # same-numbered PRs exist in every repo.
    param([Parameter(Mandatory = $true)] [scriptblock] $Body)
    Push-Location -LiteralPath $Main
    try { & $Body } finally { Pop-Location }
}

# One gh call for all four fields rather than one call per field: each invocation
# is a process spawn plus an API round trip, and reading them separately also opens
# a window in which the PR could change between reads, leaving this run acting on a
# state that never existed all at once. ConvertFrom-Json is built in, so parsing the
# result costs nothing extra.
$prJson = Invoke-InMainCheckout {
    $raw = & gh pr view $Pr --json state,baseRefName,headRefName,mergeCommit
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($raw | Out-String).Trim())
}
if (-not $prJson) {
    Exit-WithError "could not read PR #$Pr (is the number right? is gh authed?)"
}
try {
    $pr = $prJson | ConvertFrom-Json
} catch {
    Exit-WithError "gh returned something that is not JSON for PR #${Pr}: $($_.Exception.Message)"
}

$State = [string]$pr.state
$Integration = [string]$pr.baseRefName
$HeadBranch = [string]$pr.headRefName
# Absent until the PR is actually merged; the sync loop below falls back to plain
# ref equality when it is empty.
$MergeOid = ''
if ($pr.mergeCommit) { $MergeOid = [string]$pr.mergeCommit.oid }
if (-not $Integration) { Exit-WithError "PR #$Pr has no base branch" }

Write-Output "merge-pr: PR #$Pr  state=$State  base=$Integration  head=$HeadBranch  main=$Main"

# --- 0. Wrong-repo guard ---------------------------------------------------------
# The repo is resolved from cwd/REPO, so a shell sitting in a DIFFERENT repo's
# checkout makes every step below operate on that repo - same-numbered PRs exist
# everywhere, so the gh calls above still "succeed" and nothing else would catch
# it. Verify PR #$Pr actually belongs to this working set before touching anything.
$Leaf = $HeadBranch.Substring($HeadBranch.LastIndexOf('/') + 1)
$Project = Split-Path -Path $Main -Leaf
# A workspace member's worktree lives at $WORKTREE_HOME/<workspace>/<slug>/<project>,
# not the bare $WORKTREE_HOME/<project>/<slug> layout used outside a workspace - so
# the existence check below must accept either, or it misfires "wrong repo" for
# every workspace member even when its worktree is exactly where setup-worktree put it.
$WorkspaceRoot = Get-NormalPath (Split-Path -Path $Main -Parent)
$WorkspaceWt = ''
if (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.agents/workspace.json')) {
    $WorkspaceWt = "$WorktreeHome/$(Split-Path -Path $WorkspaceRoot -Leaf)/$Leaf/$Project"
}
if ($State -eq 'MERGED') {
    # Idempotent-rerun case: finishing a half-done close-out implies SOME local
    # residue - a worktree in either layout, or the local head branch. Neither
    # existing means there is nothing to close out here: almost certainly the
    # wrong repo.
    $plainWt = "$WorktreeHome/$Project/$Leaf"
    $hasPlain = Test-Path -LiteralPath $plainWt
    $hasWorkspace = $WorkspaceWt -and (Test-Path -LiteralPath $WorkspaceWt)
    $hasBranch = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/heads/$HeadBranch")
    if (-not $hasPlain -and -not $hasWorkspace -and -not $hasBranch -and $env:MERGE_PR_FORCE -ne '1') {
        $where = $plainWt
        if ($WorkspaceWt) { $where = "$plainWt or $WorkspaceWt" }
        Exit-WithError "PR #$Pr is already MERGED and neither a worktree ($where) nor a local branch '$HeadBranch' exists in $Main - nothing to close out here. WRONG REPO? cd into the intended repo and re-run (or MERGE_PR_FORCE=1 to run teardown+sync here anyway)."
    }
} else {
    $known = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/heads/$HeadBranch")
    if (-not $known) {
        $known = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/remotes/origin/$HeadBranch")
    }
    if (-not $known) {
        if (Test-GitSuccess @('-C', $Main, 'fetch', '--prune', 'origin')) {
            $known = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/remotes/origin/$HeadBranch")
        }
    }
    if (-not $known) {
        Exit-WithError "PR #$Pr's head branch '$HeadBranch' is unknown in $Main (not local, not on origin) - WRONG REPO? The repo is resolved from cwd/REPO; cd into the intended repo and re-run."
    }
}

# --- 1. Remove the head branch's worktree FIRST --------------------------------
# So `--delete-branch` can remove the local branch. remove-worktree.ps1 is
# idempotent (no-ops if the worktree is already gone) and derives the worktree path
# from the branch leaf against this same repo. REPO is handed over through the
# environment rather than a `$env:` assignment expression so the parity check's
# env-var scan sees only what this script CONSUMES, never what it produces.
if ($HeadBranch) {
    Write-Output "merge-pr: tearing down worktree for $HeadBranch ..."
    $priorRepo = [Environment]::GetEnvironmentVariable('REPO')
    [Environment]::SetEnvironmentVariable('REPO', $Main)
    try {
        & (Join-Path $Here 'remove-worktree.ps1') $HeadBranch
        if ($LASTEXITCODE -ne 0) { Exit-WithError "remove-worktree.ps1 failed (exit $LASTEXITCODE)" }
    } finally {
        [Environment]::SetEnvironmentVariable('REPO', $priorRepo)
    }
}

# --- 2. Merge (unless already merged) ------------------------------------------
if ($State -eq 'MERGED') {
    Write-Output "merge-pr: PR #$Pr already merged - skipping merge, finishing the local sync."
} else {
    # draft -> ready is the orchestrator's review approval - the one thing in the
    # flow that says a human-in-the-loop read this diff, as opposed to a gate saying
    # the suite passed (the gate reports by PR comment and never touches this flag).
    # It sits here, one line above the merge, so `ready` can never be a stale badge:
    # the step-1 teardown above kills processes rooted in the worktree and can take
    # real time, and a flip before it would leave a window where the PR reads as
    # approved but is not merged. Inside the not-yet-MERGED branch it is also
    # idempotent on re-run, and `gh pr ready` on an already-ready PR is a no-op, so
    # nothing needs to read `isDraft` first.
    Write-Output "merge-pr: marking PR #$Pr ready (review approval) ..."
    Invoke-InMainCheckout {
        & gh pr ready $Pr
        if ($LASTEXITCODE -ne 0) { Exit-WithError "gh pr ready failed (exit $LASTEXITCODE)" }
        Write-Output "merge-pr: merging PR #$Pr (real merge commit, deleting branch) ..."
        & gh pr merge $Pr --merge --delete-branch
        if ($LASTEXITCODE -ne 0) { Exit-WithError "gh pr merge failed (exit $LASTEXITCODE)" }
    }
}

# --- 3. Sync the local integration branch in the MAIN checkout ------------------
# Anchored to MAIN so it works regardless of the caller's cwd. Fast-forward only:
# the main checkout never carries direct commits (all work lands via PR merge on
# the remote), so a non-ff pull means an anomaly that should stop us loudly.
$Current = Get-GitOutput @('-C', $Main, 'rev-parse', '--abbrev-ref', 'HEAD')
if ($Current -ne $Integration) {
    Write-Output "merge-pr: main checkout is on '$Current'; switching to '$Integration' ..."
    & git -C $Main checkout $Integration
    if ($LASTEXITCODE -ne 0) { Exit-WithError "could not check out '$Integration' in $Main" }
}

# `gh pr merge` returns before GitHub is guaranteed to serve the new tip, so a pull
# fired immediately can fast-forward to nothing ("Already up to date") and silently
# leave the branch on the PRE-merge commit - while a `rev-parse HEAD` in the done
# message still prints a sha and reads as "synced." That is the "said synced,
# wasn't" bug. So: poll-fetch until the remote actually carries the merge commit,
# fast-forward each round, and VERIFY the local branch truly reached the merged tip.
# The message is never proof; the ref-equality check below is - and on failure we
# die loudly, never lie.
# The merge just performed above is not reflected in the $MergeOid read before it,
# so re-read it here - and only here, where it is finally knowable.
if (-not $MergeOid) {
    $MergeOid = Invoke-InMainCheckout {
        $oid = (& gh pr view $Pr --json mergeCommit -q '.mergeCommit.oid' 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { return '' }
        return $oid
    }
}

Write-Output "merge-pr: syncing local '$Integration' to the merged tip ..."
$synced = $false
foreach ($attempt in 1..6) {
    Test-GitSuccess @('-C', $Main, 'fetch', '--prune', 'origin') | Out-Null
    Test-GitSuccess @('-C', $Main, 'merge', '--ff-only', "origin/$Integration") | Out-Null
    $local = Get-GitOutput @('-C', $Main, 'rev-parse', $Integration)
    $remote = Get-GitOutput @('-C', $Main, 'rev-parse', "origin/$Integration")
    $carriesMerge = $true
    if ($MergeOid) {
        $carriesMerge = Test-GitSuccess @('-C', $Main, 'merge-base', '--is-ancestor', $MergeOid, $Integration)
    }
    if ($local -eq $remote -and $carriesMerge) {
        $synced = $true
        break
    }
    Write-Output "merge-pr: remote not serving the merge yet (attempt $attempt/6) - waiting ..."
    Start-Sleep -Seconds 2
}
if (-not $synced) {
    $oid = $MergeOid
    if (-not $oid) { $oid = 'unknown' }
    Exit-WithError "local '$Integration' did NOT reach the merged tip (merge commit $oid still absent after retries) - SYNC FAILED; do NOT cut new worktrees off '$Integration' until this is resolved."
}

$short = Get-GitOutput @('-C', $Main, 'rev-parse', '--short', $Integration)
Write-Output "merge-pr: done - PR #$Pr merged, worktree removed, local '$Integration' synced to $short."
