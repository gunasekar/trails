#!/bin/sh
# Hunk opens in a popup on a trail, including when the editor is open.
. "$REPO/test/lib.sh"
t_setup
(cd "$PROJ" && git init -q && echo one >a && git add a && git -c user.email=t@t -c user.name=t commit -qm init && echo two >a) || fail "no repository"
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "terminal never attached"
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
term=$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v w="$win" '$2 == w { print $1; exit }')
sock=$(tmux display-message -p '#{socket_path}')
show_diff() { tmux run-shell -b "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' '$TRAILS' diff"; }
show_diff
wait_for 5 screen_has driver-1 "hunk diff --watch in $PROJ context=99999 graphics=false" || fail "Hunk popup missing"
assert_eq "$(tmux list-panes -t "$win" -F '#{@trails_pane}' | tr '\n' ' ')" 'agent ' "popup adds no split pane"
tmux send-keys -t driver-1 q Enter
wait_for 5 sh -c "! tmux capture-pane -pt driver-1 | grep -q 'hunk diff --watch'" || fail "Hunk popup did not close"
EDITOR=ed TMUX="$sock,1,0" TRAILS_CLIENT="$term" "$TRAILS" edit
show_diff
wait_for 5 screen_has driver-1 "hunk diff --watch in $PROJ context=99999 graphics=false" || fail "Hunk popup missing with editor"
assert_eq "$(tmux list-panes -t "$win" -F '#{@trails_pane}' | sort | tr '\n' ' ')" 'agent editor ' "editor remains beside agent"
