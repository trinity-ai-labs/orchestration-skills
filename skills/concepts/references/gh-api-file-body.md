# `gh api` with a body read from a file

`gh api` has two flags for a field value, and only one reads a file:

- **`-F` is `--field`** — a leading `@` is expanded into the named file's contents. It also types a bare
  number as a JSON integer and `true`/`false` as booleans.
- **`-f` is `--raw-field`** — the value is sent verbatim, so `-f body=@notes.md` stores the literal
  eleven-character string `@notes.md`.

**The wrong flag fails in the worst direction: the command exits 0 and prints a URL.** Nothing errors, the
run reports success, and the damage is visible only to a person opening the issue or comment. Re-fetching
the body and confirming it is the markdown rather than a path is the only check that sees it.

**A genuine literal still belongs on `-f`** — a title, a state — so the rule is not "always use `-F`". The
two cases where `-F` is required are an `@file` value and a value whose JSON **type** matters.
