# 21. The tmux server from a service manager

- Status: accepted
- Date: 2026-10

## Context

Every trail lives in one tmux server, and that server is whatever process first ran
`tmux`: usually a shell in a terminal. On macOS a process stays in the *coalition* of
the app that started it, however it detaches (tmux forks, calls `setsid`, and is
adopted by launchd), and a Force Quit of the app ends its whole coalition. A Force
Quit of kitty took down the tmux server it had started, with every agent in it, while
a normal quit of Zed a moment earlier did not.

`trails restore` brings the trails back, and the opt-in line from `trails keys` runs it
whenever tmux starts. But that only helps once something starts tmux again, and a
server started by `tmux -D`, the foreground form a service manager needs, reads its
config only when its first client connects: after a `kill-server`, a launch agent's
server sat five hours with its trails lost, until a terminal attached.

## Decision

`trails server` runs the tmux server for a service manager, and the Homebrew formula
declares it as a service, so `brew services start trails` installs and loads it: a
launch agent (`sh.brew.trails`) on macOS, a systemd user unit on Linux.

- **Its environment is the login shell's.** A service starts with Homebrew's bin and
  the system's on `PATH`; the server's environment is every pane's, and an agent under
  `~/.local/bin` would not be found. `trails server` re-runs itself once through the
  user's login shell (the account's, from `dscl` or `getent`).
- **It restores, a second after starting tmux.** That restore is the server's first
  client, so it also makes the server read `tmux.conf`.
- **It waits for tmux rather than exec'ing it.** `tmux -D` exits 0 after a
  `kill-server`, and Homebrew's systemd unit restarts on failure only. Ended unasked,
  `trails server` exits 1; asked to stop, it kills the server and exits 0.
- **No retry loop of its own.** With another server on the socket (one a terminal
  started), it exits 1 at once, and the service manager's own restart tries again.
- **Opt-in.** Installing trails changes nothing; `brew services start trails` is a
  choice, like the `trails keys` lines.

## Consequences

- A Force Quit of any terminal or editor no longer takes the agents with it, for
  those who start the service.
- The trails come back within seconds of any server restart, with no terminal open.
- `brew services stop trails` stops the server, and with it every trail; they come
  back as lost, as after a reboot.
- The `PATH` agents need has to be set where a login shell reads it (`~/.zprofile`,
  `~/.zshenv`, `~/.bash_profile`), not only in `~/.zshrc`.
- One service per user and socket: a second launch agent of one's own running
  `tmux -D` would fight it for the socket.
