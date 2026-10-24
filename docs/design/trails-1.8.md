# trails 1.8: a trail ID of its own

Status: implemented in 1.8.0 ([ADR 20](../decisions/0020-a-trail-has-an-id-of-its-own.md)).

Every trail gets an ID when it starts, and keeps it until it ends: its record is
filed under it, its window carries it, and everything that finds a trail's record
finds it by it. The tmux session name (`acme/checkout-2`) stays what you type and
what the picker shows, but it stops being the record's identity.

## Why

Up to 1.7 a record's key is its trail's tmux address, `<workspace>/<name>`, and its
file is `sessions/<workspace>/<name>`. The address is the right thing for tmux, which
needs a session name unique on the server, and the wrong thing to identify a trail
by, because it changes while the trail stays the same:

- **A restore that can't get its old name back** (a fresh trail took `checkout-2`
  after the reboot) lands on `checkout-3`. The record has to be rewritten under the
  new key and the old one deleted, with the old content put back between attempts
  in case the agent dies on arrival: `restore_one` and the `rec_prev` dance in
  `launch` are the most delicate code in trails, and all of it is moving a file
  because its name changed.
- **A codebase moved to another workspace** in the config changes its trails' keys
  on the next restore, the same move again.
- **Numbers are reused.** `acme/checkout-2` today and `acme/checkout-2` tomorrow are
  unrelated trails with one key. Anything that held the key in between (a picker
  row, a `trails ls` reader, the wrapper's `--forget`) can act on the wrong one.
- **The layout can't be by codebase.** Names are unique per workspace, not per
  codebase, so `sessions/<path>/<name>` collides: the same codebase in two
  workspaces, or across a workspace move, both want `sessions/<path>/checkout`.

An ID that is the trail's own, from start to end, takes all four away.

## The trail ID

- **Shape:** `t` and eight lowercase hex digits, `t3f9a0c1e`: the `t` so it can never
  read as a number, a flag or a conversation ID. From `uuidgen`'s first eight (or
  `/proc/sys/kernel/random/uuid`'s), made again in the rare case a record of that
  ID exists. Short enough to read in `trails ls` and type in `trails restore`.
- **Made** by `launch`, before the record is written, for every new trail, a
  resumed one from the history included (a resume is a new trail on an old
  conversation). **Kept** by a restore: the lost trail comes back as itself.
- **Carried** on the trail's window as `@trails_trail`, beside `@trails_session`
  (its address, still) and `@trails_id` (its conversation, unchanged).
- **Not** the conversation ID: that changes on `/clear` and `/resume`, and codex has
  none until its first hook. Not the tmux session ID (`$12`) either: it dies with the
  server, which is exactly when the record is needed.

## Where records live

```
~/.local/state/trails/
├─ sessions/
│  ├─ workspace-acme-checkout/      ← path_key of the codebase, as the checklist's
│  │  ├─ t3f9a0c1e                  ← one record per trail, named by its ID
│  │  └─ t07be5d22
│  └─ -dotfiles/
│     └─ t9c41aa07
└─ history/<conversation id>        ← unchanged
```

The folder is `path_key` of the codebase root (`codebase_root`, a worktree under its
main checkout), the same name the checklist uses under `data`, so one codebase's
trails sit together. It is for reading: nothing depends on it. A record is found by
its ID alone (`sessions/*/<id>`, one glob), so a codebase that moves on disk, or a
`path_key` that changes, leaves records findable where they are.

A record gains two fields and keeps the rest:

```
trail=t3f9a0c1e
session=acme/checkout-2      ← the tmux address it runs (or last ran) under
agent= dir= id= yolo= task= workspace= label= name= server=
```

## What changes, call site by call site

| Today | 1.8 |
|---|---|
| `rec_path KEY` → `sessions/<ws>/<name>` | `rec_path TID` → `sessions/*/<tid>`, the one match; a new record's folder from `path_key` |
| `rec_keys`: files two levels down, as `ws/name` | the same files, as IDs |
| `@trails_session` is the record's key (`trail_key`) | `@trails_trail` is; `@trails_session` is only the address |
| `rec_is_dead`: no window with that `@trails_session` and `@trails_id` | no window with that `@trails_trail` |
| `session_taken`: a tmux session, a window's `@trails_session`, or a record file of that name | the same, with "a record whose `session=` is that name" (one `grep -rlx` over `sessions/`, as `trail_name_taken` already does for `name=`) |
| `restore_one`: launch under the old key, else a new one; move the record; put it back on failure | launch under the record's ID and its old address if free, else the next `-N`; rewrite `session=` in place. The record is still put back, where it was, between attempts: a launch that dies on arrival forgets it |
| `launch`'s `rec_prev`: save and restore the key's previous record around a refused `new-session` | only for a restore, whose record it rewrote; a new trail's ID has no previous record, and goes |
| the wrapper's `--forget KEY` | `--forget TID` |
| `rec_note_id`, `rec_note_task`, `sessions()` | read `@trails_trail` with the rest of the window's options, key records by it |
| picker rows: `restore:<key>` | `restore:<tid>` |
| `trails restore` | unchanged; `trails restore TARGET` (the picker's internal form) takes an ID |

`hist_add` copies the record whole, `trail=` and `session=` included; the history
stays keyed by conversation, and nothing reads `trail=` from it.

## `trails ls`

The table is unchanged. The TSV gains `trail` before the title, which stays last:

```text
life  state  session  agent  yolo  dir  id  when  workspace  trail  title
```

`-` for a trail that ended. A reader that takes the last field keeps working, and so
does one that counts fields up to `workspace`, since `trail` comes after it.

## Migration

Records from 1.7 are `sessions/<ws>/<name>` with no `trail=`. The first 1.8 run that
reads records (any `trails`, `ls`, `restore`, the status line's count aside) moves
them, once. A `.migrating` folder keeps two runs from doing it together; the launch
lock would have replaced the picker's own exit trap:

1. For each file two levels down without a `trail=` line: make an ID, write the record
   with `trail=` and `session=<ws>/<name>` added at `sessions/<path_key>/<tid>`
   (temp file and `mv`, as every record write), then remove the old file.
2. A running trail whose window has that `@trails_session` and no `@trails_trail` gets
   its record's ID from the next `sessions` pass; until then `rec_is_dead` matches it
   as 1.7 did, by session and conversation, so it never reads lost.
3. Empty `sessions/<ws>/` folders are removed.

Idempotent: a second run finds nothing without `trail=`. A record that can't be moved
(its folder unwritable) is left where it is, said on stderr, and goes unread.

A 1.7 trail still running through the upgrade has a wrapper that will call
`--forget <ws>/<name>` when its agent exits. 1.8's `--forget` takes an argument with a
`/` as an old key: it finds the record whose `session=` is that name and the window it
came from, and forgets that. Also gone in 1.9.

## Unchanged

- tmux session names, window names, badges (`#2`, `#payments`), and the keys.
- The history: `history/<conversation id>`, the newest 100.
- What a name may be, and that names are unique box-wide (`trail_name_taken`).
- Records are machine-local. `data` (the synced folder) holds checklists only; a
  record names a tmux server and processes on this machine, and means nothing on
  another.

## Tests

- **IDs** (`t-launch`): a launch writes `sessions/<path>/<tid>` with `trail=` and
  `session=`, and the window carries the same ID.
- **Restore keeps the trail** (`t-restore`): its ID and its record, in place.
- **Restore under a taken session** (`t-restore`): kill the server, make a tmux session
  of your own by the lost trail's name (a fresh trail can't take it: a lost trail keeps
  its name), restore: it comes back as `-2` with the same ID and the same file,
  `session=` rewritten. The same test shows a hand-made session by that name doesn't
  make the dead record read alive.
- **Migration** (`t-upgrade`): 1.7-shaped records, with and without a running window,
  become 1.8-shaped, the running one reading running; a second run changes nothing.
- **An old wrapper** (`t-upgrade`): `--forget default/payments` closes the migrated
  record into the history.
- **ls** (`t-ls`, `t-hooks`): the TSV's `trail` column, before the title, the same for
  a running trail and the lost one it becomes.
- Every test that read a record at `ws/name` finds it by its session now
  (`test/bin/trec`).

Not separate tests: a restore after a workspace move takes the same path as one under
a taken session (only `session=` and `workspace=` change); a number reused by a new
trail gets a new ID because every launch makes one.

## Order of work

1. ADR 20, "A trail has an ID of its own", superseding the part of ADR 3 that keys
   records by session name.
2. The ID, `@trails_trail` and the record's new fields, written beside today's key;
   lookups still by key. Tests green.
3. Lookups by ID: `rec_path`, `rec_is_dead`, `rec_keys`, `--forget`, the picker's
   `restore:` rows, `sessions()`.
4. `restore_one` and `launch` without the moves; the restore tests rewritten to
   assert the file stays.
5. The new layout, `sessions/<path_key>/<tid>`, and the migration with its tests.
6. `trails ls`'s `trail` column; README's fields table; ARCHITECTURE's records
   section; the test plan's M4 run on both Macs, through a real upgrade from 1.7.2
   with trails running.

## Open questions

- **Show the ID anywhere but `ls`?** The picker's preview header could carry it for
  debugging; nothing else needs it. Leaning no.
- **Re-file a record whose codebase moved?** Lookups don't need it, so only for
  tidiness. Leaning no: the folder is a reading aid, and `dir=` is the truth.
