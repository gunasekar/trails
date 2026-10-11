# Architecture

`trails` is one POSIX `sh` script, [`bin/trails`](../bin/trails). Its comments
carry the detailed reasoning, much of it measured. This page is the map.

## Sessions

Every agent runs in its own tmux session named `trails-<project>`, where
`<project>` is the directory's basename with `.`, `:` and spaces turned into
`_`. A second agent in the same project gets `-2`, `-3` and so on. `$PREFIX` is
the only place the prefix is spelled.

"A session of ours, for this directory" is never read off the name, because the
name can't answer it: `trails-foo-2` is equally foo's second agent and project
foo-2's first. `is_ours` asks tmux instead. Each session is created with
`-c "$PWD"`, and tmux keeps that as `#{session_path}`.

Each session also carries user options that `trails` sets at launch:

| Option | Holds |
|---|---|
| `@agent` | which agent row started it, e.g. `claude (YOLO)` |
| `@trails_id` | the conversation ID it was started with (see Surviving tmux) |
| `@agent_locked` | "one agent, one pane", for a tmux.conf to enforce (below) |

The status bar and pane border are turned off per session, since a session is a
single pane whose name you already know.

### What tmux.conf can add

None of this is required, but a tmux.conf can use those options:

- **Guard the split keys** with `if -F '#{@agent_locked}'`, so a second pane can't
  turn an agent session into something three frontends would each draw wrong.
- **Title from the agent:** `set-titles-string` built from `#{@agent}` and
  `#{pane_title}` gives every terminal tab "claude · what it is working on". The
  map's pane borders read the same string.
- **A second prefix that also reaches nested clients,** which the map uses.

## Agents

What trails can start comes from `~/.config/trails/config.json`, or the built-in
agents (the same JSON, inside the script) when there is no file. `load_agents`
reads it once per run with `jq` and turns each agent into one line,
`name|command|args|yolo|start|resume|idform`, default agent first. Everything
else asks through `agent_row`. A bar, not a tab, separates the fields, because
most agents leave some empty and tab counts as whitespace to `read`.

The config's `mode` is read alongside, by `load_mode`, and only the picker uses it: a
`+ new` row is YOLO when the mode says so or Tab flipped it, not both, and only
if its agent has a `yolo` flag.

`launch` builds the command from that line: the program's words, the YOLO flag if
the row was armed, then the session template with `{id}` filled in: `resume` with
the ID being resumed, else `start` with a fresh ID, else `resume` with one that
`create` printed. An agent with only `find` starts with no ID and no record;
`rec_note_id` writes the record once the reader can see the conversation.

The readers are built in. `claude` asks claude's `~/.claude/sessions/<pid>.json`
for the session's process. `codex` looks for the rollout file the codex process
holds open (`lsof`), else the newest `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`
whose first line names this directory, written since the session started, that no
other record claims. An agent without a `session` block
still launches; it just gets no record, so it can't be restored.

The record and the tmux `@agent` option hold the agent *name*. Rename or remove
an agent and its lost rows fail to restore with "unknown agent" and keep their
record until the agent is back or the row is forgotten.

## Session states

Every session has two signals: whether its tmux session is running (`●`) or not
(`○`), and a state word. One table in the script, `STATES`, holds each state's
glyph, colour, word, legend line and sort position, and every view draws from it:
the picker, `trails ls` and its legend, the map, and the TSV's `state` column.

| State | Running | Comes from |
|---|---|---|
| needs you | yes | `classify`: still, and asking (`blocked` inside the script) |
| your turn | yes | `classify`: still, not asking (`idle`) |
| working | yes | `classify`: the screen changed |
| lost | no | a record whose session is gone |
| closed | no | an agent's own history, with nothing running it |
| elsewhere | no | the same, but held open by a `claude` trails didn't start |

The README has the lifecycle diagram. The picker is two lists, and every row in
either does something on Enter — fzf has no row it won't select, so there are no
label lines to step over. The main list has this directory's running and lost
sessions, one `<agent> · new trail` row per agent, and `↩ resume old trails`
(verb `more`) when anything ended here. That row re-runs trails with
`TRAILS_PICKER=old`, which lists the closed and elsewhere conversations; Esc there
re-runs it without, back to the main list. The reload subprocesses inherit the
variable, so Tab and ctrl-x redraw the list they were pressed in. Running versus stopped is decided by
state name, never by glyph: macOS awk compares strings by locale collation, which
ranks `●` and `○` equal.

## Who wants you: working, your turn, needs you

There are no per-agent hooks. Claude Code's hooks would report this exactly, but
only for Claude, and the other CLIs have nothing. The signal every agent already
gives is its screen: each TUI animates while it works (spinner, timer, token
count), and a stopped one sits still.

So `classify` captures every session's visible screen, waits `AGENT_SETTLE`
(0.35s), and captures again:

| State | Rule |
|---|---|
| `working` | the screen changed between the samples |
| `blocked` | still, and the bottom 15 lines match `AGENT_ASK_RE` |
| `idle` | still, and not asking |

The error is one-sided by construction: `working` needs two samples to differ,
so a still screen can never read as working. The bad case is a slow agent read
as idle. `blocked` vs `idle` is the one heuristic, and both sort above
`working`, so a wrong guess costs a colour, not a missed agent.

A tmux timestamp doesn't work instead: `#{session_activity}` tracks tmux's own
alert bookkeeping, not bytes written to the pane.

## trails ls

`ls` answers "where is everything", box-wide, in one list built by `ls_rows`, in
`STATES` order: running sessions most-wants-you first, then lost ones, then ended
conversations newest first.

Piped, it is TSV, a contract for notifiers: `life state session agent yolo dir id
when pid title`, `life` being `running` or `stopped`. An empty field is written `-`, never left empty, because tab counts
as whitespace to `read` and two tabs in a row collapse, shifting every later field.
The title goes last because it is free text. On a terminal it is a padded table,
with `#N` on the Nth session in a directory. The badge is read off the session
name *against its directory*, because the name alone can't tell foo's second
agent from project foo-2's first.

Reading conversation history costs most of an `ls`. `TRAILS_RECENT_MAX=0` skips it,
for a menu-bar poll that only wants running sessions.

## Surviving tmux

Every agent lives inside the tmux server, so a reboot, a crash or
`tmux kill-server` takes them all down. The conversations survive, since each CLI
keeps its transcripts. What dies is the knowledge of which conversation belonged
to which session.

So `trails` writes that down outside tmux, one file per session:

```text
~/.local/state/trails/sessions/trails-foo
agent=claude
dir=/Users/me/code/foo
id=15fcb95c-19cc-49dc-a7fc-7a7dd032e5c9
yolo=yolo
task=Fixing the flaky test
```

**The ID is chosen up front.** `trails` generates it and starts the agent under it
(`claude --session-id`, `opencode --session`), then resumes by it (`--resume`,
`--session`). `--continue` would not do: it means "the latest conversation in
this directory", so two sessions in one project would resume the same one.

**The task is kept current** by every `sessions()` pass, which a menu-bar poll
runs every few seconds, so a lost row can say what the session was doing.

**So is the conversation.** The ID trails chose is only where a session started:
`/resume` or `/clear` inside claude moves it to another one. Every `sessions()`
pass asks claude which conversation it has open (the pane's process is the wrapper,
its child is claude, and `~/.claude/sessions/<pid>.json` names the `sessionId`).
When that differs, the record and `@trails_id` follow it. Otherwise a restore after
tmux dies would bring back the conversation you left, and the one you were in would
look like a stranger's.

**Deleting a record at the right moment is the hard part.** A session you quit
is over, and a session tmux took down is the whole point, but from outside both
look the same. tmux's hooks can't tell them apart: `session-closed` also fires
partway through `kill-server`, and `pane-exited` reports the wrong session name.
So the agent runs under a small `sh` wrapper:

```sh
self=$1 name=$2; shift 2; trap : INT QUIT; "$@"; s=$?; "$self" --forget "$name"; exit $s
```

When the agent exits by itself, the wrapper forgets the record. When tmux dies,
it hangs up on the whole process group and the wrapper dies to SIGHUP before it
can forget anything. A reboot runs nothing at all.

**A record is dead** when no session carries its ID as `@trails_id`, not when no
session has its name. Otherwise a session you created by hand under the same
name would hide it. A dead record also keeps its name reserved, so a fresh agent
lands on `-2` and can't overwrite it.

`trails restore` brings back every dead record, detached, in its own directory.
If claude refuses the ID (`No conversation found`, an agent you never typed
into), it starts fresh in its place. If the agent can't start at all, the record
is put back for next time.

## Recent conversations

Records aren't history, because the wrapper deletes one as soon as its agent
exits. For "what was I working on here", `trails` reads each agent's own
transcript store, the one its `--resume` reads. That covers every conversation,
including ones from before `trails`, and there is nothing to import or keep.

| Agent | Store | Shown when |
|---|---|---|
| claude | `~/.claude/projects/<dir>/<id>.jsonl`, one JSON event per line | `"entrypoint":"cli"` (not the SDK), and it has an `ai-title` or a `last-prompt` |
| opencode | the `session` table in `~/.local/share/opencode/opencode.db` | top-level, not archived, and titled |

Claude names the folder after the directory with every non-alphanumeric turned
into `-`. That mapping is lossy, so each file's own `cwd` is checked too.

**Cost tracks the rows shown, not the history.** Only files modified inside
`TRAILS_RECENT_DAYS` are looked at, newest first, one `stat` for the lot, and the
scan stops after `TRAILS_RECENT_MAX` hits. The picker reads them once per run and
caches them, so a Tab doesn't pay for it again.

Whether a claude conversation last ran YOLO comes from the transcript too: each
turn records its `permissionMode`, and `bypassPermissions` is what
`--dangerously-skip-permissions` runs as. A closed row resumes in that mode, the way a
lost row comes back in its recorded one. opencode records nothing like it.

The picker shows this directory's; `trails ls` shows every directory's.

Conversations a record holds are left out, since they're already running or lost
rows. A conversation still open in a `claude` that `trails` didn't start is
marked `!`, and Enter refuses it. Claude writes a file per running process,
`~/.claude/sessions/<pid>.json`, naming its `sessionId`, so "open" is that file's
pid being alive. Resuming it would put a second Claude on the conversation, each
adding turns the other never sees.

## The picker

`print_menu` builds TSV rows of `verb`, `target`, `what's drawn`. fzf draws only
the third field. Tab and ctrl-x pass the target to a subcommand of the script
(`--toggle-yolo`, `--kill`) and reload the menu. They're
subcommands rather than inline shell because fzf runs its bindings through
`$SHELL`, where zsh expands a leading `=` and silently ate the kill.

The running block is classified once per picker run and cached in a temp file,
because `classify` sleeps and every Tab reloads. Recent rows are cached the same
way.

| Verb | Enter does |
|---|---|
| `new` / `yolo` | launch a fresh agent, with the YOLO flag for `yolo` |
| `attach` | attach to the running session |
| `restore` | `restore_one`, then attach |
| `resume` / `resume-yolo` | launch with the resume flag and that ID, recorded like any launch; `resume-yolo` when it last ran YOLO or Tab armed it |
| `open` | refuse, naming the process that has it |

`launch` creates the session detached, stamps it, waits 1.5s and checks the pane
isn't already dead before attaching. An agent that fails at once (a bad token, no
keychain) would otherwise take its error with it and look like nothing happened.
Inside tmux, outside a map, it runs the agent bare in the current pane
instead of nesting.

## The menu-bar plugin

`extras/swiftbar/trails.10s.sh` is a SwiftBar plugin, installed into
`share/trails/swiftbar/` with its icons. It is a reader of `trails ls`, not part
of trails: every 10 seconds it runs `TRAILS_RECENT_MAX=0 trails ls`, keeps the
running rows, and draws them.

- **Icon:** twelve pre-drawn PNGs in `icons/` (three top-dot states, two bottom,
  for a light and a dark bar), made by `assets/render.swift --menubar`. A
  coloured image can't be a template image, so the plugin picks the light or dark
  set from the system appearance.
- **Notifications:** it remembers each session's state between polls in
  `~/.cache/trails/swiftbar-state` and speaks on the working → stopped edge, once,
  after `TRAILS_NOTIFY_AFTER` seconds. Nothing can tell whether you're looking at
  a session, so the wait is what keeps the one you're working in quiet.
- **Resume** runs `tmux attach-session` as the command of a new tab, through the
  chosen terminal's AppleScript. The choice is stored in
  `~/.config/trails/terminal`, not in SwiftBar's storage for the plugin: SwiftBar
  names that after the plugin's resolved path, which through Homebrew carries the
  version, so every upgrade would start it empty.

`trails swiftbar` links the plugin into SwiftBar's plugin folder (read from
`defaults read com.ameba.SwiftBar PluginDirectory`). It links through the path the
script was invoked by, `/opt/homebrew/bin/../share/…`, not the resolved Cellar
path, so the link survives `brew upgrade`. It never replaces a real file.

## The map

`trails map` is a tmux session named `trails_map` whose panes are each a tmux
client attached to an agent session. It borrows the view and owns nothing: kill
it and every agent is where it was. That's why it is never reconciled, only
rebuilt, and why its name is outside `$PREFIX`. Under the prefix, `trails ls`
would count it as an agent that is always working. The underscore matters:
`trails-map` is what a project folder called `map` gets.

Panes are ordered most-wants-you first and re-tiled after every split, since
splitting halves the current pane and runs out of room fast. Two agents go side
by side only when the window is at least 160 columns wide. Each pane is stamped
with `@dir` and `@ag` so its border can read `<dir> · <agent> · <task>`.

A tmux window has one size, so a session watched by a map pane and, say, a
Zed thread can't be drawn right for both. `window-size` stays at tmux's default
`latest`, so the view you last typed in wins and the other catches up when you
press a key there.

Inside the map, a shell you split off (`C-b |`) can run `trails`. The agent
still gets its own session, and that pane becomes a viewer of it.

## The README demos

`assets/demo.gif` and `assets/nvim.gif` are recorded with
[VHS](https://github.com/charmbracelet/vhs) from `assets/demo/*.tape`. Each tape
first sources `assets/demo/sandbox.sh`, which gives the recording its own HOME
and tmux server, a sample project, two ended claude conversations, and stand-in
`claude` and `codex` agents (`assets/demo/agent`) that need no login or API. The
repo's own `bin/trails` comes first on `PATH`, so a re-record shows the version
being released. After a change to what the picker or `ls` shows, re-record from
the repo root:

```console
vhs assets/demo/demo.tape
vhs assets/demo/nvim.tape
```
