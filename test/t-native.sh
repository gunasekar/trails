#!/bin/sh
# ADR 28's first part: trails' server as tmux shows it. The status line's left is tmux's own
# [session], a click on it opens the workspaces; closing a session's last window moves the
# terminal to a workspace rather than out of tmux, while a trail that ends still lets go of the
# client inside its workspace window; and a trail's state carries when it last changed.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"] } }
CFG

DRIVER_DIR=$T/code/a driver "$TRAILS" new one
wait_for 5 screen_has alpha/one 'agent id=' || fail "one never started"
driver_attached || fail "the terminal never attached"

# ── The keys ────────────────────────────────────────────────────────────────────
"$TRAILS" keys | tmux source-file - || fail "tmux refused the keys"
assert_eq "$(tmux show -gv status-left)" '[#{?@trails_map,▦ map,#{session_name}}] ' "status-left is tmux's [session]"
assert_match "$(tmux list-keys -T root MouseDown1StatusLeft)" "display-popup .* ws " "a click on it opens the workspaces"
assert_eq "$(tmux show -gv detach-on-destroy)" no-detached "the server moves a terminal on, not out"

# ── A trail's session lets go of its nested client ─────────────────────────────
assert_eq "$(tmux show -v -t '=alpha/one:' detach-on-destroy)" on "a trail's session keeps on, from launch"
tmux set -u -t '=alpha/one:' detach-on-destroy
"$TRAILS" --hold
assert_eq "$(tmux show -v -t '=alpha/one:' detach-on-destroy)" on "--hold sets it on a trail made before"

# ── Closing the last window of a session of yours ──────────────────────────────
# The first terminal goes; a second one, on a server of its own, is the terminal from here.
tmux kill-session -t driver-1
sock=$(tmux display-message -p '#{socket_path}')
tmux -L viewer new-session -d -x 120 -y 30 "env -u TMUX tmux -S '$sock' new-session -s mine 'sleep 300'"
wait_for 5 sh -c "tmux has-session -t =mine 2>/dev/null" || fail "mine never started"
vtty=$(tmux -L viewer display-message -p '#{pane_tty}')
on_view() { tmux list-clients -F '#{client_tty} #{session_name}' | awk -v t="$vtty" '$1 == t { print $2 }'; }
wait_for 5 sh -c "[ -n \"\$(tmux list-clients -F '#{client_tty}' | grep -x '$vtty')\" ]" || fail "the terminal never attached to mine"
tmux kill-window -t '=mine:'
wait_for 5 sh -c "! tmux has-session -t =mine 2>/dev/null" || fail "mine outlived its window"
sleep 0.5
assert_eq "$(on_view)" alpha "moved to the workspace, not out of tmux"

# ── A trail that ends ───────────────────────────────────────────────────────────
# Its session goes; the client in its workspace window exits with it, rather than being moved
# to some other session inside that window.
wtty=$(tmux list-panes -t '=alpha:' -F '#{pane_tty}' | head -n 1)
tmux list-clients -F '#{client_tty} #{session_name}' | grep -q "^$wtty alpha/one$" || fail "no nested client for one"
tmux kill-session -t '=alpha/one'
sleep 1
assert_eq "$(tmux list-clients -F '#{client_tty}' | grep -cx "$wtty")" 0 "the nested client let go"

# ── When the state last changed ────────────────────────────────────────────────
DRIVER_DIR=$T/code/a driver "$TRAILS" new two
wait_for 5 screen_has alpha/two 'agent id=' || fail "two never started"
agent=$(tmux list-panes -t '=alpha/two:' -F '#{pane_id}' | head -n 1)
at() { tmux show -pqv -t "$agent" @trails_state_at; }
type_in "$agent" 'hook working'
wait_for 5 sh -c "[ \"\$(tmux show -pqv -t '$agent' @trails_state)\" = working ]" || fail "never working"
t1=$(at)
[ -n "$t1" ] || fail "no @trails_state_at"
sleep 1.2
type_in "$agent" 'hook working'
sleep 0.5
assert_eq "$(at)" "$t1" "the same word again keeps the time"
type_in "$agent" 'hook idle'
wait_for 5 sh -c "[ \"\$(tmux show -pqv -t '$agent' @trails_state)\" = idle ]" || fail "never idle"
[ "$(at)" -gt "$t1" ] || fail "a new word did not move the time: $(at) vs $t1"
