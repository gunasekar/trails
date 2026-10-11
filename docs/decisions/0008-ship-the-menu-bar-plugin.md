# 8. Ship the menu-bar plugin with trails

- Status: accepted
- Date: 2026-10

## Context

The SwiftBar plugin that shows agents in the menu bar lived in the author's
dotfiles. It reads `trails ls`, and when `ls` changed shape the two drifted: a new
plugin against an old trails dropped every task title until trails was upgraded.
Anyone else installing trails had no way to get the plugin at all.

## Decision

The plugin and its icons live in the trails repo under `extras/swiftbar/` and
install with trails into `share/trails/swiftbar/`. `trails swiftbar` links the
plugin into SwiftBar's plugin folder, and `brew info trails` says so.

It stays a reader of `trails ls` and nothing more (ADR 6): it holds no session
state of its own beyond what it needs to notify once, and `trails swiftbar` only
places a link.

## Consequences

- One release carries both ends of the `ls` contract, so they can't drift.
- A link, through Homebrew's unversioned path, means `brew upgrade trails`
  updates the plugin with nothing to redo.
- Resume supports Terminal, iTerm and Ghostty, chosen from the plugin's menu.
- trails gains one macOS-only command. It refuses clearly elsewhere.
