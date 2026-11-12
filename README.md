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

![Earlier Trails tour: the picker, a trail, the old side-by-side diff and shell layout, workspaces, and the map](assets/trails.gif)

The recording shows an earlier layout; the diff now opens in a popup and the shell
shortcut opens a native tmux floating pane.

## Its opinions

- **One machine holds the agents.** Everything else connects to it: a second
  laptop, an editor over ssh, a phone. Close the lid, come back, and the
  conversation is where you left it, mid-turn.
- **Work grouped the way you think of it.** A workspace is a company, a client,
  or "personal": unrelated repos together, and one ssh connection reaches them all.
- **The agent writes, you stay hands-on.** The editor, a shell and the diff of
  what the agent changed are each a key away in the trail window:
  read the code, run it, and review every change before it lands, without leaving
  the trail.
- **An agent is known by its config and its hooks, never its files.** Every agent
  is equal, and an agent's release can't break trails.
- **tmux does the work.** A trail is a tmux session on trails' own socket
  (`tmux -L trails` by default), so anything that speaks tmux can reach it, and
  uninstalling trails leaves ordinary tmux behind.

It is not for running a swarm of agents and shipping what comes back unread, and
it has no chat window of its own: the agent's interface is the agent's.

## Install

```console
brew install gunasekar/tap/trails
```

Or put [`bin/trails`](bin/trails), one POSIX `sh` script, anywhere on your
`PATH`. It needs tmux 3.3 or later, fzf and jq, and at least one agent CLI.
[Hunk](https://hunk.dev) is required for the live diff,
[lazygit](https://github.com/jesseduffield/lazygit) for `prefix G`, and `curl` keeps the
editor picker's preview live. Native floating panes require tmux 3.8 or later.

## Quickstart

1. **Put trails on tmux's keys.** One line in `~/.config/tmux/tmux.conf` (or
   `~/.tmux.conf`) loads them from the installed trails, so they follow every
   upgrade; reload tmux after adding it. Trails uses its own tmux socket
   (`trails` by default), and the same conf is read when that server starts.
   Every other tmux server reads it too, but takes none of trails' keys or its
   status line, so a plain `tmux` of yours stays as you configured it:

   ```tmux
   run-shell "trails tmux-config | tmux source-file -"
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
   trails ▸ █   # enter: go · ctrl-s: star · ctrl-r: rename · ctrl-x: end · ctrl-e: editor · ?: keys · esc: close
   ▌ ＋ new trail…  in checkout (acme)
     acme  3 trails · 1 needs you · 1 your turn · 1 lost
       1 checkout-3f9a  needs you   4m  checkout  claude · yolo  Add idempotency keys to payment retries
       2 checkout-b07e  your turn  12m  checkout  claude         Fix the flaky cart-total test
       3 orders-c41a    working         orders    codex          Migrate orders to Postgres 17
         checkout-9d2e  lost            checkout  claude         Spike: replay Stripe webhooks
     ↩ resume old trails  (3 ended)
   ```

From then on it is keys: `prefix P` for every trail, `E` for the
editor beside the agent, `H` for its diff, `G` for lazygit. `prefix ?` lists them all, trails'
as `trails: …`. The
everyday loop, and every other way trails is used, are in
[docs/scenarios.md](docs/scenarios.md).

## Keys

In tmux, after `prefix`, from `trails tmux-config`:

| Key | Does |
|---|---|
| `P` | the [picker](#the-picker), in a popup: every workspace with its trails and windows |
| `S` | star the trail you are on, or unstar it ([stars](#stars)) |
| `F` | to the starred trail that most wants you; again, the next one |
| `E` | the editor beside the agent; again, back where you were |
| `` ` `` | a new floating pane (tmux 3.8), the same as `prefix *` |
| `G` | lazygit in a popup ([the diff](#the-editor-a-shell-and-the-diff)) |
| `H` | the live Hunk diff in a popup ([the diff](#the-editor-a-shell-and-the-diff)) |
| `N` | the codebase's [checklist](#checklist) |
| `M` | the [map](#the-map): up to four trails side by side |
| `K` `J` | the previous and next workspace |
| `R` | rename the trail you are on ([named trails](#named-trails)) |

In the picker:

| Key | Does |
|---|---|
| typing | filter the rows |
| `enter` | go there: a trail, a window, a session; on a workspace, a new trail there; bring back a lost trail, resume a closed one, or start an agent |
| `ctrl-s` | star the trail under the cursor, or unstar it |
| `ctrl-r` | rename the trail under the cursor; an empty name takes it away |
| `ctrl-x` | end a running trail, close a tool window, or forget a lost or closed one |
| `ctrl-e` | the editor for the row's codebase |
| `ctrl-/` | in an editor's picker and the old trails: show or hide the preview, the trail's screen kept live |
| `ctrl-n` | a new workspace; in the agents, name the trail you are about to start |
| `tab` | in the agents and the old trails: toggle YOLO (run everything unconfirmed) |
| `?` | the keys and what the states mean |
| `esc` | close it; from the agents or the old trails, back to it |

Every trails key is a capital letter, but `` ` `` for a floating pane, so tmux's own
keys stay tmux's: `?` still lists every binding, trails' among them as
`trails: …`, and `(` and `)` still cycle through every session. `P`, `S`, `F`,
`N`, `G`, `R`, `J` and `K` are unbound in tmux's defaults; `E` replaces spreading the panes out evenly (still
`:select-layout -E`), and `M` clearing the marked pane (still `prefix m` on it). A
line after the `trails tmux-config` one that binds the same key wins.

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
├─ checkout-3f9a        ← shows acme/checkout-3f9a; the editor beside it
├─ checkout-b07e        ← shows acme/checkout-b07e
└─ billing·nvim         ← the editor alone, nothing running in billing
acme/checkout-3f9a      ← a trail: claude in ~/code/checkout, its ID t3f9a
acme/checkout-b07e      ← another, in the same codebase
```

The status line is tmux's own: the workspace you are in as `[acme]`, its windows
(the trails, and any window of yours), and at the right what the current trail is
working on, then the checklist's count before the clock:

```text
[acme] 1:checkout-3f9a  2:checkout-b07e*  3:billing·nvim   Fix the flaky cart-total test · ☑ 2/5 · 14:05
```

A click on `[acme]` opens the picker, as `prefix P` does. Closing the last
window of a session moves the terminal to a workspace, or one of your own
sessions, instead of out of tmux. Windows, panes and sessions you make yourself
are plain tmux: trails never lists, renames or restores them.

#### Stars

`prefix S` stars the trail you are on, or unstars it (`ctrl-s` in the picker, or
`trails star [TRAIL]`): a trail you want to see through, whatever state it is in.
The star is kept in the trail's record, so it survives tmux going down and
`trails restore`. A starred trail:

- has ★ before its number in the picker and in the window list;
- is where `prefix F` (`trails next`) takes you: the starred trail that most wants
  you, one whose bell you haven't seen first, then needs you before your turn,
  then the longest waiting; pressed again, the next one;
- can be the only kind that notifies: `"notify": { "only": "starred" }`
  ([notifications](#notifications)).

`trails tmux-config` prints bindings, hooks, status and neutral theme slots
`@window_label_prefix`, `@window_label_style` and `@window_label_suffix` for the
star and bell. Load it after the theme. Themes
that expand those slots can show the indicators without Trails-specific formats.

**A bell for what wants you.** A trail blocked on a question, or done with a turn,
rings tmux's bell in its window: tmux marks the window (stock tmux shows `!` after
its name), your terminal plays its bell, and the mark goes when you open the
window. After `[acme]`, one bell and a count stand for the trails that want you in
the workspaces you are not in, and nothing at all when none do:

```text
[acme] 󰂚 2 1:checkout-3f9a  2:checkout-b07e!  3:billing·nvim   Fix the flaky cart-total test · 14:05
```

The bell is a Nerd Font glyph; set another, or none, in the config:
`"alerts": { "glyph": "*" }`, or `"alerts": false`. A theme whose window format
shows no tmux flags can show the same bell after a window's name with
`#{E:@trails_bell}`, and colour the name as the bell's with `#{E:@trails_bell_style}`
before it (a theme that sets the name's colour itself keeps tmux's own bell style
from showing), for example
`set -g window-status-format "#{E:@trails_bell_style}#I:#W#{E:@trails_bell}"`.
A starred trail's ★ is `#{E:@trails_star}`, for the start of a theme's window
formats, before the window's number. It leaves the colour yellow, so set yours
after it: `#{E:@trails_star}#[fg=#686868]#I:#W`. tmux's stock formats get it from
`trails tmux-config`; a theme's are left as they are.

The task is the title the agent gives its terminal, Claude's summary of the
conversation, read as it changes and cut at 40 characters; a named trail has its
name in its window instead.

Plain tmux moves you around too: `tmux a -t acme` is the workspace and
`tmux a -t acme/checkout-3f9a` one trail. An unnamed trail's session and window
carry its ID, four hex digits that stay with it through a restore and are never
another trail's while it lives.

### The picker

`trails`, `prefix P` or a click on `[acme]` opens one list of everything worth
going to on trails' server: each workspace, the one you are in first, with its
trails, its lost trails and its windows in the status line's order; the tmux
sessions you made yourself; and the trails that ended. The cursor starts on
where you are. It is for starting a trail and going to one: the map has its own
key (`prefix M`), and the row says what a trail is doing, with no preview:

```text
trails ▸ █                    # enter: go · ctrl-s: star · ctrl-r: rename · ctrl-x: end · …
▌ ＋ new trail…  in checkout (acme)
  acme  2 trails · 1 needs you · 1 lost
    1 checkout-3f9a  working          checkout  claude          Fix the flaky cart test
  ★ 2 payments       needs you   4m   checkout  claude · yolo   Which retry budget?
      checkout-b07e  lost             checkout  claude          Split the totals job
    3 notes          yours
  personal  1 trail · 1 your turn
    1 blog           your turn  12m   blog      codex           Draft the release post
  ── yours ──
    scratch
  ↩ resume old trails  (7 ended)
```

A trail's row has its window number and ★ when starred, its state, how long it
has waited on you, its codebase, its agent and what it is working on:

| State | Means | Enter |
|---|---|---|
| needs you | the agent is asking you something | go to it |
| your turn | it finished its turn | go to it |
| working | it is busy | go to it |
| unknown | nothing says: [set up its hooks](#hooks-for-each-agent) | go to it |
| lost | tmux died under it: a reboot, a crash, `kill-server` | bring it back on its conversation |
| closed | it ended in the last 10 days (in the old trails) | resume it, in the mode it last ran in |

Enter on a workspace starts a trail there: its codebases, then the agent, the
same as **＋ new trail…** does for the workspace you are in (its trails and
windows are rows of their own). **＋ new trail…** picks a codebase of the
workspace you are in, the cursor on the one you are in, then the agent to
start, with Tab for YOLO and ctrl-n to name the trail. **↩ resume old trails**
lists every workspace's trails that ended, from trails' own history of the newest
100. In an editor's terminal the picker is that codebase's trails alone
([from an editor](#from-an-editor)).

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
| claude | the [Claude Code plugin](integrations/agents/claude), or `~/.claude/settings.json` | yes |
| codex | the [Codex plugin](integrations/agents/codex), or `~/.codex/hooks.json`; trust with `/hooks` | yes |
| gemini | `~/.gemini/settings.json` | yes |
| copilot | `~/.copilot/hooks/trails.json` | no hook: reads *working* through a prompt |
| cursor | the [Cursor plugin](integrations/agents/cursor), or `~/.cursor/hooks.json` | no hook: reads *working* through a prompt |
| opencode | `~/.config/opencode/plugins/trails.js` | yes |

Each status command ends in `2>/dev/null || true`: silent, never failing a turn,
and inert outside tmux. Cursor pre-hooks also return the JSON response its protocol
requires to let the prompt or tool call proceed. With `--id`, a trail follows its conversation through
`/resume` and `/clear`, and a restore brings back the one it is in now. A conversation that runs
outside the trail's pane, such as a fork an agent sends to the background, is not
the trail's: the trail keeps its own, and trails leaves the fork alone. To keep it in
a trail, start one and pick the conversation up there with the agent's own resume.

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

Install the plugin from a local checkout (run these in the Trails repository):

```sh
codex plugin marketplace add .
codex plugin add trails@trails
```

Then open `/hooks` in Codex, review and trust the Trails hooks, and start a new
session. Remove any manually installed Trails handlers first so they do not run
twice. Keep unrelated hooks. The plugin is distributed through this repository;
it is not listed in the public OpenAI plugin directory.

For manual setup, copy [integrations/agents/codex/hooks/hooks.json](integrations/agents/codex/hooks/hooks.json) to `~/.codex/hooks.json`.
If that file already exists, append these handlers to its matching event arrays
instead of replacing it. Make sure `trails` is on the hook's `PATH`. Codex runs a
hook only once you have reviewed and trusted it: `/hooks` in codex. Start a new
session after trusting the hooks to run `SessionStart`.

These hooks follow [Codex's lifecycle events](https://learn.chatgpt.com/docs/hooks):
prompts and pre/post tool calls mark working, permission requests mark waiting,
and session start, completion, or interruption mark idle.

```json
{
  "hooks": {
    "SessionStart": [{"hooks": [{"type": "command", "command": "trails state idle --id \"$(jq -r '.session_id // empty')\" --agent codex 2>/dev/null || true", "statusMessage": "Trails: session ready"}]}],
    "UserPromptSubmit": [{"hooks": [{"type": "command", "command": "trails state working --agent codex 2>/dev/null || true", "statusMessage": "Trails: prompt started"}]}],
    "PreToolUse": [{"hooks": [{"type": "command", "command": "trails state working --agent codex 2>/dev/null || true", "statusMessage": "Trails: tool started"}]}],
    "PostToolUse": [{"hooks": [{"type": "command", "command": "trails state working --agent codex 2>/dev/null || true", "statusMessage": "Trails: tool finished"}]}],
    "PermissionRequest": [{"hooks": [{"type": "command", "command": "trails state waiting --agent codex 2>/dev/null || true", "statusMessage": "Trails: waiting for approval"}]}],
    "Stop": [{"hooks": [{"type": "command", "command": "trails state idle --id \"$(jq -r '.session_id // empty')\" --agent codex 2>/dev/null || true", "statusMessage": "Trails: turn finished"}]}],
    "Interrupt": [{"hooks": [{"type": "command", "command": "trails state idle --agent codex 2>/dev/null || true", "statusMessage": "Trails: turn interrupted"}]}]
  }
}
```

Run Codex in trails as `codex --no-daemon` (the built-in agent does). Without it,
the Codex TUI hands its turns to a shared background server, and the hooks run
there, with the environment of whichever terminal first started that server: not
the trail's pane, so trails never hears from them. In an agent of your own config,
add `--no-daemon` to its `program`.

Codex picks its own conversation IDs, and passes each hook a JSON object on stdin
with `session_id` among it, the ID `codex resume` takes. `SessionStart` and `Stop`
hand it to trails, so a Codex trail comes back after tmux dies: `SessionStart` for
a new session and after `/new` or a resume, `Stop` for a session that started
before the hooks were trusted. After upgrading from hooks without `--id`, review
them again in `/hooks`.

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

The native plugin is in [integrations/agents/cursor](integrations/agents/cursor). Load it from
a local checkout:

```sh
cursor-agent --plugin-dir /absolute/path/to/trails/integrations/agents/cursor
```

`--plugin-dir` applies to that invocation. To use it for trails launched by the
picker, run `trails config` and append the same flag and absolute path to the
Cursor agent's `program`, keeping its other fields. Trails splits `program` on
spaces, so use a checkout path without spaces. A Cursor marketplace listing is
not published yet. Local loading does not download plugin updates; update the
checkout to pick up changes. See the [plugin setup](integrations/agents/cursor/README.md).

Use the plugin or manual hooks, not both. Keep unrelated hooks when removing old
Trails handlers. Verify completion status with `trails ls` after an interactive turn. In a live
headless check, tool hooks fired but prompt-submit and completion hooks did not;
manual setup uses the same events and cannot fix skipped callbacks. This CLI also
skips `sessionStart` with `--resume`, which Trails uses after creating a chat, so
a new Cursor trail may stay unknown until a later hook fires.

For manual setup, copy [integrations/agents/cursor/hooks/hooks.json](integrations/agents/cursor/hooks/hooks.json) to `~/.cursor/hooks.json`.
If that file already exists, append these handlers to its matching event arrays
instead of replacing it; keep `version: 1`. Make sure `trails` is on the hook's
`PATH`, then restart Cursor CLI. These are global hooks and also apply to the editor.

The [Cursor hooks](https://cursor.com/docs/hooks) mark prompts and pre/post tool
calls working, and session start or completion idle. Shell and MCP hooks cover
clients that skip generic tool events. There is no documented permission-request
event, so a permission prompt still reads working. Older CLI versions have skipped
`beforeSubmitPrompt` and `stop`: check with `trails ls` during and after a turn.

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{"command": "trails state idle --agent cursor-agent 2>/dev/null || true"}],
    "beforeSubmitPrompt": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true; printf '%s\\n' '{\"continue\":true}'"}],
    "preToolUse": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true; printf '%s\\n' '{\"permission\":\"allow\"}'"}],
    "postToolUse": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true"}],
    "beforeShellExecution": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true; printf '%s\\n' '{\"permission\":\"allow\"}'"}],
    "afterShellExecution": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true"}],
    "beforeMCPExecution": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true; printf '%s\\n' '{\"permission\":\"allow\"}'"}],
    "afterMCPExecution": [{"command": "trails state working --agent cursor-agent 2>/dev/null || true"}],
    "stop": [{"command": "trails state idle --agent cursor-agent 2>/dev/null || true"}]
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
| codex | 0.165.0: plugin install and discovery checked; trusted user hooks reported working in a live trail; other transitions not all checked | `session_id` on stdin, from the 0.166.0 binary's hook input |
| gemini | its docs only, not installed | not yet |
| copilot | its docs only, not installed | not yet |
| cursor | 2026.10.22-27dcf5f: plugin start and tool/shell events fired; headless prompt/stop skipped; resume skips start; interactive completion unverified | not yet |
| opencode | 2.0.25 installed; event names in its binary | not yet |

</details>

### Notifications

When a trail needs you, or ends a turn that ran 30 seconds or more, a sound
plays, whatever app or terminal is in front, on the machine running the agents:
`afplay` on macOS, `canberra-gtk-play` (or `paplay`) on Linux. Which trail it was,
the bell on the status line says. It rides on the
[hooks](#status-from-the-agents-hooks): a trail without them stays quiet. There
is no popup: up to 1.20 notifications were escape sequences to the terminal,
which depended on the emulator, and the operating system's would show as Script
Editor's, not trails'
([ADR 28](docs/decisions/0028-a-tmux-native-server-that-tells-you-what-waits.md)).

```json
"notify": {
  "on": ["waiting", "idle"],
  "idle_after": 30,
  "show": "unfocused",
  "sound": "system",
  "only": "all"
}
```

| Key | Means |
|---|---|
| `on` | the states that sound: `waiting` (needs you), `idle` (your turn) |
| `idle_after` | your turn sounds only after a turn this many seconds long; `0` for every turn |
| `show` | `unfocused`: not while a focused terminal shows that trail's window; `always` |
| `sound` | `system` (on macOS, Blow), a sound's name (`Tink`, `Pop`, … from `/System/Library/Sounds` or `~/Library/Sounds`), a file's path, or `silent` |
| `only` | `all`, or `starred`: only the [starred](#stars) trails; the rest still ring their bell |

`"notify": false` turns it off. Each key left out keeps its default. `unfocused`
needs tmux to know which terminal has focus, `set -g focus-events on`; without
it, the sound always plays.

### The editor, a shell and the diff

`prefix E` opens your editor (`$EDITOR`, nvim if unset) beside the agent, in the
codebase. Press it again to return to the previous pane. The agent takes 40% of
the window and the editor 60%. When the trail ends, the editor stays in a
window of its own. `trails edit` does the same from a shell.

`` prefix ` `` creates a native tmux floating pane, just like `prefix *` on tmux
3.8. Run a shell or any other command there; `exit` or Ctrl-D at the shell prompt
closes it. Each invocation creates a new pane. On older tmux versions that lack
`new-pane`, use your usual tmux split keys instead.

`prefix H` opens [Hunk](https://hunk.dev) in a large popup over the window.
It watches the codebase's changes live and shows whole changed files side by
side, including while the editor is open. Quit Hunk with `q` to close the
popup. Hunk and a Git repository are required; its appearance follows your Hunk
configuration. `trails diff [DIR]` runs the same live viewer in the terminal.
The former Trails `diff` configuration is no longer used.

`prefix G` opens [lazygit](https://github.com/jesseduffield/lazygit) in the same
popup, in the same codebase, to stage, commit and push. Quit it with `q`.
`trails git [DIR]` runs it in the terminal.

If lazygit, Hunk or `$EDITOR` (nvim by default) isn't installed, or the codebase
isn't a Git repository, `prefix G`, `H` and `E` say so on tmux's message line
and open nothing. tmux runs them with the server's `PATH` and `EDITOR`, which a
server started by launchd may not share with your shell.

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

Its session is `acme/payments`, its window and its row in the picker
`checkout·payments`, and the agent gets the name too where its config says how
(Claude runs with `--name payments`). An unnamed trail is its codebase and its ID,
`checkout-3f9a`.
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
starts, add the line `trails tmux-config` offers for it:

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
unit on Linux. It starts tmux on the configured socket (`trails` by default),
brings back the lost trails without waiting for a terminal, and starts tmux
again after a crash or a `kill-server`. The server takes your login shell's
environment, so put the `PATH` your agents need in `~/.zprofile` or `~/.zshenv`
(or bash's `~/.bash_profile`), not only in `~/.zshrc`. `brew services stop trails`
stops it, and with it every trail; they come back as lost, as after a reboot.
With the service installed and no server up, `trails` asks the service to start
one rather than starting it in your terminal. A server on that socket started
some other way (the service stopped, a `tmux -L trails` of your own) is not
guarded: the service waits for it to go, and the attached terminals are told,
once an hour, until it does. `tmux -L trails kill-server` hands the agents over
to the service, which restores them. Its log is
`$(brew --prefix)/var/log/trails-boot.log`.

### The map

`prefix M` (or `trails map 4`) puts up to four trails side by side in one window,
across workspaces, each a live view you can type into; on it, the status line shows
`[▦ map]`. `C-b d` leaves them all running.

![prefix M: trails from two workspaces picked into the map, four agents at work side by side, and the map in the status line beside the workspaces](assets/map.gif)

### From an editor

Any editor that can run a command in a terminal can run `trails`, and every
editor and shell sees the same trails. In an editor's terminal, picking a trail
attaches to it alone, so the panel shows that one trail.

- **VS Code** (and Cursor): a terminal profile, `"trails": { "path": "/bin/zsh", "args": ["-lc", "exec trails"] }`
  under `terminal.integrated.profiles.osx`, then pick **trails** from the
  new-terminal menu. Or use
  [PTYrig](https://marketplace.visualstudio.com/items?itemName=ptyrig.ptyrig)
  with `"ptyrig.command": "trails"` for **Ctrl+\** hide/show and
  **Ctrl+Shift+\** new session.
- **Zed:** `"terminal_init_command": "exec trails"` under `agent`. Over ssh it
  runs on the host, where tmux keeps the agent alive across disconnects.
- **Neovim:** a terminal running `trails` in a side panel.

trails tells an editor's terminal by the variables editors set (`NVIM`,
`ZED_TERM`, `TERM_PROGRAM`); `TRAILS_ATTACH=session` or `=workspace` settles it.

Terminal titles use `agent · activity`, or `agent* · activity` in YOLO mode.
For example: `codex* · Fixing login bug`. The activity follows the title published
by the agent; before that, Trails uses its current directory. The `*` is a
compact display marker; picker labels and stored launch modes retain their
existing YOLO representation. Existing tmux sessions keep the title format they
were created with until recreated; their directory fallback is still recognized.
Editors can follow these standard terminal titles
without a Trails-specific reporting hook or extension.

## Commands

| Command | Does |
|---|---|
| `trails` | the picker: every workspace, the one you are in first |
| `trails ws [NAME]` | the picker, or go to workspace `NAME` |
| `trails ws list` / `of [DIR]` / `add NAME [DIR]` / `next`, `prev` | the workspaces; the one `DIR` belongs to; add `DIR` to `NAME`; the next or previous running one |
| `trails new NAME [AGENT]` | start a trail named `NAME`, `-y` for YOLO |
| `trails star [TRAIL]` / `next` | star the trail you are on, or `TRAIL`; to the starred trail that most wants you |
| `trails rename [TRAIL] NAME` | name the trail you are on, or `TRAIL` (its ID); `''` takes its name away |
| `trails edit [DIR]` | the editor beside the agent |
| `trails diff [DIR]` | the live Hunk diff; `prefix H` opens it in a popup |
| `trails git [DIR]` | lazygit; `prefix G` opens it in a popup |
| `trails checklist [DIR]` / `note TEXT` | the checklist; add an item |
| `trails ls [-a \| DIR]` | the trails, here, in `DIR` or everywhere |
| `trails restore` | bring back every lost trail |
| `trails boot` | start tmux and the lost trails, for `brew services start trails` |
| `trails server [NAME]` | the tmux socket trails is on, or move its trails to `NAME` once the old server is stopped |
| `trails map [N \| new]` | trails side by side in one window |
| `trails tmux-config` | tmux bindings, status, hooks and optional theme indicators |
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
  "server": "trails",
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
| `server` | tmux socket name (`tmux -L NAME`). Empty means `trails`. A missing key means `trails` too, except an upgrade that still has records on the ordinary server pins `"default"` once. Use `default` to stay there. To move: `brew services stop trails`, `trails server trails`, `brew services start trails`; the trails come back on their conversations |
| `workspaces` | see [Workspaces](#workspaces) |
| `data` | a folder for each codebase's checklist; `.trails/checklist.md` in the codebase without it |
| `map` | `two` (`side`, `stacked`, `auto`) and `layout` (a tmux layout for three or more) |
| `notify` | the operating system's notifications: see [Notifications](#notifications) |

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
| `TRAILS_SOCKET` | *(config `server`)* | tmux socket name; overrides `server` in the config (empty still means `trails`) |
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
<summary><b>The tmux lines</b> <code>trails tmux-config</code> prints</summary>

```text
bind -N "trails: every trail, the picker" P if -F "#{e|>=:#{client_width},217}" { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 60% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 60% -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } { if -F "#{e|>=:#{client_width},134}" { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 130 -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 130 -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 97% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 97% -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } }
bind -N "trails: the picker, on a click on [session]" -n MouseDown1StatusLeft if -F "#{e|>=:#{client_width},217}" { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 60% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 60% -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } { if -F "#{e|>=:#{client_width},134}" { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 130 -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 130 -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } { if -F "#{e|>=:#{client_height},29}" { display-popup -E -w 97% -h 70% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } { display-popup -E -w 97% -h 95% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' || { echo; echo press enter to close; read -r _; }" } } }
bind -N "trails: star this trail, or unstar it" S run-shell "TRAILS_CLIENT=#{client_name} 'trails' star"
bind -N "trails: the starred trail that most wants you" F run-shell "TRAILS_CLIENT=#{client_name} 'trails' next"
bind -N "trails: the editor beside the agent" E run-shell "TRAILS_CLIENT=#{client_name} 'trails' edit"
bind -N "trails: a floating pane" ` new-pane
bind -N "trails: this codebase's checklist" N display-popup -E -w 60% -h 50% -s bg=terminal -S bg=terminal,fg=brightblack "'trails' checklist"
bind -N "trails: the previous workspace" K run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws prev"
bind -N "trails: the next workspace" J run-shell "TRAILS_CLIENT=#{client_name} 'trails' ws next"
bind -N "trails: the map" M run-shell "TRAILS_CLIENT=#{client_name} 'trails' map here"
bind -N "trails: lazygit in a popup" G run-shell "TRAILS_CLIENT=#{client_name} 'trails' git"
bind -N "trails: the live diff in Hunk" H run-shell "TRAILS_CLIENT=#{client_name} 'trails' diff"
bind -N "trails: rename this trail" R command-prompt -p "rename trail:" "run-shell \"TRAILS_CLIENT=#{client_name} 'trails' rename '%%'\""
set -g status-left-length 40
set -g status-right-length 80
set -g status-right "#{?@trails_window,…}#('trails' checklist --count '#{?@trails_dir,#{@trails_dir},#{pane_current_path}}')%H:%M "
set -g status-left "[#{?@trails_map,▦ map,#{session_name}}] #{?…}"
set -g @trails_bell "#{?window_bell_flag,#[fg=yellow] 󰂚,}"
set -g @trails_bell_style "#{?window_bell_flag,#[fg=yellow],}"
set -g @trails_star "#{?@trails_starred,#[fg=yellow]★ ,}"
%if "#{==:#{E:window-status-format},#I:#W#{?window_flags,#{window_flags}, }}"
set -g window-status-format "#{?@trails_starred,#[fg=yellow]★#[default] ,}#I:#W#{?window_flags,#{window_flags}, }"
%endif
%if "#{==:#{E:window-status-current-format},#I:#W#{?window_flags,#{window_flags}, }}"
set -g window-status-current-format "#{?@trails_starred,#[fg=yellow]★#[default] ,}#I:#W#{?window_flags,#{window_flags}, }"
%endif
set -g detach-on-destroy no-detached
run-shell -b "'trails' --hold >/dev/null 2>&1"
set-hook -g "alert-bell[42]" "run-shell -b \"'trails' --wants >/dev/null 2>&1\""
set-hook -g "session-window-changed[42]" "run-shell -b \"'trails' --wants >/dev/null 2>&1\""
set-hook -g "client-session-changed[42]" "run-shell -b \"'trails' --wants >/dev/null 2>&1\""
set-hook -g "window-unlinked[42]" "run-shell -b \"'trails' --wants >/dev/null 2>&1\""
set -g @window_label_prefix '#{E:@trails_star}'
set -g @window_label_style '#{E:@trails_bell_style}'
set -g @window_label_suffix '#{E:@trails_bell}'
```

It prints trails' full path where these show `trails`, the full `status-left`
and `status-right` formats where they show `…`, and `bg=default` for
`bg=terminal` before tmux 3.8. Both status lines replace yours: set yours after
the `trails tmux-config` line to keep them. Or paste only the lines you want, and paste again when they change.

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
