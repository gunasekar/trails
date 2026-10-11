# 4. Recent conversations come from each agent's own store

- Status: accepted
- Date: 2026-10

## Context

Records (ADR 3) are deleted when an agent exits, so they say nothing about
conversations you closed yesterday. A history log of our own would start empty,
miss every agent started outside `trails`, and drift whenever a conversation is
continued elsewhere.

## Decision

Read each agent's own transcript store, the one its `--resume` reads: claude's
`~/.claude/projects/<dir>/<id>.jsonl` and opencode's SQLite `session` table.
Show at most `TRAILS_RECENT_MAX` (5) from the last `TRAILS_RECENT_DAYS` (10),
leaving out conversations a record holds. Mark with `!`, and refuse to resume, a
claude conversation still open in a process `trails` didn't start, using
`~/.claude/sessions/<pid>.json`.

## Consequences

- Old and new conversations take the same path; nothing to import or migrate.
- Cost tracks the rows shown: a time window on mtime, newest first, stop at the
  limit.
- It depends on undocumented file formats that each CLI can change. Parsing is
  deliberately loose (`grep` and `sed` on single JSON lines) and fails to an
  empty list rather than an error.
