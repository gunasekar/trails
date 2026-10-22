# Architecture

`trails` is one POSIX `sh` script, [`bin/trails`](../bin/trails). Its comments
carry the detailed reasoning, much of it measured. This page is the map.

## Scope

trails is a launcher for tmux ([ADR 6](decisions/0006-a-launcher-not-an-app.md)).
Its job is four verbs on trails: **start** one, **find** it again, **resume** it
after tmux or the agent is gone, and **end** it. Since 1.0 the places those verbs
act in are workspaces, and the editor and a shell come along beside the agent
([ADR 13](decisions/0013-workspaces-are-sessions-trails-are-windows.md)). Once an
agent is running, everything is plain tmux and trails has nothing left to do.

The 1.0 design ([design/trails-1.0.md](design/trails-1.0.md)) sets seven
principles that every feature passes: plain tmux objects, no default key bindings,
nothing set on tmux beyond `@trails_*` options, never rearrange the user's
windows, nothing hidden, native tmux first, and no residue.

In scope:

- **Starting** any agent CLI the config names, as a window in its workspace's
  session, in the directory you're in, in the agent's own mode or its YOLO flag.
- **Finding:** the picker's three screens, `trails ls` for this directory,
  `trails ls -a` for every one, and whether each agent is working or waiting on
  you.
- **Resuming:** a record per trail that outlives tmux, `trails restore`, and
  ended conversations read from the agents' own stores.
- **Ending** a trail, or forgetting a lost one.
- **Workspaces:** which codebases go together, from the config, and a session
  per workspace to switch between over one connection.
- **The editor and a shell** beside a codebase's trails
  ([ADR 15](decisions/0015-companions-are-marked-windows.md)).
- **The map**, several trails in one window, as a window that owns nothing.
- **A TSV contract** (`trails ls`) for other tools to build on, and the menu-bar
  plugin, which ships with trails but is only a reader of it
  ([ADR 8](decisions/0008-ship-the-menu-bar-plugin.md)).

Out of scope:

- **A UI around the agents.** No TUI or GUI of trails' own: once you're attached,
  you're in tmux and the agent's own interface.
- **A daemon.** Nothing of trails runs between commands, except the small wrapper
  that forgets a trail's record when its agent exits.
- **Per-agent integrations.** No hooks or APIs into the agents. Status comes from
  the screen ([ADR 2](decisions/0002-status-from-the-screen.md)), or from a file
  the agent already writes for itself
  ([ADR 11](decisions/0011-an-agents-own-state-beats-its-screen.md)), and adding an
  agent is a config entry, not code
  ([ADR 7](decisions/0007-agents-in-a-config-file.md)).
- **The agents' work itself:** git worktrees, branches, diffs, prompts or task
  queues. trails puts you in the trail, and what happens there is the agent's
  business and yours.
- **Owning history.** Conversations stay in each agent's own store. trails reads
  them and imports, copies or syncs nothing.
- **Configuring tmux.** trails sets `@trails_*` user options on what it makes and
  nothing else, binds no keys, and never edits `tmux.conf`. `trails keys` prints
  suggestions.
- **Saved layouts.** No `open` list, no layout file: a restore rebuilds what was
  running from the records, and tmuxinator or sesh work beside trails for the rest.
- **Sandboxing or permissions.** YOLO is the agent's own flag. trails only
  refuses the sandbox-bypassing ones as root.
- **Machine concerns,** such as keeping the machine awake (removed in ADR 6), and
  reaching agents on other machines: trails runs where the agents live, and you
  reach it over ssh.

The test for a new feature: is it about starting, finding, resuming or ending a
trail, or the place it lives? If not, it belongs in a tool built on `trails ls`,
not in trails.

## The model

| Term | Means | tmux |
|---|---|---|
| Codebase | one directory; a git worktree is its own codebase | none |
| Workspace | a user-chosen set of codebases | a session named after it, marked `@trails_workspace` |
| Trail | one agent working in one codebase | a session of its own, `<workspace>/<codebase>[-N]`, `status off`, holding one window with the agent in it: what an editor attaches to, one trail and nothing else |
| The trail's window | how the workspace shows a trail | a window in the workspace session named like the agent's, marked `@trails_window`, whose first pane is a nested tmux client of the trail's session |
| Agent, editor and shell panes | the agent, with your editor and a shell beside it | panes of the trail's window, marked `@trails_pane` `agent`, `editor` or `shell` |
| Editor or shell window | your editor or shell with no trail in the codebase, or left when one ended | a window `<codebase>·nvim` or `<codebase>·shell` marked `@trails_tool` (`editor` or `shell`); a *tool window* in the code |
| Map | several agents side by side | panes, each a nested client of a trail's session, in a window no editor attaches to |

The words are tmux's own, plus trail. A trail has two windows: the agent's, in
the trail's session, and the trail's, in the workspace. Where it matters the text
says which.

The agent's window, and the trail's window after it, is named `<codebase>·<agent>`,
`<codebase>·<agent>-N` for the Nth unnamed trail in that codebase, or
`<codebase>·<name>` for a named one. The
codebase label is the directory's basename with `.`, `:` and spaces turned into
`_`, or `<repo>@<branch>` for a worktree.

Everything trails knows about a trail is on the agent's window, in the trail's
session, so nothing is parsed back out of a name:

| Option | Holds |
|---|---|
| `@agent` | which agent row started it, e.g. `claude (YOLO)` |
| `@trails_id` | the conversation it is in (see Surviving tmux) |
| `@trails_dir` | the directory, verbatim from `$PWD` at launch |
| `@trails_ws` | its workspace |
| `@trails_session` | its session's name, also its record's key |
| `@trails_label` | the codebase label |
| `@trails_name` | the name you gave it, if any |
| `@trails_since` | when it started, Unix time |

The trail's window carries `@trails_window` (the trail's key), `@trails_dir`,
`@trails_ws` and `@trails_label`, and each of its panes `@trails_pane`: `agent`,
`editor` or `shell`. The agent pane also carries `@ag` and `@dir`, the agent and
the codebase label, as a map pane does: its own command is `tmux`, so a
`pane-border-format` that labels panes by command reads them instead, e.g.
`#{?@ag,#{@ag},#{pane_current_command}}`. An editor or shell window carries
`@trails_tool` (`editor`, or `shell` for a released window that kept only a
shell) with `@trails_dir`, `@trails_ws` and `@trails_label`.

Until 1.4 these tags were `@trails_view`, `@trails_cell` and `@trails_companion`,
and the panes `view` and `edit`. Every read takes both spellings for one release,
so a trail running through the upgrade is still found; writes use the new ones.

**A trail is a session** because a client attaches to a session, never to a
window, and every client of a session shares its current window: an editor
attached to the workspace would follow whatever window you browse to
([ADR 14](decisions/0014-editor-views.md)). So the agent runs in a session of its
own, and the workspace shows it through the trail's window, whose first pane is a
nested client of that session, the way a map pane is
([ADR 16](decisions/0016-the-trail-lives-in-its-view.md)). The editor and a shell
can then sit beside the agent in that window without the session, and so an
editor's panel, ever seeing them. The session goes when the agent exits, and the
window's client with it; a window you killed is rebuilt by the next attach
(`ensure_window`), since the trail lives on, and one that lost only its agent
pane, the nested client detached, gets the pane back the same way. Named trails name their session:
`lattiq/payments`. tmux gives a window one size, so a session shown by two clients
of different shapes (the trail's window and an editor's panel) is sized to the one
you last typed in, and the other sees it clipped or filled: accepted, as in the
map.

**Trails from before 1.0** are sessions named `trails-<project>` with `@agent` and
`@trails_id` as session options. They are listed by prefix, attached to and ended
as sessions, and their record keeps its old key until a restore moves it. `$PREFIX`
is the only place the prefix is spelled.

### Workspaces

`load_workspaces` reads the config once per run into lines of
`name|root|pattern`, `~` expanded, a bare list taken as the codebases, and a name
tmux could not use skipped with a warning. `workspace_of DIR` tries the
directory, the repository it is in, and that repository's main checkout
(`git rev-parse --git-common-dir`), nearest first; for each, the most specific
entry wins, an exact path over a glob and a longer glob over a shorter one, with
`*` crossing `/` as a `case` pattern does. No `workspaces` key means `default`;
some configured and none claiming the directory means no answer, which is the
picker's cue to ask.

The workspace session is created by the first trail or editor window, as
`new-session -d -s NAME` with that window, and marked. A session of that name
without the mark is refused (D1 in the design). The last window out takes the
session down with it, so no empty session is left.

### Where an attach lands

An editor's terminal attaches to the trail's session; a terminal of your own
attaches to the workspace on the trail's window (`attach -t '=ws:@window'`),
made again first if you killed it. Inside tmux the first nests a client of the
session in the pane, as a map pane does, and the second runs `switch-client`.
`from_editor` tells them apart by `NVIM`, `ZED_TERM` and `TERM_PROGRAM` (which
tmux overwrites inside a pane, so there the first two decide), and
`TRAILS_ATTACH=session|workspace` overrides (`view`, the old spelling, still
works). `launch` strips `NVIM` and `ZED_TERM` from the environment it starts a
tmux server with, since a starting server copies its client's environment into
every later pane.

Every `switch-client` names the client trails is acting for, read at startup
(`CLIENT`). Without `-c`, tmux switches its idea of the current client, the
most recently active one, and by the time trails switches that can be a nested
client it has just started: the nested client in a trail's window, or a map pane.
Under a fast `default-shell` that client was up first, and got switched to the
workspace in place of the terminal that asked. With two terminals on one
workspace the guess can also be the other terminal, so the client is found in
order: `TRAILS_CLIENT`, which the `run-shell` bindings from `trails keys` pass
as `#{client_name}` (run-shell expands formats, display-popup does not); from a
shell in a pane, the client showing `TMUX_PANE`, the most recently active when
several do; else tmux's guess, which inside a popup is the client that opened
it. A client found this way that is itself a pane of the server, the nested
client in a trail's window or a map pane, is followed outward to the terminal
showing that pane (`client_outer`): a key pressed there with the double prefix
names it, and switching it to the workspace would put the workspace inside its
own window.

## Finding trails

`sessions` is one `list-windows -a` for the box. A window is a trail when it
carries `@agent` and `@trails_session` and lives in that session (the row from the
session named by its key; the trail's window in the workspace has no `@agent`), or
when its session has the 0.6
prefix. Each row is `wid key ws agent-label dir codebase
badge task`, and the pass also keeps every record's task and conversation current
(below). `classify` adds the state and the peer name in front of and before the
task. Everything above reads these rows: `live_trails` keeps this directory's or
one workspace's for the picker, `ls_rows` the lot for `trails ls`, `map_menu` for
the map.

The badge (`#2`, `#payments`, `-`) is read off the key against the codebase label
and the name, never off a name alone.

## Agents

What trails can start comes from `~/.config/trails/config.json`, or the built-in
agents (the same JSON, inside the script) when there is no file. `load_agents`
reads it once per run with `jq` and turns each agent into one line,
`name|command|args|yolo|start|resume|idform|create|find|naming`, default agent first. Everything
else asks through `agent_row`. A bar, not a tab, separates the fields, because
most agents leave some empty and tab counts as whitespace to `read`.

The config's `mode` is read alongside, by `load_mode`, and only the picker uses it: a
`new` row is YOLO when the mode says so or Tab flipped it, not both, and only
if its agent has a `yolo` flag.

`launch` builds the command from that line: the program's words, the YOLO flag if
the row was armed, then the session template with `{id}` filled in: `resume` with
the ID being resumed, else `start` with a fresh ID, else `resume` with one that
`create` printed. An agent with only `find` starts with no ID and no record;
`rec_note_id` writes the record once the reader can see the conversation.

The readers are built in. `claude` asks claude's `~/.claude/sessions/<pid>.json`
for the window's process, and reads the trail's state from the same file.
`codex` looks for the rollout file the codex process holds open (`lsof`), else the
newest `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` whose first line names this
directory, written since the trail started (`@trails_since`), that no other record
claims. An agent without a `session` block still launches; it just gets no record,
so it can't be restored.

The record and the tmux `@agent` option hold the agent *name*. Rename or remove
an agent and its lost rows fail to restore with "unknown agent" and keep their
record until the agent is back or the row is forgotten.

## Trail states

Every trail has two signals: whether it is running (`●`) or not (`○`), and a
state word. One table in the script, `STATES`, holds each state's glyph, colour,
word, legend line and sort position, and every view draws from it: the picker,
`trails ls` and its legend, the map, and the TSV's `state` column.

| State | Running | Comes from |
|---|---|---|
| needs you | yes | `classify`: still, and asking (`blocked` inside the script) |
| your turn | yes | `classify`: still, not asking (`idle`) |
| working | yes | `classify`: the screen changed |
| lost | no | a record whose trail is gone |
| closed | no | an agent's own history, with nothing running it |
| elsewhere | no | the same, but held open by a `claude` trails didn't start |

The README has the lifecycle diagram. Running versus stopped is decided by state
name, never by glyph: macOS awk compares strings by locale collation, which ranks
`●` and `○` equal.

## Who wants you: working, your turn, needs you

There are no per-agent hooks. Claude Code's hooks would report this exactly, but
only for Claude, and they need setting up. Two signals are used instead, in order
([ADR 11](decisions/0011-an-agents-own-state-beats-its-screen.md)).

**The agent's own record, where it keeps one.** `agent_state` asks the reader the
agent's config names as `session.find`. `claude` reads `status` from
`~/.claude/sessions/<pid>.json`, the same file it reads the conversation from:

| `status` | State |
|---|---|
| `busy` | `working` |
| `waiting` (a dialog is open, `waitingFor` says which) | `blocked` |
| `idle` | `idle` |

`codex` reads the last turn event in the trail's rollout,
`rollout-<time>-<id>.jsonl`, found by its `@trails_id`. A `task_complete` or
`turn_aborted` there is `idle`. A `task_started` falls through, because codex
doesn't write approval prompts to the rollout, so only the screen can tell working
from blocked.

No file, or a value the reader doesn't know, falls through to the screen.

**The screen, for everything else.** Each TUI animates while it works (spinner,
timer, token count), and a stopped one sits still. So `classify` captures the
visible screen of every window left over, waits `AGENT_SETTLE` (0.35s), and
captures again:

| State | Rule |
|---|---|
| `working` | the screen changed between the samples |
| `blocked` | still, and the bottom 15 lines match `AGENT_ASK_RE` |
| `idle` | still, and not asking |

The sleep is paid once for the whole list, and not at all when every trail
answered from its record. Pane pids and the process tree are read once per pass.

The screen's error is mostly one-sided: `working` needs two samples to differ, so
the bad case is a slow agent read as idle. The exception is anything an idle agent
redraws on a timer. A Claude status line with a `refreshInterval` did exactly that,
and is why Claude is read from its record. `blocked` vs `idle` is the screen's one
heuristic, and both sort above `working`, so a wrong guess costs a colour, not a
missed agent.

A tmux timestamp doesn't work instead: `#{session_activity}` tracks tmux's own
alert bookkeeping, not bytes written to the pane.

## trails ls

`ls` answers "what's here", the picker's rows as text (`ls DIR` the same for
another directory), and `ls -a` answers "where is everything", box-wide
([ADR 10](decisions/0010-ls-is-this-directory.md)). All three are one list built
by `ls_rows`, in `STATES` order: running trails most-wants-you first, then lost
ones, then ended conversations newest first.

Piped, it is TSV, a contract for notifiers: `life state session agent yolo dir id
when pid peer workspace title`, `life` being `running` or `stopped` and `session`
the trail's session name (or a 0.6 session's). An empty field is written `-`, never
left empty, because tab counts as whitespace to `read` and two tabs in a row
collapse, shifting every later field. The title goes last because it is free
text, and new fields go in front of it. On a terminal it is a padded table, the
badge leading and the workspace after the agent; `ls_rows` carries the badge as an
extra leading field that the TSV drops, since a badge needs the label and name
the TSV doesn't carry.

Reading conversation history costs most of an `ls`. `TRAILS_RECENT_MAX=0` skips it,
for a menu-bar poll that only wants running trails.

## Surviving tmux

Every agent lives inside the tmux server, so a reboot, a crash or
`tmux kill-server` takes them all down. The conversations survive, since each CLI
keeps its transcripts. What dies is the knowledge of which conversation belonged
to which trail.

So `trails` writes that down outside tmux, one file per trail, keyed by its
session's name (one directory down), or by its session name for a trail from 0.6:

```text
~/.local/state/trails/sessions/lattiq/augur-2
agent=claude
dir=/Users/me/code/augur
id=15fcb95c-19cc-49dc-a7fc-7a7dd032e5c9
yolo=yolo
task=Fixing the flaky test
workspace=lattiq
label=augur
name=
```

**The ID is chosen up front.** `trails` generates it and starts the agent under it
(`claude --session-id`, `opencode --session`), then resumes by it (`--resume`,
`--session`). `--continue` would not do: it means "the latest conversation in
this directory", so two trails in one codebase would resume the same one.

**The task is kept current** by every `sessions` pass, which a menu-bar poll
runs every few seconds, so a lost row can say what the trail was doing.

**So is the conversation.** The ID trails chose is only where a trail started:
`/resume` or `/clear` inside claude moves it to another one. Every `sessions`
pass asks claude which conversation it has open (the pane's process is the wrapper,
its child is claude, and `~/.claude/sessions/<pid>.json` names the `sessionId`).
When that differs, the record and `@trails_id` follow it. Otherwise a restore after
tmux dies would bring back the conversation you left, and the one you were in would
look like a stranger's.

**Deleting a record at the right moment is the hard part.** A trail you quit
is over, and a trail tmux took down is the whole point, but from outside both
look the same. tmux's hooks can't tell them apart: `session-closed` also fires
partway through `kill-server`, and `pane-exited` reports the wrong session name.
So the agent runs under a small `sh` wrapper:

```sh
self=$1 name=$2 resume=$3; shift 3; trap : INT QUIT; t0=$(date +%s); "$@"; s=$?
  [ -n "$resume" ] && [ "$s" -ne 0 ] && [ $(($(date +%s) - t0)) -lt 20 ] ||
    "$self" --forget "$name"
  exit $s
```

When the agent exits by itself, the wrapper forgets the record. When tmux dies,
it hangs up on the whole process group and the wrapper dies to SIGHUP before it
can forget anything. A reboot runs nothing at all.

One exit keeps the record: a resume that fails within its first 20 seconds. An
agent can take longer than the launch check to start and then refuse the resume
(claude starting several MCP servers, then "No conversation found"). Forgetting
the record then would lose the only pointer to the conversation, so the trail
comes back as lost, to retry or forget.

**A record is dead** when no window carries its key (`@trails_session`, or the
session name for 0.6) together with its ID as `@trails_id`, not when no session
has its name. Otherwise a session you created by hand under the same name would
hide it. The trail's window killed is nothing to a record: the trail lives in its
session. A
dead record also keeps its name reserved, so a fresh agent lands on `-2` and
can't overwrite it.

`trails restore` brings back every dead record, detached, in its own directory,
into the workspace the config gives that directory now (the record's workspace
only when no entry claims it), rebuilding its session and its window and keeping the
name. If claude refuses the ID (`No conversation found`, an agent you
never typed into), it starts fresh in its place. If the agent can't start at all,
the record is put back for next time. Companions are not restored.

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

The codebase screen and `trails ls` show this directory's; a workspace's screen
shows the box's that its workspace claims; `trails ls -a` shows every directory's.

Conversations a record holds are left out, since they're already running or lost
rows. A conversation still open in a `claude` that `trails` didn't start is
marked `!`, and Enter refuses it. Claude writes a file per running process,
`~/.claude/sessions/<pid>.json`, naming its `sessionId`, so "open" is that file's
pid being alive. Resuming it would put a second Claude on the conversation, each
adding turns the other never sees.

## The picker

One command, five screens, chosen by `TRAILS_PICKER` (which the reload
subprocesses inherit) and, for a workspace's, `TRAILS_WS`. A bare `trails` picks
the screen from where it runs: an editor's terminal always gets its codebase's;
inside tmux a client whose session is a workspace gets that workspace's, which a
popup over it inherits; `~` and `/` get the workspaces; anything else is a
codebase.

| Screen | `TRAILS_PICKER` | Rows |
|---|---|---|
| this codebase | *(empty)* | running and lost trails here, editor and shell windows, a `new` row per agent, `↩ resume old trails` |
| its ended conversations | `old` | closed and elsewhere, from that last row; Esc goes back |
| a workspace | `workspace` | its running and lost trails and windows across its codebases with a codebase column, `＋ new trail…`, `↩ resume old trails` |
| its ended conversations | `workspace-old` | |
| a codebase's agents | `agents` | a `new` row per agent, for the directory `＋ new trail…` picked; Esc goes back to the workspace (`TRAILS_BACK`) |
| the workspaces | `ws` | one row each with what runs in it, the last attached marked and under the cursor |

`print_menu` builds TSV rows of `verb`, `target`, `what's drawn`. fzf draws only
the third field. Trails are gathered first as raw rows (`state verb target dir
codebase agent yolo badge when title`) and drawn together in `STATES` order so the
columns line up; editor and shell windows follow with their kind where the state
goes. Tab and
ctrl-x pass the target to a subcommand of the script (`--toggle-yolo`, `--kill`)
and reload the menu. They're subcommands rather than inline shell because fzf
runs its bindings through `$SHELL`, where zsh expands a leading `=` and silently
ate the kill. The preview is `--peek`, the row's screen through `capture-pane`,
and ctrl-e comes back through `--expect` so the editor it opens gets fzf's
terminal.

The running block is classified once per picker run and cached in a temp file,
because `classify` sleeps and every Tab reloads. Recent rows are cached the same
way; on the workspace picker the cache holds every trail classified, for the
counts.

| Verb | Target | Enter does |
|---|---|---|
| `new` / `yolo` | agent, or `agent:dir` on a workspace's screen | launch a fresh agent, with the YOLO flag for `yolo` |
| `attach` | window id | `attach_to`: the workspace on the trail's window, or its session |
| `restore` | record key | `restore_one` in the record's directory, then attach |
| `resume` / `resume-yolo` | `agent:id:dir` | launch with the resume flag and that ID in that directory, recorded like any launch; `resume-yolo` when it last ran YOLO (unless Tab flipped it back) or Tab armed it |
| `open` | `agent:id:dir` | refuse, naming the process that has it |
| `tool` | window id | an editor or shell window: switch or attach to it |
| `browse` | | `pick_codebase`: the workspace's codebase tree (`codebase_tree`), walking the file system from a `browse:DIR` row (`walk_dir`), then the agents screen |
| `workspace` | name | `ws_switch`: switch or attach to its session on the trail that most wants you, or its screen |
| `more` | | the ended-conversations screen |

A codebase or agents screen in a directory no workspace claims first asks which
workspace its trail goes in (`ask_workspace`): `default` first, adding nothing,
then the workspace browsed from (`TRAILS_BACK`), then the rest, each adding the
directory to it as a codebase.
ctrl-n on the workspace picker names a new workspace and takes its first codebase
from the directories under `~`.

`launch` creates the trail's session detached, holding the agent's window with
`status off`, stamps the window, makes the trail's window in the workspace (with the
workspace session around it when there is none), waits 1.5s and checks the pane
isn't already dead before attaching. An agent that fails at once (a bad token, no
keychain) would otherwise take its error with it and look like nothing happened.

## The editor and a shell

`trails edit` and `trails shell` put the editor and a shell beside the agent, as
panes of the trail's window, marked `@trails_pane` `editor` and `shell` beside the
`agent` pane. The trail's session holds the agent alone, so an editor's panel or a
map pane attached to it sees neither. Run again, the command selects the pane that
is there; run from that pane, it goes back with `select-pane -l`. In the code
these are `tool`, `tool_find` and `tool_make`.

`window_layout` decides where the panes go from which of them exist, whatever
the order they were opened in: the agent alone fills the window; a shell with no
editor pane runs along the bottom, full width, a quarter high; an editor pane
takes the left 60% and the agent the right 40%; a shell with an editor pane sits
under the editor only, a quarter high. It uses `move-pane` (tmux 3.2), which puts
a pane where it belongs whether it was there already or not, then `resize-pane`
for the sizes, since a size given to `move-pane` is taken from the pane it splits.
It runs after every pane is made, and the editor pane's command ends by running
`trails --layout` in the background, so a shell that sat under the editor goes
back along the bottom once the pane has gone. The window you are on decides: from
a trail's window or an editor or shell window, that window; from a plain window in
the workspace, the window of the trail in the pane's directory that most wants
you; outside tmux, the current directory's or `DIR`'s. Directories are compared
resolved, because tmux reports a pane's path through symlinks.

With no trail in the codebase, `edit` makes the editor alone as a window in the
workspace, `<codebase>·nvim`, marked `@trails_tool editor`, and `shell` goes along
its bottom. Such a window is renamed and re-marked for what it holds whenever its
panes change (`tool_remark`): `<codebase>·shell` once the editor has left, the
editor's name again when one is opened in it. When a trail ends with panes beside it, `window_release` turns the
trail's window into such a window rather than killing what you had open: renamed
for the editor (or `<codebase>·shell`), marked `@trails_tool`, the trail's mark
dropped. Run by the agent's wrapper on exit and by `trails end` and ctrl-x before
they kill the session. An editor's terminal is shown no editor or shell rows in
the picker.

## Keys

trails binds nothing. `trails keys` prints lines for a tmux.conf: the picker and
the workspace picker in a `display-popup`, which leaves no window behind and from
which `switch-client` works (the popup check behind D4 of the design is
`test/t-popup.sh`), and the editor and the shell. The popups are styled onto the
terminal's own background (`-s`, `-S`, tmux 3.3): tmux 3.8's default
`popup-style` is a theme grey, gray45 when the terminal reports a light theme,
and the picker's dim text is unreadable on it. The colour's name is chosen by
`tmux -V`: in a style `bg=default` means the base style's background, which for
a popup is `popup-style` itself, so on 3.8 it keeps the grey; 3.8 added
`bg=terminal` for the terminal's own, and a tmux before it rejects the word.
`prefix P`, `W`, `e` and `` ` `` are free in tmux 3.8's default table; `P` is
"pick a trail", and the backtick for the shell is the editors' own
toggle-terminal key.

## The menu-bar plugin

`extras/swiftbar/trails.10s.sh` is a SwiftBar plugin, installed into
`share/trails/swiftbar/` with its icons. It is a reader of `trails ls -a`, not
part of trails: every 10 seconds it runs `TRAILS_RECENT_MAX=0 trails ls -a`, keeps the
running rows, and draws them.

- **Icon:** twelve pre-drawn PNGs in `icons/` (three top-dot states, two bottom,
  for a light and a dark bar), made by `assets/render.swift --menubar`. A
  coloured image can't be a template image, so the plugin picks the light or dark
  set from the system appearance.
- **Notifications:** it remembers each trail's state between polls in
  `~/.cache/trails/swiftbar-state` and speaks on the working → stopped edge, once,
  after `TRAILS_NOTIFY_AFTER` seconds. Nothing can tell whether you're looking at
  a trail, so the wait is what keeps the one you're working in quiet.
- **Resume** runs `trails open` on the key as the command of a new tab, through
  the chosen terminal's AppleScript, so it lands where the picker would: the
  workspace on the trail's window, with the editor and shell beside the agent. The
  choice is stored in `~/.config/trails/terminal`, not in SwiftBar's storage for
  the plugin: SwiftBar names that after the plugin's resolved path, which through
  Homebrew carries the version, so every upgrade would start it empty.
- **End** runs `trails end` on the key, which kills the trail's session (the
  nested client in the trail's window exits with it, and the window keeps any
  editor or shell beside the agent as an editor or shell window) or a 0.6
  session, and forgets the record.

A launchd job has no locale, and a tmux client in the C locale rewrites every
byte it cannot print as `_`, the tab between two format fields included. trails
exports a UTF-8 `LC_CTYPE` when the caller set none, so what the plugin asks for
reads the same as it would from a shell.

`trails swiftbar` links the plugin into SwiftBar's plugin folder (read from
`defaults read com.ameba.SwiftBar PluginDirectory`). It links through the path the
script was invoked by, `/opt/homebrew/bin/../share/…`, not the resolved Cellar
path, so the link survives `brew upgrade`. It never replaces a real file.

## The map

`trails map` is a tmux session named `trails_map` whose panes are each a tmux
client attached to a trail's session, which already holds exactly one trail (a
session that is gone is a trail that is gone). It borrows the session and owns
nothing: kill it and
every agent is where it was. That's why it is never reconciled, only rebuilt, and
why it lives in no workspace: it shows the trails that most want you across all
of them. The name is outside `$PREFIX`, under which `trails ls` would count it as
an agent that is always working; the underscore matters, since `trails-map` is
what a project folder called `map` would have got.

Panes are ordered most-wants-you first and re-tiled after every split, since
splitting halves the current pane and runs out of room fast. Two agents go side
by side only when the terminal is at least 160 columns wide, measured on the
client that asked (`CLIENT`), since tmux's guess can be the nested client in a
trail's window, a fraction of a window wide; the config's `map.two` (`side`, `stacked`) settles it
instead, and `map.layout` names the tmux layout for three or more. Each pane is
stamped with `@dir` and `@ag` so its border can read `<dir> · <agent> · <task>`.

A tmux window has one size, so a trail watched by a map pane and, say, a Zed
thread can't be drawn right for both. `window-size` stays at tmux's default
`latest`, so the client you last typed in wins and the other catches up when you
press a key there.

Inside the map, a shell you split off (`C-b |`) can run `trails`. The agent
still gets its own window in its workspace, and that pane becomes a viewer of
it.

## The README demos

`assets/workspace.gif`, `assets/nvim.gif` and `assets/map.gif` are recorded with
[VHS](https://github.com/charmbracelet/vhs) from `assets/demo/*.tape`, with the real
Claude Code: the map demo gives four agents a small task each, so a recording costs a little
of your plan. Each tape first sources `assets/demo/sandbox.sh`, which gives trails
its own config (a workspace `acme` over `~/code/*`), records and tmux server, and a
sample Go project at `~/code/checkout` (refused if that exists, removed afterwards).
The demo's tmux runs through a wrapper that loads the demo's own config, the
`trails keys` bindings and a plain status line, so the recording machine's tmux.conf
is not in the shot. trails reads a sandboxed Claude history holding only two example
conversations, so `trails ls -a` never lists the machine's own projects; a wrapper
drops that setting before running the real `claude`, whose demo conversation is
removed afterwards too. The repo's own `bin/trails` comes first on `PATH`, so a
re-record shows the version being released. After a change to what the picker or
`ls` shows, re-record from the repo root, with `claude` logged in:

```console
vhs assets/demo/workspace.tape
vhs assets/demo/nvim.tape
vhs assets/demo/map.tape
```

## Tests

`test/run.sh` runs the integration tests in `test/t-*.sh`, one per area: launch,
ls, classify, picker, screens (the workspace screens), tools (the editor and the
shell), inside (inside
tmux: switch-client, a nested editor client, the refused collision), legacy (0.6
sessions beside the new model), restore, map, workspace (the config), and the
popup check behind D4 of the design. CI runs them after ShellCheck. Each test is
its own process on its own tmux server in a throwaway `HOME`: `TMUX_TMPDIR` puts
the socket there, `XDG_CONFIG_HOME` and `XDG_STATE_HOME` give it a config and
records of its own, and `TMUX`, `TERM_PROGRAM`, `NVIM` and `ZED_TERM` are unset so
trails sees a plain terminal outside tmux even when the tests run from an editor
inside one. Nothing in `bin/trails` knows it is under test.

Three stand-ins on `PATH` from `test/bin` do what a person, a CLI and an editor
would:

- **`agent`** plays the agent. It takes the flags trails passes and then reads commands
  from its pane, so a test drives it with `tmux send-keys`: `ask` puts a question on
  screen, `busy` changes the screen for two seconds, `title` sets the task, `exit` quits.
- **`fzf`** plays the picker's keyboard. It prints the first row matching `$FZF_PICK`,
  copies the rows it was given to `$FZF_DUMP` (numbered, one block per fzf a run
  opens), and with ctrl-n among `$FZF_KEYS` runs the bound command so `$FZF_QUERY`
  becomes the name typed. `$FZF_PICKS` and `$FZF_KEYS` may name files whose lines
  are taken one per fzf, so a test can drive a screen that leads to another;
  `$FZF_KEY` is what `--expect` reports. No match is Esc.
- **`ed`** plays the editor: it says where it opened and waits for `exit`.

A test that needs trails attached, or fzf on a terminal, runs it in a *driver*: a session
on the test server whose pane is the terminal, with `TMUX` unset so trails attaches as a
nested client, the way the map does. Not `script(1)`: it passes an EOF on its own stdin
through the pty as ^D, which the agent reads as the end of its input. Where a client
is, `client_at` reads from `list-clients`, whose formats expand in the client's own
context; `display-message -c` only picks where a message is shown.
