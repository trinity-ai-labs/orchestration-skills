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
#   1. bin/*.sh and scripts/*.sh lint clean at their declared dialect.
#   2. both plugin manifests parse, carry their host's required fields, and
#      agree on version (Claude Code and Codex each read their own).
#   3. every skill has the frontmatter Claude Code dispatches on.
#   4. no skill prescribes `gh api -f` with an @file value (it stores the
#      literal string and exits 0 — the one failure here that looks like success).
#   5. examples/worktree.json is one the real reader can consume.
#   6. bin/*.ps1 lint, or SKIP loudly — never a silent ok.
#   7. bin/ ships each helper in both shells and the two agree on surface facts.
#   8. every skills/ .md path cited in a tracked doc resolves.
#   9. shipped prose carries no issue numbers.
#  10. skills/ within the per-file ceiling AND the per-sub-skill ceiling.
#  11. shipped prose carries no war stories.
#  12. no skill cites another skill — the glossary excepted.
#  13. no sentence has had its front removed (a partial prose deletion).
#  14. the glossary stays tied to the tree.
#  15. both bin/ ports answer the predicates they share identically.
#
# Checks 9, 11 and 12 exist together and guard one thing: a skill must be
# actionable without opening anything else. 10 bounds what one agent loads;
# these three stop that load growing the SHAPE that got it there — narrative,
# then citations of narrative, then conventions for writing those citations.

set -u

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
skip() {
	printf 'SKIP  %s\n' "$1"
}

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

# --- 2. BOTH plugin manifests parse, carry what their host needs, and agree ---

# This plugin installs on two hosts, and each reads its own manifest: Claude Code
# reads .claude-plugin/plugin.json, Codex reads .codex-plugin/plugin.json. The
# skills/ tree is shared, so the manifests are the only per-host files, and the
# version is the one field both must agree on — an install is pinned to that
# string, so two manifests carrying different versions ship two different
# releases under one tag, and nothing else here would notice.
cc_manifest='.claude-plugin/plugin.json'
codex_manifest='.codex-plugin/plugin.json'
if [ ! -f "$cc_manifest" ] || [ ! -f "$codex_manifest" ]; then
	fail "manifest: $cc_manifest and $codex_manifest must BOTH be present — this check had nothing to validate"
else
	manifest_problems="$(
		python3 - "$cc_manifest" "$codex_manifest" <<'PY'
import json, pathlib, sys

def load(path):
    try:
        payload = json.loads(pathlib.Path(path).read_text())
    except ValueError as err:
        print(f"{path}: does not parse as JSON: {err}")
        return None
    if not isinstance(payload, dict):
        print(f"{path}: is not a JSON object")
        return None
    return payload

cc_path, codex_path = sys.argv[1], sys.argv[2]
cc, codex = load(cc_path), load(codex_path)

# repository is NOT here because Claude Code needs it to load the plugin — it does
# not. It is here because skills/orchestrate/SKILL.md section 7 resolves the filing
# target for a close-out finding from this field, in a rule whose whole point is
# that the target is never guessed or remembered; the same section compares the
# same field against the origin to decide whether that finding crosses a repo
# boundary. Drop the field and both resolve to nothing, silently: a manifest
# without repository is still a well-formed manifest, so every other signal stays
# green. That is exactly how it would come to be absent, which is why this sits on
# the list rather than in a commit message — the next reader tidying away a field
# the loader does not need is who it is written for.
#
# Keep quote characters BALANCED in here, this comment included. The heredoc body
# sits inside a $(...) substitution, and sh tracks quoting across the whole of it
# while looking for the closing paren — so one stray apostrophe in a comment reads
# as an unterminated string, and the gate dies with a syntax error at end of file,
# hundreds of lines below the character that caused it. CI runs this the same way,
# nested one substitution deeper.
if cc is not None:
    for field in ("name", "description", "author", "version", "license", "repository"):
        if not cc.get(field):
            print(f"{cc_path}: missing '{field}'")

# Codex rejects any top-level key outside this allowlist and refuses to ingest the
# plugin — so a field copied across from the Claude manifest out of symmetry
# (schema, displayName) is not a harmless extra, it is a failed install. The list
# mirrors the allowed_keys set in the Codex plugin validator.
CODEX_ALLOWED = {
    "id", "name", "version", "description", "skills", "apps", "mcpServers",
    "interface", "author", "homepage", "repository", "license", "keywords",
}
if codex is not None:
    for key in sorted(set(codex) - CODEX_ALLOWED):
        print(f"{codex_path}: top-level key '{key}' is not accepted by Codex")
    for field in ("name", "version", "description"):
        if not codex.get(field):
            print(f"{codex_path}: missing '{field}'")
    author = codex.get("author")
    if not isinstance(author, dict) or not author.get("name"):
        print(f"{codex_path}: missing 'author.name'")
    interface = codex.get("interface")
    if not isinstance(interface, dict):
        print(f"{codex_path}: missing 'interface' object")
    else:
        for field in ("displayName", "shortDescription", "longDescription",
                      "developerName", "category"):
            value = interface.get(field)
            if not isinstance(value, str) or not value.strip():
                print(f"{codex_path}: interface.{field} must be a non-empty string")
        caps = interface.get("capabilities")
        if not isinstance(caps, list) or not caps or not all(
            isinstance(v, str) and v.strip() for v in caps
        ):
            print(f"{codex_path}: interface.capabilities must be an array of strings")
        prompts = interface.get("defaultPrompt")
        if not isinstance(prompts, list) or not prompts or not all(
            isinstance(v, str) and v.strip() for v in prompts
        ):
            print(f"{codex_path}: interface.defaultPrompt must be an array of strings")
        else:
            if len(prompts) > 3:
                print(f"{codex_path}: interface.defaultPrompt takes at most 3 entries")
            for v in prompts:
                if len(v) > 128:
                    print(f"{codex_path}: interface.defaultPrompt entry over 128 chars")

# The agreement. Read as strings, because a version is a string everywhere it is
# consumed, and compared only once both parsed — an unparseable manifest has
# already been reported and has no version to disagree with.
if cc is not None and codex is not None:
    cc_version, codex_version = cc.get("version"), codex.get("version")
    if cc_version and codex_version and cc_version != codex_version:
        print(
            f"version mismatch: {cc_path} is {cc_version} but {codex_path} is "
            f"{codex_version} -- both hosts pin an install to this string, so they "
            "move together or one host ships the wrong release"
        )
PY
	)" || {
		fail "manifest: the reader crashed — the manifests could not be examined"
		manifest_problems=''
	}
	if [ -n "$manifest_problems" ]; then
		printf '%s\n' "$manifest_problems" | while IFS= read -r problem; do
			printf 'FAIL  manifest: %s\n' "$problem" >&2
		done
		# Counted here rather than in the loop above: a `while` fed by a pipe runs
		# in a subshell, so an increment inside it is discarded and the script
		# would exit 0 having just printed failures.
		fails=$((fails + 1))
	else
		ok "manifest: $cc_manifest and $codex_manifest each carry every required field, and agree on version"
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

# Every tracked .md under skills/, not just the spines: the gh api prose this
# check exists for now lives in references/ (decompose's emitting.md), and a
# check scoped to SKILL.md would go green over the passage it was written for.
skill_docs="$(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null | tr '\n' ' ')"
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

# The marker that says a containing folder of sibling repos is a WORKSPACE, and
# therefore that its members' worktrees live at
# $WORKTREE_HOME/<workspace>/<leaf>/<repo> rather than $WORKTREE_HOME/<project>/<leaf>.
# A helper that resolves paths under the worktree home and never reads this knows
# only one of the two layouts - which is not a drift between siblings but a gap in
# both at once, the one shape the comparison below cannot see.
WORKSPACE_MARKER = ".agents/workspace.json"

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

    # Per-sibling, not a comparison: the shared omission the comparison cannot see.
    for ext, env, code in ((".sh", sh_env, sh_code), (".ps1", ps_env, ps_code)):
        if "WORKTREE_HOME" in env and WORKSPACE_MARKER not in code:
            problems.append(
                f"bin/{name}{ext}: resolves paths under WORKTREE_HOME but never "
                f"reads {WORKSPACE_MARKER} - a repo inside a workspace keeps its "
                "worktrees at $WORKTREE_HOME/<workspace>/<leaf>/<repo>, so a helper "
                "that knows only the bare $WORKTREE_HOME/<project>/<leaf> resolves a "
                "path that never exists for every workspace member. Both siblings "
                "missing it agree with each other perfectly, which is why this is "
                "checked per file rather than between them."
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

# --- 8. every skills/ .md path cited in a tracked doc resolves ----------------

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
	# The class carries / so the path may nest — skills/<slug>/SKILL.md and
	# skills/<slug>/references/<doc>.md are one pattern, not two. It carries
	# neither < nor >, which is what keeps the placeholder form the corpus writes
	# for a deliberately dangling example out of the match; and the literal
	# skills/ prefix is what keeps a bare README.md in prose out of it.
	cite_hits="$(grep -hoE 'skills/[A-Za-z0-9_/-]+\.md' $md_files)"
	if [ -z "$cite_hits" ]; then
		fail "citations: no skills/ .md path matched in any tracked *.md — this check scanned nothing"
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
			ok "citations: $cite_count skills/ .md path citation(s) across tracked docs resolve ($distinct distinct path(s))"
		fi
	fi
fi

# --- 9. shipped prose carries no issue numbers ------------------------------

# A `#123` in a skill sends the reader to a tracker mid-task: obeyed it derails
# the run, ignored it leaves them acting on a rule they do not understand. The
# war story and its link both live in the PR that made the change.

tracker_files="$(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null || true)"
if [ -z "$tracker_files" ]; then
	fail "tracker-citations: git listed no tracked *.md under skills/ — this check scanned nothing"
else
	# Code spans and fenced blocks are stripped first: a `#1` in a command or a
	# colour literal is not a tracker coordinate.
	tracker_hits="$(
		for f in $tracker_files; do
			sed -e '/^```/,/^```/d' -e 's/`[^`]*`//g' "$f" |
				grep -nE '(^|[^A-Za-z0-9_&])#[0-9]+([^0-9]|$)' | sed "s|^|$f:|"
		done
	)"
	if [ -n "$tracker_hits" ]; then
		printf '%s\n' "$tracker_hits" | while IFS= read -r l; do printf 'FAIL  no-issue-numbers: %s\n' "$l" >&2; done
		fail "no-issue-numbers: move the reference, and the reasoning behind it, into the PR that makes the change"
	else
		ok "no-issue-numbers: $(printf '%s\n' $tracker_files | wc -l | tr -d ' ') shipped file(s) carry none"
	fi
fi

# --- 10. skills/ within the per-file AND per-sub-skill ceilings --------------

# The per-file ceiling and the instrument AGENTS.md states. Changing either here
# without changing it there leaves the two halves of one rule disagreeing, with
# both of them green — see the note at 10 above for why the unit matters as much
# as the number.
budget=30000

# The per-sub-skill ceiling: the SUM of the same measurement over one
# skills/<slug>/ tree — a spine plus its own references, which is what one agent
# loads, and the growth the per-file half misses when a sub-skill gains files
# rather than grows one. AGENTS.md states this one too, with the same
# both-green disagreement available. Both are BACKSTOPS, not budgets — the
# largest sub-skill today sits a little over half of this number, so they catch
# runaway growth rather than ration prose. There is deliberately no corpus-wide
# ceiling: prose behind a pointer costs a reader nothing until it is followed,
# so the corpus total is a quantity no reader ever pays.
budget_per_skill=50000

# Tracked files under skills/, for the reason checks 8 and 9 both give: skills/
# is what ships, and a scratch note or a gate log left in a worktree is not prose
# this repo ships. `--others --exclude-standard` adds files not yet staged: a new
# skill is exactly what these ceilings exist to weigh, and it would otherwise be
# invisible until `git add` — a false green on the run an author actually reads.
budget_files=''
for f in $(git ls-files --cached --others --exclude-standard 'skills/*.md' 2>/dev/null | sort -u); do
	[ -f "$f" ] || continue
	budget_files="$budget_files $f"
done
if [ -z "$budget_files" ]; then
	fail "attention-budget: git listed no tracked *.md under skills/ — this check scanned nothing"
else
	budget_counted=0
	budget_over=''
	budget_largest=0
	budget_largest_file=''
	budget_broke=''
	budget_slugs=''
	budget_pairs=''
	for f in $budget_files; do
		# wc's OWN exit status, captured before anything else touches the value:
		# the substitution runs wc alone, so a failure here is wc's and not some
		# later formatting step's. A file that could not be measured is a failure
		# in its own right — an unmeasured file prints the same green as a small
		# one.
		if ! budget_raw="$(wc -w <"$f")"; then
			budget_broke="$budget_broke $f"
			continue
		fi
		# wc pads its output on some platforms and not others; strip the padding
		# so `test -gt` is comparing an integer. Nothing is asserted on this
		# pipeline's status — the measurement already succeeded above.
		words="$(printf '%s' "$budget_raw" | tr -d '[:space:]')"
		# A measurement that is not a number is an unmeasured file, not a small
		# one. Without this, `test` errors on the empty string and the file is
		# reported with a blank count — a confusing red where the honest answer
		# is that this file was never actually compared against anything.
		case $words in
		'' | *[!0-9]*)
			budget_broke="$budget_broke $f"
			continue
			;;
		esac
		budget_counted=$((budget_counted + 1))
		# Group by the path's second segment: skills/<slug>/ is one sub-skill.
		# Recorded as a slug:words pair and summed after the loop, because POSIX
		# sh has no arrays to hold one running total per slug. An unmeasurable
		# file has already `continue`d, so it is missing from these pairs exactly
		# as it is from the count — and it fails the check in its own right, so a
		# short sum is never what a green rests on.
		budget_slug="${f#skills/}"
		budget_slug="${budget_slug%%/*}"
		budget_pairs="$budget_pairs $budget_slug:$words"
		case " $budget_slugs " in
		*" $budget_slug "*) ;;
		*) budget_slugs="$budget_slugs $budget_slug" ;;
		esac
		if [ "$words" -gt "$budget_largest" ]; then
			budget_largest="$words"
			budget_largest_file="$f"
		fi
		[ "$words" -le "$budget" ] || budget_over="$budget_over $f($words)"
	done
	# One total per sub-skill, from the pairs recorded above. Every measured file
	# contributed exactly one pair and every pair's slug is in this list, so the
	# grouping cannot silently drop a file, sum short, and still read as green.
	budget_skill_over=''
	budget_skill_report=''
	for budget_slug in $budget_slugs; do
		budget_skill_words=0
		for budget_pair in $budget_pairs; do
			case $budget_pair in
			"$budget_slug":*)
				budget_pair_words="${budget_pair#*:}"
				budget_skill_words=$((budget_skill_words + budget_pair_words))
				;;
			esac
		done
		budget_skill_report="$budget_skill_report $budget_slug($budget_skill_words)"
		[ "$budget_skill_words" -le "$budget_per_skill" ] ||
			budget_skill_over="$budget_skill_over $budget_slug($budget_skill_words)"
	done
	# Four independent verdicts rather than a chain, for the reason stated at the
	# top of this file: an unmeasurable file and an over-ceiling file are different
	# failures, and an `elif` would report the first and hide the second in the one
	# run where both are true.
	budget_clean=1
	if [ -n "$budget_broke" ]; then
		fail "attention-budget: could not be measured, so these files were NOT checked:$budget_broke"
		budget_clean=0
	fi
	if [ "$budget_counted" -eq 0 ]; then
		fail "attention-budget: no tracked skills/ file was measured — this check scanned nothing"
		budget_clean=0
	fi
	if [ -n "$budget_over" ]; then
		# Named with its count, so the author can see how far over it is rather
		# than only that it is: the remedy is to extract or delete to make room,
		# and how much room is the first thing they need. It also says which
		# half extraction settles, since a reader who takes it as the whole
		# remedy relocates words the sub-skill half counts wherever they sit.
		fail "attention-budget: over the ${budget}-word PER-FILE ceiling (wc -w):$budget_over — extract a whole role or subsystem body its reader reaches on the happy path, or delete, to make room; an error-path body stays inline however cleanly it separates. AGENTS.md carries both tests. Extraction settles this half only: the per-sub-skill ceiling counts the same words wherever they sit inside skills/<slug>/"
		budget_clean=0
	fi
	if [ -n "$budget_skill_over" ]; then
		fail "attention-budget: over the ${budget_per_skill}-word PER-SUB-SKILL ceiling (wc -w summed over skills/<slug>/):$budget_skill_over — a sub-skill is one spine plus its own references, so extraction inside it moves nothing: split a whole pass out of it, or delete. AGENTS.md carries both ceilings"
		budget_clean=0
	fi
	if [ "$budget_clean" -eq 1 ]; then
		ok "attention-budget: $budget_counted tracked skills/ file(s) within the ${budget}-word per-file ceiling (wc -w; largest $budget_largest_file at $budget_largest), and each sub-skill within the ${budget_per_skill}-word ceiling:$budget_skill_report"
	fi
fi

# --- 11. shipped prose carries no war stories -------------------------------

# The incident that motivated a rule belongs in the PR that fixed it, where it
# stays attached to the diff. In a skill it is words a reader cannot act on, and
# this corpus once carried 22,451 of them.
#
# Matched per PARAGRAPH, not per line. `git grep` is line-oriented and shipped
# prose here is hard-wrapped, so a banned phrase routinely straddles the break
# an editor happened to choose — skills/review/SKILL.md once carried a live
# instance split as "The failure" / "this prevents:" across a newline, invisible
# to a single-line grep while the check reported green. Each paragraph (lines
# separated by a blank line — where hard-wrapping in this corpus actually stops)
# is folded to single-space-joined tokens before matching, so the phrase reads
# the same whether or not an editor wrapped it. The reported line is recovered
# from the matched token's own original line, never guessed: a match spanning a
# wrap is reported at the line the match STARTS on, exactly as a single-line
# match already was.

story_files="$(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null || true)"
if [ -z "$story_files" ]; then
	fail "no-war-stories: git listed no tracked *.md under skills/ — this check scanned nothing"
else
	story_hits_out="$(mktemp)" || exit 2
	story_broken_out="$(mktemp)" || exit 2
	story_err_out="$(mktemp)" || exit 2
	python3 - "$story_hits_out" "$story_broken_out" $story_files <<'PY' 2>"$story_err_out"
import bisect
import re
import sys

PATTERN = re.compile(
    r"The failure this prevents|[Oo]bserved (on|in one|twice|three times|across|while dispatching)"
)


def paragraphs(text):
    """Runs of consecutive non-blank lines, as [(line_no, line_text), ...].

    A blank line is where hard-wrapping stops in this corpus, so it is also
    where a wrap-spanning search stops: joining across it would match words
    that were never actually adjacent on an editor's screen.
    """
    para = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        if line.strip():
            para.append((line_no, line))
        elif para:
            yield para
            para = []
    if para:
        yield para


hits_path, broken_path, *files = sys.argv[1:]
with open(hits_path, "w") as hits_f, open(broken_path, "w") as broken_f:
    for path in files:
        try:
            text = open(path, encoding="utf-8").read()
        except (OSError, UnicodeDecodeError) as err:
            broken_f.write(f"{path}: could not be read: {err}\n")
            continue
        for para in paragraphs(text):
            # Whitespace-delimited tokens, each carrying the line it came from,
            # rejoined with a single space. A run of leading spaces on an
            # indented continuation line collapses the same as a bare newline
            # does — both are "the wrap", and the pattern requires exactly one
            # space between words either way.
            tokens = [(tok, ln) for ln, line in para for tok in line.split()]
            pieces, starts, pos = [], [], 0
            for tok, _ in tokens:
                starts.append(pos)
                pieces.append(tok)
                pos += len(tok) + 1
            norm = " ".join(pieces)
            for m in PATTERN.finditer(norm):
                # The token whose span covers the match's start: bisect finds
                # the last token starting at or before it.
                idx = bisect.bisect_right(starts, m.start()) - 1
                line_no = tokens[idx][1]
                hits_f.write(f"{path}:{line_no}: {m.group(0)!r}\n")
PY
	story_status=$?
	if [ "$story_status" -ne 0 ]; then
		sed 's/^/      /' "$story_err_out" >&2
		fail "no-war-stories: the reader crashed — shipped prose could not be examined"
	else
		story_clean=1
		if [ -s "$story_broken_out" ]; then
			sed 's/^/      /' "$story_broken_out" >&2
			fail "no-war-stories: could not be read, so these files were NOT checked — see above"
			story_clean=0
		fi
		# Derived rather than round-tripped through the reader: every file in
		# $story_files ends up either scanned or in story_broken_out, never both
		# and never neither, so the difference is exact.
		story_total="$(printf '%s\n' $story_files | wc -l | tr -d ' ')"
		story_broken_count="$(wc -l <"$story_broken_out" | tr -d ' ')"
		story_scanned=$((story_total - story_broken_count))
		if [ "$story_scanned" -le 0 ]; then
			fail "no-war-stories: no tracked skills/ file could be read — this check scanned nothing"
			story_clean=0
		fi
		if [ -s "$story_hits_out" ]; then
			sed 's/^/FAIL  no-war-stories: /' "$story_hits_out" >&2
			fail "no-war-stories: state the rule; put the incident in the PR that makes the change"
			story_clean=0
		fi
		if [ "$story_clean" -eq 1 ]; then
			ok "no-war-stories: $story_scanned shipped file(s) state rules, not incidents"
		fi
	fi
	rm -f "$story_hits_out" "$story_broken_out" "$story_err_out"
fi

# --- 12. no skill cites another skill, the concept map excepted --------------

# A spine pointing at its own references is the shape working. A skill reaching
# into ANOTHER skill to explain itself is not finished: state what your reader
# needs where they act. Unbounded cross-skill citation is what grew a
# 96-reference web, a checker for it, and a convention for writing it.
#
# skills/glossary/ is the one permitted target, and it is a different edge
# rather than a hole in this one. An entry there is a DEFINITION — what a thing
# is — which every pass needs identically and none of them owns, so the copies
# drift with nothing able to make them agree. A RULE is the opposite: it is what
# one stance does about that thing, it differs per stance, and it is restated
# where its reader acts. So the map is cited and never cites back: the ban still
# holds in the direction that grew the web, and an entry reaching into a pass
# fails this check exactly as any other cross-skill citation does.

cross_hits="$(
	for f in $(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null); do
		own="$(printf '%s' "$f" | cut -d/ -f2)"
		grep -oE '`skills/[a-z-]+/[^`]*\.md`' "$f" 2>/dev/null | tr -d '`' | while IFS= read -r p; do
			tgt="$(printf '%s' "$p" | cut -d/ -f2)"
			# Own references: the shape working. The concept map: the one other
			# legal target, and only as a target — a file INSIDE the map whose own
			# slug is `concepts` cites nothing else and still fails here.
			[ "$tgt" = "$own" ] || [ "$tgt" = glossary ] || printf '%s: %s\n' "$f" "$p"
		done
	done
)"
if [ -n "$cross_hits" ]; then
	printf '%s\n' "$cross_hits" | while IFS= read -r l; do printf 'FAIL  no-cross-skill-citations: %s\n' "$l" >&2; done
	fail "no-cross-skill-citations: restate the rule where its reader acts, or drop it — only skills/glossary/ may be cited across skills, and only for a DEFINITION"
else
	ok "no-cross-skill-citations: every skill is readable on its own, citing only its own references and the glossary"
fi

# --- 13. no sentence has had its front removed --------------------------------

# Check 11 bans a war story by its OPENING words, so a pass that strips the
# opening and leaves the rest passes it — and what survives is a sentence
# starting mid-clause, which reads as damage a reader routes around rather than
# as a rule. Two of them sat green in this corpus for four releases.
#
# The tell is mechanical: in markdown an emphasis run opens after whitespace, so
# `*` glued to the end of the preceding word means the text that used to sit in
# front of it is gone. Anchored on that, not on any phrase, because the phrase
# is exactly what the deletion took.

orphan_hits="$(
	git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null \
		| while IFS= read -r f; do
			grep -nE '[A-Za-z0-9][.,;:!?]\*[A-Za-z]' "$f" 2>/dev/null \
				| sed "s|^|$f:|"
		done
)"
if [ -n "$orphan_hits" ]; then
	printf '%s\n' "$orphan_hits" | cut -c1-160 | while IFS= read -r l; do
		printf 'FAIL  no-half-deleted-prose: %s\n' "$l" >&2
	done
	fail "no-half-deleted-prose: an emphasis run opens mid-word — finish the deletion, keeping any RULE the removed sentence carried"
else
	orphan_n="$(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null | wc -l | tr -d ' ')"
	ok "no-half-deleted-prose: $orphan_n shipped file(s) carry no sentence whose front was removed"
fi

# --- 14. the glossary stays tied to the tree -------------------------------

# A map of definitions treats drift, so a map that has itself gone stale is the
# disease one level up: an entry nobody cites, or a definition nobody can find,
# reads exactly like a live one. Three properties, each mechanical.
#
#   findable  every entry has a row in the index. check 8 catches a row pointing
#             at a missing entry; the reverse is silent, so it is checked here.
#   used      every entry is cited by at least one pass. An entry nothing points
#             at is prose no reader reaches, which is what the map exists to stop.
#   a definition, not an instruction
#             an entry never ADDRESSES the reader. "you"/"your" is the mechanical
#             tell: a definition describes a thing, an instruction addresses a
#             person, and an entry that starts instructing has become a stance
#             nobody acting will read. Banning modal words instead does not work
#             -- "decided by dependency, never by understanding" is a fact, and a
#             check that reds on it would be turned off within a week.
#
# NOT checked, deliberately: whether a term is defined somewhere OUTSIDE the map.
# Every instrument tried for it reds on legitimate USE -- a pass naming four slice
# fields is using them, not redefining them -- and a guard that fails correct work
# is one everybody learns to wave through.

map_dir=skills/glossary
map_index="$map_dir/SKILL.md"
if [ ! -f "$map_index" ]; then
	fail "glossary: $map_index is missing — the map's index is what every pointer resolves through"
else
	map_entries="$(git ls-files "$map_dir/vocabulary/*.md" "$map_dir/mechanics/*.md" 2>/dev/null || true)"
	if [ -z "$map_entries" ]; then
		fail "glossary: no tracked entries under $map_dir/vocabulary or $map_dir/mechanics — this check scanned nothing"
	else
		map_problems=''
		map_n=0
		for e in $map_entries; do
			map_n=$((map_n + 1))
			grep -qF "$e" "$map_index" || map_problems="$map_problems
$e: no row in the index — unfindable for a reader who cannot already name it"
			# Cited by a pass: any tracked skills/ file outside the map itself.
			cited=$(git ls-files 'skills/*.md' 'skills/**/*.md' 2>/dev/null \
				| grep -v "^$map_dir/" \
				| while IFS= read -r f; do grep -qF "$e" "$f" && echo x; done | wc -l | tr -d ' ')
			[ "${cited:-0}" -gt 0 ] || map_problems="$map_problems
$e: cited by no pass — an entry nothing points at is prose no reader reaches"
			if grep -qniE '\b(you|your|yours)\b' "$e"; then
				map_problems="$map_problems
$e: addresses the reader — an entry carries a definition, and what to DO about it belongs to the stance that acts"
			fi
			# Naming another entry's term without linking to it is how a second,
			# drifting definition starts. The term set is DERIVED from the entry
			# filenames rather than listed here, so it grows with the glossary and
			# cannot go stale against it. Both spellings, since prose hyphenates.
			for other in $map_entries; do
				[ "$other" = "$e" ] && continue
				term_slug="$(basename "$other" .md)"
				term_words="$(printf '%s' "$term_slug" | tr '-' ' ')"
				if grep -qiF "$term_words" "$e" || grep -qiF "$term_slug" "$e"; then
					grep -qF "$other" "$e" || map_problems="$map_problems
$e: names '$term_words' without linking $other — an unlinked mention is where a second definition starts"
				fi
			done
		done
		if [ -n "$map_problems" ]; then
			printf '%s\n' "$map_problems" | while IFS= read -r l; do
				[ -n "$l" ] && printf 'FAIL  glossary: %s\n' "$l" >&2
			done
			fail "glossary: an entry must be indexed, cited, and free of instruction"
		else
			ok "glossary: $map_n entr(y/ies) each indexed, cited by a pass, and stating a definition rather than an instruction"
		fi
	fi
fi

# --- 15. the two ports answer the shared predicates the same way -------------

# The parity check above reads SURFACE: a sibling exists, the usage lines match,
# the contract env vars match, the .ps1 is ASCII. It makes no claim about what the
# two implementations DO, and cannot: comparing behaviour needs the behaviour run.
# So a predicate written twice can diverge and stay green on everything else, and
# the divergence surfaces as the same PR merging differently depending on which
# shell the user's platform handed them.
#
# One table, asked of both. Extraction is by function name and a MISSING function
# is a failure rather than a skip: renaming one silently is exactly how the pair
# would stop being compared while this check kept reporting ok.

pc_cases=scripts/port-cases/squash-boundary.tsv
pc_sh=bin/merge-pr.sh
pc_ps1=bin/merge-pr.ps1

if [ ! -f "$pc_cases" ]; then
	fail "port-cases: $pc_cases is missing — the shared table is what makes this a comparison"
elif [ "$(grep -cv '^#' "$pc_cases" || true)" -lt 1 ]; then
	# A table gutted to comments answers every comparison with silence, and silence
	# compares equal to silence. That is the vacuous pass this check exists to deny.
	fail "port-cases: $pc_cases holds no cases — an empty table agrees with itself"
else
	pc_n=$(grep -cv '^#' "$pc_cases" || true)
	pc_tmp="$(mktemp -d)" || exit 2

	python3 - "$pc_sh" "$pc_ps1" "$pc_tmp" <<'PY'
import re, sys
sh_path, ps1_path, out = sys.argv[1], sys.argv[2], sys.argv[3]
src = open(sh_path, encoding="utf-8").read()
i = src.find("squash_boundary_ok() {")
j = src.find("\n}\n", i)
if i < 0 or j < 0:
    sys.exit("squash_boundary_ok not found in " + sh_path)
open(out + "/fn.sh", "w", encoding="utf-8").write(src[i:j + 3])
src = open(ps1_path, encoding="utf-8").read()
i = src.find("function Test-SquashBoundary {")
j = src.find("\n}\n", i)
if i < 0 or j < 0:
    sys.exit("Test-SquashBoundary not found in " + ps1_path)
open(out + "/fn.ps1", "w", encoding="utf-8").write(src[i:j + 3])
PY
	pc_extract=$?

	if [ "$pc_extract" -ne 0 ]; then
		fail "port-cases: could not extract both predicates — a rename leaves the pair uncompared while this check still reports ok"
	else
		# bash side
		{
			echo "set -u"
			echo ". $pc_tmp/fn.sh"
			echo 'while IFS="	" read -r i h b d e; do'
			echo '  case "$i" in "#"*) continue ;; esac'
			echo '  [ "$i" = - ] && i=""; [ "$b" = - ] && b=""; [ "$d" = - ] && d=""; [ "$h" = - ] && h=""'
			echo '  if squash_boundary_ok "$i" "$h" "$b" "$d"; then g=squash; else g=merge; fi'
			echo '  printf "%s\t%s\n" "$e" "$g"'
			echo "done < $pc_cases"
		} > "$pc_tmp/run.sh"
		bash "$pc_tmp/run.sh" > "$pc_tmp/out.sh" 2>"$pc_tmp/err.sh" || true

		pc_bad="$(awk -F'\t' '$1 != $2 { print "    row " NR ": bash said " $2 ", the table says " $1 }' "$pc_tmp/out.sh")"
		pc_rows=$(grep -c . "$pc_tmp/out.sh" || true)

		if [ "$pc_rows" != "$pc_n" ]; then
			fail "port-cases: bash answered $pc_rows of $pc_n case(s) — the driver did not read the whole table"
		elif [ -n "$pc_bad" ]; then
			printf '%s\n' "$pc_bad" >&2
			fail "port-cases: bin/merge-pr.sh disagrees with the table"
		elif ! command -v pwsh >/dev/null 2>&1; then
			skip "port-cases: bash agrees with all $pc_n case(s), but pwsh is not on PATH so bin/merge-pr.ps1 was NOT compared here; the check job on ubuntu-latest ships pwsh and does compare it"
		else
			# Quoted heredoc: the driver is PowerShell, and an unquoted one lets the
			# shell expand $line and $f before pwsh ever sees them. Paths arrive as
			# arguments for the same reason.
			cat > "$pc_tmp/run.ps1" <<'PS'
param([string] $Fn, [string] $Cases)
. $Fn
foreach ($line in Get-Content $Cases) {
    if ($line.StartsWith('#')) { continue }
    $f = $line -split "`t"
    $v = @('', '', '', '')
    for ($k = 0; $k -lt 4; $k++) { if ($f[$k] -ne '-') { $v[$k] = $f[$k] } }
    $verdict = if (Test-SquashBoundary -IntegrationBranch $v[0] -Head $v[1] -Base $v[2] -DefaultBranch $v[3]) { 'squash' } else { 'merge' }
    "$($f[4])`t$verdict"
}
PS
			pwsh -NoProfile -NonInteractive -File "$pc_tmp/run.ps1" "$pc_tmp/fn.ps1" "$pc_cases" > "$pc_tmp/out.ps1" 2>"$pc_tmp/err.ps1" || true
			pc_prows=$(grep -c . "$pc_tmp/out.ps1" || true)
			if [ "$pc_prows" != "$pc_n" ]; then
				sed 's/^/      /' "$pc_tmp/err.ps1" >&2
				fail "port-cases: pwsh answered $pc_prows of $pc_n case(s) — the driver did not read the whole table"
			else
				pc_pbad="$(awk -F'\t' '$1 != $2 { print "    row " NR ": pwsh said " $2 ", the table says " $1 }' "$pc_tmp/out.ps1")"
				pc_diff="$(paste "$pc_tmp/out.sh" "$pc_tmp/out.ps1" | awk -F'\t' '$2 != $4 { print "    row " NR ": bash said " $2 ", pwsh said " $4 }')"
				if [ -n "$pc_pbad" ]; then
					printf '%s\n' "$pc_pbad" >&2
					fail "port-cases: bin/merge-pr.ps1 disagrees with the table"
				elif [ -n "$pc_diff" ]; then
					printf '%s\n' "$pc_diff" >&2
					fail "port-cases: the two ports disagree — surface parity cannot see this"
				else
					ok "port-cases: both ports answer all $pc_n shared case(s) identically, and as the table says"
				fi
			fi
		fi
	fi
	rm -rf "$pc_tmp"
fi

# --- report ------------------------------------------------------------------

if [ "$fails" -eq 0 ]; then
	printf '\ncheck: ok — scripts lint clean, manifest and skills well-formed, example config reads, bin/ helpers at parity, skills/ paths resolve, and shipped prose is within budget and free of issue numbers, war stories, cross-skill citations and half-deleted sentences, the glossary is tied to the tree, and the two bin/ ports answer their shared predicates identically\n'
	exit 0
fi
printf '\ncheck: %s failure(s)\n' "$fails" >&2
exit 1
