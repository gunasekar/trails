# Scenarios

Every way trails is used, as of the one-picker model
([ADR 17](decisions/0017-one-picker-levels-not-screens.md)). The first eight
are the everyday loop, drawn from the 1.0 design's journeys
([trails-1.0.md](design/trails-1.0.md#journeys)); the rest is everything else,
grouped by what you are doing. The [README](../README.md) has the detail of
each command and key.

Keys are the ones `trails keys` prints: `prefix P` the picker, `prefix W` the
workspaces, `prefix e` the editor, `` prefix ` `` a shell, `prefix N` the checklist.

## The everyday loop

| # | Scenario | How |
|---|---|---|
| 1 | Arrive at the machine: a fresh terminal, or an ssh login | `trails` from `~`, or `ssh host -t trails`: the workspaces; Enter attaches, on the trail that most wants you |
| 2 | Get to the trail that needs you | Selected on arrival; or `prefix P`, where the cursor starts on it |
| 3 | Start a trail in this codebase | `trails` in the repo, or `prefix P`: **＋ new trail…**, then an agent |
| 4 | Start a trail in another codebase of the workspace | `prefix P`: **＋ new trail…**, the codebase, then an agent |
| 5 | Move between trails and workspaces | `prefix P` for this workspace's trails, `prefix W` for the workspaces, or tmux's own window keys |
| 6 | Read or change the code beside the agent | `prefix e` for the editor, `` prefix ` `` for a shell |
| 7 | Come back after a break: lid closed, Wi-Fi dropped, a reboot | As in 1. After a reboot or a tmux crash, `trails restore` first |
| 8 | Finish, or pick old work back up | Quit the agent, or ctrl-x on its row; **↩ resume old trails** for what ended |

## Everything else

### Setting up

1. Install with Homebrew, or put `bin/trails` on `PATH`, with tmux 3.3 or later,
   fzf, jq and an agent CLI.
2. `trails config` writes the built-in agents to
   `~/.config/trails/config.json`, to edit: the agents, `default_agent`, `mode`
   (`default` or `yolo`), `map` and `data`.
3. Put a codebase in a workspace with `trails ws add NAME [DIR]`, or declare
   workspaces in the config: `/*` entries for workspace directories, plain
   paths for codebases of their own, and an optional `root` for `browse…`.
4. No workspaces at all: everything runs in `default`.
5. `trails keys` prints the tmux.conf lines for the five keys above.

### Starting a trail

1. In a repo: `trails`, **＋ new trail…**, an agent.
2. In a workspace: **＋ new trail…**, a codebase from the tree, an agent.
3. In a folder the tree doesn't list: **＋ new trail…**, **browse…**, walk to
   it, an agent. Inside a workspace directory it belongs there without asking.
4. In a folder no workspace claims: asked where it goes, `default` first and
   adding it nowhere, or a workspace, which adds it there.
5. Named: `trails new NAME [AGENT]`, or ctrl-n on the agents list. Claude takes
   the name as its own.
6. In YOLO: Tab on the agent's row, or `"mode": "yolo"` in the config to make
   it the default, when Tab is how you start one prompting.
7. From an editor's terminal (VS Code, Cursor, Zed, Neovim): the editor sees
   that one trail.
8. A second in the same codebase: a sibling, marked `#2`.

### Finding and moving

1. `trails` in a repo: that codebase's trails, the one that most wants you
   first.
2. `prefix P` in a workspace: its trails across its codebases.
3. `trails` from `~`, a fresh ssh login, or `prefix W`: the workspaces.
4. `trails ws NAME`: straight to a workspace.
5. `trails ls`, `ls -a`, `ls DIR`: a table of trails, tab-separated when piped.
7. tmux's own keys: next and previous window, `prefix s`, `choose-tree`.
8. Esc goes up a level, from a codebase to its workspace to the workspaces, and
   ctrl-c quits.

### Watching

1. Each trail says where it is: ● needs you, ● your turn, ● working, ○ lost,
   ○ closed.
2. ctrl-/ previews a trail's screen without opening it.
3. `trails map [N]`: several agents side by side in one window, the N that
   most want you; `map new` picks them again.

### Beside the agent

1. `prefix e` / `trails edit`: the editor on the left 60%, the agent on the
   right. Again goes back.
2. `` prefix ` `` / `trails shell`: a shell along the bottom.
3. Where nothing runs, the editor in a window of its own (`checkout·nvim`).
4. When the agent ends, the editor and shell stay, as the codebase's window.
5. ctrl-e in the picker: the editor for the row's codebase.

### Checklist

What to do next in a codebase, and the prompts to give its agent, parked while
it works.

1. `prefix N`: the checklist in a popup. Type an item, Enter adds it.
2. ↑ ↓ to an item: Space ticks it done, or back; Enter copies it, to paste into
   the agent.
3. Esc closes; ctrl-e opens the file in `$EDITOR`, in a popup of its own.
4. The status line counts it before the clock: `☑ 2/5`, open of all.
5. `trails note "TEXT"` adds one from a shell, and `trails checklist` opens it.
6. The config's `data` keeps every codebase's checklist in a folder of yours: iCloud
   Drive, and they are the same on each Mac.

### Ending and resuming

1. ctrl-x in the picker ends a running trail, into the history, or forgets a lost
   one; in the old trails, it forgets a closed one.
2. **↩ resume old trails**: the trails that ended here in the last 10 days, from
   trails' own history; Enter resumes one in the mode it last ran in, and Tab
   flips it.

### When things die

1. tmux dies (a crash, `kill-server`): the trails show as ○ lost.
2. `trails restore` brings each back on its own conversation, into its
   workspace.
3. A reboot: the same.
4. The lid closes, the network drops: the agents run on, and reattaching finds
   them mid-turn.

### Remote and more than one screen

1. One machine holds the agents, the others ssh in: `trails` lands on the same
   trails.
2. Zed over ssh and VS Code Remote-SSH attach to the same trails.
3. A workspace in two terminals: `tmux new-session -t ws -s 'ws~2'`, each
   terminal on a trail of its own.
4. The editor and shell keys act for the terminal that pressed them, however
   many are on the workspace.

### Agents

1. Any agent CLI, by one entry in the config: `name`, `program`, `yolo`,
   `session`.
2. Each says what it is doing, and which conversation it is in, through its hooks
   ([the README](../README.md#hooks-for-each-agent); for Claude, the plugin). trails reads none of an
   agent's files.
3. Session IDs (`start`, `create`, or the hooks' `--id`) are what bring a trail
   back after tmux dies.

### Edges trails handles

1. It refuses to start an agent in `/`.
2. It refuses a tmux session named like a workspace that it didn't make.
3. A git worktree belongs where its main checkout does.
4. A codebase whose name has a space or a `'` in it.
