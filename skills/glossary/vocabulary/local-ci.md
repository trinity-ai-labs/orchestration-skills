# local CI — a job on a runner this machine holds

A CI job is on **local CI** when it runs on a runner registered on this machine, so its minutes cost nothing.
It is read off three facts, in order:

1. **The job's `runs-on` labels**, in the workflow that runs it.
2. **The repository's runners**, from `gh api repos/<o>/<r>/actions/runners` — each one's `name` and
   `labels` — and the runner those labels match.
3. **This machine's registration of that runner**: a `.runner` file in its runner directory whose
   `agentName` is that runner's `name`, the directory a project's runner install script defaults to
   `$HOME/actions-runner/<r>`. A runner name equal to this
   machine's hostname, `config.sh`'s default name, corroborates the match and proves nothing by itself.

**A GitHub-hosted runner, or a paid provider's, is never local CI.** **A seat that cannot place the job's
runner reads it as not local CI**: the API refused, no `.runner` file was found, or the labels also match a
runner this machine does not hold.

Local CI is a fact about where a job ran, not a gate mode: a remote gate on local CI is still remote.
