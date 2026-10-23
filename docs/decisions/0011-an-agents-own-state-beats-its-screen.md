# 11. An agent's own state beats its screen

- Status: accepted, amended by ADR 18: hooks answer too, the newer of hook and file
  winning, and Codex's rollout no longer answers for its state
- Date: 2026-10
- Amends ADR 2, which reads every agent's state off its screen

## Context

ADR 2 reads state from two screen captures `AGENT_SETTLE` apart. It rests on one
property: an agent that isn't working doesn't repaint, so a still screen can never
read as working.

Claude Code's status line broke that property. A status line with a
`refreshInterval` redraws on a timer, idle or not. One that shows countdowns, such
as a usage reset or a prompt-cache expiry, changes its text every few minutes while
Claude sits on a finished turn. When a redraw lands between the two captures, the
session reads as working. The menu-bar plugin polls every 10 seconds, so it catches
about one redraw in thirty. Each catch re-arms its notification, and you're told
"your turn" again about a session you already knew was waiting.

Claude already writes its state down. Each running Claude keeps
`~/.claude/sessions/<pid>.json`, which trails reads to follow a session's
conversation (ADR 3). The same file has a `status` field, set from Claude's own
state, not from its screen:

| `status` | Claude means | trails reads |
|---|---|---|
| `busy` | a turn or delegated work is running | working |
| `waiting` | a dialog wants you: a permission prompt, a question, a sandbox request. `waitingFor` names it | needs you |
| `idle` | neither | your turn |

ADR 2 turned down Claude's hooks because they serve one agent and need setting up.
This file has the first cost but not the second. trails reads it already, there is
nothing to install, and nothing runs between commands.

## Decision

`classify` asks an agent's own reader for its state before it looks at the screen.
The reader is the one the agent's config names as `session.find`, so an agent
configured as Claude gets both its conversation and its state from Claude's file.
Two readers report a state:

- **`claude`** answers all three states from `status`.
- **`codex`** answers only *your turn*. Its rollout, the session log trails already
  finds for the conversation, records each turn as an `event_msg` whose payload
  type is `task_started`, then `task_complete` or `turn_aborted`. When the last of
  those ended a turn, codex is idle. Codex leaves approval prompts out of the
  rollout, so inside a turn it could be working or waiting on you, and the screen
  decides. The rollout is found by the session's conversation ID, which is in its
  file name. This is checked against codex 0.162.1's source, not a live codex.

A reader that can't answer falls back to the screen check. That covers no file
(Claude's folder-trust prompt comes before it), a `status` value the reader doesn't
know, and every agent without a reader. The settle sleep is paid only when at least
one session falls back.

## Consequences

- A Claude status line, or anything else Claude redraws while idle, no longer reads
  as working.
- *Needs you* is exact for Claude. The screen check missed dialogs whose wording
  `AGENT_ASK_RE` didn't cover, such as `/config`, and could be fooled by prose
  saying "Do you want".
- A listing of only Claude sessions skips the settle sleep. The menu-bar poll drops
  from about 0.5 seconds to about 0.15.
- Neither file is a documented interface. A release that renames a field or its
  values sends that agent back to the screen check, with its status-line weakness,
  until the reader is updated. It doesn't break the listing.
- A codex mid-turn is still read off its screen, so a redraw there can't show a
  finished turn as working, which was the case that mattered. Telling *needs you*
  from *working* inside a turn is the old heuristic.
- Other agents are still read off their screens. Each one that writes its state
  somewhere trails can read gets a reader in `agent_state`, next to its `find`
  reader. A screen-only agent with a status line of its own has the same weakness
  Claude had.
