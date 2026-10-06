# code shape — domain, domain map, domain tag, shared spine, seam test, setup debt

**Code shape** is how a project's files divide by what they are about, and how cheaply that division lets a
change be scoped, gated and reviewed.

A **domain** is one area of behaviour a project's code is about — billing, search, an admin surface — whose
files change together and whose tests assert about it. It is a fact about the code, named by the project; a
folder usually carries one, and code placed outside its domain's folder is the commonest departure.

A **domain map** is a file mapping path globs to domains, read top to bottom with the first matching glob
winning. It **covers** a project when every tracked file matches some glob. A map built from evidence — what
each test imports or calls — rather than written by hand under-approximates, since a reach through a runtime
string or a config value leaves no import behind.

A **domain tag** is the mark on a test naming the domain it asserts about, in whatever form the project's
test tooling offers — an annotation, a tag option, a naming convention, a registered list. A tag is
**checked** when something fails on a wrong or missing one; an unchecked tag is a guess about the test.

The **shared spine** is the set of files the map assigns to every domain — shared code, configuration,
build setup — so a change to any of them can affect everything, and a gate that narrows by domain runs the
whole suite whenever one is touched.

A **seam test** is a test written at a boundary a caller or a user crosses — a route, a command, a module's
public interface — rather than against a module's internals. It survives a refactor behind that boundary
and fails when the behaviour across it breaks, which a test of wiring does not.

**Setup debt** is a property of a project's setup that makes every future change dearer to scope, gate or
review — no domain map, untagged tests, a full-suite gate slow enough to matter, a signal worked out by hand
each time. It is stated as three parts: the measured signal with its unit, what it costs each change, and
the move that removes it. It is a fact about the project, distinct from a defect in the code: nothing is
broken, and every change pays for it.
