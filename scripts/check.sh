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
#   2. .claude-plugin/plugin.json parses and carries what Claude Code needs —
#      plus what the SKILLS need, which is not the same set. `claude plugin
#      validate --strict` is the authoritative check and the one the
#      community-marketplace review runs, but it needs the CLI installed and is
#      not reproducible on a bare runner. This covers the failure modes that
#      actually break a published plugin: unparseable JSON, a missing name, and
#      the `author` field whose absence makes --strict fail at submission time.
#      It also covers `repository`, which the loader does not need at all — see
#      the field list below for why it is required here anyway.
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
#      It also asserts one thing about each sibling ALONE, which the comparison
#      cannot: a helper that consumes WORKTREE_HOME reads
#      .agents/workspace.json. Comparing siblings is structurally blind to a
#      SHARED omission — two ports that are identically wrong agree with each
#      other perfectly — and that is exactly how remove-worktree shipped with no
#      workspace branch in either language, resolving a path that never exists
#      for every workspace member, printing "already removed" and exiting 0.
#      A repo inside a workspace keeps its worktrees at
#      $WORKTREE_HOME/<workspace>/<leaf>/<repo> rather than the bare
#      $WORKTREE_HOME/<project>/<leaf>, so a helper that resolves paths under
#      that home and never looks at the marker knows only half the layouts.
#      This stays at the altitude the rest of 7 works at — a token in the
#      comment-stripped source, exactly like the env-var scan — and it makes no
#      claim that the branch it finds is CORRECT, only that the question was
#      asked. That is the honest ceiling here: whether a workspace path is
#      assembled right is semantics, and a checker that judged it would be a
#      second implementation of the thing it checks.
#   8. Every path under skills/ ending in .md that a tracked *.md cites resolves
#      in the tree. The skills point at each other constantly instead of
#      restating each other — two copies of a rule drift and nothing marks which
#      one is stale — so a rename or a deletion leaves a citation pointing at
#      nothing, and a dead path reads exactly as authoritative as a live one.
#      Observed: a dispatch instruction named the wrong skill, survived a rename
#      that swapped two skills' names wholesale, read perfectly across seven
#      releases, and reached two live briefs. Scoped to git-tracked files, so an
#      untracked scratch note or a gate log left in a worktree cannot turn the
#      gate red.
#      It follows the CORPUS rather than enumerating one filename. Scoped to
#      SKILL.md — which is what shipped first — it missed a reference doc cited
#      by path, skills/setup/references/gate-queue.md, which is the same
#      coordinate with the same failure mode and was uncovered while the check
#      read as complete. The character class admits the nested segment instead,
#      so a reference doc added tomorrow is covered the day it is cited rather
#      than the day someone remembers to widen a filename list.
#      The citation shape stays PATH-shaped, and that is the boundary that keeps
#      this check quiet: the pattern is anchored on skills/, so every match names
#      a directory. A BARE filename is deliberately unreachable — this corpus
#      writes README.md and AGENTS.md in running prose constantly, naming no
#      directory and usually not even this repo, so a pattern over those would
#      red the gate on every other project's README mentioned in passing. That
#      is the noisy-check failure below, arriving through the widening instead of
#      through italics.
#      One false positive the nesting does admit, named here so a red on it is a
#      diagnosis rather than a mystery: the match is unanchored on its LEFT, and
#      every sibling repo is named <something>-skills, so a URL of the form
#      github.com/<org>/<x>-skills/blob/main/<doc>.md matches from its own
#      "skills/" onward and reports skills/blob/main/<doc>.md as dangling. No
#      tracked doc carries one today, and the remedy is the house style anyway —
#      a doc in THIS repo is cited by repo-relative path, which is the form this
#      check exists to keep alive. A left-boundary guard was considered and
#      rejected: it costs a second grep stage plus a boundary character class
#      whose every member is a judgement call, to buy a case that has not
#      occurred and that names itself in the failure output when it does.
#      What it does NOT reach, deliberately: only the file-path form. A citation
#      by prose phrase (decompose's Verify field cites "per execute's own note on
#      backgrounding a banned run") and a count duplicated across two sentences
#      ("five items" against "one of the four") go stale identically and are
#      invisible here. Neither is mechanically checkable in this corpus: italics
#      carry emphasis throughout, not just around section names, so a pattern
#      over them is mostly false positives, and a noisy check is one the next
#      author routes around. Both keep the prose rules already pointed at them.
#      The line drawn is the corpus's own — if a checker can tell the reference
#      is stale without reading the sentence, it is a coordinate.
#      Unlike 4 there is no anchor separating a citation from prose SHOWING a
#      dead path, because a dead path is a dead path either way. A doc that needs
#      to display one writes it in the placeholder form the corpus already uses
#      (this comment, or README.md's skills/<slug>/SKILL.md): angle brackets are
#      not a path component, so the pattern does not match and nothing has to be
#      suppressed. The widening preserves that exactly — < is outside the class,
#      so skills/<slug>/ still fails at its first character — which is load-
#      bearing rather than incidental, since this comment and the README both
#      carry the form and a widening that reached it would red the gate on the
#      check's own documentation. No per-line opt-out is offered, since one would
#      be indistinguishable from a real stale citation claiming to be deliberate.
#   9. Every tracker coordinate in shipped prose names the tracker it resolves
#      in. skills/ SHIPS, and is read by agents working inside whatever repo the
#      plugin is installed in — so a bare #123 there resolves against the
#      READER's tracker, where it is some unrelated issue. True for the author,
#      false everywhere it is actually read. That is the failure AGENTS.md's
#      citation convention names for a bare README.md, arriving in a coordinate
#      class check 8 structurally cannot reach: a path either resolves in the
#      tree or it does not, while a number is a valid string in every repo and
#      has nothing to be resolved against. What CAN be checked is whether the
#      prose says WHOSE tracker it is — a token in the source, exactly as 8's
#      paths are — and that is the whole of what this asserts.
#      Two forms clear it, and they are the two the corpus already uses: the
#      qualifier "this repo's own #N", and an attribution naming the owning
#      repository as an `owner/repo` code span sitting immediately before the
#      number (`trinity-ai-labs/trinity` (PR #4798)). Either one anywhere in the
#      PASSAGE clears every coordinate in that passage, deliberately: a worked
#      example carrying three coordinates would otherwise have to repeat the
#      qualifier three times, which is worse prose than the defect it prevents.
#      Code spans and fenced blocks are stripped from the text COORDINATES are
#      read out of, so a worked invocation (`decompose #1042`) is not a citation
#      and never was. They are not stripped from the text the attribution is
#      matched against, because that form puts the repository inside a code span
#      and the number outside it, so one strip would delete the thing being
#      looked for. The PASSAGE is a whole paragraph, or ONE list item within
#      one: a blank-line block cut again at its list markers, with a marker
#      opening a passage and every later line joining it, so a multi-line item
#      stays whole. That last part is load-bearing rather than incidental —
#      decompose's umbrella-disambiguation example carries its qualifier and one
#      of the coordinates it covers nine lines and two code fences apart, inside
#      one item.
#      The item rather than the blank-line block, because the unit has to be the
#      smallest span a reader takes a qualifier as governing, and a bullet run is
#      not that: the qualifier in one bullet has nothing to do with a coordinate
#      in the next. The block unit shipped first and was measured — a bare
#      coordinate injected into a bullet whose SIBLING carried a qualifier came
#      back green, which is exactly the defect this check exists to catch,
#      cleared by a sentence four bullets away. Tightening cost no false
#      positives: all nine live coordinates still pass, and the only one needing
#      more than its own line (decompose's continuation) is covered by its own
#      item.
#      Nesting is deliberately NOT containment: an indented sub-bullet is its own
#      passage, not part of its parent. Treating it as part would reintroduce the
#      same leak one level down, a parent's qualifier clearing every child.
#      Scoped to skills/ because that is what ships. AGENTS.md, README.md and
#      CHANGELOG.md are read only from this checkout, where a bare number is
#      already correct and this rule would be pure noise.
#      The honest ceiling, and it is the same one check 7 states about surface
#      shape: this asserts the question was asked, never that the answer is
#      right. A passage citing two repositories that qualifies only one of
#      them passes, and separating those needs the sentence read.
#      One narrower gap, considered and left open: an UNBALANCED backtick makes
#      the code-span strip pair the wrong two, which can swallow a coordinate
#      and green it. Asserting balance per passage was rejected — no tracked
#      passage is unbalanced today, so it would buy a case that has not
#      occurred, and it would red the gate on a markdown defect that has nothing
#      to do with trackers, under a message about them.
#  10. Tracked prose under skills/ is held to TWO ATTENTION BUDGETS, both
#      measured with `wc -w` over the same file set: no single file over 30,000
#      words, and the CORPUS — the sum across all of them — under a RATCHET.
#      skills/ ships, and a rule only binds the agent that actually reads it —
#      so past some total the corpus stops being a set of rules and becomes a
#      document its reader is compacted out of. That failure is observed rather
#      than theoretical, and it is the one nothing else here can see: no diff
#      contains it, and which rule gets dropped is settled by file size and
#      position rather than by anyone.
#      It is also a property of the TOTAL, which is why the per-file half alone
#      structurally could not see it: every one of the 17 tracked files was
#      green while they summed to 121,280 words — 4x the per-file ceiling — and
#      this check reported ok on that every release, where a green ceiling line
#      is read as headroom.
#      The ratchet is a RATCHET and not a target. It is set to the tree's
#      measured total once a cut has landed, so it only ever moves DOWN, and
#      raising it to fit new prose is the one edit this constant must never
#      receive — guardrail gaming arriving as a one-character diff. Extraction
#      is a remedy for the per-file half ALONE: it moves words between files,
#      and the corpus half counts them wherever they sit.
#      AGENTS.md is the prose that OWNS this rule; this is the half that
#      enforces it, and the two are a pair that has to be changed together. Both
#      numbers and the instrument are copied from there deliberately rather than
#      parsed out of it — a scanner over that bullet would make a reword change
#      what the gate enforces, silently — and the same house pattern check 7
#      uses for the contract env vars it borrows from the same file. **The unit
#      is the part that has to match, not just the number**: bytes, lines and
#      characters are all plausible readings of "how long is this file", they
#      all disagree with `wc -w`, and picking a different one leaves BOTH halves
#      green while the pair says two different things. So: `wc -w`, tracked
#      files under skills/, 30,000 per file and the ratchet across them.
#      It reports BOTH numbers on success, not just a verdict — the largest file
#      with its count, and the corpus total against the ratchet. A ceiling check
#      that prints only "ok" tells an author nothing about how much room is
#      left, which is the number they need before adding prose; and the corpus
#      total is the number a green per-file line was being read as vouching for.
#      What it does NOT do: judge whether an extraction was the RIGHT one. Which
#      bodies may move behind a pointer is the discriminator AGENTS.md states,
#      and it turns on TWO tests, both of which need the prose read: whether a
#      reader would NOTICE the absence, and whether that reader reaches the body
#      on the HAPPY PATH. An error-path body fails the second however cleanly it
#      passes the first, so extracting one is not a way back under this ceiling.
#      A green here means the file is small enough, never that splitting it was
#      done well; that judgement stays with the diff, which in a prose repo is
#      the only review there is.
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
for field in ("name", "description", "author", "version", "license", "repository"):
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

# --- 9. every tracker coordinate in shipped prose names its repository --------

# Only skills/ ships, so only skills/ is scanned — a bare #N in a contributor doc
# is read from this checkout and already resolves. Tracked files for the same
# reason check 8 gives: a scratch note left in a worktree is not prose this repo
# ships, and a gate that reds on one is a gate a contributor stops trusting.
skill_prose=''
for f in $(git ls-files 'skills/*.md' 2>/dev/null); do
	[ -f "$f" ] || continue
	skill_prose="$skill_prose $f"
done
if [ -z "$skill_prose" ]; then
	fail "tracker-citations: git listed no tracked *.md under skills/ — this check scanned nothing"
else
	# A temp file rather than $( ), for the reason check 7 gives: a here-doc nested
	# inside a command substitution is still scanned for quotes, and the qualifier
	# this scanner looks for is spelled with an apostrophe in it.
	tracker_out="$(mktemp)" || exit 2
	python3 - $skill_prose >"$tracker_out" 2>&1 <<'PY'
import pathlib
import re
import sys

# A tracker coordinate. Anchored on the digit, so `<pkg>#test` and a markdown
# heading are both out of reach without needing a rule of their own.
CITATION = re.compile(r"#[0-9]+")
# The two forms the corpus uses to say whose tracker it is. The qualifier is a
# fixed house phrase rather than a family of paraphrases: the check has to be
# predictable enough that an author can satisfy it on the first try, and the
# failure message below names the exact wording.
QUALIFIER = re.compile(r"this repo(?:sitory)?'s own", re.IGNORECASE)
# The attribution is deliberately ADJACENT rather than paragraph-wide, which the
# qualifier is not. An owner/repo slug is the shape of half the paths in this
# corpus - `scripts/check.sh`, `examples/worktree.json`, `bin/setup-worktree.sh`
# - so a paragraph-wide match on that shape would green almost anything and the
# check would assert nothing. Requiring the slug to sit immediately before the
# number is what separates naming a repository from mentioning a file, and it is
# how the corpus already writes it. Backticks are required for the same reason:
# unquoted, `2>/dev/null` and `release/x.y.z` are slugs too.
ATTRIBUTION = re.compile(
    r"`[A-Za-z0-9][A-Za-z0-9._-]*/[A-Za-z0-9][A-Za-z0-9._-]*`[^#`]{0,24}#[0-9]+"
)
CODE_SPAN = re.compile(r"`[^`]*`")
FENCE = re.compile(r"^[ \t]*(?:```|~~~)")
# A list marker, which is where a blank-line block is cut into passages. The
# trailing \s is what keeps prose out: `*The failure this prevents` opens an
# italic run and `3.19.0 shipped` opens a sentence, and neither is a bullet.
MARKER = re.compile(r"^[ \t]*(?:[-*+]|[0-9]+\.)\s")

problems = []
coordinates = 0
passages = 0

for name in sys.argv[1:]:
    text = pathlib.Path(name).read_text(encoding="utf-8", errors="replace")
    # Fenced lines are emptied rather than dropped, so a fence sitting inside a
    # list item neither splits that item nor opens a new one - an emptied line
    # matches no marker, so it joins whatever passage it is already in.
    fenced = False
    lines = []
    for number, raw in enumerate(text.splitlines(), 1):
        blank = not raw.strip()
        if FENCE.match(raw):
            fenced = not fenced
            lines.append((number, blank, ""))
            continue
        lines.append((number, blank, "" if fenced else raw))
    if fenced:
        # An unclosed fence swallows the rest of the file, and a scan that saw
        # nothing prints the same green as one that found nothing wrong.
        problems.append(
            f"{name}: ends inside an unclosed code fence - everything after it "
            "was skipped, so this file was not actually scanned"
        )

    blocks = []
    current = []
    for entry in lines:
        if entry[1]:
            if current:
                blocks.append(current)
                current = []
        else:
            current.append(entry)
    if current:
        blocks.append(current)

    # Then cut each block at its list markers. The passage - a whole paragraph,
    # or ONE list item within one - is the span a qualifier is taken to govern,
    # and a bullet run is not that: a qualifier in one bullet has nothing to do
    # with a coordinate in the next. A marker opens a passage and every later
    # line joins it, so a multi-line item stays whole - which decompose's
    # umbrella-disambiguation example needs, its qualifier and one of the
    # coordinates it covers being nine lines and two code fences apart. Lines
    # before a block's first marker are a passage of their own.
    passages_in_block = []
    for block in blocks:
        current = []
        for entry in block:
            if MARKER.match(entry[2]) and current:
                passages_in_block.append(current)
                current = []
            current.append(entry)
        if current:
            passages_in_block.append(current)

    for block in passages_in_block:
        joined = " ".join(line for _, _, line in block)
        # Citations are read from the code-span-stripped text and attributions
        # from the raw text, because the attributed form puts the repository
        # INSIDE a code span and the number outside it. One strip would lose the
        # thing being looked for.
        prose = CODE_SPAN.sub(" ", joined)
        hits = CITATION.findall(prose)
        if not hits:
            continue
        passages += 1
        coordinates += len(hits)
        if QUALIFIER.search(prose) or ATTRIBUTION.search(joined):
            continue
        sites = ", ".join(
            f"{name}:{number}"
            for number, _, line in block
            if CITATION.search(CODE_SPAN.sub(" ", line))
        )
        problems.append(
            f"{sites}: {' '.join(hits)} names no repository - a bare coordinate "
            "resolves against the READER's tracker, where it is some unrelated "
            "issue. Write it as \"this repo's own #N\", or attribute it as "
            "`owner/repo` immediately before the number."
        )

if coordinates == 0:
    problems.append(
        "no #<number> matched in any tracked skills/ doc - the pattern found "
        "nothing, so this check scanned nothing"
    )

# Counts first, on one line, so the shell can report what was examined without
# re-deriving it: a green naming no total is indistinguishable from a green over
# an empty scan.
print(f"{coordinates} {passages} {len(problems)}")
for problem in problems:
    print(problem)
PY
	tracker_status=$?
	tracker_coords=''
	tracker_passages=''
	tracker_problems=''
	{ read -r tracker_coords tracker_passages tracker_problems; } <"$tracker_out"
	if [ "$tracker_status" -ne 0 ] || [ -z "$tracker_problems" ]; then
		sed 's/^/      /' "$tracker_out" >&2
		fail "tracker-citations: the scanner crashed — shipped prose could not be examined"
	elif [ "$tracker_problems" -gt 0 ]; then
		# Each problem printed as its own line rather than summarised, because they
		# are not all the same failure: a bare coordinate, an unclosed fence that
		# hid the rest of a file, and a pattern that matched nothing at all each
		# need naming as themselves. One summary sentence would have to pick one
		# and misdescribe the others.
		sed -n '2,$p' "$tracker_out" | while IFS= read -r problem; do
			printf 'FAIL  tracker-citations: %s\n' "$problem" >&2
		done
		# Counted here rather than in the loop above: a `while` fed by a pipe runs
		# in a subshell, so an increment inside it is discarded and the script
		# would exit 0 having just printed failures.
		fails=$((fails + 1))
	else
		ok "tracker-citations: $tracker_coords coordinate(s) across $tracker_passages passage(s) in shipped prose name the tracker they resolve in"
	fi
	rm -f "$tracker_out"
fi

# --- 10. skills/ within the per-file ceiling AND the corpus ratchet ----------

# The per-file ceiling and the instrument AGENTS.md states. Changing either here
# without changing it there leaves the two halves of one rule disagreeing, with
# both of them green — see the note at 10 above for why the unit matters as much
# as the number.
budget=30000

# The corpus-wide ceiling: the SUM of the same measurement over the same file
# set. It is a RATCHET — lowered to the tree's measured total once a cut has
# landed, never raised to fit new prose — so a change that adds net words to
# skills/ goes red here even while every individual file stays comfortably under
# the per-file number. The arc driving it down is this repo's own #298, whose
# end state is under 40,000.
corpus_ratchet=53658

# Tracked files under skills/, for the reason checks 8 and 9 both give: skills/
# is what ships, and a scratch note or a gate log left in a worktree is not prose
# this repo ships.
budget_files=''
for f in $(git ls-files 'skills/*.md' 2>/dev/null); do
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
	budget_total=0
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
		# The same measurement the per-file half tests, behind the same guards:
		# an unmeasurable file has already `continue`d, so it is missing from
		# this sum exactly as it is from the count — and it fails the check on
		# its own, so a short sum is never what a green rests on.
		budget_total=$((budget_total + words))
		if [ "$words" -gt "$budget_largest" ]; then
			budget_largest="$words"
			budget_largest_file="$f"
		fi
		[ "$words" -le "$budget" ] || budget_over="$budget_over $f($words)"
	done
	# Three independent verdicts rather than a chain, for the reason stated at the
	# top of this file: an unmeasurable file and an over-budget file are different
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
		# remedy relocates words the corpus half counts wherever they sit.
		fail "attention-budget: over the ${budget}-word PER-FILE ceiling (wc -w):$budget_over — extract a whole role or subsystem body its reader reaches on the happy path, or delete, to make room; an error-path body stays inline however cleanly it separates. AGENTS.md carries both tests. Extraction settles this half only: the corpus ratchet counts the same words wherever they sit"
		budget_clean=0
	fi
	if [ "$budget_total" -gt "$corpus_ratchet" ]; then
		fail "attention-budget: the corpus is $budget_total words (wc -w across $budget_counted tracked skills/ file(s)), over the ${corpus_ratchet}-word ratchet — DELETE prose; extraction moves words between files and leaves this total untouched. The ratchet only ever moves down: lower it to the tree's new total once a cut has landed, never raise it to fit"
		budget_clean=0
	fi
	if [ "$budget_clean" -eq 1 ]; then
		ok "attention-budget: $budget_counted tracked skills/ file(s) within the ${budget}-word per-file ceiling (wc -w; largest $budget_largest_file at $budget_largest); corpus $budget_total against the ${corpus_ratchet}-word ratchet"
	fi
fi

# --- report ------------------------------------------------------------------

if [ "$fails" -eq 0 ]; then
	printf '\ncheck: ok — scripts lint clean, manifest and skills well-formed, example config reads, bin/ helpers at parity, cross-skill citations resolve, tracker coordinates name their repository, shipped prose within the per-file ceiling and the corpus ratchet\n'
	exit 0
fi
printf '\ncheck: %s failure(s)\n' "$fails" >&2
exit 1
