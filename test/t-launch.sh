#!/bin/sh
# trails new: a named trail gets a session of its own holding the agent, a trail's window in its
# workspace's session showing it, its options and its record; quitting the agent takes all of
# them away, and the workspace session goes when its last trail does.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 has_session default || fail "no workspace session"
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never printed"

screen=$(screen default/payments)
assert_match "$screen" 'agent id=[0-9a-f-]{36} name=payments resume=0 yolo=0' "the agent's arguments"
id=$(printf '%s\n' "$screen" | sed -n 's/.*id=\([0-9a-f-]*\) .*/\1/p' | head -n 1)

# The trail's session holds the agent's window; the workspace session is marked and holds the trail's window, a
# window named like it whose pane is a client of the session.
assert_eq "$(tmux display-message -pt default '#{@trails_workspace}')" default "@trails_workspace"
wid=$(tmux list-windows -t default/payments -F '#{window_id}')
assert_eq "$(tmux list-windows -t default/payments -F '#{window_name}')" "proj·payments" "the window, named"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}')\" = 'proj·payments' ]" || fail "no window in the workspace"
win=$(tmux list-windows -t default -F '#{window_id}')
[ "$win" != "$wid" ] || fail "the trail's window is the trail's own window"
assert_eq "$(tmux display-message -pt "$win" '#{@trails_window} #{@trails_dir} #{@trails_ws} #{@trails_label} #{@trails_pane} #{@ag} #{@dir}')" \
  "default/payments $PROJ default proj agent stub proj" "the trail's window's options"
# Its border labels the agent's pane by the agent, not by `tmux`, the command it runs.
assert_eq "$(tmux display-message -pt "$win" '#{T:pane-border-format}')" " stub " "the agent pane's border label"

# The titles are trails' own, whatever tmux.conf says (this one says nothing): a workspace
# reads "trails · <host>", a trail its agent and the title the agent gives, a leading glyph
# dropped.
assert_eq "$(tmux show-options -v -t default set-titles)" on "titles on, in the workspace"
assert_eq "$(tmux display-message -pt default '#{T:set-titles-string}')" "trails · $(tmux display-message -p '#{host_short}')" "the workspace's title"
assert_eq "$(tmux show-options -gv set-titles)" off "and nowhere else"
assert_eq "$(tmux display-message -pt default/payments '#{T:set-titles-string}')" "stub · payments ready" "a trail's"
type_in default/payments "title ✳ Fixing the flaky test"
wait_for 5 sh -c "[ \"\$(tmux display-message -pt default/payments '#{T:set-titles-string}')\" = 'stub · Fixing the flaky test' ]" ||
  fail "a trail's title, with its task: $(tmux display-message -pt default/payments '#{T:set-titles-string}')"
wait_for 5 sh -c "tmux list-clients -t default/payments -F '#{client_tty}' | grep -qx \"\$(tmux display-message -pt '$win' '#{pane_tty}')\"" ||
  fail "the trail's window's pane is not a client of the session"
assert_eq "$(tmux show-options -t default/payments -v status)" off "the session has no status line"
opts() { tmux display-message -pt "$wid" "$1"; }
assert_eq "$(opts '#{@agent}')" stub "@agent"
assert_eq "$(opts '#{@trails_id}')" "$id" "@trails_id"
assert_eq "$(opts '#{@trails_dir}')" "$PROJ" "@trails_dir"
assert_eq "$(opts '#{@trails_ws}')" default "@trails_ws"
assert_eq "$(opts '#{@trails_session}')" default/payments "@trails_session"
assert_eq "$(opts '#{@trails_label}')" proj "@trails_label"
assert_eq "$(opts '#{@trails_name}')" payments "@trails_name"
assert_match "$(opts '#{@trails_since}')" '^[0-9]{10}$' "@trails_since"

# The driver landed in the workspace, on that window (after BOOT, so wait for it).
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default" || fail "the driver never attached"
client=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
assert_eq "$(client_at "$client" '#{session_name} #{window_id}')" "default $win" "attached to the workspace, on the trail's window"

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
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')\" = 'proj·fast proj·payments ' ]" || fail "two windows: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"

# Quitting forgets: the session goes, the trail's window's client with it and so the trail's window, and the record.
type_in default/payments exit
wait_for 5 no_session default/payments || fail "the session outlived its agent"
wait_for 2 test ! -e "$rec" || fail "record outlived its agent"
wait_for 5 sh -c "[ \"\$(tmux list-windows -t default -F '#{window_name}')\" = 'proj·fast' ]" || fail "the trail's window outlived its agent, or the other went: $(tmux list-windows -t default -F '#{window_name}' | tr '\n' ' ')"
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
wait_for 5 sh -c "[ \"\$(tmux list-windows -t lattiq -F '#{window_name}')\" = 'augur·api' ]" || fail "no window in lattiq"
assert_file "$STATE/lattiq/api" "the record under the workspace"

# A directory no workspace claims runs in default, and says so. (Run off a terminal, the
# attach at the end fails; the trail is up by then.)
out=$(cd "$PROJ" && "$TRAILS" new stray 2>&1)
assert_match "$out" 'no workspace claims ~/proj — running in "default"' "the unclaimed directory is said"
wait_for 5 screen_has default/stray 'agent id=' || fail "stray never started"
