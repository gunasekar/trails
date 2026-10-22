# 17. One picker: levels, not screens

- Status: accepted
- Date: 2026-10

## Context

The picker grew a screen for each way in. A bare `trails` chose between a
codebase's screen, a workspace's and the workspaces by looking at the editor's
variables, the tmux session and the directory, and each screen had rows and
keys of its own. A codebase started an agent from one row per agent, while a
workspace went through `＋ new trail…`. ctrl-n named a trail on one screen,
made a workspace on another and did nothing on a third. Esc went back on some
screens and quit others. The directory list under `＋ new trail…` held every
folder under the workspace's `root`, and `root` defaulted to `~`, so a
workspace without one listed `~/Library` and `~/Movies`.

`docs/design/picker-consolidation.md` draws what there was, the seven
inconsistencies (I1 to I7) and the decisions taken (D1 to D7). This records the
ones that outlive it.

## Decision

**One picker, at four levels: workspaces, workspace, codebase, agent.** Where
it runs decides only the level it opens on: `~` and `/` the workspaces, a
workspace's tmux session that workspace, a codebase's directory that codebase.

- **Every screen that lists trails has the same rows, in one order:**
  `＋ new trail…`, then the running and lost trails, then the editor and shell
  windows, then `↩ resume old trails`. `＋ new trail…` is the one way to start an
  agent (D2). From a workspace it picks a codebase first, from a codebase it goes
  straight to the agents. Tab and ctrl-n act on the agents screen only.
- **Esc goes up a level, ctrl-c quits** (D4). A codebase's screen goes up to its
  workspace's, a workspace's to the workspaces, which quits. The helper lists,
  the codebase tree, `browse…` and the agents, go back to where they came from.
  fzf aborts the same way for Esc and ctrl-c, so the screens name `esc` in
  `--expect` and the dispatch handles it as a key. An editor's terminal sees one
  codebase by design ([ADR 14](0014-editor-views.md)), so there Esc quits.
- **A workspace is workspace directories and codebases** (D5). A config entry
  ending in `/*` is a workspace directory: its child folders are codebases. Any
  other entry is a codebase of its own, and a path that is also a workspace
  directory makes that directory a codebase too. `root` is only where `browse…`
  starts. No config key changes: the config already said this.
- **`＋ new trail…` is a tree, one level deep** (D5): each workspace directory
  with its child folders under it, those with trails or recent history first,
  then the single codebases, then `browse…`, which walks the file system a
  folder at a time. A deeper folder with trails or history is listed under its
  workspace directory, so it needs browsing once (D6).
- **A listed path claims the folders inside it** (D6), as a glob already did, so
  a folder inside a workspace never asks where it belongs. The nearest entry
  claims it.
- **`default` holds the trails of folders no workspace claims** (D7). The
  question such a folder gets lists workspaces by name, `default` first, *not
  added to a workspace*, so Enter keeps it there, then the workspace browsed
  from, then the rest, each *add it here*. A bare `trails` asks it every time
  it runs there; `trails new` asks nothing and uses `default`.
- **Kept as they were** (D1, D3): Enter on a running workspace attaches at once,
  and ctrl-n on the workspaces screen makes a workspace.

## Consequences

- A screen's rows and keys no longer depend on how you got to it, and getting
  anywhere is Enter down and Esc up.
- Starting an agent in a codebase takes one more Enter than it did: the agent
  rows moved behind `＋ new trail…`, a step that keeps the trails, what you
  usually came for, at the top.
- Quitting from a codebase's screen takes ctrl-c, or Esc up through the
  workspace and the workspaces. Esc no longer quits from where it used to.
- fzf searches only what it draws, so the tree filters on folder names: `kite`
  finds `kitewatch`, but a workspace directory's name matches its own row, not
  its children's.
- A workspace that relied on `root` to list the folders under it now needs a
  `/*` entry for them. One whose `root` and glob named the same folder, the
  usual case, sees no difference.
- The test fzf (`test/bin/fzf`) presses Esc as a key with `FZF_PICK=!esc`, and
  an empty pick, its old Esc, is now ctrl-c.

## Alternatives

- **Enter on a workspace opens its screen, never attaches.** One rule for Enter
  everywhere, at the cost of a second Enter on the commonest move. Rejected
  (D1): attaching at once is what that row is for.
- **Keep the agent rows on a codebase's screen.** Fewer keys to start an agent,
  but two ways to do it, and a screen whose shape depends on where it was
  opened. Rejected (D2).
- **The whole tree under each workspace directory.** Finds nested repos without
  browsing, but lists every folder of every repo. Rejected (D5) for one level
  and `browse…`; listing folders that hold a `.git` is the way to nested repos
  if they are wanted.
- **A `＋ new workspace…` row.** More visible than ctrl-n, but a second way to do
  one thing. Rejected (D3) until it is missed.
