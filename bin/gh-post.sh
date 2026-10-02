#!/usr/bin/env bash
# Make one of this flow's GitHub writes once, safely re-runnable, without ever
# touching a post another party made.
#
#   gh-post.sh comment  <issue|pr> <n>  --key <key> --body-file <file>
#   gh-post.sh review   <pr-n>          --key <key> --body-file <file>
#   gh-post.sh close    <issue-n>       --reason <completed|not_planned> [--key <key> --body-file <file>]
#   gh-post.sh sub-issue <parent-n> <child-n>
#
# Run it from ANYWHERE inside the target repo (or set REPO=). Every gh call runs
# from that repo's MAIN checkout, so `{owner}/{repo}` resolves to it.
#
# Why a marker, and why never the author. Every party in this flow - dispatcher,
# implementer, review pass, gate - writes as the SAME ambient `gh` account, so
# `author.login` cannot tell one party's post from another's, and position or
# recency picks whichever party happened to write last. What identifies a post is
# the hidden marker `<!-- pipeline:<key> -->` appended to its body, built from a
# key the caller chooses to name the party and the purpose
# (`gate-verdict/<leaf>`, `dispatcher-grant/<leaf>`). Before writing, the helper
# pages through ALL the comments (or reviews) on the target looking for that exact
# marker; a key that merely shares a prefix does not match, because the marker's
# closing ` -->` follows the key directly.
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
# Exit: 0 on any of the four answers; 1 on a failed gh or git call, with a
# helper-owned message on stderr; 2 on bad usage (including a number that names
# the wrong kind of thing - a PR where an issue was asked for, or the reverse).
set -euo pipefail

norm_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

die() { printf 'gh-post: error: %b\n' "$*" >&2; exit 1; }

usage() {
  [ $# -eq 0 ] || printf 'gh-post: %s\n' "$*" >&2
  echo "usage: gh-post.sh comment <issue|pr> <n> --key <key> --body-file <file>" >&2
  echo "       gh-post.sh review <pr-n> --key <key> --body-file <file>" >&2
  echo "       gh-post.sh close <issue-n> --reason <completed|not_planned> [--key <key> --body-file <file>]" >&2
  echo "       gh-post.sh sub-issue <parent-n> <child-n>" >&2
  echo "  prints POSTED: <url>, UPDATED: <url> or DECLINED: <reason>, each on its own line" >&2
  echo "  run from inside the target repo, or set REPO=/path/to/repo" >&2
  exit 2
}

# --- Pure predicates ---------------------------------------------------------
# Each is answered by BOTH ports against scripts/port-cases/gh-post-*.tsv, so a
# rename here is a red gate rather than a silently uncompared pair.

# The hidden marker for a key.
#   build_marker <key>
build_marker() {
  printf '<!-- pipeline:%s -->' "$1"
}

# Does a body carry exactly this key's marker? A literal substring test, case
# sensitive: `gate/x` does not match a body marked `gate/x-retry`, since the
# marker's ` -->` must follow the key immediately.
#   marker_matches <body> <key>
marker_matches() {
  case "$1" in
  *"$(build_marker "$2")"*) return 0 ;;
  *) return 1 ;;
  esac
}

# Which kind an argument vector asks for, or `usage` when it is not a valid call.
# Purely syntactic: no file is read and nothing is fetched. Prints one word.
#   arg_kind <arg>...
arg_kind() {
  local kind="${1:-}" key="" body="" reason="" have_key=0 have_body=0 have_reason=0 npos a
  local -a pos=()
  [ $# -gt 0 ] && shift
  case "$kind" in
  comment) npos=2 ;;
  review | close) npos=1 ;;
  sub-issue) npos=2 ;;
  *) echo usage; return 0 ;;
  esac
  while [ $# -gt 0 ]; do
    a="$1"
    case "$a" in
    --key | --body-file | --reason)
      [ $# -ge 2 ] || { echo usage; return 0; }
      case "$a" in
      --key) [ "$have_key" = 0 ] || { echo usage; return 0; }; have_key=1; key="$2" ;;
      --body-file) [ "$have_body" = 0 ] || { echo usage; return 0; }; have_body=1; body="$2" ;;
      --reason) [ "$have_reason" = 0 ] || { echo usage; return 0; }; have_reason=1; reason="$2" ;;
      esac
      shift 2
      ;;
    -*) echo usage; return 0 ;;
    *) pos+=("$a"); shift ;;
    esac
  done
  [ "${#pos[@]}" -eq "$npos" ] || { echo usage; return 0; }
  # Every number is a positive decimal with no leading zero. The comment kind's
  # first positional is the target type, so its number is the second.
  local first=0
  if [ "$kind" = comment ]; then
    case "${pos[0]}" in issue | pr) ;; *) echo usage; return 0 ;; esac
    first=1
  fi
  local i
  for ((i = first; i < npos; i++)); do
    case "${pos[$i]}" in
    '' | 0* | *[!0123456789]*) echo usage; return 0 ;;
    esac
  done
  if [ "$kind" = sub-issue ] && [ "${pos[0]}" = "${pos[1]}" ]; then
    echo usage; return 0
  fi
  case "$kind" in
  comment | review)
    [ "$have_key" = 1 ] && [ "$have_body" = 1 ] && [ "$have_reason" = 0 ] || { echo usage; return 0; }
    ;;
  close)
    [ "$have_reason" = 1 ] && [ "$have_key" = "$have_body" ] || { echo usage; return 0; }
    case "$reason" in completed | not_planned) ;; *) echo usage; return 0 ;; esac
    ;;
  sub-issue)
    [ "$have_key$have_body$have_reason" = 000 ] || { echo usage; return 0; }
    ;;
  esac
  # A key is what goes inside an HTML comment, so it is held to a closed ASCII
  # set: no space, no `>` (which could close the comment early), nothing a locale
  # could widen. The set is spelled out rather than written as ranges because a
  # bracket range follows the locale's collation in bash.
  if [ "$have_key" = 1 ]; then
    case "$key" in
    '' | *[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/:-]*) echo usage; return 0 ;;
    esac
  fi
  [ "$have_body" = 0 ] || [ -n "$body" ] || { echo usage; return 0; }
  echo "$kind"
}

# --- Arguments -----------------------------------------------------------------

KIND=$(arg_kind "$@")
[ "$KIND" != usage ] || usage

shift
POS=()
KEY="" BODY_FILE="" REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
  --key) KEY="$2"; shift 2 ;;
  --body-file) BODY_FILE="$2"; shift 2 ;;
  --reason) REASON="$2"; shift 2 ;;
  *) POS+=("$1"); shift ;;
  esac
done

if [ -n "$BODY_FILE" ]; then
  [ -f "$BODY_FILE" ] || usage "body file not found: $BODY_FILE"
fi

REPO="${REPO:-$PWD}"

command -v gh >/dev/null 2>&1 || die "gh (GitHub CLI) not found on PATH"

# Resolve the MAIN working tree - same logic as the other helpers.
if ! COMMON=$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
  die "not inside a git repo: $REPO\n  run from inside the target repo, or set REPO=/path/to/repo"
fi
COMMON=$(norm_path "$COMMON")
MAIN=$(dirname "$COMMON")

TMP_DIR=$(mktemp -d) || die "could not create a temp directory"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- gh ----------------------------------------------------------------------

# One REST call, from the MAIN checkout, its stdout in GH_OUT - or exit 1 with a
# message naming the helper. Into a variable rather than onto stdout because
# `exit` inside a command substitution only leaves the subshell.
GH_OUT=""
gh_api() { # gh_api <what-for> <gh-api-arg>...
  local what="$1" status=0
  shift
  GH_OUT=$(cd "$MAIN" && gh api "$@") || status=$?
  [ "$status" -eq 0 ] || die "$what failed (gh exit $status)"
}

# `issue` or `pr` for a number, so a call naming the wrong kind is refused as bad
# usage before anything is written. One read also carries the state the close
# kind needs. No jq expression here carries a string literal: Windows PowerShell
# 5.1 strips embedded double quotes from a native command's arguments, and the
# sibling port passes these same expressions; @tsv prints a null as empty. The possibly-empty field rides LAST: a tab is IFS whitespace, so
# `read` collapses an empty field in the middle and shifts every one after it.
target_type() { # target_type <n> - sets TARGET_TYPE, TARGET_STATE, TARGET_API, TARGET_REASON
  gh_api "reading #$1" "repos/{owner}/{repo}/issues/$1" \
    --jq '[(.pull_request != null), .state, .url, .state_reason] | @tsv'
  local is_pr
  IFS=$'\t' read -r is_pr TARGET_STATE TARGET_API TARGET_REASON <<<"$GH_OUT"
  if [ "$is_pr" = true ]; then TARGET_TYPE="pr"; else TARGET_TYPE="issue"; fi
}

kind_word() { if [ "$1" = issue ]; then echo "an issue"; else echo "a pull request"; fi; }

require_type() { # require_type <n> <issue|pr>
  target_type "$1"
  [ "$TARGET_TYPE" = "$2" ] || usage "#$1 is $(kind_word "$TARGET_TYPE"), not $(kind_word "$2")"
}

# The body as posted: the caller's file with the marker appended, unless the file
# already carries it (a re-run handed back the body it wrote last time).
MARKED=""
marked_body() {
  local body marker
  body=$(cat "$BODY_FILE") || die "could not read $BODY_FILE"
  marker=$(build_marker "$KEY")
  MARKED="$TMP_DIR/body.md"
  if marker_matches "$body" "$KEY"; then
    printf '%s\n' "$body" >"$MARKED"
  else
    printf '%s\n\n%s\n' "$body" "$marker" >"$MARKED"
  fi
}

# The first post on a listing endpoint carrying this key's marker. Every page is
# read: a marker on page two is still ours to update, and missing it is exactly
# the duplicate this helper exists to prevent. Bodies travel base64-encoded so a
# newline or a tab inside one cannot break the row apart.
FOUND_ID="" FOUND_URL=""
find_marked() { # find_marked <what-for> <list-endpoint>
  local id url b64 body
  FOUND_ID="" FOUND_URL=""
  gh_api "$1" --paginate "$2" --jq '.[] | [.id, .html_url, (.body | values | @base64)] | @tsv'
  while IFS=$'\t' read -r id url b64; do
    [ -n "$id" ] || continue
    body=$(printf '%s' "$b64" | base64 --decode) || die "could not decode a body from $2"
    if marker_matches "$body" "$KEY"; then
      FOUND_ID="$id" FOUND_URL="$url"
      return 0
    fi
  done <<<"$GH_OUT"
}

post_comment() { # post_comment <n>
  marked_body
  find_marked "listing the comments on #$1" "repos/{owner}/{repo}/issues/$1/comments"
  if [ -n "$FOUND_ID" ]; then
    gh_api "editing comment $FOUND_URL" -X PATCH "repos/{owner}/{repo}/issues/comments/$FOUND_ID" \
      -F "body=@$MARKED" --jq .html_url
    echo "UPDATED: $GH_OUT"
  else
    gh_api "commenting on #$1" -X POST "repos/{owner}/{repo}/issues/$1/comments" \
      -F "body=@$MARKED" --jq .html_url
    echo "POSTED: $GH_OUT"
  fi
}

# --- The four kinds --------------------------------------------------------------

case "$KIND" in
comment)
  require_type "${POS[1]}" "${POS[0]}"
  post_comment "${POS[1]}"
  ;;
review)
  N="${POS[0]}"
  require_type "$N" pr
  marked_body
  find_marked "listing the reviews on PR #$N" "repos/{owner}/{repo}/pulls/$N/reviews"
  if [ -n "$FOUND_ID" ]; then
    gh_api "editing review $FOUND_URL" -X PUT "repos/{owner}/{repo}/pulls/$N/reviews/$FOUND_ID" \
      -F "body=@$MARKED" --jq .html_url
    echo "UPDATED: $GH_OUT"
  else
    gh_api "posting a review on PR #$N" -X POST "repos/{owner}/{repo}/pulls/$N/reviews" \
      -f event=COMMENT -F "body=@$MARKED" --jq .html_url
    echo "POSTED: $GH_OUT"
  fi
  ;;
close)
  N="${POS[0]}"
  require_type "$N" issue
  # The closing comment first, so its URL is on stdout before the state change
  # that can still fail.
  [ -z "$KEY" ] || post_comment "$N"
  if [ "$TARGET_STATE" = closed ] && [ "$TARGET_REASON" = "$REASON" ]; then
    echo "DECLINED: #$N is already closed as $REASON"
  else
    gh_api "closing #$N as $REASON" -X PATCH "repos/{owner}/{repo}/issues/$N" \
      -f state=closed -f "state_reason=$REASON" --jq .html_url
    echo "UPDATED: $GH_OUT"
  fi
  ;;
sub-issue)
  PARENT="${POS[0]}" CHILD="${POS[1]}"
  require_type "$PARENT" issue
  PARENT_API="$TARGET_API"
  gh_api "reading #$CHILD" "repos/{owner}/{repo}/issues/$CHILD" \
    --jq '[(.pull_request != null), .id, .parent_issue_url] | @tsv'
  IFS=$'\t' read -r CHILD_IS_PR CHILD_ID CHILD_PARENT <<<"$GH_OUT"
  [ "$CHILD_IS_PR" = false ] || usage "#$CHILD is a pull request, not an issue"
  if [ "$CHILD_PARENT" = "$PARENT_API" ]; then
    echo "DECLINED: #$CHILD is already a sub-issue of #$PARENT"
  elif [ -n "$CHILD_PARENT" ]; then
    # Another parent's link is another party's decision; re-parenting it is not
    # this helper's call.
    die "#$CHILD is already a sub-issue of $CHILD_PARENT - not re-parenting it under #$PARENT"
  else
    gh_api "linking #$CHILD under #$PARENT" -X POST "repos/{owner}/{repo}/issues/$PARENT/sub_issues" \
      -F "sub_issue_id=$CHILD_ID" --jq .html_url
    echo "POSTED: $GH_OUT"
  fi
  ;;
esac
