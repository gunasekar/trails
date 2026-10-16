#!/bin/sh
# Inside tmux (R6 in the design): the agent still gets its view and a cell in its workspace,
# and the client you are in is switched there — or, from an editor's terminal, the pane
# becomes a nested client of the trail's view, one trail and nothing else. And D1: a session
# with the workspace's name that trails did not make is refused.
. "$REPO/test/lib.sh"
t_setup

# A session of your own, with a client on it, as a terminal in tmux would be.
tmux new-session -d -s mine -c "$PROJ" -x 120 -y 40 sh
driver tmux attach -t mine
wait_for 5 sh -c 'tmux list-clients -t mine | grep -q .' || fail "no client on mine"
client=$(tmux list-clients -t mine -F '#{client_name}')
where() { client_at "$client"; }

# trails new from a shell pane: a window in default, and the client switched to it.
type_in mine "$TRAILS new payments"
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
at() { [ "$(where)" = "$1" ]; }
wait_for 5 at 'default proj·payments' || fail "the client was not switched to the trail, it is on: $(where)"
assert_eq "$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')" "default default/payments driver-1 mine " "no nested or extra sessions"

# From an editor's terminal (NVIM set): the trail is made the same way, and the pane shows it.
tmux switch-client -c "$client" -t mine
type_in mine "NVIM=1 $TRAILS new review"
wait_for 5 screen_has default/review 'agent id=' || fail "review never started"
wait_for 5 screen_has mine 'name=review' || fail "the pane did not show the trail"
assert_eq "$(client_at "$client" '#{session_name}')" mine "the client stayed in the editor's session"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "proj·payments proj·review " "both trails in the workspace"
# Two clients on the view: the cell's, and the editor's pane. Detaching the pane's leaves the cell's.
wait_for 5 sh -c "[ \"\$(tmux list-clients -t default/review | wc -l | tr -d ' ')\" = 2 ]" || fail "expected the cell's client and the pane's on the view"
inner=$(tmux list-clients -t default/review -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt mine '#{pane_tty}')" '$2 == t { print $1 }')
[ -n "$inner" ] || fail "the pane is not a client of the view"
tmux detach-client -t "$inner"
wait_for 5 sh -c "[ \"\$(tmux list-clients -t default/review | wc -l | tr -d ' ')\" = 1 ]" || fail "the pane's client lingers"

# The picker from a shell pane: picking a running trail switches the client to its window.
wait_shell mine || fail "the shell never came back"
type_in mine "FZF_PICK='#payments' $TRAILS"
wait_for 5 at 'default proj·payments' || fail "the picker did not switch to the trail, the client is on: $(where)"
assert_eq "$(tmux list-sessions -F '#{session_name}' | sort | tr '\n' ' ')" "default default/payments default/review driver-1 mine " "still no extra sessions"

# D1: a session by the workspace's name that is not a workspace is refused, and nothing is made.
mkdir -p "$T/acme"
"$TRAILS" ws add acme "$T/acme" >/dev/null 2>&1 || fail "ws add"
tmux new-session -d -s acme -c "$T/acme" sh
out=$(cd "$T/acme" && "$TRAILS" new x 2>&1)
assert_match "$out" 'a tmux session named "acme" exists and isn.t a trails workspace' "refused"
assert_eq "$(tmux list-windows -t acme -F '#{window_name}' | wc -l | tr -d ' ')" 1 "nothing added to it"
assert_no_file "$STATE/acme/x" "no record"
