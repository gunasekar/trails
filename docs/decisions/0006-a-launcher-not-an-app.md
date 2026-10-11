# 6. A launcher for tmux, not an app

- Status: accepted
- Date: 2026-10

## Context

trails grew from a picker into something with a status view, a restore system,
recent conversations, a multi-agent window and a keep-awake mode. Tools like
claude-squad go further and run their own TUI around the agents. The question
came up whether trails should become a compiled app (Go or Rust) with more of its
own interface.

## Decision

trails is a launcher for tmux. Its job is to start an agent in a tmux session,
help you find that session again, resume it after tmux or the agent is gone, and
end it. Once an agent is running, the session is plain tmux and trails has
nothing left to do.

So it stays one POSIX `sh` script, and features that are not about finding,
starting, resuming or ending sessions go. For v0 that meant:

- removing keep-awake (`ctrl-a`, `caffeinate`): a machine concern, not a session one
- removing `trails new`: the picker's `+ new` rows already do it
- folding `trails recent` and `restore -n` into `trails ls`, one place to see where
  every session is
- renaming `cockpit` to `map`, which is a view of running sessions and nothing more

## Consequences

- No daemon and no background process. The only thing left behind a running
  agent is the small wrapper that forgets its record when it exits.
- Anything that wants more (notifications, a menu bar) builds on `trails ls`'s TSV
  instead of growing trails.
- A rewrite in a compiled language is worth reconsidering only when a concrete
  pain appears, such as transcript parsing breaking, not for capability's sake.
