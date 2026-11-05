#!/bin/sh
# `trails boot`, which starts the tmux server for a service manager to keep running: it brings back the
# trails tmux lost with no terminal attached, leaves a server something else started alone,
# exits 1 when its server ends unasked (a kill-server, for the manager to start it again) and 0
# when it is asked to stop.
. "$REPO/test/lib.sh"
t_setup
# Already in the environment it should run in: no login shell, which would drop test/bin
# from PATH and the stub agent with it.
TRAILS_BOOT_ENV=1
export TRAILS_BOOT_ENV

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')
tmux kill-server
sleep 0.3

# Started with no client, the trail comes back: its restore is the server's first client.
"$TRAILS" boot >"$T/server.log" 2>&1 &
sv=$!
wait_for 10 sh -c "[ \"\$(tmux display-message -pt '=default/payments:' '#{@trails_id}' 2>/dev/null)\" = '$id' ]" ||
  fail "nothing came back when the server started: $(cat "$T/server.log")"
wait_for 5 grep -q "restored default/payments" "$T/server.log" || fail "the restore's output is not in the service's log: $(cat "$T/server.log")"
spid=$(tmux display-message -p '#{pid}')
# Under it, for the manager to watch: its child, or the background subshell's.
p=$(ps -o ppid= -p "$spid" | tr -d ' ')
[ "$p" = "$sv" ] || [ "$(ps -o ppid= -p "$p" | tr -d ' ')" = "$sv" ] || fail "the server is not under trails boot"

# A second one, with that server up, leaves it alone and exits 1: the manager tries again.
"$TRAILS" boot >"$T/second.log" 2>&1
assert_eq "$?" 1 "a second server exits 1"
assert_match "$(cat "$T/second.log")" "something else started holds the socket" "and says why"
assert_eq "$(tmux display-message -p '#{pid}')" "$spid" "the first server untouched"
# Again, and it says nothing: the log has the stretch once, from when it began, not a line per
# try (the manager tries every few seconds).
"$TRAILS" boot >"$T/again.log" 2>&1
assert_eq "$?" 1 "tried again, it still exits 1"
assert_eq "$(cat "$T/again.log")" "" "and logs nothing the second time"

# A kill-server ends it with 1, so the manager starts it again.
tmux kill-server
wait "$sv"
assert_eq "$?" 1 "ended unasked, it exits 1"

# Asked to stop, it stops its server and exits 0. Having started one, it logs a stretch of
# refusals afresh next time.
"$TRAILS" boot >"$T/third.log" 2>&1 &
sv=$!
wait_for 10 sh -c "tmux has-session -t '=default/payments' 2>/dev/null" || fail "the trail never came back the second time"
"$TRAILS" boot >"$T/fourth.log" 2>&1
assert_match "$(cat "$T/fourth.log")" "holds the socket" "a new stretch is logged again"
kill -TERM "$sv"
wait "$sv"
assert_eq "$?" 0 "asked to stop, it exits 0"
wait_for 5 sh -c "! tmux list-sessions >/dev/null 2>&1" || fail "its server still runs after a stop"

# Inside trails' own server it refuses: it is that server, not something to run in one.
# A TMUX pointing at another socket is cleared first, so boot can still start ours.
out=$(TMUX="$(printf '%s/tmux-%s/%s' "$TMUX_TMPDIR" "$(id -u)" "$TRAILS_SOCKET"),1,0" "$TRAILS" boot 2>&1)
assert_eq "$?" 1 "inside trails' tmux it refuses"
assert_match "$out" "brew services start trails" "and says what it is for"
