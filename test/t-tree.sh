#!/bin/sh
# The tree (ADR 28): prefix W, or a click on [session], lists everything worth going to on trails'
# server: each workspace with its windows (a trail's state and how
# long it has been in it, and any window of yours), then the sessions you made. Enter goes
# there. A star (prefix S, ctrl-s in the tree, trails star) marks a trail with ★, in
# its record too, so a restore keeps it.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/other/c"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"], "beta": ["~/other/*"] } }
CFG

DRIVER_DIR=$T/code/a driver "$TRAILS" new one
wait_for 5 screen_has alpha/one 'agent id=' || fail "one never started"
driver_attached || fail "the terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt driver-1 '#{pane_tty}')" '$2 == t { print $1 }')
DRIVER_DIR=$T/code/a driver "$TRAILS" new two
wait_for 5 screen_has alpha/two 'agent id=' || fail "two never started"
driver_attached || fail "two's driver never attached"
DRIVER_DIR=$T/other/c driver "$TRAILS" new three
wait_for 5 screen_has beta/three 'agent id=' || fail "three never started"
driver_attached || fail "three's driver never attached"
for d in 2 3; do tmux kill-session -t "driver-$d"; done
tmux new-window -d -t '=alpha:' -n notes 'sleep 300'
tmux new-session -d -s mine 'sleep 300'
type_in "$(tmux list-panes -t '=beta/three:' -F '#{pane_id}')" 'hook waiting'
wait_for 5 sh -c "[ \"\$(tmux show -pqv -t \"\$(tmux list-panes -t '=beta/three:' -F '#{pane_id}')\" @trails_state)\" = waiting ]" || fail "three never waiting"

drawn() { "$TRAILS" tree --rows | cut -f4 | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/ *$//'; }
tid() { tmux display-message -pt "=$1:" '#{@trails_trail}'; }

# ── What it lists, in order ──────────────────────────────────────────────────────
rows=$(drawn)
order=$(printf '%s\n' "$rows" | awk '{ print $1 }' | tr '\n' ' ')
case $order in
  "alpha one two notes beta three ── "*mine*) ;;
  *) fail "not workspaces, their windows, then yours: $order" ;;
esac
assert_match "$rows" "three +● needs you +[0-9]+m" "a trail's state, and for how long"
assert_match "$rows" "notes +yours" "a window of yours, in its workspace"
case $rows in *"alpha/"* | *"beta/"*) fail "a trail's own session listed: $rows" ;; *) ;; esac

# ── A star ──────────────────────────────────────────────────────────────────────
t2=$(tid alpha/two)
"$TRAILS" star "$t2"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" 1 "starred on its window"
assert_eq "$(grep -h '^starred=' "$STATE"/*/"$t2")" starred=1 "and in its record"
rows=$(drawn)
assert_match "$rows" "^ +two +★ ● " "two has its star, in its place"
assert_eq "$(printf '%s\n' "$rows" | grep -c '★')" 1 "once: no list of the starred of its own"

# A restore keeps it.
tmux kill-session -t '=alpha/two'
"$TRAILS" restore >/dev/null 2>&1
wait_for 10 sh -c "tmux has-session -t '=alpha/two' 2>/dev/null" || fail "two never came back"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" 1 "still starred after a restore"
assert_eq "$(tmux list-windows -t '=alpha:' -F '#{@trails_window} #{@trails_starred}' | awk '$1 == "alpha/two" { print $2 }')" 1 "its workspace window too"

# Again: off.
"$TRAILS" star "$t2"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" "" "unstarred on its window"
assert_eq "$(grep -ch '^starred=' "$STATE"/*/"$t2")" 0 "and in its record"
"$TRAILS" star ''
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" "" "an empty TRAIL stars nothing"

# ── Enter goes there ────────────────────────────────────────────────────────────
tmux switch-client -c "$term" -t '=alpha:'
sock=$(tmux display-message -p '#{socket_path}')
tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' FZF_PICK='three' '$TRAILS' tree"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" ||
  fail "Enter on three did not take the terminal to beta"
# To a window that isn't its workspace's current one: two, while alpha is on one.
tmux select-window -t "$(tmux list-windows -t '=alpha:' -F '#{window_id} #{@trails_window}' | awk '$2 == "alpha/one" { print $1 }')"
tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' FZF_PICK='[[:space:]]two[[:space:]]+●' '$TRAILS' tree"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = alpha ]" ||
  fail "Enter on two did not take the terminal to alpha"
assert_eq "$(tmux display-message -p -t '=alpha:' '#{@trails_window}')" alpha/two "and to two's window"

# ── Next: the starred trail that most wants you ─────────────────────────────────
on_term() { tmux list-clients -F '#{client_name} #{session_name} #{window_id}' | awk -v c="$term" '$1 == c { print $2 " " $3 }'; }
next() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' '$TRAILS' next"; }
wid_of() { tmux list-windows -t "=$1:" -F '#{window_id} #{@trails_window}' | awk -v t="$2" '$2 == t { print $1 }'; }
before=$(on_term)
next
sleep 0.5
assert_eq "$(on_term)" "$before" "nothing starred, next stays"
# three needs you, in beta, seen already; one is done with a turn, its bell not yet seen.
"$TRAILS" star "$(tid beta/three)"
"$TRAILS" star "$(tid alpha/one)"
a1=$(tmux list-panes -t '=alpha/one:' -F '#{pane_id}' | head -n 1)
type_in "$a1" 'hook working'
sleep 0.3
type_in "$a1" 'hook idle'
wait_for 5 sh -c "[ \"\$(tmux display-message -p -t '$(wid_of alpha alpha/one)' '#{window_bell_flag}')\" = 1 ]" || fail "one's bell never rang"
next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = '$(wid_of alpha alpha/one)' ]" ||
  fail "next did not go to one, unseen, first: $(on_term)"
next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = '$(wid_of beta beta/three)' ]" ||
  fail "next again did not go on to three: $(on_term)"
assert_eq "$(on_term | cut -d' ' -f1)" beta "in its workspace"

# ── The keys ────────────────────────────────────────────────────────────────────
"$TRAILS" keys | tmux source-file - || fail "tmux refused the keys"
assert_match "$(tmux list-keys -T prefix W)" "display-popup .* tree " "prefix W, the tree"
assert_match "$(tmux list-keys -T root MouseDown1StatusLeft)" "display-popup .* tree " "the click, the tree"
assert_match "$(tmux list-keys -T prefix S)" "run-shell .* star" "prefix S, a star"
assert_match "$(tmux list-keys -T prefix F)" "run-shell .* next" "prefix F, next"
