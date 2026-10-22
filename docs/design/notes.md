# Notes: design

Status: implemented · 2026-10-22.

While an agent works for ten minutes or an hour, the thoughts that come up, "this
should also change", "that behaviour is wrong", get lost. They belong to the
codebase, not the trail: the trail is on something else, and the thought is
usually the start of the next one.

## Decided

| # | Question | Decision |
|---|---|---|
| N1 | What a note belongs to | The codebase, not the trail. |
| N2 | Where notes live | In the repo, at `.scratch/trails/notes.md` from the codebase's root, by default. The config's `notes` moves it: relative to the root, or `~`/absolute with `{codebase}` for its name. trails touches no ignore file: committing or ignoring is the repo's call |
| N3 | Format | A Markdown checklist. The note is the item, plain: no date or trail after it, which cluttered every line of a list kept by hand. Detail goes under it, indented |
| N4 | The key | One key, `prefix N`, a popup. `n` is tmux's next-window, and `Q` reads as quit |
| N5 | Writing a note | One line, on fzf's input line in the popup. Enter saves, Esc drops it. Detail goes in the file, under the item |
| N6 | Opening the notes | Enter on an empty line, or `trails notes`: `$EDITOR` on the file |

Two multi-line ways came first. A note box of trails' own, raw-mode input in shell
with Shift-Enter for a new line (which behind tmux arrives as plain Enter unless
the terminal sends it otherwise, as Ghostty's `shift+enter=text:\x1b\r` does), had
no cursor to move and no line to go back to. `$EDITOR` on a blank note, as git
takes a commit message, edited well but was too much for a quick thought. One
line is what a thought caught mid-trail needs.

## Not yet

- The picker shows how many open notes a codebase has, and opens them.
- Starting a trail from a note: pick one on the agents screen, and it becomes
  the trail's first prompt and its name.
