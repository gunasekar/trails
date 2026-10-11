# 3. Records and a wrapper to survive tmux dying

- Status: accepted
- Date: 2026-10

## Context

A reboot, crash or `tmux kill-server` takes every agent down. The transcripts
survive, but which conversation belonged to which session lived only in tmux.
`--continue` can't recover it: it means "the latest conversation in this
directory", so two sessions in one project would resume the same one.

## Decision

- Choose each conversation's ID up front and pass it to the agent
  (`claude --session-id`, `opencode --session`), then resume by it.
- Write one record per session to `~/.local/state/trails/sessions/<name>`:
  agent, directory, ID, YOLO, last known task.
- Run the agent under a small `sh` wrapper that deletes the record when the agent
  exits. tmux's hooks can't make that call: `session-closed` fires partway through
  `kill-server`, and `pane-exited` reports the wrong session. When tmux dies it
  hangs up on the wrapper too, so the record survives.
- Treat a record as dead when no session carries its ID in `@trails_id`.

## Consequences

- `trails restore` and the `↻` rows bring sessions back on their own
  conversations.
- Only agents that accept a chosen ID can be restored (claude, opencode).
  cursor-agent needs an ID from `create-chat` first, so it isn't covered yet.
- A dead record reserves its name until it is restored or forgotten.
- Restoring brings back the conversation, not a half-run command.
