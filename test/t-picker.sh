#!/bin/sh
# The picker, driven through the stub fzf: the rows it draws, a new trail from a row, a
# name typed after ctrl-n, and rejoining a running session.
. "$REPO/test/lib.sh"
t_setup

# The rows as fzf receives them: open the picker, have the stub fzf copy its input and
# press Esc. Not `--print-menu` on its own, which never sees the running sessions — the
# dispatch classifies those into a cache before fzf starts.
menu() {
  rm -f "$T/menu"
  FZF_PICK='' FZF_DUMP=$T/menu trails_bg
  wait_for 5 test -s "$T/menu" || fail "the picker never reached fzf"
  sed 's/\x1b\[[0-9;]*m//g' "$T/menu"
}

# Nothing running: one "new trail" row per agent, the default agent first.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | cut -f1,2 | tr '\t\n' '  ')" "new stub new other " "new rows only"
assert_match "$(printf '%s\n' "$rows" | head -n 1 | cut -f3)" 'stub · new trail' "the drawn row"

# Enter on "stub · new trail" starts one, named after the directory.
FZF_PICK='stub · new trail' trails_bg
wait_for 5 has_session trails-proj || fail "no session trails-proj"
wait_for 5 screen_has trails-proj 'agent id=' || fail "agent never started"

# It is now an attach row, above the new rows.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | head -n 1 | cut -f1,2)" "attach	trails-proj" "attach row first"
assert_match "$(printf '%s\n' "$rows" | head -n 1 | cut -f3)" '● (your turn|working) +stub' "drawn with its state"

# ctrl-n, a name, Enter on a new row: the trail takes the name.
FZF_KEYS=ctrl-n FZF_QUERY=billing FZF_PICK='stub · new trail' trails_bg
wait_for 5 has_session trails-billing || fail "no session trails-billing"
wait_for 5 screen_has trails-billing 'name=billing' || fail "the name never reached the agent"

# Esc starts nothing.
before=$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')
FZF_PICK='' trails_bg
sleep 2
assert_eq "$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')" "$before" "Esc leaves sessions alone"
