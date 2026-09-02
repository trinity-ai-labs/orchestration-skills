#!/bin/sh
# The repo's gate — the check a contributor runs before pushing, and the exact
# command CI runs. There is deliberately ONE copy: two copies of a check drift,
# and the one that stops firing looks identical to the one that passed.
#
#   sh scripts/check.sh
#
# POSIX /bin/sh with no bashisms, so it holds to the standard it enforces on
# bin/. It needs nothing installed beyond shellcheck, python3, and bash — this
# repo has no package.json and no install step by design, and a gate that
# required one would be a gate nobody could run before pushing.
#
# What it enforces, and the failure each rule prevents:
#   1. Every shell script passes shellcheck at the dialect its own shebang
#      declares. bin/ ships and lands on a user's PATH, so a bashism there is a
#      runtime failure discovered at the moment of use. Reading the shebang
#      keeps this correct if a script ever legitimately needs bash — the shebang
#      is the contract, and this checks whatever it declares.
#   2. .claude-plugin/plugin.json parses and carries what Claude Code needs.
#      `claude plugin validate --strict` is the authoritative check and the one
#      the community-marketplace review runs, but it needs the CLI installed and
#      is not reproducible on a bare runner. This covers the failure modes that
#      actually break a published plugin: unparseable JSON, a missing name, and
#      the `author` field whose absence makes --strict fail at submission time.
#      The catalogue that lists this plugin lives in trinity-ai-labs/claude-plugins
#      and is validated there — this repo ships a plugin, not a marketplace.
#   3. Every skill has the frontmatter Claude Code needs, with `name` matching
#      its directory. A skill missing `name` or `description` silently fails to
#      load, and a mismatched `name` registers the slash-command under the wrong
#      word.
#   4. No skill prescribes `gh api -f` with an `@file` value. `-f`/`--raw-field`
#      sends its value verbatim; only `-F`/`--field` expands a leading `@` into
#      the file's contents. A skill documenting `gh api … -f body=@file` teaches
#      the agent to publish the literal path instead of the issue body — and `gh`
#      exits 0 with a comment URL, so neither the agent nor anything downstream
#      notices. Only a human opening the issue sees it.
#      Anchored on `gh api` so that prose QUOTING the wrong flag to warn against
#      it stays legal — the warning bullets in write-issue and decompose have to
#      name `-f body=@file` to be about it, and a guard that cannot tell a
#      prescription from a warning would force the next author to delete the
#      warning to get green.
#   5. examples/worktree.json parses AND the real reader agrees with it.
#      setup-worktree.sh reads envFiles/env/install out of a project's
#      .agents/worktree.json; if the example drifts from that shape, every repo
#      copied from it gets a bare worktree with no env and no node_modules.
#   6. Every bin/*.ps1 lints under PSScriptAnalyzer. bin/ ships on a user's PATH
#      inside whichever shell Claude Code hands them, so a defect in a .ps1 is a
#      runtime failure on a Windows user's machine at the moment of use, exactly
#      as a bashism in a .sh is. This is the one check here that needs a tool the
#      repo does not require, so it reports SKIPPED — never ok — when pwsh or the
#      module is absent: a check that could not run has nothing to say, and green
#      for it is a claim CI later contradicts.
#   7. bin/ ships the same helper in BOTH shells, and the two agree: every
#      bin/<name>.sh has a bin/<name>.ps1 sibling and vice versa, their usage
#      lines carry the same argument spec, they consume the same CONTRACT
#      environment variables (the ones a caller passes, which AGENTS.md freezes —
#      not every variable each side internally touches, since the bash helpers
#      need MSYS path-translation plumbing that has no PowerShell counterpart),
#      and every .ps1 is printable ASCII terminated by LF.
#      Two failures, both silent. A helper that exists in only one language works
#      for part of the userbase and is simply missing for the rest, with no error
#      until someone on the other shell finds nothing on PATH. And a non-ASCII
#      byte in a .ps1 corrupts under Windows PowerShell 5.1, which decodes a
#      BOM-less file as the system ANSI codepage — surfacing as a parse error
#      nowhere near the character that caused it. AGENTS.md states both rules;
#      only this check enforces them, because prose does not stop two
#      hand-maintained copies of the same logic from drifting apart, it only
#      makes the drift someone's fault after the fact.
#   8. Every skills/<name>/SKILL.md path cited in a tracked *.md resolves in the
#      tree. The skills point at each other constantly instead of restating each
#      other — two copies of a rule drift and nothing marks which one is stale —
#      so a rename or a deletion leaves a citation pointing at nothing, and a
#      dead path reads exactly as authoritative as a live one. Observed: a
#      dispatch instruction named the wrong skill, survived a rename that swapped
#      two skills' names wholesale, read perfectly across seven releases, and
#      reached two live briefs. Scoped to git-tracked files, so an untracked
#      scratch note or a gate log left in a worktree cannot turn the gate red.
#      What it does NOT reach, deliberately: only the file-path form. A citation
#      by prose phrase (decompose's Verify field cites "per execute's own note on
#      backgrounding a banned run") and a count duplicated across two sentences
#      ("five items" against "one of the four") go stale identically and are
#      invisible here. Neither is mechanically checkable in this corpus: italics
#      carry emphasis throughout, not just around section names, so a pattern
#      over them is mostly false positives, and a noisy check is one the next
#      author routes around. Both keep the prose rules already pointed at them.
#      The third residual IS a coordinate and is left out only by scope: a
#      reference doc cited by path, skills/setup/references/gate-queue.md, cited
#      4 times and resolving today. Widening to it is a character class, not a
#      new idea — counted here so it stays countable rather than forgotten.
#      The line drawn is the corpus's own — if a checker can tell the reference
#      is stale without reading the sentence, it is a coordinate.
#      Unlike 4 there is no anchor separating a citation from prose SHOWING a
#      dead path, because a dead path is a dead path either way. A doc that needs
#      to display one writes it in the placeholder form the corpus already uses
#      (this comment, or README.md's skills/<slug>/SKILL.md): angle brackets are
#      not a path component, so nothing has to be suppressed — and no per-line
#      opt-out is offered, since one would be indistinguishable from a real stale
#      citation claiming to be deliberate.
#
# Every check that scans a SET of files asserts the set is non-empty before it
# scans: a check whose pattern stops matching prints the same green as a check
# that passed, so an empty scan is a failure in its own right.
#
# NOT here, deliberately: the version-bump guard. It diffs against a PR base and
# reads the manifest as it was at that commit, so it is meaningful only in CI —
# a local copy would either not work or lie about what a merge would ship. It
# stays inline in .github/workflows/ci.yml.
#
# Reports EVERY failure rather than stopping at the first, then exits 1.

set -u

# Run from the repo root regardless of where the caller stood, so every relative
# path below means the same thing whether CI or a contributor invoked it.
root="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)" || exit 2
cd "$root" || exit 2

fails=0
fail() {
	fails=$((fails + 1))
	printf 'FAIL  %s\n' "$1" >&2
}
ok() {
	printf 'ok    %s\n' "$1"
}
# Distinct from ok on purpose. A check that could not run must not print green —
# so the one step below that needs an optional tool says SKIP and names what was
# not examined, rather than passing silently and being contradicted by CI.
skip() {
	printf 'SKIP  %s\n' "$1"
}

# A missing tool must not read as green, and it cannot be reported per-check
# either — a check that never ran has nothing to say. Refuse up front instead.
#
# `pwsh` is deliberately NOT on this list. The repo is zero-dependency by design,
# and a gate that needs an install is a gate nobody can run before pushing — so
# requiring pwsh to check a Windows helper would cost every contributor on macOS
# and Linux the ability to run the gate at all. The parity check (7) needs no
# pwsh and therefore always runs; only PSScriptAnalyzer (6) needs one, and it
# skips loudly.
missing=''
for tool in shellcheck python3 bash; do
	command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
	printf 'check: required tool(s) not on PATH:%s\n' "$missing" >&2
	printf 'check: install them and re-run — a check that cannot run must not print green.\n' >&2
	exit 2
fi

# --- 1. shell scripts lint at their declared dialect -------------------------

sh_files=''
for f in bin/*.sh scripts/*.sh; do
	[ -f "$f" ] || continue
	sh_files="$sh_files $f"
done
if [ -z "$sh_files" ]; then
	fail "shellcheck: no scripts matched bin/*.sh or scripts/*.sh — this check scanned nothing"
elif shellcheck -S warning $sh_files; then
	ok "shellcheck clean:$sh_files"
else
	fail "shellcheck: problems reported above"
fi

# --- 2. the plugin manifest parses and carries what Claude Code needs --------

manifest='.claude-plugin/plugin.json'
if [ ! -f "$manifest" ]; then
	fail "manifest: $manifest is missing — this check had nothing to validate"
else
	manifest_problems="$(
		python3 - "$manifest" <<'PY'
import json, pathlib, sys

path = pathlib.Path(sys.argv[1])
try:
    plugin = json.loads(path.read_text())
except ValueError as err:
    print(f"does not parse as JSON: {err}")
    sys.exit(0)
if not isinstance(plugin, dict):
    print("is not a JSON object")
    sys.exit(0)
for field in ("name", "description", "author", "version", "license"):
    if not plugin.get(field):
        print(f"missing '{field}'")
PY
	)" || {
		fail "manifest: the reader crashed — $manifest could not be examined"
		manifest_problems=''
	}
	if [ -n "$manifest_problems" ]; then
		printf '%s\n' "$manifest_problems" | while IFS= read -r problem; do
			printf 'FAIL  manifest: %s: %s\n' "$manifest" "$problem" >&2
		done
		# Counted here rather than in the loop above: a `while` fed by a pipe runs
		# in a subshell, so an increment inside it is discarded and the script
		# would exit 0 having just printed failures.
		fails=$((fails + 1))
	else
		ok "manifest: $manifest parses and carries every required field"
	fi
fi

# --- 3. every skill has the frontmatter Claude Code dispatches on ------------

skills_seen=0
for dir in skills/*/; do
	[ -d "$dir" ] || continue
	skills_seen=$((skills_seen + 1))
	slug="${dir%/}"
	slug="${slug##*/}"
	file="${dir}SKILL.md"
	if [ ! -f "$file" ]; then
		fail "skills: $dir has no SKILL.md"
		continue
	fi
	# Frontmatter is the block between the first two `---` lines.
	fm="$(awk '/^---$/{n++; next} n==1' "$file")"
	for key in name description argument-hint; do
		printf '%s\n' "$fm" | grep -qE "^$key:" ||
			fail "skills: $slug: missing '$key' in frontmatter"
	done
	declared="$(printf '%s\n' "$fm" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')"
	[ "$declared" = "$slug" ] ||
		fail "skills: $slug: frontmatter name is '$declared', must match the directory"
done
if [ "$skills_seen" -eq 0 ]; then
	fail "skills: no skill directories under skills/ — this check scanned nothing"
else
	ok "skills: $skills_seen skill(s) carry loadable frontmatter with a matching name"
fi

# --- 4. no skill prescribes gh api -f with an @file value -------------------

skill_docs=''
for f in skills/*/SKILL.md; do
	[ -f "$f" ] || continue
	skill_docs="$skill_docs $f"
done
if [ -z "$skill_docs" ]; then
	fail "gh-api: no SKILL.md files to scan — this check scanned nothing"
elif at_file_hits="$(grep -nE 'gh api.*(-f|--raw-field) +"?[a-z_]+=@' $skill_docs)"; then
	printf '%s\n' "$at_file_hits" | sed 's/^/      /' >&2
	fail "gh-api: a skill prescribes gh api -f with an @file value; use -F, which reads the file"
else
	ok "gh-api: no skill prescribes -f with an @file value"
fi

# --- 5. the shipped example config is one the real reader can consume -------

example='examples/worktree.json'
if [ ! -f "$example" ]; then
	fail "config-example: $example is missing — this check had nothing to validate"
else
	if python3 - "$example" <<'PY'
import json, sys

cfg = json.load(open(sys.argv[1]))
missing = [k for k in ("envFiles", "install", "gate", "scopedCheck") if k not in cfg]
if missing:
    print(f"missing {missing}")
    sys.exit(1)
assert isinstance(cfg["envFiles"], list), "envFiles must be a list"
assert isinstance(cfg.get("env", {}), dict), "env must be an object"
PY
	then
		ok "config-example: $example parses and carries the keys the skills read"
	else
		fail "config-example: $example does not satisfy the shape the skills read"
	fi

	# And prove the real reader agrees, not just a schema guess: run the script's
	# own emit_config and eval what it emits — the same two steps
	# setup-worktree.sh performs. emit_config emits a bash ARRAY assignment, so it
	# is exercised under bash rather than reimplemented here in sh; reimplementing
	# it would recreate the second, drifting copy this file exists to avoid.
	emit_body="$(sed -n '/^emit_config()/,/^}/p' bin/setup-worktree.sh)"
	if [ -z "$emit_body" ]; then
		fail "config-example: emit_config not found in bin/setup-worktree.sh — the reader check scanned nothing"
	else
		reader="$(mktemp)"
		{
			printf '%s\n' '#!/usr/bin/env bash'
			printf '%s\n' 'set -e'
			printf '%s\n' "$emit_body"
			printf '%s\n' 'eval "$(emit_config "$1")"'
			printf '%s\n' '[ -n "$INSTALL_CMD" ] || { echo "reader produced no install command" >&2; exit 1; }'
			printf '%s\n' '[ "${#ENV_FILES[@]}" -gt 0 ] || { echo "reader produced no env files" >&2; exit 1; }'
			printf '%s\n' 'printf "config-example: reader parsed the example: install=%s, %s env file(s)\n" "$INSTALL_CMD" "${#ENV_FILES[@]}"'
		} >"$reader"
		if reader_out="$(bash "$reader" "$example" 2>&1)"; then
			ok "$reader_out"
		else
			printf '%s\n' "$reader_out" | sed 's/^/      /' >&2
			fail "config-example: setup-worktree.sh's own reader could not consume $example"
		fi
		rm -f "$reader"
	fi
fi

# --- 6. bin/*.ps1 lint, or say plainly that they were not linted -------------

ps1_files=''
for f in bin/*.ps1; do
	[ -f "$f" ] || continue
	ps1_files="$ps1_files $f"
done

# One pwsh launch, three outcomes distinguished by exit code — 2 means the module
# is absent (a skip, not a verdict), 1 means it found something, 0 means clean.
# Probing in a separate process first would double a cold pwsh start for no gain.
# Scans the bin directory rather than an interpolated file list: the glob above
# has already asserted the set is non-empty, and bin/ holds nothing else the
# analyzer would read (it only looks at .ps1/.psm1/.psd1).
analyzer_run='if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) { exit 2 }; $found = @(Invoke-ScriptAnalyzer -Path ./bin -Severity Error,Warning); if ($found.Count -gt 0) { $found | Format-List | Out-String -Width 200; exit 1 }; exit 0'

if [ -z "$ps1_files" ]; then
	fail "psscriptanalyzer: no scripts matched bin/*.ps1 — this check scanned nothing"
elif ! command -v pwsh >/dev/null 2>&1; then
	skip "psscriptanalyzer: pwsh not on PATH —$ps1_files were NOT linted here; the check job on ubuntu-latest lints them (it ships pwsh and PSScriptAnalyzer preinstalled)"
else
	analyzer_out="$(pwsh -NoProfile -NonInteractive -Command "$analyzer_run" 2>&1)"
	analyzer_status=$?
	if [ "$analyzer_status" -eq 2 ]; then
		skip "psscriptanalyzer: module not installed —$ps1_files were NOT linted here; the check job on ubuntu-latest ships it preinstalled and lints them there"
	elif [ "$analyzer_status" -eq 0 ]; then
		ok "psscriptanalyzer clean:$ps1_files"
	else
		printf '%s\n' "$analyzer_out" | sed 's/^/      /' >&2
		fail "psscriptanalyzer: problems reported above"
	fi
fi

# --- 7. bin/ ships the same helper in both shells, and the two agree ---------

# Output goes through a temp file rather than a command substitution. A here-doc
# nested inside $( ) is still scanned for quotes by the shell, so a stray
# apostrophe in a Python comment would end the substitution in the wrong place and
# fail the whole script with a syntax error dozens of lines later — a trap worth
# one mktemp to avoid, and the same reason the reader check below uses one.
parity_out="$(mktemp)" || exit 2
python3 - >"$parity_out" 2>&1 <<'PY'
import pathlib
import re

BIN = pathlib.Path("bin")

# The env-var comparison is scoped to the CONTRACT surface: the variables a caller
# passes in, which AGENTS.md freezes and which both implementations therefore have
# to agree on. It is deliberately NOT "every environment variable each side
# happens to touch", because the two shells legitimately need different internal
# plumbing: the bash helpers set MSYS path-translation variables for their child
# processes (MSYS_NO_PATHCONV and friends) that have no PowerShell counterpart at
# all, since PowerShell has no MSYS path form to translate. Demanding identical
# sets would go red on a correct implementation, and the only way to green it
# would be to invent a variable nobody reads - which is exactly the guardrail
# gaming AGENTS.md forbids. Widen this set only by widening the contract.
CONTRACT_ENV = {
    "WORKTREE_HOME", "REPO", "WORKSPACE", "WORKTREE_DEST", "MERGE_PR_FORCE",
}

# A bash script CONSUMES an environment variable by reading it with a fallback:
# ${NAME:-...} and its :=/:?/:+ siblings.
SH_CONSUMED = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*):[-=?+]")
# ... except when the name is only ever assigned a value it did not itself
# contribute. NAME="${NAME:-default}" is the read-with-fallback idiom and stays;
# a plain local that happens to be read with a default is not consumed, and
# neither is a NAME=value prefix that hands a value DOWN to a child process.
SH_ASSIGNED = re.compile(
    r"(?m)^\s*(?:export\s+|local\s+|readonly\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$"
)
# The PowerShell equivalent is any $env:NAME reference ...
PS_ENV = re.compile(r"\$env:([A-Za-z_][A-Za-z0-9_]*)")
# ... minus the ones being ASSIGNED, which the script produces for a child rather
# than consumes from its caller. Both sides are measured the same way.
PS_ASSIGNED = re.compile(r"\$env:([A-Za-z_][A-Za-z0-9_]*)\s*=[^=]")

BLOCK_COMMENT = re.compile(r"(?s)<#.*?#>")


def code_only(text):
    """Strip comments before scanning either dialect.

    Both families explain their interface in prose sitting right next to the
    syntax it describes - the setup-worktree.sh header quotes the literal string
    ${VAR:-$HOME/...} to document the config format, and every header paraphrases
    the CLI. Scanning that prose would invent a variable named VAR, and would let
    a stray "usage:" in a comment shadow the real runtime line, which is the one
    shape of drift this whole check exists to catch.
    """
    text = BLOCK_COMMENT.sub("", text)
    return "\n".join(l for l in text.splitlines() if not l.lstrip().startswith("#"))


def usage_spec(code, name, ext):
    """The argument spec from the script's own runtime `usage:` line.

    Reads CODE, not the raw file, so the header comment cannot stand in for the
    line a user actually sees when they get the invocation wrong.
    """
    needle = "usage: " + name + ext
    for line in code.splitlines():
        idx = line.find(needle)
        if idx < 0:
            continue
        rest = line[idx + len(needle):]
        # Stop at the closing quote the shell or PowerShell wrote, so the trailing
        # redirection of the bash form is not compared against the PowerShell form.
        rest = re.split(r"""["']""", rest, maxsplit=1)[0]
        return " ".join(rest.split())
    return None


def sh_consumed_env(code):
    names = {m.group(1).upper() for m in SH_CONSUMED.finditer(code)}
    self_referential = {}
    for m in SH_ASSIGNED.finditer(code):
        target, value = m.group(1), m.group(2)
        key = target.upper()
        refs_itself = ("$" + target) in value or ("${" + target) in value
        self_referential[key] = self_referential.get(key, False) or refs_itself
    names = {n for n in names if n not in self_referential or self_referential[n]}
    return names & CONTRACT_ENV


def ps_consumed_env(code):
    names = {m.group(1).upper() for m in PS_ENV.finditer(code)}
    names -= {m.group(1).upper() for m in PS_ASSIGNED.finditer(code)}
    return names & CONTRACT_ENV


problems = []

sh_files = {p.stem: p for p in sorted(BIN.glob("*.sh"))}
ps_files = {p.stem: p for p in sorted(BIN.glob("*.ps1"))}

if not sh_files:
    problems.append("no bin/*.sh matched - this check scanned nothing")
if not ps_files:
    problems.append("no bin/*.ps1 matched - this check scanned nothing")

for name in sorted(set(sh_files) - set(ps_files)):
    problems.append(
        f"bin/{name}.sh has no bin/{name}.ps1 sibling - it is missing from PATH "
        "in a PowerShell-tool session, with no error until a user runs it"
    )
for name in sorted(set(ps_files) - set(sh_files)):
    problems.append(
        f"bin/{name}.ps1 has no bin/{name}.sh sibling - it is missing from PATH "
        "in a Bash-tool session, with no error until a user runs it"
    )

for name in sorted(set(sh_files) & set(ps_files)):
    # One read per file: the byte view drives the encoding checks, and the text it
    # decodes to drives both the usage-line and the env-var extraction.
    ps_bytes = ps_files[name].read_bytes()
    ps_code = code_only(ps_bytes.decode("utf-8", errors="replace"))
    sh_code = code_only(sh_files[name].read_text(encoding="utf-8", errors="replace"))

    # Encoding, checked on the bytes rather than on anything already decoded: a
    # .ps1 that is not printable ASCII plus LF is the corruption AGENTS.md names.
    if b"\r" in ps_bytes:
        line = ps_bytes[: ps_bytes.index(b"\r")].count(b"\n") + 1
        problems.append(
            f"bin/{name}.ps1: line {line}: carriage return - .gitattributes pins "
            "*.ps1 to LF, and a CRLF checkout is how a helper dies before it runs"
        )
    # CR is excluded here because the check above already names it precisely; left
    # in, one CRLF checkout would report the same root cause twice.
    bad = [
        (i, b)
        for i, b in enumerate(ps_bytes)
        if b not in (0x0A, 0x0D) and not 0x20 <= b <= 0x7E
    ]
    if bad:
        i, b = bad[0]
        line = ps_bytes[:i].count(b"\n") + 1
        problems.append(
            f"bin/{name}.ps1: line {line}: byte 0x{b:02x} is not printable ASCII "
            f"({len(bad)} such byte(s)) - PowerShell 5.1 reads a BOM-less file as "
            "the system ANSI codepage and reports the resulting parse error "
            "nowhere near this character"
        )
    if ps_bytes and not ps_bytes.endswith(b"\n"):
        problems.append(f"bin/{name}.ps1: no trailing newline - the file is not LF-terminated")

    sh_usage = usage_spec(sh_code, name, ".sh")
    ps_usage = usage_spec(ps_code, name, ".ps1")
    if sh_usage is None:
        problems.append(f"bin/{name}.sh prints no runtime usage line naming {name}.sh - nothing to compare against")
    if ps_usage is None:
        problems.append(f"bin/{name}.ps1 prints no runtime usage line naming {name}.ps1 - nothing to compare against")
    if sh_usage is not None and ps_usage is not None and sh_usage != ps_usage:
        problems.append(
            f"bin/{name}: usage lines disagree - .sh takes [{sh_usage}], "
            f".ps1 takes [{ps_usage}]"
        )

    sh_env = sh_consumed_env(sh_code)
    ps_env = ps_consumed_env(ps_code)
    # Two empty sets compare equal, so a pattern that stopped matching would report
    # perfect agreement. Every helper here reads at least WORKTREE_HOME, so an
    # empty extraction means the scanner broke, not that the pair is clean.
    if not sh_env and not ps_env:
        problems.append(
            f"bin/{name}: neither sibling appears to consume any contract "
            "environment variable - the extraction found nothing, so this pair "
            "was not actually compared"
        )
    elif sh_env != ps_env:
        only_sh = ", ".join(sorted(sh_env - ps_env)) or "-"
        only_ps = ", ".join(sorted(ps_env - sh_env)) or "-"
        problems.append(
            f"bin/{name}: consumed contract env vars disagree - only in .sh: "
            f"{only_sh}; only in .ps1: {only_ps}"
        )

for problem in problems:
    print(problem)
PY
parity_status=$?

if [ "$parity_status" -ne 0 ]; then
	sed 's/^/      /' "$parity_out" >&2
	fail "parity: the reader crashed — bin/ could not be examined"
elif [ -s "$parity_out" ]; then
	while IFS= read -r problem; do
		printf 'FAIL  parity: %s\n' "$problem" >&2
	done <"$parity_out"
	# Counted once here rather than per line: the loop is fed by a redirect, not a
	# pipe, so an increment inside it would survive — but one FAIL per check keeps
	# the tally comparable with every other section above.
	fails=$((fails + 1))
else
	ok "parity: every bin/ helper ships as both .sh and .ps1, with matching usage and env vars"
fi
rm -f "$parity_out"

# --- 8. every skills/<name>/SKILL.md path cited in a tracked doc resolves -----

# The set is what git tracks, not what the glob finds: a scratch note, a gate log
# or a stray copy sitting in a worktree is not a doc this repo ships, and a gate
# that goes red on one is a gate a contributor learns to stop trusting. On a bare
# clone git is present by construction, so this needs nothing installed.
md_files=''
for f in $(git ls-files '*.md' 2>/dev/null); do
	[ -f "$f" ] || continue
	md_files="$md_files $f"
done
if [ -z "$md_files" ]; then
	fail "citations: git listed no tracked *.md files — this check scanned nothing"
else
	cite_hits="$(grep -hoE 'skills/[A-Za-z0-9_-]+/SKILL\.md' $md_files)"
	if [ -z "$cite_hits" ]; then
		fail "citations: no skills/<name>/SKILL.md path matched in any tracked *.md — this check scanned nothing"
	else
		cite_count="$(printf '%s\n' "$cite_hits" | wc -l | tr -d ' ')"
		cited="$(printf '%s\n' "$cite_hits" | sort -u)"
		distinct=0
		dangling=''
		for path in $cited; do
			distinct=$((distinct + 1))
			[ -f "$path" ] || dangling="$dangling $path"
		done
		if [ -n "$dangling" ]; then
			# Every dangling path, and every site citing it, in one run: a rename
			# breaks citations in batches, and reporting the first would cost a gate
			# run per citation to discover the rest. Deduped because one line citing
			# two dead paths is grepped once per path and would otherwise be printed
			# twice, reading as two separate sites.
			for path in $dangling; do
				grep -nF -- "$path" $md_files
			done | sort -u | sed 's/^/      /' >&2
			fail "citations: cited in a tracked doc but absent from the tree:$dangling"
		else
			ok "citations: $cite_count skills/<name>/SKILL.md citation(s) across tracked docs resolve ($distinct distinct path(s))"
		fi
	fi
fi

# --- report ------------------------------------------------------------------

if [ "$fails" -eq 0 ]; then
	printf '\ncheck: ok — scripts lint clean, manifest and skills well-formed, example config reads, bin/ helpers at parity, cross-skill citations resolve\n'
	exit 0
fi
printf '\ncheck: %s failure(s)\n' "$fails" >&2
exit 1
