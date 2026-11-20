# Standing up a self-hosted runner for the gate

Reference for Step 1 of `/pipeline:setup`, *The real gate*. **Read it only once the user has said yes to the
CI-runner offer** — a no is a complete answer, and the project then gates locally. Everything here lands in
the project, never in this plugin's helpers.

**The gate rule never asks where a runner lives**: a GitHub-hosted runner or a paid provider's satisfies a
remote gate exactly as a self-hosted one does (`skills/procedures/config-keys.md`, `gatePreference`).
Self-hosting is only what this offer brings, so that a remote gate costs the user nothing.

**Nothing is registered, committed or started without the user's yes to that artifact** — the install script,
the workflow and the registration are each shown first (`skills/ground-rules/SKILL.md`, rule 14).
**Per repo, or across a workspace's members**: a runner registers to one repository, so in a workspace repeat
the whole of this for each member the user names, each with its own runner directory, service and label.

## Tell the user first

- **What the machine needs**: the toolchain `gate` runs on, disk for the runner's work directory, and the
  machine left on — on macOS with the user logged in, since the service is a per-user launch agent — and that a
  self-hosted runner takes one job at a time, Actions queueing the rest.
- **On a public repository, a self-hosted runner executes the code of any PR that can trigger its
  workflow**, a fork's included — so have the user require approval for outside contributors' workflow runs
  in the repository's Actions settings, or keep the runner to private repositories.
- **Machine facts and secrets stay off the committed config** — the runner's host, its service, keychain or
  signing access. Say what the runner needs on the machine; never write a secret anywhere, and never commit,
  print or log the registration token, which is short-lived by design.

## The install script — committed, and the project's own

Write `.github/scripts/install-<os>-runner.sh` (`install-macos-runner.sh`, `install-linux-runner.sh`) into the
project, show it, and commit it on the user's yes in the PR setup opens, the project running and evolving it
from there. **It is idempotent: a re-run converges on the same runner, never a
second registration.** It must:

1. Resolve `<o>/<r>` with `gh repo view --json nameWithOwner --jq .nameWithOwner`, a runner directory outside
   the repository (default `$HOME/actions-runner/<r>`) and a label (default `<r>-gate`), each overridable.
2. Unpack the runner release for this OS and architecture into that directory where it holds none.
3. Skip registration where the directory already holds a `.runner` file; otherwise take a token with
   `gh api -X POST repos/<o>/<r>/actions/runners/registration-token --jq .token` into a variable never echoed,
   and run `./config.sh --unattended --url https://github.com/<o>/<r> --token "$TOKEN" --labels <label>`.
4. Install the service with `./svc.sh install` only where it is not installed yet — on macOS, where its plist
   is absent, since `install` refuses an existing one — on Linux under `sudo`, naming the user it runs as.
5. **On macOS, remove `SessionCreate` from the plist and reload the service** (below), on every run.
6. Where the gate needs the user's login-shell toolchain, write the runner's `.path` from
   `"$SHELL" -lc 'printf %s "$PATH"'`, in the runner's directory.
7. Start the service (`./svc.sh start`, after the patch on macOS) and print the label and its status.

### The macOS SessionCreate trap

**`./svc.sh install` writes `SessionCreate = true` into the runner's launchd plist**
(`~/Library/LaunchAgents/actions.runner.<o>-<r>.<runner-name>.plist`), which starts the runner in a fresh
security session that cannot reach the user's login Keychain — so **anything needing that Keychain fails on the
runner and passes in the user's own session**: WebKit's WebCrypto key storage falls back to another backend,
and code signing and notarization cannot reach the Developer ID identity. The script removes the key after
`svc.sh install` and reloads, and since reinstalling the service writes a fresh plist, **the patch is part of
the script and runs on every run, never a one-off hand edit**:

```sh
/usr/libexec/PlistBuddy -c 'Delete :SessionCreate' "$PLIST" 2>/dev/null || true
./svc.sh stop 2>/dev/null || true
./svc.sh start
```

**It is one case of a general class: a self-hosted runner's environment can differ from the user's session** —
its security session, its `PATH`, the login-shell environment a service never sources. Say so to the user, and
read a red seen only on the runner through it (*The first-run parity check*).

## The gate workflow — drafted, shown, committed only on a yes

Draft `.github/workflows/gate.yml` running the project's `gate` on every `pull_request`, on the runner's label,
and show it before anything is committed — this yes is the user's agreement to adding CI, and covers this
workflow alone. **Give it no `branches` filter**: a slice of an epic targets the epic branch, and a filter
naming only the integration branch leaves every such slice with no PR CI, gating locally:

```yaml
name: gate
on:
  pull_request:
concurrency:
  group: gate-${{ github.ref }}
  cancel-in-progress: true
jobs:
  gate:
    runs-on: [self-hosted, <label>]
    steps:
      - uses: actions/checkout@v4
      - run: <install>
      - run: <gate>
```

**Leave drafts in** — an implementer's PR is a draft when its gate runs, so a `draft == false` filter would
leave every slice with no answer and send it to the local fallback. The concurrency group cancels a superseded
head's run, so a fix-round push does not queue a stale gate on a runner that takes one job at a time. Set the
environment `gate` needs in the workflow or the runner's `.env`, never by assuming the user's shell.

## The first-run parity check

**The first remote gate is compared against a local run of the same `gate` at the same SHA** — the setup PR
that adds the workflow being that first run, so register the runner before that PR opens, and the local one
made in a worktree cut at its head, never the main checkout. Green on both settles it. **A red only on the
runner points at the runner's environment, not the code**: name what differs, by the class above, fix it in
the install script, and re-run, a CI re-run being the user's call. Red on both is the gate's own answer. Report
the result in setup's handoff.
