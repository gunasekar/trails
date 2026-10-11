# 5. The name: trails

- Status: accepted
- Date: 2026-10

## Context

The script began as `agent`. cursor-agent ships a binary called `agent` that
overwrote the symlink on install and on every self-update, so it became `aigent`.
That dodged the clash but not speech-to-text, which writes "agent" every time,
and dictating to a coding agent is a common way to use it.

## Decision

Call it `trails`. Checked before choosing: no Homebrew formula or cask, no
command on macOS or Debian, nothing in the AI tooling space. The nearest uses are
a Node.js web framework dormant since 2022 that installs no command, and a small
Rust crate.

Rejected along the way: `sesh` (an established tmux session manager in Homebrew),
`crew` (CrewAI's vocabulary), `conductor` and `pitboss` (existing agent
orchestrators), `lane` (close to the Lanes app for AI sessions), `helm`,
`foreman`, `deck` (existing commands).

## Consequences

- Sessions are named `trails-<project>` and records live under
  `~/.local/state/trails`. Renaming the prefix again would strand running
  sessions unless they are renamed with it.
- The name is claimed as a tap formula, `gunasekar/tap/trails`. Homebrew's core
  catalogue can't be reserved and only accepts established projects.
