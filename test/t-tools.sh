#!/bin/sh
# Editor and shell: trails edit and shell as panes beside the agent in the trail's window, which its
# session never shows; the editor alone as a window where nothing runs; a trail's window whose trail ends
# keeping its panes as such a window; their rows in the picker, ctrl-e there, and ctrl-x.
. "$REPO/test/lib.sh"
t_setup
EDITOR='ed'
export EDITOR

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default" || fail "the driver never attached"
client=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/payments" { print $1 }')
[ -n "$win" ] || fail "no window"
panes() { tmux list-panes -t "$win" -F '#{@trails_pane}' | sort | tr '\n' ' '; }
on_window() { [ "$(client_at "$client" '#{window_id}')" = "$win" ]; }
at_pane() { [ "$(client_at "$client" '#{pane_id}')" = "$1" ]; }

# A shell window of your own in the workspace, in the codebase, to run the commands from.
tmux new-window -t default -c "$PROJ" sh
mine=$(tmux display-message -pt 'default:{end}' '#{window_id}')
tmux switch-client -c "$client" -t "=default:$mine"
wins() { tmux list-windows -t default -F '#{window_name}' | grep '·' | sort | tr '\n' ' '; }

geom() { tmux display-message -pt "$1" '#{pane_left} #{pane_top} #{pane_width} #{pane_height}'; }
# The layout is laid after the pane appears, so a geometry is waited for, not read at once.
geom_is() { [ "$(geom "$1")" = "$2" ]; }
W=$(tmux display-message -pt "$win" '#{window_width}')
H=$(tmux display-message -pt "$win" '#{window_height}')

# trails shell, with only the agent there: a shell pane along the bottom of the trail's window, full
# width, a quarter high, in the codebase; the client is taken to it. The trail's session is untouched:
# one window, one pane.
type_in "$mine" "$TRAILS shell"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 2 ]" || fail "no shell pane in the trail's window"
assert_eq "$(panes)" "agent shell " "the panes, marked"
spane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "shell" { print $1 }')
assert_eq "$(tmux display-message -pt "$spane" '#{pane_current_path}')" "$PROJ" "a shell in the codebase"
wait_for 5 geom_is "$spane" "0 $((H - H / 4)) $W $((H / 4))" || fail "the shell: along the bottom, full width, a quarter high: got $(geom "$spane")"
wait_for 5 on_window || fail "the client was not taken to the trail's window"
assert_eq "$(client_at "$client" '#{pane_id}')" "$spane" "on the shell"
assert_eq "$(tmux list-panes -t default/payments | wc -l | tr -d ' ')" 1 "the session still shows the agent alone"
assert_eq "$(wins)" "proj·payments " "no shell window"

# trails edit: the editor takes the left 60%, the session the right 40%, and the shell moves
# under the editor, a quarter high.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 3 ]" || fail "no editor pane in the trail's window"
assert_eq "$(panes)" "agent editor shell " "the panes, marked"
epane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
vpane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "agent" { print $1 }')
wait_for 5 screen_has "$epane" "ed in $PROJ" || fail "the editor is not in the codebase: $(screen "$epane" | grep -v '^$' | head -2)"
EW=$((W * 60 / 100))
wait_for 5 geom_is "$epane" "0 0 $EW $((H - H / 4 - 1))" || fail "the editor: left, 60% wide, above the shell: got $(geom "$epane")"
assert_eq "$(geom "$spane")" "0 $((H - H / 4)) $EW $((H / 4))" "the shell: under the editor only"
assert_eq "$(geom "$vpane")" "$((EW + 1)) 0 $((W - EW - 1)) $H" "the session: right 40%, full height"
wait_for 5 at_pane "$epane" || fail "the client was not taken to the editor"

# Again, from another window: selected, not duplicated, laid out the same.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
sleep 1.5
assert_eq "$(panes)" "agent editor shell " "still one editor"
assert_eq "$(client_at "$client" '#{window_id} #{pane_id}')" "$win $epane" "taken to it again"
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
sleep 1.5
assert_eq "$(panes)" "agent editor shell " "still one shell"
wait_for 5 geom_is "$spane" "0 $((H - H / 4)) $EW $((H / 4))" || fail "the shell stays under the editor: got $(geom "$spane")"

# From the shell pane itself, trails shell goes back to the pane you came from.
tmux select-pane -t "$epane"
tmux select-pane -t "$spane"
wait_shell "$spane" || fail "the shell pane never came up"
type_in "$spane" "$TRAILS shell"
wait_for 5 at_pane "$epane" || fail "the toggle did not go back: on $(client_at "$client" '#{pane_id}')"
assert_eq "$(panes)" "agent editor shell " "nothing closed"

# The editor quits: its pane goes, and the shell goes back along the bottom, full width.
type_in "$epane" exit
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 2 ]" || fail "the editor's pane outlived the editor"
wait_for 5 geom_is "$spane" "0 $((H - H / 4)) $W $((H / 4))" || fail "the shell kept its column: $(geom "$spane")"

# And the editor again, for what follows.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 3 ]" || fail "no editor pane the second time"
epane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
wait_for 5 at_pane "$epane" || fail "not taken to the second editor"

# Outside tmux, trails edit DIR attaches to the workspace on the trail's window.
driver "$TRAILS" edit "$PROJ"
driver_attached || fail "edit from outside never attached"
assert_eq "$(client_at "$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "driver-$DRIVERS" '#{pane_tty}')" '$2 == t { print $1 }')" '#{session_name} #{window_id}')" "default $win" "edit from outside attached on the trail's window"

# The nested client in the agent pane detaches (the double prefix reaches it): the pane goes,
# the trail lives on, and the next way in gives the window its agent pane back, laid out.
apane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "agent" { print $1 }')
tmux detach-client -t "$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "$apane" '#{pane_tty}')" '$2 == t { print $1 }')"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 2 ]" || fail "the agent pane outlived its client"
driver "$TRAILS" edit "$PROJ"
driver_attached || fail "edit after the detach never attached"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 3 ]" || fail "the agent pane was not given back: panes $(tmux list-panes -t "$win" -F '#{pane_id}=#{@trails_pane}:#{pane_current_command}' | tr '\n' ' '); clients $(tmux list-clients -F '#{client_name}:#{session_name}' | tr '\n' ' ')"
assert_eq "$(panes)" "agent editor shell " "the panes, marked, again"
apane=$(tmux list-panes -t "$win" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "agent" { print $1 }')
wait_for 5 geom_is "$apane" "$((EW + 1)) 0 $((W - EW - 1)) $H" || fail "the agent pane: right 40%, full height: got $(geom "$apane")"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default/payments" || fail "the new pane is not a client of the session"
assert_eq "$(tmux display-message -pt "$apane" '#{@ag} #{@dir}')" "stub proj" "stamped"

# The picker: panes beside an agent are the trail's, so the codebase's screen has no
# tool window row. ctrl-e on "＋ new trail…" in another codebase, where nothing runs, makes
# that codebase's editor alone and goes there; its screen lists the editor as a tool window,
# under "＋ new trail…" with the trails, and the workspace screen under the codebase column.
rm -f "$T/menu"
FZF_PICK='' FZF_DUMP=$T/menu trails_bg
wait_for 5 test -s "$T/menu" || fail "no picker"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/menu" | grep -v '^--- ' | cut -f1 | tr '\n' ' ')" "agents attach " "the way to a new trail, then the trail"
mkdir -p "$T/other"
DRIVER_DIR=$T/other FZF_KEY=ctrl-e FZF_PICK='^agents' driver "$TRAILS"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'other·ed'" || fail "ctrl-e made no editor"
owid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "other·ed" { print $1 }')
wait_for 5 screen_has "$owid" "ed in $T/other" || fail "the editor is not in that codebase"
assert_eq "$(tmux display-message -pt "$owid" '#{@trails_tool} #{@trails_dir} #{@trails_ws} #{@trails_label} #{@trails_pane}')" \
  "editor $T/other default other editor" "the window's options"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $owid'" || fail "not taken to it"
rm -f "$T/omenu"
DRIVER_DIR=$T/other FZF_PICK='' FZF_DUMP=$T/omenu driver "$TRAILS"
wait_for 5 test -s "$T/omenu" || fail "no picker in other"
orows=$(sed 's/\x1b\[[0-9;]*m//g' "$T/omenu" | grep -v '^--- ')
assert_eq "$(printf '%s\n' "$orows" | cut -f1 | tr '\n' ' ')" "agents tool " "the editor under the way to a new trail"
assert_match "$(printf '%s\n' "$orows" | grep "tool	$owid" | cut -f3)" '^editor +ed$' "the editor's row"
rm -f "$T/wmenu"
type_in "$mine" "FZF_DUMP=$T/wmenu $TRAILS"
wait_for 5 test -s "$T/wmenu" || fail "no workspace screen"
assert_match "$(sed 's/\x1b\[[0-9;]*m//g' "$T/wmenu" | grep "tool	$owid" | cut -f3)" '^editor +other +ed' "the editor's row, under the codebase column"

# An editor's terminal (NVIM set) sees trails only: no tool window rows.
rm -f "$T/emenu"
DRIVER_DIR=$T/other FZF_PICK='' FZF_DUMP=$T/emenu driver NVIM=1 "$TRAILS"
wait_for 5 test -s "$T/emenu" || fail "no picker from the editor"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/emenu" | grep -v '^--- ' | cut -f1 | tr '\n' ' ')" "agents " "the way to a new trail only"

# Enter on a tool window's row goes to its window.
DRIVER_DIR=$T/other FZF_PICK="tool	$owid" driver "$TRAILS"
driver_attached || fail "picking the editor never attached"
assert_eq "$(client_at "$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt "driver-$DRIVERS" '#{pane_tty}')" '$2 == t { print $1 }')" '#{session_name} #{window_id}')" "default $owid" "picking the editor went there"

# trails shell in that codebase goes under its editor.
DRIVER_DIR=$T/other driver "$TRAILS" shell
driver_attached || fail "trails shell in other never attached"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$owid' | wc -l | tr -d ' ')\" = 2 ]" || fail "no shell under the editor alone"
assert_eq "$(tmux list-panes -t "$owid" -F '#{@trails_pane}' | sort | tr '\n' ' ')" "editor shell " "its panes"

# The editor exits and leaves the shell: the window is renamed and re-marked for what it
# holds. An editor opened in it again marks it back, so trails edit from elsewhere finds it
# rather than making a second editor window.
oepane=$(tmux list-panes -t "$owid" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
type_in "$oepane" exit
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$owid' '#{window_name} #{@trails_tool} #{window_panes}')\" = 'other·shell shell 1' ]" || fail "not re-marked as a shell window: $(tmux display-message -pt "$owid" '#{window_name} #{@trails_tool} #{window_panes}'); panes: $(tmux list-panes -t "$owid" -F '#{pane_id}=#{@trails_pane}:#{pane_current_command}' | tr '\n' ' '); oepane=$oepane: $(tmux capture-pane -pt "$oepane" 2>&1 | grep -v '^$' | tail -3 | tr '\n' '|')"
ospane=$(tmux list-panes -t "$owid" -F '#{pane_id}')
wait_shell "$ospane" || fail "the shell pane never came up"
type_in "$ospane" "$TRAILS edit"
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$owid' '#{window_name} #{@trails_tool} #{window_panes}')\" = 'other·ed editor 2' ]" || fail "not re-marked as an editor window: $(tmux display-message -pt "$owid" '#{window_name} #{@trails_tool} #{window_panes}')"
DRIVER_DIR=$T/other driver "$TRAILS" edit
sleep 1.5
assert_eq "$(wins)" "other·ed proj·payments " "no second editor window"

# The agent exits with the editor and the shell beside it: the session goes, and the trail's window keeps
# them as the codebase's editor window — named for the editor, marked, no longer a trail's window, not
# a trail. The record goes with the trail.
type_in default/payments exit
wait_for 5 no_session default/payments || fail "the session outlived its agent"
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$win' '#{window_name}')\" = 'proj·ed' ]" || fail "the trail's window was not released: $(tmux display-message -pt "$win" '#{window_name} #{@trails_window} #{@trails_tool}')"
assert_eq "$(tmux display-message -pt "$win" '#{@trails_tool}|#{@trails_window}|#{@trails_dir}')" "editor||$PROJ" "a tool window now"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$win' | wc -l | tr -d ' ')\" = 2 ]" || fail "the agent pane lingers"
assert_eq "$(panes)" "editor shell " "the editor and the shell stay"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | wc -l | tr -d ' ')" 0 "not a trail"
assert_no_file "$STATE/default/payments" "the record went"

# trails edit finds that window for the codebase, and a new trail there gets a trail's window of its own.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
wait_for 5 on_window || fail "trails edit did not select the released window"
assert_eq "$(wins)" "other·ed proj·ed " "the two editor windows"

# ctrl-x on a tool window closes its window, and nothing else.
(cd "$T/other" && "$TRAILS" --kill "$owid")
wait_for 3 sh -c "! tmux list-windows -t default -F '#{window_id}' | grep -qx '$owid'" || fail "the editor window survived ctrl-x"
assert_eq "$(wins)" "proj·ed " "the rest stand"
