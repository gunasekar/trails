# Trails for Cursor

A native Cursor plugin that reports working and idle status to Trails.
Requires `trails` on the hook's `PATH`.

Load from a local checkout:

```sh
cursor-agent --plugin-dir /absolute/path/to/trails/integrations/agents/cursor
```

The flag applies to each invocation. To load the plugin in the Trails picker,
run `trails config` and append `--plugin-dir` and the absolute plugin directory
to your existing Cursor agent's `program`. Keep the other agent fields, including
its session configuration. Trails splits `program` on spaces, so use a checkout
path without spaces.

The native manifest is `.cursor-plugin/plugin.json`, which references
`hooks/hooks.json`. See [Cursor plugin formats](https://cursor.com/docs/reference/plugins).
This plugin has not been published to Cursor's marketplace. Local loading reads
the checkout; update the checkout and restart the CLI to pick up changes.

For manual global setup, copy `hooks/hooks.json` to `~/.cursor/hooks.json`, or append
its handlers to matching event arrays if the file already exists. Preserve
`version: 1`. Manual global hooks also apply to the editor. Use the plugin or
manual setup, not both; remove only old Trails handlers when switching.

The hooks cover prompt submission, generic pre/post tool calls, shell and MCP
calls, session start, and completion. Pre-hooks return the JSON response required
to let the prompt or call proceed. No documented permission-request event exists,
so permission prompts continue to show working.

Cursor CLI 2026.10.22-27dcf5f loaded a temporary copy of this plugin during a live
headless check. Session start, generic pre/post tool, and pre/post shell hooks
fired. Prompt-submit and completion hooks did not fire in that run; interactive
completion and MCP events remain unverified. Check `trails ls` during and after
an interactive turn before relying on completion status. Manual hooks use the same
events and do not fix skipped lifecycle callbacks.

Cursor CLI also skips `sessionStart` when invoked with `--resume`. Trails creates
a chat and then launches it with `--resume`, so a newly opened Cursor trail can
remain unknown until a later hook fires. This affects both plugin and manual
setup; installing the hooks does not initialize an already open trail.

Hook commands and pre-hook JSON responses have also been checked with simulated
tmux. Native plugin loading is verified; full lifecycle parity is not.
