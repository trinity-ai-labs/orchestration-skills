# Platform mappings

Reference for `skills/execute/SKILL.md`. The rest of this skill names **capabilities**; this is the only file naming a host's tools, models and paths. **Where your actual tool list disagrees with this table, trust the tool list and say so in your report.**

|  | Claude Code | Codex |
|---|---|---|
| Manifest | `.claude-plugin/plugin.json` | `.codex-plugin/plugin.json` |
| Skill discovery | `skills/<slug>/SKILL.md`, `name` + `description` frontmatter | identical |
| Fresh sub-agent, never a fork | `Agent`, any `subagent_type` but `fork` | `spawn_agent` with `fork_turns: "none"` |
| Dispatch in the background | `run_in_background: true` | every spawn is detached |
| Correct, resume, list, or stop one | `SendMessage` / `TaskStop` | `followup_task` / `list_agents` |
| Self-paced tick | `ScheduleWakeup`, ≈600s | `wait_agent`, `timeout_ms` 300000–600000 |
| Standard tier | `model: "sonnet"` | a mid preset **and** `reasoning_effort` |
| Top tier | `model: "opus"` | a top preset **and** `reasoning_effort` |
| Auto worktree provisioner — BANNED | `isolation: "worktree"` | none seen; any that appears is banned too |
| `bin/` on `PATH` | yes, while enabled | **no** |

⛔ **On Codex set `model` AND `reasoning_effort` on every spawn** — `model` alone silently resets effort to that model's default, so a top-tier slice runs at a tier nobody chose. Spawning needs `features.multi_agent = true` in the host config; without it there is no spawn tool at all.

## Calling a helper — two questions, and the second is the whole Codex gap

**Which extension.** `<name>.sh` for a Bash shell tool, `<name>.ps1` for a PowerShell one; arguments, env vars, the `READY:` line and exit codes are identical. A native-Windows session without Git for Windows has **no bash at all**, so `.sh` there is a command that does not exist rather than a script that fails, and the error reads as a broken plugin.

**Bare command, or absolute path.** Claude Code puts an enabled plugin's `bin/` on the shell tool's `PATH`, which is why this skill writes every helper bare. **Codex puts nothing on `PATH`** — its manifest has no `bin` key — but it does install `bin/` with the rest of the plugin, under `$CODEX_HOME/plugins/cache/<marketplace>/<plugin>/<version>/`. So there a bare `setup-worktree.sh` is *command not found*: **resolve that root once before you provision anything, and call every helper by absolute path from it.** Skipped, the run dies at its first helper, before any work exists to hand back.
