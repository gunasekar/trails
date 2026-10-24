<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.png">
    <img alt="trails" src="assets/logo-light.png" width="240">
  </picture>
</h1>

**Your coding agents, in tmux, by workspace. Reachable from any editor, any
terminal, and over one ssh connection.**

trails is a command-line tool: a session manager for coding agents, built on
tmux. It runs Claude Code, Codex, Gemini, Copilot, Cursor, opencode or any other
agent CLI in a tmux session of its own, a *trail*, and groups trails by
workspace, a set of codebases you choose. From anywhere, `trails` shows what is
running and what is waiting on you, opens the one you pick, brings old ones back
after tmux or the machine dies, and puts the editor beside the agent with one key.

![From one terminal: the workspaces, a workspace's trails with a live preview, the editor and a shell beside the agent, and the workspaces in the status line](assets/trails.gif)

![prefix M: trails from two workspaces picked into the map, four agents at work side by side, and the map in the status line beside the workspaces](assets/map.gif)

After the first `trails`, everything above is a key, named at the bottom right as
it is pressed: `prefix P` a workspace's trails, `e` the editor, `` ` `` a shell,
`(` and `)` the workspaces, `M` the map, `A` every trail, `G` the diff and `N` a
note, all from the one tmux.conf line in [Workspaces](#workspaces). `prefix ?` lists
them.

## What it's for

- **One machine holds the agents.** A laptop, a desktop or a server runs tmux and
  the agents; everything else, including a second laptop, is a thin client over
  ssh. Close the lid, drop Wi-Fi, come back: the conversation is where you left
  it, mid-turn.
- **Work grouped the way you think of it.** A workspace is a company, a client,
  or "personal": unrelated repos together. One ssh connection carries every
  workspace, and `trails ws` moves between them without reconnecting.
- **The agent first, the editor beside it.** Start the agent, and bring up
  nvim and a shell next to it when you want them, in the same tmux session.
- **Every editor sees the same trails.** Zed over ssh, VS Code Remote, a Neovim
  panel and a plain terminal all land on the same running agents. An editor's
  panel sees exactly one trail; your terminal sees the workspace.
- **Nothing but tmux.** No TUI or daemon of its own, no key bindings, no tmux
  options beyond its own `@trails_*` marks. `tmux ls` reads as your layout, plain
  tmux keys drive it, and uninstalling trails leaves ordinary tmux behind.

## Who it's for

trails is for people who stay hands-on with their code. It keeps agents
running and you beside them: the editor next to the agent, its diff a key away, a
note for later. You read, review and write the code yourself, with agents doing a
share of it, and you would rather have a small tool than a platform.

It is not for running a swarm of agents and shipping what comes back unread, and
it has no chat window of its own: the agent's interface is the agent's.

## Works with

| | |
|---|---|
| Agents | Claude Code, Codex, Gemini, Copilot, Cursor, opencode built in; any CLI by one config entry. Each tells trails what it is doing through its own hooks ([setup](#hooks-for-each-agent)); trails reads none of an agent's files |
| Editors | Zed (local and over ssh), VS Code and Cursor (local and Remote-SSH), Neovim, anything with a terminal pane |
| Terminals | any, including over ssh; a popup inside tmux with `trails keys` |
| Systems | macOS and Linux; tmux 3.3 or later, fzf, jq |

Because it's just a command, it plugs into whatever you already use:

- **any editor with a terminal**: VS Code, Zed's agent threads, a Neovim side
  panel, or anything else that can run a command in a pane
- **any terminal** (Ghostty, iTerm, Terminal), in the project you're working on
  or over ssh to the machine where the agents live

Every one of them lands on the same trails.

```console
~/code/checkout $ trails
checkout (acme) ▸ Pick a trail: █   # enter: open · ctrl-e: editor · ctrl-/: preview · ctrl-x: end, forget · esc: up
  ＋ new trail…
▌ ● needs you  claude · yolo  Add idempotency keys to payment retries
  ● your turn  claude    #2   Fix the flaky cart-total test
  ● working    codex          Migrate orders to Postgres 17
  ○ lost       claude         Spike: replay Stripe webhooks
  ↩ resume old trails  (3 ended)
```

Enter on **＋ new trail…** lists the agents to start here, with Tab for YOLO and
ctrl-n to name the trail:

```console
checkout (acme) ▸ Start an agent: █   # enter: start · tab: toggle YOLO · ctrl-n: name it · ctrl-e: editor · esc: back
▌ claude · new trail
  codex · new trail
  cursor · new trail
```

Enter on **↩ resume old trails** opens the trails that ended here, and Esc
comes back:

```console
Resume a trail: █   # enter: resume · tab: toggle YOLO · ctrl-e: editor · ctrl-/: preview · esc: back
▌ ○ closed     claude · yolo  2d ago  Release notes for v2.3
  ○ closed     claude         4d ago  Tighten the refund window
  ○ closed     codex          6d ago  Bump the payment SDK
```

From `~`, or a fresh ssh login, `trails` lists your workspaces instead, with what
runs in each; from a shell in a workspace's tmux session it lists that workspace's
trails across its codebases. `trails ls -a` shows every directory:

```console
~ $ trails ls -a
    ● needs you  claude · yolo  acme      ~/code/checkout              Add idempotency keys to payment retries
#2  ● your turn  claude         acme      ~/code/checkout              Fix the flaky cart-total test
#3  ● working    codex          acme      ~/code/checkout              Migrate orders to Postgres 17
    ● working    claude         personal  ~/code/storefront            Lazy-load product images
    ○ lost       claude         acme      ~/code/checkout              Spike: replay Stripe webhooks
    ○ closed     claude · yolo  acme      ~/code/checkout      2d ago  Release notes for v2.3
```

Because each agent runs inside tmux, it outlives the terminal that started it.
Close the laptop, drop Wi-Fi or quit the terminal, and the conversation is still
running when you come back. ssh in from another machine and run `trails`, and
you're in the very same coding sessions: the same conversations, mid-turn, right
where you left them. One ssh connection reaches every workspace, and you move
between them without reconnecting.

And if tmux itself goes down, after a reboot, a crash or a `kill-server`, the
trails show up as *lost*, not gone. `trails restore` brings each one back on the
conversation it was in, into its workspace. To have tmux do that itself whenever
it starts, add the line `trails keys` offers for it to your tmux.conf:

```tmux
run-shell -b "trails restore >/dev/null 2>&1"
```

It is opt-in, and not loaded with the rest of `trails keys`: every lost trail comes
back on its own, so ctrl-x a lost row you don't want back. With nothing lost, it
does nothing, so reloading tmux.conf is harmless.

## Install

With Homebrew, on macOS or Linux:

```console
brew install gunasekar/tap/trails
```

By hand: it's one POSIX `sh` script. Put [`bin/trails`](bin/trails) anywhere on
your `PATH`.

It needs `tmux` (3.3 or later), `fzf` and `jq`, plus at least one agent CLI on
`PATH`. macOS ships `jq`; Homebrew installs all three. Keeping the picker's
preview current uses `curl`, without which it is a snapshot.

Then give each agent you use the hooks that tell trails what it is doing
([Hooks for each agent](#hooks-for-each-agent)). For Claude Code it is a plugin:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

Recommended: [delta](https://github.com/dandavison/delta) (`brew install git-delta`),
which `trails diff` uses to show changes side by side. Without it the diff is git's
own one-column output in `less`. See [The diff](#the-diff).

## Quickstart

```console
trails ws add acme ~/code/checkout   # file a codebase under a workspace (optional)
cd ~/code/checkout
trails              # pick an agent to start, or a trail to rejoin or resume
trails edit         # the editor beside it, in the same tmux session
trails ls -a        # where every trail is, in every directory
trails map 4        # the four that most want you, side by side in one window
trails keys         # tmux.conf lines that put all of this on a key
```

With no workspaces configured, everything runs in one workspace called
`default`, and trails behaves much as it did before 1.0.

The everyday loop, and every other way trails is used, are in
[docs/scenarios.md](docs/scenarios.md).

## Usage

| Command | Does |
|---|---|
| `trails` | the picker for where you are: this codebase's trails and the agents you can start; a workspace's trails, from a shell in its tmux session; or the workspaces, from `~` |
| `trails ws [NAME]` | pick a workspace, or go to `NAME`: switch to its session inside tmux, attach outside, landing on the trail that most wants you; its picker when nothing runs there |
| `trails ws list` / `ws of [DIR]` / `ws add NAME [DIR]` / `ws next`, `prev` | the workspaces in the config; the one `DIR` (here) belongs to; put `DIR` (here) in workspace `NAME`, creating it if new; the terminal to the next or previous running workspace |
| `trails new NAME [AGENT]` | start a trail named `NAME`, with `-y` for YOLO: its session is `<workspace>/NAME`, and claude takes `NAME` as its own name, so other Claude sessions can message it by that name |
| `trails edit` / `shell` | the editor beside the agent, or a shell along the bottom, as panes of the trail's window in the workspace (the editor alone in a window of its own when nothing runs there): made once, then selected. The window you are on says which codebase, or `DIR` after the command |
| `trails ls [-a \| DIR]` | this directory's trails: running, lost when tmux died, or finished in the last 10 days. `DIR` lists that directory instead, `-a` every directory |
| `trails note [TEXT]` / `notes` | add a note on this codebase, typed on a line without `TEXT`; open its notes in `$EDITOR`. See [Notes](#notes) |
| `trails restore` | bring back every trail lost when tmux died, each on its own conversation, into its workspace, detached |
| `trails map [N]` | several running agents side by side in one window: re-attach to the map already up, pick a set, or take the `N` that most want you (`map new` forces a fresh pick) |
| `trails keys` | print tmux.conf lines that put the picker, the workspaces, every trail, a note and the diff in popups, bind the editor, a shell, the workspaces and the map, and list the workspaces in the status line; trails binds nothing itself |
| `trails diff [DIR]` | the codebase's changes, untracked files too, side by side: in a popup from `prefix G`. See [The diff](#the-diff) |
| `trails state WORD [--id ID]` | for an agent's hooks: `working`, `waiting` or `idle`, and the conversation it is in. See [Status](#status-from-the-agents-hooks) |
| `trails config` | open the config in `$EDITOR`, writing the built-ins first if there isn't one |
| `trails help [keys]` | the commands, the picker's keys and the tmux ones (also `-h`, `--help`); `keys` for the keys alone, which `?` in the picker shows |

### Workspaces

A workspace is a set of codebases you choose, related or not: one per company,
say, or everything personal. It is declared in `~/.config/trails/config.json`,
as paths or globs, with an optional `root`:

```json
"workspaces": {
  "acme":     { "root": "~/code", "codebases": ["~/code/*"] },
  "personal": ["~/src/*", "~/.dotfiles"]
}
```

- An entry ending in `/*` is a *workspace directory*: every folder in it is a
  codebase, so a newly cloned repo needs no edit. Any other entry is a codebase
  of its own, and a path that is also a workspace directory makes that
  directory a codebase too.
- A folder inside a listed one belongs to it, at any depth, and a git worktree
  belongs where its main checkout does, wherever it lives.
- The most specific entry wins an overlap: an exact path beats a glob.
- `root` is where `browse…`, under "＋ new trail…" in the picker, starts walking;
  `~` without one.
- A name is letters, digits, `-` and `_`: it becomes a tmux session name. It
  can't be `list`, `of` or `add`.
- `trails ws add NAME` adds a codebase for you, and the picker offers to when
  you start a trail in a directory no workspace claims. Edits never move a running
  trail.

### What tmux shows

Each trail is a small tmux session of its own, holding the agent and nothing
else: what an editor attaches to, with nothing it can wander off to. A workspace
is a tmux session named after it, with a window per trail whose first pane is a
nested tmux client showing the trail's session, the way a pane of the map does.
The editor and a shell you open beside the agent are panes of that window, so the
trail's session, and any editor on it, never sees them.

```text
acme                    ← workspace
├─ checkout             ← shows acme/checkout; nvim and a shell beside it (trails edit, shell)
├─ checkout-2           ← shows acme/checkout-2
├─ ledger               ← shows acme/ledger
└─ billing·nvim         ← the editor alone, nothing running in billing
acme/checkout           ← a trail: claude in ~/code/checkout
acme/checkout-2         ← another, same codebase
acme/ledger             ← codex in ~/code/ledger
```

The pane showing a trail runs a tmux client, so a `pane-border-format` that
labels panes by their command reads `tmux` on it; the pane carries `@ag` (the
agent) and `@dir` (the codebase) for that, as the map's panes do:
`#{?@ag,#{@ag},#{pane_current_command}}`.

Plain tmux moves you around: the next and previous window keys, `prefix s` or
`choose-tree`, `switch-client`. `tmux a -t acme` is the workspace and
`tmux a -t acme/checkout` is one trail. trails sets nothing on any of it beyond
`@trails_*` options, never touches your tmux.conf, and binds no keys: `trails keys`
prints the lines that would, for you to take or leave. One line in tmux.conf loads
them all from the installed trails each time tmux reads it, so they follow every
upgrade with nothing to paste:

```tmux
run-shell "trails keys | tmux source-file -"
```

A line after it that sets the same key or option wins, which is how to change
one. Or paste only the lines you want, below, and paste again when they change.
The popups take the terminal's own background: tmux 3.8 shades them grey by
default, which a list in dim text does not survive. `bg=terminal` is tmux 3.8's
word for it; before 3.8 the word is `bg=default`, and `trails keys` prints the one
your tmux takes.

```text
# trails: one line in tmux.conf loads all of these, and follows every upgrade:
#   run-shell "'trails' keys | tmux source-file -"
# or paste what you want of them instead.
# Opt-in, not loaded with the rest: put this in tmux.conf to bring back, whenever tmux starts,
# the trails it lost (a reboot, a crash). To drop one for good, ctrl-x on its lost row.
# run-shell -b "'trails' restore >/dev/null 2>&1"
bind P display-popup -E -w 60% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }"
bind W display-popup -E -w 60% -h 50% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' ws || { echo; echo press enter to close; read -r _; }"
bind e run-shell "TRAILS_CLIENT=#{client_name} 'trails' edit"
bind ` run-shell "TRAILS_CLIENT=#{client_name} 'trails' shell"
bind N display-popup -E -w 70% -h 3 -s bg=terminal -S bg=terminal,fg=brightblack "'trails' note"
bind ( run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws prev"
bind ) run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws next"
bind M run-shell "TRAILS_CLIENT=#{client_name} 'trails' map here"
bind ? display-popup -E -w 70% -h 80% -s bg=terminal -S bg=terminal,fg=brightblack -T " trails keys " "'trails' help keys | less -R"
bind A display-popup -E -w 70% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "env TRAILS_PICKER=all 'trails' || { echo; echo press enter to close; read -r _; }"
bind G run-shell "TRAILS_CLIENT=#{client_name} 'trails' diff"
set -g status-left-length 60
set -g status-left "#{S/n:#{?@trails_workspace,…}}│ "
```

The last two lines put the running workspaces at the left of the status line, the
one you are on in reverse video, apart from the window you are on, which tmux
underlines:

```text
 lattiq  personal │ 1:gunasekar  2:gunasekar-2  3:trails*
```

Click one to go there, or `prefix (` and `)` for the one before and after, in
place of tmux's own cycling through every session, each trail's among them.
`trails keys` prints the full `status-left`; it replaces one you have.

`trails keys` prints trails' full path where these show `trails`, and the full
format where `status-left` shows `…`. The `run-shell` lines pass the terminal
that pressed the key, so with two terminals on one workspace the right one moves.
A popup closes as soon as trails exits, so when trails refuses something there,
the picker's and the workspaces' popups wait for Enter to let you read why, and
the note's shows it on tmux's message line. `P`, `W`, `A`, `e`, `` ` ``, `N` and `G` are
unbound in tmux's defaults. `(` and `)` take tmux's cycling through every session
for the workspaces alone, `?` takes tmux's list of every binding (still
`:list-keys`) for trails' keys alone, and `M` takes clearing the marked pane, which `prefix m`
on it still does, for the map (`prefix M` in [trails map](#trails-map)). Change
any of them.

A session exists while something runs in it: the first trail creates the
workspace session, and the last one out takes it down. A session named like a
workspace that trails didn't make is refused, never added to.

**A workspace in two terminals.** Every terminal on a tmux session shares its
current window, so a second terminal on `acme` moves when the first does. For a
second terminal that moves on its own, give it a session grouped with the
workspace's: the same trails, and a current window of its own.

```sh
tmux new-session -t acme -s 'acme~2' ; set destroy-unattached on
```

`-t acme` groups it with `acme`, `-s` names it, and `destroy-unattached` takes it
away when that terminal closes. trails treats it as `acme`: the picker shows
acme's trails, and picking one, or opening the editor or a shell, moves that
terminal alone and keeps it on `acme~2`. trails never makes such a session
itself, and the workspaces list counts `acme` once.

### The picker

One picker at four levels: the workspaces, a workspace, a codebase, and the
agents to start. Where it runs decides the level it opens on. Enter goes down a
level, Esc goes up one, and ctrl-c quits
([ADR 17](docs/decisions/0017-one-picker-levels-not-screens.md)).

**This codebase** (a shell in a repo, or an editor's terminal): **＋ new trail…**
first, which lists the agents to start here, then its running and lost trails,
its editor and shell windows (not in an editor's terminal, which wants trails
only), then **↩ resume old trails**, which opens a second list of the trails that
ended here (Esc goes back). The cursor starts on the trail that most wants you.
Picking a running trail from a terminal of your own lands in the workspace on
that trail's window; from an editor's terminal it attaches to the trail's session,
so the editor sees that one trail.

**This workspace** (a shell in a workspace's tmux session, or a popup over one):
its trails across its codebases, with a codebase column, and one way to start a new one:

```console
acme ▸ Pick a trail: █   # enter: open · ctrl-e: editor · ctrl-/: preview · ctrl-x: end · esc: up
▌ ● needs you  checkout  claude · yolo  Add idempotency keys to payment retries
  ● your turn  ledger    codex          Migrate orders to Postgres 17
  ○ lost       checkout  claude         Spike: replay Stripe webhooks
  editor       checkout  nvim · acme/checkout
  ＋ new trail…  (53 codebases)
  ↩ resume old trails  (12 ended)
```

**＋ new trail…** lists the workspace's codebases as a tree: each workspace
directory with its folders under it, those with trails or recent history first,
then the codebases of their own, then `browse…`. Pick one, then an agent to start
there, with Tab for YOLO and ctrl-n to name it. Esc on either list comes back:

```console
acme ▸ New trail in: █   # enter: pick · esc: back
▌ ~/code/                   browse inside
    checkout                ● 2 trails
    ledger                  ○ 1 ended
    billing
    …
  ~/ops/terraform
  browse…                   from ~/code

ledger (acme) ▸ Start an agent: █   # enter: start · tab: toggle YOLO · ctrl-n: name it · ctrl-e: editor · esc: back
▌ claude · new trail
  codex · new trail
```

`browse…` and a workspace directory that isn't a codebase itself walk the file
system a folder at a time. A folder inside the workspace starts its trail there
with nothing asked, and is listed in the tree while it has trails or history. A
folder outside every workspace gets the question below.

**The workspaces** (from `~`, `/`, or `trails ws`): one row each, with what runs
in it, the one you were in last marked and under the cursor. Enter attaches to
its session on the trail that most wants you, or shows its screen when nothing
runs there. ctrl-n names a new workspace and takes its first codebase from the
directories under `~`.

```console
Pick a workspace: █   # enter: open · ctrl-n: new workspace
▌ acme         ● 3 trails · 1 needs you  · last
  personal     ● 1 trail
  client-x       nothing running
```

Every trail has two signals. The glyph says whether it is running (`●`) or not
(`○`); the word says what's going on:

| State | Means | Enter |
|---|---|---|
| `●` needs you | running, and the agent is asking you something | attach |
| `●` your turn | running, and it finished its turn | attach |
| `●` unknown | running, and nothing says what it's doing: [set up its hooks](#status-from-the-agents-hooks) | attach |
| `●` working | running, and it's busy | attach |
| `○` lost | tmux died under it (a reboot, a crash, `kill-server`) | bring it back on its conversation |
| `○` closed | it ended in the last 10 days; its conversation can be resumed | resume it, in the mode it last ran in |

```mermaid
stateDiagram-v2
    direction LR
    state "your turn" as your_turn
    state "needs you" as needs_you
    state "running ●" as running {
        working --> your_turn: turn ends
        your_turn --> working: you reply
        working --> needs_you: asks you something
        needs_you --> working: you answer
    }
    [*] --> working: start, resume, restore
    state "closed ○" as closed
    state "lost ○" as lost
    running --> closed: you quit or end it
    running --> lost: tmux dies
    lost --> working: restore
    closed --> working: resume
```

### Status from the agent's hooks

What a running trail is doing, and which conversation it is in, comes from the
agent's own hooks ([ADR 18](docs/decisions/0018-status-from-the-agents-hooks.md),
[ADR 19](docs/decisions/0019-no-agents-files-read.md)). The agent runs
`trails state working`, `waiting` or `idle`, with `--id` and its conversation where
it can, and trails takes its word. Without hooks a trail is *unknown*: trails doesn't
guess from the screen, and reads none of the agent's files.

Setting the hooks up is yours, and short: [each agent's hooks](#hooks-for-each-agent)
are below, to paste beside any hooks already there. Each hook ends in
`2>/dev/null || true`, so it is silent, never fails a turn, and does nothing outside
tmux or where `trails` isn't on the hook's `PATH`.

| Agent | Where | working | needs you | your turn |
|---|---|---|---|---|
| claude | the [Claude Code plugin](plugins/trails), or `~/.claude/settings.json` | prompt sent, tool done | permission prompt, a question | session start, turn end |
| codex | `~/.codex/hooks.json` (trust them with `/hooks` in codex) | prompt sent, tool done | permission request | session start, turn end |
| gemini | `~/.gemini/settings.json` | before the agent, after a tool | notification | session start, after the agent |
| copilot | `~/.copilot/hooks/trails.json` | prompt sent, tool done | (no hook) | session start, agent stop |
| cursor | `~/.cursor/hooks.json` | prompt sent | (no hook) | stop |
| opencode | `~/.config/opencode/plugins/trails.js` | busy, tool done | permission asked | idle |

For Claude, the plugin is the shortest way, and it also tells trails which
conversation Claude is in, so a trail follows it through `/resume` and `/clear`:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

An agent with no hook for a permission prompt reads as *working* through one. For an agent
not listed, have its hooks run `trails state working` when a prompt is sent or a tool
has run, `trails state waiting` when it asks you something, and `trails state idle`
when a session starts and when a turn ends, with `--id` and the conversation wherever
the hook knows it, at least when a session starts. `--id` is what lets a restore bring
back the conversation the agent is in now, and an agent that picks its own
conversation ID (no `session.start`) be restored at all. Getting the ID out of the
agent is the hook's job, in the agent's terms: trails takes what it is given.

<a id="hooks-for-each-agent"></a>
<details>
<summary><b>Hooks for each agent</b>, to paste</summary>

##### Claude Code

The shortest way is the plugin in this repo, which holds exactly these hooks:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

Or paste them into `~/.claude/settings.json`; use one or the other, or each hook
runs twice. Claude reads hooks when a session starts, so running sessions need a
restart.

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command",
      "command": "trails state idle --id \"$(jq -r '.session_id // empty')\" 2>/dev/null || true" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "trails state idle 2>/dev/null || true" }] }],
    "Notification": [{ "matcher": "permission_prompt",
      "hooks": [{ "type": "command", "command": "trails state waiting 2>/dev/null || true" }] }],
    "PreToolUse": [{ "matcher": "AskUserQuestion",
      "hooks": [{ "type": "command", "command": "trails state waiting 2>/dev/null || true" }] }]
  }
}
```

Claude passes each hook a JSON object on stdin, `session_id` among it, and runs
`SessionStart` again after `/resume` and `/clear`: so the trail follows it to the
conversation it moved to.

##### Codex

`~/.codex/hooks.json`. Codex runs a hook only once you have reviewed and trusted
it: `/hooks` in codex.

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "trails state idle 2>/dev/null || true" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "trails state idle 2>/dev/null || true" }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "trails state waiting 2>/dev/null || true" }] }]
  }
}
```

Codex picks its own conversation IDs, so without `--id` a Codex trail is not
restored after tmux dies. Add `--id` to the `SessionStart` hook once you have
checked which field of its hook input holds the ID (not yet checked here).

##### Gemini CLI

`~/.gemini/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "trails state idle 2>/dev/null || true" }] }],
    "BeforeAgent": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "AfterTool": [{ "hooks": [{ "type": "command", "command": "trails state working 2>/dev/null || true" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "trails state waiting 2>/dev/null || true" }] }],
    "AfterAgent": [{ "hooks": [{ "type": "command", "command": "trails state idle 2>/dev/null || true" }] }]
  }
}
```

##### GitHub Copilot CLI

`~/.copilot/hooks/trails.json`. Copilot has no hook for a permission prompt: it
reads as *working* until you answer.

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{ "type": "command", "bash": "trails state idle 2>/dev/null || true" }],
    "userPromptSubmitted": [{ "type": "command", "bash": "trails state working 2>/dev/null || true" }],
    "postToolUse": [{ "type": "command", "bash": "trails state working 2>/dev/null || true" }],
    "agentStop": [{ "type": "command", "bash": "trails state idle 2>/dev/null || true" }]
  }
}
```

##### Cursor

`~/.cursor/hooks.json`. Cursor's CLI has been reported to skip `beforeSubmitPrompt`
and `stop`, which its editor runs: check with `trails ls` after a turn. It has no
hook for a permission prompt.

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [{ "command": "trails state working 2>/dev/null || true" }],
    "stop": [{ "command": "trails state idle 2>/dev/null || true" }]
  }
}
```

##### opencode

A plugin, `~/.config/opencode/plugins/trails.js`:

```js
// trails: tell trails what this opencode is doing (trails state), from its own events.
export const Trails = async ({ $ }) => {
  const say = (word) => $`trails state ${word}`.quiet().nothrow()
  return {
    "tool.execute.after": async () => { await say("working") },
    event: async ({ event }) => {
      const t = event.type
      if (t === "session.status") {
        const s = event.properties?.status?.type
        if (s === "busy") await say("working")
        else if (s === "idle") await say("idle")
      } else if (t === "session.idle") await say("idle")
      else if (t === "permission.asked") await say("waiting")
      else if (t === "permission.replied") await say("working")
    },
  }
}
```

##### What has been checked

| Agent | Events | Conversation ID |
|---|---|---|
| claude | against 2.1.309 installed, the plugin validated | `session_id` on stdin, in its docs |
| codex | its docs only, not installed | not yet |
| gemini | its docs only, not installed | not yet |
| copilot | its docs only, not installed | not yet |
| cursor | 2026.07.09 installed; reports say the CLI skips both | not yet |
| opencode | 2.0.25 installed; event names in its binary | not yet |

</details>

| Key | Does |
|---|---|
| `enter` | open the row: attach, restore, resume, start the agent, or go to the editor or shell window |
| `tab` | toggle YOLO (run everything unconfirmed) on an agent to start, in the agents list, or a closed trail, flipping a new trail from the config's `mode` and a closed one from the mode it last ran in |
| `ctrl-n` | in the agents list, name the trail you are about to start: type the name, then Enter. On the workspace picker, a new workspace |
| `ctrl-e` | the editor for the row's codebase (`trails edit`) |
| `ctrl-/` | show or hide the preview: the trail's screen, under the list and kept current, refreshed every second, scrolled to its latest output. A trail wider than the preview wraps in it; a narrower one keeps its width, as its agent drew it. Open by default when there are rows for it |
| `ctrl-x` | end a running trail, close an editor or shell window, or forget a lost one; in the old trails, forget a closed one |
| `ctrl-a` | every running trail, in every workspace, on one screen (also `prefix A` from `trails keys`). Esc there comes back to where you were |
| `?` | the keys: the tmux ones from `trails keys`, the picker's, and what the states mean, in a popup (in place when the picker is itself in one). `q` comes back. `prefix ?` shows the same |
| `esc` | up a level: an old list or the agents back to where they came from, a codebase's screen to its workspace's, a workspace's to the workspaces, and the workspaces out. An editor's terminal quits from its codebase's screen |
| `ctrl-c` | quit, from any screen |

`trails` refuses to open an agent in `/`. `$HOME` is fine. A directory no
workspace claims asks which workspace its trail goes in, each time:

```console
~/Downloads/spike is in no workspace: █
▌ default    not added to a workspace
  personal   add it here
  acme       add it here
```

Enter keeps it in `default`, the workspace for every trail whose directory no
workspace claims. A workspace's row adds the directory to it as a codebase.
`trails new` asks nothing and uses `default`.

### Named trails

Name a trail when you start it, and that one name is how everything refers to it:

```console
~/code/checkout $ trails new payments
~/code/checkout $ trails ls
#payments  ● working    claude · yolo  acme  ~/code/checkout
#2         ● your turn  claude         acme  ~/code/checkout  Fix the flaky cart-total test
```

- **tmux** has its session as `acme/payments`, so `tmux a -t acme/payments` works,
  and its window in the workspace as `checkout·payments`.
- **The picker and `trails ls`** show `#payments` where an unnamed trail shows `#2`.
- **The agent** gets the name too where its config says how (`session.name`):
  Claude runs with `--name payments`.

A name is letters, digits, `-` and `_`, not digits alone, not starting with `-`,
not the codebase's name with a `-N` (which reads as an unnamed trail), and unused
by any running or lost trail. Resuming or restoring a named trail brings its name
back.

### The editor and a shell

The editor or a shell beside the agent, as panes of the trail's window. The
trail's session holds the agent alone, so an editor attached to it sees neither.
The panes are the **agent**, the **editor** and the **shell**, and they go where
they go whichever you open first:

- agent alone: the whole window
- agent and shell: the shell along the bottom, full width, a quarter high
- agent and editor: the editor on the left 60%, the agent on the right 40%
- all three: the shell under the editor only, a quarter high; the agent keeps
  its full-height column

Where nothing runs, the editor gets a window of its own in the workspace,
`checkout·nvim`, and the shell goes along its bottom.

| Command | Opens |
|---|---|
| `trails edit` | `$EDITOR` (nvim if unset) beside the agent, in the trail you run it from, else in the codebase's trail that most wants you; alone in a window of its own when nothing runs there. `C-b z` zooms a pane |
| `trails shell` | a shell in the codebase, tmux's own default command, along the bottom of that same window |
| `trails diff` | the codebase's changes, side by side: see [The diff](#the-diff) |

The window you are on decides the codebase: run from a trail or an editor window,
the command acts on that window; from a plain window in the workspace, on the
pane's directory; outside tmux, on the current directory, or `DIR` after the
command. Run again, it selects the pane that is there; run from that pane, it
goes back to the one you came from. When the agent exits or you end the trail
with the editor or a shell beside it, they stay, as the codebase's editor window
(`checkout·nvim`, or `checkout·shell` with only a shell). Nothing here is
restored after tmux dies: an editor or a shell is reopened with one command.

### The diff

`trails diff`, or `prefix G` from `trails keys`, shows a codebase's changes side
by side, to read what an agent did: in a popup over the workspace, wide enough for
both sides, or in the terminal when run from a shell. `q` closes it. The codebase
is the one `trails edit` would pick.

The changes are the working tree against `HEAD`, staged or not, and the files no
one has added yet, which agents make and `git diff` alone leaves out. Nothing is
staged to show them.

The config's `diff` says what shows them, in one of three ways.

- **A pager**, the diff piped to it. It should page, since the popup closes when it
  exits. The default is `delta --side-by-side --paging=always` when
  [delta](https://github.com/dandavison/delta) is installed, else `less`.
- **A program that finds the changes itself**, run in the popup in the codebase,
  with `"pipe": false`. Neovim with
  [codediff.nvim](https://github.com/esmuellert/codediff.nvim), VS Code's diff view,
  untracked files included, `q` closing it and the popup:

  ```json
  "diff": { "command": "nvim -c 'CodeDiff --exit-on-close'", "pipe": false }
  ```

  It is only started when there are changes to show.
- **A program with a window of its own**, run in the codebase with no popup, with
  `"gui": true`. [Fork](https://git-fork.com)'s commit view on the codebase:

  ```json
  "diff": { "command": "fork status", "gui": true }
  ```

### Notes

A thought about what else to do in a codebase, caught while an agent works on
something else, so it outlives the trail you had it in. Each codebase has a
notes file, a Markdown checklist that any editor opens:

```markdown
# checkout: notes

- [ ] Retry budget should be per merchant
- [x] Fix the flaky cart-total test
```

`prefix N` (from `trails keys`) opens a one-line popup, its keys shown until you
type:

```text
Note for checkout ▸ enter: save · esc: discard · enter on an empty note: open the notes
```

A note longer than the popup scrolls sideways as you type, and is kept whole.

Enter adds the note as an item. Esc drops it.
Enter on an empty line opens the notes in `$EDITOR`, to read them, tick them off
or add detail under an item.

`trails note "TEXT"` adds one from a shell, and `trails notes` opens them. From
the popup the codebase is the window's it opened over, from a shell the
directory you are in, and the notes are at the codebase's root: the
repository's top, or the directory itself outside git.

They go in `.scratch/trails/notes.md` there, or where the config's `notes`
says. trails writes the file and nothing else: commit it, or ignore `.scratch/`,
as the repo wants.

### trails ls

Plain `trails ls` lists the directory you're in, the same trails as the picker.
`trails ls ~/code/api` lists that directory, as if you'd run `trails ls` there.
`trails ls -a` lists every directory:

```console
$ trails ls -a
    ● needs you  claude · yolo  acme      ~/code/api               Rework the retry budget
#2  ● your turn  claude         personal  ~/.dotfiles              Fix the flaky test
    ○ lost       claude · yolo  acme      ~/code/foundry           Improve observability
    ○ closed     claude · yolo  personal  ~/notes         2h ago   Weekly review

● needs you  running, asking you something
● your turn  running, finished its turn
○ lost       not running: tmux died · trails restore brings it back
○ closed     not running: it ended · resume it from its directory
```

The first column names each running trail, so you can call it something:
`#2` marks the second trail in the same codebase, `#name` a named trail. The
workspace column follows the agent. The
dim legend covers the states on screen. Piped, `ls` prints one tab-separated line
per row, in the same order, with `-` for an empty field:

```text
life  state  session  agent  yolo  dir  id  when  workspace  title
```

| Field | Values |
|---|---|
| `life` | `running` (the trail is there) or `stopped` |
| `state` | `needs-you`, `your-turn`, `unknown`, `working` (running) · `lost`, `closed` (stopped) |
| `session` | what to attach to: the trail's session (`acme/checkout-2`); `-` for a trail that ended |
| `yolo` | `yolo` or `-` |
| `when` | when an ended trail ended (Unix time), else `-` |
| `workspace` | the trail's workspace; for an ended one, the one its directory belongs to now |

Any status bar, notifier or script can read it. The title stays last, so a reader that takes the last field keeps working as columns
are added. Set `TRAILS_RECENT_MAX=0` for a poll that only wants running trails; it
skips reading the history.

### trails map

`trails map 4` puts the four trails that most want you side by side in one
window, across workspaces. Each pane is a live view of a real trail, labelled with
its directory, its agent and what it's working on; type into any of them, and
detach (`C-b d`) to leave them all running. `trails map` re-attaches to the map
already up, or lets you pick up to four, the four that most want you ticked.

Three or more are tiled. Two go side by side when the terminal is at least 160
columns wide, since each agent wants about 80 to draw itself, and one above the
other when it is not. To settle it yourself, in the config:

```json
"map": { "two": "side", "layout": "tiled" }
```

`two` is `side`, `stacked` or `auto`; `layout` is the tmux layout for three or
more: `tiled`, `main-vertical` (one big pane on the left, the rest stacked on the
right), `main-horizontal`, `even-horizontal` or `even-vertical`. The map is plain
tmux, so its own keys rearrange a map you are looking at: `C-b Space` cycles the
layouts, `C-b M-1` to `M-5` pick one, `C-b z` zooms a pane to the whole window and
back, `C-b C-←` and friends resize, and `C-b ←↑↓→` move between panes. `main-pane-width`
in your tmux.conf sets the big pane's share for the `main-` layouts.

**The map a key away.** `prefix M` (from `trails keys`) goes to the map, which
the status line lists after the workspaces while one is up, a click away like them:

```text
 lattiq  personal  ▦ map │ 1:gunasekar  2:gunasekar-2  3:trails*
```

With no map up, or on the map already, it asks which trails, from every
workspace, with the four that most want you ticked; four at most, as a 2×2 grid.
`trails map new` asks the same way.

### Environment

| Variable | Default | Does |
|---|---|---|
| `TRAILS_ATTACH` | *(unset)* | `session` or `workspace`: where picking a trail lands, instead of guessing from the editor's variables (see From an editor). `view`, the old spelling, still works |
| `TRAILS_RECENT_DAYS` | `10` | how far back closed trails are listed |
| `TRAILS_RECENT_MAX` | `5` | how many of them to show (`0` for none) |

### Agents

Which agents trails can start, and how, is a list in
`~/.config/trails/config.json`, beside the workspaces. With no file, the built-in
agents apply. `trails config` writes them out as a starting point and opens the
file in `$EDITOR`. Changing agents never needs a change to trails.

```json
{
  "mode": "default",
  "default_agent": "claude",
  "agents": [
    {
      "name": "claude",
      "program": "claude",
      "yolo": "--dangerously-skip-permissions",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" }
    },
    { "name": "claude-opus", "program": "claude --model opus", "yolo": "--dangerously-skip-permissions" },
    { "name": "aider", "program": "aider --model ollama_chat/gemma3:1b", "yolo": "--yes-always" }
  ]
}
```

| Field | Means |
|---|---|
| `name` | what the picker shows. Letters, digits, `.`, `_` and `-` |
| `program` | the command line to run, split on spaces (no shell quoting; use a wrapper script for anything fancier) |
| `yolo` | *(optional)* the flag Tab adds to run everything unconfirmed |
| `session` | *(optional)* how trails learns which conversation a trail is in, so it can come back after tmux dies. See below. |
| `default_agent` | *(optional)* listed first in the picker |
| `mode` | *(optional)* `default` (the agent's own, prompting mode) or `yolo`: the mode a *new trail* row starts in. Tab flips a row from it, so with `yolo` Tab is how you start one in default mode. Closed trails come back in the mode they last ran in unless Tab flips them, and an agent with no `yolo` flag always runs in default mode. |
| `map` | *(optional)* how `trails map` lays out its panes: `two` (`side`, `stacked`, or `auto`, the default, which goes side by side from 160 columns) and `layout` for three or more (a tmux layout name, `tiled` by default). See [trails map](#trails-map). |
| `diff` | *(optional)* what `trails diff` shows the changes with: a pager to pipe to, `{ "command": ..., "pipe": false }` for one that finds them itself, or `{ "command": ..., "gui": true }` for an app. See [The diff](#the-diff). |
| `notes` | *(optional)* where a codebase's notes go: a path from the codebase's root, or `~`/absolute, with `{codebase}` for its name (`"~/notes/{codebase}.md"`). `.scratch/trails/notes.md` by default. See [Notes](#notes). |

Only agents whose command is on `PATH` are offered. Closed trails come from
trails' own history of the trails it ran (the newest 100), not from the agents':
a conversation started outside trails is the agent's own resume's to find.

#### Restore

To bring a trail back after tmux dies, trails needs the ID of the conversation
it was in. `session.resume` says how to resume one (`{id}` marks where the ID
goes), and how trails learns the ID:

| Key | trails gets the ID by | Example |
|---|---|---|
| `start` | choosing it, and starting the agent under it | `"start": "--session-id {id}", "id": "uuid"` |
| `create` | running a command that prints a fresh one | `"create": "cursor-agent create-chat"` |
| *(neither)* | the agent's hooks saying it: `trails state WORD --id ID` | codex |

`id` is the shape `start` generates: `uuid`, or `ses_hex` for opencode. With hooks
that pass `--id`, a trail also follows a conversation that changes inside the
agent, such as `/resume` or `/clear` in claude.

`session.name` is the flag that gives the agent a name of its own, `{name}` marking
where it goes. Only a named trail passes it. The built-in claude has
`"name": "--name {name}"`, and an agent without it still gets the trails name.

#### Built-in agents

The six most-used coding agents, with flags checked against each tool's latest
`--help` or docs in October 2026:

| Agent | Runs | YOLO flag | Restore |
|---|---|---|---|
| claude | `claude` | `--dangerously-skip-permissions` | yes: chosen ID, and follows `/resume` and `/clear` with its hooks |
| codex | `codex` | `--dangerously-bypass-approvals-and-sandbox` | only with hooks that pass `--id`: it picks its own ID |
| gemini | `gemini` | `--approval-mode yolo` | yes: chosen ID |
| copilot | `copilot` | `--allow-all` | yes: chosen ID |
| cursor | `cursor-agent` | `--force` | yes: `cursor-agent create-chat` |
| opencode | `opencode` | `--auto` | yes: chosen ID |

A trail that never got a message has nothing to resume, so restoring one
starts the agent fresh in its place.

Any other agent is one entry in the config. It runs in tmux like the rest; add a
`session` block only if the tool can start or resume by ID:

```json
{ "name": "aider", "program": "aider --model ollama_chat/gemma3:1b", "yolo": "--yes-always" },
{ "name": "antigravity", "program": "agy", "yolo": "--dangerously-skip-permissions" },
{ "name": "qwen", "program": "qwen", "yolo": "--yolo" }
```

trails refuses a YOLO launch as root for the two flags that also bypass a sandbox
(`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`).

### From an editor

Any editor that can run a command in a terminal pane can run `trails`, and every
editor and every shell shares one set of trails. In an editor's terminal, picking
a trail attaches to its session, so the panel shows that one trail; trails
tells an editor's terminal from your own by the variables editors set (`NVIM`,
`ZED_TERM`, `TERM_PROGRAM`), and `TRAILS_ATTACH=session` or `=workspace` settles
it by hand. Inside tmux, an editor's pane becomes a nested client of the trail's
session, and a
shell's client is switched to the workspace instead: no agent ever runs bare in
a pane any more, so an agent started from Neovim inside tmux is reachable from
everywhere else too.

- **VS Code:** add a terminal profile, then pick **trails** from the new-terminal
  menu. A login shell, so `trails` is found on your usual `PATH`:

  ```json
  "terminal.integrated.profiles.osx": {
    "trails": { "path": "/bin/zsh", "args": ["-lc", "exec trails"] }
  }
  ```

  To open it as an editor tab with a key, add to `keybindings.json`:

  ```json
  {
    "key": "cmd+alt+t",
    "command": "workbench.action.terminal.newWithProfile",
    "args": { "profileName": "trails", "location": "editor" }
  }
  ```

  The same works in Cursor and other VS Code-based editors.

- **Zed:** in `settings.json`, set `"terminal_init_command": "exec trails"` under
  `agent`. In remote mode it runs on the ssh host, where tmux keeps the agent
  alive across disconnects.
- **Neovim:** open a terminal running `trails` in a side panel.
- **Anything else:** run `trails` wherever the editor opens a terminal.

### Upgrading to 1.6

- **Status comes from the agent's hooks.** trails no longer reads state off the
  screen, so an agent without hooks shows *unknown*.
- **Gone:** the SwiftBar menu-bar plugin and `trails swiftbar`, `trails open` and
  `trails end` (ctrl-x ends a trail; `trails restore` forgets records it can't
  bring back), and support for trails from 0.6 (`trails-<project>` sessions):
  end any still running before upgrading.

### Upgrading to 1.7

- **trails reads no agent's files** ([ADR 19](docs/decisions/0019-no-agents-files-read.md)).
  Claude's status now comes from its hooks too: install the
  [Claude Code plugin](plugins/trails), or paste its hooks from
  [Hooks for each agent](#hooks-for-each-agent). Until then Claude trails read *unknown*.
- **Resume old trails** lists trails' own history: the trails that ended from 1.7
  on. Conversations from before, or started outside trails, are found by the
  agent's own resume.
- **Gone:** `trails hooks` (the snippets are in [Hooks for each agent](#hooks-for-each-agent)),
  the *elsewhere* state, the `@name` badge, the `pid` and `peer` columns of
  `trails ls`, and `session.find` in the config, which is ignored.
- **Codex** trails are restored only with hooks that pass `--id`.

## How it works

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) covers how workspaces, trails and
their windows map onto tmux, how trails are found and named, how *working*, *your
turn* and *needs you* come from the agent's hooks, how trails
survive tmux dying, where the history of ended trails comes from, and how the map and the
editor borrow a trail's session without owning it. Key design decisions are recorded in
[docs/decisions/](docs/decisions/), and the 1.0 design with its principles in
[docs/design/trails-1.0.md](docs/design/trails-1.0.md).

## License

[MIT](LICENSE)
