#!/bin/sh
# Companions: trails edit, shell and ide as windows in the workspace beside the codebase's
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

# trails edit: the editor in the codebase, as a marked window, and the client is taken there.
type_in "$mine" "$TRAILS edit"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'proj·ed'" || fail "no editor window"
ewid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·ed" { print $1 }')
wait_for 5 screen_has "$ewid" "ed in $PROJ" || fail "the editor did not open in the codebase"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$client' '\$1 == c { print \$2 }')\" = '$ewid' ]" ||
  fail "the client was not taken to the editor"
assert_eq "$(tmux display-message -pt "$ewid" '#{@trails_companion} #{@trails_dir} #{@trails_ws} #{@trails_label}')" \
  "edit $PROJ default proj" "the window's options"

# Again, from another window: selected, not duplicated.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS edit"
sleep 1.5
assert_eq "$(wins)" "proj·ed proj·payments " "still one editor"
assert_eq "$(client_at "$client" '#{window_id}')" "$ewid" "taken there again"

# trails shell: a shell in the codebase.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS shell"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'proj·shell'" || fail "no shell window"
swid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·shell" { print $1 }')
assert_eq "$(tmux display-message -pt "$swid" '#{pane_current_path} #{@trails_companion}')" "$PROJ shell" "a shell in the codebase"

# trails ide: the editor beside a nested client of the trail's view, in one window.
tmux switch-client -c "$client" -t "=default:$mine"
sleep 0.3
type_in "$mine" "$TRAILS ide"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'proj·ide'" || fail "no ide window"
iwid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·ide" { print $1 }')
assert_eq "$(tmux list-panes -t "$iwid" | wc -l | tr -d ' ')" 2 "two panes"
wait_for 5 sh -c "tmux capture-pane -pt '$iwid.0' | grep -q 'ed in' && tmux capture-pane -pt '$iwid.1' | grep -q 'payments'" ||
  fail "the ide does not show the editor and the trail: $(tmux list-panes -t "$iwid" -F '#{pane_index} #{pane_current_command} #{pane_dead}'); 0: $(tmux capture-pane -pt "$iwid.0" | grep -v '^$' | head -3); 1: $(tmux capture-pane -pt "$iwid.1" | grep -v '^$' | head -3)"
assert_eq "$(tmux display-message -pt "$iwid" '#{@trails_of}')" default/payments "beside that trail"

# Outside tmux, trails edit DIR attaches to the workspace on the editor's window.
driver "$TRAILS" edit "$PROJ"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $ewid'" || fail "edit from outside did not attach to the editor"

# The picker lists them, on the codebase's screen and on the workspace's.
rm -f "$T/menu"
FZF_PICK='' FZF_DUMP=$T/menu trails_bg
wait_for 5 test -s "$T/menu" || fail "no picker"
rows=$(sed 's/\x1b\[[0-9;]*m//g' "$T/menu" | grep -v '^--- ')
assert_eq "$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ')" "attach companion companion companion new new " "companions after the trails, before the new rows"
assert_match "$(printf '%s\n' "$rows" | grep "companion	$ewid" | cut -f3)" '^editor +ed$' "the editor's row"
assert_match "$(printf '%s\n' "$rows" | grep "companion	$iwid" | cut -f3)" '^ide +ed · default/payments$' "the ide's row"
rm -f "$T/wmenu"
type_in "$mine" "FZF_DUMP=$T/wmenu $TRAILS"
wait_for 5 test -s "$T/wmenu" || fail "no workspace screen"
assert_match "$(sed 's/\x1b\[[0-9;]*m//g' "$T/wmenu" | grep "companion	$swid" | cut -f3)" '^shell +proj +(sh|bash|zsh)' "the shell's row, under the codebase column"

# Enter on a companion's row goes to its window.
FZF_PICK="companion	$swid" trails_bg
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $swid'" || fail "picking the shell did not go there"

# ctrl-e on a new row in another codebase makes that codebase's editor and goes there.
mkdir -p "$T/other"
DRIVER_DIR=$T/other FZF_KEY=ctrl-e FZF_PICK='stub · new trail' driver "$TRAILS"
wait_for 5 sh -c "tmux list-windows -t default -F '#{window_name}' | grep -qx 'other·ed'" || fail "ctrl-e made no editor"
owid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "other·ed" { print $1 }')
wait_for 5 screen_has "$owid" "ed in $T/other" || fail "the editor is not in that codebase"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $owid'" || fail "not taken to it"

# ctrl-x on a companion closes its window, and nothing else.
(cd "$PROJ" && "$TRAILS" --kill "$swid")
wait_for 3 sh -c "! tmux list-windows -t default -F '#{window_id}' | grep -qx '$swid'" || fail "the shell window survived ctrl-x"
assert_eq "$(wins)" "other·ed proj·ed proj·ide proj·payments " "the rest stand"

# The editor quits: its window goes, and the trail is untouched.
type_in "$ewid" exit
wait_for 3 sh -c "! tmux list-windows -t default -F '#{window_id}' | grep -qx '$ewid'" || fail "the editor window outlived the editor"
assert_file "$STATE/default/payments" "the trail's record stands"
