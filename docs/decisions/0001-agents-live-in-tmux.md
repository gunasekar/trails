# 1. Agents live in tmux sessions

- Status: accepted
- Date: 2026-07

## Context

An agent run from an editor's terminal dies with that terminal. In Zed's remote
mode the terminal runs on the ssh host, so a dropped connection kills the agent,
and `claude --resume` only replays the transcript into a new process. Several
frontends (a shell, Zed, nvim) also want to reach the same running agent.

## Decision

Every agent runs in its own tmux session, `trails-<project>`, created detached
and then attached. Every frontend runs `trails`, which attaches to an existing
session or starts one. Inside tmux, outside a cockpit, the agent runs bare in the
current pane instead of nesting.

## Consequences

- Agents survive disconnects, closed laptops and closed terminals.
- Sessions are plain tmux: `tmux a -t trails-foo` works with no `trails` at all.
- tmux itself becomes the single point of failure, which ADR 3 addresses.
- One session is one agent in one pane; a second pane would make every frontend
  draw it wrong, so the session is marked `@agent_locked` for tmux.conf to guard.
