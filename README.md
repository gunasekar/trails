# trails

A launcher for AI coding agents that live in tmux. Start Claude Code, Cursor,
opencode, antigravity or pi in a tmux session of its own, come back to it from any
terminal or editor, see where every session is, and resume the ones you closed.

Once an agent is running, trails gets out of the way: the session is plain tmux.

```text
claude  + new                                  ← enter starts a fresh one
  ├─ ● [blocked · #2]        Rework the retry budget   ← asking you something
  ├─ ● [working · YOLO]      Migrate the schema        ← getting on with it
  ├─ ↻ [restore]             Old spike                 ← lost when tmux died
  └─ ◷ [2d ago · YOLO]       Tidy the release notes    ← finished, resumable
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

It needs `tmux`, `fzf` and `jq`, plus at least one agent CLI on `PATH`. macOS
ships `jq`; Homebrew installs all three. Reading recent opencode conversations uses
`sqlite3`, which macOS ships with.

## Quickstart

```console
cd ~/code/my-project
trails              # pick an agent to start, or a session to rejoin or resume
trails ls           # where every session is, in every directory
trails map 4        # the four that most want you, side by side in one window
```

## Usage

| Command | Does |
|---|---|
| `trails` | the picker for this directory: start an agent, or rejoin, restore or resume a session |
| `trails ls` | where every agent session is: running, lost when tmux died, or finished in the last 10 days |
| `trails restore` | bring back every session lost when tmux died, each on its own conversation, detached |
| `trails map [N]` | several running agents side by side in one window: re-attach to the map already up, pick a set, or take the `N` that most want you (`map new` forces a fresh pick) |
| `trails config` | open the agents file in `$EDITOR`, writing the built-ins first if there isn't one |
| `trails help` | the commands and picker keys (also `-h`, `--help`) |

### The picker

Each agent you have installed gets a `+ new` row, with this directory's sessions
beneath it. The cursor starts on the session that most wants you.

| Row | Means | Enter |
|---|---|---|
| `●` | running: `blocked` (asking you something), `idle` (finished its turn) or `working` | attach |
| `↻` | lost when tmux died (a reboot, a crash, `kill-server`) | bring it back on its conversation |
| `◷` | a recent conversation here that nothing is running | resume it, in the mode it last ran in |
| `!` | a recent conversation still open in a `claude` that trails didn't start | refuses, and says where it's open |

| Key | Does |
|---|---|
| `enter` | start, attach, restore or resume |
| `tab` | arm the highlighted agent or `◷` row for YOLO (run everything unconfirmed) |
| `ctrl-x` | kill the highlighted session, or forget a `↻` row |

`trails` refuses to open an agent in `/`. `$HOME` is fine.

### trails ls

```console
$ trails ls
● blocked  claude · yolo  ~/code/api            Rework the retry budget
● idle     claude         ~/.dotfiles #2        Fix the flaky test
↻ restore  claude · yolo  ~/code/foundry        Improve observability
◷ 2h ago   claude · yolo  ~/notes               Weekly review
! 1d ago   claude         ~/scratch             Spike on caching  (open in claude, pid 812)
↻ trails restore brings these back · ◷ run trails in its directory to resume
```

`#2` marks the second session in the same directory. Piped, `ls` prints one
tab-separated line per row, in the same order, with `-` for an empty field:

```text
state  session  agent  yolo  dir  id  when  pid  title
```

| Field | Values |
|---|---|
| `state` | `blocked`, `idle`, `working` (running) · `restore` (lost with tmux) · `recent`, `open` (finished; `open` is still held by a `claude` trails didn't start) |
| `session` | the tmux session name, or `-` for a finished conversation |
| `yolo` | `yolo` or `-` |
| `when` | when a finished conversation was last active (Unix time), else `-` |
| `pid` | the process holding an `open` one, else `-` |

That makes it easy to drive a menu-bar item (SwiftBar, xbar) that counts the
agents waiting on you. Set `TRAILS_RECENT_MAX=0` for a poll that only wants
running sessions; it skips reading conversation history.

### Environment

| Variable | Default | Does |
|---|---|---|
| `TRAILS_RECENT_DAYS` | `10` | how far back `◷` rows look |
| `TRAILS_RECENT_MAX` | `5` | how many of them to show (`0` for none) |
| `AGENT_SETTLE` | `0.35` | seconds between the two screen samples that tell `working` from `idle` |
| `AGENT_ASK_RE` | *(see script)* | regex meaning "this agent is asking you something" |

### Agents

Which agents trails can start, and how, is a list in
`~/.config/trails/config.json`. With no file, the built-in agents apply.
`trails config` writes them out as a starting point and opens the file in
`$EDITOR`. Changing agents never needs a change to trails.

```json
{
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
| `session` | *(optional)* how to start a conversation under an ID trails chooses (`start`) and resume it (`resume`); `{id}` marks where the ID goes, and `id` is `uuid` or `ses_hex`. This is what lets a session come back after tmux dies. |
| `default_agent` | *(optional)* listed first in the picker |

Only agents whose command is on `PATH` are offered. Recent conversations are
read from claude's and opencode's own history, and are filed under the first
agent that runs `claude` or `opencode`.

The built-in agents, checked against each tool's docs or `--help` in October
2026:

| Agent | Runs | YOLO flag | Restores after tmux dies |
|---|---|---|---|
| claude | `claude` | `--dangerously-skip-permissions` | yes |
| codex | `codex` | `--dangerously-bypass-approvals-and-sandbox` | no |
| gemini | `gemini` | `--approval-mode=yolo` | no |
| cursor | `cursor-agent` | `--force` | no |
| opencode | `opencode` | `--auto` | yes |
| copilot | `copilot` | `--allow-all` | yes |
| qwen | `qwen` | `--yolo` | no |
| aider | `aider` | `--yes-always` | no |
| amp | `amp` | `--dangerously-allow-all` | no |
| goose | `goose session` | none (set `GOOSE_MODE=auto`) | no |
| crush | `crush` | `--yolo` | no |
| kiro | `kiro-cli chat` | `--trust-all-tools` | no |
| antigravity | `agy` | `--dangerously-skip-permissions` | no |
| pi | `pi` | none (it never asks) | yes |

"No" means the tool can only resume an ID it made itself, so trails can't choose
one up front to bring the session back by. The agent still runs normally in tmux.
trails refuses a YOLO launch as root for the two flags that also bypass a sandbox
(`--dangerously-skip-permissions`, `--dangerously-bypass-approvals-and-sandbox`).

### From an editor

Point the editor's agent terminal at `trails`, and every editor and every shell
shares one set of sessions.

- **Zed:** in `settings.json`, set `"terminal_init_command": "exec trails"` under
  `agent`. In remote mode it runs on the ssh host, where tmux keeps the agent
  alive across disconnects.
- **Neovim:** open a terminal running `trails` in a side panel.

## How it works

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) covers how sessions are named and
found, how `working` / `idle` / `blocked` is read off the screen, how sessions
survive tmux dying, where recent conversations come from, and how the map
borrows sessions without owning them. Key design decisions are recorded in
[docs/decisions/](docs/decisions/).

## License

[MIT](LICENSE)
