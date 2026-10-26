# 23. The task in the status line, and a trail renamed as it runs

- Status: accepted
- Date: 2026-10

## Context

Since [ADR 22](0022-an-unnamed-trail-is-named-by-its-id.md) an unnamed trail's window is
`augur-3f9a`: unique, and saying nothing about the work. What the work is, trails already
knows without asking any agent: an agent titles its terminal (OSC 2), Claude with its
summary of the conversation, and the trail's session passes it on as `<agent> · <task>`
(`TRAIL_TITLE`), which the picker's task column and the record's `task=` read.

That title is the agent's, and it does not follow the work. Claude sets its summary early
and keeps it: a trail started on one question and carried on to others still reads as the
first. Only you know when the work has moved on.

## Decision

- **The current trail's task is at the right of the status line**, before the checklist's
  count: `trails keys` puts it first in `status-right`, cut at 40 characters, and raises
  `status-right-length` to 80 to hold it. Read from the current window's agent pane with
  `#{P:}`, as tmux draws the bar, so it follows the title with nothing of trails running. A
  title that only repeats the codebase, the hostname seed or an empty one shows nothing.
- **At the right, for the current trail only.** After each window's name, six trails with
  their tasks run past a laptop's width, and even the current one's alone pushes the window
  list about as it changes; at the right it has room of its own. The others' are in the
  picker, a key away.
- **A named trail shows nothing there.** Its name, in its window's name, is yours, and says
  what you meant.
- **A trail can be named while it runs**: `trails rename [TRAIL] NAME`, `prefix R` (tmux's
  own prompt), or ctrl-r on its row in the picker. An empty name takes it away. The name is
  checked as a new trail's is.
- **A rename is a label, not an address**: `@trails_name`, the windows' names, the badge and
  the record's `name=` change; the session does not. The wrapper was handed the session's name
  at launch and gives the trail's window back by it when the agent exits, and it can't be
  told of a new one.

## Consequences

- No agent integration: any agent that titles its terminal shows a task, and one that does
  not shows its window's name alone, as before.
- A trail renamed while it runs has a session `lattiq/augur-3f9a` and a name `payments`, where
  one named at start has `lattiq/payments`. Both show the name everywhere but `tmux a -t`.
  The next restore brings a renamed trail back as `<workspace>/<name>`, and the two meet.
- The agent keeps the name it was started with (`session.name`, Claude's `--name`): trails
  can't reach into it.
- `status-right` was trails' already; a tmux.conf that sets its own after the `trails keys`
  line keeps its own, without the task or the count.
- `prefix R` is taken.
