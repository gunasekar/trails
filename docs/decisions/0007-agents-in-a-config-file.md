# 7. Agents live in a config file

- Status: accepted
- Date: 2026-10

## Context

Which agents trails could start, with which flags, was a table inside the script.
Adding an agent, pointing one at a different model, or fixing a flag a CLI renamed
meant editing trails itself. Agent CLIs change their flags often, and people run
the same CLI several ways (claude with and without `--model opus`, aider against
a local model).

## Decision

Agents move to `~/.config/trails/config.json`, in the shape claude-squad uses:
a `name` and the `program` it runs, plus two optional fields of trails' own:

- `yolo`, the flag Tab adds for a run-everything-unconfirmed launch
- `session`, the `start` and `resume` templates (with `{id}`) and the ID shape
  that let trails choose a conversation ID and bring it back after tmux dies

Two top-level keys sit beside the list: `default_agent`, listed first, and
`mode`, `default` (the agent's own, prompting mode) or `yolo`, the mode a new
launch starts in. Tab flips a
row from that default rather than always meaning "arm". A value other than those
two reads as `default`: a typo must never decide to run every agent unconfirmed.

The built-in agents are the same JSON, inside the script, and apply until the
file exists. `trails config` writes them out as a starting point. Agents whose
command is not on `PATH` are not offered. JSON is read with `jq`.

## Consequences

- Adding or changing an agent is an edit to a JSON file, never to trails.
- `jq` becomes a dependency. macOS ships it, and the Homebrew formula depends on it.
- `program` is split on spaces with no shell quoting; anything fancier belongs in
  a wrapper script.
- Recent conversations are still read only from claude's and opencode's own
  stores, and are filed under the first agent that runs that command.
- A broken config stops the picker with the parse error, but not `trails ls`, so a
  menu bar polling it keeps working.
