# Host tool mappings

Entry in `skills/procedures/SKILL.md`. Every pass names **capabilities**; this is the one file naming a
host's tools, models and paths. **Where your actual tool list disagrees with this table, trust the tool
list and say so in your report.**

|  | Claude Code | Codex |
|---|---|---|
| Manifest | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |
| Skill discovery | `skills/<slug>/SKILL.md`, `name` + `description` frontmatter | identical |
| Fresh sub-agent, never a fork | `Agent`, any `subagent_type` but `fork` | `spawn_agent` with `fork_turns: "none"` |
| Dispatch in the background | `run_in_background: true` | every spawn is detached |
| Wait on agents you dispatched | end your turn with no tool call — it is safe: each report re-invokes you as a new turn. The tell you can read is the background spawn call's own result, which says you will be notified when that agent completes — the host's promise to re-invoke you. Observed from a main session and from a sub-agent dispatched in the background waiting on its own children | **not established — read your tool list** |
| Correct or resume a live one — the FIRST lever | `SendMessage` | `followup_task` |
| List the live ones — the agents YOU spawned, never their children | `ListAgents` | `list_agents` |
| Stop one — the SECOND lever, for a changed scope | `TaskStop` | **not established — read your tool list** |
| Reach the agent that SPAWNED you, from inside a sub-agent | `SendMessage`, `to: "main"` — from a BACKGROUND sub-agent | **not established — read your tool list** |
| Self-paced tick | `ScheduleWakeup`, ≈600s | `wait_agent`, `timeout_ms` 300000–600000 |
| Persistent watch over a ledger directory | `Monitor`, whose command runs in **zsh** on macOS | **not established — read your tool list** |
| Longest single foreground command | the shell tool's `timeout`, up to 600000 ms (default 120000) | **not established — read your tool list** |
| When a sub-agent is reported completed | when it stops with no live background children of its own — one that ended its turn to wait on its children is not reported | **not established — read your tool list** |
| A command you detached, seen from inside a sub-agent | unlike a child agent's report, its exit re-invokes nothing: the sub-agent's ended turn is its hand-back, reported completed with the command still running — observed, not documented | **not established — read your tool list** |
| Concurrent sub-agent ceiling | 20 running at once by default, changed by `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`; an over-cap spawn is REFUSED, not queued, with `Concurrent subagent limit reached. You can run N subagents at once. Do not retry.` | **not established — read your tool list** |
| Standard tier | `model: "sonnet"` | a mid preset **and** `reasoning_effort` |
| Top tier | `model: "opus"` | a top preset **and** `reasoning_effort` |
| Auto worktree provisioner — BANNED | `isolation: "worktree"` | none seen; any that appears is banned too |
| `bin/` on `PATH` | yes, while enabled | **no** |

⚠️ **Correcting a live agent, listing the live ones and killing one are three rows because they are three
acts with different costs.** Merged into one label they read as a single capability, and a reader reaches
for whichever tool it recognises — which on this table was the destructive one. **And a cell naming a stop
your host may not have is worse than a blank one**, since the flow sends you here *for* that tool: where a
row says the tool is not established, the sentence above is the whole instruction — read your own tool
list, and say in your report what you found.

⚠️ **A filled wait cell is the ordinary case: where it names an ended turn, ending your turn IS the wait and
loses nothing**, since each child's report re-invokes you. The row has THREE branches — that ended turn; a
call that blocks until a child reports; and, selected by a BLANK cell, neither. **A blank means this table
establishes neither for that host, and it is a reading rather than an absence of one** — read your own tool
list, and where that confirms neither exists, there is no wait to make and `skills/ground-rules/SKILL.md`
rule 10 carries what to do instead.

⚠️ **The reach-your-spawner row hands back a RECEIPT, never a reply, so send and carry on rather than
wait.** The call returns synchronously and what comes back acknowledges that the message is queued; the
agent it addresses reads it on its own next turn, and an answer, when it comes, arrives as a message of
its own rather than as the call's return. **The Claude Code cell carries a precondition its neighbours do
not** — that address resolves from a sub-agent dispatched in the BACKGROUND, which this flow defaults to
but does not require, so a foreground dispatch has no channel and the row is not the one to read. **And
the listing row runs one way only**: a sub-agent is not given the tool that enumerates live agents, so it
cannot discover an address the way a spawning agent discovers one.

⚠️ **A check that outlasts one foreground call is detached with its exit status written INSIDE the detached
shell, then polled with foreground calls in the same turn:**

```sh
nohup sh -c '{ <check>; } > check.log 2>&1; echo "EXIT=$?" >> check.log' >/dev/null 2>&1 &
for i in $(seq 1 55); do grep -q '^EXIT=' check.log && break; sleep 10; done; tail -n 40 check.log
```

Run the second line as its own call with its timeout at the limit above, and again until the tail shows the
`EXIT=` line — each call returns the log, so it is a watch whose result you act on rather than a call made to
keep a turn open. **The braces put the whole check under one redirect**, since a redirect on an `&&` chain
binds to its last command alone and the rest of the output never reaches the log; **and the exit line goes
inside `sh -c`**, since outside it `&` detaches only the last command and the line lands nowhere. On a shell
without these, any equivalent that writes the whole check's output and its own exit status into its log does
the job.

⚠️ **The ceiling row answers why a spawn failed before you decide what failed.** A refusal there is a
capacity answer about the whole session and says nothing about the child you asked for; spawning succeeds
again once the running count drops below the limit, so an agent whose own children are still running has
slots it can wait on, and one with none has nothing to free.

⛔ **On Codex set `model` AND `reasoning_effort` on every spawn** — `model` alone silently resets effort to
that model's default, so a slice meant for the top tier runs at a tier nobody chose. Spawning needs
`features.multi_agent = true` in the host config; without it there is no spawn tool at all.

## Calling a helper — two questions, and the second is the whole Codex gap

**Which extension.** `<name>.sh` for a Bash shell tool, `<name>.ps1` for a PowerShell one; arguments, env
vars, the `READY:` line and exit codes are identical (`skills/procedures/worktree-helper.md` carries that
contract). A native-Windows session without Git for Windows has **no bash at all**, so `.sh` there is a
command that does not exist rather than a script that fails, and the error reads as a broken plugin.

**Bare command, or absolute path.** Claude Code puts an enabled plugin's `bin/` on the shell tool's
`PATH`, which is why this corpus writes every helper bare. **Codex puts nothing on `PATH`** — its manifest
has no `bin` key — but it does install `bin/` with the rest of the plugin, under
`$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/`. So there a bare `setup-worktree.sh` is
*command not found*: **resolve that root once before you provision anything, and call every helper by
absolute path from it.** Skipped, the run dies at its first helper, before any work exists to hand back.
