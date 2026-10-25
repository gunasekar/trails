#!/bin/sh
# `trails server`, the tmux server for a service manager to keep running: it brings back the
# trails tmux lost with no terminal attached, leaves a server something else started alone,
# exits 1 when its server ends unasked (a kill-server, for the manager to start it again) and 0
# when it is asked to stop.
. "$REPO/test/lib.sh"
t_setup
# Already in the environment it should run in: no login shell, which would drop test/bin
# from PATH and the stub agent with it.
TRAILS_SERVER_ENV=1
export TRAILS_SERVER_ENV

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')
tmux kill-server
sleep 0.3

# Started with no client, the trail comes back: its restore is the server's first client.
"$TRAILS" server >"$T/server.log" 2>&1 &
sv=$!
wait_for 10 sh -c "[ \"\$(tmux display-message -pt '=default/payments:' '#{@trails_id}' 2>/dev/null)\" = '$id' ]" ||
  fail "nothing came back when the server started: $(cat "$T/server.log")"
wait_for 5 grep -q "restored default/payments" "$T/server.log" || fail "the restore's output is not in the service's log: $(cat "$T/server.log")"
spid=$(tmux display-message -p '#{pid}')
# Under it, for the manager to watch: its child, or the background subshell's.
p=$(ps -o ppid= -p "$spid" | tr -d ' ')
[ "$p" = "$sv" ] || [ "$(ps -o ppid= -p "$p" | tr -d ' ')" = "$sv" ] || fail "the server is not under trails server"

# A second one, with that server up, leaves it alone and exits 1: the manager tries again.
"$TRAILS" server >"$T/second.log" 2>&1
assert_eq "$?" 1 "a second server exits 1"
assert_match "$(cat "$T/second.log")" "running already" "and says why"
assert_eq "$(tmux display-message -p '#{pid}')" "$spid" "the first server untouched"

# A kill-server ends it with 1, so the manager starts it again.
tmux kill-server
wait "$sv"
assert_eq "$?" 1 "ended unasked, it exits 1"

# Asked to stop, it stops its server and exits 0.
"$TRAILS" server >"$T/third.log" 2>&1 &
sv=$!
wait_for 10 sh -c "tmux has-session -t '=default/payments' 2>/dev/null" || fail "the trail never came back the second time"
kill -TERM "$sv"
wait "$sv"
assert_eq "$?" 0 "asked to stop, it exits 0"
wait_for 5 sh -c "! tmux list-sessions >/dev/null 2>&1" || fail "its server still runs after a stop"

# Inside tmux it refuses: it is the server, not something to run in one.
out=$(TMUX=/tmp/elsewhere,1,0 "$TRAILS" server 2>&1)
assert_eq "$?" 1 "inside tmux it refuses"
assert_match "$out" "brew services start trails" "and says what it is for"
