---
name: concepts
description: >-
  The pipeline's concept map — one definition per shared term, and nothing else. Read an entry when you
  meet a term the pipeline uses as though you already know it, or when you are writing a pass and need the
  canonical definition rather than a fresh one. Entries carry DEFINITIONS ONLY: what a thing is, never what
  to do about it, which belongs to whichever pass acts on it. This is a reference index, not a workflow —
  there is nothing here to run and nothing here to dispatch.
argument-hint: "[the term to look up — omit to read the index]"
---

# Concepts — one definition per shared term

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
- **One hop, one direction.** A pass cites an entry **directly**, so meeting an unfamiliar term costs one
  read rather than a walk through this index. Nothing here cites a pass, and no entry cites another entry
  — a map that points back at its readers is the citation web this replaces, wearing a different name.

**This index is for finding an entry you cannot name**, and for an author checking whether a term already
has a home before writing a definition into a pass. It is not the route a citation takes.

## The map

| term | entry |
|---|---|
| branch leaf | `skills/concepts/references/branch-leaf.md` |
| closing keyword | `skills/concepts/references/closing-keyword.md` |
| epic branch | `skills/concepts/references/epic-branch.md` |
| `gh api` body from a file | `skills/concepts/references/gh-api-file-body.md` |
| sub-issue link | `skills/concepts/references/sub-issue-link.md` |
