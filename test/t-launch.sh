#!/bin/sh
# trails new: a named trail gets a window in its workspace's session, an editor view of its
# own, its options and its record; quitting the agent takes all of them away, and the
# workspace session goes when its last trail does.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 has_session default || fail "no workspace session"
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never printed"

screen=$(screen default/payments)
assert_match "$screen" 'agent id=[0-9a-f-]{36} name=payments resume=0 yolo=0' "the agent's arguments"
id=$(printf '%s\n' "$screen" | sed -n 's/.*id=\([0-9a-f-]*\) .*/\1/p' | head -n 1)

# The workspace session is marked, holds the trail's window, and the view holds the same one.
assert_eq "$(tmux display-message -pt default '#{@trails_workspace}')" default "@trails_workspace"
assert_eq "$(tmux list-windows -t default -F '#{window_name}')" "proj·payments" "the window, named"
wid=$(tmux list-windows -t default -F '#{window_id}')
assert_eq "$(tmux list-windows -t default/payments -F '#{window_id}')" "$wid" "the view holds the same window"
opts() { tmux display-message -pt "$wid" "$1"; }
assert_eq "$(opts '#{@agent}')" stub "@agent"
assert_eq "$(opts '#{@trails_id}')" "$id" "@trails_id"
assert_eq "$(opts '#{@trails_dir}')" "$PROJ" "@trails_dir"
assert_eq "$(opts '#{@trails_ws}')" default "@trails_ws"
assert_eq "$(opts '#{@trails_view}')" default/payments "@trails_view"
assert_eq "$(opts '#{@trails_label}')" proj "@trails_label"
assert_eq "$(opts '#{@trails_name}')" payments "@trails_name"
assert_match "$(opts '#{@trails_since}')" '^[0-9]{10}$' "@trails_since"

# The driver landed in the workspace, on that window (after BOOT, so wait for it).
wait_for 5 sh -c 'tmux list-clients | grep -q .' || fail "the driver never attached"
client=$(tmux list-clients -F '#{client_name}' | head -n 1)
assert_eq "$(client_at "$client" '#{session_name} #{window_id}')" "default $wid" "attached to the workspace, window selected"

rec=$STATE/default/payments
assert_file "$rec" "the record"
assert_eq "$(sed -n 's/^agent=//p' "$rec")" stub "record agent"
assert_eq "$(sed -n 's/^dir=//p' "$rec")" "$PROJ" "record dir"
assert_eq "$(sed -n 's/^id=//p' "$rec")" "$id" "record id"
assert_eq "$(sed -n 's/^workspace=//p' "$rec")" default "record workspace"
assert_eq "$(sed -n 's/^label=//p' "$rec")" proj "record label"
assert_eq "$(sed -n 's/^name=//p' "$rec")" payments "record name"

# A second trail named the same is refused.
out=$(cd "$PROJ" && "$TRAILS" new payments 2>&1)
assert_match "$out" "payments.*(taken|in use|already)" "a taken name is refused"

# YOLO, and the other agent: a second window in the same session.
trails_bg new fast other -y
wait_for 5 screen_has default/fast 'agent (other)' || fail "the other agent never started"
assert_match "$(screen default/fast)" 'yolo=1' "yolo flag passed"
assert_eq "$(tmux display-message -pt default/fast '#{@agent}')" "other (YOLO)" "@agent with YOLO"
assert_eq "$(sed -n 's/^yolo=//p' "$STATE/default/fast")" yolo "record yolo"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "proj·fast proj·payments " "two windows"

# Quitting forgets: the window leaves the workspace and its view, and the record goes.
type_in default/payments exit
wait_for 5 no_session default/payments || fail "the view outlived its agent"
wait_for 2 test ! -e "$rec" || fail "record outlived its agent"
assert_eq "$(tmux list-windows -t default -F '#{window_name}')" "proj·fast" "the other window stays"
assert_file "$STATE/default/fast" "the other record stays"

# The last trail out takes the workspace session with it: nothing is left behind.
type_in default/fast exit
wait_for 5 no_session default || fail "an empty workspace session was left behind"

# A configured workspace: the trail lands in its session, under the codebase's label.
mkdir -p "$T/work/lattiq/augur"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "agents": [ { "name": "stub", "program": "agent", "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "lattiq": ["~/work/lattiq/*"] } }
CFG
DRIVER_DIR=$T/work/lattiq/augur driver "$TRAILS" new api
wait_for 5 screen_has lattiq/api 'agent id=' || fail "no trail in lattiq"
assert_eq "$(tmux list-windows -t lattiq -F '#{window_name}')" "augur·api" "the window, in the workspace"
assert_file "$STATE/lattiq/api" "the record under the workspace"

# A directory no workspace claims runs in default, and says so. (Run off a terminal, the
# attach at the end fails; the trail is up by then.)
out=$(cd "$PROJ" && "$TRAILS" new stray 2>&1)
assert_match "$out" 'no workspace claims ~/proj — running in "default"' "the unclaimed directory is said"
wait_for 5 screen_has default/stray 'agent id=' || fail "stray never started"
