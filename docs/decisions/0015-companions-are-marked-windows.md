# 15. Companions: the editor and a shell as marked windows beside a trail

- Status: accepted
- Date: 2026-10

## Context

The design's R7 puts the agent first: a trail is the unit, and the editor is
brought up beside it when wanted, over SSH where no desktop editor is running.
A workspace holds unrelated repos, so "the editor" has to mean the editor for
one codebase, and opening it twice must not make two.

## Decision

`trails edit` makes an ordinary window in the workspace session beside the
codebase's trails, named like a trail's (`augur·ide`, `augur·nvim`) and marked
`@trails_companion` with the codebase on it. `trails shell` is a pane across
the bottom of that window, marked `@trails_shell`.

- **The window you are on decides the codebase.** From a trail or another
  companion, that one's directory; from a plain window, the pane's directory;
  outside tmux, the current directory, or a directory given after the command.
- **One of each kind per codebase.** Run again, the command selects the window
  that is there. Run from the companion itself, it goes back with
  `last-window`.
- **`edit`** runs `$EDITOR`, nvim if unset, beside the codebase's trail when one
  runs (the trail you run it from, else the one there that most wants you), and
  alone only when none does. **`shell`** runs tmux's own default command, in a
  pane a quarter high along the bottom of the editor's window (amended 2026-10:
  it was a window of its own, and a shell wants to sit under the editor and the
  agent, not beside them in the window list). Amended 2026-10: the design had a third command, `ide`, for the side-by-side
  outright and `edit` for the editor alone; the first live use showed an editor
  alone is never wanted next to a running agent, so `edit` took the side-by-side
  and `ide` went. `C-b z` gives the editor the whole window when wanted.
- **Never a split in a trail's window**, which the editors attached to that
  trail would see: the shell splits the editor's window, a layout window no
  editor attaches to. Never a shell at the workspace level.
- The picker lists companions on both trail screens, goes to one on Enter and
  closes one on ctrl-x; ctrl-e opens the editor for the row's codebase. An
  editor's terminal sees no companion rows: it wants trails only (R9).
- Companions are not restored. An editor or a shell is reopened with one
  command.

## Consequences

- An SSH session to the agent machine can have the editor one key away from
  the agent, in the same tmux client, without a tmuxinator layout to keep.
- The toggle back is tmux's "where I was", which may be any window, not
  specifically the last trail.
- Directories are compared resolved, because tmux reports a pane's path through
  symlinks and a trail keeps the path it was started by.
- `trails keys` suggests `prefix e` and `S` for the two, checked free in tmux
  3.8's default table. trails binds nothing itself.
