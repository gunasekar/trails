# 27. The service starts the server, not the terminal

- Status: accepted. Amends [ADR 21](0021-the-tmux-server-from-a-service-manager.md);
  builds on trails' dedicated tmux socket (`"server"`, `tmux -L trails`)
- Date: 2026-11

## Context

ADR 21 put the tmux server under a service manager, so that a Force Quit of a
terminal can't end it. It left a gap: whatever starts tmux on trails' socket first
owns the server. The dedicated socket (`tmux -L trails`) closed part of it: a bare
`tmux` now starts a server of its own and can no longer take trails' place. trails
itself still could.
If the service's server goes (a `kill-server`, a stopped or restarted service),
the next `trails` or `trails restore` typed in a terminal, inside the manager's
restart delay, starts tmux itself, in that terminal's coalition. The service then
refuses to start, as ADR 21 says it should while another server holds the socket.

That happened, on the ordinary default socket before the dedicated one. On one
machine a server started by `trails restore` in kitty held
the socket for 37 hours while the service refused 2,605 times, each logged as the
same undated line and seen nowhere else. A Force Quit of kitty then ended the
server and every agent in it, which is exactly what the service was installed to
prevent.

## Decision

- **With the service installed, trails doesn't start the server.** `tmux_door`,
  the one call that can start it, finds no server and asks the service manager
  to start the service now (`launchctl kickstart gui/<uid>/<label>`,
  `systemctl --user start <unit>`), then waits for the socket, up to 15 seconds.
  Not `kickstart -k`, which would kill a boot that is still running.
- **The service is found by what it runs.** A launch agent plist or systemd user
  unit with `trails` and `boot` in it, whatever Homebrew names it.
  `TRAILS_SERVICE` names one instead, or none when empty (the tests).
- **If the service doesn't come, trails starts the server anyway** and says that
  this terminal now holds the agents. A blocked trails would be worse than an
  unguarded one.
- **A foreign server is announced, not just retried.** `trails boot` logs the
  start of a stretch of refusals once, with the time, and shows a message on
  every attached terminal then and hourly after. The message says what is at
  risk and how to move: `tmux -L <socket> kill-server`, after which the
  service restarts tmux and restores the trails.

## Consequences

- `trails`, `trails restore` and the picker can no longer leave the agents in a
  terminal's server while the service is installed.
- A bare `tmux` can't, being on another socket. Only something that names
  trails' socket itself (`tmux -L trails`), or trails when the service won't
  start, can still put the server in a terminal; that is made visible, not
  prevented.
- The first trail after a server restart can wait a few seconds longer, while
  launchd or systemd starts the service.
- The boot log has timestamps, so the start of a stretch can be placed in time.
