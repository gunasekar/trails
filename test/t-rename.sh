#!/bin/sh
# The task in the status line, and a trail renamed when its work moves on (ADR 23): the right of
# the status line reads the agent's title, before the checklist's count; a name, from trails rename or the picker's
# ctrl-r, replaces it in the window, the badge and the record, and the session stays.
. "$REPO/test/lib.sh"
t_setup

NEW='^agents	|stub · new trail'
FZF_PICK="$NEW" trails_bg
wait_for 5 has_unnamed default proj || fail "no unnamed trail: $(tmux ls)"
s=$(unnamed default proj 1)
wait_for 5 screen_has "$s" 'agent id=' || fail "the agent never started"
tid=$(tmux display-message -pt "$s" '#{@trails_trail}')
wid=$(tmux display-message -pt "$s" '#{window_id}')
cell=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk -v k="$s" '$2 == k { print $1 }')
[ -n "$cell" ] || fail "no trail's window"

# The right of the status line as trails keys sets it, up to the checklist's count (a job, which
# display-message would not wait for), drawn for the trail's window.
"$TRAILS" keys | tmux source-file - || fail "trails keys did not load"
task_fmt=$(tmux show -gv status-right | sed 's/#(.*//')
[ -n "$task_fmt" ] || fail "no task in status-right"
bar() { tmux display-message -pt "$cell" "$task_fmt"; }
bar_is() { [ "$(bar)" = "$1" ]; }

# The agent's title, without the agent: the stub's own as it starts, then what it says next.
wait_for 5 bar_is "agent ready · " || fail "the agent's first title: '$(bar)'"
type_in "$s" 'title Fixing the flaky test'
wait_for 5 bar_is "Fixing the flaky test · " || fail "the task: '$(bar)'"
# A title that says nothing shows nothing: an empty one, and the codebase's name alone, which
# is what the trail's session titles itself with while its agent has no title.
type_in "$s" 'title '
wait_for 5 bar_is "" || fail "an empty title: '$(bar)'"
tmux select-pane -t "$cell.0" -T 'stub · proj'
wait_for 5 bar_is "" || fail "the codebase's name alone: '$(bar)'"
# Long ones are cut.
type_in "$s" 'title Almanac readiness review and Hawkeye sessions'
wait_for 5 bar_is "Almanac readiness review and Hawkeye ses… · " || fail "a long task: '$(bar)'"

# Renamed by its ID: its windows, its badge and its record take the name; its session stays.
"$TRAILS" rename "$tid" aws-setup || fail "rename refused"
assert_eq "$(tmux display-message -pt "$wid" '#{@trails_name}')" aws-setup "@trails_name"
assert_eq "$(tmux display-message -pt "$wid" '#{window_name}')" "proj·aws-setup" "the agent's window"
assert_eq "$(tmux display-message -pt "$cell" '#{window_name}')" "proj·aws-setup" "the trail's window"
assert_eq "$(sed -n 's/^name=//p' "$(trec "$s")")" aws-setup "the record's name"
has_session "$s" || fail "the session was renamed"
# A named trail's window says what it is for: no task after it.
wait_for 5 bar_is "" || fail "a named trail: '$(bar)'"

# A name refused as a new trail's is refused here too, and changes nothing.
"$TRAILS" rename "$tid" "proj-beef" 2>/dev/null && fail "a name like an unnamed trail's was taken"
"$TRAILS" rename "$tid" "a b" 2>/dev/null && fail "a name with a space was taken"
assert_eq "$(tmux display-message -pt "$wid" '#{@trails_name}')" aws-setup "unchanged by a refused name"
"$TRAILS" rename t0000 x 2>/dev/null && fail "renamed a trail that isn't there"

# The picker's ctrl-r: the query is the row's new name, and the picker comes back.
FZF_KEYS=ctrl-r FZF_QUERY=retries FZF_PICK='#aws-setup' trails_bg
wait_for 5 sh -c "[ \"\$(tmux display-message -pt '$wid' '#{@trails_name}')\" = retries ]" ||
  fail "ctrl-r did not rename: $(tmux display-message -pt "$wid" '#{@trails_name}')"
assert_eq "$(tmux display-message -pt "$cell" '#{window_name}')" "proj·retries" "renamed from the picker"

# An empty name takes it away: back to its session's name, and the task.
"$TRAILS" rename "$tid" '' || fail "unnaming refused"
assert_eq "$(tmux display-message -pt "$cell" '#{window_name}')" "proj-${tid#t}" "back to its ID"
assert_eq "$(sed -n 's/^name=//p' "$(trec "$s")")" "" "the record unnamed"
wait_for 5 bar_is "Almanac readiness review and Hawkeye ses… · " || fail "the task back: '$(bar)'"

# From inside the trail's window, with no ID: the pane it runs in says which trail.
pane=$(tmux list-panes -t "$cell" -F '#{pane_id}' | head -n 1)
TMUX=$(tmux display-message -p '#{socket_path},0,0') TMUX_PANE=$pane "$TRAILS" rename here || fail "rename from the trail's pane refused"
assert_eq "$(tmux display-message -pt "$wid" '#{@trails_name}')" here "renamed the trail it ran in"
# From prefix R: a run-shell job, in no pane, told the terminal that pressed the key.
c=$(tmux list-clients -F '#{client_name}' | head -n 1)
[ -n "$c" ] || fail "no terminal attached"
tmux switch-client -c "$c" -t "$cell"
TMUX=$(tmux display-message -p '#{socket_path},0,0') TRAILS_CLIENT=$c "$TRAILS" rename bykey || fail "rename from a key refused"
assert_eq "$(tmux display-message -pt "$wid" '#{@trails_name}')" bykey "renamed the trail on the terminal that pressed the key"

# Restored, a renamed trail is a named one: back under its name.
tmux kill-server
sleep 0.3
out=$(cd "$T" && "$TRAILS" restore 2>&1)
printf '%s\n' "$out" | grep -qx "restored $s as default/bykey" || fail "not back under its name: '$out'"
wait_for 5 has_session default/bykey || fail "no default/bykey"
assert_eq "$(tmux display-message -pt default/bykey '#{@trails_trail}')" "$tid" "the same trail"
