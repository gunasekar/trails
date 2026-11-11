#!/bin/sh
# The managed editor opens beside the agent and survives its exit.
. "$REPO/test/lib.sh"
t_setup
EDITOR='ed'
export EDITOR
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "terminal never attached"
client=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
sock=$(tmux display-message -p '#{socket_path}')
TMUX="$sock,1,0" TRAILS_CLIENT="$client" "$TRAILS" edit
wait_for 5 sh -c "tmux list-panes -t '$win' -F '#{@trails_pane}' | grep -qx editor" || fail "editor missing"
epane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
wait_for 5 screen_has "$epane" "ed in $PROJ" || fail "editor opened outside codebase"
assert_eq "$(tmux list-panes -t default/payments | wc -l | tr -d ' ')" 1 "agent session stays separate"
TMUX="$sock,1,0" TRAILS_CLIENT="$client" "$TRAILS" edit
assert_eq "$(tmux list-panes -t "$win" -F '#{@trails_pane}' | grep -cx editor)" 1 "editor is reused"
type_in default/payments exit
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$win' '#{@trails_tool} #{window_panes}')\" = 'editor 1' ]" || fail "editor did not survive agent: $(tmux display-message -pt "$win" "#{@trails_tool} #{window_panes} #{@trails_window}"), $(tmux list-panes -t "$win" -F "#{pane_id} #{@trails_pane}")"
