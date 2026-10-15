#!/bin/sh
# D4 in docs/design/trails-1.0.md: a command run inside display-popup can see the tmux
# server ($TMUX) and act on the client that opened the popup (switch-client). That is what
# lets the picker run in a popup and switch workspaces from there.
. "$REPO/test/lib.sh"
t_setup

tmux new-session -d -s w 'sleep 60'
tmux new-session -d -s other 'sleep 60'
driver tmux attach -t w
wait_for 5 sh -c 'tmux list-clients | grep -q .' || fail "no client attached"
client=$(tmux list-clients -F '#{client_name}')

tmux display-popup -c "$client" -E "sh -c 'echo TMUX=\$TMUX > $T/out; tmux switch-client -t other; echo rc=\$? >> $T/out'"
wait_for 3 grep -q rc= "$T/out" || fail "popup never wrote its result"

assert_match "$(cat "$T/out")" "^TMUX=$T/tmux-[0-9]+/default,[0-9]+,[0-9]+$" "TMUX inside the popup"
assert_match "$(cat "$T/out")" "rc=0" "switch-client from the popup"
assert_eq "$(client_at "$client" '#{session_name}')" other "the client switched"
