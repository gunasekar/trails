# trails 1.7: no agent's files read, and the checklist

trails runs coding agents, and knows them only through its config: how to start
one, how to resume a conversation, its YOLO flag, its name flag. What an agent
is doing, and which conversation it is in, it hears from the agent's hooks
(`trails state`). It reads no agent's files, settings or databases.
[ADR 19](../decisions/0019-no-agents-files-read.md) has the why.

Up to 1.6, trails read Claude's files in seven places, Codex's rollout files and
opencode's database. This removes all of them.

## What goes, and what stands in

| | Read from the agent | Instead |
|---|---|---|
| 1 | Claude's state, from `~/.claude/sessions/<pid>.json` | the hooks alone |
| 2 | the conversation a Claude moved to (`/resume`, `/clear`), from the same file; Codex's conversation ID, from its rollout files | the hooks say it: `trails state WORD --id ID` |
| 3 | Claude's own name (`trails-2b`), the `peer` column of `trails ls` | dropped |
| 4 | a name set inside Claude (`--name`, `/rename`), kept on restore | dropped: a name given in trails is in the record already |
| 5 | "resume old" rows from Claude's transcripts and opencode's database | trails' own history of the trails it ran |
| 6 | *elsewhere*: a conversation open in a Claude trails did not start | dropped, with the rows that needed it |
| 7 | `trails hooks`: hook formats for six agents, and whether each agent's settings hold them | dropped: the snippets move to [the README](../../README.md#hooks-for-each-agent); an agent is hooked when its hooks speak |

The config's `session.find` goes with 2: nothing is found, it is told.

## `trails state WORD --id ID`

The hook passes the conversation ID it is in, when its agent gives it one. The
pane gets `@trails_said_id` beside `@trails_state`, and when it differs from the
one the trail carries, `trails state` starts `trails --said` in the background:
one pass of `sessions()`, whose `rec_note_id` moves the record. At once, not at
the next listing, which a reboot might come before.

- **Only the trail's own agent.** A `claude -p` that the agent runs from its shell
  inherits the pane, and its hooks say *its* conversation. The trail's agent is
  the one nearest the pane's process, so the first ID sets a depth (processes
  from the hook up to the pane's process, `@trails_said_depth`), and an ID from
  deeper down is left out. No agent is named: it is process depth.
- **Only an ID**: a letter or digit first, then letters, digits, `_ . -`. Nothing
  an agent would read as a flag (`-x`), and no path (`..`).

- A Claude that `/resume`s or `/clear`s runs its `SessionStart` hook with the new
  ID, so the record follows it, as the reader did.
- An agent that starts under an ID of its own (Codex, Gemini) gets its record
  when its first hook reports the ID, as Codex did from its rollout.
- How the ID is had is the snippet's business, never trails': Claude's hooks get
  JSON on stdin, so its snippet is
  `trails state idle --id "$(jq -r '.session_id // empty')"`. Each agent's
  field name is checked against its docs and an installed copy before it goes in
  [the README](../../README.md#hooks-for-each-agent).
- No `--id`, or an empty one: the state alone, as now.

## History: trails' own

When a trail's agent exits, or you end it, its record moves to
`history/<conversation id>` with `ended=<epoch>`, rather than being deleted. So does
the conversation an agent leaves for another (a `/clear`, a `/resume`). "Resume old" lists those, newest
first, as it listed Claude's and opencode's conversations: the agent, the YOLO
mode, the workspace, and the task the record last held (`task=`).

- Only a trail with a conversation ID has one to resume, so only those are kept;
  and only a conversation that had a turn. `trails state working` marks the pane
  `@trails_worked`, and one whose hooks spoke but never said *working* stays out,
  since an agent refuses to resume a conversation that never got a message. A
  resumed conversation counts as worked; an agent without hooks can't say, and
  is kept.
- Resuming one starts a trail on it, and its history entry goes once the agent
  has survived starting: a resume that dies on arrival keeps it, to try again.
- ctrl-x on a closed row, in the old trails, forgets it. ctrl-x on a lost row
  forgets that outright, as before; on a running trail it ends it, into the
  history.
- The newest 100 are kept.
- Two agents on one conversation: trails can't tell that a conversation in its
  history is open in an agent it didn't start (that took reading the agent's own
  files), so resuming it there would run it twice. The agent's own resume has the
  same edge.

What it does not list: conversations started outside trails. The agent's own
resume (`claude --resume`, `codex resume`) finds those.

## Status

Every agent, Claude included, is *unknown* until its hooks speak. For Claude
that is the Claude Code plugin, or the snippet pasted into its settings: setting
up Claude becomes what setting up any other agent already was.

## `trails ls`

The `peer` column goes, and `pid` with it, since only *elsewhere* rows had one:

```
life  state  session  agent  yolo  dir  id  when  workspace  title
```

A script that takes the title as the last field keeps working.

## The checklist

Notes were for parking what to do next, and the prompts to give the agent, while
it works. 1.7 names them for what they are, a checklist, and makes the list
something you act on, not only a file to open.

- **`prefix N`** opens one fzf: a line to type a new item on, and the items under
  it, open ones first. No shortcuts, only whether something is typed: Enter adds
  it; with nothing typed, ↑ ↓ move, Space ticks the item done or back, Enter copies
  it (to tmux's buffer and the terminal's clipboard) and closes. ctrl-e opens the
  file, Esc closes. Space needs fzf's `transform` (0.45); older, Tab ticks.
- **The status line** counts it before the clock, `☑ 2/5`, open of all, for the
  codebase you are on. `trails keys` sets `status-right` for it; tmux.conf drops its
  own.
- **The name**: `trails checklist`, the file `.trails/checklist.md`.
  `trails note TEXT` stays the way to add one. The old `notes` key is still read,
  and a codebase's `.scratch/trails/notes.md` is moved to the new place the first time it is wanted.
- **Where, shared**: the config's `data`, a folder of yours, puts every codebase's
  checklist at `<data>/trails/<path>/checklist.md`, `<path>` the codebase's root
  from `$HOME` with every non-alphanumeric as `-`, as Claude names a project. Set to
  iCloud Drive, the checklists are the same on each machine. trails owns the layout
  under `data`; the config only says where.

## Since 1.7.0

- **1.7.1:** the item under the cursor, whole, in fzf's preview under the list
  (`checklist --text`), wrapped at words.
- **1.7.2:** Enter on a typed item adds it and the list stays open, on it, for the
  next (`checklist --enter`, a `transform`); Enter with nothing typed still copies
  and closes. ctrl-e brings the list back once the editor quits. The list is ten
  rows and the preview takes the rest; the popup is 60% wide. The editor and the
  shell open on the right: the agent on the left 40% beside the editor's 60%, or
  60% beside a shell's 40%, and with both, the shell under the editor.

## Tests

- The checklist: an item added, Esc adding nothing, Enter on one copying it
  (with the lines under it), ctrl-e, ticking and back, the count, the old file
  moved and the old key read.

- `trails state WORD --id ID` sets the pane's ID; the record follows it.
- An agent with no start ID gets its record from its first hook's ID.
- A trail whose agent exits lands in history, and "resume old" lists it with its
  task; resuming it removes the entry; ctrl-x forgets it.
- Nothing under `$HOME/.claude`, `$HOME/.codex` or opencode's data is read: the
  tests run with none.
