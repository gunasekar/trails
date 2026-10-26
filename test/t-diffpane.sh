#!/bin/sh
# The diff beside the agent (ADR 25): never by itself, at any width; prefix G puts Hunk on a
# trail's right side, remembered across resizes; it gives way to the editor and comes back after
# it; prefix G again, or quitting it, puts it away for good.
. "$REPO/test/lib.sh"
t_setup

# A git repository with a change in it: the diff is only for one.
(cd "$PROJ" && git init -q && echo one >a.txt && git add a.txt &&
  git -c user.email=t@t -c user.name=t commit -qm init && echo two >a.txt) || fail "no repository"

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
driver_attached || fail "never attached"
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
[ -n "$win" ] || fail "no trail's window"
panes() { tmux list-panes -t "$win" -F '#{@trails_pane}' | sort | tr '\n' ' '; }
panes_are() { [ "$(panes)" = "$1" ]; }
dpane() { tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "diff" { print $1 }'; }

# The agent alone, at the driver's 120 columns and made wide: nothing opens by itself.
assert_eq "$(panes)" "agent " "the agent alone"
tmux resize-window -t "$win" -x 240 -y 50
sleep 1
assert_eq "$(panes)" "agent " "wide: still the agent alone"

# prefix G: the diff on the right, Hunk on the codebase, whole files, 60% of the window.
c=$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v w="$win" '$2 == w { print $1; exit }')
[ -n "$c" ] || fail "no terminal on the trail's window"
key_g() { TMUX=$(tmux display-message -p '#{socket_path},0,0') TRAILS_CLIENT=$c "$TRAILS" diff; }
key_g
wait_for 5 panes_are "agent diff " || fail "prefix G showed no diff: $(panes)"
d=$(dpane)
wait_for 5 screen_has "$d" "hunk diff --watch in $PROJ context=99999" || fail "not Hunk on the codebase, whole files: $(screen "$d")"
assert_eq "$(tmux display-message -pt "$d" '#{pane_width}')" 144 "the diff 60% of 240, the agent's 40% beside it"
# Its border says hunk, not the shell that runs it.
assert_eq "$(tmux display-message -pt "$d" '#{T:pane-border-format}')" " hunk " "the diff pane's border label"
# A window from before the current format and label (1.13.0's) gets them from the next layout,
# with no rebuild.
tmux set-option -w -t "$win" pane-border-format ' #{?@ag,#{@ag},#{pane_current_command}} ' \; set-option -pu -t "$d" @trails_cmd
tmux set-hook -w -t "$win" window-resized "run-shell true"
"$TRAILS" --layout "$win"
assert_eq "$(tmux display-message -pt "$d" '#{T:pane-border-format}')" " hunk " "an old window's labels after a layout"
assert_eq "$(tmux show-hooks -w -t "$win" window-resized 2>/dev/null)" "" "1.13's resize hook taken off"
# Hunk's startup questions to the terminal stay in tmux: with passthrough, their answers would
# be typed into the agent's pane.
tmux set -g allow-passthrough on
assert_eq "$(tmux show -pv -t "$d" allow-passthrough)" off "no passthrough from the diff pane"

# Asked for, it stays through a resize, narrow or wide.
tmux resize-window -t "$win" -x 150 -y 50
sleep 1
assert_eq "$(panes)" "agent diff " "narrow: the diff asked for stays"
tmux resize-window -t "$win" -x 240 -y 50

# prefix G again puts it away, for good; once more brings it back.
key_g
wait_for 5 panes_are "agent " || fail "prefix G again left the diff: $(panes)"
assert_eq "$(tmux display-message -pt "$win" '#{@trails_diff}')" off "put away, remembered"
key_g
wait_for 5 panes_are "agent diff " || fail "prefix G brought no diff back: $(panes)"

# The editor takes the right side from it, and when the editor ends the diff comes back.
EDITOR=ed TMUX=$(tmux display-message -p '#{socket_path},0,0') TRAILS_CLIENT=$c "$TRAILS" edit >/dev/null 2>&1
wait_for 5 panes_are "agent editor " || fail "the editor and the diff both: $(panes)"
e=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
assert_eq "$(tmux display-message -pt "$e" '#{T:pane-border-format}')" " ed " "the editor pane's border label, the editor's name"
type_in "$e" exit
wait_for 5 panes_are "agent diff " || fail "the diff not back after the editor: $(panes)"

# A shell goes under it, as under the editor.
TMUX=$(tmux display-message -p '#{socket_path},0,0') TRAILS_CLIENT=$c "$TRAILS" shell >/dev/null 2>&1
wait_for 5 panes_are "agent diff shell " || fail "no shell beside the diff: $(panes)"
s=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "shell" { print $1 }')
assert_eq "$(tmux display-message -pt "$s" '#{pane_left}')" "$(tmux display-message -pt "$(dpane)" '#{pane_left}')" "the shell under the diff"
tmux kill-pane -t "$s"

# Quit with q, it stays away.
type_in "$(dpane)" q
wait_for 5 panes_are "agent " || fail "q left the diff: $(panes)"
assert_eq "$(tmux display-message -pt "$win" '#{@trails_diff}')" off "quitting puts it away"

# prefix G while the editor has the right side can't show the diff: the popup instead (a config
# diff command that reads and exits, so it closes by itself), and nothing remembered, so the
# editor's end brings no diff that wasn't asked for.
tmux set-option -wu -t "$win" @trails_diff
jq '.diff = "cat >/dev/null"' "$XDG_CONFIG_HOME/trails/config.json" >"$T/cfg.tmp" && mv "$T/cfg.tmp" "$XDG_CONFIG_HOME/trails/config.json"
EDITOR=ed TMUX=$(tmux display-message -p '#{socket_path},0,0') TRAILS_CLIENT=$c "$TRAILS" edit >/dev/null 2>&1
wait_for 5 panes_are "agent editor " || fail "no editor for the G-during-editor check: $(panes)"
key_g
sleep 1
assert_eq "$(tmux display-message -pt "$win" '#{@trails_diff}')" "" "G with the editor open remembers nothing"
e=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
type_in "$e" exit
wait_for 5 panes_are "agent " || fail "the editor's end: $(panes)"
sleep 1
assert_eq "$(panes)" "agent " "no diff after the editor"

# A Hunk that can't start fails once and stays away: the layout its end asks for doesn't start it
# again, round and round.
tmux set-environment -g HUNK_FAILS "$T/fails"
key_g
wait_for 5 test -s "$T/fails" || fail "prefix G started no Hunk"
sleep 2
assert_eq "$(wc -l <"$T/fails" | tr -d ' ')" 1 "started once"
assert_eq "$(panes)" "agent " "and gone"
[ "$(tmux display-message -pt "$win" '#{@trails_diff}')" != on ] || fail "still asked for after failing"
tmux set-environment -gu HUNK_FAILS

# The agent's exit takes the diff with it, and the window.
key_g
wait_for 5 panes_are "agent diff " || fail "prefix G after the failure showed no diff: $(panes)"
type_in default/payments exit
wait_for 5 sh -c "! tmux list-windows -t default -F '#{window_id}' 2>/dev/null | grep -qxF '$win'" ||
  fail "the window stayed with the diff in it: $(panes)"
