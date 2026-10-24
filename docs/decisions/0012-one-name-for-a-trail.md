# 12. One name for a trail, everywhere

- Status: accepted, amended by [ADR 13](0013-workspaces-are-sessions-trails-are-windows.md) (the session is
  `<workspace>/<name>`) and [ADR 19](0019-no-agents-files-read.md) (no `@name` badge or
  `peer` column)
- Date: 2026-10

## Context

A trail had several handles, and none of them was one you could tell another agent:

| Handle | Problem |
|---|---|
| tmux session, `trails-checkout-2` | says nothing about the work, and Claude's peers never see it |
| conversation ID | the only one that survives tmux, but a UUID |
| task title | readable, but it changes as the agent works, and isn't unique |
| Claude's peer name | what one Claude session messages another by, but derived when not set, like `trails-20` |

The use that made this matter is one Claude session asking another for something:
"ask payments how the retries look". Claude Code addresses peers by their display
name, which `claude --name` sets. Measured on Claude Code 2.1.300:

- `--name` sets the peer name (`nameSource: user` in its sessions file).
- It also pins the terminal title. Claude never replaces a named session's title
  with a summary, and writes no `ai-title` for it.
- It is stored in the conversation as a `custom-title`, so `--resume` brings the
  name back without `--name`.

## Decision

A trail can be named when it starts, with `trails new NAME [AGENT]` or ctrl-n on a
picker row. The name is used as is in every place:

- the tmux session is `trails-<name>`
- the agent gets it through a `session.name` template in its config, `--name {name}`
  for claude
- the picker and `trails ls` badge it `#<name>`, in the slot an unnamed trail's
  `#2` uses

A name is letters, digits, `-` and `_`, not digits alone, and free: no running
session and no record holds `trails-<name>`. Checking the session namespace is
enough for Claude too, since both are machine-wide. Only a fresh start passes the
name to the agent. Resuming a named conversation asks for `trails-<name>` back.

Naming is opt-in. An unnamed trail keeps today's `trails-<project>-N` and lets Claude
pick its own name.

## Consequences

- One word reaches a trail from tmux, from trails and from another Claude session.
- A named Claude loses its task summary: its title is its name. That is why naming
  isn't the default, and why the row drops a title that only repeats the name.
  Closed rows show `#<name> · <last prompt>`.
- `/rename` inside Claude changes its peer name and conversation title, but not the
  tmux session, until the conversation is next resumed.
- Agents without a `session.name` still get the tmux name and the badge, but no name
  of their own. Claude is the only agent with peer messaging today.
- The picker now runs fzf with `--print-query`, and ctrl-n turns search off so the
  name being typed doesn't filter the row away.
- Every running Claude shows its peer name as `@<name>` in `trails ls`, the picker
  and the map, and in the TSV's `peer` column. That covers unnamed trails, whose
  derived name trails had no other way to show, and a `/rename` the tmux name hasn't
  caught up with. The column goes before `title`, so readers that split the TSV
  positionally, such as the menu-bar plugin, name it to keep the title whole.
