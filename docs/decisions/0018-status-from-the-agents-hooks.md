# 18. Status from the agent's hooks

- Status: accepted, amended by [ADR 19](0019-no-agents-files-read.md): the hooks are
  the only source, Claude's file no longer answers, they say the conversation too
  (`--id`), and `trails hooks` is gone, its snippets in [the README](../../README.md#hooks-for-each-agent)
- Date: 2026-10
- Supersedes ADR 2 (status from the screen); amends ADR 11 (an agent's own state
  beats its screen)

## Context

Before 1.6, trails answered "which agent wants me" in three ways. Claude's state file
(`~/.claude/sessions/<pid>.json`) gives all three states exactly, for Claude only.
Codex's rollout gives *your turn* and nothing inside a turn. Every other agent, and
Codex mid-turn, is read off its screen: two captures `AGENT_SETTLE` apart, and a
regex for questions.

The screen check is the weak part. A status line or a countdown that redraws while
the agent sits idle reads as working (the reason for ADR 11). `AGENT_ASK_RE` misses
dialogs it has no words for and fires on prose that has them. Every listing pays a
settle sleep when any session falls back to it. And it is guesswork presented as
fact: a wrong *working* hides an agent that is waiting on you.

When ADR 2 was written, hooks were Claude's alone. That is no longer so. Claude
Code, Codex (stable since 0.124), Gemini CLI, Copilot CLI and Cursor all run a
command at the start and end of a turn, and most when they want permission;
opencode has plugin events for the same moments. A hook knows the state; the screen
only suggests it.

tmux-claude-hatch, a small Claude-only picker, takes the same line on setup: its
hooks are the user's to install, and it ships them as a Claude Code plugin so that
installing them is one command.

## Decision

An agent tells trails its state through its own hooks, calling one command:

```sh
trails state working | waiting | idle
```

It runs in the agent's pane (the hook inherits `TMUX_PANE`), sets two pane options,
`@trails_state` and `@trails_state_at` (epoch seconds), and exits 0 without output
whatever happens, so a hook can never fail a turn or print into it. Outside tmux it
does nothing.

The words are the agent's side of trails' three: *working*, *waiting* (needs you),
*idle* (your turn).

`classify` takes:

1. **The hook's state**, `@trails_state` on the agent's pane.
2. **Claude's own file**, as ADR 11, which needs no setup. When it and the hook
   both answer, the newer wins.
3. Otherwise **unknown**: grey, sorted after *your turn* and before *working*.

The screen is no longer read (ADR 2), and Codex's rollout no longer answers for
its state (ADR 11): hooks cover both, exactly.

Setting the hooks up is the user's, and trails makes it short:

```sh
trails hooks          # each agent: hooked or not
trails hooks AGENT    # the hook config for AGENT, and where it goes
```

trails prints them and says where; pasting them in is the user's, beside any hooks
already there. trails writes into no other tool's config. For Claude the hooks also
ship as a Claude Code plugin in this repo, installed with `/plugin install`.

An agent trails has no entry for is wired by hand: the README gives the three
moments to hook and the command for each.

## Consequences

- Status is exact for every agent with hooks, and the same code path for all of
  them. Adding an agent's status is a hook mapping in `trails hooks`, not a reader
  in trails.
- No screen reads: no settle sleep, no false *working* from a redraw, no question
  missed for words the pattern didn't know.
- An agent with neither hooks nor Claude's file shows *unknown* until you set its
  hooks up. That is honest, and a change: before 1.6 it showed a guess.
- Claude keeps working with no setup, through its file.
- A turn that ends without its end hook firing (an interrupt, in agents that skip
  `Stop` then) leaves *working* standing until the next event. For Claude, the
  newer of hook and file answers.
- An agent with no hook for a permission prompt (Copilot, Cursor) reads as
  *working* through one.
- The hook formats are the agents' and they move. `trails hooks` is where that
  churn lands, and a stale mapping costs exactness for one agent, never the
  listing.

See [docs/design/trails-1.6.md](../design/trails-1.6.md) for the per-agent hook
mappings.
