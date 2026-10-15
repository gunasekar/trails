# 14. An editor attaches to a view: a session holding one linked window

- Status: accepted
- Date: 2026-10

## Context

With trails as windows in a workspace session (ADR 13), an editor's terminal
attaching to the workspace would follow whatever window you browse to, since
every client of a session shares its current window. An editor's panel must
show one trail and nothing it can wander off to (R9 in the design), while the
workspace session moves freely for the terminals attached to it.

## Decision

Every trail's window is also linked, with `link-window`, into a small session
of its own: the **editor view**, named `<workspace>/<codebase>[-N]`, or
`<workspace>/<name>` for a named trail. It holds that one window and nothing
else, so an editor attached to it sees one trail. The view is made with the
trail, rebuilt by the next attach if it was killed, and goes by itself when the
agent exits, since the window leaves both sessions.

Where an attach lands depends on who is asking:

- **An editor's terminal** attaches to the view. nvim sets `NVIM` in its
  terminals, Zed sets `ZED_TERM`, and both Zed and VS Code set `TERM_PROGRAM`;
  inside tmux, where tmux overwrites `TERM_PROGRAM`, the first two tell. Inside
  tmux the editor's pane becomes a nested client of the view, as a map cell is.
- **A terminal of your own** attaches to the workspace with the trail's window
  selected, and inside tmux the client is switched there.
- `TRAILS_ATTACH=view` or `=workspace` overrides the guess, and trails strips
  `NVIM` and `ZED_TERM` from the environment it starts a tmux server with, so a
  server begun from an editor's terminal does not make every later pane look
  like one.

The view's name is also the trail's record key, so `tmux a -t lattiq/payments`,
the record file and the `session` field of `trails ls` all say the same thing.
A name is checked free against running trails, old sessions and records before
it is used.

## Consequences

- A trail shows up twice in `tmux ls`, once as a window of its workspace and
  once as its view. Both are named for what they are, and the design's
  principle 5 (nothing hidden) is met by saying so in the docs.
- The map's cells attach to views, which already hold exactly one trail, and
  make a missing view before attaching.
- A view that a user kills is not a lost trail: the window lives on in the
  workspace, and a record is alive while any window carries its key and
  conversation.
- Listing a trail from its window reads it from the workspace session's row and
  skips the view's, so one `list-windows -a` lists every trail once.
- Detecting an editor by environment is a guess. The override exists because
  the guess will be wrong somewhere, and the failure either way is only which
  of two right things you land in.
