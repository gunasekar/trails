# 24. trails' keys are capital letters

- Status: accepted. Amended in 1.12: `H` is gone, since `prefix ?` lists trails' keys
  among tmux's own by their notes (`bind -N`)
- Date: 2026-10

## Context

`trails keys` bound a mix: capitals (`P`, `W`, `A`, `N`, `G`, `M`, `R`), a lower-case `e`
for the editor, and symbols that took tmux's own: `(` and `)` its cycling through every
session, `?` its list of every binding. Next to a tmux.conf's own keys, mostly lower case
(`r` to reload, `m`, `g`, `|`, `-`), there was no telling at a glance which key was whose,
and the keys trails took from tmux were ones a tmux user reaches for.

## Decision

Every key trails binds is a capital letter, but `` ` `` for the shell, the editors' own
toggle-terminal key, which tmux leaves unbound.

| does | was | now |
|---|---|---|
| the editor beside the agent | `e` | `E` |
| the previous and next workspace | `(` `)` | `K` `J` |
| trails' keys | `?` | `H` |

`K` and `J` are vim's up and down; `H` is help. All three are free in tmux 3.8's default
table. `E` takes tmux's spreading the panes out evenly, still `:select-layout -E`.

## Consequences

- tmux's `?`, `(` and `)` are tmux's again: every binding, and every session in turn.
- A tmux.conf's lower-case keys can't meet trails': a capital is trails', anything else is
  tmux's or yours.
- Hands used to `prefix e`, `(`, `)` and `?` learn new ones. `trails keys` follows an upgrade
  the next time tmux reads tmux.conf, but a reload binds and never unbinds: the old keys keep
  trails' commands until tmux restarts, or until they are given back by hand (`unbind e`,
  `bind ? list-keys -N`, `bind ( switch-client -p`, `bind ) switch-client -n`).
- The README's GIFs show the old keys until the demos are recorded again from
  `assets/demo/*.tape`, which press the new ones.
