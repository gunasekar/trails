#!/bin/sh
# Every running trail, in every workspace, on one screen: prefix A opens it, ctrl-a reaches it
# from the other screens and Esc goes back; Enter goes to a trail, ctrl-x ends one from anywhere.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/other/c"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"], "beta": ["~/other/*"] } }
CFG

DRIVER_DIR=$T/code/a driver "$TRAILS" new t1
wait_for 5 screen_has alpha/t1 'agent id=' || fail "t1 never started"
DRIVER_DIR=$T/other/c driver "$TRAILS" new t2
wait_for 5 screen_has beta/t2 'agent id=' || fail "t2 never started"
term_of() { tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "driver-$DRIVERS" '#{pane_tty}')" '$2 == t { print $1 }'; }

# As prefix A opens it: both workspaces' trails, each with its workspace/codebase, and
# nothing else; Enter on one lands in its workspace, on its window.
rm -f "$T/d1"
DRIVER_DIR=$T FZF_DUMP=$T/d1 FZF_PICK='beta/c' driver TRAILS_PICKER=all "$TRAILS"
driver_attached || fail "the pick attached nowhere"
rows=$(sed 's/\x1b\[[0-9;]*m//g' "$T/d1")
assert_match "$rows" "alpha/a" "alpha's trail listed"
assert_match "$rows" "beta/c" "beta's trail listed"
printf '%s\n' "$rows" | grep -q 'new trail\|resume old' && fail "only running trails: $rows"
assert_eq "$(client_at "$(term_of)" '#{session_name}')" beta "landed in beta"

# ctrl-a from a codebase's screen goes to every trail; Esc there comes back to that screen.
rm -f "$T/d2"
printf 'ctrl-a\n' >"$T/keys"
printf '%s\n' '.' '!esc' >"$T/picks"
DRIVER_DIR=$T/code/a FZF_DUMP=$T/d2 FZF_KEY=$T/keys FZF_PICKS=$T/picks driver "$TRAILS"
wait_for 5 sh -c "[ \"\$(grep -c '^--- ' '$T/d2' 2>/dev/null)\" = 3 ]" || fail "not three screens: $(grep -c '^--- ' "$T/d2")"
d2=$(sed 's/\x1b\[[0-9;]*m//g' "$T/d2")
assert_match "$(printf '%s\n' "$d2" | sed -n '/^--- 2$/,/^--- 3$/p')" "beta/c" "ctrl-a: every trail"
assert_match "$(printf '%s\n' "$d2" | sed -n '/^--- 3$/,$p')" "new trail" "Esc: back on the codebase's screen"

# ctrl-x from the all-trails screen ends a trail of any directory.
wid=$(tmux list-windows -a -F '#{window_id} #{@trails_session}' | awk '$2 == "alpha/t1" { print $1 }')
(cd "$T" && TRAILS_PICKER=all "$TRAILS" --kill "$wid")
wait_for 3 sh -c "! tmux has-session -t '=alpha/t1' 2>/dev/null" || fail "ctrl-x on the all screen left alpha/t1"

# prefix A, in trails keys.
assert_match "$("$TRAILS" keys)" '^bind A display-popup .*TRAILS_PICKER=all' "prefix A bound"
