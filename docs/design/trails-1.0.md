# trails 1.0: design

Status: draft · 2026-10-16

trails 1.0 groups agent sessions into workspaces you define and keeps every one
reachable from any editor. The features are specific to that use case. The
behaviour is plain tmux, so a tmux user never meets anything unfamiliar.

## Principles

Every feature passes one test: uninstall trails, and everything left is
ordinary tmux that still makes sense.

1. **Plain tmux objects.** A workspace is a session, a trail is a window, a
   layout is panes. Each shows in `tmux ls` and `choose-tree` under a readable
   name, and plain tmux commands drive it.
2. **No default key bindings.** trails binds nothing. `trails keys` prints
   suggested lines for tmux.conf, to paste or ignore.
3. **Never touch the user's tmux.conf or options.** trails sets only
   `@trails_*` user options, and only on what it created.
4. **Never rearrange.** trails creates and names windows. It never moves,
   renames or closes one the user arranged. Config changes apply to new and
   restored trails.
5. **Nothing hidden.** Every session trails makes has a name that says what it
   is, and the docs say why it exists.
6. **Native first.** Switching workspaces is `switch-client`, browsing is
   `choose-tree`. trails' picker is a filtered view over the same objects,
   never a parallel world.
7. **Leave no residue.** No empty sessions, no placeholder windows: a session
   exists while something runs in it.

The features are specific to this use case (agents, workspaces, editors over
SSH). The behaviour is what a tmux user already expects.

## Requirements

Nine requirements. R6 is a bug in 0.6 against the README's own promise; R7 to
R9 are new.

| ID | Requirement |
| --- | --- |
| R1 | One machine holds code and agents (probochs); others are thin clients over SSH (airbochs) |
| R2 | One SSH connection carries several workspaces, and you move between them without reconnecting |
| R3 | An agent session survives a closed editor, a dropped connection, a closed laptop |
| R4 | The same agent session is reachable from any editor (nvim, VS Code, Zed) or a terminal, from several at once |
| R5 | No editor owns an agent session; an editor is a view onto it |
| R6 | R3 to R5 hold however you got there: a plain shell, inside tmux, or an editor inside tmux |
| R7 | Agent first: the agent is the primary unit, and the editor is brought up beside it when wanted |
| R8 | A workspace is a user-chosen set of codebases, related or not; trails never infers it from the directory layout |
| R9 | Editors reach the machine remotely (Zed over SSH, VS Code Remote-SSH); opening trails in one shows exactly one trail |

**Why R6 is a bug.** Inside tmux, 0.6 runs the agent bare in the current pane
(ADR 1). From nvim inside tmux, that agent gets no `trails-*` session, so no
other editor can reach it, and "every one of them lands on the same sessions"
is false.

**Worked example for R8.** One user groups code by the company it belongs to,
and git already switches identity per folder
(`includeIf "gitdir:~/workspace/lattiq/"`). Each company is a workspace of
unrelated repos:

```text
~/workspace/
├─ lattiq/      53 repos   → workspace lattiq
├─ prcpnt/                 → workspace prcpnt
├─ padnam/                 → workspace padnam
└─ gunasekar/   10 repos   → workspace personal
~/.dotfiles, ~/.dotfiles-private → workspace personal
```

This layout is one way to fill R8, not a rule: another user lists repos by
hand, wherever they live.

## Model

A workspace is a tmux session, a trail is a window in it, and each trail's
window is also linked into a small session of its own that editors attach to.

| Term | Means | tmux |
| --- | --- | --- |
| Codebase | one directory; a git worktree is its own codebase | none |
| Trail | one agent working in one codebase | a window in its workspace session |
| Companion | the editor or a shell for one codebase | a window in its workspace session |
| Workspace | a user-chosen set of codebases | a session, named after the workspace |
| Editor view | what an editor attaches to: one trail, nothing else | a session holding only that trail's window, linked |
| Layout | side-by-side views (the map, agent beside editor) | panes, in a window no editor attaches to |

What `tmux ls` and `choose-tree` show:

```text
lattiq                  ← workspace
├─ augur·claude         ← trail
├─ augur·claude-2       ← another trail, same codebase
├─ augur·nvim           ← companion
└─ ledger·codex
lattiq/augur            ← editor view: augur·claude, linked
lattiq/augur-2          ← editor view: augur·claude-2, linked
lattiq/ledger           ← editor view: ledger·codex, linked
```

**Why editor views exist.** Every client of a session shares its current
window, so an editor attached to `lattiq` would follow whatever window you
browse to. A window can belong to several sessions (`link-window`), so each
trail's window is linked into its own session: the editor sees one trail, and
the workspace session moves freely. They are plain sessions, named
`<workspace>/<codebase>[-N]`, visible and documented (principle 5).

Verified on tmux 3.8 in a throwaway server: the linked window is one window in
both sessions; each session keeps its own current window; when the agent
exits, the window leaves both and the editor view closes with it
(principle 7). A `/` in a session name works with `has-session -t =name`.

**Agent windows hold one pane.** A split in a trail's window would show in
every editor attached to it, so layouts live in windows of their own.

## Workspaces

Workspaces are declared in `~/.config/trails/config.json`. The config decides
what trails lists, never where a trail may run.

```json
"workspaces": {
  "lattiq": {
    "root": "~/workspace/lattiq",
    "codebases": ["~/workspace/lattiq/*"]
  },
  "personal": {
    "codebases": ["~/workspace/gunasekar/*", "~/.dotfiles", "~/.dotfiles-private"]
  }
}
```

- **`codebases`** are paths or globs. A glob picks up a newly cloned repo with
  no edit.
- **`root`** (optional) is where a workspace's new windows open when no
  codebase applies, and where browsing for another directory starts; else
  `$HOME`.
- **No `workspaces` key:** one workspace, `default`, holds everything, and
  trails behaves much as 0.6.
- **Overlaps:** the most specific entry wins; an exact path beats a glob.
- **Worktrees follow their main repo** (`git rev-parse --git-common-dir`),
  wherever they live, so they are never listed. Their windows read
  `augur@<branch>·claude`.

**Listed, not allowed.** The picker lists a workspace's codebases and ends
with "＋ another directory…". Starting a trail in a directory no workspace
claims, from there or with `cd` + `trails`, asks once: add it to this
workspace (written to the config), or run it here this once.

**The config is the user's file.** `trails ws add NAME` edits it, as
`trails config` does today; nothing about workspaces lives in the state
directory. Editing it never moves running windows (principle 4).

## Journeys

One command, `trails`, does the right thing for where it runs: a workspace
picker from nowhere in particular, a codebase's trails from inside one, a
switch instead of a nested tmux from inside tmux.

### Over one SSH connection

One SSH connection is one tmux client, and a client changes which session it
shows without reconnecting.

```console
airbochs $ ssh probochs -t trails

Pick a workspace: █
▌ lattiq     3 trails · 1 needs you
  personal   1 trail
  prcpnt     nothing running
```

1. **Pick lattiq.** Its session is up, so you attach, landing on the trail
   that needs you.
2. **Pick prcpnt, with nothing running.** No empty session is made
   (principle 7): the same picker shows prcpnt's codebases, and starting a
   trail creates the session with that trail as its first window.
3. **Inside a workspace,** plain tmux moves you: next and previous window,
   prefix+s / `choose-tree`, prefix+( and ) for the previous and next session.
4. **`trails` again** (at a shell, or from a bound popup) shows this
   workspace's codebases and trails; picking a running trail selects its
   window.
5. **`trails ws`** shows the workspace picker and runs `switch-client`. Same
   connection; the workspace you left keeps running.
6. **Reconnect** with the same command: the picker marks the workspace you
   were in.

### From an editor

Zed over SSH, VS Code Remote-SSH or nvim's terminal runs `trails` in a
codebase. It lists that codebase's trails, whatever their workspace, and
attaches to the chosen trail's editor view (`lattiq/augur`): one agent,
nothing else. Starting a new trail creates its window in the workspace and its
editor view. The editor never sees workspaces.

### From a shell in a repo

`cd ~/workspace/lattiq/augur; trails` shows augur's trails, as 0.6 does.
Picking one attaches to the lattiq workspace with that trail's window
selected. Inside tmux it runs `switch-client` instead of nesting, which fixes
R6.

## Companions

A companion is the editor or a shell for one codebase: an ordinary window in
the workspace, beside that codebase's trails.

| Companion | Command | Opens | Window |
| --- | --- | --- | --- |
| Editor | `trails edit` | `$EDITOR` in the codebase | `augur·nvim` |
| Shell | `trails shell` | `$SHELL` in the codebase | `augur·shell` |
| Side by side | `trails ide` | a layout window: editor beside a nested view of the agent, as the map does | `augur·ide` |

- **One editor per directory.** Trails sharing a path share its editor; a
  worktree is another path, so it gets its own.
- **The window you are on decides the codebase,** since a workspace holds
  unrelated repos. Run from a trail or another companion, the command acts on
  that codebase.
- **Toggle, not duplicate.** `trails edit` selects the codebase's editor
  window if it exists and creates it if not; run again from the editor, it
  returns to the last trail.
- **Never a split in a trail's window:** editors attached to that trail would
  see it.
- **No session-level shell.** A workspace has no shell of its own; every
  window runs in some codebase.

## Picker

The picker stays fzf, a filtered view over the same tmux objects
(principle 6): one command, three screens, chosen by where it runs.

### Picking a workspace

From nowhere in particular (`~`, a fresh SSH login) or `trails ws`:

```console
Pick a workspace: █          # enter: open · ctrl-n: new workspace
▌ lattiq      ● 3 trails · 1 needs you
  personal    ● 1 trail
  prcpnt        nothing running
  padnam        nothing running
```

Sorted by what wants you, then by name. This is where most SSH logins land,
so it stays short.

### Inside a workspace

`trails` at a shell in the workspace, or from a bound popup:

```console
lattiq ▸ Pick a trail: █     # enter: open · tab: YOLO · ctrl-n: name it · ctrl-e: editor · ctrl-x: end
▌ ● needs you  augur     claude · yolo  Health endpoint returns 500
  ● your turn  ledger    codex          Postgres 17 migration
  ● working    augur     claude    #2   Flaky ledger test
    editor     augur     nvim
  ○ lost       billing   claude         Rate limit headers
  augur     · new claude
  ledger    · new claude
  billing   · new claude
  ＋ another codebase…           (51 more under ~/workspace/lattiq)
  ↩ resume old trails  (12 ended)
```

0.6's picker with a codebase column. Two choices keep it short:

- **Running trails first, flat, sorted by state,** as today. Grouping by
  codebase would push "needs you" down the list.
- **New-trail rows only for codebases with something running or recent.**
  The rest sit behind "another codebase…", an fzf over the directories under
  `root`. Typing filters everything anyway.

Companions appear as rows (`editor augur nvim`) so they can be reached from
the picker too.

### From an editor, or a shell in a repo

0.6's picker as it is, with the workspace in the prompt:

```console
augur (lattiq) ▸ Pick a trail: █
▌ ● needs you  claude · yolo  Health endpoint returns 500
  ● working    claude    #2   Flaky ledger test
  claude · new trail
  ↩ resume old trails  (4 ended)
```

### Preview

fzf's `--preview` runs `tmux capture-pane -p -t <window>` for the row under
the cursor, so the right half shows that agent's screen as it is now:

```console
▌ ● needs you  augur  claude   Health endpoint… │ Do you want to run `pytest -x`?
  ● working    ledger codex    Postgres 17…      │   1. Yes  2. Yes, don't ask  3. No
```

It answers "what is it asking me?" without opening the trail, and costs
nothing: the picker already knows the window. A key toggles it; off by
default below a width that fits two columns, such as an editor side panel.

### Left out

- **No tree of our own.** Workspace → codebase → trail is what prefix+s /
  `choose-tree` shows, with the editor views as sessions beside them.
- **No status-bar additions.** Window names (`augur·claude`) carry the state
  through tmux's own status line, and the `set-titles-string` guidance from
  0.6 covers the rest.

## Commands and keys

Every feature is a command first; key bindings are lines the user chooses to
add (principle 2).

| Command | Does | Compared with 0.6 |
| --- | --- | --- |
| `trails` | the picker for where you are: workspaces, or a codebase's trails | same command, one directory |
| `trails ws [NAME]` | pick or name a workspace and switch to it | new |
| `trails ws add NAME` | add the current directory to a workspace in the config | new |
| `trails edit` / `shell` / `ide` | the codebase's companions | new |
| `trails new NAME [AGENT]` | start a named trail | same |
| `trails ls [-a \| DIR]` | list trails; the TSV gains a `workspace` field | same, extended |
| `trails restore` | rebuild lost trails into their workspaces | same, extended |
| `trails map [N]` | several agents side by side | same |
| `trails keys` | print suggested tmux.conf bindings | new |

`trails keys` prints, and changes nothing:

```text
# trails: paste what you want into tmux.conf
bind a display-popup -E -w 80% -h 70% trails
bind W display-popup -E -w 60% -h 50% 'trails ws'
bind e run-shell 'trails edit'
bind v run-shell 'trails ide'
bind S run-shell 'trails shell'
```

The keys are suggestions, checked free in tmux 3.8's default prefix table (`T`
and `E` are taken: pane title, even layout). A user with other habits changes
them. The picker in a popup leaves no window behind.

## What persists

Two files persist. The tmux layout is never saved, because it can always be
rebuilt from them.

| Layer | Holds | Where | Survives a reboot |
| --- | --- | --- | --- |
| Definition | workspaces and their codebases | `~/.config/trails/config.json`, the user's, can live in dotfiles | yes |
| Records | running trails: codebase, agent, conversation, name | `~/.local/state/trails/sessions/`, trails' own (exists in 0.6) | yes |
| Live | workspace sessions, trail windows, editor views | the tmux server | no |

- **`trails restore`** reads the records, creates each trail's window in the
  workspace the config gives its codebase, resumes its conversation, and
  re-creates its editor view. Companions are not restored: an editor or shell
  is reopened with one command.
- **Records move from session to window.** 0.6 keys a record by session name;
  1.0 keys it by the trail's own id, with its workspace and window name, and
  marks the window `@trails_id` as today.
- **Config edits** apply to new and restored trails only; running windows stay
  where they are.

## Implementation

Stay a POSIX `sh` script, and add the test suite 0.6 lacks.

- **Why shell.** tmux power users read and patch shell; the tmux plugin
  ecosystem is shell. The principles remove what pushed toward Go: no
  reconciliation loop, no key management, no permanent window to keep alive.
- **What's left fits:** a `workspaces` key read with `jq`, glob matching,
  `git rev-parse` for worktrees, `link-window`, `switch-client`,
  `display-popup`.
- **Tests:** a plain `sh` integration suite against a throwaway server
  (`tmux -L trails-test -f /dev/null`), with a stub agent in place of claude.
  It runs in CI beside `sh -n` and ShellCheck.
- **Revisit Go** only if the script outgrows shell again: if it stops being
  readable, or the suite gets slow.
- **Contracts kept:** the `trails ls` TSV gains one field before the title
  (`workspace`); the SwiftBar plugin reads the title as the last field, so it
  keeps working. The 0.6 records are migrated on first run.

Starting point: `bin/trails` 0.6.1 is 2,701 lines with 12 `jq` and 35 `awk`
calls and no tests.

## Decisions

Decided 2026-10-16. The common thread: pick whatever creates and moves the
fewest things.

| # | Question | Decision |
| --- | --- | --- |
| D1 | A session already has the workspace's name | Plain workspace name, marked `@trails_workspace`; refuse on a collision |
| D2 | An `open` list of codebases on entry | Not in 1.0 |
| D3 | Editor view names | The trail's name when it has one, else `<codebase>[-N]` |
| D4 | `$TMUX` inside `display-popup` | Verified on tmux 3.8 by `test/t-popup.sh` |
| D5 | The map | Stays its own session; its cells attach to editor views |
| D6 | Migration from 0.6 | Running sessions left alone; records migrated |
| D7 | The Air on its own | Out of scope; trails works the same on any machine |

**D1. Plain names, refuse on collision.** A workspace session is named after
the workspace (`lattiq`), as a tmux user expects in `tmux ls`
(principle 1). The `@trails_workspace` option, not a name prefix, tells trails
which sessions are its own. When a session by that name exists without the
mark, trails stops:

```text
trails: a session named "lattiq" exists and isn't a trails workspace.
        Rename it (tmux rename-session -t lattiq …) or the workspace in config.json.
```

Adopting the user's session would add windows to something they built
(principle 4). A `trails-` prefix would dodge a rare collision by making every
workspace read `trails-lattiq`.

**D2. No `open` list in 1.0.** `trails restore` brings back what was running,
and users who want fixed layouts have tmuxinator or sesh, which work beside
trails because its sessions are plain. It would be the first setting that
makes trails create something nobody asked for. Revisit only if it's missed.

**D3. Named trails name their editor view.** `trails new payments` in lattiq
gives `lattiq/payments`; an unnamed second trail in augur gives
`lattiq/augur-2`. This is 0.6's `#name` / `#2` rule carried over, and the name
you chose is what you type in `tmux a -t lattiq/payments`.

**D4. Verified.** Inside `display-popup`, `$TMUX` is set, `display-message`
resolves the client that opened the popup, and `switch-client` from there
returns 0; `$TMUX_PANE` is empty, since a popup is not a pane, and nothing
needs it there. `test/t-popup.sh` checks this on every run.

**D5. The map stays a session.** It shows the trails that most want you
across workspaces, so it can't live inside one. Its cells are nested clients;
in 1.0 they attach to editor views, which already hold exactly one trail.

**D6. Leave running 0.6 sessions alone.**

- Running `trails-<project>` sessions keep working: `trails` lists them under
  a "from 0.6" group and attaches to them as before. They drain as they end.
- Lost 0.6 records restore into the new model, as windows in their codebase's
  workspace.
- Moving live sessions automatically would be trails rearranging
  (principle 4). A one-off `trails adopt` can come later if wanted.

**D7. One machine at a time.** trails works the same on any machine; used on
its own, the Air runs its own server with its own workspaces. Showing one
machine's trails from another is SSH's and the editors' remote modes' job,
not trails'.
