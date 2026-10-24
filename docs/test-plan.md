# Test plan

How every scenario in [scenarios.md](scenarios.md) is tested: by the automated
suite where a stub agent and a stub fzf can stand in, by hand where only a real
terminal, editor, agent or app will do. Run before a release.

## Automated

```console
test/run.sh            # every test/t-*.sh, each on its own tmux server, in a throwaway HOME
test/run.sh checklist  # one of them
```

Each test runs with `test/bin` first on `PATH`: a stub agent that reads `ask`,
`busy`, `title`, `exit` and `hook WORD` from its pane, a stub fzf driven by `FZF_PICK`,
`FZF_PICKS`, `FZF_DUMP` (with `!esc` for Esc and `!query` for Enter on typed
text), and a stub editor. Nothing touches the real tmux server or config.

## Coverage

`A` is automated (the test file), `M` is a manual check below, `—` is not
covered yet.

### The everyday loop

| # | Scenario | Covered by |
|---|---|---|
| 1 | Arrive: workspaces from `~`, Enter attaches | A `t-screens` · M1 |
| 2 | Get to the trail that needs you | A `t-picker` (cursor), `t-classify` (state) · M2 |
| 3 | New trail in this codebase | A `t-picker` |
| 4 | New trail in another codebase | A `t-screens` |
| 5 | Move between trails and workspaces | A `t-screens`, `t-inside`, `t-grouped` |
| 6 | Editor and shell beside the agent | A `t-tools` · M3 |
| 7 | Come back after a break, restore after tmux dies | A `t-restore`, `t-autorestore`, `t-upgrade` · M4 |
| 8 | Finish, or resume old work | A `t-launch`, `t-picker` (ctrl-x) · M5 (resume) |

### Everything else

| Area | Scenario | Covered by |
|---|---|---|
| Setting up | install, deps on PATH | M6 |
| | `trails config` | — |
| | broken, empty, wrong-typed config | A `t-edges` |
| | `trails ws add`, workspaces in the config | A `t-workspace` |
| | no workspaces: `default` | A `t-picker`, `t-launch` |
| | `trails keys` lines accepted by tmux | A `t-checklist` (prefix N, status-right) · M6 |
| Starting | new trail in a repo, a workspace | A `t-picker`, `t-screens` |
| | browse… to an unlisted folder | A `t-screens` |
| | folder no workspace claims: the question | A `t-screens` |
| | named: `trails new`, ctrl-n | A `t-launch`, `t-picker` |
| | YOLO: Tab, `"mode": "yolo"` | A `t-launch` · M5 |
| | from an editor's terminal | A `t-inside`, `t-tools` · M8 |
| | a second trail in a codebase (`#2`) | A `t-picker` |
| Finding | codebase, workspace, workspaces screens | A `t-screens`, `t-picker` |
| | `trails ws NAME` | A `t-screens` |
| | `trails ls`, `-a`, `DIR`, piped | A `t-ls` |
| | Esc up, ctrl-c out | A `t-screens`, `t-picker` |
| Watching | states, from hooks | A `t-classify`, `t-hooks`, `t-ls` |
| | preview: layout, follow, live refresh, wrap | M9 |
| | `trails map` | A `t-map` |
| | every running trail: prefix A, ctrl-a, Esc back, ctrl-x from it | A `t-all` |
| | `?`: the keys, `trails help keys` | A `t-edges` (the text) · checked by hand with real fzf |
| Beside the agent | edit, shell, toggles, kept window, ctrl-e | A `t-tools` |
| | the diff: untracked files, a popup from prefix G, a gui command | A `t-diff` |
| Checklist | prefix N: add, Esc, Enter copies, ctrl-e; tick; count; `note`; path, old `notes` key and file | A `t-checklist` · M10 |
| Ending | ctrl-x | A `t-picker`, `t-tools`, `t-map` |
| | resume old trails, from the history; ctrl-x forgets one; a resume that dies keeps it | A `t-hooks` · M5 |
| | a conversation that never had a turn stays out of the history | A `t-tools` |
| When things die | lost, `trails restore` (and forgetting what it can't bring back), reboot | A `t-restore` · M4 |
| | restore when tmux starts, the opt-in line | A `t-autorestore` |
| Remote | ssh in, one connection for every workspace | M1 |
| | Zed over ssh, VS Code Remote-SSH | M8 |
| | two terminals on one workspace | A `t-grouped` |
| Agents | any CLI by config | A (stub agent) |
| | hooks: the state, `--id` and the record following it at once; bad IDs and a nested agent's left out | A `t-hooks` · M2 |
| | tmux 3.4 and 3.5, which escape the field separator | CI (Ubuntu, tmux 3.4) |
| | session IDs bring a trail back | A `t-restore` |
| Edges | refuse `/`, a deleted directory | A `t-edges` (deleted) |
| | refuse a foreign session by a workspace's name | A `t-inside` |
| | worktrees | A `t-workspace` |
| | spaces and `'` in a codebase's name | A `t-picker` |

## Manual checks

Each on the real machine, in Ghostty, with `trails keys` pasted into tmux.conf.

| # | Do | Expect |
|---|---|---|
| M1 | From another machine: `ssh host -t trails`, pick a workspace, `prefix W` to another, detach, reconnect | The workspaces list; attached on the trail that most wants you; switched without reconnecting; the one you were in marked on return |
| M2 | Ask claude something that needs a permission; let another finish its turn | `● needs you` and `● your turn` in the picker, the cursor on the one that needs you |
| M3 | In a trail: `prefix e`, again, `` prefix ` ``, quit the agent | Editor right 60%, agent left; back to the agent; shell under the editor (a 40% column on the right with no editor); editor and shell kept as the codebase's window |
| M4 | `tmux kill-server`, then `trails`, then `trails restore` | Trails shown `○ lost`; each back on its conversation, in its workspace |
| M5 | End a claude trail, then **↩ resume old trails**, Tab on it, Enter | Listed as closed; Tab flips YOLO; resumes on its conversation |
| M6 | `brew install` or `bin/trails` on PATH; `trails keys` into tmux.conf, reload | Every line accepted, every key works |
| M7 | *(retired in 1.6, with the menu-bar plugin)* | |
| M8 | VS Code / Zed terminal (local and Remote-SSH): `trails`, pick a trail | The codebase's trails only; attached to that one trail; no workspace |
| M9 | `prefix P` on a busy trail, on a wide one, on a narrow one; ctrl-/ | Preview under the list to the popup's bottom, latest output, updating every second; wide one wrapped, narrow one at its width; ctrl-/ hides and shows |
| M10 | `prefix N`, type, Enter, type, Enter; ↓, Space; ↓, Enter, then ⌘V in the agent; `prefix N`, ctrl-e, quit the editor | Both items added to the checklist (`.trails/checklist.md`, or under `data`), the list open on each; the item under the cursor shown whole under the list; ticked, moved down, `☑` count in the status line drops; the item pasted; the file in a large popup, then the list again |

### Run, 2026-10-23

On airbochs, with trails 1.5.0, then 1.5.1 for M7. All ten pass.

| # | Result |
|---|---|
| M1 | `ssh airbochs -t trails` from probochs: the workspaces, attached on the trail that most wants you, `prefix W` to another without reconnecting, the last one marked on return |
| M2 | Claude asking a question read as needs you, red, with the cursor on it, and in the menu bar; your turn once answered |
| M3 | Editor left, back to the agent, shell under the editor; on `/exit`, the window kept as `imprint·nvim` with both panes |
| M4 | On a tmux server of its own (`TMUX_TMPDIR`, `XDG_STATE_HOME`): lost after `kill-server`, restored on the same conversation, which still knew the word it was given |
| M5 | The ended conversation listed as closed; Tab took YOLO off; resumed on it, `claude --resume` without the YOLO flag |
| M6 | `brew upgrade` to 1.5.0, `trails keys` into tmux.conf: every line taken, every key working |
| M7 | Listing and End fine, End on `default/it's` included. Resume failed: the tab said the trail was gone. Fixed in 1.5.1 (below), then Resume worked |
| M8 | VS Code over Remote-SSH from probochs: attached to the trail's own session, `personal/trails`, not the workspace |
| M9 | Under the list, filled, refreshing; a wide trail wrapped; nothing for a row that is no trail; ctrl-/ hides and shows |
| M10 | A note added once, nothing on Esc, the notes in a large popup on Enter on an empty line |

M7's failure: Resume runs `trails open` in a new tab through `bash --noprofile --norc`, which has the system's PATH alone. trails was called by its full path but couldn't find tmux there, and read a running trail as gone. trails now adds the directory it runs from and the Homebrew prefixes to PATH when tmux isn't on it (1.5.1, pinned in `t-edges`).

## Bug hunt

Beyond the scenarios, each area was pushed with odd input and failure: names with
spaces, quotes and unicode; broken or wrong-typed config; missing dependencies;
deleted directories; corrupt records; killed windows and servers; races; many
trails. Every fix has a check in `test/t-edges.sh` (or the test named), which
fails on the code before it.

### Fixed, 2026-10-23

Data loss first.

| Finding | Was | Now |
|---|---|---|
| `trails end NAME` for a name that is no trail | killed that session: a whole workspace, or one of your own; a prefix (`dri`) killed `driver-1` | refused: a key is `WORKSPACE/NAME` or a 0.6 `trails-…`, matched exactly |
| `trails end trails-proj` beside a live `trails-proj-2` | killed the live one | only the exact name |
| `trails end default/../../x` | deleted `~/x` | refused; a record's path never leaves its directory |
| `trails open NAME` | turned off the status bar of any session it named | refused, as `end` |
| `trails ls` (the menu bar) racing a trail's end | brought the ended trail back as lost | a record is rewritten only while it is there, each writer with its own temp file |
| two trails started at once | one killed by "duplicate session"; or both running, the record the loser's | one at a time through naming a trail (a lock); a name taken meanwhile is refused |
| two `trails restore` at once | a fresh duplicate agent, and the real trail's record gone | the second sees it back, and says so |
| a broken config | read as no workspaces and the default notes path, silently | named, with jq's reason; commands stop, `ls` goes on |
| `ws add` on a config that is a link into dotfiles | replaced the link with a file, mode reset | written through the link |
| `ws add` to a workspace given as a string | dropped it | kept, and read as a codebase |
| without fzf | `fzf: command not found`, exit 0 | says so, exit 1 |
| the preview on a row that is no trail, or a lost one | another trail's screen | nothing |
| a folder name with a `\|` | the trail vanished from `ls`, the picker, the map | fields split on the unit separator |
| `trails edit` starting the server | left `NVIM`, `ZED_TERM` in every later pane | through the same door as a launch |
| a trail with no title, in the menu bar | the workspace's name shown as its task | `ls` prints `-`, the plugin reads it as none |
| a folder named with `[`, `*`, `?` | added, then claimed by others and not itself | escaped as it is added |
| a codebase path with a space | missing from the codebase tree | there |
| a link inside a workspace directory | asked which workspace it is in | its workspace's |
| a listed path and a glob as long | the first in the config won | the path, the narrower |
| resuming in a directory with a `:` | `cd` to the wrong path | the directory after the agent and ID |
| a name like the codebase's own, or `-x` | numbered as an unnamed trail; grep's usage | refused |
| ctrl-n on the workspaces with a name in use | added to that workspace | refused |
| a deleted current directory | a trail made pointing nowhere | refused |
| a refusal in a popup | gone with the popup | the picker's waits for Enter, the note's shows on tmux's line |
| `trails keys` from a path with a space or `'` | broken bindings | quoted |
| an older fzf | the lists failed on its unknown options | each newer option asked of fzf; hints in a header, a snapshot preview |
| an agent entry that isn't an object, a second by one name | broke every agent; two rows starting the first | skipped and said so |
| no agent installed | `unknown agent ''` | says so |
| notes: `{codebase}` with `&` or `\`; an unwritable path; `notes DIR` for a missing one; `.git` | `R{codebase}D.md`; "nothing to note"; made the folder; `.git/.scratch` | as named; says why; refused; the repo's |
| `trails edit`, `notes` with `$EDITOR` not installed | raw tmux errors | says so |
| `trails map 0`, `abc`, a huge number | the wrong message, or a shell error | refused as such |
| `AGENT_SETTLE`, `AGENT_ASK_RE` with a typo | sleep's or grep's usage on every pass | the default, and said once |
| a lost trail whose directory is gone | told to ctrl-x it, which only works there | `trails end KEY` |

### Known, not fixed

| Finding | Why it stands |
|---|---|
| A worktree whose own path a catch-all glob (`~/*`) claims goes there, not to its main checkout's workspace | rare, and which should win is a design call |
| Without `data`, a git worktree's checklist is its own, not the main checkout's (with `data`, it is the main checkout's) | the repository's top is where it lives, by design |
| A trail session renamed by hand drops out of the lists | renaming trails' sessions is outside what trails supports |
| Map pane borders read the host name without a `set-titles` in tmux.conf | cosmetic |
| A temp directory left by a picker killed with SIGKILL | KILL can't be trapped |
