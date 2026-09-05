## Troubleshooting

**A git error while installing this plugin is not evidence of an auth or permissions problem.** Every repository behind this plugin is public, clones clean (no illegal Windows filename characters, no case collisions, no reserved DOS names), and needs no credentials — so when a clone or fetch fails, the cause lives in *your* environment or in how a marketplace declared its source, never in a broken or private repo. It is never a permissions problem with the plugin itself.

All three causes below present as the same undifferentiated "git error," and their fixes have nothing in common — match your error text to a cause before changing anything:

| Your error names... | Cause |
|---|---|
| `Host key verification failed`, `No ED25519 host key is known for github.com` | The marketplace declared its source with the GitHub `owner/repo` shorthand, which clones over SSH by default |
| `SSL certificate problem: unable to get local issuer certificate` | Corporate TLS interception |
| `detected dubious ownership in repository` | Git's dubious-ownership check |

### Cause 1: the GitHub shorthand source clones over SSH by default

The literal error:

```
Failed to install: Failed to clone repository: Cloning into 'C:\Users\...\.claude\plugins\cache\temp_github_...'...
No ED25519 host key is known for github.com and you have requested strict checking.
Host key verification failed.
fatal: Could not read from remote repository.
```

Per Claude Code's own documentation: a marketplace entry that declares its source as `{"source": "github", "repo": "owner/repo"}` — the GitHub `owner/repo` shorthand — clones over **SSH** by default, not HTTPS; set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` to make it clone over HTTPS instead. This marketplace's entries used exactly that shorthand for three fully public repositories that need no credentials at all, so Claude Code silently chose SSH for a request that had no reason to need it. With no `github.com` entry in `known_hosts` — normal for anyone who has never pushed over SSH from that machine — strict host-key checking rejects the clone before it starts.

This reads as a broken plugin rather than as a protocol choice, because nothing about installing a public plugin suggests SSH is involved: the reader never typed `git@github.com`, never touched their own git config, and the failure has the same "clone failed" shape a real permissions problem produces. The actual decision — HTTPS vs. SSH — was made by the marketplace entry's source type, on the reader's behalf, before git ever looked at anything on their machine.

**This is fixed in the marketplace as of now.** `trinity-ai-labs/claude-plugins` declares all three plugins with an explicit `{"source": "url", "url": "https://github.com/....git"}`, which Claude Code takes verbatim and clones over HTTPS — so a current install will not hit this. If you're pinned to an older marketplace entry, or you hit this same error shape installing from a *different* marketplace that still uses the `github` shorthand, set the escape hatch in your Claude Code settings:

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_PREFER_HTTPS": "1"
  }
}
```

> **If you publish a marketplace:** prefer an explicit `{"source": "url", "url": "https://github.com/owner/repo.git"}` over the GitHub `owner/repo` shorthand for public plugins. The shorthand clones over SSH by default, which silently requires an SSH key and a trusted host key your users have no reason to have for a repo that needs neither — turning a working public install into a "broken plugin" report that traces back to the marketplace manifest, not their machine.

### Cause 2: corporate TLS interception

Presents as:

```
SSL certificate problem: unable to get local issuer certificate
```

Your network is intercepting TLS and presenting a certificate signed by a corporate CA that git doesn't trust. Point git at that CA bundle instead of rejecting it:

```
git config --global http.sslCAInfo /path/to/corporate-ca-bundle.pem
```

**Never** `git config --global http.sslVerify false`. Disabling verification to get one clone through leaves it disabled for every fetch afterward, silently — the fix for today's clone becomes a standing hole that makes every future fetch on that machine interceptable without warning.

### Cause 3: dubious ownership

Presents as:

```
fatal: detected dubious ownership in repository at 'C:/...'
```

Fix:

```
git config --global --add safe.directory <path>
```
