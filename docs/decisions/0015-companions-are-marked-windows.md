# 15. Companions: the editor and a shell as marked windows beside a trail

- Status: accepted
- Date: 2026-10

## Context

The design's R7 puts the agent first: a trail is the unit, and the editor is
brought up beside it when wanted, over SSH where no desktop editor is running.
A workspace holds unrelated repos, so "the editor" has to mean the editor for
one codebase, and opening it twice must not make two.

## Decision

`trails edit`, `trails shell` and `trails ide` make an ordinary window in the
workspace session beside the codebase's trails, named like a trail's
(`augur·nvim`, `augur·shell`, `augur·ide`) and marked `@trails_companion` with
the codebase on it.

- **The window you are on decides the codebase.** From a trail or another
  companion, that one's directory; from a plain window, the pane's directory;
  outside tmux, the current directory, or a directory given after the command.
- **One of each kind per codebase.** Run again, the command selects the window
  that is there. Run from the companion itself, it goes back with
  `last-window`.
- **`edit`** runs `$EDITOR`, nvim if unset. **`shell`** runs tmux's own default
  command. **`ide`** puts the editor beside a nested client of a trail's editor
  view (ADR 14): the trail you run it from, else the codebase's trail that most
  wants you; with none it says so and makes nothing.
- **Never a split in a trail's window**, which the editors attached to that
  trail would see, and never a shell at the workspace level.
- The picker lists companions on both trail screens, goes to one on Enter and
  closes one on ctrl-x; ctrl-e opens the editor for the row's codebase.
- Companions are not restored. An editor or a shell is reopened with one
  command.

## Consequences

- An SSH session to the agent machine can have the editor one key away from
  the agent, in the same tmux client, without a tmuxinator layout to keep.
- The toggle back is tmux's "where I was", which may be any window, not
  specifically the last trail.
- Directories are compared resolved, because tmux reports a pane's path through
  symlinks and a trail keeps the path it was started by.
- `trails keys` suggests `prefix e`, `v` and `S` for the three, checked free in
  tmux 3.8's default table. trails binds nothing itself.
