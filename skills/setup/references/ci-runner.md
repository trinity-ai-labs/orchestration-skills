# Standing up a self-hosted runner for the gate

Reference for Step 1 of `/pipeline:setup`, *The real gate*. **Read it only once the user has said yes to the
CI-runner offer** — a no is a complete answer, and the project then gates locally. Everything here lands in
the project, never in this plugin's helpers.

**The gate rule never asks where a runner lives**: a GitHub-hosted runner or a paid provider's satisfies a
remote gate exactly as a self-hosted one does (`skills/procedures/config-keys.md`, `gatePreference`).
Self-hosting is only what this offer brings, so that a remote gate costs the user nothing: a job on local CI
(`skills/glossary/vocabulary/local-ci.md`) also lifts the required local preflight
(`skills/procedures/config-keys.md`, `preflight`).

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
from there. **It is the PROJECT's script because what a runner needs differs by project**, so it is written from
what this project's `gate` — and any other job the user means to put on the runner — actually needs, and
never from a fixed recipe.

**Every script does the same five things**, since they are what registering a runner is. It is idempotent: a
re-run converges on the same runner, never a second registration.

1. Resolve `<o>/<r>` with `gh repo view --json nameWithOwner --jq .nameWithOwner`, a runner directory outside
   the repository (default `$HOME/actions-runner/<r>`) and a label (default `<r>-gate`), each overridable.
2. Unpack the runner release for this OS and architecture into that directory where it holds none.
3. Skip registration where the directory already holds a `.runner` file; otherwise take a token with
   `gh api -X POST repos/<o>/<r>/actions/runners/registration-token --jq .token` into a variable never echoed,
   and run `./config.sh --unattended --url https://github.com/<o>/<r> --token "$TOKEN" --labels <label>`.
4. Install the service with `./svc.sh install` only where it is not installed yet — on macOS, where its plist
   is absent, since `install` refuses an existing one — on Linux under `sudo`, naming the user it runs as.
5. Start the service (`./svc.sh start`) and print the label and its status.

**Everything else goes in only where this project needs it.** Read the gate's script, the project's existing
CI and its agent guidance for what the gate reaches on the machine, ask the user what they cannot show, and
**add a step per need you found, each with a comment saying which need it answers** — so the next reader can
tell a step the project relies on from one copied in. **A step for a need the project does not have is not
caution, it is a change to the machine nobody asked for.** The traps below are a checklist to read the project
against, never steps to include by default.

### Traps to check the project against

**A self-hosted runner's environment can differ from the user's own session** — its security session, its
`PATH`, the login-shell environment a service never sources — so a gate that passes in the user's terminal can
fail on the runner with nothing wrong in the code. Each known case, and the project need that makes it bite:

- **macOS: the login Keychain.** `./svc.sh install` writes `SessionCreate = true` into the runner's launchd
  plist (`~/Library/LaunchAgents/actions.runner.<o>-<r>.<runner-name>.plist`), which starts the runner in a
  fresh security session that cannot reach the login Keychain. **It bites only a project whose jobs reach that
  Keychain** — code signing or notarization with a Developer ID identity, or tests storing keys through the
  platform (WebKit's WebCrypto key storage falls back to another backend there). Where one does, the script
  removes the key after the service install and reloads, and since reinstalling the service writes a fresh
  plist, **that step runs on every run of the script, never as a one-off hand edit**:

  ```sh
  # The gate signs with the login Keychain's Developer ID identity; SessionCreate would hide it.
  /usr/libexec/PlistBuddy -c 'Delete :SessionCreate' "$PLIST" 2>/dev/null || true
  ./svc.sh stop 2>/dev/null || true
  ./svc.sh start
  ```

  A project whose jobs never touch the Keychain leaves the plist as the runner wrote it.
- **The login-shell toolchain.** A service never sources the user's shell profile, so a toolchain found only
  through it (a version manager's shims, a Homebrew prefix) is missing on the runner. **It bites only where
  the gate relies on such a tool**; there the script writes the runner's `.path` from
  `"$SHELL" -lc 'printf %s "$PATH"'` in the runner's directory, or the workflow installs the toolchain itself.

**A trap the project hits that is not listed here** goes into its script the same way, with its comment, and
is worth raising for this list.

## The gate workflow — drafted, shown, committed only on a yes

Draft `.github/workflows/gate.yml` running the project's `gate` on every `pull_request`, on the runner's label,
its setup steps taken from what the project's gate needs and from any CI it already runs rather than from the
skeleton below alone, and show it before anything is committed — this yes is the user's agreement to adding CI, and covers this
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
      - run: <preflight>
      - run: <gate>
```

**Run the `preflight` as its own step before the `gate` step**, so a type or lint error fails the job in
seconds and is named on its own line; where `preflight` is the same command as `gate`, the one `gate` step
is it. **Leave drafts in** — an implementer's PR is a draft when its gate runs, so a `draft == false` filter would
leave every slice with no answer and send it to the local fallback. The concurrency group cancels a superseded
head's run, so a fix-round push does not queue a stale gate on a runner that takes one job at a time. Set the
environment `gate` needs in the workflow or the runner's `.env`, never by assuming the user's shell.

## Reading the first remote gate

The setup PR that adds the workflow is the runner's first gate, so register the runner before that PR opens.
**Green settles it.** **Where it is red, re-run the failing tests by name locally at the same SHA**, in a
worktree cut at that head and never the main checkout: **a red only on the runner points at the runner's
environment, not the code** — name what differs, read it against *Traps to check the project against*, fix it
in the project's install script, and re-run, a CI re-run after a test failure being the user's call
(`skills/ground-rules/SKILL.md`, rule 14, whose one exception is a re-run once, on local CI, for an
infrastructure failure, never after a test failure). Red on both is the gate's own
answer. Report the result in setup's handoff.
