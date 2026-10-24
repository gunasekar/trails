# 20. A trail has an ID of its own

- Status: accepted
- Date: 2026-10
- Supersedes the part of [ADR 3](0003-restore-records-and-wrapper.md) that names a
  record by its trail's session

## Context

Up to 1.7 a trail's record was named by its tmux session, `<workspace>/<name>`, at
`sessions/<workspace>/<name>`. The session is the right name for tmux, which needs it
unique on the server, and the wrong one for a trail, because it changes while the
trail stays the same. A restore that found its session taken (by a session of your
own, or a workspace the config moved the codebase to) came back as `-N`, and had to
move its record to the new name, putting the old one back between attempts in case
the agent died on arrival. A number freed by one trail was taken by the next, so one
key could name two trails a moment apart. And records could not be filed by codebase:
names are unique per workspace, not per codebase.

## Decision

Every trail gets an ID when it starts: `t` and eight hex digits, from a UUID. It is
on the trail's window as `@trails_trail`, and its record is
`sessions/<codebase>/<ID>`, the codebase as `path_key` names it, the checklist's
folder name. A record is found by its ID alone; the folder is for reading.

- A restore keeps the ID: the same trail, the same record, in place. Only its
  `session=` changes when it lands on `-N`.
- A resume from the history is a new trail on an old conversation, with a new ID.
- The session stays the trail's address: what you type, what the picker and
  `trails ls` show. The conversation ID stays the agent's.
- A record is alive while a window carries its ID.

## Consequences

- No record moves after it is written, and `launch` and `restore_one` lose the moving
  of records under a changed name.
- The state directory reads by codebase, as the checklists do.
- `trails ls`'s TSV gains a `trail` column, before the title.
- 1.7's records move once, on the first run of 1.8 that reads them (`rec_migrate`); a
  trail running through the upgrade is matched as before until a pass gives its window
  its record's ID, and its old wrapper's `--forget SESSION` still finds its record.
- Finding a record is a glob rather than a path, and asking which record has a
  session is a grep: both over a handful of files.

See [docs/design/trails-1.8.md](../design/trails-1.8.md).
