# 2. Read agent status off the screen

- Status: accepted, amended by ADR 11
- Date: 2026-07

## Context

The picker exists to answer "which agent wants me". tmux's `session_attached` is
about your terminal, not the agent, and `#{session_activity}` tracks tmux's alert
bookkeeping rather than pane output. Claude Code's hooks would report the state
exactly, but only for Claude; cursor-agent, opencode and antigravity have none.

## Decision

Capture each pane's visible screen twice, `AGENT_SETTLE` apart. Changed is
`working`; unchanged and asking a question (`AGENT_ASK_RE` on the bottom lines)
is `blocked`; otherwise `idle`.

## Consequences

- Works for every agent with no integration, because every agent TUI animates
  while it works.
- Costs one settle sleep per listing, which the picker pays once and caches.
- The error is one-sided: a still screen can never read as working.
- `blocked` vs `idle` is a heuristic and can be fooled by an agent printing
  "Approve". Both sort above `working`, so a wrong guess only changes a colour.
- A resize is a screen change, so an agent can read as `working` for one poll
  after a map attaches.

ADR 11 amends this: an agent that writes its own state down is read from that
record first, and the screen is the fallback. Today that is Claude, fully, and
codex, for whether it is between turns.
