#!/bin/sh
# Every workspace on one list (ADR 30), from anywhere: each workspace's trails with their
# codebase, Enter on one lands in its workspace, ctrl-x ends one of any directory, and "↩ resume
# old trails" holds every workspace's ended trails, with a workspace/codebase column. prefix A
# and ctrl-a, which a screen of every trail needed, are gone.
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
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }

# From a codebase of alpha's: both workspaces' trails, alpha's first; Enter on beta's lands in
# beta, on its window.
rm -f "$T/d1"
DRIVER_DIR=$T/code/a FZF_DUMP=$T/d1 FZF_PICK='c·t2' driver "$TRAILS"
driver_attached || fail "the pick attached nowhere"
rows=$(plain "$T/d1")
assert_eq "$(printf '%s\n' "$rows" | grep '^workspace' | cut -f2 | tr '\n' ' ')" "alpha beta " "alpha, where you are, first"
assert_match "$rows" "a·t1 .* a +stub" "alpha's trail, with its codebase"
assert_match "$rows" "c·t2 .* c +stub" "beta's trail, with its codebase"
assert_eq "$(client_at "$(term_of)" '#{session_name}')" beta "landed in beta"

# ctrl-x from the one list ends a trail of any directory.
wid=$(tmux list-windows -a -F '#{window_id} #{@trails_session}' | awk '$2 == "alpha/t1" { print $1 }')
: >"$T/cache"
(cd "$T" && TRAILS_PICKER=one TRAILS_MENU_CACHE=$T/cache "$TRAILS" --kill "$wid")
wait_for 3 sh -c "! tmux has-session -t '=alpha/t1' 2>/dev/null" || fail "ctrl-x on the one list left alpha/t1"
# The reload after it reads the cache again: every trail left, classified, as the list reads it.
assert_eq "$(awk -F'\t' '{ print NF, $3 }' "$T/cache")" "9 beta/t2" "the cache, refreshed in the one list's shape"

# Ended trails, of two workspaces: the old list has both, each with workspace/codebase.
tmux new-session -d -s hold # the server outlives the trails' sessions
DRIVER_DIR=$T/code/a driver "$TRAILS" new t3
wait_for 5 screen_has alpha/t3 'agent id=' || fail "t3 never started"
driver_attached || fail "t3's launch never finished" # an agent gone before then "exited immediately"
for s in alpha/t3 beta/t2; do
  type_in "$s" "hook working"
  type_in "$s" "title Ended in ${s%%/*}"
  wait_for 5 sh -c "'$TRAILS' ls -a >/dev/null; grep -qx 'task=Ended in ${s%%/*}' \"\$(trec $s)\"" || fail "$s's task never reached its record"
  type_in "$s" exit
  wait_for 5 no_session "$s" || fail "$s outlived its agent"
done
rm -f "$T/d2"
printf '%s\n' 'resume old trails' '' >"$T/p2"
DRIVER_DIR=$T FZF_DUMP=$T/d2 FZF_PICKS=$T/p2 driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 2' '$T/d2'" || fail "the old list never opened: $(plain "$T/d2" | tr '\n' '|')"
assert_match "$(plain "$T/d2" | grep 'resume old trails')" '\(2 ended\)' "the row counts every workspace's"
old=$(plain "$T/d2" | sed -n '/^--- 2$/,$p' | sed 1d)
assert_match "$old" "alpha/a .*Ended in alpha" "alpha's, as alpha/a"
assert_match "$old" "beta/c .*Ended in beta" "beta's, as beta/c"

# Esc on the old list comes back to the one list.
rm -f "$T/d3"
printf '%s\n' 'resume old trails' '!esc' '' >"$T/p3"
DRIVER_DIR=$T FZF_DUMP=$T/d3 FZF_PICKS=$T/p3 driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d3'" || fail "esc never came back: $(plain "$T/d3" | tr '\n' '|')"
assert_match "$(plain "$T/d3" | sed -n '/^--- 3$/,$p' | sed -n 2p)" "new trail" "back on the one list"

# No prefix A, no ctrl-a.
"$TRAILS" tmux-config | grep -q '^bind -N "[^"]*" A ' && fail "prefix A still bound"
case $("$TRAILS" help keys) in *ctrl-a*) fail "ctrl-a still in the keys" ;; *) ;; esac
exit 0
