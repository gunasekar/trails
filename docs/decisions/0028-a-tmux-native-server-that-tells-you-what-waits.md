# 28. A tmux-native server that tells you what waits

- Status: accepted, built in parts: the status line's left, `detach-on-destroy` and
  `@trails_state_at` in 1.19; the bells, the popup, the watch list and notifications to come
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

One key (`prefix W`) or a click on `[session]` opens a tree: the ★ watch list first,
then each workspace with its windows, each trail's state and how long it has
waited, then the sessions you made yourself under "yours". Enter goes there, in any
session. Your own sessions are offered, never managed.

### Freshness

`trails state` stamps when a trail's state changes (`@trails_state_at`), so the
popup can say how long each has waited and the status line can tell a trail that
just finished from one that has waited long: within `"alerts": { "fresh_for": 900 }`
seconds it is fresh.

### The watch list

`prefix S` (free in stock tmux), or ctrl-s in the popup, stars the trail; the star
is in its record, so it survives a restore. Starred trails come first in the popup
and their bells always show. Notifications still come for every trail.

### Notifications, whatever the terminal

`"notify": { "via": [...] }`, any of:

- `os` (the default): the operating system's own, with a sound, on the machine
  running the agents (`osascript` on macOS, `notify-send` on Linux). Shows over any
  app, any terminal.
- `terminal`: today's escape sequences, per terminal, for when you are over ssh.
- `ntfy`: a push to a topic you subscribe to, on a laptop or a phone, anywhere.

Which words notify, and `idle_after`, are unchanged.

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
- Notifications reach you in any terminal, and outside one, on the agents' machine;
  elsewhere through ntfy, or the terminal escapes as before.
- Built in shell, before the port to Go ([ADR 29](0029-trails-in-go.md)): the
  status line by events (`trails state` keeps the counts, tmux's formats show them),
  never a polling job. The popup opens as slowly as the picker does until the port.
- `trails keys` sets more of the server's options (`detach-on-destroy`, the status
  line); they are trails' server's only, since 1.18.
- Open: the window's bell has to sit in the window format, which is usually the
  user's theme (the demo's pads each name to 25 columns and shows no tmux flags).
  trails must not overwrite it: likely a format of its own (`#{E:@trails_bell}`) to
  add to one's theme, appended to tmux's stock format when the theme has none.
