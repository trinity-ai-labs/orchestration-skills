# review checkpoint

A **review checkpoint** is one `/pipeline:review` panel over an epic branch's tip
(`skills/glossary/vocabulary/epic-branch.md`) mid-arc, posted onto the epic's own draft PR into the
integration branch (`skills/glossary/vocabulary/integration-branch.md`). It reads the change since a base
SHA — the previous checkpoint's reviewed head, or the epic's fork point the first time — rather than the
PR's whole diff, which the close-out panel reads once the last slice has merged.

**A review checkpoint is not a merge checkpoint.** "Checkpoint" alone names a merge an `autoMerge*` key may
hold — a fact about who merges. A review checkpoint is a fact about who reads: it gates nothing, merges
nothing, and the epic PR it posts onto stays a draft.
