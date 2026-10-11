# 9. Two signals per session: running or not, and a state word

- Status: accepted
- Date: 2026-10
- Supersedes the row markers in ADRs 3 and 4 (`↻`, `◷`, `!`)

## Context

The picker and `trails ls` marked rows with a dot for every running agent,
whatever it was doing, plus `↻` for lost, `◷` for recent and `!` for open
elsewhere. The internal words `blocked` and `idle` showed through. Readers had to
learn five symbols to answer two questions: is it running, and does it need me?
The picker also made each agent's row both a tree heading and the "start new"
button.

## Decision

Every session shows two signals. The glyph says whether its tmux session exists:
`●` running, `○` not. A coloured word says the rest:

- running: **needs you** (red), **your turn** (yellow), **working**
- not running: **lost** (tmux died; restorable), **closed** (ended; resumable),
  **elsewhere** (open in a claude trails didn't start)

One `STATES` table in the script defines glyph, colour, word, legend and order,
and every view reads it. `trails ls` pipes a `life` column (`running`/`stopped`)
ahead of the state. The picker lists this directory's running and lost sessions,
then one *new trail* row per agent, then *resume old trails*, which opens the
ended conversations as a second list. Every row does something on Enter; there
are no label rows, which fzf can't make unselectable.

## Consequences

- Two questions, two signals, matching the two dots in the menu-bar mark.
- The `ls` TSV changed shape. The menu-bar plugin ships in the same release
  (ADR 8), so the two move together.
- `blocked` and `idle` remain the screen classifier's internal names only.
