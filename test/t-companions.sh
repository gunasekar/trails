#!/bin/sh
# Companions: trails edit and shell as windows in the workspace beside the codebase's
# trails, made once and selected after; their rows in the picker, ctrl-e there, and ctrl-x
# on one.
. "$REPO/test/lib.sh"
t_setup
EDITOR='ed'
export EDITOR

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
wait_for 5 sh -c 'tmux list-clients | grep -q .' || fail "the driver never attached"
client=$(tmux list-clients -F '#{client_name}' | head -n 1)

# A shell window of your own in the workspace, in the codebase, to run the commands from.
tmux new-window -t default -c "$PROJ" sh
mine=$(tmux display-message -pt 'default:{end}' '#{window_id}')
tmux switch-client -c "$client" -t "=default:$mine"
wins() { tmux list-windows -t default -F '#{window_name}' | grep '·' | sort | tr '\n' ' '; }

# trails edit, with a trail running: the editor beside it, one window with two panes, and
# the client is taken there.
type_in "$mine" "$TRAILS edit"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'proj·ide'" || fail "no ide window"
ewid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·ide" { print $1 }')
assert_eq "$(tmux list-panes -t "$ewid" | wc -l | tr -d ' ')" 2 "two panes"
wait_for 5 sh -c "tmux capture-pane -pt '$ewid.0' | grep -q 'ed in $PROJ' && tmux capture-pane -pt '$ewid.1' | grep -q 'payments'" ||
  fail "the window does not show the editor and the trail: 0: $(tmux capture-pane -pt "$ewid.0" | grep -v '^$' | head -2); 1: $(tmux capture-pane -pt "$ewid.1" | grep -v '^$' | head -2)"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$client' '\$1 == c { print \$2 }')\" = '$ewid' ]" ||
  fail "the client was not taken to the editor"
assert_eq "$(tmux display-message -pt "$ewid" '#{@trails_companion} #{@trails_dir} #{@trails_ws} #{@trails_label} #{@trails_of}')" \
  "ide $PROJ default proj default/payments" "the window's options"

# Again, from another window: selected, not duplicated.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
sleep 1.5
assert_eq "$(wins)" "proj·ide proj·payments " "still one editor"
assert_eq "$(client_at "$client" '#{window_id}')" "$ewid" "taken there again"

# trails shell: a shell pane across the bottom of that window, in the codebase; again, it
# is selected, not duplicated.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
wait_for 5 sh -c "[ \"\$(tmux list-panes -t '$ewid' | wc -l | tr -d ' ')\" = 3 ]" || fail "no shell pane"
spane=$(tmux list-panes -t "$ewid" -F '#{pane_id} #{@trails_shell}' | awk '$2 == 1 { print $1 }')
[ -n "$spane" ] || fail "the shell pane is not marked"
assert_eq "$(tmux display-message -pt "$spane" '#{pane_current_path}')" "$PROJ" "a shell in the codebase"
assert_eq "$(tmux display-message -pt "$spane" '#{pane_left} #{pane_width}')" "0 $(tmux display-message -pt "$ewid" '#{window_width}')" "across the bottom"
assert_eq "$(client_at "$client" '#{window_id}')" "$ewid" "taken to the window"
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
sleep 1.5
assert_eq "$(tmux list-panes -t "$ewid" | wc -l | tr -d ' ')" 3 "still one shell"
assert_eq "$(wins)" "proj·ide proj·payments " "no shell window"

# Outside tmux, trails edit DIR attaches to the workspace on the editor's window.
driver "$TRAILS" edit "$PROJ"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $ewid'" || fail "edit from outside did not attach to the editor"

# The picker lists them, on the codebase's screen and on the workspace's.
rm -f "$T/menu"
FZF_PICK='' FZF_DUMP=$T/menu trails_bg
wait_for 5 test -s "$T/menu" || fail "no picker"
rows=$(sed 's/\x1b\[[0-9;]*m//g' "$T/menu" | grep -v '^--- ')
assert_eq "$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ')" "attach companion new new " "the companion after the trail, before the new rows"
assert_match "$(printf '%s\n' "$rows" | grep "companion	$ewid" | cut -f3)" '^editor +ed · default/payments$' "the editor's row"
rm -f "$T/wmenu"
type_in "$mine" "FZF_DUMP=$T/wmenu $TRAILS"
wait_for 5 test -s "$T/wmenu" || fail "no workspace screen"
assert_match "$(sed 's/\x1b\[[0-9;]*m//g' "$T/wmenu" | grep "companion	$ewid" | cut -f3)" '^editor +proj +ed · default/payments' "the editor's row, under the codebase column"

# An editor's terminal (NVIM set) sees trails only: no companion rows.
rm -f "$T/emenu"
FZF_PICK='' FZF_DUMP=$T/emenu driver NVIM=1 "$TRAILS"
wait_for 5 test -s "$T/emenu" || fail "no picker from the editor"
assert_eq "$(sed 's/\x1b\[[0-9;]*m//g' "$T/emenu" | grep -v '^--- ' | cut -f1 | tr '\n' ' ')" "attach new new " "trails and new rows only"

# Enter on a companion's row goes to its window.
FZF_PICK="companion	$ewid" trails_bg
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{session_name} #{window_id}' | grep -cx 'default $ewid')\" -ge 2 ]" || fail "picking the editor did not go there"

# ctrl-e on a new row in another codebase, where nothing runs, makes that codebase's editor
# alone and goes there.
mkdir -p "$T/other"
DRIVER_DIR=$T/other FZF_KEY=ctrl-e FZF_PICK='stub · new trail' driver "$TRAILS"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'other·ed'" || fail "ctrl-e made no editor"
owid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "other·ed" { print $1 }')
wait_for 5 screen_has "$owid" "ed in $T/other" || fail "the editor is not in that codebase"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $owid'" || fail "not taken to it"

# The editor quits beside a trail: its pane goes, the trail's view and the shell stay.
type_in "$ewid.0" exit
wait_for 3 sh -c "[ \"\$(tmux list-panes -t '$ewid' | wc -l | tr -d ' ')\" = 2 ]" || fail "the editor's pane outlived the editor"

# ctrl-x on a companion closes its window, and nothing else. The trail is untouched.
(cd "$T/other" && "$TRAILS" --kill "$owid")
wait_for 3 sh -c "! tmux list-windows -t default -F '#{window_id}' | grep -qx '$owid'" || fail "the editor window survived ctrl-x"
assert_eq "$(wins)" "proj·ide proj·payments " "the rest stand"
assert_file "$STATE/default/payments" "the trail's record stands"
assert_eq "$(tmux display-message -pt default/payments '#{window_name} #{pane_dead}')" "proj·payments 0" "the trail runs on"
