<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/logo-dark.png">
    <img alt="trails" src="assets/logo-light.png" width="240">
  </picture>
</h1>

trails is an opinionated session manager for coding agents, built on tmux. Each
agent (Claude Code, Codex, Gemini, Copilot, Cursor, opencode, or any CLI you
configure) runs in a tmux session of its own, a *trail*, grouped by workspace.
`trails` shows what is running and what is waiting on you, opens the one you
pick, and brings them back after tmux or the machine goes down.

![From one terminal: the workspaces, a workspace's trails with a live preview, the editor and a shell beside the agent, and the workspaces in the status line](assets/trails.gif)

## Its opinions

- **One machine holds the agents.** Everything else connects to it: a second
  laptop, an editor over ssh, a phone. Close the lid, come back, and the
  conversation is where you left it, mid-turn.
- **Work grouped the way you think of it.** A workspace is a company, a client,
  or "personal": unrelated repos together, and one ssh connection reaches them all.
- **The agent writes, you stay hands-on.** The editor, a shell and the diff of
  what the agent changed are each a key away, beside the agent, in its own window:
  read the code, run it, and review every change before it lands, without leaving
  the trail.
- **An agent is known by its config and its hooks, never its files.** Every agent
  is equal, and an agent's release can't break trails.
- **tmux does the work.** No daemon and no server of its own: a trail is a tmux
  session, so anything that speaks tmux can reach it, and uninstalling trails
  leaves ordinary tmux behind.

It is not for running a swarm of agents and shipping what comes back unread, and
it has no chat window of its own: the agent's interface is the agent's.

## Install

```console
brew install gunasekar/tap/trails
```

Or put [`bin/trails`](bin/trails), one POSIX `sh` script, anywhere on your
`PATH`. It needs tmux 3.3 or later, fzf and jq, and at least one agent CLI.
[delta](https://github.com/dandavison/delta) (`brew install git-delta`) is
recommended for the diff, and `curl` keeps the picker's preview live.

## Quickstart

1. **Put trails on tmux's keys.** One line in `~/.config/tmux/tmux.conf` (or
   `~/.tmux.conf`) loads them from the installed trails, so they follow every
   upgrade; reload tmux after adding it:

   ```tmux
   run-shell "trails keys | tmux source-file -"
   ```

2. **Give your agent its hooks**, so trails knows what it is doing. For Claude
   Code it is a plugin, typed in Claude:

   ```
   /plugin marketplace add gunasekar/trails
   /plugin install trails@trails
   ```

   For any other agent, see [Hooks for each agent](#hooks-for-each-agent).

3. **File your codebases under workspaces** (optional; without any, everything is
   in `default`):

   ```console
   trails ws add acme ~/code/checkout
   ```

4. **Run `trails`** in a codebase and start an agent:

   ```console
   ~/code/checkout $ trails
   checkout (acme) ▸ Pick a trail: █   # enter: open · ctrl-e: editor · ctrl-/: preview · ctrl-x: end · ?: keys · esc: up
     ＋ new trail…
   ▌ ● needs you  claude · yolo  #3f9a  Add idempotency keys to payment retries
     ● your turn  claude         #b07e  Fix the flaky cart-total test
     ● working    codex          #c41a  Migrate orders to Postgres 17
     ○ lost       claude         #9d2e  Spike: replay Stripe webhooks
     ↩ resume old trails  (3 ended)
   ```

From then on it is keys: `prefix P` for this workspace's trails, `E` for the
editor beside the agent, `G` for its diff. `prefix H` lists them all. The
everyday loop, and every other way trails is used, are in
[docs/scenarios.md](docs/scenarios.md).

## Keys

In tmux, after `prefix`, from `trails keys`:

| Key | Does |
|---|---|
| `P` | this workspace's trails, in a popup: the picker |
| `W` | the workspaces |
| `A` | every running trail, in every workspace |
| `E` | the editor beside the agent; again, back where you were |
| `` ` `` | a shell beside the agent; again, back |
| `G` | the codebase's changes, side by side ([the diff](#the-editor-a-shell-and-the-diff)) |
| `N` | the codebase's [checklist](#checklist) |
| `M` | the [map](#the-map): up to four trails side by side |
| `K` `J` | the previous and next workspace |
| `R` | rename the trail you are on ([named trails](#named-trails)) |
| `H` | these keys, in a popup |

In the picker:

| Key | Does |
|---|---|
| `enter` | open the row: attach, bring back a lost trail, resume a closed one, or start an agent |
| `tab` | toggle YOLO (run everything unconfirmed) on an agent to start or a closed trail |
| `ctrl-n` | name the trail you are about to start; on the workspaces, a new workspace |
| `ctrl-r` | rename the running trail under the cursor; an empty name takes it away |
| `ctrl-e` | the editor for the row's codebase |
| `ctrl-/` | show or hide the preview: the trail's screen, kept live |
| `ctrl-x` | end a running trail, close an editor or shell window, or forget a lost or closed one |
| `ctrl-a` | every running trail, in every workspace |
| `?` | the keys and what the states mean |
| `esc` | up a level: a codebase to its workspace, a workspace to the workspaces, then out |

Every trails key is a capital letter, but `` ` `` for the shell, so tmux's own
keys stay tmux's: `?` still lists every binding, `(` and `)` still cycle through
every session. `P`, `W`, `A`, `N`, `G`, `R`, `H`, `J` and `K` are unbound in
tmux's defaults; `E` replaces spreading the panes out evenly (still
`:select-layout -E`), and `M` clearing the marked pane (still `prefix m` on it). A
line after the `trails keys` one that binds the same key wins.

## Using it

### Workspaces

A workspace is a set of codebases you choose, in `~/.config/trails/config.json`,
as paths or globs:

```json
"workspaces": {
  "acme":     { "root": "~/code", "codebases": ["~/code/*"] },
  "personal": ["~/src/*", "~/.dotfiles"]
}
```

`~/code/*` makes every folder in `~/code` a codebase, so a new clone needs no
edit. A folder inside a codebase, and a git worktree of one, belong to it; the
most specific entry wins an overlap. `trails ws add NAME [DIR]` edits the config
for you, and the picker offers to when you start a trail in a directory no
workspace claims.

In tmux, a workspace is a session named after it, with a window per trail, and
each trail is a small session of its own holding the agent alone:

```text
acme                    ← workspace: a window per trail
├─ checkout-3f9a        ← shows acme/checkout-3f9a; the editor and a shell beside it
├─ checkout-b07e        ← shows acme/checkout-b07e
└─ billing·nvim         ← the editor alone, nothing running in billing
acme/checkout-3f9a      ← a trail: claude in ~/code/checkout, its ID t3f9a
acme/checkout-b07e      ← another, in the same codebase
```

The status line lists the running workspaces at the left, a click away, and at
the right what the current trail is working on, then the checklist's count before
the clock:

```text
 acme  personal │ 1:checkout-3f9a  2:checkout-b07e*  3:billing·nvim   Fix the flaky cart-total test · ☑ 2/5 · 14:05
```

The task is the title the agent gives its terminal, Claude's summary of the
conversation, read as it changes and cut at 40 characters; a named trail has its
name in its window instead.

Plain tmux moves you around too: `tmux a -t acme` is the workspace and
`tmux a -t acme/checkout-3f9a` one trail. An unnamed trail's session and window
carry its ID, four hex digits that stay with it through a restore and are never
another trail's while it lives.

### The picker

`trails` opens where you are: in a codebase, its trails and the agents to start;
in a workspace's tmux session, the workspace's trails across its codebases; from
`~`, the workspaces. Enter goes down a level and Esc up one. The cursor starts on
the trail that most wants you.

Every trail is running (`●`) or not (`○`), and says what is going on:

| State | Means | Enter |
|---|---|---|
| `●` needs you | the agent is asking you something | attach |
| `●` your turn | it finished its turn | attach |
| `●` working | it is busy | attach |
| `●` unknown | nothing says: [set up its hooks](#hooks-for-each-agent) | attach |
| `○` lost | tmux died under it: a reboot, a crash, `kill-server` | bring it back on its conversation |
| `○` closed | it ended in the last 10 days | resume it, in the mode it last ran in |

**＋ new trail…** lists the agents to start, with Tab for YOLO and ctrl-n to name
the trail. **↩ resume old trails** lists the trails that ended here, from trails'
own history of the newest 100.

`trails ls` prints the same rows, and `trails ls -a` every directory's; piped, it
is tab-separated for scripts ([the fields](#trails-ls)).

### Status from the agent's hooks

What a trail is doing, and which conversation it is in, comes from the agent's
own hooks ([ADR 18](docs/decisions/0018-status-from-the-agents-hooks.md),
[ADR 19](docs/decisions/0019-no-agents-files-read.md)). They run
`trails state working`, `waiting` or `idle`, with `--agent` and the agent's
program, and `--id` and its conversation where the hook knows it. trails takes
their word: it never guesses from the screen and reads none of an agent's files.
Without hooks, a trail is *unknown*.

| Agent | Hooks go in | needs you |
|---|---|---|
| claude | the [Claude Code plugin](plugins/trails), or `~/.claude/settings.json` | yes |
| codex | `~/.codex/hooks.json`, trusted with `/hooks` in codex | yes |
| gemini | `~/.gemini/settings.json` | yes |
| copilot | `~/.copilot/hooks/trails.json` | no hook: reads *working* through a prompt |
| cursor | `~/.cursor/hooks.json` | no hook: reads *working* through a prompt |
| opencode | `~/.config/opencode/plugins/trails.js` | yes |

Each hook ends in `2>/dev/null || true`: silent, never failing a turn, and
inert outside tmux. With `--id`, a trail follows its conversation through
`/resume` and `/clear`, and a restore brings back the one it is in now.

<a id="hooks-for-each-agent"></a>
<details>
<summary><b>Hooks for each agent</b>, to paste</summary>

##### Claude Code

The plugin in this repo holds exactly these hooks:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

Or paste them into `~/.claude/settings.json`; one or the other, or each hook runs
twice. Claude reads hooks when a session starts, so running sessions need a
restart.

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command",
      "command": "trails state idle --id \"$(jq -r '.session_id // empty')\" --agent claude 2>/dev/null || true" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "trails state working --agent claude 2>/dev/null || true" }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "trails state working --agent claude 2>/dev/null || true" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "trails state idle --agent claude 2>/dev/null || true" }] }],
    "Notification": [
      { "matcher": "permission_prompt",
        "hooks": [{ "type": "command", "command": "trails state waiting --agent claude 2>/dev/null || true" }] },
      { "matcher": "idle_prompt",
        "hooks": [{ "type": "command", "command": "trails state idle --agent claude 2>/dev/null || true" }] }],
    "PreToolUse": [{ "matcher": "AskUserQuestion",
      "hooks": [{ "type": "command", "command": "trails state waiting --agent claude 2>/dev/null || true" }] }]
  }
}
```

Claude passes each hook a JSON object on stdin, `session_id` among it, and runs
`SessionStart` again after `/resume` and `/clear`, so the trail follows it.

##### Codex

`~/.codex/hooks.json`. Codex runs a hook only once you have reviewed and trusted
it: `/hooks` in codex.

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "trails state idle --agent codex 2>/dev/null || true" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "trails state working --agent codex 2>/dev/null || true" }] }],
    "PostToolUse": [{ "hooks": [{ "type": "command", "command": "trails state working --agent codex 2>/dev/null || true" }] }],
    "Stop": [{ "hooks": [{ "type": "command", "command": "trails state idle --agent codex 2>/dev/null || true" }] }],
    "PermissionRequest": [{ "hooks": [{ "type": "command", "command": "trails state waiting --agent codex 2>/dev/null || true" }] }]
  }
}
```

Codex picks its own conversation IDs, so without `--id` a Codex trail is not
restored after tmux dies. Add `--id` to `SessionStart` once you have checked which
field of its hook input holds the ID (not yet checked here).

##### Gemini CLI

`~/.gemini/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "trails state idle --agent gemini 2>/dev/null || true" }] }],
    "BeforeAgent": [{ "hooks": [{ "type": "command", "command": "trails state working --agent gemini 2>/dev/null || true" }] }],
    "AfterTool": [{ "hooks": [{ "type": "command", "command": "trails state working --agent gemini 2>/dev/null || true" }] }],
    "Notification": [{ "hooks": [{ "type": "command", "command": "trails state waiting --agent gemini 2>/dev/null || true" }] }],
    "AfterAgent": [{ "hooks": [{ "type": "command", "command": "trails state idle --agent gemini 2>/dev/null || true" }] }]
  }
}
```

##### GitHub Copilot CLI

`~/.copilot/hooks/trails.json`:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{ "type": "command", "bash": "trails state idle --agent copilot 2>/dev/null || true" }],
    "userPromptSubmitted": [{ "type": "command", "bash": "trails state working --agent copilot 2>/dev/null || true" }],
    "postToolUse": [{ "type": "command", "bash": "trails state working --agent copilot 2>/dev/null || true" }],
    "agentStop": [{ "type": "command", "bash": "trails state idle --agent copilot 2>/dev/null || true" }]
  }
}
```

##### Cursor

`~/.cursor/hooks.json`. Cursor's CLI has been reported to skip `beforeSubmitPrompt`
and `stop`, which its editor runs: check with `trails ls` after a turn.

```json
{
  "version": 1,
  "hooks": {
    "beforeSubmitPrompt": [{ "command": "trails state working --agent cursor-agent 2>/dev/null || true" }],
    "stop": [{ "command": "trails state idle --agent cursor-agent 2>/dev/null || true" }]
  }
}
```

##### opencode

A plugin, `~/.config/opencode/plugins/trails.js`:

```js
// trails: tell trails what this opencode is doing (trails state), from its own events.
export const Trails = async ({ $ }) => {
  const say = (word) => $`trails state ${word} --agent opencode`.quiet().nothrow()
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

##### Any other agent

Have its hooks run `trails state working` when a prompt is sent or a tool has
run, `trails state waiting` when it asks you something, and `trails state idle`
when a session starts and when a turn ends, each with `--agent PROGRAM` (its
command's name, as the config runs it), and `--id` and the conversation wherever
the hook knows it, at least when a session starts. Getting the ID out of the agent
is the hook's job: trails takes what it is given.

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

### The editor, a shell and the diff

`prefix E` opens your editor (`$EDITOR`, nvim if unset) and `` prefix ` `` a
shell, beside the agent, as panes of the trail's window in the codebase. Pressed
again, each takes you back where you were. They go where they go whichever you
open first:

| Open | Layout |
|---|---|
| the agent | the whole window |
| agent and shell | the agent on the left 60%, the shell on the right 40% |
| agent and editor | the agent on the left 40%, the editor on the right 60% |
| all three | the agent on the left, full height; the shell under the editor, a quarter high |

The trail's own session holds the agent alone, so an editor attached to it sees
neither pane. Where nothing runs, the editor gets a window of its own,
`checkout·nvim`. When a trail ends, its editor and shell stay, as that window.
`trails edit` and `trails shell` do the same from a shell.

`prefix G` (`trails diff`) shows the codebase's changes side by side, in a popup:
the working tree against `HEAD`, staged or not, and the files the agent made that
git doesn't track yet. Nothing is staged to show them; `q` closes it. It uses
delta when it is installed, else `less`, and the config's `diff` picks another:

```json
"diff": { "command": "nvim -c 'CodeDiff --exit-on-close'", "pipe": false }
```

That is Neovim with [codediff.nvim](https://github.com/esmuellert/codediff.nvim),
which finds the changes itself (`"pipe": false`). A plain string is a pager the
diff is piped to, and `"gui": true` runs an app with a window of its own, such as
[Fork](https://git-fork.com) (`"command": "fork status"`).

### Checklist

What to do next in a codebase, and the prompts you mean to give its agent, parked
while it works on something else. `prefix N` opens it: a line to type a new item
on, the items under it, open ones first, and under them the item the cursor is
on, whole.

```text
Checklist for checkout ▸ type a new item · ↑↓ to one: space ticks it, enter copies it · ctrl-e: edit · esc: close
▌ ☐ Ask it to make the retry budget per merchant, so one merchant's outage doesn't…
  ☐ Check the refund window against the spec
  ☑ Fix the flaky cart-total test
──────────────────────────────────────────────────────────────────────────────────
Ask it to make the retry budget per merchant, so one merchant's outage doesn't
↳ spend every other merchant's retries.
Keep the global cap as a ceiling.
```

| Key | Does |
|---|---|
| type, then `enter` | add it; the list stays open, on it, for the next |
| `↑` `↓` | move through the items |
| `space` | tick the item done, or back |
| `enter`, nothing typed | copy the item, with the lines under it, and close: paste it into the agent |
| `ctrl-e` | the file in `$EDITOR`; quit it and the list is back |
| `esc` | close |

The status line counts the codebase's open items of all, `☑ 2/5`.
`trails note "TEXT"` adds one from a shell.

It is a Markdown file, `.trails/checklist.md` at the codebase's root, which you
commit or ignore as the repo wants. Or keep every codebase's checklist in a
synced folder, to have the same ones on every machine, with the config's `data`:

```json
"data": "~/Library/Mobile Documents/com~apple~CloudDocs/"
```

That puts them in iCloud Drive under `trails/`, one folder per codebase, named
from its path under your home folder as Claude names a project
(`~/code/checkout` is `code-checkout`). A worktree shares its repository's.

### Named trails

```console
~/code/checkout $ trails new payments
```

Its session is `acme/payments`, its window `checkout·payments`, the picker shows
it as `#payments`, and the agent gets the name too where its config says how
(Claude runs with `--name payments`). An unnamed trail is `#` and its ID, `#3f9a`.
A name comes back with the trail when it is resumed or restored.

A trail can be named, or renamed, while it runs: when the work has moved on from
what the agent's title says, `prefix R` (or `trails rename NAME` in it, ctrl-r in
the picker) names it, and an empty name takes the name away. Its windows, its badge
and its record take the name; its session keeps the one it started with until a
restore brings it back under the name. The agent keeps the name it was started with.

### When tmux goes down

After a reboot, a crash or a `kill-server`, the trails show up as *lost*, not
gone. Enter on one brings it back on its conversation, and `trails restore`
brings back them all, each into its workspace. To have tmux do that whenever it
starts, add the line `trails keys` offers for it:

```tmux
run-shell -b "trails restore >/dev/null 2>&1"
```

A tmux server started from a terminal can also go down *with* that terminal. On
macOS, a Force Quit of kitty, Ghostty or Zed ends the tmux server that was
started from one of its shells, and every agent in it, however detached it
looked. To have the server belong to no app, let your service manager run it:

```console
brew services start trails
```

That runs `trails boot` at login: a launch agent on macOS, a systemd user
unit on Linux. It starts tmux, brings back the lost trails without waiting for
a terminal, and starts tmux again after a crash or a `kill-server`. The server
takes your login shell's environment, so put the `PATH` your agents need in
`~/.zprofile` or `~/.zshenv` (or bash's `~/.bash_profile`), not only in
`~/.zshrc`. `brew services stop trails` stops it, and with it every trail; they
come back as lost, as after a reboot. While a server a terminal started is still
up, the service waits for it to go. Its log is
`$(brew --prefix)/var/log/trails-boot.log`.

### The map

`prefix M` (or `trails map 4`) puts up to four trails side by side in one window,
across workspaces, each a live view you can type into. The status line lists it
after the workspaces while it is up. `C-b d` leaves them all running.

![prefix M: trails from two workspaces picked into the map, four agents at work side by side, and the map in the status line beside the workspaces](assets/map.gif)

### From an editor

Any editor that can run a command in a terminal can run `trails`, and every
editor and shell sees the same trails. In an editor's terminal, picking a trail
attaches to it alone, so the panel shows that one trail.

- **VS Code** (and Cursor): a terminal profile, `"trails": { "path": "/bin/zsh", "args": ["-lc", "exec trails"] }`
  under `terminal.integrated.profiles.osx`, then pick **trails** from the
  new-terminal menu.
- **Zed:** `"terminal_init_command": "exec trails"` under `agent`. Over ssh it
  runs on the host, where tmux keeps the agent alive across disconnects.
- **Neovim:** a terminal running `trails` in a side panel.

trails tells an editor's terminal by the variables editors set (`NVIM`,
`ZED_TERM`, `TERM_PROGRAM`); `TRAILS_ATTACH=session` or `=workspace` settles it.

## Commands

| Command | Does |
|---|---|
| `trails` | the picker for where you are |
| `trails ws [NAME]` | pick a workspace, or go to `NAME` |
| `trails ws list` / `of [DIR]` / `add NAME [DIR]` / `next`, `prev` | the workspaces; the one `DIR` belongs to; add `DIR` to `NAME`; the next or previous running one |
| `trails new NAME [AGENT]` | start a trail named `NAME`, `-y` for YOLO |
| `trails rename [TRAIL] NAME` | name the trail you are on, or `TRAIL` (its ID); `''` takes its name away |
| `trails edit` / `shell` `[DIR]` | the editor or a shell beside the agent |
| `trails diff [DIR]` | the codebase's changes, side by side |
| `trails checklist [DIR]` / `note TEXT` | the checklist; add an item |
| `trails ls [-a \| DIR]` | the trails, here, in `DIR` or everywhere |
| `trails restore` | bring back every lost trail |
| `trails boot` | start tmux and the lost trails, for `brew services start trails` |
| `trails map [N \| new]` | trails side by side in one window |
| `trails keys` | the tmux.conf lines for the keys and the status line |
| `trails state WORD [--id ID] [--agent PROGRAM]` | for an agent's hooks: `working`, `waiting` or `idle` |
| `trails config` | the config in `$EDITOR`, the built-in agents written first |
| `trails help [keys]` | the commands and keys |

## Configuration

`~/.config/trails/config.json` holds the workspaces, the agents, and a few
settings. Without one, the built-in agents apply; `trails config` writes them out
and opens the file.

```json
{
  "mode": "default",
  "default_agent": "claude",
  "agents": [
    {
      "name": "claude",
      "program": "claude",
      "yolo": "--dangerously-skip-permissions",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid",
                   "name": "--name {name}" }
    },
    { "name": "aider", "program": "aider --model ollama_chat/gemma3:1b", "yolo": "--yes-always" }
  ],
  "data": "~/Library/Mobile Documents/com~apple~CloudDocs/"
}
```

| Key | Means |
|---|---|
| `agents` | what the picker can start: `name`, `program` (split on spaces), `yolo` (the flag Tab adds), `session` (how to restore it, below). Only agents on `PATH` are offered |
| `default_agent` | listed first |
| `mode` | `default` or `yolo`: the mode a new trail starts in; Tab flips it |
| `workspaces` | see [Workspaces](#workspaces) |
| `data` | a folder for each codebase's checklist; `.trails/checklist.md` in the codebase without it |
| `diff` | what shows the diff: see [the diff](#the-editor-a-shell-and-the-diff) |
| `map` | `two` (`side`, `stacked`, `auto`) and `layout` (a tmux layout for three or more) |

<details>
<summary><b>Restoring an agent</b>: the <code>session</code> block, and the built-in agents</summary>

To bring a trail back, trails needs its conversation ID. `session.resume` says
how to resume one (`{id}` marks where it goes), and trails learns the ID by:

| Key | trails gets the ID by | Example |
|---|---|---|
| `start` | choosing it, and starting the agent under it | `"start": "--session-id {id}", "id": "uuid"` |
| `create` | running a command that prints a fresh one | `"create": "cursor-agent create-chat"` |
| *(neither)* | the agent's hooks saying it: `trails state WORD --id ID` | codex |

`id` is the shape `start` generates: `uuid`, or `ses_hex` for opencode.
`session.name` is the flag that names the agent, `{name}` where it goes; only a
named trail passes it.

| Agent | Runs | YOLO flag | Restore |
|---|---|---|---|
| claude | `claude` | `--dangerously-skip-permissions` | chosen ID; follows `/resume` and `/clear` with its hooks |
| codex | `codex` | `--dangerously-bypass-approvals-and-sandbox` | only with hooks that pass `--id` |
| gemini | `gemini` | `--approval-mode yolo` | chosen ID |
| copilot | `copilot` | `--allow-all` | chosen ID |
| cursor | `cursor-agent` | `--force` | `cursor-agent create-chat` |
| opencode | `opencode` | `--auto` | chosen ID |

A trail that never got a message has nothing to resume, so restoring it starts the
agent fresh. trails refuses a YOLO launch as root for the two flags that also
bypass a sandbox.

</details>

<details>
<summary><b>Environment</b></summary>

| Variable | Default | Does |
|---|---|---|
| `TRAILS_ATTACH` | *(unset)* | `session` or `workspace`: where picking a trail lands, instead of guessing from the editor's variables |
| `TRAILS_RECENT_DAYS` | `10` | how far back closed trails are listed |
| `TRAILS_RECENT_MAX` | `5` | how many of them to show (`0` for none) |

</details>

<a id="trails-ls"></a>
<details>
<summary><b><code>trails ls</code> for scripts</b></summary>

Piped, `trails ls` prints one tab-separated line per row, `-` for an empty field,
the title last so a reader that takes the last field keeps working as columns are
added:

```text
life  state  session  agent  yolo  dir  id  when  workspace  trail  title
```

| Field | Values |
|---|---|
| `life` | `running` or `stopped` |
| `state` | `needs-you`, `your-turn`, `unknown`, `working` · `lost`, `closed` |
| `session` | the trail's session (`acme/checkout-3f9a`); for a lost one, the session it had; `-` for one that ended |
| `yolo` | `yolo` or `-` |
| `when` | when an ended trail ended (Unix time), else `-` |
| `workspace` | the trail's workspace |
| `trail` | its trail ID (`t3f9a`; `t` and eight hex digits for a trail started before 1.10), the same through a restore; `-` for one that ended |

`TRAILS_RECENT_MAX=0` skips the history, for a poll that wants running trails only.

</details>

<details>
<summary><b>The tmux lines</b> <code>trails keys</code> prints</summary>

```text
bind P display-popup -E -w 60% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }"
bind W display-popup -E -w 60% -h 50% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' ws || { echo; echo press enter to close; read -r _; }"
bind E run-shell "TRAILS_CLIENT=#{client_name} 'trails' edit"
bind ` run-shell "TRAILS_CLIENT=#{client_name} 'trails' shell"
bind N display-popup -E -w 60% -h 50% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' checklist"
bind K run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws prev"
bind J run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws next"
bind M run-shell "TRAILS_CLIENT=#{client_name} 'trails' map here"
bind A display-popup -E -w 70% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "env TRAILS_PICKER=all 'trails' || { echo; echo press enter to close; read -r _; }"
bind G run-shell "TRAILS_CLIENT=#{client_name} 'trails' diff"
bind H run-shell "TRAILS_CLIENT=#{client_name} 'trails' --keys"
bind R command-prompt -p "rename trail:" "run-shell \"TRAILS_CLIENT=#{client_name} 'trails' rename '%%'\""
set -g status-left-length 60
set -g status-right-length 80
set -g status-right "#{?@trails_window,…}#('trails' checklist --count '#{?@trails_dir,#{@trails_dir},#{pane_current_path}}')%H:%M "
set -g status-left "#{S/n:#{?@trails_workspace,…}}│ "
```

It prints trails' full path where these show `trails`, the full `status-left`
and `status-right` formats where they show `…`, and `bg=default` for
`bg=terminal` before tmux 3.8. Both status lines replace yours: set yours after
the `trails keys` line to keep them. Or paste only the lines you want, and paste again when they change.

**A workspace in two terminals.** Terminals on one tmux session share its current
window. For a second terminal that moves on its own, give it a session grouped
with the workspace's, which trails treats as the workspace:

```sh
tmux new-session -t acme -s 'acme~2' ; set destroy-unattached on
```

</details>

## How it works

[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) covers how workspaces and trails map
onto tmux, how status comes from the agents' hooks, how trails survive tmux dying,
and how the map and the editor borrow a trail's session without owning it. Key
decisions are in [docs/decisions/](docs/decisions/). Upgrading from an earlier
version: the [release notes](https://github.com/gunasekar/trails/releases) say
what changed.

## License

[MIT](LICENSE)
