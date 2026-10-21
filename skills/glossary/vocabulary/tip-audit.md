# tip audit — cold, gives way, charged, environmental

A **tip audit** is one cold run of the whole suite against the newest tip of an integration branch
(`skills/glossary/vocabulary/integration-branch.md`) or an epic branch
(`skills/glossary/vocabulary/epic-branch.md`), queued in a project's gate queue whenever that tip moves and run
between close-outs rather than in front of any merge. It gates no PR and holds no merge: its verdict is a fact
about a tip already landed.

**Cold** means it reads no cache and no stored green, so every step executes. Its command is the project's
`fullGate` where one is declared, which is cold by meaning.

It **gives way**: an ordinary ticket arriving while it runs stops it, and a stopped audit records nothing.

A red audit is **charged** to the first merge, since the branch's last green audit or an epic branch's fork
point, at which its failing tests fail. A failure that also fails at the green audit the narrowing started
from is **environmental**, and is charged to no merge.
