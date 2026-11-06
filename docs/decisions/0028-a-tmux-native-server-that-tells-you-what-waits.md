# 28. A tmux-native server that tells you what waits

- Status: accepted, built: the status line's left, `detach-on-destroy` and
  `@trails_state_at` in 1.19; the bells in 1.20; notifications as a sound, the
  tree (the popup) and stars in 1.21. `E` and `M` deferred
- Date: 2026-11

## Context

Since trails runs on a socket of its own (`tmux -L trails`, 1.17) and its keys load
only there (1.18), its server can look and behave however trails decides without
touching anyone's own tmux. What it decides should still feel like tmux to someone
who uses tmux, and today it does not quite:

- The status-left lists every workspace, a session selector stock tmux never shows.
- Closing the last window of a session drops you out of tmux (stock
  `detach-on-destroy on`), where on trails' server you expect a workspace.
- Nothing on the status line says which trails want you. The picker and `trails ls`
  do, and notifications do, through terminal escape sequences (kitty's OSC 99,
  iTerm2's OSC 9, OSC 777), so whether you get one depends on the emulator.

These were tried on a demo server (`showcase-*` on airbochs) before deciding.

## Decision

### The status line

- **Left: tmux's own `[session]`.** The workspace you are in, as stock tmux shows
  any session. A click on it opens the popup (below); `MouseDown1StatusLeft`, which
  stock tmux leaves unbound (its right-click menu stays).
- **The window list is tmux's.** A workspace's windows are its trails, and any
  window you add. A trail that wants you, blocked on a question or finished its
  turn and waiting for your next message, carries a bell after its name, `2: api 󰂚`,
  gone once you open it.
- **One bell with a count for the rest**, after the session name: `[acme] 󰂚 2` is
  two trails in other workspaces that want you. Nothing at zero. Never a list of
  names, so the line does not grow with the number of trails.
- **Right: the trail's task**, the checklist count, the time, as today. It is
  tmux's pane-title slot, made readable.
- **A flash when it happens:** `display-message` for a few seconds ("api needs you ·
  acme · …"), then gone, and the window rings tmux's bell, so the terminal plays its
  own sound whatever it is.
- The glyph is the config's (`󰂚`, a Nerd Font bell, by default).

### The popup

One key (`prefix W`) or a click on `[session]` opens a tree: each workspace with its windows, each trail's state and how long it has
waited, then the sessions you made yourself under "yours". Enter goes there, in any
session. Your own sessions are offered, never managed.

### Freshness

`trails state` stamps when a trail's state changes (`@trails_state_at`), so the
popup can say how long each has waited and the status line can tell a trail that
just finished from one that has waited long: within `"alerts": { "fresh_for": 900 }`
seconds it is fresh.

### Stars

`prefix S` (free in stock tmux), or ctrl-s in the popup, stars the trail; the star
is in its record, so it survives a restore. A starred trail has ★ beside its name
in the popup, with no list of its own there; its window has ★ before its number in the window list; `prefix F` (free in stock tmux) goes to the
starred trail that most wants you, again to the next. Notifications come for every
trail, or with `"only": "starred"` for starred trails alone.

### Notifications: a sound

A sound, on the machine running the agents (`afplay` on macOS, `canberra-gtk-play`
or `paplay` on Linux), Blow by default: heard over any app, any terminal, or none.
Which trail it was, the bell on the status line says, so there is no popup. Not
while a focused terminal shows the trail's window (`"show": "unfocused"`, the
default; tmux knows focus only with `focus-events on`). The escape sequences of
[ADR 26](0026-notifications-on-the-terminal.md) go: terminal-specific, a line of
config per emulator, nothing for one that reports no type. Which words sound, and
`idle_after`, are unchanged.

A popup through the operating system was built first and dropped: macOS shows
`osascript`'s as Script Editor's, a generic notification that doesn't read as
trails', and refused one from a Trails app signed on the machine; it takes an app
signed with a Developer ID. That stays open, should the popup be wanted. A push
service (ntfy) was considered and left out.

### Closing the last window

`detach-on-destroy no-detached` on trails' server: tmux moves you to the most recently
used session that no client shows, a workspace or one of yours, and detaches you only
when there is none. Every trail's own session keeps `on`, so a trail that ends still
lets go of its nested client, and is never where you land: it always has that nested
client, so it is never "detached".

### Windows, panes and sessions you make

trails manages only what it marked (`@trails_window`, `@trails_pane`,
`@trails_workspace`). Anything else on its server is plain tmux: listed by tmux,
switched to with tmux's keys, never listed, renamed or restored by trails.

### Deferred

`prefix E` and `prefix M` replace stock tmux's "spread panes out evenly" and "clear
the marked pane". They stay for now; to be revisited.

## Consequences

- The status line reads as stock tmux plus one bell, and only when something waits.
- Notifications reach you in any terminal, and outside one, on the agents' machine.
  Over ssh from another machine, the bell on the trail's window still reaches you;
  the notification does not.
- Built in shell, before the port to Go ([ADR 29](0029-trails-in-go.md)): the
  status line by events (`trails state` keeps the counts, tmux's formats show them),
  never a polling job. The popup opens as slowly as the picker does until the port.
- `trails keys` sets more of the server's options (`detach-on-destroy`, the status
  line); they are trails' server's only, since 1.18.
- The window's bell sits in the window format, which is usually the user's theme, and
  trails does not touch it: tmux's stock format shows the bell flag as `!`, and a theme
  that shows no flags adds `#{E:@trails_bell}`, the glyph when the window's flag is up,
  and `#{E:@trails_bell_style}` before the name, to colour it as the bell, since a theme
  that colours the name itself hides tmux's own bell style.
