#!/bin/sh
# Companions: trails edit and shell as panes beside the agent in its cell, which the view
# never shows; the editor alone as a window where nothing runs; a cell whose trail ends
# keeping its panes as such a window; their rows in the picker, ctrl-e there, and ctrl-x.
. "$REPO/test/lib.sh"
t_setup
EDITOR='ed'
export EDITOR

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default" || fail "the driver never attached"
client=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
cell=$(tmux list-windows -t default -F '#{window_id} #{@trails_cell}' | awk '$2 == "default/payments" { print $1 }')
[ -n "$cell" ] || fail "no cell"
panes() { tmux list-panes -t "$cell" -F '#{@trails_pane}' | sort | tr '\n' ' '; }
on_cell() { [ "$(client_at "$client" '#{window_id}')" = "$cell" ]; }
at_pane() { [ "$(client_at "$client" '#{pane_id}')" = "$1" ]; }

# A shell window of your own in the workspace, in the codebase, to run the commands from.
tmux new-window -t default -c "$PROJ" sh
mine=$(tmux display-message -pt 'default:{end}' '#{window_id}')
tmux switch-client -c "$client" -t "=default:$mine"
wins() { tmux list-windows -t default -F '#{window_name}' | grep '·' | sort | tr '\n' ' '; }

# trails edit, with a trail running: the editor splits the cell, to the agent's left, and the
# client is taken there. The view is untouched: one window, one pane.
type_in "$mine" "$TRAILS edit"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$cell' | wc -l | tr -d ' ')\" = 2 ]" || fail "no editor pane in the cell"
assert_eq "$(panes)" "editor view " "the panes, marked"
epane=$(tmux list-panes -t "$cell" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "editor" { print $1 }')
wait_for 5 screen_has "$epane" "ed in $PROJ" || fail "the editor is not in the codebase: $(screen "$epane" | grep -v '^$' | head -2)"
assert_eq "$(tmux display-message -pt "$epane" '#{pane_left}')" 0 "to the left"
wait_for 5 on_cell || fail "the client was not taken to the cell"
assert_eq "$(tmux list-panes -t default/payments | wc -l | tr -d ' ')" 1 "the view still shows the agent alone"
assert_eq "$(wins)" "proj·payments " "no editor window"

# Again, from another window: selected, not duplicated.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
sleep 1.5
assert_eq "$(panes)" "editor view " "still one editor"
assert_eq "$(client_at "$client" '#{window_id} #{pane_id}')" "$cell $epane" "taken to it again"

# trails shell: a shell pane across the bottom of the cell, in the codebase; again, it is
# selected, not duplicated.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$cell' | wc -l | tr -d ' ')\" = 3 ]" || fail "no shell pane"
assert_eq "$(panes)" "editor shell view " "the panes, marked"
spane=$(tmux list-panes -t "$cell" -F '#{pane_id} #{@trails_pane}' | awk '$2 == "shell" { print $1 }')
assert_eq "$(tmux display-message -pt "$spane" '#{pane_current_path}')" "$PROJ" "a shell in the codebase"
assert_eq "$(tmux display-message -pt "$spane" '#{pane_left} #{pane_width}')" "0 $(tmux display-message -pt "$cell" '#{window_width}')" "across the bottom"
assert_eq "$(client_at "$client" '#{window_id} #{pane_id}')" "$cell $spane" "taken to the shell"
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
sleep 1.5
assert_eq "$(panes)" "editor shell view " "still one shell"
assert_eq "$(wins)" "proj·payments " "no shell window"

# From the shell pane itself, trails shell goes back to the pane you came from.
tmux select-pane -t "$epane"
tmux select-pane -t "$spane"
wait_shell "$spane" || fail "the shell pane never came up"
type_in "$spane" "$TRAILS shell"
wait_for 5 at_pane "$epane" || fail "the toggle did not go back: on $(client_at "$client" '#{pane_id}')"
assert_eq "$(panes)" "editor shell view " "nothing closed"

# Outside tmux, trails edit DIR attaches to the workspace on the cell.
driver "$TRAILS" edit "$PROJ"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $cell'" || fail "edit from outside did not attach on the cell"

# The picker: panes beside an agent are the trail's, so the codebase's screen has no
# companion row. ctrl-e on a new row in another codebase, where nothing runs, makes that
# codebase's editor alone and goes there; its screen lists the editor as a companion, after
# the trails and before the new rows, and the workspace screen under the codebase column.
rm -f "$T/menu"
FZF_PICK='' FZF_DUMP=$T/menu trails_bg
wait_for 5 test -s "$T/menu" || fail "no picker"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/menu" | grep -v '^--- ' | cut -f1 | tr '\n' ' ')" "attach new new " "the trail and the new rows"
mkdir -p "$T/other"
DRIVER_DIR=$T/other FZF_KEY=ctrl-e FZF_PICK='stub · new trail' driver "$TRAILS"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'other·ed'" || fail "ctrl-e made no editor"
owid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "other·ed" { print $1 }')
wait_for 5 screen_has "$owid" "ed in $T/other" || fail "the editor is not in that codebase"
assert_eq "$(tmux display-message -pt "$owid" '#{@trails_companion} #{@trails_dir} #{@trails_ws} #{@trails_label} #{@trails_pane}')" \
  "edit $T/other default other editor" "the window's options"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $owid'" || fail "not taken to it"
rm -f "$T/omenu"
DRIVER_DIR=$T/other FZF_PICK='' FZF_DUMP=$T/omenu driver "$TRAILS"
wait_for 5 test -s "$T/omenu" || fail "no picker in other"
orows=$(sed 's/\x1b\[[0-9;]*m//g' "$T/omenu" | grep -v '^--- ')
assert_eq "$(printf '%s\n' "$orows" | cut -f1 | tr '\n' ' ')" "companion new new " "the companion before the new rows"
assert_match "$(printf '%s\n' "$orows" | grep "companion	$owid" | cut -f3)" '^editor +ed$' "the editor's row"
rm -f "$T/wmenu"
type_in "$mine" "FZF_DUMP=$T/wmenu $TRAILS"
wait_for 5 test -s "$T/wmenu" || fail "no workspace screen"
assert_match "$(sed 's/\x1b\[[0-9;]*m//g' "$T/wmenu" | grep "companion	$owid" | cut -f3)" '^editor +other +ed' "the editor's row, under the codebase column"

# An editor's terminal (NVIM set) sees trails only: no companion rows.
rm -f "$T/emenu"
DRIVER_DIR=$T/other FZF_PICK='' FZF_DUMP=$T/emenu driver NVIM=1 "$TRAILS"
wait_for 5 test -s "$T/emenu" || fail "no picker from the editor"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/emenu" | grep -v '^--- ' | cut -f1 | tr '\n' ' ')" "new new " "new rows only"

# Enter on a companion's row goes to its window.
DRIVER_DIR=$T/other FZF_PICK="companion	$owid" driver "$TRAILS"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{session_name} #{window_id}' | grep -cx 'default $owid')\" -ge 2 ]" || fail "picking the editor did not go there"

# trails shell in that codebase goes under its editor.
DRIVER_DIR=$T/other driver "$TRAILS" shell
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$owid' | wc -l | tr -d ' ')\" = 2 ]" || fail "no shell under the editor alone"
assert_eq "$(tmux list-panes -t "$owid" -F '#{@trails_pane}' | sort | tr '\n' ' ')" "editor shell " "its panes"

# The agent exits with the editor and the shell beside it: the view goes, and the cell keeps
# them as the codebase's editor window — named for the editor, marked, no longer a cell, not
# a trail. The record goes with the trail.
type_in default/payments exit
wait_for 5 no_session default/payments || fail "the view outlived its agent"
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$cell' '#{window_name}')\" = 'proj·ed' ]" || fail "the cell was not released: $(tmux display-message -pt "$cell" '#{window_name} #{@trails_cell} #{@trails_companion}')"
assert_eq "$(tmux display-message -pt "$cell" '#{@trails_companion}|#{@trails_cell}|#{@trails_dir}')" "edit||$PROJ" "a companion now"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$cell' | wc -l | tr -d ' ')\" = 2 ]" || fail "the view pane lingers"
assert_eq "$(panes)" "editor shell " "the editor and the shell stay"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | wc -l | tr -d ' ')" 0 "not a trail"
assert_no_file "$STATE/default/payments" "the record went"

# trails edit finds that window for the codebase, and a new trail there gets a cell of its own.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
wait_for 5 on_cell || fail "trails edit did not select the released window"
assert_eq "$(wins)" "other·ed proj·ed " "the two editor windows"

# ctrl-x on a companion closes its window, and nothing else.
(cd "$T/other" && "$TRAILS" --kill "$owid")
wait_for 3 sh -c "! tmux list-windows -t default -F '#{window_id}' | grep -qx '$owid'" || fail "the editor window survived ctrl-x"
assert_eq "$(wins)" "proj·ed " "the rest stand"
