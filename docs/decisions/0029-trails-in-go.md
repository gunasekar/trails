# 29. trails in Go

- Status: proposed
- Date: 2026-11

## Context

trails is one POSIX `sh` script: 6,035 lines, about 4,000 of them code (177 functions,
363 tmux calls, 68 awk programs, 29 jq calls), and 2,000 of comments. Shell suited it:
trails is mostly glue around tmux, it installs as one file, and it reads like the tmux
commands it issues.

Two things have changed:

- **It is slow to start.** `trails help` takes about 0.2 s and `trails ls` about 0.9 s,
  with no tmux server at all (probochs, 2026-11-05): nearly every step forks jq, awk,
  find or tmux. What [ADR 28](0028-a-tmux-native-server-that-tells-you-what-waits.md)
  adds runs often: a status-line job every few seconds, a popup that has to open at
  once, timestamps and ages, a watch list, notifications through the OS or HTTP.
- **Its bugs are the language's.** In one day: `exec tmux` skipped the function that
  adds `-L`, so opening a trail reached the wrong server ("no sessions", 1.17 and 1.18);
  tmux 3.4 and 3.5 escape the unit separator trails splits on; and much of the code is
  quoting care. None of these are trails' logic.

## Decision

trails moves to Go, as a single static binary, once ADR 28 has shipped in shell.

- **ADR 28 first, in shell.** Its status line needs no polling job: `trails state`
  runs on every change already, so it keeps counts in tmux options and the status
  line reads them with tmux's own formats. Most of the rest is tmux options. Built
  first, it is settled by use before it is ported, and its tests join the contract;
  the cost is a few hundred more lines to port, and a popup as slow as the picker
  until then.
- **The same CLI**: commands, flags, output, the config file, the records, the tmux
  options and layout. The integration tests (`test/t-*.sh`) drive the CLI and tmux,
  never the script's insides, so they are the contract: the port is done when every
  one of them passes unchanged.
- **Still no daemon.** A binary that runs and exits, as the script does; the tmux
  server and the service (`trails boot`) are unchanged.
- **Homebrew installs the binary** (a bottle, or built from source by the formula);
  `trails keys`, the hooks and the service call `trails` as before.
- **Released as 2.0.** Config, records and the tmux layout stay compatible, so an
  upgrade is `brew upgrade`, and a server running the script's trails carries on.
- **The shell version is kept to fixes** once the port starts, until the Go one
  passes every test, then retired.

## Consequences

- Hooks, the picker and the popup cost milliseconds.
- Real types for state, records and time; HTTP and OS calls without forks.
- A build step, and contributors read Go rather than one script.
- A real project: about 4,000 lines of logic and the tmux-version workarounds to
  carry over, with two versions maintained until the switch.
