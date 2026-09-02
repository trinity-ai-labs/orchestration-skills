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
# compares the usage lines and the consumed env-var sets on every run. Everything
# it compares is SURFACE SHAPE, and semantics are out of its reach: both ports can
# pass every check it makes and still behave differently on the same input. What
# holds the pair together is the frozen contract in AGENTS.md and the review of
# every change to it; the check catches the drift that shows on the surface.
#
# ASCII only, no exceptions - see the note in setup-worktree.ps1 for why.
#
# Run it from ANYWHERE inside the target repo (or set REPO=). It performs the whole
# "Merge & cleanup" sequence as ONE command, in the one correct order, so no
# load-bearing step can be dropped:
#
#   1. Resolve the MAIN checkout + the PR's base (integration) and head branch,
#      and decide which merge MODE this one boundary gets (see below).
#   2. Preflight the PR's mergeability, BEFORE anything irreversible happens - the
#      two steps that follow cannot be undone by a later failure, and the step
#      that actually fails is the last one. A conflicting PR stops here with the
#      worktree intact and the PR still a draft.
#   3. Remove the head branch's worktree - git refuses to delete a branch that's
#      still checked out in a worktree, so `gh pr merge --delete-branch` would
#      error on the local-branch step if the worktree still existed. Done via
#      remove-worktree.ps1, which kills processes rooted in the tree first.
#   4. Mark the PR ready - the dispatcher's review approval - and immediately
#      `gh pr merge` it, deleting both the local and remote branch. A merge that
#      fails anyway puts the draft flag back before it exits.
#   5. Sync the local copy of the PR's base branch to the just-merged tip - in the
#      main checkout, in whatever linked worktree is standing on it, or by ref.
#   6. On the squash path ONLY: verify the merged tree against the epic tip that
#      was gated, and delete the branch once it matches.
#   7. Verify the main checkout is still standing where it was when the run began.
#
# The merge mode. Every merge here is a real merge commit, with exactly ONE
# exception a project may opt into: the epic buffer branch collapsing back into
# the integration branch it was cut from. That branch is scaffolding - it exists
# for one arc and is deleted at its end - so on a long-lived release branch a
# project may prefer one commit per arc to N slice merges plus a merge commit.
# It is declared up front in <repo>/.agents/worktree.json, never decided here:
#
#   { "epicMerge": "merge" }   // "merge" (the default) | "squash"
#
# Absent, unreadable, or anything but the exact string "squash" means "merge", so
# a typo cannot silently squash and no existing project changes behaviour. There
# is deliberately no argument, no environment variable and no flag for this: the
# helper CLI contract is frozen (AGENTS.md), and a per-merge switch is exactly the
# close-out-time history decision the config exists to prevent.
#
# Even under "squash" the boundary is one merge and one only, and TWO conditions
# have to hold for it. A slice -> epic merge stays a real merge commit with no
# opt-out (those merge commits are the epic's review record, and the integration
# gate's `^2` check reads their second parent), and single-slice work cuts no epic
# branch, so it has no buffer to collapse. What separates them is a RELATIONSHIP,
# never a branch name - no prefix is ever the key for anything in this flow - and
# the relationship IS the definition of an epic branch: it is the branch an epic's
# slices PR'd into. `gh pr list --base <head> --state merged` answers exactly that,
# and a slice branch and a single-slice branch both answer zero.
#
# That question alone would reach one merge it must never reach, because an
# INTEGRATION branch answers it too - it is the branch every slice of every arc
# PR'd into, so a long-lived `release/x.y.z` counts in the dozens. Under "squash"
# a `release/0.4.0 -> dev` close-out would therefore collapse the entire release
# branch, irreversibly, with the tree comparison passing and every signal reading
# clean. So the squash additionally requires that the PR's BASE is not the
# repository's default branch, which is the standing constraint - the squashes are
# for epic buffers merging into integration/release branches, not into `main` or
# `dev` - expressed as something the helper can check rather than as advice
# someone has to remember.
#
# That narrowing is deliberate and it has one consequence worth stating, because
# the next reader will otherwise read it as a bug: in a project whose INTEGRATION
# branch simply IS the default branch, the genuine `epic -> main` boundary is
# skipped too, and `"epicMerge": "squash"` correctly does nothing there. Such a
# project was already told to leave the setting at its default; this makes that
# automatic instead of a thing anyone has to remember, and it is the only reading
# under which the constraint can be enforced rather than advised - nothing
# distinguishes an integration branch merging into `main` from an epic branch
# merging into `main` except a prefix, and no prefix is ever the key here.
#
# Every way either question can fail to produce a usable answer - a network error,
# an empty response, a gh failure, a count of zero, a default branch that could not
# be determined - falls back to a real merge commit. A missed squash is cosmetic; a
# wrong squash is unrecoverable history.
#
# Before any of that it REFUSES to run when the copy being executed, or the directory
# it is being run from, sits inside the worktree step 3 tears down: that teardown
# kills every process rooted in the tree, and this process would be one of them. The
# guard below says why it refuses rather than re-execing from somewhere safe.
#
# Step 5 is the whole reason this helper exists. `gh pr merge` advances the branch
# on the REMOTE; the local base branch in the main checkout does NOT move. Syncing
# it is a manual step with NO forcing feedback - every visible signal (Merged,
# branch deleted, PR closed) says "done", so it is the step that gets silently
# skipped, and the miss only surfaces later when the NEXT worktree is cut from a
# stale HEAD. This helper anchors every git call to the MAIN checkout with
# `git -C $Main`, independent of cwd, and only ever moves the branch FORWARD (the
# main checkout never carries direct commits, so a non-ff means something is wrong
# and should surface loudly, not merge-commit past).
#
# The main checkout is the one piece of global mutable state in a flow that is
# otherwise isolated per worktree, and several sessions share it - so step 5 never
# switches it. A base branch that is not the checked-out one is advanced where it
# already lives: inside the linked worktree standing on it, or as a bare REF
# (`fetch` + `branch -f`) when none is. Step 7 then confirms nothing else moved the
# checkout meanwhile.
#
# Idempotent: if the PR is already merged, it skips the merge and still runs the
# worktree teardown + local sync, so a re-run finishes a half-done close-out.

# The analogue of `set -e`, and it covers CMDLET failures only. Whether a native
# command's non-zero exit ALSO raises a terminating error is a separate switch, so
# this script sets both rather than inheriting either. Windows PowerShell 5.1 has
# no such switch; 7.4 added one, off by default today, and a caller's session or
# profile can turn it on - a preference variable is inherited by every script the
# session runs. These helpers spend non-zero exits as questions rather than as
# failures, so with it on a probing git / gh call throws before the $LASTEXITCODE
# check below ever reads it. Pinning it off is also what keeps this comment true:
# one that asserts today's default as a guarantee goes stale silently when the
# default moves, with nothing at the code it describes to show that it has.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$Here = $PSScriptRoot
$ConfigRel = '.agents/worktree.json'

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
    # exactly as remove-worktree.ps1 anchors its kill scan, so ".../1322-foo" cannot
    # match ".../1322-foo-retry" - this decides a REFUSAL, and an over-eager match
    # here would block a legitimate close-out rather than merely fail to prevent a
    # bad one. Case-insensitive, because Windows paths are.
    param(
        [Parameter(Mandatory = $true)] [string] $Candidate,
        [Parameter(Mandatory = $true)] [string] $Tree
    )
    if (-not $Candidate -or -not $Tree) { return $false }
    if ($Candidate.Equals($Tree, [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $Candidate.StartsWith("$Tree/", [StringComparison]::OrdinalIgnoreCase)
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

function Get-ConfigScalar {
    # One scalar out of the project's own config, or an empty string.
    #
    # Deliberately smaller than setup-worktree.ps1's config block: that one reads an
    # array and an env map and has to expand shell syntax in the values, while this
    # needs a single string compared against a literal. ConvertFrom-Json is built in,
    # so unlike the bash sibling there is no interpreter to probe for and no machine
    # on which this reader is simply unavailable.
    #
    # Where setup-worktree.ps1 EXITS on a config it cannot parse, this returns empty
    # and the caller falls back to a real merge commit. That asymmetry is the point
    # rather than leniency, and it comes from what the unreadable config costs each
    # side. There, it yields a worktree with no env symlinks and no install - a
    # broken tree wearing every appearance of a good one - so stopping is the only
    # honest answer. Here it yields precisely today's behaviour, which is what every
    # project that has never heard of this key already gets: the fallback IS the safe
    # state, so an unreadable config costs a cosmetic miss where refusing would break
    # the close-out of every PR over a key most projects never set.
    param(
        [Parameter(Mandatory = $true)] [string] $Path,
        [Parameter(Mandatory = $true)] [string] $Name
    )
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    try {
        $cfg = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    } catch {
        return ''
    }
    # The key is matched CASE-SENSITIVELY, which PowerShell does not do on its own:
    # a PSObject property lookup ignores case, so `"EpicMerge"` would be found here
    # and NOT by the bash sibling, whose node / python parse reads the exact key.
    # A pair that disagrees about the same config file is the drift the parity rule
    # exists to prevent, and this one fails in the destructive direction - the whole
    # promise of the key is that a misspelling cannot silently squash. Iterating the
    # properties is also what keeps this safe under Set-StrictMode 2.0, which turns
    # a plain read of an absent property into a throw.
    foreach ($prop in $cfg.PSObject.Properties) {
        if ($prop.Name -ceq $Name) {
            if ($prop.Value -is [string]) { return $prop.Value }
            return ''
        }
    }
    return ''
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
    # for a dispatcher is usually inside some other repo's worktree entirely, and
    # same-numbered PRs exist in every repo.
    # ArgumentList is how a caller hands a value INTO the block: a scriptblock
    # invoked from here resolves free variables through the scope chain, which
    # reaches script-level state like $Pr but makes a caller's own local an
    # invisible dependency. Passing it as a parameter states the binding instead.
    param(
        [Parameter(Mandatory = $true)] [scriptblock] $Body,
        [object[]] $ArgumentList = @()
    )
    Push-Location -LiteralPath $Main
    try { & $Body @ArgumentList } finally { Pop-Location }
}

function Get-GitRefOrEmpty {
    # The sha a ref resolves to, or an empty string when the ref does not exist -
    # where Get-GitOutput would exit. The sync loop reads refs that can legitimately
    # be absent for a round (the local base branch, before `branch -f` creates it),
    # and an absent ref there is a "not yet" to retry rather than a failure to die on.
    param([Parameter(Mandatory = $true)] [string] $Ref)
    $out = & git -C $Main rev-parse --verify --quiet $Ref 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    return (($out | Out-String).Trim())
}

function Get-WorktreeHoldingBranch {
    # The path of the worktree that has $Branch checked out, or an empty string if
    # no worktree does. `git branch -f` refuses to move a branch that is checked out
    # ANYWHERE, so step 4 has to know before it tries: a base standing in a linked
    # worktree is advanced from inside that tree instead. Answering empty is not a
    # failure - an epic branch whose worktree has been torn down is exactly that
    # case, and the sync falls back to moving the ref.
    param([Parameter(Mandatory = $true)] [string] $Branch)
    $out = & git -C $Main worktree list --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }
    $candidate = ''
    foreach ($line in (($out | Out-String) -split "`r?`n")) {
        if ($line.StartsWith('worktree ')) { $candidate = $line.Substring(9).Trim() }
        elseif ($line.Trim() -eq "branch refs/heads/$Branch") { return (Get-NormalPath $candidate) }
    }
    return ''
}

function Get-PrField {
    # A single field, for the two values that have to be read at a specific MOMENT
    # rather than with the batch below: `mergeable` because GitHub computes it
    # asynchronously and it is polled until it settles, and `isDraft` because it
    # must describe the instant before this run flips it.
    param([Parameter(Mandatory = $true)] [string] $Name)
    return Invoke-InMainCheckout -ArgumentList @($Name) -Body {
        param([string] $Field)
        $value = (& gh pr view $Pr --json $Field -q ".$Field" 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { return '' }
        return $value
    }
}

# One gh call for all the fields that can be read together rather than one call per
# field: each invocation is a process spawn plus an API round trip, and reading them
# separately also opens a window in which the PR could change between reads, leaving
# this run acting on a state that never existed all at once. ConvertFrom-Json is
# built in, so parsing the result costs nothing extra. `mergeable` rides along here
# so the preflight's FIRST answer is free; only an answer that has not settled yet
# costs a further call.
$prJson = Invoke-InMainCheckout {
    $raw = & gh pr view $Pr --json state,baseRefName,headRefName,headRefOid,mergeCommit,mergeable
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($raw | Out-String).Trim())
}
if (-not $prJson) {
    Exit-WithError "could not read PR #$Pr (is the number right? is gh authed?)"
}
# $PrView, not $pr: PowerShell variable names are case-INSENSITIVE, so a $pr here
# would BE $Pr, the PR number read from the arguments - silently replacing it with
# this object, after which every later `gh pr ready` / `gh pr merge` / message
# receives the object's ToString() in place of the number.
try {
    $PrView = $prJson | ConvertFrom-Json
} catch {
    Exit-WithError "gh returned something that is not JSON for PR #${Pr}: $($_.Exception.Message)"
}

$State = [string]$PrView.state
$Integration = [string]$PrView.baseRefName
$HeadBranch = [string]$PrView.headRefName
# Absent until the PR is actually merged; the sync loop below falls back to plain
# ref equality when it is empty.
$MergeOid = ''
if ($PrView.mergeCommit) { $MergeOid = [string]$PrView.mergeCommit.oid }
if (-not $Integration) { Exit-WithError "PR #$Pr has no base branch" }

Write-Output "merge-pr: PR #$Pr  state=$State  base=$Integration  head=$HeadBranch  main=$Main"

# Where the main checkout stands BEFORE this run touches anything. Step 6 checks it
# is still here at the end: nothing in this helper switches the checkout, so any
# movement came from another session, and step 4's verification cannot see it -
# that check proves the BASE reached the merged tip and has no opinion about a
# DIFFERENT branch having moved instead, which is the half that corrupts.
# `--abbrev-ref HEAD` prints the literal "HEAD" on a detached checkout, which
# compares as its own value and needs no special case.
$StartBranch = Get-GitOutput @('-C', $Main, 'rev-parse', '--abbrev-ref', 'HEAD')
$StartHead = Get-GitOutput @('-C', $Main, 'rev-parse', 'HEAD')

function Assert-CheckoutUnmoved {
    # Stop the run if the main checkout is no longer on the branch it started on.
    # Called before every advance in step 4 as well as over the finished run in step
    # 6, because the on-base decision that picks step 4's path is made once and then
    # used across a retry loop - and on that path `merge --ff-only` names no branch,
    # so it moves WHATEVER is checked out at the moment it runs. A switch landing in
    # between would fast-forward another session's branch toward this PR's base,
    # which is the corruption this helper exists to prevent rather than to relocate.
    $now = Get-GitOutput @('-C', $Main, 'rev-parse', '--abbrev-ref', 'HEAD')
    if ($now -ne $StartBranch) {
        Exit-WithError "the main checkout $Main was on '$StartBranch' when this run started and is on '$now' now - this helper never switches it, so another process moved it mid-run. PR #$Pr IS merged, but the local sync of '$Integration' may be incomplete: check where '$StartBranch' and '$now' point before cutting any worktree off either."
    }
}

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

# --- Self-teardown guard ---------------------------------------------------------
# Step 2 hands the head branch's worktree to remove-worktree.ps1, which kills every
# process rooted in that tree BEFORE removing it. This process is rooted there
# whenever merge-pr is running out of, or standing in, the very tree it is about to
# delete: by its script path, when the copy being executed is the one inside the
# worktree, and by its cwd, when the caller merely happens to be standing there.
# Both are fatal, in different ways per platform. Where the scan matches, the run is
# killed in the middle of the teardown and what it leaves is the worst shape a
# failure takes - the worktree gone, the PR NOT merged, and a transcript whose last
# lines are a teardown reporting success. Where it does not, Windows refuses to
# delete a directory a process is standing in or has a file open under, and the
# teardown fails on a locked file instead. The pair is ONE contract implemented
# twice, so the same command refuses in both shells rather than failing differently.
#
# Refusing rather than re-execing a copy from somewhere safe: WHICH copy that would
# be is a guess - the installed one may be a different version, or absent entirely
# on the machine of someone whose checkout IS this repo - and silently running code
# the caller did not name is a poor trade on the one helper whose whole job is to be
# the final step.
#
# Two forms of one answer, and they are not interchangeable. $HeadWt keeps the path
# exactly as git printed it, because that is what step 2 HANDS to
# remove-worktree.ps1 - git matches its registry against what it recorded, and a
# resolved spelling of the same directory is a different string. $DoomedWt is the
# resolved form, because the guards below decide whether two paths are the same tree
# by comparing them, and one directory has more than one spelling.
#
# Step 2 reuses this value rather than asking again, and that is a correctness
# requirement rather than thrift: the guards below refuse the run when THIS process
# is rooted in the tree about to be torn down, so a second Get-WorktreeHoldingBranch
# there could answer differently and the teardown would then be about a tree the
# guards never examined.
$HeadWt = Get-WorktreeHoldingBranch $HeadBranch
# A registration whose directory was deleted by hand still lists here. Handing that
# path over would send remove-worktree.ps1 down its absolute-path branch, where a
# missing directory it cannot resolve a repo from means it skips the prune that is
# the only thing left to do - so drop back to the branch name, which reaches it.
if ($HeadWt -and -not (Test-Path -LiteralPath $HeadWt)) { $HeadWt = '' }
$DoomedWt = ''
if ($HeadWt) { $DoomedWt = Get-RealPath $HeadWt }
# The MAIN checkout is never what step 2 removes - a head branch that happens to be
# checked out there is not a tree this run will delete, and refusing on it would
# block a close-out launched from the one directory that is always safe. Blanking
# $HeadWt with it is what keeps that true now that step 2 takes this path directly:
# the one path this run must never hand to a teardown is the main checkout's.
if ($DoomedWt -and $DoomedWt.Equals((Get-RealPath $Main), [StringComparison]::OrdinalIgnoreCase)) {
    $DoomedWt = ''
    $HeadWt = ''
}
if ($DoomedWt) {
    if (Test-PathInside -Candidate (Get-RealPath $Here) -Tree $DoomedWt) {
        Exit-WithError @"
this copy of merge-pr.ps1 lives at $Here/merge-pr.ps1, INSIDE the worktree this close-out has to tear down ($DoomedWt) - REFUSED, and nothing has been touched: the worktree is intact and PR #$Pr is untouched.
  The teardown kills every process rooted in that tree, and this one is rooted there: the run would die mid-teardown, leaving the tree removed and the PR unmerged while the teardown printed a clean finish.
  Run a copy that lives OUTSIDE that tree - bare off PATH is the installed one:
    cd $Main
    merge-pr.ps1 $Pr
"@
    }
    if (Test-PathInside -Candidate (Get-RealPath (Get-Location).Path) -Tree $DoomedWt) {
        Exit-WithError @"
this run's working directory ($((Get-Location).Path)) is INSIDE the worktree this close-out has to tear down ($DoomedWt) - REFUSED, and nothing has been touched: the worktree is intact and PR #$Pr is untouched.
  The teardown kills every process whose cwd is rooted in that tree, and this one's is: the run would die mid-teardown, leaving the tree removed and the PR unmerged while the teardown printed a clean finish.
  Re-run from outside that tree - the helper resolves the repo from cwd, so stand in the main checkout:
    cd $Main
    merge-pr.ps1 $Pr
"@
    }
}

# --- Merge mode ------------------------------------------------------------------
# Three questions, all answered before anything irreversible happens, and ALL have
# to say yes for the squash path to be reachable. The order is a short-circuit: the
# config is a local file read, so a project that has not opted in never spends a
# gh call at all and behaves exactly as it does today.
#
#   1. Did the PROJECT declare it? Only the exact string "squash" counts. Absent,
#      unreadable, misspelled, or any other value is "merge".
#   2. Is this a boundary the squash is allowed to reach? The standing constraint
#      is that the squashes are for an epic buffer collapsing into an
#      integration/release branch - never for a release branch merging back into
#      `main` or `dev`. The default branch is what tells those apart, so a base
#      that IS the default branch never squashes. That is deliberately wider than
#      the release-branch case it was added for: in a project whose integration
#      branch is itself the default branch, the genuine `epic -> main` boundary is
#      skipped too, and "squash" correctly does nothing. Such a project was already
#      told to leave the setting at its default; this makes that automatic. The
#      alternative - telling an integration branch from an epic branch when both
#      merge into `main` - has no answer but a branch-name prefix, and no prefix is
#      ever the key for anything in this flow.
#   3. Is this the epic boundary? An epic branch is the branch an epic's slices
#      PR'd into, so asking GitHub how many merged PRs targeted the HEAD branch IS
#      the definition rather than a proxy for it. A slice branch and a single-slice
#      branch both answer 0, which is what keeps those two merges real without
#      needing a rule of their own.
#
# Every way questions 2 and 3 can fail to produce a usable answer - gh missing,
# unauthenticated, offline, rate-limited, a default branch that came back empty or
# unresolvable, a branch nobody PR'd into, a reply that is not a number - lands on
# "merge". The asymmetry is the whole design: a missed squash leaves a readable
# history that merely has more commits in it, while a wrong squash flattens an
# arc's commits off the integration branch irreversibly.
#
# The epic tip is captured HERE, before the merge, because the squash close-out
# below needs the commit that was gated in order to check what actually landed -
# and after the squash the PR no longer points at a branch that exists. Failing to
# capture it therefore falls back to "merge" as well: without that commit the
# squash path has no substitute for the ancestry check it breaks, and a squash
# whose result cannot be verified is exactly the unrecoverable case above.
$MergeMode = 'merge'
$EpicTip = ''
# `-ceq`, not `-eq`: PowerShell's default string comparison ignores case, so `-eq`
# would accept "Squash" and "SQUASH" where the bash sibling's `=` accepts neither.
# Observed on this very pair before the fix - the .ps1 squashed a config the .sh
# merged, from the same file. Only the exact string counts, on both sides.
if ($HeadBranch -and (Get-ConfigScalar -Path "$Main/$ConfigRel" -Name 'epicMerge') -ceq 'squash') {
    # An unknown default branch is not a licence to guess, and "not answered" has
    # two shapes rather than one. gh (2.92) renders a null field as an empty line -
    # which is also what a failed call and a repository with no default branch
    # produce - while a raw `jq -r` prints the literal "null" for that same input.
    # A gh that ever formatted it the second way would hand back a string that
    # compares unequal to every real base, i.e. it would read as "not the default
    # branch" and OPEN the squash path on the one answer that means the question
    # went unanswered. Both shapes are normalised to empty so the single truthiness
    # test below covers them, and a branch genuinely named `null` is normalised
    # with them: on an answer this ambiguous, merge is the direction everything on
    # this path errs in.
    $defaultBranch = Invoke-InMainCheckout -Body {
        $value = (& gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { return '' }
        return $value
    }
    if ($defaultBranch -ceq 'null') { $defaultBranch = '' }
    # `-cne`, not `-ne`: PowerShell's default string comparison ignores case, and
    # git refs are case-SENSITIVE, so a base literally named `Main` in a repo whose
    # default branch is `main` is a different branch that `-ne` would call the same
    # one - skipping a squash that was legitimate. The same class of bug the
    # `-ceq 'squash'` above exists for, arriving through the other comparison, and
    # in the other direction; both are wrong and only the case-sensitive form
    # matches what the bash sibling's `!=` does.
    if ($defaultBranch -and ($Integration -cne $defaultBranch)) {
        $slicePrs = Invoke-InMainCheckout -ArgumentList @($HeadBranch) -Body {
            param([string] $Base)
            $value = (& gh pr list --base $Base --state merged --json number --jq 'length' 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -ne 0) { return '' }
            return $value
        }
        if ($slicePrs -match '^[0-9]+$' -and [int] $slicePrs -gt 0) {
            # Read the same way as the mergeCommit field above: the batch requested
            # it, so the property exists on the object whether or not it carries a
            # value.
            $tip = ''
            if ($PrView.headRefOid) { $tip = [string]$PrView.headRefOid }
            if ($tip) {
                $MergeMode = 'squash'
                $EpicTip = $tip
                Write-Output "merge-pr: '$HeadBranch' is an epic branch ($slicePrs merged slice PR(s) targeted it) and this project declares epicMerge=squash - it collapses into one commit on '$Integration'."
            }
        }
    }
}

# --- 1. Mergeability preflight ---------------------------------------------------
# Everything past this point is irreversible, and the step that can actually fail -
# the merge - is the last one. A PR whose base moved under it fails there with
# "Pull Request has merge conflicts", by which point the worktree teardown has
# already removed the only tree the conflict could be resolved in and the review
# flag has already been flipped. So ask GitHub whether the merge is possible while
# nothing has been touched yet, and stop clean if it is not.
#
# `mergeable` is computed asynchronously: GitHub answers UNKNOWN while its test
# merge is still running, which is the ordinary answer for a PR pushed seconds ago.
# UNKNOWN means "not yet known" - neither CONFLICTING nor fine - so it is polled a
# few times and then FALLS THROUGH rather than blocking. Hard-failing on UNKNOWN
# would make this helper flaky on exactly the PRs that just arrived, and the merge
# in step 3 is a truthful authority for the case the poll could not resolve.
if ($State -ne 'MERGED') {
    $Mergeable = [string]$PrView.mergeable
    foreach ($attempt in 1..3) {
        if ($Mergeable -eq 'MERGEABLE' -or $Mergeable -eq 'CONFLICTING') { break }
        Write-Output "merge-pr: mergeability not computed yet (attempt $attempt/3) - waiting ..."
        Start-Sleep -Seconds 2
        $Mergeable = Get-PrField 'mergeable'
    }
    if ($Mergeable -eq 'CONFLICTING') {
        # Name the worktree the caller has to resolve it in - setup-worktree.ps1 puts
        # it at one of exactly two paths, decided by whether this repo sits in a
        # workspace.
        $ConflictWt = "$WorktreeHome/$Project/$Leaf"
        if ($WorkspaceWt) { $ConflictWt = $WorkspaceWt }
        Exit-WithError @"
PR #$Pr conflicts with '$Integration' - nothing has been touched: the worktree is intact and the PR is still a draft.
  Resolve it in the branch's own worktree, by merging the base IN (never rebase - these branches are never rewritten):
    cd $ConflictWt
    git fetch origin && git merge origin/$Integration
    <resolve, commit, push>
  If that worktree is gone, re-attach one first: setup-worktree.ps1 --existing $HeadBranch
  Then re-gate the PR and re-run: merge-pr.ps1 $Pr
"@
    }
}

# --- 2. Remove the head branch's worktree --------------------------------------
# Before the merge, so `--delete-branch` can remove the local branch - the ordering
# git forces, and the reason step 1 exists: it is only safe to tear the tree down
# once the merge is known to be possible. remove-worktree.ps1 is idempotent, no-oping
# if the worktree is already gone. REPO is handed over through the environment rather
# than a `$env:` assignment expression so the parity check's env-var scan sees only
# what this script CONSUMES, never what it produces.
#
# Hand over the PATH this run already resolved, not the branch name. $HeadWt is git's
# own answer to "which worktree has this branch checked out", so it is right under
# every layout at once - the bare <worktree home>/<project>/<leaf>, a workspace
# member's <worktree home>/<workspace>/<leaf>/<repo>, and anywhere WORKTREE_DEST put
# one. Passing the branch made the callee re-derive from scratch what the caller was
# already holding, and that is exactly how the two got out of step: this helper knew
# about the workspace layout and remove-worktree did not, so a workspace member's
# teardown resolved a path that never existed, reported "already removed", and exited
# 0 - which the $LASTEXITCODE check below duly passed, because the miss was not an
# error - and the --delete-branch below then ran against a branch still checked out
# in a live worktree, the precise failure the remove-then-merge ordering prevents.
#
# The branch name stays as the fallback for the case git has no answer to give: a
# worktree in detached HEAD, one whose branch was switched, or a tree already gone.
# There remove-worktree.ps1's own (now workspace-aware) resolution takes over, which
# is why both halves of this fix were needed and neither substitutes for the other.
if ($HeadBranch) {
    Write-Output "merge-pr: tearing down worktree for $HeadBranch ..."
    $teardownTarget = $HeadBranch
    if ($HeadWt) { $teardownTarget = $HeadWt }
    $priorRepo = [Environment]::GetEnvironmentVariable('REPO')
    [Environment]::SetEnvironmentVariable('REPO', $Main)
    try {
        & (Join-Path $Here 'remove-worktree.ps1') $teardownTarget
        if ($LASTEXITCODE -ne 0) { Exit-WithError "remove-worktree.ps1 failed (exit $LASTEXITCODE)" }
    } finally {
        [Environment]::SetEnvironmentVariable('REPO', $priorRepo)
    }
}

# --- 3. Merge (unless already merged) ------------------------------------------
if ($State -eq 'MERGED') {
    Write-Output "merge-pr: PR #$Pr already merged - skipping merge, finishing the local sync."
} else {
    # draft -> ready is the dispatcher's review approval - the one thing in the
    # flow that says a human-in-the-loop read this diff, as opposed to a gate saying
    # the suite passed (the gate reports by PR comment and never touches this flag).
    # GitHub refuses to merge a draft, so the flip has to precede the merge; it sits
    # one line above it so `ready` can never be a stale badge, since the step-2
    # teardown kills processes rooted in the worktree and can take real time, and a
    # flip before that would leave a window where the PR reads as approved but is
    # not merged. `gh pr ready` on an already-ready PR is a no-op, so the flip
    # itself is unconditional and idempotent on re-run.
    #
    # isDraft is read anyway, and read HERE rather than with the fields at the top,
    # because it has one job: to say whether THIS run is what set the flag. Only
    # then may the failure path put it back - a PR that arrived already ready keeps
    # the state it came with rather than being pushed into a draft nobody asked for.
    $WasDraft = Get-PrField 'isDraft'
    Write-Output "merge-pr: marking PR #$Pr ready (review approval) ..."
    Invoke-InMainCheckout {
        & gh pr ready $Pr
        if ($LASTEXITCODE -ne 0) { Exit-WithError "gh pr ready failed (exit $LASTEXITCODE)" }
    }
    # gh's own output is left flowing to the host, so the exit code travels out of
    # the scriptblock through a script-scoped flag rather than as a return value -
    # a returned boolean would arrive appended to everything gh printed.
    #
    # The squash path deliberately does NOT pass --delete-branch. The branch has to
    # outlive the merge long enough for the squash close-out below to compare what
    # landed against the commit that was gated, because that comparison is what
    # replaces the ancestry guarantee a squash destroys - and a branch already
    # deleted by the same call that squashed it could not be kept if the comparison
    # came back wrong.
    if ($MergeMode -eq 'squash') {
        $MergeArgs = @('--squash')
        Write-Output "merge-pr: merging PR #$Pr (squash - the epic buffer collapses to one commit; the branch is deleted once the tree check below passes) ..."
    } else {
        $MergeArgs = @('--merge', '--delete-branch')
        Write-Output "merge-pr: merging PR #$Pr (real merge commit, deleting branch) ..."
    }
    $script:MergeFailed = $false
    Invoke-InMainCheckout -ArgumentList @(, $MergeArgs) -Body {
        param([string[]] $GhMergeArgs)
        & gh pr merge $Pr @GhMergeArgs
        if ($LASTEXITCODE -ne 0) { $script:MergeFailed = $true }
    }
    if ($script:MergeFailed) {
        # The flag must not SURVIVE a merge that failed. A non-draft PR that is not
        # being merged right this second reads, everywhere else in this flow, as a
        # diff a dispatcher approved - so leaving it set would have the PR wearing
        # a review it never received. This matters most when step 1 answered UNKNOWN
        # and fell through: the conflict it could not rule out surfaces exactly here.
        $DraftNote = 'it was already non-draft before this run and is left that way'
        if ($WasDraft -eq 'true') {
            $script:RestoreFailed = $false
            Invoke-InMainCheckout {
                & gh pr ready $Pr --undo
                if ($LASTEXITCODE -ne 0) { $script:RestoreFailed = $true }
            }
            if ($script:RestoreFailed) {
                $DraftNote = "its draft flag could NOT be restored - put it back by hand: gh pr ready $Pr --undo"
            } else {
                $DraftNote = 'it is back to a draft'
            }
        }
        Exit-WithError @"
merging PR #$Pr failed - $DraftNote, and its worktree has already been torn down (step 2).
  Re-attach a tree to the branch, fix it there, and re-run:
    setup-worktree.ps1 --existing $HeadBranch
    cd <the READY: path it prints> && git fetch origin && git merge origin/$Integration
    <resolve, commit, push>   (merge the base IN - never rebase)
    merge-pr.ps1 $Pr
"@
    }
}

# --- 4. Sync the local base branch in the MAIN checkout --------------------------
# Anchored to MAIN so it works regardless of the caller's cwd, and only ever moving
# the branch forward: the main checkout never carries direct commits (all work lands
# via PR merge on the remote), so a non-ff means an anomaly that should stop loudly.
#
# Which of the THREE paths runs is decided by where the base branch actually is:
#
#   the main checkout is standing on it
#              -> `merge --ff-only` there; no switch is needed and the working tree
#                 follows the branch it is already on.
#   a LINKED worktree is standing on it
#              -> `merge --ff-only` inside THAT worktree. This is the ordinary path,
#                 not an edge: an epic branch gets a worktree of its own, and every
#                 slice of that epic PRs into it, so every one of those close-outs
#                 finds the base checked out somewhere.
#   nothing is standing on it
#              -> move the REF (`fetch` + `branch -f`), which needs no working tree.
#
# `branch -f` is what forces the split: git refuses to move a branch any worktree is
# standing on, so a checked-out base has to be advanced from inside its own tree.
# `--ff-only` is why doing so is safe - it can only move the branch forward, never
# discard a commit, which is the same guarantee the on-base path already relies on.
#
# What none of the three does is SWITCH the main checkout. Switching to the base
# opens a window in which another session's own switch lands, and everything after
# it then operates on whatever is checked out at that moment rather than on the base
# - observed: a slice PR based on an epic branch switched the checkout off the
# release branch, another session put it back mid-sync, and the local release branch
# was left pointing at the epic branch's merge commit, six commits of unrelated work,
# while origin/release had independently advanced. Not switching removes the window
# entirely, and leaves nothing to switch back afterwards.
$OnBase = ($StartBranch -eq $Integration)
$BaseWt = ''

# `gh pr merge` returns before GitHub is guaranteed to serve the new tip, so a sync
# fired immediately can advance to nothing and silently leave the branch on the
# PRE-merge commit - while a `rev-parse` in the done message still prints a sha and
# reads as "synced." That is the "said synced, wasn't" bug. So: poll-fetch until the
# remote actually carries the merge commit, advance each round, and VERIFY the local
# branch truly reached the merged tip. The message is never proof; the ref-equality
# check below is - and on failure we die loudly, never lie.
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
$diverged = $false
$ffFailed = $false
$ffOut = ''
foreach ($attempt in 1..6) {
    Test-GitSuccess @('-C', $Main, 'fetch', '--prune', 'origin') | Out-Null
    Assert-CheckoutUnmoved
    if ($OnBase) {
        Test-GitSuccess @('-C', $Main, 'merge', '--ff-only', "origin/$Integration") | Out-Null
    } else {
        $hasLocal = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/heads/$Integration")
        if ($hasLocal -and -not (Test-GitSuccess @('-C', $Main, 'merge-base', '--is-ancestor', $Integration, "origin/$Integration"))) {
            # Checked FIRST, so it covers both off-base paths rather than only the
            # ref one. It is the precise instrument for one of the two ways a sync
            # can be blocked - the local branch carrying commits the remote does not
            # - and answering it here, off the refs, is what lets the worktree path
            # below attribute its own failure to the OTHER cause instead of guessing
            # between them. `branch -f` is a force move and could DISCARD those
            # commits; `merge --ff-only` could not, but would fail with a message the
            # caller then has to interpret. Either way it is a stable condition - the
            # remote only ever advances - so stop on it rather than retrying.
            $diverged = $true
            break
        }
        # Re-resolved EVERY round rather than once before the loop, because `merge`
        # names no branch: it moves whatever the tree it runs in has checked out.
        # Asking which tree holds the base immediately before merging in it is what
        # keeps those two the same tree, and it is the same question either way, so a
        # stale answer buys nothing. It also makes both ways the answer can change
        # self-healing instead of fatal: a worktree removed mid-run, or switched to
        # another branch, simply stops holding the base, and the sync falls through to
        # moving the ref - which is what is now correct for that state.
        $BaseWt = Get-WorktreeHoldingBranch -Branch $Integration
        if ($BaseWt) {
            # A linked worktree is standing on the base, so its ref cannot be moved
            # from outside; advance it from inside that tree instead. Divergence was
            # ruled out above, so a failure here is the tree's STATE, not the refs' -
            # keep git's own message, which names the files that block the
            # fast-forward and is the part a caller cannot re-derive from
            # "sync failed". The try/catch is for the redirection rather than for git:
            # `2>&1` on a native command turns its stderr into error records, and
            # whether that is data or a terminating error under
            # $ErrorActionPreference = 'Stop' has moved between PowerShell versions.
            # Either way the outcome a caller needs is the same one, so catching it
            # here keeps a host difference from turning a reportable sync failure into
            # an unhandled one.
            try {
                $ffOut = ((& git -C $BaseWt merge --ff-only "origin/$Integration" 2>&1) | Out-String).Trim()
                $ffOk = ($LASTEXITCODE -eq 0)
            } catch {
                $ffOut = $_.Exception.Message
                $ffOk = $false
            }
            if (-not $ffOk) {
                $ffFailed = $true
                break
            }
        } else {
            # Creates the branch when the main checkout has no local copy of it, which
            # is the ordinary state for an epic branch whose own worktree has since
            # been torn down.
            Test-GitSuccess @('-C', $Main, 'branch', '-f', $Integration, "origin/$Integration") | Out-Null
        }
    }
    # The merge-commit ancestry test is only asked once the two refs already agree,
    # so the rounds spent waiting for the remote to serve the merge cost one git
    # spawn rather than two.
    $local = Get-GitRefOrEmpty "refs/heads/$Integration"
    $remote = Get-GitRefOrEmpty "refs/remotes/origin/$Integration"
    if ($local -and $local -eq $remote) {
        $carriesMerge = $true
        if ($MergeOid) {
            $carriesMerge = Test-GitSuccess @('-C', $Main, 'merge-base', '--is-ancestor', $MergeOid, $Integration)
        }
        if ($carriesMerge) {
            $synced = $true
            break
        }
    }
    Write-Output "merge-pr: remote not serving the merge yet (attempt $attempt/6) - waiting ..."
    Start-Sleep -Seconds 2
}
if ($diverged) {
    Exit-WithError @"
local '$Integration' carries commits 'origin/$Integration' does not, so advancing it would discard them - REFUSED, and the local branch is untouched. PR #$Pr IS merged; only the local sync is outstanding.
  Inspect what is on it and reconcile it by hand:
    git -C $Main log --oneline origin/$Integration..$Integration
  Until then do NOT cut new worktrees off '$Integration'.
"@
}
if ($ffFailed) {
    $ffDetail = $ffOut
    if (-not $ffDetail) { $ffDetail = '(no output)' }
    Exit-WithError @"
could not fast-forward '$Integration' inside the worktree $BaseWt, so the local branch is still behind the merged tip. PR #$Pr IS merged; only the local sync is outstanding.
  '$Integration' is NOT diverged - that was checked first - so what blocks it is the state of that working tree: uncommitted changes over a file the fast-forward touches, or a merge left unfinished in it. git said:
    $ffDetail
  Clear that tree and finish the sync from inside it:
    git -C $BaseWt status
    git -C $BaseWt merge --ff-only origin/$Integration
  Until then do NOT cut new worktrees off '$Integration' - the local ref is behind the merged tip.
"@
}
if (-not $synced) {
    $oid = $MergeOid
    if (-not $oid) { $oid = 'unknown' }
    Exit-WithError "local '$Integration' did NOT reach the merged tip (merge commit $oid still absent after retries) - SYNC FAILED; do NOT cut new worktrees off '$Integration' until this is resolved."
}

# --- 5. Squash close-out: verify the tree, THEN delete the branch ----------------
# Nothing to do on the merge path - `--delete-branch` already removed both copies
# of the branch, and the merge commit's second parent keeps the ancestry that
# `git branch -d` and the integration gate's `^2` check both read.
#
# On the squash path neither of those is true, and the two failures are one fact:
# the squash commit has no second parent, so the epic branch is NOT an ancestor of
# the new integration tip. `git branch -d` therefore reports it as not fully
# merged on EVERY squashed close-out, and the flow's standing rule - stop on that
# warning, never force past it - would halt every one of them if followed
# literally here.
#
# So the warning is not waved through; it is ANSWERED BY A DIFFERENT INSTRUMENT.
# It is a statement about ancestry, and squash breaks ancestry by construction, so
# on this path it is expected and carries no information. What has to be true
# instead is that what landed IS what was gated, and that is a question about
# TREES, which a squash preserves exactly:
#
#   git diff --quiet <epic tip before the merge> <the squash commit>
#
# Empty means the integration branch now holds, byte for byte, the tree the
# close-out gate ran on. That is a stronger property than `^2` ever gave, because
# it compares the trees directly instead of inferring coverage from parentage -
# and it only comes back empty when the close-out cadence was actually run, since
# the final `merge origin/<integration>` into the epic before gating is what makes
# those two trees equal. A skipped cadence surfaces here as a failed comparison
# rather than as a non-empty diff nobody looked at.
#
# Deleting only ever happens after that comparison passes. If it fails the branch
# survives untouched, which is the entire safety story on this path.
#
# Placed after the sync rather than beside the merge so that a failure here leaves
# every other part of the close-out finished: the merge is done and the local base
# branch is at the merged tip, so the only thing outstanding is a branch that still
# exists. Re-running the helper resumes from exactly here.
if ($MergeMode -eq 'squash') {
    $hasRemote = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/remotes/origin/$HeadBranch")
    $hasLocal = Test-GitSuccess @('-C', $Main, 'show-ref', '--verify', '--quiet', "refs/heads/$HeadBranch")
    if (-not $hasRemote -and -not $hasLocal) {
        Write-Output "merge-pr: '$HeadBranch' is already gone locally and on origin - an earlier run finished the squash close-out."
    } else {
        $tipShort = $EpicTip
        if ($tipShort.Length -gt 12) { $tipShort = $tipShort.Substring(0, 12) }
        Write-Output "merge-pr: verifying the squashed tree against the epic tip that was gated ($tipShort) ..."
        # Both objects have to be READABLE before the comparison means anything: an
        # absent one makes `git diff` fail rather than answer, and a check that could
        # not run must never stand in for one that passed. The epic tip survives in
        # the local branch or in origin/<head> - neither is pruned yet, because this
        # path is exactly the one that did not delete the branch - and the squash
        # commit arrived with step 4's fetch, which already proved '$Integration'
        # carries it.
        $verifyFailed = ''
        if (-not $MergeOid) {
            $verifyFailed = "GitHub has not reported the squash commit for PR #$Pr yet, so there is nothing to compare the epic tip against"
        } elseif (-not (Test-GitSuccess @('-C', $Main, 'cat-file', '-e', "$EpicTip^{commit}"))) {
            $verifyFailed = "the epic tip $EpicTip is not an object this repo holds, so the comparison could not be made"
        } elseif (-not (Test-GitSuccess @('-C', $Main, 'cat-file', '-e', "$MergeOid^{commit}"))) {
            $verifyFailed = "the squash commit $MergeOid is not an object this repo holds, so the comparison could not be made"
        } elseif (-not (Test-GitSuccess @('-C', $Main, 'diff', '--quiet', $EpicTip, $MergeOid))) {
            $verifyFailed = "the tree on '$Integration' after the squash is NOT the tree that was gated"
        }
        if ($verifyFailed) {
            $rhs = $MergeOid
            if (-not $rhs) { $rhs = '<squash commit>' }
            Exit-WithError @"
PR #$Pr was squashed onto '$Integration', but $verifyFailed - so '$HeadBranch' has NOT been deleted and is intact, locally and on origin.
  On this path that comparison REPLACES git's "not fully merged" warning: a squash breaks ancestry by construction, so the warning says nothing, and the tree check is the only thing standing between the delete and losing work. It did not pass, so nothing was deleted.
  See for yourself:
    git -C $Main diff $EpicTip $rhs
  The usual cause is the close-out cadence being skipped - '$Integration' moved while the epic ran and was never merged back INTO '$HeadBranch', so what landed is not what the close-out gate ran on.
  Everything else is done: the merge is complete and local '$Integration' is synced. Re-running merge-pr.ps1 $Pr resumes from this check.
"@
        }
        # `-D`, not `-d`. This is the one place in this flow where git's "not fully
        # merged" refusal is overridden, and that refusal is precisely the one the
        # standing rule says never to force past - so the two conditions below are
        # what make it correct HERE, and neither is context that carries anywhere
        # else. (Step 4's `branch -f` forces a different refusal entirely, with its
        # own divergence check standing in for it; nothing about this line applies
        # to it, and nothing about it applies to this line.)
        #
        #   - ONLY on this path. `-d` asks the ancestry question, which a squash
        #     answers "no" for a reason that has nothing to do with whether the work
        #     landed. On the merge path that same refusal would be REAL, and nothing
        #     there needs a force anyway - `gh pr merge --delete-branch` does the
        #     deleting and no `git branch -d` runs at all.
        #   - ONLY after the tree comparison PASSED. The Exit-WithError immediately
        #     above is not a formality standing between the check and the delete; it
        #     IS the guard `-d` would otherwise have been. Reached with the
        #     comparison failed, skipped, or moved below this point, `-D` deletes a
        #     branch whose work is not on the integration branch, and nothing
        #     anywhere records that it existed.
        #
        # So do not lift this line out of the block, do not move it above that
        # Exit-WithError, and do not cite it as precedent for forcing past any other
        # guard. The tree comparison is what earns the force, and it earns it
        # exactly once, here.
        $deleteFailed = @()
        if ($hasRemote) {
            Write-Output "merge-pr: tree matches - deleting '$HeadBranch' on origin ..."
            if (-not (Test-GitSuccess @('-C', $Main, 'push', 'origin', '--delete', $HeadBranch))) {
                $deleteFailed += "git -C $Main push origin --delete $HeadBranch"
            }
        }
        if ($hasLocal) {
            Write-Output "merge-pr: tree matches - deleting local '$HeadBranch' ..."
            if (-not (Test-GitSuccess @('-C', $Main, 'branch', '-D', $HeadBranch))) {
                $deleteFailed += "git -C $Main branch -D $HeadBranch"
            }
        }
        if ($deleteFailed.Count -gt 0) {
            $commands = $deleteFailed -join "`n    "
            Exit-WithError @"
PR #$Pr is squashed onto '$Integration' and the tree was VERIFIED against the gated epic tip, but deleting '$HeadBranch' failed.
  Nothing is at risk - the work is on '$Integration' and the local sync is done; only the branch is left behind. Finish it by hand:
    $commands
"@
        }
    }
}

# --- 6. Verify the main checkout did not move under us ---------------------------
# Step 4's verification proves the BASE reached the merged tip. It has no opinion
# about a branch that moved INSTEAD - which is the half that actually corrupts, and
# is silent: every other signal reads as a successful close-out. Nothing here
# switches the checkout, so a branch or HEAD that differs from where the run started
# was moved by another process, and saying so is the difference between an immediate
# stop and a poisoned base the next worktree forks from.
Assert-CheckoutUnmoved
# Only off the base: standing ON it, HEAD is the very ref step 4 verified against the
# merged tip, so comparing it to the start commit would assert nothing but that the
# sync happened. Off it, step 4 advanced a DIFFERENT branch - by ref, or inside its
# own linked worktree - and never touched the MAIN checkout's working tree at all,
# so any movement here is another process's.
if (-not $OnBase) {
    $NowHead = Get-GitOutput @('-C', $Main, 'rev-parse', 'HEAD')
    if ($NowHead -ne $StartHead) {
        Exit-WithError "the main checkout $Main is still on '$StartBranch' but its HEAD moved from $StartHead to $NowHead - this run only advanced '$Integration', which is a different branch, so another process moved '$StartBranch' mid-run. Check where it points before cutting any worktree off it."
    }
}

$short = Get-GitOutput @('-C', $Main, 'rev-parse', '--short', $Integration)
Write-Output "merge-pr: done - PR #$Pr merged, worktree removed, local '$Integration' synced to $short, main checkout still on '$StartBranch'."
