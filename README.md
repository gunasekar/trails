# trails

An fzf picker for AI coding agents that live in tmux. Start Claude Code, Cursor,
opencode, antigravity or pi in a tmux session of their own, come back to it from
any terminal or editor, and see at a glance which one is waiting on you.

```text
claude  + new                                    ← enter starts a fresh one
  ├─ ● [blocked · #2]        Rework the retry budget   ← asking you something
  ├─ ● [working · YOLO]      Migrate the schema        ← getting on with it
  ├─ ↻ [restore]             Old spike                 ← died with tmux
  └─ ◷ [2d ago]              Tidy the release notes    ← a recent conversation
cursor  + new
  └─ ● [idle · #3]           Fix the flaky auth test   ← finished its turn
opencode  + new
```

Because each agent runs inside tmux, it outlives the terminal that started it.
Close the laptop, drop Wi-Fi or quit the terminal, and the conversation is still
running when you come back. A plain shell, a Zed thread and an nvim panel all go
through `trails` and land on the same sessions.

## Install

With Homebrew, on macOS or Linux:

```console
brew install gunasekar/tap/trails
```

By hand: it's one POSIX `sh` script. Put [`bin/trails`](bin/trails) anywhere on
your `PATH`.

It needs `tmux` and `fzf`, plus at least one agent CLI on `PATH`. Reading recent
opencode conversations uses `sqlite3`, which macOS ships with. Holding the Mac
awake (`ctrl-a`) uses macOS's `caffeinate`.

## Quickstart

```console
cd ~/code/my-project
trails              # pick an agent to start, or a session to rejoin
trails ls           # every agent on this machine, and which ones want you
trails cockpit 4    # the four that most want you, in one window
```

## Usage

| Command | Does |
|---|---|
| `trails` | pick a running session to rejoin, or an agent to start |
| `trails new` | skip the running sessions, start a fresh one |
| `trails ls` | every agent session on the box: a table on a terminal, TSV (state, session, agent, task) when piped |
| `trails recent` | conversations from the last 10 days in every directory: a table on a terminal, TSV (mtime, agent, directory, ID, title, pid if still open) when piped |
| `trails restore` | bring back every session that died with tmux, each on its own conversation, detached (`-n` or `--dry-run` lists them instead) |
| `trails cockpit [N]` | several agents in one window: re-attach to one already up, pick a set, or take the `N` that most want you (`cockpit new` forces a fresh pick) |
| `trails help` | the commands and picker keys (also `-h`, `--help`) |

In the picker, each agent you have installed gets a `+ new` row, with this
directory's sessions beneath it:

| Row | Means | Enter |
|---|---|---|
| `●` | running: `blocked` (asking you something), `idle` (finished its turn) or `working` | attach |
| `↻` | died with tmux (a reboot, a crash, `kill-server`) | bring it back on its conversation |
| `◷` | a recent conversation here that nothing is running | resume it |
| `!` | a recent conversation still open in a `claude` that trails didn't start | refuses, and says where it's open |

| Key | Does |
|---|---|
| `enter` | start, attach, restore or resume |
| `tab` | arm the highlighted agent or `◷` row for YOLO (run everything unconfirmed) |
| `ctrl-a` | hold the Mac awake for as long as that session lives |
| `ctrl-x` | kill the highlighted session, or forget a `↻` row |

The cursor starts on the session that most wants you. `trails` refuses to open
an agent in `/`. `$HOME` is fine.

### Environment

| Variable | Default | Does |
|---|---|---|
| `TRAILS_RECENT_DAYS` | `10` | how far back `◷` rows and `trails recent` look |
| `TRAILS_RECENT_MAX` | `5` | how many of them to show |
| `AGENT_SETTLE` | `0.35` | seconds between the two screen samples that tell `working` from `idle` |
| `AGENT_ASK_RE` | *(see script)* | regex meaning "this agent is asking you something" |

### Agents

Agents are rows in the `AGENTS` table at the top of the script: name, command,
extra args, YOLO flag, and the three fields that make a session restorable.
Adding one is one line. Only agents whose command is on `PATH` are offered.

| Agent | Command | YOLO flag | Restore and recent |
|---|---|---|---|
| claude | `claude` | `--dangerously-skip-permissions` | yes |
| cursor | `cursor-agent` | `--force` | no |
| antigravity | `agy` | `--dangerously-skip-permissions` | no |
| opencode | `opencode` | `--auto` | yes |
| pi | `pi` | none (it never asks) | no |

### From an editor

Point the editor's agent terminal at `trails`, and every editor and every shell
shares one set of sessions.

- **Zed:** in `settings.json`, set `"terminal_init_command": "exec trails"` under
  `agent`. In remote mode it runs on the ssh host, where tmux keeps the agent
  alive across disconnects.
- **Neovim:** open a terminal running `trails` in a side panel.

### Menu bar

`trails ls` piped gives one line per session, `state<TAB>session<TAB>agent<TAB>task`,
sorted most-wants-you first. A SwiftBar or xbar plugin can poll it to show a count
and notify when an agent stops and waits for you. `trails recent` piped does the
same for recent conversations.

## How it works

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) covers how sessions are named and
found, how `working` / `idle` / `blocked` is read off the screen, how sessions
survive tmux dying, where recent conversations come from, and how the cockpit
borrows sessions without owning them. Key design decisions are recorded in
[docs/decisions/](docs/decisions/).

## License

[MIT](LICENSE)
