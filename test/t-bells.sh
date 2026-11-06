#!/bin/sh
# ADR 28's bells: a trail that wants you, blocked on a question or done with a turn, rings tmux's
# bell in its workspace window, which tmux flags unless it is in front of you and clears once
# opened; the status line shows, after [session], one bell and the count of those in the
# workspaces you are not in, kept by trails --wants from tmux's hooks.
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
[ -n "$term" ] || fail "no terminal"
# Each driver until its trails has attached, so the trail's workspace window exists; then gone,
# so beta is in front of no one and its bell is flagged.
DRIVER_DIR=$T/code/a driver "$TRAILS" new two
wait_for 5 screen_has alpha/two 'agent id=' || fail "two never started"
driver_attached || fail "two's driver never attached"
DRIVER_DIR=$T/other/c driver "$TRAILS" new three
wait_for 5 screen_has beta/three 'agent id=' || fail "three never started"
driver_attached || fail "three's driver never attached"
for d in 2 3; do tmux kill-session -t "driver-$d" 2>/dev/null; done
wait_for 5 sh -c "[ \"\$(tmux display-message -p -t '=beta:' '#{session_attached}')\" = 0 ]" || fail "beta still shown"

"$TRAILS" keys | tmux source-file - || fail "tmux refused the keys"
win() { tmux list-windows -t "=$1:" -F '#{window_id} #{@trails_window}' | awk -v t="$2" '$2 == t { print $1 }'; }
tmux switch-client -c "$term" -t "=alpha:"
tmux select-window -t "$(win alpha alpha/one)"
sleep 0.5
agent() { tmux list-panes -t "=$1:" -F '#{pane_id}' | head -n 1; }
flag() { tmux display-message -p -t "$(win "$1" "$2")" '#{window_bell_flag}'; }
bar() { tmux capture-pane -p -t driver-1 | tail -n 1; }

# Nothing wants you: no bell, no count.
"$TRAILS" --wants
assert_eq "$(tmux show -gv @trails_wants_all)" 0 "none at first"
case $(bar) in *󰂚*) fail "a bell with nothing waiting: $(bar)" ;; *) ;; esac

# two, in alpha but not in front of you, ends a turn: its window rings and is flagged.
type_in "$(agent alpha/two)" 'hook working'
sleep 0.3
type_in "$(agent alpha/two)" 'hook idle'
wait_for 5 sh -c "[ \"\$(tmux display-message -p -t '$(win alpha alpha/two)' '#{window_bell_flag}')\" = 1 ]" ||
  fail "two's window not flagged"
assert_eq "$(flag alpha alpha/one)" 0 "one, in front of you, not flagged"

# three, in beta, waits on you: beta's count, shown after [alpha] while you are on alpha.
type_in "$(agent beta/three)" 'hook waiting'
wait_for 5 sh -c "[ \"\$(tmux show -gv @trails_wants_all)\" = 2 ]" ||
  fail "the count never reached 2: $(tmux show -gv @trails_wants_all); $(tmux list-windows -a -F '#{session_name} bell=#{window_bell_flag}' | tr '\n' ' ')"
# Many counts at once, as a burst of hooks runs them, end in the right one.
i=0
while [ $i -lt 20 ]; do "$TRAILS" --wants & i=$((i + 1)); done
wait
assert_eq "$(tmux show -gv @trails_wants_all)" 2 "twenty counts at once still say 2"
assert_eq "$(tmux show -v -t '=alpha:' @trails_wants_here)" 1 "alpha's own: two"
assert_eq "$(tmux show -v -t '=beta:' @trails_wants_here)" 1 "beta's: three"
wait_for 5 sh -c "tmux capture-pane -p -t driver-1 | tail -n 1 | grep -q '^\\[alpha\\] 󰂚 1 '" ||
  fail "the status line does not say one elsewhere: $(bar)"

# Starred, a trail's window has ★ before its number in the window list (tmux's stock format).
"$TRAILS" star "$(tmux display-message -pt '=alpha/two:' '#{@trails_trail}')"
assert_eq "$(tmux show -wqv -t "$(win alpha alpha/two)" @trails_starred)" 1 "the star on its workspace window"
wait_for 5 sh -c "tmux capture-pane -p -t driver-1 | tail -n 1 | grep -q '★ [0-9]*:'" || fail "no star before the window's number: $(bar)"
case $(bar) in "[alpha] ★"*) fail "a star count after [alpha]: $(bar)" ;; *) ;; esac

# Opening two clears its bell; on beta, alpha's count is what is elsewhere.
tmux select-window -t "$(win alpha alpha/two)"
wait_for 5 sh -c "[ \"\$(tmux show -v -t '=alpha:' @trails_wants_here)\" = 0 ]" || fail "two's bell outlived opening it"
tmux switch-client -c "$term" -t "=beta:"
wait_for 5 sh -c "[ \"\$(tmux show -gv @trails_wants_all)\" = 0 ]" || fail "beta's bell outlived opening it: $(tmux show -gv @trails_wants_all)"
wait_for 5 sh -c "! tmux capture-pane -p -t driver-1 | tail -n 1 | grep -q '󰂚'" || fail "a bell with nothing waiting: $(bar)"
"$TRAILS" star "$(tmux display-message -pt '=alpha/two:' '#{@trails_trail}')"
assert_eq "$(tmux show -wqv -t "$(win alpha alpha/two)" @trails_starred)" "" "unstarred, off its workspace window"

# A theme's window format can show the same bell.
assert_eq "$(tmux show -gv @trails_bell)" '#{?window_bell_flag,#[fg=yellow] 󰂚,}' "@trails_bell for a theme"
assert_eq "$(tmux show -gv @trails_bell_style)" '#{?window_bell_flag,#[fg=yellow],}' "and its colour, for the window's name"
assert_eq "$(tmux show -gv @trails_star)" '#{?@trails_starred,#[fg=yellow]★ ,}' "and the star"
# A theme's window format is its own: the keys leave it be.
tmux set -g window-status-format '#I|#W'
"$TRAILS" keys | tmux source-file - || fail "tmux refused the keys again"
assert_eq "$(tmux show -gv window-status-format)" '#I|#W' "a theme's format kept"
