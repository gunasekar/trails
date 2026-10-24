# 3. Records and a wrapper to survive tmux dying

- Status: accepted, amended by [ADR 19](0019-no-agents-files-read.md): the conversation a
  trail moved to comes from its hooks' `--id`; no agent's file is read. And by
  [ADR 20](0020-a-trail-has-an-id-of-its-own.md): a record is named by its trail's ID,
  under its codebase, not by its session
- Date: 2026-10

## Context

A reboot, crash or `tmux kill-server` takes every agent down. The transcripts
survive, but which conversation belonged to which session lived only in tmux.
`--continue` can't recover it: it means "the latest conversation in this
directory", so two sessions in one project would resume the same one.

## Decision

- Learn each conversation's ID, then resume by it. Best is to choose it up front
  and pass it to the agent (`claude --session-id`, `opencode --session`,
  `gemini --session-id`, `copilot --session-id`). Failing that, ask the agent
  for a fresh one (`cursor-agent create-chat`), or read back the one it made from
  its own files (codex's `~/.codex/sessions` rollouts). Each agent's config says
  which.
- Write one record per session to `~/.local/state/trails/sessions/<name>`:
  agent, directory, ID, YOLO, last known task.
- Run the agent under a small `sh` wrapper that deletes the record when the agent
  exits. tmux's hooks can't make that call: `session-closed` fires partway through
  `kill-server`, and `pane-exited` reports the wrong session. When tmux dies it
  hangs up on the wrapper too, so the record survives.
- Treat a record as dead when no session carries its ID in `@trails_id`.
- Follow the conversation, not the launch: `/resume` or `/clear` inside claude
  moves a session to another conversation, so every listing reads claude's own
  `~/.claude/sessions/<pid>.json` for the session's agent and updates the record
  and `@trails_id` to match.

## Consequences

- `trails restore` and the `↻` rows bring sessions back on the conversation
  they were last in, not just the one they started with. `trails ls` lists them.
- The six built-in agents can all be restored. An agent that offers none of the
  three ways runs normally but can't come back.
- codex writes nothing until its first message, so a codex session can't be
  restored before then, and two codex sessions in one directory that both start
  talking between two listings can be told apart only by `lsof`.
- A dead record reserves its name until it is restored or forgotten.
- Restoring brings back the conversation, not a half-run command.
