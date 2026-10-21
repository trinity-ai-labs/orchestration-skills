# code shape — domain, core, component, release unit, central list, domain map, exception list, domain tag, shared spine, split gate, moves the boundary, seam test, guard, probe, setup debt

**Code shape** is how a project's files divide by what they are about, and how cheaply that division lets a
change be scoped, gated and reviewed. **The folder is the unit**: what ships, what is shared and where a test
lives all follow from where code sits.

A **domain** is one area of behaviour a project's code is about — billing, search, an admin surface — whose
files change together and whose tests assert about it. It is a fact about the code, named by the project, and
a folder usually carries one.

Code sits in three **layers**, dependencies pointing down from the release unit through the component to the
core:

- The **core** is the shared code every release unit is built on — thin, and changed rarely and on purpose.
  Code enters it only when a second component needs what one component holds.
- A **component** is a self-contained piece with its code and all of its tests — unit, integration, browser —
  in its own folder, tested on its own. It depends on the core and never on another component.
- A **release unit** is what is versioned and shipped on its own: a thin assembly of components plus a shell.
  It never imports another release unit; where one shows another, it reads a descriptor the other publishes,
  not its source. Code only one release unit needs stays in that unit.

A release unit or a component **declares itself** in a manifest in its own folder, found by a glob. A
**central list** is the opposite: one file every domain, component or release unit edits to register itself
by name — a unit, a route, a test, a product — which folder-discovered declarations would make unnecessary.

A **domain map** is a file mapping path globs to domains, read top to bottom with the first matching glob
winning. It **covers** a project when every tracked file matches some glob. A map built from evidence — what
each test imports or calls — rather than written by hand under-approximates, since a reach through a runtime
string or a config value leaves no import behind. **Once a gate's selection comes from structure, the map is
an exception list**: an **exception list** holds only what the folders and the import or build graph cannot
express — such a runtime-string or config-value reach — and is no longer the selection mechanism.

A **domain tag** is the mark on a test naming the domain it asserts about, in whatever form the project's
test tooling offers — an annotation, a tag option, a naming convention, a registered list. A tag is
**checked** when something fails on a wrong or missing one; an unchecked tag is a guess about the test. Where
a test sits in its subject's folder, the folder names its domain, and a tag carries only what the folder
cannot say.

The **shared spine** is the set of files the map assigns to every domain — shared code, configuration,
build setup — so a change to any of them can affect everything, and a gate that narrows by domain map runs
the whole suite whenever one is touched.

A **split gate** is a partial per-change gate — it runs only what a change can affect, falling back to the
whole suite on anything it cannot place — with the full gate kept rather than dropped. It is
**structure-selected** when it takes its selection from the folders a change touches plus the release units
built from them, found from the manifests and the import or build graph, so a change to the core selects
every release unit that core reaches and prints that reach; it is **map-selected** when it takes its selection
from a domain map's union of the touched domains.

A change **moves the boundary** when it touches what a split gate's selection rests on, so no selection can
vouch for it:

- for a **structure-selected** gate, only its **selection machinery** — the gate itself, the manifests'
  discovery, the exception list and its checks, the toolchain or a lockfile. A change to shared code or the
  core alone does not move it: the gate already selects the release units that change reaches.
- for a **map-selected** gate, the domain map or its checks, a shared-spine file, the toolchain or a lockfile.

A **seam test** is a test written at a boundary a caller or a user crosses — a route, a command, a module's
public interface — rather than against a module's internals. It survives a refactor behind that boundary
and fails when the behaviour across it breaks, which a test of wiring does not.

A **guard** is a permanent test — committed, and run by every gate whose selection reaches it. A **probe** is
a check run once to learn something or to prove a fix, and never committed as a permanent case. The same
assertion can be either; what separates them is whether it stays in the suite.

**Setup debt** is a property of a project's setup that makes every future change dearer to scope, gate or
review — nothing a gate can narrow its selection by, untagged tests, tests living away from their subject, a central list, a full-suite
gate slow enough to matter, a signal worked out by hand each time, agent guidance
(`skills/glossary/vocabulary/agent-guidance.md`) every agent loads whole. It is a fact about the project,
distinct from a defect in the code: nothing is broken, and every change pays for it.
