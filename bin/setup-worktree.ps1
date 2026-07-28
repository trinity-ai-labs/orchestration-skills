#!/usr/bin/env pwsh
# Create an isolated git worktree for a task, in a central per-project home.
#
#   setup-worktree.ps1 <branch> <base>
#
# The PowerShell sibling of setup-worktree.sh, for a native Windows session with
# no bash at all: no WSL and no Git for Windows, where Claude Code hands the agent
# the PowerShell tool instead of the Bash tool and the .sh helpers are simply not
# runnable. Everything a caller can observe is identical on both sides: the two
# positional arguments, the WORKTREE_HOME / REPO / WORKTREE_DEST environment
# variables, the "READY: <path>" line on stdout, and the exit codes. The pair is
# ONE CLI contract implemented twice, and scripts/check.sh compares the two usage
# lines and the two consumed env-var sets on every run so the copies cannot drift
# apart quietly - prose alone never stopped two hand-maintained copies of the same
# logic from diverging, it only made the divergence someone's fault afterwards.
#
# ASCII only, no exceptions. Windows PowerShell 5.1 decodes a file that carries no
# byte-order mark using the system ANSI codepage, so a single non-ASCII byte
# anywhere (an em-dash in a comment being by far the likeliest) is read as mojibake
# and surfaces as a parse error nowhere near the character that actually caused it,
# which makes it expensive to trace back. Shipping a BOM to dodge that is worse
# than staying ASCII, so every byte in this file sits inside 0x20-0x7E.
#
# What it does, driven by the project's own config at <repo>/.agents/worktree.json:
#   - creates the worktree at  $WORKTREE_HOME/<project>/<branch-leaf>
#     (WORKTREE_HOME defaults to %LOCALAPPDATA%\wt on Windows and ~/.worktrees
#     elsewhere - the worktrees themselves stay out of the repo, since a worktree
#     nested inside its own repo confuses git, and the Windows default is shorter
#     because a nested node_modules path under ~/.worktrees blows past MAX_PATH)
#   - symlinks the project's gitignored env files (envFiles)
#   - exports the project's env (env) - e.g. a shared build-cache dir
#   - runs the project's install command (install) inside the worktree
#
# <branch>  full name of the new branch, e.g. feat/toasts-top-right (any prefix:
#           feat/ fix/ refactor/ chore/ docs/ ...). The worktree dir is named after
#           the segment past the last slash.
# <base>    branch to fork from. REQUIRED, no default - integration branches roll
#           over often, so a hardcoded default just goes stale.
#
# Every branch gets the same treatment - env symlinks and a real install - so a
# worktree is always self-contained and can face any check the project has.
#
# JSON is parsed with the built-in ConvertFrom-Json. That is a real advantage this
# side has over the bash sibling: bash has no JSON parser, so setup-worktree.sh has
# to shell out to python3 with a node fallback and fails outright on a machine that
# has neither. This path needs nothing beyond PowerShell itself.

# The analogue of `set -e`. It only covers CMDLET failures: Windows PowerShell 5.1
# does not fold a native command's exit code into $ErrorActionPreference, so every
# git / gh call below checks $LASTEXITCODE explicitly. Without that check a failed
# git call falls through on empty output and the script keeps going against a path
# it never resolved.
$ErrorActionPreference = 'Stop'

function Write-Stderr {
    # `echo ... >&2`. Write-Error would work but wraps the message in a formatted
    # error record with a call-site preamble, which is noise in a CLI helper whose
    # stderr a human reads directly.
    param([Parameter(Mandatory = $true)] [string] $Message)
    [Console]::Error.WriteLine($Message)
}

function Exit-WithError {
    param(
        [Parameter(Mandatory = $true)] [string] $Message,
        [int] $Code = 1
    )
    Write-Stderr $Message
    exit $Code
}

function Get-NormalPath {
    # Git prints Windows paths with forward slashes (C:/Users/...) while Join-Path
    # and $HOME produce backslashes (C:\Users\...). Both forms work for filesystem
    # operations; neither works for STRING comparison against the other, and every
    # failure from mixing them is silent rather than loud - the already-exists guard
    # below simply stops matching and starts failing OPEN. So every value that is
    # later compared or prefix-matched is normalised at the point it is produced.
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

function Get-GitOutput {
    # Runs git, fails loudly on a non-zero exit, and returns stdout as one string.
    param([Parameter(Mandatory = $true)] [string[]] $GitArgs)
    $out = & git @GitArgs
    if ($LASTEXITCODE -ne 0) {
        Exit-WithError ("git " + ($GitArgs -join ' ') + " failed (exit $LASTEXITCODE)")
    }
    return (($out | Out-String).Trim())
}

function Test-GitSuccess {
    # The probe form: swallows all output and reports only whether git exited 0.
    param([Parameter(Mandatory = $true)] [string[]] $GitArgs)
    & git @GitArgs *> $null
    return ($LASTEXITCODE -eq 0)
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

function Get-JsonValue {
    # Reads a property that may be absent from a ConvertFrom-Json object, which
    # carries only the keys the file actually had. A plain $cfg.missing is $null by
    # default but THROWS under Set-StrictMode 2.0 - which a user's PowerShell profile
    # can switch on globally, so this script cannot assume it is off.
    param($Object, [Parameter(Mandatory = $true)] [string] $Name)
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Expand-ShellValue {
    # The config's `env` values are authored for the bash sibling, which emits them
    # UNQUOTED and lets the shell expand them: `${TURBO_CACHE_DIR:-$HOME/.cache/x}`
    # is exactly how a project declares a cache dir that an already-set variable
    # wins over. PowerShell performs no such expansion, so without this the value
    # would be exported verbatim and every worktree's build cache would point at a
    # directory literally named "${TURBO_CACHE_DIR:-...}" - wrong, and silent,
    # because a cache that never hits looks the same as a cold one.
    param([string] $Value)
    if (-not $Value) { return '' }

    $lookup = {
        param([string] $Name)
        $v = [Environment]::GetEnvironmentVariable($Name)
        if (-not $v -and $Name -eq 'HOME') { $v = $HOME }
        if ($null -eq $v) { $v = '' }
        return $v
    }

    # ${NAME:-fallback} first, so a fallback that itself references $HOME still gets
    # expanded by the two passes below.
    $expanded = [regex]::Replace($Value, '\$\{([A-Za-z_][A-Za-z0-9_]*):-([^}]*)\}', {
            param($m)
            $set = & $lookup $m.Groups[1].Value
            if ($set) { return $set }
            return $m.Groups[2].Value
        })
    $expanded = [regex]::Replace($expanded, '\$\{([A-Za-z_][A-Za-z0-9_]*)\}', {
            param($m) & $lookup $m.Groups[1].Value
        })
    $expanded = [regex]::Replace($expanded, '\$([A-Za-z_][A-Za-z0-9_]*)', {
            param($m) & $lookup $m.Groups[1].Value
        })
    return $expanded
}

function Invoke-ProjectInstall {
    # The install command is a command LINE declared by the project's own config,
    # so it has to be interpreted rather than spawned as an argv - `pnpm install
    # --frozen-lockfile` and anything with a pipe in it both have to work. The bash
    # sibling evals it for the same reason and at the same trust level: by the time
    # you are cutting a worktree you already run this repo's install and test
    # commands.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '',
        Justification = 'The config''s install value is a project-declared command line; interpreting it is the feature, and the bash sibling evals the same string.')]
    param(
        [Parameter(Mandatory = $true)] [string] $Command,
        [Parameter(Mandatory = $true)] [string] $WorkingDirectory
    )
    # corepack-shimmed package managers (e.g. pnpm) provision the pinned version on
    # first use and, by default, block on a [Y/n] download prompt - which has nowhere
    # to go in this non-interactive install and hangs or fails the cold-cache run.
    # Auto-accept so the first worktree setup warms the cache instead of stalling.
    # Harmless when the install command does not go through corepack. Set through
    # the .NET API rather than `$env:` assignment so the parity check's env-var scan
    # sees only variables this script CONSUMES, never ones it produces.
    [Environment]::SetEnvironmentVariable('COREPACK_ENABLE_DOWNLOAD_PROMPT', '0')
    Push-Location -LiteralPath $WorkingDirectory
    try {
        Invoke-Expression $Command
        if ($LASTEXITCODE -ne 0) {
            Exit-WithError "install command failed (exit $LASTEXITCODE): $Command"
        }
    } finally {
        Pop-Location
    }
}

if ($args.Count -lt 2) {
    Write-Stderr "usage: setup-worktree.ps1 <branch> <base>"
    Write-Stderr "  e.g. setup-worktree.ps1 feat/toasts-top-right release/0.3.4"
    Write-Stderr "  run from inside the target repo, or set REPO=/path/to/repo"
    exit 1
}

$Branch = [string]$args[0]
$Base = [string]$args[1]

$WorktreeHome = Get-NormalPath (Get-WorktreeHome)

$Repo = $env:REPO
if (-not $Repo) { $Repo = (Get-Location).Path }

$ConfigRel = '.agents/worktree.json'

$Main = Get-RepoRoot -Path $Repo
if (-not $Main) {
    Write-Stderr "not inside a git repo: $Repo"
    Exit-WithError "  run from inside the target repo, or set REPO=/path/to/repo"
}
$Project = Split-Path -Path $Main -Leaf
$Slug = $Branch.Substring($Branch.LastIndexOf('/') + 1)

# A repo inside a workspace (a containing folder of sibling repos, marked by
# .agents/workspace.json) gets its worktrees under the WORKSPACE's namespace, not
# its own. Bare repo names in a polyrepo are things like `api` and `client` -
# generic enough that two unrelated projects collide in a flat ~/.worktrees.
# setup-workspace.ps1 sets WORKTREE_DEST directly when it cuts a whole task.
$WorkspaceRoot = Get-NormalPath (Split-Path -Path $Main -Parent)
if ($env:WORKTREE_DEST) {
    $Wt = Get-NormalPath $env:WORKTREE_DEST
} elseif (Test-Path -LiteralPath (Join-Path $WorkspaceRoot '.agents/workspace.json')) {
    $Wt = "$WorktreeHome/$(Split-Path -Path $WorkspaceRoot -Leaf)/$Slug/$Project"
} else {
    $Wt = "$WorktreeHome/$Project/$Slug"
}

# Per-project config (optional).
$EnvFiles = @()
$InstallCmd = ''
$Config = "$Main/$ConfigRel"
if (Test-Path -LiteralPath $Config) {
    try {
        $cfg = Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
    } catch {
        Exit-WithError "could not parse $Config as JSON: $($_.Exception.Message)"
    }
    $install = Get-JsonValue -Object $cfg -Name 'install'
    if ($install) { $InstallCmd = [string]$install }

    $files = Get-JsonValue -Object $cfg -Name 'envFiles'
    if ($files) { $EnvFiles = @($files) }

    $declaredEnv = Get-JsonValue -Object $cfg -Name 'env'
    if ($declaredEnv) {
        foreach ($prop in $declaredEnv.PSObject.Properties) {
            [Environment]::SetEnvironmentVariable($prop.Name, (Expand-ShellValue ([string]$prop.Value)))
        }
    }
} else {
    Write-Stderr "note: no config at $Config - creating a bare worktree (no env symlinks, no install)."
    Write-Stderr "  add $ConfigRel to '$Project' to declare envFiles / install."
}

# Fail early with a fetch hint if base isn't a known local ref (a freshly-cut
# integration branch won't exist locally until you fetch it).
if (-not (Test-GitSuccess @('-C', $Main, 'rev-parse', '--verify', '--quiet', $Base))) {
    Write-Stderr "base branch not found locally: $Base"
    Exit-WithError "  try: git -C `"$Main`" fetch origin   (or pass origin/$Base)"
}

$WtParent = Split-Path -Path $Wt -Parent
if (-not (Test-Path -LiteralPath $WtParent)) {
    New-Item -ItemType Directory -Path $WtParent -Force | Out-Null
}

# --porcelain rather than the human listing the bash sibling greps: it emits one
# bare `worktree <path>` line per entry, so the comparison is against a whole
# normalised path instead of a substring of a padded table row. A substring match
# fails OPEN when the two sides disagree on slash direction, and a failed-open
# idempotency guard turns a harmless re-run into `git worktree add`'s "already
# exists" error instead of the intended no-op.
$known = @()
foreach ($line in (Get-GitOutput @('-C', $Main, 'worktree', 'list', '--porcelain')) -split "`n") {
    if ($line -match '^worktree\s+(.*)$') { $known += (Get-NormalPath $Matches[1].Trim()) }
}
if ($known -contains $Wt) {
    Write-Output "worktree already exists: $Wt"
} else {
    & git -C $Main worktree add -b $Branch $Wt $Base
    if ($LASTEXITCODE -ne 0) { Exit-WithError "git worktree add failed (exit $LASTEXITCODE)" }
}

# Symlink the project's gitignored env files (tests/build read these).
foreach ($rel in $EnvFiles) {
    $src = "$Main/$rel"
    if (-not (Test-Path -LiteralPath $src)) { continue }
    $dest = "$Wt/$rel"
    $destDir = Split-Path -Path $dest -Parent
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    try {
        New-Item -ItemType SymbolicLink -Path $dest -Target $src -Force | Out-Null
    } catch {
        # Creating a symlink on Windows needs Developer Mode or an elevated shell;
        # without either it fails outright. Copy so the worktree is at least usable,
        # but say so loudly: a copy is a SNAPSHOT, so a later edit to the main
        # checkout's env file never reaches this worktree, and the stale value shows
        # up as a test failure that looks like a code bug.
        Copy-Item -LiteralPath $src -Destination $dest -Force
        Write-Stderr "note: could not symlink $rel (needs Developer Mode or an elevated shell); COPIED instead."
        Write-Stderr "  later edits to $src will NOT reach this worktree."
    }
}

# Materialize node_modules / deps (worktrees don't share them; the gate needs them).
if ($InstallCmd) {
    Invoke-ProjectInstall -Command $InstallCmd -WorkingDirectory $Wt
}

Write-Output "READY: $Wt (branch $Branch off $Base)"
