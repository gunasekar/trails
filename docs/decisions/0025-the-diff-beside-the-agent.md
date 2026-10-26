# 25. The diff beside the agent

- Status: accepted
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
- **On by width.** It opens by itself on a window 200 columns wide or more (40% of 200 is
  80, as narrow as an agent's screen goes) and goes when the window narrows; the layout
  runs again on `window-resized`.
- **`prefix G` overrides it**, per window: shown on a narrow window, put away on a wide one,
  remembered (`@trails_diff`). Quitting Hunk with `q` puts it away too. Where the diff
  can't be shown (no trail's window, no Hunk, no git repository, the editor on the right),
  `prefix G` is the popup it was.
- **The trail's**: the agent leaving takes it, where the editor and shell stay.

## Consequences

- On a wide screen a trail opens as agent and diff, the agent at a readable width.
- Hunk is optional: without it nothing changes, and `trails diff` and the popup stay.
- `prefix G` changes meaning on a trail's window, from a snapshot to a live pane. The popup
  is still `trails diff`, and `prefix G` anywhere else.
- A trail's window carries a `window-resized` hook, set on every layout, so a trail from
  before this gets it on its next attach.
- The diff pane has `allow-passthrough` off: Hunk's startup questions to the terminal,
  passed through, came back as keystrokes into the agent's pane.
- The editor and the diff can't be seen together; CodeDiff, from the editor, is the deeper
  review when the live view isn't enough.
