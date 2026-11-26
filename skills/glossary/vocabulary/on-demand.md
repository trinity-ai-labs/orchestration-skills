# on demand — run because something asked, never by a gate

A check, probe, tool or test is **on demand** when it runs because work, an agent or the owner asks for it,
and never on every gate. Three demands start one:

- **work demand** — a change touches the area the check covers;
- **agent demand** — an agent doubts that code does what its name or its comment says;
- **owner demand** — a maintainer asks.

**What puts a check on demand is its value per run, never its speed**: a fast check with nothing to say on most
changes is on demand, and a slow one whose failure is costly and invisible while building is a guard
(`skills/glossary/vocabulary/code-shape.md`).

**An on-demand check is never wired into a project's `gate` or `preflight`** — a check either of those runs is
the gate's, whatever started that run. A `fullGate` run on a maintainer's ask is the opposite case: the
project's gate, run at a moment a maintainer chose, and not an on-demand check.
