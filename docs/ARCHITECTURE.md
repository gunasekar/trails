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
- **Finding:** the picker's levels (workspaces, workspace, codebase, agent), `trails ls` for this directory,
  `trails ls -a` for every one, and whether each agent is working or waiting on
  you.
- **Resuming:** a record per trail that outlives tmux, `trails restore`, and
  ended trails, from trails' own history of what it ran.
- **Ending** a trail, or forgetting a lost one.
- **Workspaces:** which codebases go together, from the config, and a session
  per workspace to switch between over one connection.
- **The editor and a shell** beside a codebase's trails
  ([ADR 15](decisions/0015-companions-are-marked-windows.md)).
- **The map**, several trails in one window, as a window that owns nothing.
- **A TSV contract** (`trails ls`) for other tools to build on: a status bar, a
  notifier, a script.

Out of scope:

- **A UI around the agents.** No TUI or GUI of trails' own: once you're attached,
  you're in tmux and the agent's own interface.
- **A daemon.** Nothing of trails runs between commands, except the small wrapper
  that moves a trail's record into the history when its agent exits.
- **Per-agent integrations.** No APIs into the agents, and none of their files
  read ([ADR 19](decisions/0019-no-agents-files-read.md)). trails knows an agent by
  its config entry ([ADR 7](decisions/0007-agents-in-a-config-file.md)), and hears
  from it through the agent's own hooks, which call `trails state` and are the
  user's to set up ([ADR 18](decisions/0018-status-from-the-agents-hooks.md),
  [the README](../README.md#hooks-for-each-agent)).
- **The agents' work itself:** git worktrees, branches, diffs, prompts or task
  queues. trails puts you in the trail, and what happens there is the agent's
  business and yours.
- **Owning conversations.** They stay in each agent's own store, which trails
  never reads. It keeps a history of the trails it ran (their records, see
  [History](#history)), not of what was said in them.
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
| Trail | one agent working in one codebase | a session of its own, `<workspace>/<codebase>-<ID>` or `<workspace>/<name>`, `status off`, holding one window with the agent in it: what an editor attaches to, one trail and nothing else |
| The trail's window | how the workspace shows a trail | a window in the workspace session named like the agent's, marked `@trails_window`, whose first pane is a nested tmux client of the trail's session |
| Agent, editor, shell and diff panes | the agent, with your editor, a shell and the live diff beside it | panes of the trail's window, marked `@trails_pane` `agent`, `editor`, `shell` or `diff` |
| Editor or shell window | your editor or shell with no trail in the codebase, or left when one ended | a window `<codebase>·nvim` or `<codebase>·shell` marked `@trails_tool` (`editor` or `shell`); a *tool window* in the code |
| Map | several agents side by side | panes, each a nested client of a trail's session, in a window no editor attaches to |

The words are tmux's own, plus trail. A trail has two windows: the agent's, in
the trail's session, and the trail's, in the workspace. Where it matters the text
says which.

The agent's window, and the trail's window after it, is named `<codebase>-<ID>`
for an unnamed trail, its trail ID without the `t` (`augur-3f9a`,
[ADR 22](decisions/0022-an-unnamed-trail-is-named-by-its-id.md)), or
`<codebase>·<name>` for a named one: the trail's key without its workspace (a
trail renamed while it runs keeps its session, below), and not the agent, which
the picker shows. The
codebase label is the directory's basename with `.`, `:` and spaces turned into
`_`, or `<repo>@<branch>` for a worktree.

trails titles the terminal its sessions are shown in, setting `set-titles` and
`set-titles-string` on each session it makes, so the titles hold on any tmux.conf
and every other session's stay the user's. A workspace, and the map, read
`trails · <host>`. A trail's session reads `<agent> · <task>`, the task being the
title the agent gives its pane (its directory until it gives one): the trail's
window in the workspace and the map's panes show the trail through a tmux client of
that session, so that title is their pane's title too, and the map's borders are
made from it.

Everything trails knows about a trail is on the agent's window, in the trail's
session, so nothing is parsed back out of a name:

| Option | Holds |
|---|---|
| `@agent` | which agent row started it, e.g. `claude (YOLO)` |
| `@trails_id` | the conversation it is in (see Surviving tmux) |
| `@trails_dir` | the directory, verbatim from `$PWD` at launch |
| `@trails_ws` | its workspace |
| `@trails_session` | its session's name, its address in tmux |
| `@trails_trail` | its trail ID, its record's name (ADR 20) |
| `@trails_label` | the codebase label |
| `@trails_name` | the name you gave it, if any |
| `@trails_since` | when it started, Unix time |

The trail's window carries `@trails_window` (the trail's key), `@trails_dir`,
`@trails_ws` and `@trails_label`, and each of its panes `@trails_pane`: `agent`,
`editor`, `shell` or `diff`. The agent pane also carries `@ag` and `@dir`, the agent
and the codebase label, as a map pane does: its own command is `tmux`, so a
`pane-border-format` that labels panes by command reads them instead. The editor
and diff panes carry `@trails_cmd` (the editor's name, `hunk`) for the same reason:
their commands are compound lines, so the process in front is the shell running
them. The window's format is
`#{?@ag,#{@ag},#{?@trails_cmd,#{@trails_cmd},#{pane_current_command}}}`
(`PANE_LABEL_FMT`), set when the window is made and again by every `window_layout`,
with the diff pane's label, so a window from before a change to either reads the
current one without being rebuilt. An editor or shell window carries
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
own window. A `TMUX_PANE` with no `TMUX` beside it is another server's, left by an
`unset TMUX`, and is dropped first: a server trails started would take it into its
global environment, and every `run-shell` binding and popup there would read it as
the pane it ran in, so `prefix e` opened the editor beside whatever trail held that
pane id.

A client on a session grouped with a workspace's (`tmux new-session -t acme`, a
second terminal on one workspace) is that workspace: `client_ws` reads the mark
from the session its group is named after, since tmux copies no session options
into a group, and `switch_to` keeps such a client on its own session, selecting
the same window there, so it keeps a current window of its own. Any other client
is switched as asked.

## Finding trails

`sessions` is one `list-windows -a` for the box. A window is a trail when it
carries `@agent` and `@trails_session` and lives in that session (the row from the
session named by its key; the trail's window in the workspace has no `@agent`).
Each row is `wid key ws agent-label dir codebase
badge task`, and the pass also keeps every record's task and conversation current
(below). `classify` adds the state in front. Everything above reads these rows: `live_trails` keeps this directory's or
one workspace's for the picker, `ls_rows` the lot for `trails ls`, `map_menu` for
the map.

The badge (`#3f9a`, `#payments`; `#2` and `-` for unnamed trails from before 1.10)
is read off the key against the codebase label and the name, never off a name alone.

What tmux is asked for comes back with its fields between `$US`, the unit
separator, never `|` (a directory may hold one) nor a tab (the shell reads a tab
as whitespace and drops empty fields). tmux 3.4 and 3.5 print a control character
in a format's output escaped, `$US` as the four characters `\037`, where 3.3 and
3.8 print the byte; so trails' `tmux` function puts the byte back in the output of
any command whose arguments carry `$US`, keeping tmux's exit status. tmux escapes
no backslash, so `\037` there can only be the separator. A `read` with that IFS is never fed a
command substitution of its own: its IFS would split the substitution's words.

A key trails is handed (by the picker, the map) is checked by `key_ok`: a
`WORKSPACE/NAME`, and nothing with `..` or a leading `/`. A record is named by a trail
ID, `t` and four hex digits, or eight for one from 1.8 or 1.9 (`tid_ok`), and
`rec_path` finds nothing for anything else, so no argument reaches outside the
records' directory.

## Agents

What trails can start comes from `~/.config/trails/config.json`, or the built-in
agents (the same JSON, inside the script) when there is no file. `load_agents`
reads it once per run with `jq` and turns each agent into one line,
`name|command|args|yolo|start|resume|idform|create|naming`, default agent first. Everything
else asks through `agent_row`. A bar, not a tab, separates the fields, because
most agents leave some empty and tab counts as whitespace to `read`.

The config's `mode` is read alongside, by `load_mode`, and only the picker uses it: a
`new` row is YOLO when the mode says so or Tab flipped it, not both, and only
if its agent has a `yolo` flag.

`launch` builds the command from that line: the program's words, the YOLO flag if
the row was armed, then the session template with `{id}` filled in: `resume` with
the ID being resumed, else `start` with a fresh ID, else `resume` with one that
`create` printed. An agent with neither picks its own ID, and starts with no record:
`rec_note_id` writes it once the agent's hooks say the ID (`trails state WORD --id
ID`). trails has no readers of an agent's files. An agent without a `session` block
still launches; it just gets no record, so it can't be restored.

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
| needs you | yes | `classify`: the agent is asking (`blocked` inside the script) |
| your turn | yes | `classify`: its turn ended (`idle`) |
| unknown | yes | `classify`: nothing said |
| working | yes | `classify`: it is busy |
| lost | no | a record whose trail is gone |
| closed | no | trails' history of the trails that ended |

The README has the lifecycle diagram. Running versus stopped is decided by state
name, never by glyph: macOS awk compares strings by locale collation, which ranks
`●` and `○` equal.

## Who wants you: working, your turn, needs you

The agent says ([ADR 18](decisions/0018-status-from-the-agents-hooks.md)), and
nothing else does ([ADR 19](decisions/0019-no-agents-files-read.md)).

`trails state working|waiting|idle [--id ID] [--agent PROGRAM]`, run from the agent's
hooks, sets `@trails_state` on the agent's pane, the hook's `TMUX_PANE`;
`@trails_worked` once the conversation has had a turn (it said *working*, or any word
after its first); and `@trails_said_id` when the hook passes the conversation. A call
whose `--agent` isn't the trail's agent's program (`@trails_program`, set at launch)
is dropped whole: an agent the trail's agent runs from its shell, of another kind,
inherits the pane, and would otherwise speak for the trail.
It is dispatched at the top of the script, before the config or the agents are
read, since it runs on every turn of every hooked agent, and it is silent and exits
0 whatever happens, since a hook's output can land in the transcript and a failing
hook is reported on every turn.

An ID is taken only if it is one (a letter or digit, then letters, digits, `_ . -`)
and only from the trail's own agent. An agent the trail's agent starts from its
shell (a `claude -p`) inherits the pane, and its hooks would say its own
conversation; but the trail's agent is the one nearest the pane's process, so the
first ID records how many processes up from the hook the pane's process is
(`@trails_said_depth`), and an ID from deeper down is left out. When the ID is not
the one the trail carries, `trails state` starts `trails --said` in the background,
a `sessions` pass that moves the record at once (`rec_note_id`), rather than at the
next listing; only for a trail's pane (`@trails_session`), not any pane a hook runs in.

`classify` reads every trail's word in the one `list-windows` of its pass:
`working`, `waiting` (`blocked` inside the script) or `idle`; anything else, or
nothing, is `unknown`, grey, sorted between *your turn* and *working*.

The screen is not read. Up to 1.5 it was: two captures `AGENT_SETTLE` apart,
changed being working and a question on screen needing you. It guessed, and a
status line or countdown that redraws an idle screen read as working; hooks know.
Up to 1.6 Claude's own state file answered too, and Codex's rollout for its
conversation; 1.7 reads neither.

The hooks for each agent are in [the README](../README.md#hooks-for-each-agent), as documentation: the
events that mean working (a prompt sent, a tool done; the second clears *waiting*
once a permission is granted), waiting (a permission prompt, a question) and idle (a
session started, a turn ended), and where the agent can say it, the conversation.
Getting the ID out of the agent is the snippet's job, in the agent's terms. The
repo's Claude Code plugin, `plugins/trails`, carries Claude's; a test keeps it equal
to the docs. Copilot and Cursor have no hook for a permission prompt, so their hooks
say working through one.

## trails ls

`ls` answers "what's here", the picker's rows as text (`ls DIR` the same for
another directory), and `ls -a` answers "where is everything", box-wide
([ADR 10](decisions/0010-ls-is-this-directory.md)). All three are one list built
by `ls_rows`, in `STATES` order: running trails most-wants-you first, then lost
ones, then ended ones newest first.

Piped, it is TSV, a contract for notifiers: `life state session agent yolo dir id
when workspace title`, `life` being `running` or `stopped` and `session`
the trail's session name. An empty field is written `-`, never
left empty, because tab counts as whitespace to `read` and two tabs in a row
collapse, shifting every later field. The title goes last because it is free
text, and new fields go in front of it. On a terminal it is a padded table, the
badge leading and the workspace after the agent; `ls_rows` carries the badge as an
extra leading field that the TSV drops, since a badge needs the label and name
the TSV doesn't carry.

Reading the history of ended trails is the slow part of an `ls`. `TRAILS_RECENT_MAX=0` skips it,
for a poll that only wants running trails.

## Surviving tmux

`launch` takes a lock (`launch_lock`, a directory, broken after five seconds)
from choosing a trail's session through marking its window, so two launches at
once can't take one name, and a restore that finds its trail back on its own
conversation stops (status 3) rather than starting a second agent. Records are
rewritten (`rec_rewrite`) only while they exist, each writer with its own temp
file, so a poll's `trails ls` can't bring back a trail that just ended.

Every agent lives inside the tmux server, so a reboot, a crash or
`tmux kill-server` takes them all down. The conversations survive, since each CLI
keeps its transcripts. What dies is the knowledge of which conversation belonged
to which trail.

So `trails` writes that down outside tmux, one file per trail, named by the trail's
ID under its codebase's folder ([ADR 20](decisions/0020-a-trail-has-an-id-of-its-own.md)):

```text
~/.local/state/trails/sessions/code-augur/t3f9a
agent=claude
dir=/Users/me/code/augur
id=15fcb95c-19cc-49dc-a7fc-7a7dd032e5c9
yolo=yolo
task=Fixing the flaky test
workspace=lattiq
label=augur
name=
server=default
trail=t3f9a
session=lattiq/augur-3f9a
```

**A trail's ID is its own.** `launch` makes it (`new_tid`, four hex digits from a
UUID) and puts it on the trail's window as `@trails_trail`; a restore keeps it, a
resume from the history makes a new one. It only has to be unique among the trails
there are, running or lost, so `new_tid` makes another while a record or a window
has it, and `launch` asks again under its lock, since two launches can draw the same
one before either writes its record. An unnamed trail's session is named by it
(`<workspace>/<codebase>-<ID>`), so a new trail never needs a free number found for it. The folder is `path_key` of the codebase root, the checklist's name
for it, and is for reading: `rec_path` finds a record by its ID alone
(`sessions/*/<id>`), and nothing depends on where it sits. The session, `session=`,
is the trail's address in tmux and may change under it: a restore that finds its
session taken (by a session of your own, or its workspace moved) lands on its name, or
`<codebase>-<ID>`, in the workspace it has now, with a `-N` only if that is taken too,
and only that line changes. Asking which
record runs as a session (`rec_of_session`, `session_taken`) greps `session=`.

**Records from before 1.8** were `sessions/<workspace>/<name>` with no `trail=`.
`rec_migrate`, first thing in any run that reads records, gives each an ID and files
it under its codebase, once (a `.migrating` folder keeps two runs from doing it at
the same time). A trail still running from before has no `@trails_trail`: the next
`sessions` pass gives its window its record's ID, and until then `rec_is_dead`
matches it as 1.7 did, by session and conversation. The wrapper of such a trail calls
`--forget SESSION`, and its record is found by `session=`.

**A record belongs to one tmux server**, the socket's name (`default`, or what `-L`
named). A record counts as lost, and is restored, only on its own server: on any
other, every trail of the first would look dead, and restoring them there would run
each conversation twice. A record from before 1.6 has no `server` and counts as
`default`.

**The ID is chosen up front.** `trails` generates it and starts the agent under it
(`claude --session-id`, `opencode --session`), then resumes by it (`--resume`,
`--session`). `--continue` would not do: it means "the latest conversation in
this directory", so two trails in one codebase would resume the same one.

**The task is kept current** by every `sessions` pass (the picker, `trails ls`,
anything polling it), so a lost row can say what the trail was doing.

**So is the conversation.** The ID trails chose is only where a trail started:
`/resume` or `/clear` inside claude moves it to another one. A hook that passes
`--id` sets `@trails_said_id` on the pane; when every `sessions` pass finds it
differs from `@trails_id`, the record and `@trails_id` follow it, and the
conversation left goes into the history. Otherwise a restore after tmux dies would
bring back the conversation you left. Without such a hook the record keeps the
conversation the trail started on.

**Deleting a record at the right moment is the hard part.** A trail you quit
is over, and a trail tmux took down is the whole point, but from outside both
look the same. tmux's hooks can't tell them apart: `session-closed` also fires
partway through `kill-server`, and `pane-exited` reports the wrong session name.
So the agent runs under a small `sh` wrapper:

```sh
self=$1 tid=$2 sess=$3 resume=$4; shift 4; trap : INT QUIT; t0=$(date +%s); "$@"; s=$?
  if [ -n "$resume" ] && [ "$s" -ne 0 ] && [ $(($(date +%s) - t0)) -lt 20 ]; then
    [ "$resume" != restore ] || tmux run-shell -b "'$self' --refused $tid $sess >/dev/null 2>&1"
  else
    "$self" --forget "$tid" "$sess"
  fi
  exit $s
```

When the agent exits by itself, the wrapper moves the record into the history
(`rec_close`). When tmux dies, it hangs up on the whole process group and the
wrapper dies to SIGHUP before it can touch anything. A reboot runs nothing at all.

One exit keeps the record: a resume that fails within its first 20 seconds. An
agent can take longer than the launch check to start and then refuse the resume
(claude starting several MCP servers, then "No conversation found"). Forgetting
the record then would lose the only pointer to the conversation, so the trail
comes back as lost, to retry or forget. A restore refused that way is different:
kept as lost, it would be refused again by every restore, so the wrapper asks the
server to run `--refused`, which waits for the dying session to go and starts the
agent fresh in its place, as the same trail. That is what `restore_one` does when
the refusal comes inside the launch check. It runs from the server because the
wrapper's own process group dies with the pane. A refusal inside the launch check
reaches both: `restore_one` and `--refused` each start the trail fresh. A restore
asks first, inside the launch lock, whether a window already carries the trail's
ID (`trail_back`), so the second finds it back and stops.

**A record is dead** when no window carries its trail ID (`@trails_trail`), not when
no session has its name. Otherwise a session you created by hand under the same name
would hide it. The trail's window killed is nothing to a record: the trail lives in its
session. A
dead record also keeps its ID and its session's name reserved, so a fresh trail gets
another and can't overwrite it.

`trails restore` brings back every dead record, detached, in its own directory,
into the workspace the config gives that directory now (the record's workspace
only when no entry claims it), rebuilding its session and its window and keeping the
name, and its ID: the record stays where it is, and only `session=` changes when the
session it had is taken. If claude refuses the ID (`No conversation found`, an agent you
never typed into), it starts fresh in its place. If the agent can't start at all,
the record is put back for next time. Companions are not restored.

**The server itself** can be left to a service manager: `trails boot`, which
`brew services start trails` runs ([ADR 21](decisions/0021-the-tmux-server-from-a-service-manager.md)).
A tmux server a terminal started belongs, on macOS, to that app's coalition however
it detaches, and a Force Quit of the app ends the coalition, the server included.
`boot_run` goes through the login shell once, for its environment (a service
starts with a bare `PATH`, and the server's environment is every pane's), refuses
while another server holds the socket, and starts `tmux -D` in the background with
`trails restore` a second later. The restore matters: a `-D` server reads `tmux.conf`
only when its first client connects, so a restore line there waits for a terminal,
and this restore is that client. `tmux -D` exits 0 after a `kill-server`, and
systemd restarts only a unit that failed, so `boot_run` waits for it rather than
exec'ing it, and exits 1 when it ends unasked; asked to stop (TERM), it kills the
server and exits 0.

## History

A trail's record moves to `history/<conversation id>`, under the state directory,
with `ended=<epoch>`, when its agent exits or you end it (`rec_close`), and when the
agent moves to another conversation (`rec_note_id`). A record with no conversation
ID has nothing to resume and is just forgotten, and so is a conversation that never
had a turn: its hooks spoke once and no more (`@trails_worked`), and an agent
refuses to resume a conversation that never got a message. A fresh trail that dies on
arrival is taken out again by `launch`. A resumed one counts as
worked; with no hooks to tell, it is kept. The newest 100 are kept.

"Resume old trails" and `trails ls`'s closed rows are the history (`recent_rows`):
an agent that is installed and can resume, ended inside `TRAILS_RECENT_DAYS`, the
newest `TRAILS_RECENT_MAX`, less any a record holds (running or lost already). A
closed row shows the task the record last held, and resumes in the mode the trail
last ran in, the way a lost row comes back in its recorded one. Resuming one takes
it out of the history once the agent has survived starting, so a resume that dies on
arrival is still there to try again. ctrl-x on one, in the old trails, forgets it and
reads the picker's cached list again.

One edge it can't see: whether a conversation in the history is open in an agent
trails didn't start. That took reading the agent's own files. Resuming it there runs
the conversation twice, as the agent's own resume would.

It is trails' own account of what it ran, not the agents': up to 1.6 trails read
Claude's transcripts and opencode's database for this, and listed conversations
started outside trails too. Those are the agent's own resume's to find now
([ADR 19](decisions/0019-no-agents-files-read.md)).

The codebase screen and `trails ls` show this directory's; a workspace's screen
shows those whose directory its workspace claims; `trails ls -a` shows every
directory's.

## The picker

The config is checked once, first (`config_check`): not JSON, empty or not an
object is named, and every command but `help`, `config`, `keys` and `ls` stops.
The newer fzf options the lists use are asked of fzf itself (`fzf_ok`, cached per
run): without `--info-command` the keys go in a header, without `--listen` the
preview is a snapshot, without `wrap-word` it wraps plainly.

One picker at four levels, workspaces, workspace, codebase and agent
([ADR 17](decisions/0017-one-picker-levels-not-screens.md)), each a screen chosen
by `TRAILS_PICKER` (which the reload subprocesses inherit) and, for a
workspace's, `TRAILS_WS`. A bare `trails` picks the level it opens on from where
it runs: an editor's terminal always gets its codebase's;
inside tmux a client whose session is a workspace gets that workspace's, which a
popup over it inherits; `~` and `/` get the workspaces; anything else is a
codebase.

| Screen | `TRAILS_PICKER` | Rows |
|---|---|---|
| this codebase | *(empty)* | `＋ new trail…` (the agents screen), running and lost trails here, editor and shell windows, `↩ resume old trails` |
| its ended trails | `old` | closed, from that last row; Esc goes back |
| a workspace | `workspace` | `＋ new trail…` (the codebase tree, then the agents screen), its running and lost trails and windows across its codebases with a codebase column, `↩ resume old trails` |
| its ended trails | `workspace-old` | |
| a codebase's agents | `agents` | a `new` row per agent, for the codebase `＋ new trail…` was picked on or for; Esc goes back to the workspace it was reached from (`TRAILS_BACK`), else the codebase |

`?` on every screen runs `trails --keys` (fzf's `execute`): `trails help keys`
(`keys_help`, also the middle of `trails help`) in a popup over the picker's pane, or
in `less` in place when the picker is itself in a popup, since tmux shows one popup at a
time and refuses a second silently. `q` comes back to the list as it was. In tmux,
`prefix ?` lists trails' keys among tmux's own, by their notes (below).

Esc goes up a level on every screen (D4 in `docs/design/picker-consolidation.md`):
the screens name it in `--expect`, so fzf reports it as a key, and the dispatch
execs the screen above — a codebase's to its workspace's, a workspace's to the
workspaces. The workspaces screen has no Esc key, so there it aborts. An abort
(ctrl-c) quits from anywhere, and an editor's terminal quits on Esc too.
| the workspaces | `ws` | one row each with what runs in it, the last attached marked and under the cursor |
| every trail | `all` | every running trail, in every workspace, its codebase column `workspace/codebase`; no new or old rows. `prefix A` opens it; ctrl-a on the screens above reaches it, and Esc goes back to that screen (`TRAILS_FROM`), else closes |

`print_menu` builds TSV rows of `verb`, `target`, `what's drawn`. fzf draws only
the third field. Trails are gathered first as raw rows (`state verb target dir
codebase agent yolo badge when title`) and drawn together in `STATES` order so the
columns line up; editor and shell windows follow with their kind where the state
goes. Tab and
ctrl-x pass the target to a subcommand of the script (`--toggle-yolo`, `--kill`)
and reload the menu. They're subcommands rather than inline shell because fzf
runs its bindings through `$SHELL`, where zsh expands a leading `=` and silently
ate the kill. The preview is `--peek`, the row's screen through `capture-pane`, trimmed of
the blank rows under its last line and shown under the list, scrolled to the
bottom (`follow`), as high as the list leaves room for. The screen is the
trail window's size, set by the terminal that last typed in it: a wider one
wraps (`wrap-word`), its full-width rules redrawn at `$FZF_PREVIEW_COLUMNS`, and
a narrower one stays as drawn. It is kept current by
`preview_ticker`: fzf listens on a socket in the picker's temp directory
(`--listen`), and a background loop POSTs `refresh-preview` to it once a second
with `curl`, ending when the picker kills it or its directory goes. Without
`curl`, no `--listen` and no loop: a snapshot. ctrl-e comes back through
`--expect` so the editor it opens gets fzf's
terminal.

The running block is classified once per picker run and cached in a temp file,
because every Tab and ctrl-x reloads the menu. Recent rows are cached the same
way; on the workspace picker the cache holds every trail classified, for the
counts.

Each picker run has a temp folder of its own, `$TMPDIR/trails.XXXXXX`, removed when it
exits, ctrl-c included. A picker killed outright (SIGKILL, a crash) runs no trap, so
each picker also clears the user's `trails.*` folders and fzf probe sockets more than a
day old.

| Verb | Target | Enter does |
|---|---|---|
| `new` / `yolo` | agent, or `agent:dir` on a workspace's screen | launch a fresh agent, with the YOLO flag for `yolo` |
| `attach` | window id | `attach_to`: the workspace on the trail's window, or its session |
| `restore` | trail ID | `restore_one` in the record's directory, then attach |
| `resume` / `resume-yolo` | `agent:id:dir` | launch with the resume flag and that ID in that directory, recorded like any launch; `resume-yolo` when it last ran YOLO (unless Tab flipped it back) or Tab armed it |
| `tool` | window id | an editor or shell window: switch or attach to it |
| `browse` | | `pick_codebase`: the workspace's codebase tree (`codebase_tree`), walking the file system from a `browse:DIR` row (`walk_dir`), then the agents screen |
| `agents` | | a codebase's "＋ new trail…": the agents screen for this directory |
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
editor pane is a column on the right, half the window, full height; an editor pane
takes the right 60% and the agent the left 40%; a shell with an editor pane sits
under the editor only, a quarter high. It uses `move-pane` (tmux 3.2), which puts
a pane where it belongs whether it was there already or not, then `resize-pane`
for the sizes, since a size given to `move-pane` is taken from the pane it splits.
It runs after every pane is made, and the editor pane's command ends by running
`trails --layout` in the background, so a shell that sat under the editor goes
back to its own column once the pane has gone. The window you are on decides: from
a trail's window or an editor or shell window, that window; from a plain window in
the workspace, the window of the trail in the pane's directory that most wants
you; outside tmux, the current directory's or `DIR`'s. Directories are compared
resolved, because tmux reports a pane's path through symlinks.

With no trail in the codebase, `edit` makes the editor alone as a window in the
workspace, `<codebase>·nvim`, marked `@trails_tool editor`, and `shell` goes under
it, a quarter high. Such a window is renamed and re-marked for what it holds whenever its
panes change (`tool_remark`): `<codebase>·shell` once the editor has left, the
editor's name again when one is opened in it. When a trail ends with panes beside it, `window_release` turns the
trail's window into such a window rather than killing what you had open: renamed
for the editor (or `<codebase>·shell`), marked `@trails_tool`, the trail's mark
dropped. Run by the agent's wrapper on exit and by ctrl-x before it kills the
session. An editor's terminal is shown no editor or shell rows in
the picker.

## The diff beside the agent

A trail's window can hold a fourth pane kind, `diff` (`@trails_pane diff`): Hunk on
the codebase, run as `hunk diff --watch` with git's `diff.context` set to 99999 for
that one run through `GIT_CONFIG_COUNT`/`KEY_0`/`VALUE_0`, so every changed file is
shown whole ([ADR 25](decisions/0025-the-diff-beside-the-agent.md)). Hunk has no
setting of its own for that; the rest of how it looks is the user's
`~/.config/hunk`.

`window_layout` decides it, since every change to a window's panes ends there: on a
trail's window, with an agent and no editor, `diff_wanted` asks for hunk on the PATH,
a git work tree at `@trails_dir`, and the window's `@trails_diff` set `on` by
`prefix G`; never the width, since a pane that isn't needed costs memory (Hunk idles
at ~120MB) and the agent's room, and the editor and shell are asked for too. Wanted
and missing, `diff_pane` makes it; not wanted and there, it is killed. The right side then holds the editor or else the diff, 60% wide,
and a shell goes under whichever. Two layouts at once can each make a diff pane, so
`diff_pane` counts after splitting and the later one goes.

The layout runs when a pane is made or ends, and on every attach (`attach_to`), which
is where a window from before a change to the border format reads the current one,
and a diff asked for and missing (its pane killed by hand) is made again.

`prefix G` on a trail's window is `diff_toggle`: the diff there is put away
(`@trails_diff off`), else asked for (`on`); when it still can't be shown (no hunk,
no repository, the editor on the right) the ask is forgotten and `diff_cmd` opens
the popup below instead. Hunk ending by itself, quit with `q` or failed, sets `off`
too, by the pane's own command, and asks for a layout from outside the pane, as the
editor's does: a Hunk that can't start is then not started again by that layout,
round and round. A pane killed by a layout takes its shell with it, and sets
nothing. `window_release` kills the diff before it looks at what else the window
holds, so an agent leaving takes it, and the window, with it.

The pane runs with `allow-passthrough off`, set on itself by its own id before Hunk
starts. Hunk opens by asking the terminal what it can do (device attributes, a kitty
graphics probe) in tmux's passthrough wrapping; with passthrough on, as a tmux.conf
sets it for images, tmux forwards the questions to the terminal and the answers come
back to tmux, which knows nothing of them and types them into the client's active
pane. That is the agent's, the diff being made behind it, and Claude read one answer
(`ESC P…`) as alt-p, its model picker. Off on that pane, the questions stop at tmux.
By the pane's own id because a bare `set -p` from a command in an inactive pane lands
on the active one.

## The diff

`trails diff` (`diff_cmd`) finds the codebase as `trails edit` does (`diff_dir`):
`DIR`, else the window you are on (`@trails_dir`), else the pane's directory, else
`$PWD`. From `prefix G`, a run-shell job with no terminal, on a window that is no
trail's (or when the diff beside the agent can't be shown), it opens a popup on the
terminal that pressed the key, 90% of it, running `trails diff --show DIR`; from a
shell it runs there. `diff_show` builds the diff in the codebase: `git diff HEAD`
(the empty tree's hash before a first commit), then each untracked file not
ignored against `/dev/null` with `git diff --no-index`, since agents make files
`git diff` leaves out, and nothing is staged to show them. It is piped to the
config's `diff` command (`diff_cfg`), uncoloured, or with colour into `less -R`
when there is none and delta isn't installed. A `{ "command", "pipe": false }` diff
finds the changes itself (Neovim with codediff), so `diff_show` only checks there
are some (`git status --porcelain`) and execs it in the popup; a `"gui": true` one is
run in the codebase instead, with no popup.

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
Every key trails binds is a capital letter, but the backtick for the shell, which is
the editors' own toggle-terminal key: trails' keys read apart from tmux's and from a
tmux.conf's own, which are mostly lower case
([ADR 24](decisions/0024-trails-keys-are-capitals.md)). `prefix P`, `W`, `A`, `N`,
`G`, `R`, `J` and `K` are free in tmux 3.8's default table (`C`, `D`, `L` and `T`
are taken); `P` is "pick a trail", `N` the checklist, `A` all trails, `G` the git
diff, `R` rename, and `K` and `J` the previous and next workspace, vim's up and down, beside tmux's
`(` and `)` for every session. `E` for the editor takes spreading the panes out
evenly (still `:select-layout -E`), and `M` for the map takes clearing the marked
pane (which `prefix m` on it still does). Each is bound with a note (`bind -N
"trails: …"`): tmux's `prefix ?` is `list-keys -N`, which lists only the keys that
have one, so without it trails' keys were missing from tmux's own list. With it,
trails needs no help key of its own (1.11 had `H`); the picker's `?` has the rest.

`run-shell "trails keys | tmux source-file -"` in tmux.conf loads them all each time
tmux reads it, so they follow an upgrade; the lines it prints that say so are tmux
comments, which the sourcing skips.

One line is printed commented out, so the loader skips it and it stays opt-in:
`run-shell -b "trails restore >/dev/null 2>&1"`, which brings back the trails tmux
lost whenever it starts (continuum's idea, without its snapshots: the records are
already current). Restore is a no-op with nothing lost, safe on every reload, and
races a launch only through `launch_lock` and restore's back-already check, as any
two launches do. Its output goes nowhere, since a run-shell's output is shown over
the pane.

`trails keys` also sets `status-left` to the running workspaces: tmux's own
`#{S/n:…}` loop over the sessions marked `@trails_workspace`, each in a
`range=session|ID` that tmux's stock `MouseDown1Status` binding switches to on a
click, the one the terminal is on in reverse video (its `client_session`, or a
`<workspace>~N` grouped with it). Nothing of trails runs for it. `prefix K` and
`J` run `trails ws prev` / `next` (`ws_step`): the same list, by name, round the
end, through `switch_to`, so a grouped terminal stays grouped.

Its `status-right` starts with the current trail's task, before the checklist's
count ([ADR 23](decisions/0023-the-task-in-the-status-line-and-rename.md)):
`Fixing the flaky test · ☑ 2/5 · 14:05`, cut at 40 characters, with
`status-right-length` raised to 80 to hold it. Nothing of trails runs for it
either: `STATUS_TASK_FMT` finds the current window's agent pane with `#{P:}`,
whichever pane is active, and reads its title, which is the trail's session's
`<agent> · <task>`, so the task is the agent's terminal title as it changes. The
agent's half goes up to the first ` · `; a title that only repeats the codebase,
tmux's hostname seed or an empty one shows nothing, and so does a named trail, a
`·` in its window's name, whose name says what it is for. At the right, not after
the window's name: the window list stays the width it was.

`prefix R` is tmux's `command-prompt` into `trails rename '%%'` (`rename_trail`),
as ctrl-r is in the picker. A rename changes the name, not the address: the agent
window's `@trails_name`, both windows' names, and the record's `name=`, under the
launch lock and through `check_name` in the trail's codebase. The session stays, since
the wrapper was handed its name at launch and gives the trail's window back by it
when the agent exits; a session renamed under it would leave the editor and shell
to die with the trail. A restore puts a renamed trail on `<workspace>/<name>`, as
any named trail. `R` is free in tmux's default table (`r` is commonly the reload).

## Checklist

A codebase's checklist is a Markdown file of its own, `- [ ]` and `- [x]` items
(`note_cmd`, `checklist_cmd`). Where (`checklist_file`): with the config's `data`
(`load_data_dir`), `<data>/trails/<path>/checklist.md`, `<path>` from `path_key`, the
codebase's root (`codebase_root`; a worktree's main checkout, by `path_key`) from `$HOME` with every
non-alphanumeric as `-`, as Claude names a project's folder, so the same code has the
same name on every machine and a synced folder shares it; without it,
`.trails/checklist.md` in the codebase; with only the pre-1.7 `notes`
(`load_notes_path`), its path, `{codebase}` as `codebase_label`. A checklist left in
the codebase, under any of its old names (`.scratch/trails/notes.md`,
`.scratch/trails/checklist.md`), moves to where it lives now the first time it is
opened or added to; the status line's count reads it where it is, and moves nothing. Which codebase (`note_where`): from a popup, which has no
`TMUX_PANE`, the window of the terminal that opened it, by `CLIENT`; from a shell,
`$PWD`.

`note_add` writes an item as `- [ ] TEXT`, any further lines indented under it,
making the file under a `# LABEL: checklist` heading the first time. trails writes
nothing else in the repo, `.gitignore` included.

An item is a line starting `- [ ] ` or `- [x] ` (or `*`, or `X`) at the left
margin, with the lines indented under it; everything else in the file is left as
it is. The list (`checklist_ui`) is one fzf: `--disabled`, so its input line is for
a new item and never filters, over `checklist_rows`, each row the item's line
number and its text, open ones first. The keys depend only on the input line:

- Enter is a `transform` (`checklist --enter`, `checklist_enter`): with something
  typed it adds the item and answers `clear-query+reload-sync(…)+pos(N)`, so the
  list stays open on the new item, the last open one; with nothing typed,
  `accept-or-print-query`, and trails copies the row under the cursor
  (`checklist_copy`: `tmux load-buffer -w`, so the terminal's clipboard too) and
  closes. An fzf without `transform` accepts either way, and trails adds what was
  typed, closing.
- Space is a `transform` (fzf 0.45): with nothing typed, tick the row's line
  (`checklist_toggle`, which touches only an item's own line) and reload; else
  `put( )`, a space. An older fzf ticks on Tab.
- ctrl-e opens the file, in a popup of its own from `prefix N`'s, and when the
  editor quits opens the list again (`checklist_open`'s `back`): in a popup as
  `prefix N`'s, scheduled from the editor's (`checklist_popup`), or in the same
  terminal from a shell.

A row is the item's first line, cut to the popup's width. fzf's preview, under
the list, is the row's item whole (`checklist --text FILE LINE`, `checklist_text`,
what a copy takes), wrapped at words where fzf can (`wrap-word`). The list is ten
rows and the preview takes the rest, set on start and on every resize by a
`transform` to `change-preview-window` from `FZF_LINES`; an fzf without the
`resize` event splits the popup in half.

The bindings' commands run with `SHELL=/bin/sh`: fzf runs them through `$SHELL`,
and a login shell's zsh reads a path's `=` and `~` its own way.

The status line's count is `checklist_count` on tmux's `status-interval`: a
`#()` job in the `status-right` that `trails keys` sets, given the window's
`@trails_dir` (else the pane's directory), printing `☑ open/total · ` or nothing: each item at the right brings its own separator,
so one that shows nothing leaves none behind.
Adding or ticking an item refreshes it at once (`refresh-client -S`).

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

## The map a key away

`prefix M` runs `trails map here` (`map_here`) through `run-shell`. With the map up
(`is_map`) and the terminal elsewhere, it switches there; otherwise it opens
`trails map new` in a popup on that terminal, since a run-shell job has none of its
own. The pick is `--multi=4`, the first four rows, the ones that most want you,
ticked on load. `trails keys`' `status-left` lists the map after the workspaces with
a second `#{S:}` loop over the session marked `@trails_map`, so a name never sorts
it in among them.

## The README demos

`assets/trails.gif` and `assets/map.gif` are recorded with
[VHS](https://github.com/charmbracelet/vhs) from `assets/demo/trails.tape` and
`map.tape`, with the real Claude Code. The first is the tour, kept to the everyday loop: the
workspaces, a workspace's trails with the live preview, the diff beside an agent,
then the editor in its place and a shell under it, and the status line's
workspaces. The
second is the map: prefix M's pick, across two workspaces, and four agents at work
in one window. Both give their agents small tasks, so a recording costs a little of
your plan; the tour's runs one, the map's five.

Each tape first sources `assets/demo/sandbox.sh`, which gives trails its own config
(a workspace `acme` over `~/code/*`, and `personal` over `~/src/*`), records and tmux
server, and small Go projects at `~/code/checkout` and those in `DEMO_EXTRA`, with
the repos in `DEMO_PERSONAL` under `~/src` (each refused if it exists, all removed
afterwards). The demo's tmux runs through a wrapper that loads the demo's own
config, a plain status line with `trails keys` after it, so the recording machine's
tmux.conf is not in the shot and the keys are the ones being released. Each of
those bindings is wrapped to name itself for a few seconds in a yellow badge at the
right of the status line (`prefix E · editor`), since a GIF cannot show a key
press. The tape's
shell has `TMUX` and `TMUX_PANE` unset, since VHS run from inside tmux would hand
them down. Two ended trails are seeded into trails' own (sandboxed) history for
"resume old trails", and the real `claude` runs through a wrapper that hands it the
repo's plugin hooks (`--settings`), so its trails say what they are doing; its
demo conversations are removed afterwards. The repo's own `bin/trails` comes first on `PATH`, so a
re-record shows the version being released. After a change to what the picker, a
key or the status line shows, re-record from the repo root, with `claude` logged in:

```console
vhs assets/demo/trails.tape
vhs assets/demo/map.tape
```

## Tests

`test/run.sh` runs the integration tests in `test/t-*.sh`, one per area: launch,
ls, classify, picker, screens (the workspace screens), tools (the editor and the
shell), inside (inside
tmux: switch-client, a nested editor client, the refused collision), restore,
autorestore, map, workspace and wsmap (the config), wsbar (the status line),
grouped (a second terminal on a workspace), all (every trail), edges, hooks
(`trails state` and `--id`, the history, the plugin against the docs), checklist,
diff, diffpane (the diff beside the agent), rename (the status line's task and
renaming), and the popup check behind D4 of the design. CI runs them after ShellCheck. Each test is
its own process on its own tmux server in a throwaway `HOME`: `TMUX_TMPDIR` puts
the socket there, `XDG_CONFIG_HOME` and `XDG_STATE_HOME` give it a config and
records of its own, and `TMUX`, `TERM_PROGRAM`, `NVIM` and `ZED_TERM` are unset so
trails sees a plain terminal outside tmux even when the tests run from an editor
inside one. Nothing in `bin/trails` knows it is under test. The stub agent calls
`trails state` as a hooked agent would; `t-hooks.sh` runs it with `--no-hooks` to
see what an agent with none shows.

Three stand-ins on `PATH` from `test/bin` do what a person, a CLI and an editor
would:

- **`agent`** plays the agent. It takes the flags trails passes and then reads commands
  from its pane, so a test drives it with `tmux send-keys`: `ask` puts a question on
  screen, `busy` changes the screen for two seconds, `title` sets the task, `hook WORD`
  runs `trails state WORD` as an agent's hook would, `exit` quits.
- **`fzf`** plays the picker's keyboard. It prints the first row matching `$FZF_PICK`,
  copies the rows it was given to `$FZF_DUMP` (numbered, one block per fzf a run
  opens), and with ctrl-n among `$FZF_KEYS` runs the bound command so `$FZF_QUERY`
  becomes the name typed. `$FZF_PICKS` and `$FZF_KEYS` may name files whose lines
  are taken one per fzf, so a test can drive a screen that leads to another;
  `$FZF_KEY` is what `--expect` reports. No match is an abort, ctrl-c, and
  `FZF_PICK=!esc` is Esc, reported as the key where `--expect` names it.
- **`ed`** plays the editor: it says where it opened and waits for `exit`.

A test that needs trails attached, or fzf on a terminal, runs it in a *driver*: a session
on the test server whose pane is the terminal, with `TMUX` unset so trails attaches as a
nested client, the way the map does. Not `script(1)`: it passes an EOF on its own stdin
through the pty as ^D, which the agent reads as the end of its input. Where a client
is, `client_at` reads from `list-clients`, whose formats expand in the client's own
context; `display-message -c` only picks where a message is shown.
