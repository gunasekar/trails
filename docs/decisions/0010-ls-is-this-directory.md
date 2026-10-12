# 10. `trails ls` lists this directory, `-a` lists every one

- Status: accepted
- Date: 2026-10
- Changes the scope of `trails ls` from ADR 6, which folded `recent` and
  `restore -n` into it as the one box-wide list

## Context

`trails` is scoped to the directory you're in: the picker lists this directory's
sessions and starts agents here. `trails ls` was the exception and listed every
directory on the machine. `ls` reads as "here", both from plain `ls` and from
`trails` itself, so the box-wide list kept surprising people. The precedent for it,
`tmux ls` listing every session on the server, is not one most people reason from.

The box-wide list still has a real reader: the menu-bar plugin, which asks "what did
I leave where" every 10 seconds.

## Decision

`trails ls` lists the directory you're in: running, lost and recently ended
sessions, the same rows the picker shows, as a table or TSV. `trails ls -a` (or
`--all`) lists every directory, which is what `trails ls` used to do, and
`trails ls DIR` lists DIR, as if you had run `trails ls` there. "Here" is the
exact directory, the way the picker matches it, so `trails` and `trails ls` never
disagree about what is here.

This follows `kubectl get pods`, which lists the current namespace unless asked for
all of them with `-A`, and `ls -a`, where the flag shows more.

## Consequences

- The menu-bar plugin runs `trails ls -a`. It ships with trails, so the two change
  together.
- A script outside the repo that reads `trails ls` for every directory now gets only
  the directory it runs in, with no error. It needs `-a`, and the release that ships
  this has to say so in its notes.
- The TSV columns don't change, so `dir` repeats in every row of a plain `ls`.
- A directory's subdirectories are not "here". A monorepo root lists only the
  sessions started at the root. That can change later, but only together with the
  picker.
