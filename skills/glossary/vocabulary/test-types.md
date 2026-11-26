# test-type table — which kind of test brings value in which area

A project's **test-type table** is its record, one row per area, of which kind of test brings value there:
what must be right, which test type is worth committing, whether the area is checked by hand, and what is
never committed. **It is agent guidance (`skills/glossary/vocabulary/agent-guidance.md`), not
config** — it lives in the project's tests chapter, routed from its `AGENTS.md`, and no key in
`.agents/worktree.json` holds it. Its
columns and how it is drafted with the owner are `/pipeline:setup`'s.

**It narrows a project's *Test policy* per area and never widens it**: a test the policy would not admit is
not admitted by a row, and an area with no row is held to the policy alone.
