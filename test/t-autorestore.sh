#!/bin/sh
# The opt-in line `trails keys` offers: a tmux that starts with it in its config brings back
# the trails it lost, with nothing typed.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')
tmux kill-server
sleep 0.3
assert_file "$STATE/default/payments" "the record survives"

# The line, as `trails keys` prints it, uncommented into a tmux.conf.
line=$("$TRAILS" keys | sed -n 's/^# \(run-shell -b .* restore .*\)$/\1/p')
assert_match "$line" "restore" "trails keys offers the line"
printf '%s\n' "$line" >"$T/auto.conf"
tmux -f "$T/auto.conf" new-session -d -s mine 'sleep 60'
wait_for 10 sh -c "tmux has-session -t '=default/payments' 2>/dev/null" || fail "nothing came back when tmux started"
assert_eq "$(tmux display-message -pt '=default/payments:' '#{@trails_id}')" "$id" "back on its conversation"

# On another tmux server started with the same line, the trails of the first are not lost:
# nothing is started there, and the first's trail runs on, alone.
tmux -L other -f "$T/auto.conf" new-session -d -s theirs 'sleep 60'
sleep 3
assert_eq "$(tmux -L other list-sessions -F '#{session_name}' | tr '\n' ' ')" "theirs " "nothing restored on another server"
assert_eq "$(tmux list-sessions -F '#{session_name}' | grep -c '^default/payments$')" 1 "the trail still runs once, where it was"
tmux -L other kill-server 2>/dev/null
