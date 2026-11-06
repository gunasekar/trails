# 30. One picker, one list

- Status: accepted, built in 1.21
- Date: 2026-11
- Supersedes in part: [ADR 17](0017-one-picker-levels-not-screens.md), its levels

## Context

[ADR 17](0017-one-picker-levels-not-screens.md) made the picker one thing at
four levels: workspaces, workspace, codebase, agent. Since then two more popups
came: every running trail (`prefix A`) and the tree (`prefix W`, a click on
`[session]`, [ADR 28](0028-a-tmux-native-server-that-tells-you-what-waits.md)),
which is the only place to star a trail. The three overlap, and each lacks what
another has: the picker shows one level at a time, `A` shows no lost trails and
no way to start one, the tree no details and no preview.
`docs/design/one-picker.md` draws them side by side.

## Decision

**One popup, the picker, with one list of everything**, opened by `prefix P`, a
click on `[session]` and a bare `trails`.

- **Grouped by workspace**, the one you're in first: a header per workspace
  saying what it holds, then its trails, lost trails and editor and shell
  windows in its window order, with the window number. A trail is named as its
  window is (`checkout-3f9a`, `checkout·payments`), not by the old `#` badge.
  Then the sessions of yours, then `↩ resume old trails` across every workspace.
- **A trail's row has what `prefix A` shows**: ★, state word, how long it has
  waited, codebase, agent · yolo, task. No preview: the list is for starting a
  trail and going to one, and the row says what a trail is doing.
- **Lost trails sit in their workspace**, beside their codebase's trails, and
  Enter restores one.
- **The map has no row**, nor a key in the list: `prefix M` goes to it or
  builds one. It is not a session of yours either.
- **`＋ new trail…` is the workspace you're in**: its codebase tree, the cursor on
  the codebase you're in, then the agents. A folder the tree doesn't list goes
  straight to its agents. On a trail's window the codebase is known, but a trail
  in another codebase of the workspace has to be one Enter away too.
- **Enter on a workspace's header starts a trail there**, as `＋ new trail…` does
  for the one you're in: its codebase tree, then the agents, whatever is running.
  Its trails and windows are rows under it; going "into the workspace" landed on
  a window you didn't pick.
- **The keys act on the highlighted row**: Enter goes there, ctrl-s stars, ctrl-r
  renames, ctrl-x ends, forgets or closes, ctrl-e opens the editor, ctrl-n makes
  a workspace. Esc closes the list, and goes back to it from the agents and the
  old trails. Typing filters, in the list's own order (`--no-sort`).
- **`prefix W` and `prefix A` go**, with `trails tree`, `ctrl-a` and the
  workspaces and workspace screens.
- **Kept from ADR 17**: `＋ new trail…` and its codebase tree (D2, D5, D6),
  `default` (D7), ctrl-n makes one (D3). Not D1: Enter on a workspace starts a
  trail there rather than attaching.
  An editor's terminal still sees one codebase ([ADR 14](0014-editor-views.md)).

## Consequences

- One key to remember, and everything is a filter away: a trail in another
  workspace no longer means going up a level or opening another popup.
- The list is longer than one workspace's screen. Typing filters it, the
  current workspace is first, and `prefix F` still jumps to the starred trail
  that most wants you.
- Opening it classifies every trail, as `A` does, rather than one workspace's.
- Rows are in window order, not by state: the list matches the status line,
  and the headers and `prefix F` say what wants you.
- Two keys (`W`, `A`) are free again.

## Alternatives

- **Flat, what wants you on top.** Best for triage, but a trail moves as its
  state does, and the list no longer matches the status line. Rejected (Q1).
- **The map as a row, or a key in the list.** Built first as a row under
  `＋ new trail…`; it was another kind of row for a place `prefix M` already
  reaches, and `ctrl-m` is Enter to a terminal. Removed.
- **A preview of the highlighted trail.** Built first, as `P` and `A` had it;
  unused, and it made the popup a viewer rather than a list. Removed.
- **Keep the tree for the click.** A smaller popup for a quick look, but a
  second list with keys of its own, which is what this ends. Rejected (Q2).
- **Lost trails together at the bottom.** Easier to sweep, but they belong to a
  codebase, and restoring one is about that codebase. Rejected (Q3).
