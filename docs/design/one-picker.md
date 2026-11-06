# One picker: design

Status: implemented · 2026-11-07, in one change rather than the three phases
below. Since: no map row, no preview, and Enter on a workspace's header starts a
trail there (see ADR 30). [ADR 30](../decisions/0030-one-picker-one-list.md) records the decisions
that outlive this document. Where the build differs from the proposal, the
section says so under **As built**.

trails opens three popups that overlap: the picker (`prefix P`), every running
trail (`prefix A`) and the tree (`prefix W`, or a click on `[session]`). Each
shows part of the same thing, and each has keys the others lack. This
document draws them, the one popup that replaces them, and the way there.

## Today

| | picker `P` | all trails `A` | tree `W` / click |
|---|---|---|---|
| what it lists | one workspace's or one codebase's trails, a level at a time (ADR 17) | every running trail, flat, by state | every workspace and its windows, then the sessions that aren't trails' |
| a trail's row | state, codebase, agent · yolo, badge, ago, task | state, workspace/codebase, agent · yolo, badge, ago, task | ★, name, ● state, ago |
| lost trails | yes, Enter restores | no | no |
| your windows | editor and shell windows | no | yes, as *yours* |
| new trail, resume old | yes | no | no |
| preview | the agent's screen, live | the agent's screen, live | no |
| keys | enter, ctrl-e, ctrl-x, ctrl-/, ctrl-a, ctrl-n, esc up a level | enter, ctrl-e, ctrl-x, ctrl-/, esc back | enter, ctrl-s, esc |
| the map | no | no | under *yours*, as `▦ map` |

To star a trail you open the tree; to see what it is doing, the picker or `A`;
to start one, the picker. To see what another workspace is doing, `A` or the
tree, but not the picker's level you're on.

## Proposed

One popup, the picker, with one list: every workspace's trails and windows,
grouped by workspace, the one you're in first, with the details `A` shows today
and a live preview of the highlighted trail.

```text
trails ▸ █                         enter: go · ctrl-s: star · ctrl-r: rename · ctrl-x: end · ?: keys
▌ ＋ new trail…                    in trails (personal)
  ▦ map                            4 trails · almanac-1112 needs you
  personal                         3 trails · 1 your turn
  ▸ 1 trails-c6         ★ your turn  12m  trails      claude          Fix the flaky cart test
    2 dotfiles-8e         working         _dotfiles   claude · yolo   Tidy zsh startup
      cart-71             lost            trails      claude          enter restores it
    3 notes               editor          trails
  lattiq                           2 trails · 1 needs you
    1 almanac-1112      ★ needs you   4m  almanac     codex           Which migration first?
    2 billing-3f          working         billing     claude          Split the invoice job
  default                          nothing running
  ── yours ──
    scratch
  ↩ resume old trails              (7 ended)
──────────────────────────────────────────────────────────────────────────────
  (the highlighted trail's screen, as it is now)
```

### The rows, top to bottom

1. **`＋ new trail…`**, for the workspace you're in. Where a codebase is known (a
   trail's window, a codebase's directory) it goes straight to the agents, as a
   codebase's screen does today; otherwise to that workspace's codebase tree and
   `browse…` (ADR 17's D5, D6, unchanged).

   **As built:** always the workspace's codebase tree, the cursor on the codebase
   you're in, so Enter twice still starts there. Straight to the agents, a trail
   in another codebase of the workspace had no way in from a trail's window. A
   folder the tree doesn't list (one no workspace claims) still goes straight to
   its agents.
2. **`▦ map`**, only while a map is up: its own row, not one of yours. It says
   how many trails it holds and the one that most wants you. Enter goes to it,
   ctrl-x closes it (the trails stay, the map only borrowed them).
3. **A workspace's header**, then its rows. Every workspace the config names is
   listed, `default` too when it holds anything, the one you're in first and the
   rest by name. The header says what it holds: `3 trails · 1 your turn`, or
   `nothing running`. Enter on it goes to the workspace, starting its session
   if it isn't up (today's D1: the trail that most wants you).
4. **A workspace's rows, in its window order**, the order of its status line, with
   the window number, so `★ 1` in the status line is row `1` here:
   - **a trail**: ★, number, name, state word, how long it has waited (needs you
     and your turn only), codebase, agent (· yolo), task. Enter goes to it.
   - **a lost trail**, after the trails of its codebase, or at the end of its
     workspace when it has no running trail: no number, `lost` in the state
     column, `enter restores it` in the task's. Enter restores it.
   - **an editor or shell window**: number, name, `editor` or `shell`, its
     codebase. Enter goes to it.
5. **`── yours ──`**: tmux sessions that are neither a workspace nor a trail's,
   ones you made. Enter switches to one.
6. **`↩ resume old trails`**, with how many ended: every workspace's, one list,
   with a workspace/codebase column, newest first. Enter on one resumes it in
   its workspace. Tab toggles YOLO there, as today.

The state is a word in its colour (*needs you* red, *your turn* yellow, the
rest dim), with no ● in front: the word says it, and ● reads as *something
here*, not as which state.

### Keys

| key | on | does |
|---|---|---|
| typing | anywhere | filters the rows, every column searchable, in the list's order (as built: a header shows only when its own text matches; fzf has no way to keep it for its rows) |
| enter | any row | goes there: the trail, window, workspace, map or session; restores a lost trail |
| ctrl-s | a trail | stars or unstars it (as `prefix S`) |
| ctrl-r | a trail | renames it (as `prefix R`), in a prompt inside the popup |
| ctrl-x | a trail · a lost one · an editor or shell window · the map | ends the trail · forgets it · closes the window · closes the map (as built: no question first, as ctrl-x was before; a window of yours is left alone) |
| ctrl-e | a trail | its codebase in the editor (as today) |
| ctrl-/ | anywhere | shows or hides the preview |
| ctrl-n | anywhere | makes a workspace (D3) |
| ? | anywhere | the keys, as now |
| esc | the list | closes the popup |
| esc | new trail, agents, resume old | back to the list |

There are no levels to go up through: the workspaces screen and a workspace's
screen are the headers of one list. `ctrl-a` (to everything) has nothing left
to do and goes.

### Where it opens

- **`prefix P`, a click on `[session]`, a bare `trails` in a terminal**: the
  list, the cursor on the row of the window you were in (the trail, or the
  workspace's header from a window of yours).
- **An editor's terminal** (ADR 14): unchanged, its one codebase's trails and
  nothing else, because picking another workspace's trail there would put that
  workspace into the editor's panel.
- **`prefix W` and `prefix A`** are unbound. `trails tree` and
  `TRAILS_PICKER=all` go. `trails ls` stays the text list for scripts.

### The preview

The highlighted trail's screen, live, under the list, the way `P` and `A` draw
it (`--peek`, refreshed once a second). The details are the row; the preview is
what the agent says. On a header, a window that isn't a trail, or a lost trail,
it is empty. Hidden when the popup has under ten rows for it, ctrl-/ brings it
back, as today. The popup is 80% × 80%, wide enough for every column and a
preview worth reading.

**As built:** 60% × 70%, the size `prefix P` always had: 80% × 80% covered
too much of the screen behind it. Then by the terminal: 60% where that is 130
columns or more, else 130, else nearly all of it; 70% high, or nearly all of a
short terminal. The rows fit what they get: a long task is cut with `…`, and
under 90 columns the agent column goes.

### What it costs

One `list-windows -a` for the rows (the tree's join), one `classify` for the
states (what `A` does now), the lost records, and the history cache for the
resume row's count. A reload after ctrl-s or ctrl-x redraws from the cache and
one `list-windows`, as Tab and ctrl-x do today.

## Decided

| | question | decision |
|---|---|---|
| Q1 | grouped by workspace, or flat with what wants you on top? | by workspace, the current one first |
| Q2 | keep `prefix W`, or `P` and the click only? | `P` and the click only; `W` and `A` go |
| Q3 | lost trails inside their workspace, or together near the bottom? | inside their workspace, beside their codebase's trails |
| Q4 | what are a trail's details? | what `prefix A` shows: state, codebase, agent · yolo, badge, ago, task, and the preview |
| Q5 | the map: under *yours*, or a row of its own? | its own row, under `＋ new trail…`, while a map is up |

## Path

1. **The list.** `one_rows` builds the rows above from one `list-windows -a`,
   the classify cache, the lost records and the history count; `P`, the click
   and a bare `trails` open it; the tree's ctrl-s moves over. The test fzf
   reads it the way it reads the screens now. `t-tree`, `t-all`, `t-picker`,
   `t-screens` and `t-workspace` move to the one list.
2. **The keys.** ctrl-r, ctrl-x on every kind of row, the map's row, the
   workspace headers' Enter.
3. **What goes.** The `ws`, `workspace`, `all` and `tree` screens, `prefix W` and
   `prefix A`, `ctrl-a`; `TRAILS_PICKER` keeps `old`, `agents` and the editor's
   codebase screen. README's keys table and the picker section, ARCHITECTURE's
   picker section, ADR 17 marked superseded in part.

Each phase ends with the suite green and a build on airbochs to look at before
the next.
