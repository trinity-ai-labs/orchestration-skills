# GitHub writes — `gh-post`

Entry in `skills/procedures/SKILL.md`. **How this flow comments on an issue or PR, posts a review, closes an
issue and links a sub-issue: one helper call, safe to re-run.** Read it before you make any of those writes.
**Which key a write carries, and when it is made, differs by seat and is written where each seat acts.**

## The call

`gh-post.sh` ships in this plugin's `bin/` beside the worktree helpers; **whether it resolves as a bare command
or needs an absolute path, and which extension, is `skills/procedures/host-tools.md`'s.** Run it from anywhere
inside the target repo, or prefix `REPO=/path/to/repo`.

```sh
gh-post.sh comment <issue|pr> <n> --key <key> --body-file <file>
gh-post.sh review <pr-n> --key <key> --body-file <file>
gh-post.sh close <issue-n> --reason <completed|not_planned> [--key <key> --body-file <file>]
gh-post.sh sub-issue <parent-n> <child-n>
```

- **The body travels as a FILE you write first** — `--body-file -` (stdin) is refused as bad usage. The helper
  sends it with `-F`, so the `-f` trap in `skills/glossary/mechanics/gh-api-file-body.md` cannot reach it.
- **The key names the party and the purpose of the post**, from `a-z A-Z 0-9 . _ / : -` — a slash-separated
  path such as `<purpose>/<pr>/<sha>`. The helper appends `<!-- pipeline:<key> -->` as the body's last line and
  treats as its own only a post whose LAST non-blank line is exactly that marker, found across every comment
  or review on the target — never by author, position or recency, since every party writes as the one `gh`
  account. **So the same key edits one post in place, and a different key is a different post**: put in the
  key whatever must stay separate (a round, a head SHA), and leave out whatever must not. A `<leaf>` in a key
  is the branch leaf (`skills/glossary/mechanics/branch-leaf.md`), so every write about one slice derives the
  same one.
- **`review` writes the review BODY only, with event `COMMENT`**, and a re-run edits that body in place. A
  review that threads findings on lines, or carries `APPROVE` or `REQUEST_CHANGES`, is outside its kinds.
- **`close` with `--key` posts or updates its closing comment first, then closes** with the reason.
- **`sub-issue` makes the native link** (`skills/glossary/mechanics/sub-issue-link.md`), resolving the child's
  database id itself. A child already under a different parent exits `1` and is never re-parented.

## What it prints, and what to verify

**Stdout is one line per call** — `close` with a comment prints two, the comment's first and the state's
second:

| Line | Means |
|---|---|
| `POSTED: <url>` | a new post or link was made |
| `UPDATED: <url>` | the post carrying this key was edited in place, or the close was written |
| `DECLINED: <reason>` | nothing to do (already linked, already closed with that reason) — an answer, never an error |

**Exit `0` on any of the three, `1` on a failed `gh` or `git` call, `2` on bad usage** — including a number
naming the wrong kind of thing, a PR where an issue was asked for or the reverse. Each line prints the moment
its write exists, so a `1` after a `POSTED:` line means the comment landed and the follow-up did not. **Keep
the URL it prints**: it is the link to the post, and needs no refetch to find.

**Issue CREATION, BODY edits, a review with inline comments or another event, and any write to a repository
with no local checkout to run it from are not among what it does** —
they stay raw `gh api` calls, with the body sent by `skills/glossary/mechanics/gh-api-file-body.md`'s rule, and
nothing makes them safe to re-run.
