#!/bin/sh
# Without lazygit, Hunk or the editor, G, H and E say so on the message line of the terminal
# that pressed them, and open no popup or pane; from a shell, on stderr, and a failure.
. "$REPO/test/lib.sh"
t_setup
(cd "$PROJ" && git init -q) || fail "no repository"
# A PATH with trails' own needs and none of the three: test/bin's stand-ins left out.
nb=$T/nobin
mkdir -p "$nb"
for c in tmux jq git; do ln -s "$(command -v "$c")" "$nb/$c"; done
bare="$nb:/usr/bin:/bin"

out=$(PATH=$bare "$TRAILS" git "$PROJ" 2>&1) && fail "trails git succeeded without lazygit"
assert_match "$out" "lazygit isn't installed" "no lazygit, said so"
out=$(PATH=$bare "$TRAILS" diff "$PROJ" 2>&1) && fail "trails diff succeeded without Hunk"
assert_match "$out" "hunk isn't installed" "no Hunk, said so"
out=$("$TRAILS" diff "$T/nosuch" 2>&1) && fail "trails diff succeeded on no directory"
assert_eq "$out" "trails: no such directory: $T/nosuch" "no directory, said once"

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "terminal never attached"
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
term=$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v w="$win" '$2 == w { print $1; exit }')
sock=$(tmux display-message -p '#{socket_path}')
key() { tmux run-shell -b "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' PATH='$bare' $1 '$TRAILS' $2"; }

key '' git
wait_for 5 screen_has driver-1 "trails: lazygit isn't installed" || fail "prefix G: no message"
key '' diff
wait_for 5 screen_has driver-1 "trails: hunk isn't installed" || fail "prefix H: no message"
key EDITOR=nosuch-editor edit
wait_for 5 screen_has driver-1 "nosuch-editor, which isn't installed" || fail "prefix E: no message"
assert_eq "$(tmux list-panes -t "$win" -F '#{@trails_pane}' | tr '\n' ' ')" 'agent ' "no pane added"
assert_eq "$(tmux list-panes -a -F '#{pane_in_mode}' | sort -u | tr '\n' ' ')" '0 ' "nothing in view mode"
