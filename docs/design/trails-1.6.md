# trails 1.6: hooks, a diff, and who it is for

Status: implemented in 1.6.0. `trails hooks` and the reading of Claude's state file
went in 1.7 ([ADR 19](../decisions/0019-no-agents-files-read.md)).

Seven changes. The first is the large one and has an ADR of its own
([ADR 18](../decisions/0018-status-from-the-agents-hooks.md)); the fourth is on
trial and may not ship.

1. Status from the agent's hooks, for any agent
2. A side-by-side diff on a key
3. A "who it is for" section in the README
4. (Trial) a workspace that needs you, marked in the bar
5. The menu-bar plugin removed
6. Other cuts: what the size review found unused
7. Every running trail on one screen, a key away

Some of this borrows from
[tmux-claude-hatch](https://github.com/craftzdog/tmux-claude-hatch): its hooks as a
Claude Code plugin, and its statement of who it is for. What it does not borrow:
hatch reads Claude's state file, as trails already does, and its hooks only ring
a bell and refresh a cache. Hook-driven status for every agent is new to both.

## 1. Status from the agent's hooks

### `trails state`

```sh
trails state working | waiting | idle
```

- Finds the pane from `TMUX_PANE`. No `TMUX`, no pane, an unknown word: exit 0,
  silently.
- `tmux set-option -p -t "$TMUX_PANE" @trails_state <word>` and `@trails_state_at
  <epoch>`, one tmux call.
- No stdout, no stderr, always exit 0: a hook's output can land in the agent's
  transcript, and a failing hook is reported on every turn.
- Fast: it does nothing else. No config read, no `sessions` scan. Sourcing the
  script's top level must stay cheap for this path, so `state` is dispatched
  before anything that reads the config.

The pane is the agent's own: hooks run as the agent's children and inherit its
environment. A trail's pane dies with its agent, so the options never outlive it.

### Reading it

`classify` takes, per trail:

| | Source | Agents | Setup |
|---|---|---|---|
| 1 | `@trails_state` on the agent's pane | any with hooks | `trails hooks` |
| 2 | Claude's own file (`agent_state`), the newer of it and 1 | claude | none |
| 3 | unknown | | |

`@trails_state` comes back in the one `list-panes -a` that `sessions` already
makes, so step 1 costs nothing extra.

Unknown is a fourth state everywhere a state shows:

- picker and `ls`: `● ?` in grey, sorted after *your turn*, before *working*
- the map's pick: same rank
- `trails ls` TSV: `unknown`

### `trails hooks`

```sh
trails hooks AGENT            # print the hook config for AGENT, and where it goes
trails hooks                  # each configured agent: hooked, or not
```

Print-only: pasting the hooks in is the user's. An `--install` that merged them into
each agent's settings was built and taken out again in the size review: ~60 lines
of JSON merging for a paste done once per agent.

Each agent's mapping from its events to trails' three words. "Checked" means
against the installed version on the dev machine; the rest are from the agent's
docs and are confirmed before 1.6 ships.

| Agent | working | waiting | idle | Where | Checked |
|---|---|---|---|---|---|
| claude | `UserPromptSubmit`, `PostToolUse` | `Notification` (`permission_prompt`), `PreToolUse` (`AskUserQuestion`) | `SessionStart`, `Stop` | `~/.claude/settings.json`, or the Claude Code plugin in this repo | 2.1.309, plugin validated |
| codex | `UserPromptSubmit`, `PostToolUse` | `PermissionRequest` | `SessionStart`, `Stop` | `~/.codex/hooks.json`; trusted with `/hooks` | docs only, not installed |
| gemini | `BeforeAgent`, `AfterTool` | `Notification` | `SessionStart`, `AfterAgent` | `~/.gemini/settings.json` | docs only, not installed |
| copilot | `userPromptSubmitted`, `postToolUse` | (none) | `sessionStart`, `agentStop` | `~/.copilot/hooks/trails.json` | docs only, not installed |
| cursor | `beforeSubmitPrompt` | (none) | `stop` | `~/.cursor/hooks.json` | 2026.07.09 installed; reports say the CLI skips both, to test in use |
| opencode | `session.status` busy, `tool.execute.after` | `permission.asked` | `session.status` idle, `session.idle` | `~/.config/opencode/plugins/trails.js` | 2.0.25 installed; event names in its binary, plugin folder from its docs |

`PostToolUse` as *working* is what clears *waiting* once a permission is granted:
the tool runs, its hook fires, and the agent is back at work.

Where an agent has no *waiting* event, a hook still gives exact *working* and
*your turn*; a permission prompt reads as *working* until it is answered.

For Claude the repo carries a Claude Code plugin (`plugins/trails/` with
`.claude-plugin/marketplace.json` at the root; its `hooks/hooks.json` is what
`trails hooks claude` prints, and a test keeps them equal), so the install is:

```
/plugin marketplace add gunasekar/trails
/plugin install trails@trails
```

Every hook command is `trails state WORD 2>/dev/null || true`: trails by name, and
silent when it isn't on the hook's `PATH`.

An agent with no entry: the README's "Status" section names the three moments
(a prompt sent or a tool done, a question or a permission asked, a turn ended) and
the command for each.

### What goes

The screen check, with `AGENT_SETTLE`, `AGENT_ASK_RE` and the settle sleep. It was
first kept behind an opt-in `screen_check`, then cut in the size review: it guessed
where hooks know. Codex's state reader goes too, since its hooks say more.

### Tests

- `trails state` from a pane sets both options; from outside tmux, with an unknown
  word, or with no server, prints nothing and exits 0.
- The stub agent calls `trails state` as a hooked agent would; with `--no-hooks`
  it reads *unknown*, and each hook word reads as its state.
- Hook and Claude's file: the newer wins.
- `trails hooks` prints each agent's config, and the plugin's equals Claude's.
- The picker and `ls`, table and TSV, show `unknown`.

## 2. A side-by-side diff on a key

```sh
trails diff        # this codebase's changes, side by side
```

bound by `trails keys` to `prefix G` (unbound in tmux; `D` is choose-client and
`g` is taken in 3.8). A run-shell binding, so a `gui` diff opens no popup.

- **Which codebase:** the same rule as `trails edit`: the window you are on, then
  the pane's directory, then `$PWD` or `DIR`.
- **Where:** a popup over the workspace, 90% by 90%, since side by side wants the
  whole width. `q` closes it. Run again to see the changes since.
- **What:** the working tree against `HEAD`, staged and not, plus untracked files
  (each diffed against `/dev/null`), since agents make new files and `git diff`
  alone leaves them out. Nothing is staged to show them.
- **How:** a `diff` command in the config, run in the codebase:

  ```json
  "diff": "delta --side-by-side --paging=always"
  ```

  trails pipes the diff to it, so it should page: the popup closes when it exits.
  That is the default when delta is installed, else `less -R` on a coloured diff. A command that opens a window of its own
  (`"diff": "fork status"`, Fork's commit view on macOS) is run instead of piped
  to, and no popup opens: trails tells the two apart by `{ "command": ..., "gui": true }`,
  not by guessing.
  A third kind, `{ "command": ..., "pipe": false }`, finds the changes itself and
  runs in the popup: Neovim with codediff.nvim (`nvim -c 'CodeDiff --exit-on-close'`),
  started only when there are changes.

Tests: the popup's command for a codebase with a staged, an unstaged and an
untracked change shows all three; `"gui": true` runs the command in the codebase
and opens no popup.

## 3. Who it is for

A short section near the top of the README, after "What it's for":

> trails is for people who stay hands-on with their code. It keeps agents
> running and you beside them: the editor next to the agent, its diff a key away, a
> note for later. You read, review and write the code yourself, with agents doing a
> share of it, and you would rather have a small tool than a platform.
>
> It is not for running a swarm of agents and shipping what comes back unread, and
> it has no chat window of its own: the agent's interface is the agent's.

## 4. (Trial) the bar marks a workspace that needs you

With hooks in place this is cheap: `trails state waiting` or `idle` also sets
`@trails_wants` on the workspace session, and the bar's format shows a dot beside
a workspace that has one, cleared when you visit it. It overlaps with the menu
bar's notifications, so it ships only if it earns its place in use.

## 5. The menu-bar plugin removed

The SwiftBar plugin (`extras/swiftbar`), `trails swiftbar` and the renderer's menu-bar
icons go, superseding [ADR 8](../decisions/0008-ship-the-menu-bar-plugin.md). It polled
`trails ls -a` every 10 seconds, about 0.9 s a poll, for a view the workspace bar and
the picker already give, and it was macOS-only. `trails ls`'s TSV stays, for any
status bar, notifier or script to read. The Homebrew formula stops installing
`share/trails/swiftbar` and drops its caveat at the 1.6 release.

## 6. Other cuts

What a review of every feature against use on the dev machines found unused, or
built for the menu bar:

- **0.6 compatibility**: `trails-<project>` sessions and top-level records. None ran
  on either machine; 18 stale records did. With it, the 1.4 option spellings
  (`@trails_view`, `@trails_cell`, `@trails_companion`), kept "for one release".
- **`trails open` and `trails end`**, the menu bar's Resume and End. ctrl-x ends a
  trail; `trails restore` now forgets a record it can never bring back (its folder
  gone, or unreadable), naming the conversation, which stays in the agent's history.

Kept, though asked about: resuming ended conversations, notes, named trails, a
second terminal on a workspace, `ws list` / `ws of` / browse…, and the locale fix for
launchd jobs. That one was cut and put back: a tmux started with no locale garbles the
field separator, every running trail then reads as lost, and an automatic restore would
start each one twice.

## 7. Every running trail, a key away

A picker level, `all`: every running trail, in every workspace, with state and the
live preview, its codebase column `workspace/codebase`. Enter goes to the trail,
ctrl-x ends it wherever it runs. No "＋ new trail…" or "↩ resume old trails": both
belong to one codebase or workspace. `prefix A` opens it in a popup; ctrl-a on the
codebase, workspace, old and workspaces screens reaches it, and Esc goes back to
that screen (`TRAILS_FROM`), or closes it when `prefix A` opened it.

Also: `trails restore` and its automatic form, run whenever tmux starts (the opt-in
line `trails keys` prints, commented out), restore only the records of the tmux
server they run on (`server=` in the record). Without that, a second server started
with the same config read every trail of the first as lost and ran each conversation
twice.

## Decided

1. **Hook and file both present (Claude):** the newer wins, `@trails_state_at`
   against Claude's `statusUpdatedAt`.
2. **Agents with no *waiting* event:** *working* through a permission prompt.
3. **The diff key:** `G`.
4. **No hooks:** an agent nothing speaks for is *unknown*; the screen is not read.
