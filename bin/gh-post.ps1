#!/usr/bin/env pwsh
# Make one of this flow's GitHub writes once, safely re-runnable, without ever
# touching a post another party made.
#
#   gh-post.ps1 comment  <issue|pr> <n>  --key <key> --body-file <file>
#   gh-post.ps1 review   <pr-n>          --key <key> --body-file <file>
#   gh-post.ps1 close    <issue-n>       --reason <completed|not_planned> [--key <key> --body-file <file>]
#   gh-post.ps1 sub-issue <parent-n> <child-n|owner/repo#n>
#
# The PowerShell sibling of gh-post.sh, for a native Windows session with no bash
# at all. Same arguments, the same REPO environment variable, the same stdout
# lines and the same exit codes, because the pair is ONE CLI contract implemented
# twice; scripts/check.sh compares the usage lines and consumed env vars, and asks
# both ports the shared predicates in scripts/port-cases/gh-post-*.tsv.
#
# ASCII only, no exceptions - see the note in setup-worktree.ps1 for why.
#
# Run it from ANYWHERE inside the target repo (or set REPO=). Every gh call runs
# from that repo's MAIN checkout, so `{owner}/{repo}` resolves to it.
#
# Why a marker, and why never the author. Every party in this flow writes as the
# SAME ambient `gh` account, so the author cannot tell one party's post from
# another's, and position or recency picks whichever party wrote last. What
# identifies a post is the hidden marker `<!-- pipeline:<key> -->` appended to its
# body, built from a key the caller chooses to name the party and the purpose.
# Before writing, the helper pages through ALL the comments (or reviews) on the
# target for one whose LAST non-blank line is exactly that marker. A key that
# merely shares a prefix does not match, because the marker's closing ` -->`
# follows the key directly, and a post that only quotes the marker somewhere in
# its body is not ours.
#
#   found     -> edit it in place (issue comments; review bodies via the
#                reviews update endpoint)              UPDATED: <url>
#   not found -> post a new one                          POSTED: <url>
#
# A decline is an answer, not an error: the sub-issue already linked to that
# parent, the issue already closed with that reason -> `DECLINED: <reason>`, exit 0.
# Those three lines - POSTED, UPDATED, DECLINED - are the whole stdout set.
#
# One line per call, except `close` with a closing comment, which prints TWO: the
# comment's POSTED/UPDATED line first, then the state line - UPDATED: <issue-url>
# when the close (or a changed reason) was written, DECLINED when the issue was
# already closed with that reason. `sub-issue` prints POSTED: <parent-url> for a new
# link; a child already under a DIFFERENT parent exits 1 and is never re-parented.
# The parent is always an issue in the repo the helper runs from; the child may
# be named `<owner>/<repo>#<n>` to link an issue from another repository, and is
# then read from that repository. GitHub refuses a child under a different owner
# from the parent's, and that refusal is the failed gh call's exit 1.
#
# `review` writes the review BODY only. A re-run edits that body in place; it
# never posts, re-posts or updates inline comments, so inline findings are not
# idempotent through this helper.
#
# Post first, follow up second. Each line is printed the moment its write exists,
# so a follow-up that fails afterwards (the state change after a closing comment)
# exits 1 with the posted URL already on stdout.
#
# Bodies always travel as `-F body=@file` - `-f` would store the literal path -
# and every write is REST through `gh api`, never the GraphQL `gh issue` / `gh pr`
# writes.
#
# Exit: 0 on any of the three answers; 1 on a failed gh or git call, with a
# helper-owned message on stderr; 2 on bad usage (including a number that names
# the wrong kind of thing - a PR where an issue was asked for, or the reverse).

# Declared rather than inherited: a caller's profile can switch native-command
# errors on, which would make a probing gh call throw before its $LASTEXITCODE is
# read. See merge-pr.ps1 for the full reasoning.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Write-Stderr {
    param([Parameter(Mandatory = $true)] [string] $Message)
    [Console]::Error.WriteLine($Message)
}

function Exit-WithError {
    param([Parameter(Mandatory = $true)] [string] $Message)
    Write-Stderr "gh-post: error: $Message"
    exit 1
}

function Exit-WithUsage {
    param([string] $Message = '')
    if ($Message) { Write-Stderr "gh-post: $Message" }
    Write-Stderr "usage: gh-post.ps1 comment <issue|pr> <n> --key <key> --body-file <file>"
    Write-Stderr "       gh-post.ps1 review <pr-n> --key <key> --body-file <file>"
    Write-Stderr "       gh-post.ps1 close <issue-n> --reason <completed|not_planned> [--key <key> --body-file <file>]"
    Write-Stderr "       gh-post.ps1 sub-issue <parent-n> <child-n|owner/repo#n>"
    Write-Stderr "  prints POSTED: <url>, UPDATED: <url> or DECLINED: <reason>, each on its own line"
    Write-Stderr "  run from inside the target repo, or set REPO=/path/to/repo"
    exit 2
}

function Get-NormalPath {
    param([string] $Path)
    if (-not $Path) { return '' }
    $p = $Path -replace '\\', '/'
    while ($p.Length -gt 1 -and $p.EndsWith('/') -and -not $p.EndsWith(':/')) {
        $p = $p.Substring(0, $p.Length - 1)
    }
    return $p
}

# --- Pure predicates ---------------------------------------------------------
# Each is answered by BOTH ports against scripts/port-cases/gh-post-*.tsv, so a
# rename here is a red gate rather than a silently uncompared pair.

function Get-PipelineMarker {
    # The hidden marker for a key.
    param([AllowEmptyString()] [string] $Key)
    return "<!-- pipeline:$Key -->"
}

function Test-MarkerMatch {
    # Is this key's marker the body's LAST non-blank line, exactly? That is where
    # this helper always puts it, and anchoring there is what keeps another party's
    # post that merely QUOTES a marker from being taken for ours and edited.
    # Ordinal and case-sensitive, as the bash sibling's `case` glob is. Trailing
    # spaces, tabs, CRs and newlines are ignored - the same four characters the
    # sibling strips, never .NET's wider idea of whitespace.
    param(
        [AllowEmptyString()] [string] $Body,
        [AllowEmptyString()] [string] $Key
    )
    $marker = Get-PipelineMarker -Key $Key
    $trimmed = $Body.TrimEnd(' ', "`t", "`r", "`n")
    if ($trimmed -ceq $marker) { return $true }
    return $trimmed.EndsWith("`n" + $marker, [StringComparison]::Ordinal)
}

function Get-ArgKind {
    # Which kind an argument vector asks for, or `usage` when it is not a valid
    # call. Purely syntactic: no file is read and nothing is fetched. A plain
    # function reading $args, so an argument such as `--key` is a value here and
    # never taken for a parameter name. Every comparison is case-sensitive, as the
    # bash sibling's are, and every pattern anchors on \z rather than $, which
    # also matches before a final newline the bash `case` would refuse.
    $argv = @($args | ForEach-Object { [string] $_ })
    if ($argv.Count -lt 1) { return 'usage' }
    $kind = $argv[0]
    if ($kind -ceq 'comment' -or $kind -ceq 'sub-issue') { $npos = 2 }
    elseif ($kind -ceq 'review' -or $kind -ceq 'close') { $npos = 1 }
    else { return 'usage' }
    $flags = @{}
    $pos = @()
    $i = 1
    while ($i -lt $argv.Count) {
        $a = $argv[$i]
        if ($a -ceq '--key' -or $a -ceq '--body-file' -or $a -ceq '--reason') {
            if ($i + 1 -ge $argv.Count) { return 'usage' }
            if ($flags.ContainsKey($a)) { return 'usage' }
            $flags[$a] = $argv[$i + 1]
            $i += 2
        } elseif ($a.StartsWith('-')) {
            return 'usage'
        } else {
            $pos += $a
            $i += 1
        }
    }
    if ($pos.Count -ne $npos) { return 'usage' }
    # Every number is a positive decimal with no leading zero. The comment kind's
    # first positional is the target type, so its number is the second. [0-9]
    # rather than \d, which also matches non-ASCII digits.
    $first = 0
    if ($kind -ceq 'comment') {
        if (-not ($pos[0] -ceq 'issue' -or $pos[0] -ceq 'pr')) { return 'usage' }
        $first = 1
    }
    # A sub-issue's child may instead be `<owner>/<repo>#<n>`, checked on its own
    # below, so only its parent is held to the bare-number rule here.
    $last = $npos
    if ($kind -ceq 'sub-issue') { $last = 1 }
    for ($k = $first; $k -lt $last; $k++) {
        if ($pos[$k] -cnotmatch '^[1-9][0-9]*\z') { return 'usage' }
    }
    if ($kind -ceq 'sub-issue') {
        # A bare number, or exactly one `/` between a non-empty owner and repo
        # from a closed ASCII set, then `#` and a positive number with no
        # leading zero.
        if ($pos[1] -cnotmatch '^([1-9][0-9]*|[A-Za-z0-9._-]+/[A-Za-z0-9._-]+#[1-9][0-9]*)\z') { return 'usage' }
        # Only a bare child names the parent's own repository, so only a bare
        # child can be a self-link.
        if ($pos[0] -ceq $pos[1]) { return 'usage' }
    }
    $haveKey = $flags.ContainsKey('--key')
    $haveBody = $flags.ContainsKey('--body-file')
    $haveReason = $flags.ContainsKey('--reason')
    if ($kind -ceq 'comment' -or $kind -ceq 'review') {
        if (-not ($haveKey -and $haveBody -and -not $haveReason)) { return 'usage' }
    } elseif ($kind -ceq 'close') {
        if (-not $haveReason -or ($haveKey -ne $haveBody)) { return 'usage' }
        $reason = $flags['--reason']
        if (-not ($reason -ceq 'completed' -or $reason -ceq 'not_planned')) { return 'usage' }
    } else {
        if ($haveKey -or $haveBody -or $haveReason) { return 'usage' }
    }
    # A key is what goes inside an HTML comment, so it is held to a closed ASCII
    # set: no space, no `>` (which could close the comment early). -cmatch keeps
    # [A-Z] to the ASCII capitals.
    if ($haveKey -and $flags['--key'] -cnotmatch '^[A-Za-z0-9._/:-]+\z') { return 'usage' }
    if ($haveBody -and -not $flags['--body-file']) { return 'usage' }
    return $kind
}

# --- Arguments -----------------------------------------------------------------

$Argv = @($args | ForEach-Object { [string] $_ })
$Kind = Get-ArgKind @Argv
if ($Kind -ceq 'usage') { Exit-WithUsage }

$Pos = @()
$Key = ''
$BodyFile = ''
$Reason = ''
for ($i = 1; $i -lt $Argv.Count; $i++) {
    switch -CaseSensitive ($Argv[$i]) {
        '--key' { $i++; $Key = $Argv[$i] }
        '--body-file' { $i++; $BodyFile = $Argv[$i] }
        '--reason' { $i++; $Reason = $Argv[$i] }
        default { $Pos += $Argv[$i] }
    }
}

if ($BodyFile -and -not (Test-Path -LiteralPath $BodyFile -PathType Leaf)) {
    Exit-WithUsage "body file not found: $BodyFile"
}

$Repo = $env:REPO
if (-not $Repo) { $Repo = (Get-Location).Path }

if (-not (Get-Command -Name 'gh' -ErrorAction SilentlyContinue)) {
    Exit-WithError "gh (GitHub CLI) not found on PATH"
}

# Resolve the MAIN working tree - same logic as the other helpers.
$commonOut = & git -C $Repo rev-parse --path-format=absolute --git-common-dir 2>$null
if ($LASTEXITCODE -ne 0) {
    Exit-WithError "not inside a git repo: $Repo`n  run from inside the target repo, or set REPO=/path/to/repo"
}
$Main = Get-NormalPath (Split-Path -Path (Get-NormalPath (($commonOut | Out-String).Trim())) -Parent)

# --- gh ----------------------------------------------------------------------

function Invoke-GhApi {
    # One REST call, from the MAIN checkout, its stdout trimmed - or exit 1 with a
    # message naming the helper, word for word the bash sibling's gh_api.
    param(
        [Parameter(Mandatory = $true)] [string] $What,
        [Parameter(Mandatory = $true)] [string[]] $GhArgs
    )
    Push-Location -LiteralPath $Main
    try {
        $out = & gh api @GhArgs
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($code -ne 0) { Exit-WithError "$What failed (gh exit $code)" }
    return (($out | Out-String).Trim())
}

function Get-KindWord {
    param([string] $Type)
    if ($Type -ceq 'issue') { return 'an issue' }
    return 'a pull request'
}

function Get-Target {
    # `issue` or `pr` for a number, plus the state the close kind needs, in one
    # read. No jq expression here carries a string literal: Windows PowerShell 5.1
    # strips embedded double quotes from a native command's arguments. @tsv prints
    # a null as empty.
    param([Parameter(Mandatory = $true)] [string] $Number)
    $row = Invoke-GhApi -What "reading #$Number" -GhArgs @(
        "repos/{owner}/{repo}/issues/$Number",
        '--jq', '[(.pull_request != null), .state, .url, .state_reason] | @tsv')
    $cols = $row -split "`t"
    $type = 'issue'
    if ($cols[0] -ceq 'true') { $type = 'pr' }
    $reason = ''
    if ($cols.Count -gt 3) { $reason = $cols[3] }
    return [pscustomobject]@{ Type = $type; State = $cols[1]; ApiUrl = $cols[2]; Reason = $reason }
}

function Assert-TargetType {
    param(
        [Parameter(Mandatory = $true)] [string] $Number,
        [Parameter(Mandatory = $true)] [string] $Type
    )
    $target = Get-Target -Number $Number
    if ($target.Type -cne $Type) {
        Exit-WithUsage "#$Number is $(Get-KindWord -Type $target.Type), not $(Get-KindWord -Type $Type)"
    }
    return $target
}

function Get-MarkedBodyFile {
    # The body as posted: the caller's file with the marker appended as its last
    # line, unless the file already ends with it. Trailing LFs are dropped first,
    # exactly as the bash sibling's command substitution drops them (and nothing
    # else - a CR stays), so an LF or CRLF file posts the same text from both
    # ports; a UTF-8 BOM, which ReadAllText consumes, is the one difference.
    param([Parameter(Mandatory = $true)] [string] $Dir)
    $body = ([IO.File]::ReadAllText((Resolve-Path -LiteralPath $BodyFile).ProviderPath)).TrimEnd("`n")
    if (Test-MarkerMatch -Body $body -Key $Key) {
        $text = "$body`n"
    } else {
        $text = "$body`n`n$(Get-PipelineMarker -Key $Key)`n"
    }
    $path = Join-Path $Dir 'body.md'
    [IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
    return $path
}

function Find-MarkedPost {
    # The first post on a listing endpoint carrying this key's marker, or $null.
    # Every page is read: a marker on page two is still ours to update. Bodies
    # travel base64-encoded so a newline or a tab inside one cannot break the row.
    param(
        [Parameter(Mandatory = $true)] [string] $What,
        [Parameter(Mandatory = $true)] [string] $Endpoint
    )
    $rows = Invoke-GhApi -What $What -GhArgs @(
        '--paginate', $Endpoint,
        '--jq', '.[] | [.id, .html_url, (.body | values | @base64)] | @tsv')
    foreach ($line in ($rows -split "`r?`n")) {
        if (-not $line) { continue }
        $cols = $line -split "`t"
        $body = ''
        if ($cols.Count -gt 2 -and $cols[2]) {
            try {
                $body = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($cols[2]))
            } catch {
                Exit-WithError "could not decode a body from $Endpoint"
            }
        }
        if (Test-MarkerMatch -Body $body -Key $Key) {
            return [pscustomobject]@{ Id = $cols[0]; Url = $cols[1] }
        }
    }
    return $null
}

function Send-Comment {
    param(
        [Parameter(Mandatory = $true)] [string] $Number,
        [Parameter(Mandatory = $true)] [string] $Dir
    )
    $marked = Get-MarkedBodyFile -Dir $Dir
    $found = Find-MarkedPost -What "listing the comments on #$Number" -Endpoint "repos/{owner}/{repo}/issues/$Number/comments"
    if ($found) {
        $url = Invoke-GhApi -What "editing comment $($found.Url)" -GhArgs @(
            '-X', 'PATCH', "repos/{owner}/{repo}/issues/comments/$($found.Id)",
            '-F', "body=@$marked", '--jq', '.html_url')
        Write-Output "UPDATED: $url"
    } else {
        $url = Invoke-GhApi -What "commenting on #$Number" -GhArgs @(
            '-X', 'POST', "repos/{owner}/{repo}/issues/$Number/comments",
            '-F', "body=@$marked", '--jq', '.html_url')
        Write-Output "POSTED: $url"
    }
}

# --- The four kinds --------------------------------------------------------------

$TmpDir = Join-Path ([IO.Path]::GetTempPath()) ("gh-post-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TmpDir | Out-Null
try {
    switch -CaseSensitive ($Kind) {
        'comment' {
            $null = Assert-TargetType -Number $Pos[1] -Type $Pos[0]
            Send-Comment -Number $Pos[1] -Dir $TmpDir
        }
        'review' {
            $n = $Pos[0]
            $null = Assert-TargetType -Number $n -Type 'pr'
            $marked = Get-MarkedBodyFile -Dir $TmpDir
            $found = Find-MarkedPost -What "listing the reviews on PR #$n" -Endpoint "repos/{owner}/{repo}/pulls/$n/reviews"
            if ($found) {
                $url = Invoke-GhApi -What "editing review $($found.Url)" -GhArgs @(
                    '-X', 'PUT', "repos/{owner}/{repo}/pulls/$n/reviews/$($found.Id)",
                    '-F', "body=@$marked", '--jq', '.html_url')
                Write-Output "UPDATED: $url"
            } else {
                $url = Invoke-GhApi -What "posting a review on PR #$n" -GhArgs @(
                    '-X', 'POST', "repos/{owner}/{repo}/pulls/$n/reviews",
                    '-f', 'event=COMMENT', '-F', "body=@$marked", '--jq', '.html_url')
                Write-Output "POSTED: $url"
            }
        }
        'close' {
            $n = $Pos[0]
            $target = Assert-TargetType -Number $n -Type 'issue'
            # The closing comment first, so its URL is on stdout before the state
            # change that can still fail.
            if ($Key) { Send-Comment -Number $n -Dir $TmpDir }
            if ($target.State -ceq 'closed' -and $target.Reason -ceq $Reason) {
                Write-Output "DECLINED: #$n is already closed as $Reason"
            } else {
                $url = Invoke-GhApi -What "closing #$n as $Reason" -GhArgs @(
                    '-X', 'PATCH', "repos/{owner}/{repo}/issues/$n",
                    '-f', 'state=closed', '-f', "state_reason=$Reason", '--jq', '.html_url')
                Write-Output "UPDATED: $url"
            }
        }
        'sub-issue' {
            $parent = $Pos[0]
            $child = $Pos[1]
            # A qualified child is read from its own repository and named as
            # given; a bare one lives in this repo and is named `#<n>`.
            $hash = $child.IndexOf('#')
            if ($hash -ge 0) {
                $childRef = $child
                $childApi = "repos/$($child.Substring(0, $hash))/issues/$($child.Substring($hash + 1))"
            } else {
                $childRef = "#$child"
                $childApi = "repos/{owner}/{repo}/issues/$child"
            }
            $parentTarget = Assert-TargetType -Number $parent -Type 'issue'
            $row = Invoke-GhApi -What "reading $childRef" -GhArgs @(
                $childApi,
                '--jq', '[(.pull_request != null), .id, .parent_issue_url] | @tsv')
            $cols = $row -split "`t"
            if ($cols[0] -cne 'false') { Exit-WithUsage "$childRef is a pull request, not an issue" }
            $childId = $cols[1]
            $childParent = ''
            if ($cols.Count -gt 2) { $childParent = $cols[2] }
            if ($childParent -ceq $parentTarget.ApiUrl) {
                Write-Output "DECLINED: $childRef is already a sub-issue of #$parent"
            } elseif ($childParent) {
                # Another parent's link is another party's decision; re-parenting
                # it is not this helper's call.
                # Named by number where that parent lives in this repo, by its URL
                # where not.
                $repoApi = $parentTarget.ApiUrl.Substring(0, $parentTarget.ApiUrl.LastIndexOf('/') + 1)
                if ($childParent.StartsWith($repoApi, [StringComparison]::Ordinal)) {
                    $childParent = '#' + $childParent.Substring($childParent.LastIndexOf('/') + 1)
                }
                Exit-WithError "$childRef is already a sub-issue of $childParent - not re-parenting it under #$parent"
            } else {
                $url = Invoke-GhApi -What "linking $childRef under #$parent" -GhArgs @(
                    '-X', 'POST', "repos/{owner}/{repo}/issues/$parent/sub_issues",
                    '-F', "sub_issue_id=$childId", '--jq', '.html_url')
                Write-Output "POSTED: $url"
            }
        }
    }
} finally {
    Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
