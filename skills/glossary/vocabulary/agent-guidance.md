# agent guidance — router, rule chapter, pointer, monolith

**Agent guidance** is the prose a project keeps for the agents working in it: the expectations its code cannot
teach. Laid out for progressive disclosure it is three kinds of file, and an agent working in one directory on
one topic needs the routers above it and one chapter.

A **router** is the `AGENTS.md` at a directory that carries guidance. It holds one or two sentences on what the
directory is; an *Always* section — the rules true for every change in that directory; *Commands*; a *Rules by
topic* table linking into that directory's own `.agents/rules/`; and links along the tree — down to each
package's router from the root, one link up from a package. A directory's **router chain** is its own router,
where it has one, and every router above it up to the root.

A **rule chapter** is `.agents/rules/<topic>.md` beside a router: the rules and conventions for one topic, and
nothing else. The router's topic table is the way in, so a chapter is read when the work is on its topic and
not otherwise.

A **pointer** is a `CLAUDE.md` holding exactly the one line `See [AGENTS.md](AGENTS.md).` — present so a host
that loads `CLAUDE.md` by name reaches the router beside it, and carrying no content of its own.

**In this layout each rule is stated in exactly one file**, and every other place it bears on links there.
**A description of the code is not guidance at all** — a stack list, a schema, route or module inventory, an
architecture narrative belongs to the code and the project's technical docs, and a copy of it in guidance goes
stale with nothing comparing the two. No router and no chapter holds one.

A **monolith** is guidance that departs from this layout, and it is recognised by SHAPE, never by size. Any one
of four marks makes one: **topic rules written inline in a router** rather than in a chapter it routes to;
**a description of the code in a router or a chapter**; **a `CLAUDE.md` holding content** beyond the pointer;
**one rule stated in two places**. A long router carrying none of the marks is not a monolith, and a short one
carrying any of them is. What a monolith costs is its whole length loaded by every agent that reads it, since
nothing in it says which part bears on the work at hand.

**Absent guidance is not a monolith.** A project with no `AGENTS.md` and no `CLAUDE.md` has nothing to split,
and a router with an empty topic table — every rule it carries true for every change in its directory — is
the layout, not a departure from it.
