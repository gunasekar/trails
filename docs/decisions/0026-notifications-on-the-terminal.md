# 26. Notifications on the terminal you are looking at

- Status: accepted. Amends [ADR 6](0006-a-launcher-not-an-app.md), which left
  notifications to tools reading `trails ls`
- Date: 2026-10

## Context

A trail that needs you, or whose turn has ended, shows it in the picker and in
`trails ls`, and nowhere else. Away from the picker, a trail can wait on a
permission prompt for an hour unseen. Up to 1.6 the SwiftBar plugin notified, from
polls of `trails ls` (ADR 8); it went with the plugin, macOS-only and on the
machine running the agents, which for a headless box is no screen at all.

ADR 6 put notifications outside trails because, then, only a poll could see a
state change. Since ADR 18 the agents' hooks call `trails state` on every change,
so trails sees each one as it happens, with no poll and no daemon.

Where it shows matters more than how. trails' first opinion is one machine holding
the agents and everything else connecting to it, so the notification belongs on
the terminal in front of you, wherever it is, not on the machine running the agent.
Every tmux client attached has a tty that leads there, over ssh too. Terminals
take desktop notifications as escape sequences: kitty's OSC 99, OSC 9 (iTerm2's),
OSC 777. Which terminal speaks which, and how well, varies and moves.

## Decision

- **trails decides when and what; the config decides how.** When `trails state`
  sees a trail's word change, it starts `trails --notify` in the background. That
  notifies for *needs you*, and for *your turn* after a turn at least `idle_after`
  seconds long (30), and writes title and body: the agent and the state, the trail
  and its task.
- **Written to every attached client's tty**, whichever session it shows. No
  `allow-passthrough`, and an unattached trail notifies too.
- **Which escape is the config's**, by the client's `#{client_termtype}`, matched
  against globs: `"terminals": { "kitty*": "osc99", "iTerm2*": "osc9" }` by
  default, each checked by hand (kitty 0.49.2, iTerm2 3.7.6, which takes no OSC
  777). macOS Terminal reports no type and takes none of the three. trails knows
  the formats (`osc99`, `osc9`, `osc777`), never which terminal speaks one. A client no
  glob matches gets nothing, a nested client of trails' own among them.
- **Configurable whole** under `"notify"`: the words that notify (`on`),
  `idle_after`, OSC 99's `show` (`o=`, `always` by default) and `sound`, the
  terminals; `"notify": false` turns it off.
- **Terminals only.** No command run on the agents' machine (terminal-notifier,
  ntfy): it would fire where the agents are, not where you are, and it is what a
  reader of `trails ls` can still do.
- **osc99 names each notification by its trail**, so a new one replaces the last
  and going back to work closes it.

## Consequences

- A hook stays as fast as before: one more option read in its `display-message`,
  and a background `--notify` only when the word changes, at most twice a turn.
- Notifications reach whichever laptop is attached, through ssh, with nothing
  installed there but the terminal.
- A terminal trails' default doesn't list notifies once its client_termtype is put
  in the config, if it speaks one of the three formats; one that speaks another
  needs a format added to trails.
- OSC 9 and OSC 777 carry no ID: theirs stay until dismissed, and stack.
- A client that isn't looking (a second laptop, its lid shut, still attached) is
  notified too, by design: every client.
- The escape is written to a tty tmux is drawing on. A short write, but it can
  land between two of tmux's own sequences; none has been seen to break.
