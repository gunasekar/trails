# 19. trails reads no agent's files

- Status: accepted
- Date: 2026-10
- Supersedes ADR 11 (an agent's own state beats its screen); amends ADR 18 (status
  from the agent's hooks): the hooks are the only source, and say the
  conversation as well as the state

## Context

trails runs any agent its config describes. Up to 1.6 it also read some agents'
own files: Claude's session files and transcripts in seven places (its state, the
conversation it moved to, its name, a name given inside it, its past
conversations, whether one is open elsewhere, whether its plugin is installed),
Codex's rollout files for its conversation ID, and opencode's database for its
past sessions. `trails hooks` held six agents' hook formats and checked their
settings files.

Those files are not an interface. Each is the agent's private state, in a format
it changes without notice, so every reader is a guess that a release can break.
And they made agents unequal: Claude worked with no setup, opencode listed its
history, any other agent got neither. Most of that code exists for one agent.

## Decision

trails knows an agent only through its config, and hears from it only through
its hooks.

- **Config** says how to start an agent, resume a conversation, arm YOLO and
  give it a name. Nothing else about an agent is built into trails' code; the
  six agents in the default config are data, replaced by the user's own.
- **Hooks** say what the agent is doing and which conversation it is in:
  `trails state WORD [--id ID]`. Getting the ID from the agent is the hook
  snippet's job, in the agent's own terms; trails takes it as given.
- trails reads no agent's files, settings or databases, and writes none.

## Consequences

- Every agent is equal: with hooks, exact status and a restore that follows the
  conversation; without, *unknown* and a restore of the conversation it began.
- Claude needs setup now, as every other agent did: its plugin, or its snippet.
- "Resume old" lists the trails trails ran, from its own history, not every
  conversation the agent has. The agent's own resume finds the rest.
- *Elsewhere*, Claude's own name and a name given inside Claude go. With
  *elsewhere* goes the guard against resuming a conversation that is open in an
  agent trails didn't start: trails can no longer see that, so resuming it from
  the history would run it twice, as the agent's own resume would.
- A hook's word is taken from whatever runs in the trail's pane, an agent the
  trail's agent started included; its `--id` only from the trail's own agent,
  told apart by process depth, not by name.
- About 400 lines go. An agent release can no longer break trails; it can only
  break that agent's hook snippet, which lives in the README, outside trails' code.
- The hook snippets for each agent are documentation ([the README](../../README.md#hooks-for-each-agent))
  and, for Claude, a Claude Code plugin in this repo. They are the one place an
  agent's terms appear, and they are not trails' code.

See [docs/design/trails-1.7.md](../design/trails-1.7.md).
