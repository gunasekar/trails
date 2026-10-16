#!/bin/sh
# The picker, driven through the stub fzf: the rows it draws, a new trail from a row, a
# name typed after ctrl-n, and rejoining a running trail.
. "$REPO/test/lib.sh"
t_setup

# The rows as fzf receives them: open the picker, have the stub fzf copy its input and
# press Esc. Not `--print-menu` on its own, which never sees the running trails — the
# dispatch classifies those into a cache before fzf starts.
menu() {
  rm -f "$T/menu"
  FZF_PICK='' FZF_DUMP=$T/menu trails_bg
  wait_for 5 test -s "$T/menu" || fail "the picker never reached fzf"
  sed 's/\x1b\[[0-9;]*m//g' "$T/menu" | grep -v '^--- '
}

# Nothing running: one "new trail" row per agent, the default agent first.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | cut -f1,2 | tr '\t\n' '  ')" "new stub new other " "new rows only"
assert_match "$(printf '%s\n' "$rows" | head -n 1 | cut -f3)" 'stub · new trail' "the drawn row"

# Enter on "stub · new trail" starts one: the window proj·stub in default, the view default/proj.
FZF_PICK='stub · new trail' trails_bg
wait_for 5 has_session default/proj || fail "no view default/proj"
wait_for 5 screen_has default/proj 'agent id=' || fail "agent never started"
assert_eq "$(tmux list-windows -t default -F '#{window_name}')" "proj·stub" "the window"
wid=$(tmux display-message -pt default/proj '#{window_id}')

# It is now an attach row, above the new rows, targeting its window.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | head -n 1 | cut -f1,2)" "attach	$wid" "attach row first"
assert_match "$(printf '%s\n' "$rows" | head -n 1 | cut -f3)" '● (your turn|working) +stub' "drawn with its state"

# A second unnamed trail here is the -2 sibling, and wears #2.
FZF_PICK='stub · new trail' trails_bg
wait_for 5 has_session default/proj-2 || fail "no view default/proj-2"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')\" = 'proj·stub proj·stub-2 ' ]" || fail "no sibling cell: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"
rows=$(menu)
assert_match "$(printf '%s\n' "$rows" | grep -c '^attach')" '^2$' "two attach rows"
assert_match "$(printf '%s\n' "$rows" | grep '^attach' | cut -f3 | tr '\n' '|')" '#2' "the #2 badge"

# Enter on an attach row lands in the workspace with that window selected.
FZF_PICK='#2' trails_bg
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -q 'default proj·stub-2'" ||
  fail "picking a running trail did not attach to it"

# ctrl-n, a name, Enter on a new row: the trail takes the name.
FZF_KEYS=ctrl-n FZF_QUERY=billing FZF_PICK='stub · new trail' trails_bg
wait_for 5 has_session default/billing || fail "no view default/billing"
wait_for 5 screen_has default/billing 'name=billing' || fail "the name never reached the agent"

# ctrl-x on a running row ends it: window, view and record.
wid2=$(tmux display-message -pt default/proj-2 '#{window_id}')
(cd "$PROJ" && "$TRAILS" --kill "$wid2")
wait_for 3 no_session default/proj-2 || fail "ctrl-x left the view"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')\" = 'proj·billing proj·stub ' ]" || fail "the cell stayed: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"
assert_no_file "$STATE/default/proj-2" "the record went"

# Esc starts nothing.
before=$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')
FZF_PICK='' trails_bg
sleep 2
assert_eq "$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')" "$before" "Esc leaves sessions alone"
