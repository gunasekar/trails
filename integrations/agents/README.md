# Agent integrations

Each directory packages Trails status hooks in the agent's native plugin format.
The same `hooks/hooks.json` file can be installed manually; there is one source
for both installation methods.

| Agent | Plugin setup | Manual destination |
|---|---|---|
| [Claude](claude) | `/plugin install trails@trails` after adding this repository's marketplace | Merge into `~/.claude/settings.json` |
| [Codex](codex) | Local repository marketplace, then `codex plugin add trails@trails` | `~/.codex/hooks.json` |
| [Cursor](cursor) | `cursor-agent --plugin-dir /absolute/path/to/trails/integrations/agents/cursor` | `~/.cursor/hooks.json` |

Install the plugin or merge its hooks, not both. Keep unrelated handlers in existing
configuration. `trails` must be on the agent's hook `PATH`. The hooks report status;
they do not install Trails itself. Codex additionally requires trust review with
`/hooks` after installation or hook changes.

Codex and Cursor are not published in their public plugin directories. See each
integration's README for local setup, update behavior, and verification limits.
