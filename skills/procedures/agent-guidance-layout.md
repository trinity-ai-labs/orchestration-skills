# The agent guidance layout — reading it, checking its shape, placing a line, splitting a monolith

Entry in `skills/procedures/SKILL.md`. **Four procedures over one layout** — router, rule chapter, pointer and
monolith are defined in `skills/glossary/vocabulary/agent-guidance.md`, and every step below uses those words
in exactly that sense. The steps are the same whoever runs them.

**Nothing here says when to run one or what to do with the answer.** Whether a monolith is reported, split or
added to differs by seat and is written where each seat acts.

## Reading the guidance for a piece of work

1. **Name every directory the work touches**, down to the deepest one holding a file it changes.
2. **Read each one's router chain, up to the root** — every `AGENTS.md` from that directory to the repository
   root, taking from each its *Always* rules and its *Commands*. A directory with no router of its own is
   governed by the nearest one above it.
3. **Open only the chapters those routers route the work to** — the rows of each *Rules by topic* table whose
   topic the work is on — and no other chapter.
4. **A monolith is read whole.** Its rules are not routed, so the part that bears on the work cannot be told
   from the part that does not until all of it has been read.

In a workspace, the workspace-level `AGENTS.md` beside `.agents/workspace.json` is the top of every member's
chain.

## Checking the shape

1. **List the guidance files**, untracked ones included since an agent reads the working tree:
   `git ls-files --cached --others --exclude-standard | grep -E '(^|/)(AGENTS|CLAUDE)\.md$|(^|/)\.agents/rules/[^/]+\.md$'`.
   None listed, or only pointer lines with no `AGENTS.md` beside them, is absent guidance, which is not a
   monolith, and the check ends there.
2. **Each `CLAUDE.md`**: exactly the pointer line, or holding content — the third mark.
3. **Each router**: beyond its opening sentences, *Always*, *Commands*, topic table and links, does it carry
   rules true only for some changes in its directory — a topic table cell holding rule prose rather than a
   topic and its link included? Those are topic rules inline — the first mark.
4. **Each router and chapter**: does any passage describe the code rather than set an expectation for it — a
   stack list, a schema, route or module inventory, an architecture narrative? The second mark.
5. **Across the set**: is any rule stated in two files, however differently worded? The fourth mark.
6. **The verdict names each mark found with its file**, and a count of the files the monolith spans. One mark
   is a monolith; length is never read.

In a workspace, run it inside each member, then run steps 2 to 5 on the workspace-level `AGENTS.md` and
`CLAUDE.md` beside `.agents/workspace.json` by their paths — the workspace root is not a repository, so step
1 cannot list them — and count a rule stated both there and in a member as the fourth mark.

## Placing a line — the guidance test, in order

Run it before adding, moving or changing any line of guidance, and stop at the first answer that places it.

1. **Is it an expectation the code cannot teach?** No → it goes nowhere; an agent reads it off the code.
2. **Does it hold for every change in the lowest directory containing every change it governs?** Yes → that
   directory's router, under *Always*, or under *Commands* where it is one. No → the one chapter for its topic
   in that directory's `.agents/rules/`, creating the chapter, and its row in that router's topic table, where
   neither exists yet.
3. **Is it already stated?** Yes → edit it where it stands and link to it from here; never a second statement.
4. **Does any of it describe the code?** That part never goes in, whatever the answers above.

**There is no line or word cap.** A file stays lean because every line in it passed this test, and a line
that fails it comes out however short the file is.

A `CLAUDE.md` holding content is reduced to the pointer line, with each line of what it held run through the
test like any other.

## Splitting a monolith

1. **Check the shape** (above) and keep the verdict: every mark is something the split must remove.
2. **Name the routers**: one `AGENTS.md` per directory that carries guidance — the root, and each package or
   subtree whose changes share rules the rest of the repository does not.
3. **Run every line of the existing guidance through the guidance test.** A line failing its first question,
   and the part of a line failing its fourth, is removed rather than moved — list each removal in the change.
4. **Write each chapter** from the lines the test sent to it, one file per topic under that directory's
   `.agents/rules/`.
5. **Write each router**: its opening sentences, *Always*, *Commands*, a *Rules by topic* row per chapter
   beside it, links down to package routers from the root and one link up from each package.
6. **Collapse every rule stated twice** to the one statement the test places, and replace the other with a link.
7. **Reduce every `CLAUDE.md` to the pointer line.**
8. **Verify**: every link resolves; rerun *Checking the shape* and it finds no mark; and every rule the old
   guidance stated is either findable in the new layout or listed as removed.
