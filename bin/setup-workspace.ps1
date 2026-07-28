#!/usr/bin/env pwsh
# Cut one task's worktrees across a POLYREPO workspace.
#
#   setup-workspace.ps1 [--dry-run] <branch> [repo ...]
#   setup-workspace.ps1 [--dry-run] <branch> --exclude <repo,repo>
#
# The PowerShell sibling of setup-workspace.sh, for a native Windows session with
# no bash at all: no WSL and no Git for Windows, where Claude Code hands the agent
# the PowerShell tool and the .sh helper is not runnable. Same arguments, the same
# WORKTREE_HOME / WORKSPACE environment variables, the same "READY: <path>" line on
# stdout, and the same exit codes, because the pair is ONE CLI contract implemented
# twice; scripts/check.sh compares the usage lines and the consumed env-var sets on
# every run so the two cannot drift apart.
#
# ASCII only, no exceptions - see the note in setup-worktree.ps1 for why.
#
# A workspace is a containing folder of sibling repos - not itself a repo - marked
# by `.agents/workspace.json` at its root. Run this from anywhere inside the
# workspace (the root, or any member repo).
#
# It creates one worktree per named repo, laid out the same way the workspace is:
#
#   $WORKTREE_HOME/<workspace>/<branch-leaf>/<repo>/
#
# (WORKTREE_HOME defaults to %LOCALAPPDATA%\wt on Windows, ~/.worktrees elsewhere.)
#
# Mirroring the layout is the point. A cross-repo task gets a single directory that
# looks exactly like the workspace, so relative paths between repos still resolve
# and both stacks can run side by side - which is what a feature spanning an API
# and its client actually needs.
#
# <branch>  the branch to create in EVERY named repo. One name across all of them,
#           so the PRs are obviously one change.
# [repo]    which members to cut. Name them explicitly when you know the task's
#           surface; each repo you skip is one install you don't pay for.
# --exclude the inverse: everything in the default set except these. Better when a
#           task touches most of the workspace and you want to drop one.
#
# With neither, you get the workspace's DEFAULT set: every member except those the
# manifest marks `"default": false`. That is for the member a workspace rarely
# touches together with the others - a marketing site alongside an app - so the
# common case stays cheap without anyone having to remember a flag.
#
# Each repo is provisioned by setup-worktree.ps1, so it gets that repo's own
# .agents/worktree.json treatment: env symlinks, exported env, install.
#
# The manifest is read with the built-in ConvertFrom-Json. The bash sibling has to
# shell out to python3 for the same three fields, because bash has no JSON parser -
# so on this side there is no interpreter to be missing and no second parse path to
# keep in step with the first.

# The analogue of `set -e`. Cmdlet failures only: Windows PowerShell 5.1 does not
# fold a native command's exit code into $ErrorActionPreference, so every git call
# below checks $LASTEXITCODE explicitly.
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
    Write-Stderr "setup-workspace: error: $Message"
    exit $Code
}

function Get-NormalPath {
    # Git prints Windows paths with forward slashes while Join-Path produces
    # backslashes; the two never compare equal as strings.
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

function Get-JsonValue {
    # Reads a property that may be absent from a ConvertFrom-Json object, which
    # carries only the keys the file actually had. A plain $manifest.missing is $null
    # by default but THROWS under Set-StrictMode 2.0 - which a user's PowerShell
    # profile can switch on globally, so this script cannot assume it is off.
    param($Object, [Parameter(Mandatory = $true)] [string] $Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-ArgTail {
    # The `shift` of this port. PowerShell's range operator counts DOWN when its end
    # is below its start, so $a[1..($a.Count - 1)] on a ONE-element array quietly
    # returns that element back instead of an empty tail - and the branch name would
    # then be re-read as a repo name, cutting a worktree for a member nobody asked
    # for. Guard the empty case explicitly rather than trusting the range.
    param([object[]] $Items, [int] $Skip)
    if ($null -eq $Items -or $Items.Count -le $Skip) { return @() }
    return @($Items[$Skip..($Items.Count - 1)])
}

$rest = @($args)

$DryRun = $false
if ($rest.Count -ge 1 -and $rest[0] -eq '--dry-run') {
    $DryRun = $true
    $rest = Get-ArgTail -Items $rest -Skip 1
}

if ($rest.Count -lt 1) {
    Exit-WithError "usage: setup-workspace.ps1 [--dry-run] <branch> [repo ...]"
}
$Branch = [string]$rest[0]
$rest = Get-ArgTail -Items $rest -Skip 1
$Slug = $Branch.Substring($Branch.LastIndexOf('/') + 1)

$WorktreeHome = Get-NormalPath (Get-WorktreeHome)

# Find the workspace root by walking up for the manifest. Starting from a member
# repo is the common case - you are usually already inside one. The loop stops when
# the parent stops changing rather than when it equals "/": on Windows a walk up
# from C:/Users/... bottoms out at C:/, whose parent is C:/ again, so a "/" test
# would spin forever.
$dir = $env:WORKSPACE
if (-not $dir) { $dir = (Get-Location).Path }
$dir = Get-NormalPath $dir
while (-not (Test-Path -LiteralPath "$dir/.agents/workspace.json")) {
    $parent = Get-NormalPath (Split-Path -Path $dir -Parent)
    if (-not $parent -or $parent -eq $dir) { break }
    $dir = $parent
}
if (-not (Test-Path -LiteralPath "$dir/.agents/workspace.json")) {
    Exit-WithError "no .agents/workspace.json above $((Get-Location).Path) - not inside a workspace"
}
$Root = $dir
$WorkspaceName = Split-Path -Path $Root -Leaf
$ManifestPath = "$Root/.agents/workspace.json"

try {
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
} catch {
    Exit-WithError "could not parse $ManifestPath as JSON: $($_.Exception.Message)"
}

$Base = [string](Get-JsonValue -Object $manifest -Name 'integrationBranch')
if (-not $Base) { Exit-WithError "$ManifestPath declares no integrationBranch" }

# A member is either a bare name or an object with `path` and an optional
# `"default": false`.
$All = @()
$Defaults = @()
foreach ($member in @(Get-JsonValue -Object $manifest -Name 'members')) {
    if ($null -eq $member) { continue }
    if ($member -is [string]) {
        $All += $member
        $Defaults += $member
        continue
    }
    $path = [string]$member.path
    if (-not $path) { continue }
    $All += $path
    $onByDefault = $true
    $declaredDefault = Get-JsonValue -Object $member -Name 'default'
    if ($null -ne $declaredDefault) { $onByDefault = [bool]$declaredDefault }
    if ($onByDefault) { $Defaults += $path }
}

$Exclude = @()
if ($rest.Count -ge 1 -and $rest[0] -eq '--exclude') {
    if ($rest.Count -lt 2) { Exit-WithError "--exclude needs a comma-separated list" }
    $Exclude = @([string]$rest[1] -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $rest = Get-ArgTail -Items $rest -Skip 2
}

if ($rest.Count -gt 0) {
    $Repos = @($rest | ForEach-Object { [string]$_ })
} else {
    $Repos = @($Defaults)
}

# Reject an unknown name rather than silently cutting a smaller task than asked
# for - a typo'd repo is the kind of thing you only notice three PRs later.
foreach ($name in ($Repos + $Exclude)) {
    if ($All -notcontains $name) {
        Exit-WithError "'$name' is not a member of $WorkspaceName (members: $($All -join ' '))"
    }
}

if ($Exclude.Count -gt 0) {
    $Repos = @($Repos | Where-Object { $Exclude -notcontains $_ })
    Write-Output "excluding:  $($Exclude -join ' ')"
}
if ($Repos.Count -eq 0) { Exit-WithError "every member was excluded - nothing to do" }

# Contract closure. A repo that OWNS a cross-repo contract cannot be changed alone:
# its consumers hold generated copies of what it produces, so a task that touches
# the owner without them can neither update nor verify the other side, and the
# drift only surfaces after both have merged. Pull the consumers in.
foreach ($contract in @(Get-JsonValue -Object $manifest -Name 'crossRepoContracts')) {
    if ($null -eq $contract) { continue }
    $owner = [string](Get-JsonValue -Object $contract -Name 'owner')
    if (-not $owner) { continue }
    if ($Repos -notcontains $owner) { continue }
    foreach ($consumer in @(Get-JsonValue -Object $contract -Name 'consumers')) {
        $consumer = [string]$consumer
        if (-not $consumer -or $Repos -contains $consumer) { continue }
        if ($Exclude -contains $consumer) {
            Exit-WithError "'$consumer' consumes a contract owned by '$owner', which this task includes - it cannot be excluded.`n  Either drop '$owner' from the task, or keep '$consumer' in it."
        }
        $Repos += $consumer
        Write-Output "including:  $consumer (consumes a contract owned by $owner)"
    }
}

Write-Output "workspace: $WorkspaceName ($Root)"
Write-Output "branch:    $Branch  off  $Base"
Write-Output "repos:     $($Repos -join ' ')"
Write-Output ""

$TaskDir = "$WorktreeHome/$WorkspaceName/$Slug"

if ($DryRun) {
    Write-Output "would create: $TaskDir/{$($Repos -join ',')}"
    exit 0
}

if (-not (Test-Path -LiteralPath $TaskDir)) {
    New-Item -ItemType Directory -Path $TaskDir -Force | Out-Null
}

foreach ($repo in $Repos) {
    $src = "$Root/$repo"
    if (-not (Test-Path -LiteralPath $src)) { Exit-WithError "member '$repo' not found at $src" }
    if (-not (Test-GitSuccess @('-C', $src, 'rev-parse', '--git-dir'))) {
        Exit-WithError "member '$repo' is not a git repo"
    }
    # Verify the base exists here before creating anything: in a polyrepo the
    # integration branch is a convention, and one repo lagging behind is exactly
    # the case that would otherwise leave a half-built task directory.
    if (-not (Test-GitSuccess @('-C', $src, 'rev-parse', '--verify', '--quiet', $Base))) {
        Exit-WithError "member '$repo' has no local '$Base' - run: git -C `"$src`" fetch origin"
    }
}

# WORKTREE_DEST and REPO are handed to the child through the environment rather
# than a `$env:` assignment expression, so the parity check's env-var scan sees only
# the variables this script CONSUMES and never the two it produces for its child.
$priorDest = [Environment]::GetEnvironmentVariable('WORKTREE_DEST')
$priorRepo = [Environment]::GetEnvironmentVariable('REPO')
try {
    foreach ($repo in $Repos) {
        Write-Output "--- $repo ---"
        [Environment]::SetEnvironmentVariable('WORKTREE_DEST', "$TaskDir/$repo")
        [Environment]::SetEnvironmentVariable('REPO', "$Root/$repo")
        & (Join-Path $Here 'setup-worktree.ps1') $Branch $Base
        if ($LASTEXITCODE -ne 0) { Exit-WithError "setup-worktree.ps1 failed for '$repo' (exit $LASTEXITCODE)" }
    }
} finally {
    [Environment]::SetEnvironmentVariable('WORKTREE_DEST', $priorDest)
    [Environment]::SetEnvironmentVariable('REPO', $priorRepo)
}

Write-Output ""
Write-Output "READY: $TaskDir"
Write-Output "  $((Get-ChildItem -LiteralPath $TaskDir | ForEach-Object { $_.Name }) -join ' ')"
Write-Output ""
Write-Output "Verify each HEAD before dispatching an agent - the helper does not:"
foreach ($repo in $Repos) {
    Write-Output "  git -C $TaskDir/$repo rev-parse HEAD   # must equal origin/$Base in $repo"
}
