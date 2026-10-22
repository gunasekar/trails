#!/bin/sh
# The map: a session of its own whose panes are nested clients of trails' sessions,
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
  fail "the windows are not clients of the sessions: $(tmux list-clients -F '#{session_name}')"
assert_eq "$(tmux display-message -pt 'trails_map:0.0' '#{@dir}')" other "pane 0 is the one that wants you"

# A killed trail's window changes nothing for the map: the trail lives in its session.
tmux kill-session -t trails_map
tmux kill-window -t "$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')"
driver "$TRAILS" map 2
wait_for 5 has_session trails_map || fail "no second map"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t trails_map | wc -l | tr -d ' ')\" = 2 ]" || fail "two panes in the second map"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default/payments" || fail "the map lost the trail with its window"

# Two in a 120-column terminal stack by default; map.two "side" in the config puts them side
# by side regardless.
assert_eq "$(tmux list-panes -t trails_map -F '#{pane_left}' | sort -u | wc -l | tr -d ' ')" 1 "stacked under 160 columns"
jq '. + { map: { two: "side" } }' "$XDG_CONFIG_HOME/trails/config.json" >"$T/cfg" && mv "$T/cfg" "$XDG_CONFIG_HOME/trails/config.json"
tmux kill-session -t trails_map
driver "$TRAILS" map 2
wait_for 5 sh -c "[ \"\$(tmux list-panes -t trails_map | wc -l | tr -d ' ')\" = 2 ]" || fail "no map with map.two"
assert_eq "$(tmux list-panes -t trails_map -F '#{pane_top}' | sort -u | wc -l | tr -d ' ')" 1 "side by side when the config says so"

# trails end, from anywhere: the agent's window, its session and its record go, and the
# trail's window, with a shell beside the agent, is kept as the codebase's shell window.
driver "$TRAILS" shell "$PROJ"
pwin() { tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }'; }
wait_for 5 sh -c "[ \"\$(tmux list-panes -t \"\$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '\$2 == \"default/payments\" { print \$1 }')\" | wc -l | tr -d ' ')\" = 2 ]" || fail "no shell beside payments"
pw=$(pwin)
# With no locale at all, as a launchd job runs: a tmux client in the C locale rewrites
# the tab between two fields as `_`, and the trail could not be found to end.
out=$(cd "$T" && env -u LANG -u LC_ALL -u LC_CTYPE "$TRAILS" end default/payments)
assert_eq "$out" "ended default/payments" "said so"
wait_for 3 no_session default/payments || fail "the session survived"
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$pw' '#{window_name} #{@trails_tool} #{window_panes}')\" = 'proj·shell shell 1' ]" || fail "the trail's window was not released: $(tmux display-message -pt "$pw" '#{window_name} #{@trails_window} #{@trails_tool} #{window_panes}')"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "other·ledger proj·shell " "the windows"
assert_no_file "$STATE/default/payments" "the record went"
assert_match "$(cd "$T" && "$TRAILS" end nope 2>&1)" 'no trail nope' "unknown refused"

# trails open KEY, from anywhere: the terminal lands in the workspace on the trail's window.
driver "$TRAILS" open default/ledger
driver_attached || fail "open never attached"
assert_eq "$(client_at "$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "driver-$DRIVERS" '#{pane_tty}')" '$2 == t { print $1 }')")" 'default other·ledger' "open landed on the trail's window"
assert_match "$(cd "$T" && "$TRAILS" open default/nope 2>&1)" 'gone' "an unknown trail refused"
assert_match "$(cd "$T" && "$TRAILS" open nope 2>&1)" 'no trail nope' "a key that names no trail refused"

# trails keys prints bindings, and changes nothing.
before=$(tmux list-keys | wc -l)
assert_match "$("$TRAILS" keys)" "^bind P display-popup .* \"'$TRAILS' [|][|] .*press enter to close.*\"$" "the picker binding, by absolute path, waiting on a failure"
# Every line is one tmux takes, on a server of its own.
"$TRAILS" keys | grep '^bind' >"$T/keys.conf"
tmux -L keyscheck -f /dev/null new-session -d 'sleep 10'
assert_eq "$(tmux -L keyscheck source-file "$T/keys.conf" 2>&1)" "" "tmux takes every line"
tmux -L keyscheck kill-server 2>/dev/null
assert_match "$("$TRAILS" keys)" "^bind e run-shell \"TRAILS_CLIENT=#{client_name} '$TRAILS' edit\"$" "the editor binding names the pressing client"
case $(tmux -V) in
  "tmux 3."[0-7]*) assert_match "$("$TRAILS" keys)" 'bind P .* -s bg=default ' "default is the terminal's before 3.8" ;;
  *) assert_match "$("$TRAILS" keys)" 'bind P .* -s bg=terminal ' "terminal is the terminal's from 3.8" ;;
esac
assert_eq "$(tmux list-keys | wc -l)" "$before" "nothing bound"
