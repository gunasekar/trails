#!/bin/sh
# A workspace in two terminals: the second on a session grouped with the workspace's
# (`tmux new-session -t ws`), which shares its windows and keeps a current window of its own.
# trails acts on the terminal that asked without pulling it out of its group, so moving
# between trails in one terminal leaves the other where it was.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/code/b"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "ws": ["~/code/*"] } }
CFG

# Two trails in ws, a and b. Terminal A is the driver that started a; b's driver goes, so
# A is the one terminal on ws.
# The terminal a driver's pane is: the client whose tty is that pane's.
term_of() { tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "$1" '#{pane_tty}')" '$2 == t { print $1 }'; }
DRIVER_DIR=$T/code/a driver "$TRAILS" new one
wait_for 5 screen_has ws/one 'agent id=' || fail "one never started"
driver_attached || fail "A never attached"
a=$(term_of driver-1)
[ -n "$a" ] || fail "no terminal A"
DRIVER_DIR=$T/code/b driver "$TRAILS" new two
wait_for 5 screen_has ws/two 'agent id=' || fail "two never started"
driver_attached || fail "two's driver never attached"
tmux kill-session -t driver-2
tmux switch-client -c "$a" -t "=ws:a·one"
wid_one=$(tmux list-windows -t ws -F '#{window_id} #{window_name}' | awk '$2 == "a·one" { print $1 }')
wid_two=$(tmux list-windows -t ws -F '#{window_id} #{window_name}' | awk '$2 == "b·two" { print $1 }')

# Terminal B: a session grouped with ws, and a client on it.
tmux new-session -d -t ws -s 'ws~2'
driver tmux attach -t 'ws~2'
wait_for 5 sh -c "tmux list-clients -t 'ws~2' | grep -q ." || fail "no terminal on ws~2"
b=$(tmux list-clients -t 'ws~2' -F '#{client_name}')
tmux select-window -t "=ws~2:$wid_one"

# Run trails for terminal B, as the key bindings `trails keys` prints do: from run-shell,
# with the terminal that pressed the key in TRAILS_CLIENT.
sock=$(tmux display-message -p '#{socket_path}')
for_b() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$b' $*"; }

# prefix P in B: its session has no workspace mark of its own, so it is read from the group.
rm -f "$T/menu"
for_b "FZF_PICK='' FZF_DUMP='$T/menu' '$TRAILS'"
wait_for 5 test -s "$T/menu" || fail "the picker never reached fzf"
assert_eq "$(grep -v '^--- ' "$T/menu" | head -n 1 | cut -f1)" browse "the workspace's screen, from the group"

# Picking trail two in B: B goes to it on its own session, and A stays on trail one.
for_b "FZF_PICK='#two' '$TRAILS'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name} #{window_id}' | awk -v c='$b' '\$1 == c { print \$2, \$3 }')\" = 'ws~2 $wid_two' ]" ||
  fail "B is not on two in its own session: $(client_at "$b" '#{session_name} #{window_id}')"
assert_eq "$(client_at "$a" '#{session_name} #{window_id}')" "ws $wid_one" "A stayed on one"

# The editor beside two, from B: opened in two's window, and B still on its own session.
for_b "EDITOR=ed '$TRAILS' edit"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$wid_two' | wc -l | tr -d ' ')\" = 2 ]" || fail "no editor beside two"
assert_eq "$(client_at "$b" '#{session_name} #{window_id}')" "ws~2 $wid_two" "B still on its own session"
assert_eq "$(client_at "$a" '#{session_name} #{window_id}')" "ws $wid_one" "and A still on one"

# A, ungrouped, picking two: switched within ws, as ever, and B is not moved.
tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$a' FZF_PICK='#two' '$TRAILS'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name} #{window_id}' | awk -v c='$a' '\$1 == c { print \$2, \$3 }')\" = 'ws $wid_two' ]" ||
  fail "A did not go to two in ws: $(client_at "$a" '#{session_name} #{window_id}')"
tmux select-window -t "=ws~2:$wid_one"
assert_eq "$(client_at "$a" '#{session_name} #{window_id}')" "ws $wid_two" "B moving leaves A on two"

# The grouped session is never a workspace of its own: not on the workspaces screen.
rm -f "$T/wmenu"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/wmenu driver "$TRAILS"
wait_for 5 test -s "$T/wmenu" || fail "the workspaces screen never reached fzf"
assert_eq "$(grep -v '^--- ' "$T/wmenu" | cut -f2 | tr '\n' ' ')" "ws " "ws once, and no ws~2"
