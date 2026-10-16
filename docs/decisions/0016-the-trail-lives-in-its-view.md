# 16. The trail lives in its view, and the workspace shows it through a cell

- Status: accepted
- Date: 2026-10

## Context

ADR 13 made a trail a window in its workspace session, and ADR 14 linked that
window into a session of its own, the view, for editors to attach to. ADR 15
then had to keep the editor and the shell out of the trail's window: a linked
window is one window, so every client of the view, the editor's panel among
them, would see the split. The companions went into a separate window with a
nested client of the view beside the editor.

Live use said the opposite of that layout. On a trail, one key should put a
shell along the bottom of *this* window and the editor beside the agent in it,
and an editor attached to the trail should still see the agent and nothing else.
Those two cannot both hold while the trail's window is the one the view holds.

## Decision

Turn the nesting around. **The trail is its view**: a session named
`<workspace>/<codebase>[-N]` or `<workspace>/<name>`, holding one window with
the agent in it, made first by `launch` with `status off`. **The workspace shows
it through a cell**: a window in the workspace session named like the trail,
marked `@trails_cell` with the trail's key, whose first pane is a tmux client
attached to the view, the way a map pane views an agent. Nothing is linked.

- **The editor and a shell are panes of the cell** (`@trails_pane` `edit`,
  `shell`), beside the view pane. The view holds the agent alone, so an editor's
  panel or a map pane never sees them. ADR 15's refusal to split a trail's window
  is withdrawn: the cell is no editor's window. The layout follows from which
  panes exist (`cell_layout`): the editor on the left 60% with the view on the
  right, the shell along the bottom when alone with the view and under the
  editor when there is one.
- **A cell is rebuilt, a view is not.** A killed cell is remade by the next
  attach from a terminal (`ensure_cell`); a view that is gone is a trail that is
  gone. The view goes when the agent exits, and the cell's client with it.
- **A cell with panes beside the agent outlives it** as a companion window of the
  codebase (`cell_release`): renamed for the editor, or `<codebase>·shell`, and
  marked `@trails_companion`. Run by the agent's wrapper on exit and by `trails
  end` and ctrl-x before they kill the view. Nothing you had open is killed for
  you.
- **Views get `status off`.** They are trails' own sessions, only ever looked at
  through a cell, an editor's panel or a map pane, each with a frame of its own;
  a status line inside that frame reads as a second tmux. Principle 3 (nothing
  set on the user's objects) is read as what it says: a view is not the user's.
- Records, their keys, `trails ls`, the menu-bar plugin, the map and 0.6 sessions
  are unchanged. `trail_wid` still names the agent's window; `cell_wid` names the
  cell.

## Consequences

- One window per trail in the workspace: agent, editor if you want it, shell if
  you want it. The editor-beside-trail window kind (`·ide`) and `@trails_of` go.
- tmux gives a window one size. A view shown by two clients of different shapes,
  a cell and an editor's panel, is sized to the one you last typed in
  (`window-size latest`), and the other sees it clipped or filled. The map had
  this already; now every trail an editor has open does. Accepted, as a known
  cost of tmux.
- Keys to the agent cross two tmux layers in a cell, as in the map: the prefix
  goes to the outer, and the inner's copy mode needs the double prefix. The
  mouse wheel reaches the inner, which has the scrollback.
- `tmux ls` reads as before: the workspaces, with a window per trail, and the
  views by key. `tmux a -t acme/checkout` is still one trail.
- The listing drops the view-row skip of ADR 14: a trail's window lists once, in
  its view, and a cell has no `@agent`.
- Each cell is one more tmux client process. Light, and bounded by the trails.
