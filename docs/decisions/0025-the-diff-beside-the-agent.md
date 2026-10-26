# 25. The diff beside the agent

- Status: accepted. Amended in 1.14: the diff is asked for with `prefix G`, never opened by
  the width, since a pane that isn't needed costs memory (Hunk idles at ~120MB, a few
  hundred with a large diff, one per trail) and the agent's room, and the editor and the
  shell are asked for too
- Date: 2026-10

## Context

On a wide screen a trail's agent fills the window, and its conversation runs the width of
it: 341 columns on a 26" monitor, far past a readable line. Narrowing the agent leaves the
rest of the window to fill. What people put beside an agent is the editor, a shell, and
above all the changes it is making, watched as they land; trails had the first two as panes
and the third only as a popup snapshot (`prefix G`).

The viewer has to be live, read-only, side by side with whole files, and scroll long lines
without breaking the columns. lazygit with delta came close but is a git client (a stray
key stages or discards) and cannot scroll a side-by-side diff sideways, since delta has cut
the lines before lazygit sees them. Hunk, a review-first diff viewer, does all of it,
though as one stream of files rather than one file at a time.

## Decision

- **A fourth pane kind, `diff`**: Hunk on the trail's codebase, `hunk diff --watch`, with
  git's `diff.context` set to 99999 for that run so every file is whole. How it looks is
  the user's Hunk config.
- **One slot on the right.** The right side, 60% beside the agent's 40%, holds the editor
  or else the diff, never both; the editor takes it, and when the editor ends the diff
  comes back. A shell goes under whichever, a quarter high.
- **Asked for, with `prefix G`**, per window, and remembered (`@trails_diff`): `G` again,
  or quitting Hunk with `q`, puts it away. Never by itself, at any width (1.13 opened it on
  a window 200 columns wide or more; see the amendment above). Where the diff can't be
  shown (no trail's window, no Hunk, no git repository, the editor on the right), `prefix
  G` is the popup it was.
- **The trail's**: the agent leaving takes it, where the editor and shell stay.

## Consequences

- A trail opens as the agent alone, as before; `G` puts the diff beside it, the agent at
  40%, a readable width on a wide screen.
- Hunk is optional: without it nothing changes, and `trails diff` and the popup stay.
- `prefix G` changes meaning on a trail's window, from a snapshot to a live pane. The popup
  is still `trails diff`, and `prefix G` anywhere else.
- The diff pane has `allow-passthrough` off: Hunk's startup questions to the terminal,
  passed through, came back as keystrokes into the agent's pane.
- The editor and the diff can't be seen together; CodeDiff, from the editor, is the deeper
  review when the live view isn't enough.
