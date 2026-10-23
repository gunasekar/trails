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

# Nothing running: "＋ new trail…" alone.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ')" "agents " "only the way to a new trail"
assert_eq "$(printf '%s\n' "$rows" | head -n 1 | cut -f3)" '＋ new trail…' "the drawn row"

# It leads to one "new trail" row per agent, the default agent first, and Esc there comes back.
rm -f "$T/agents"
printf '%s\n' '^agents' '!esc' >"$T/pa"
FZF_PICKS=$T/pa FZF_DUMP=$T/agents trails_bg
wait_for 5 sh -c "grep -q '^--- 3' '$T/agents'" || fail "esc on the agents never came back: $(tr '\n' '|' <"$T/agents")"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/agents" | awk '/^--- /{n=$2;next} n==2' | cut -f1,2 | tr '\t\n' '  ')" "new stub new other " "the agents"
assert_eq "$(awk '/^--- /{n=$2;next} n==3' "$T/agents" | cut -f1 | head -n 1)" agents "back on the codebase's screen"

# Through both screens, "＋ new trail…" then "stub · new trail".
NEW='^agents	|stub · new trail'

# Enter on "＋ new trail…", then "stub · new trail", starts one: the window proj in default, the session default/proj.
FZF_PICK="$NEW" trails_bg
wait_for 5 has_session default/proj || fail "no session default/proj"
wait_for 5 screen_has default/proj 'agent id=' || fail "agent never started"
assert_eq "$(tmux list-windows -t default -F '#{window_name}')" "proj" "the window"
wid=$(tmux display-message -pt default/proj '#{window_id}')

# It is now an attach row, under "＋ new trail…", targeting its window.
rows=$(menu)
assert_eq "$(printf '%s\n' "$rows" | sed -n 2p | cut -f1,2)" "attach	$wid" "attach row under the new one"
assert_match "$(printf '%s\n' "$rows" | sed -n 2p | cut -f3)" '● (your turn|working) +stub' "drawn with its state"

# A second unnamed trail here is the -2 sibling, and wears #2.
FZF_PICK="$NEW" trails_bg
wait_for 5 has_session default/proj-2 || fail "no session default/proj-2"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')\" = 'proj proj-2 ' ]" || fail "no sibling window: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"
rows=$(menu)
assert_match "$(printf '%s\n' "$rows" | grep -c '^attach')" '^2$' "two attach rows"
assert_match "$(printf '%s\n' "$rows" | grep '^attach' | cut -f3 | tr '\n' '|')" '#2' "the #2 badge"

# Enter on an attach row lands in the workspace with that window selected.
FZF_PICK='#2' trails_bg
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -q 'default proj-2'" ||
  fail "picking a running trail did not attach to it"

# ctrl-n, a name, Enter on an agent's row: the trail takes the name.
FZF_KEYS=ctrl-n FZF_QUERY=billing FZF_PICK="$NEW" trails_bg
wait_for 5 has_session default/billing || fail "no session default/billing"
wait_for 5 screen_has default/billing 'name=billing' || fail "the name never reached the agent"

# ctrl-x on a running row ends it: window, session and record.
wid2=$(tmux display-message -pt default/proj-2 '#{window_id}')
(cd "$PROJ" && "$TRAILS" --kill "$wid2")
wait_for 3 no_session default/proj-2 || fail "ctrl-x left the session"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')\" = 'proj proj·billing ' ]" || fail "the trail's window stayed: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"
assert_no_file "$STATE/default/proj-2" "the record went"

# Esc starts nothing. The test's own driver terminals come and go (the one attached to the
# trail ctrl-x just ended closes in its own time), so only the rest are compared.
trail_sessions() { tmux list-sessions -F '#{session_name}' | grep -v '^driver-' | sort | tr '\n' ' '; }
before=$(trail_sessions)
FZF_PICK='' trails_bg
sleep 2
assert_eq "$(trail_sessions)" "$before" "Esc leaves sessions alone"

# A codebase whose name holds an apostrophe: its key goes into the trail's window's pane
# command, which is a shell line, and must survive it.
mkdir -p "$T/it's"
DRIVER_DIR="$T/it's" FZF_PICK="$NEW" FZF_QUERY='' FZF_KEY='' FZF_KEYS='' trails_bg
wait_for 5 has_session "default/it's" || fail "no session for it's: $(tmux capture-pane -pS- -t "driver-$DRIVERS" 2>&1 | grep -v '^$' | tail -4 | tr '\n' '|')"
wait_for 5 screen_has "default/it's" 'agent id=' || fail "the agent never started in it's"
qwin() { tmux list-windows -t default -F '#{@trails_window}' | grep -qxF "default/it's"; }
qcli() { [ "$(tmux list-clients -t "=default/it's" 2>/dev/null | wc -l | tr -d ' ')" -ge 1 ]; }
wait_for 5 qwin || fail "no trail's window for it's"
wait_for 5 qcli || fail "the window's pane is not a client of the session"

