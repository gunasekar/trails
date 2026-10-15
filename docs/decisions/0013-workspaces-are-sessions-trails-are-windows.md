# 13. Workspaces are tmux sessions, trails are windows in them

- Status: accepted
- Date: 2026-10

## Context

Before 1.0 every agent had a tmux session of its own, `trails-<project>`
(ADR 1). That held up for one machine and one editor. It broke down over SSH
with several codebases in play:

- one SSH connection is one tmux client, and a client shows one session, so
  moving between agents in different projects meant detaching and re-attaching
- a user's work is grouped by company or client, unrelated repos together, and
  trails had no notion of that grouping at all
- inside tmux, ADR 1 ran the agent bare in the pane, so an agent started from
  nvim inside tmux had no session and no other editor could reach it

The 1.0 design ([docs/design/trails-1.0.md](../design/trails-1.0.md)) sets
seven principles, the first of which decides this: a workspace is a session, a
trail is a window, a layout is panes, and all of it is plain tmux that still
makes sense with trails uninstalled.

## Decision

- **A workspace is a user-chosen set of codebases**, declared in the config as
  paths or globs under `workspaces`. trails never infers one from the directory
  layout. A git worktree belongs where its main checkout does. With no
  `workspaces` key, one workspace, `default`, holds everything.
- **A workspace session is named after the workspace**, plainly (`lattiq`), and
  marked `@trails_workspace`. A session of that name that trails did not make is
  refused, never adopted. No session exists for an empty workspace: the first
  trail creates it, and the last one out takes it down.
- **A trail is a window in its workspace session**, `augur·claude`,
  `augur·claude-2` for the second unnamed trail in that codebase, or
  `augur·payments` for a named one. What trails knows about it lives on the
  window as `@trails_*` options (agent, conversation, directory, workspace, view,
  label, name, start time), so nothing is parsed out of a name.
- **Inside tmux the agent is never run bare.** It gets a window like anywhere
  else, and the client you are in is switched to it.
- **trails sets nothing but `@trails_*` options** on what it makes: no `status
  off`, no `@agent_locked`, no key bindings. `trails keys` prints lines to
  paste.
- **Sessions from before 1.0 keep working** until they end. They are listed,
  attached to and ended as before, and a record of one that died with tmux
  restores as a window in the workspace its directory belongs to now.

## Consequences

- `tmux ls` reads as the user's own layout: workspaces, with the trails as their
  windows, moved between with `switch-client`, `choose-tree` and the next and
  previous window keys.
- Every editor and shell sees the same trails, inside tmux too (R6 in the
  design), which the README had promised and 0.6 did not keep.
- A record is keyed by the trail's editor view name (ADR 14) rather than a
  session name, one directory down in the state directory, and keeps the
  workspace, codebase label and name so a restore can rebuild the window where
  the config now says.
- `trails ls` gains a `workspace` field before the title, and its `session`
  field is what to attach to: the editor view, or the old session name.
- A directory no workspace claims is not refused: the picker asks once whether
  to add it, and `trails new` runs it in `default` and says so.
- Principle 3 costs the 0.6 niceties: an editor's panel now shows the user's
  status line unless their tmux.conf turns it off for views.
- ADR 1's reasons for tmux stand; its "one session per agent" and "bare inside
  tmux" do not, and it is superseded by this one.
