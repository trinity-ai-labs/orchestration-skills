# grounding depth — the horizon, shape depth and slice depth

The **horizon** is the next dispatchable set: every remaining item in a plan whose dependencies have
already landed. Usually that is a wave; sometimes only the part of one that is genuinely dispatchable,
where the rest still waits on something unmerged.

**It is decided by dependency, never by understanding.** How well a planner happens to understand an item,
how small it is, or how directly someone asked about it moves nothing. It moves outward only as work
lands, and it is the only thing that promotes an item from shape depth to slice depth.

Every item sits at exactly one of two depths, and the horizon is what separates them.

**Shape depth** — everything *beyond* the horizon. Goal, area, dependency, and one line on why it comes
after the thing before it. **No `file:line`, no owned-file list, no do-not-touch boundaries, no framework
skill, no model tier, no verify bar.** An item at shape depth is not an unfinished item; it is deliberately
ungrounded, because grounding it now is what goes stale.

**Slice depth** — the horizon only. The full set a dispatchable slice carries: **`Goal`, `Owns`,
`Do NOT touch`, `Derives`, depends-on, the framework skill to open with, the model tier, the brief, and the
verify bar** — grounded against the tree as it stands now.

**That slice-field list is the canonical one.** An enumeration of it written anywhere else is a copy, and
copies of it have drifted, because each copy is internally consistent and no skill may cite another to
compare them — which is why the gate now derives this list from here and holds every copy to it.

**Both depths carry a failure and both are silent.** Grounding beyond the horizon writes coordinates that
stop existing — a path renamed by earlier work still reads as prose, so the reader builds against the
nearest plausible thing. Dispatching at shape depth hands out no scope, so the scope gets invented.
