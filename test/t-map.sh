#!/bin/sh
# The map: a session of its own whose panes are nested clients of trails' editor views,
# most-wants-you first; and trails end / trails keys.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
mkdir -p "$T/other"
DRIVER_DIR=$T/other driver "$TRAILS" new ledger
wait_for 5 screen_has default/ledger 'agent id=' || fail "ledger never started"

# ledger asks a question, so it is the one that most wants you: pane 0 of the map.
type_in default/ledger ask
sleep 1
driver "$TRAILS" map 2
wait_for 5 has_session trails_map || fail "no map"
assert_eq "$(tmux display-message -pt trails_map '#{@trails_map}')" 1 "marked"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t trails_map | wc -l | tr -d ' ')\" = 2 ]" || fail "two panes"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default/ledger && tmux list-clients -F '#{session_name}' | grep -qx default/payments" ||
  fail "the cells are not clients of the views: $(tmux list-clients -F '#{session_name}')"
assert_eq "$(tmux display-message -pt 'trails_map:0.0' '#{@dir}')" other "pane 0 is the one that wants you"

# A killed view is rebuilt for the map.
tmux kill-session -t trails_map
tmux kill-session -t default/payments
driver "$TRAILS" map 2
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default/payments" || fail "the view was not rebuilt for the map"

# trails end, from anywhere: the window, its view and its record go.
out=$(cd "$T" && "$TRAILS" end default/payments)
assert_eq "$out" "ended default/payments" "said so"
wait_for 3 no_session default/payments || fail "the view survived"
assert_eq "$(tmux list-windows -t default -F '#{window_name}')" "other·ledger" "the window went"
assert_no_file "$STATE/default/payments" "the record went"
assert_match "$(cd "$T" && "$TRAILS" end nope 2>&1)" 'no trail nope' "unknown refused"

# trails keys prints bindings, and changes nothing.
before=$(tmux list-keys | wc -l)
assert_match "$("$TRAILS" keys)" "^bind a display-popup .* '$TRAILS'$" "the picker binding, by absolute path"
assert_eq "$(tmux list-keys | wc -l)" "$before" "nothing bound"
