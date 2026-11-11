#!/bin/sh
# The backtick is an alias for tmux's native floating pane, never a managed shell.
. "$REPO/test/lib.sh"
t_setup
if ! tmux list-commands | grep -q '^new-pane '; then exit 0; fi
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "terminal never attached"
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
"$TRAILS" tmux-config | tmux source-file -
tmux send-keys -t driver-1 C-b '`'
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' -F '#{pane_floating_flag}' | grep -cx 1)\" = 1 ]" || fail "no floating pane"
assert_eq "$(tmux list-panes -t "$win" -F '#{@trails_pane}' | grep -cx shell)" 0 "floating pane is not managed"
