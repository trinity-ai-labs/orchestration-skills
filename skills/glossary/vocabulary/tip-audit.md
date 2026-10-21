# tip audit — cold, gives way, charged, environmental

A **tip audit** is one cold run of the whole suite against the newest tip of an integration branch
(`skills/glossary/vocabulary/integration-branch.md`) or an epic branch
(`skills/glossary/vocabulary/epic-branch.md`), queued as a ticket in a project's gate queue whenever that tip
moves and run between close-outs rather than in front of any merge. It exists only where a project has a gate
queue. It gates no PR and holds no merge: its verdict is a fact about a tip already landed.

**Cold** means it reads no cache and no stored green, so every step executes and none is replayed. Its
command is the project's `fullGate` where one is declared, which is cold by meaning, and otherwise `gate` run
with the cache bypassed by the task runner's own switch. A run that replayed a step is not an audit.

It **gives way**: an ordinary ticket arriving while it runs stops it, its throwaway tree is removed and it goes
back into the queue, recording nothing but that it was requeued. At most one is pending per branch, aimed at
the newest tip, so under steady traffic one may never finish, and an epic's close-out gate stays the backstop.

It catches what a scoped or cached gate cannot see — a change that breaks a test its own run never selected
or imported, or a cached green hiding a failure that predates it. A red audit is **charged** to the first
merge since the last green audit at which its failing tests, re-run by name, fail. A failure that also fails
at the last green audit is **environmental** and is charged to no merge.
