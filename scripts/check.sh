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

# A missing tool must not read as green, and it cannot be reported per-check
# either — a check that never ran has nothing to say. Refuse up front instead.
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

# --- report ------------------------------------------------------------------

if [ "$fails" -eq 0 ]; then
	printf '\ncheck: ok — scripts lint clean, manifest and skills well-formed, example config reads\n'
	exit 0
fi
printf '\ncheck: %s failure(s)\n' "$fails" >&2
exit 1
