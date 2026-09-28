# The repository description

Chapter of the root [AGENTS.md](../../AGENTS.md): the rule for changing the front-door command chain or the
hosts the plugin ships for.

- **The repo's GitHub description — the About panel, set with `gh repo edit --description` — names the
  current front-door command chain and which hosts the plugin ships for, and whoever changes either updates
  it in the same change**, since it is a repository setting rather than a file: it is never in a diff, so no
  check here can catch it drifting behind what README's own opening lines already say.
