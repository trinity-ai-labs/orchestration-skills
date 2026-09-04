---
name: glossary
description: >-
  The pipeline's concept map — one definition per shared term, and nothing else. Read an entry when you
  meet a term the pipeline uses as though you already know it, or when you are writing a pass and need the
  canonical definition rather than a fresh one. Entries carry DEFINITIONS ONLY: what a thing is, never what
  to do about it, which belongs to whichever pass acts on it. This is a reference index, not a workflow —
  there is nothing here to run and nothing here to dispatch.
argument-hint: "[the term to look up — omit to read the index]"
---

# Glossary — one definition per shared term

**A "term" here is anything with an invariant definition — a noun the passes share, and equally a FACT about a tool or an artifact.** How `gh` treats a flag, or when GitHub acts on a closing keyword, is one fact every pass needs identically and none of them owns, which is the same shape as a noun and the same drift.

The pipeline's passes are separate on purpose: a reader acts from one of them and should not have to open
another to know what to do. But the *vocabulary* is shared, so a term used by four passes was defined by
four passes — four definitions of one thing, already drifting, with nothing that could make them agree.

**This is where a definition lives. How a stance ACTS on it lives in that stance.** `epic branch` means
one thing; what `/pipeline:decompose` does about one, what `/pipeline:execute` does about one and what
`/pipeline:orchestrate` does about one are three different things, all three correct, and none of them
belong here.

## The two rules that keep this cheap

- **An entry carries a definition and no imperative.** What the thing is, what distinguishes it from the
  thing it is confused with, and nothing about when to reach for it. An entry that starts telling a reader
  what to do has become a fifth pass, and the rule it states is one nobody acting will see, because the
  reader who needed the rule was in a stance file and never came here.
- **One hop, and no entry ever cites a pass.** A pass cites an entry **directly**, so meeting an unfamiliar
  term costs one read rather than a walk through this index. **The banned direction is back out**: an entry
  reaching into a pass makes the map a fifth stance and rebuilds the citation web it replaces, and the gate
  fails it like any other cross-skill citation. **Entries may cross-link each other** — a glossary whose
  terms cannot name each other is worse, not safer, and a dozen shallow definitions are not a web. The bar
  is that **each entry stands alone**: a reader must be able to act on it without following the link, so a
  cross-link is a *see also* and never a missing half.

- **Two entries that only make sense together were one concept.** The tell is a cross-link neither side can
  be read without following — at which point it is not a *see also*, it is a definition split in half. Merge
  them and give the index two rows onto the one entry, rather than keeping the halves and relaxing the rule
  that caught them: a term can have several names and still be one thing.

**This index is for finding an entry you cannot name**, and for an author checking whether a term already
has a home before writing a definition into a pass. It is not the route a citation takes.

## The glossary

**Two kinds, and the difference is who owns the truth.**

**Vocabulary** — words this pipeline invented. They mean nothing outside this flow, and what they mean is
ours to decide, so they go wrong by **drifting**: two copies worded differently, both looking correct.

| term | entry |
|---|---|
| epic branch | `skills/glossary/vocabulary/epic-branch.md` |
| grounding depth — horizon, shape / slice | `skills/glossary/vocabulary/grounding-depth.md` |
| horizon | `skills/glossary/vocabulary/grounding-depth.md` |
| integration branch | `skills/glossary/vocabulary/integration-branch.md` |
| umbrella | `skills/glossary/vocabulary/umbrella.md` |

**Mechanics** — how something this pipeline does not own behaves: git, GitHub, the `gh` CLI. They are true
whether or not this pipeline exists, so we can only be right or wrong about them — and they go wrong by
going **stale**, when the tool changes and nobody here touches a file. A citation naming `mechanics/` is
telling its reader that before they open it.

| fact | entry |
|---|---|
| branch leaf | `skills/glossary/mechanics/branch-leaf.md` |
| closing keyword | `skills/glossary/mechanics/closing-keyword.md` |
| `gh api` body from a file | `skills/glossary/mechanics/gh-api-file-body.md` |
| sub-issue link | `skills/glossary/mechanics/sub-issue-link.md` |

**An entry may name another entry's term, and when it does it links to it.** A mechanic naming a piece of
this pipeline's vocabulary is the ordinary case — a closing keyword's predicate is about branches this flow
has names for — and the link is what stops that mention from becoming a second, drifting definition.
