# Trails for Codex

A native Codex plugin that reports working, waiting, and idle status to Trails.
Requires `trails` on the hook's `PATH`.

From a local checkout of this repository:

```sh
codex plugin marketplace add .
codex plugin add trails@trails
```

Open `/hooks`, review and trust the plugin's hooks, then start a new session.
Each handler has a descriptive `statusMessage`, such as `Trails: tool started`
or `Trails: waiting for approval`, so it is recognizable in Codex.
Changed hooks, including label changes, require a new review. Remove previously
installed manual Trails handlers from `~/.codex/hooks.json` before enabling the plugin; preserve unrelated
hooks. Installation does not automatically trust hooks.

The repository catalog is `.agents/plugins/marketplace.json`; the native manifest
is `.codex-plugin/plugin.json`. No public directory listing is required. OpenAI
currently excludes lifecycle-hook plugins from its public directory. See
[OpenAI plugin packaging](https://developers.openai.com/plugins/build/plugins).

After updating the checkout, reinstall with `codex plugin add trails@trails`
to refresh the cached copy. Restart Codex and review changed hooks with `/hooks`.

For manual installation, copy `hooks/hooks.json` to `~/.codex/hooks.json`, or append
its handlers to matching event arrays if the file already exists. Use the plugin
or manual setup, not both.

Codex 0.165.0 successfully installed this plugin in an isolated configuration, and
its runtime discovered all seven hooks as enabled plugin hooks requiring trust.
The installed user hooks were also trusted in a live Codex trail, which then
reported working. Permission, interrupt, and session-start transitions have not
all been exercised live.

Trails' Codex agent runs `codex --no-daemon`. Codex 0.166's TUI otherwise runs its
turns, and the hooks, in a shared background server started from some other
terminal, whose `TMUX_PANE` is not the trail's, so the hooks reach no trail. Add
`--no-daemon` to the `program` of a Codex agent in your own config.

`SessionStart` and `Stop` pass the hook input's `session_id` to Trails (`--id`), the
ID `codex resume` takes, so a Codex trail is restored after tmux dies. Hooks
installed before this need a new review in `/hooks`.
