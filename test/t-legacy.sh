#!/bin/sh
# A trail from 0.6 — a session of its own named trails-<project> — keeps working beside the
# new model (D6 in the design): listed, attached to, ended. Its record, once the session dies
# with tmux, restores as a window in the workspace its directory belongs to now.
. "$REPO/test/lib.sh"
t_setup

# What 0.6 left behind: the session, its options, its record.
id=11111111-2222-3333-4444-555555555555
tmux new-session -d -s trails-proj -c "$PROJ" -x 120 -y 40 "agent --session-id $id"
tmux set-option -t trails-proj @agent stub
tmux set-option -t trails-proj @trails_id "$id"
mkdir -p "$STATE"
printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=\n' "$PROJ" "$id" >"$STATE/trails-proj"
wait_for 5 screen_has trails-proj 'agent id=' || fail "the 0.6 agent never started"

# Listed as running, under its session name, with no workspace.
row=$(cd "$PROJ" && "$TRAILS" ls | cat)
assert_eq "$(printf '%s\n' "$row" | cut -f1,3,4,6,7,11)" "running	trails-proj	stub	$PROJ	$id	-" "the 0.6 row"

# A new trail here goes into the workspace, and both are listed.
trails_bg new fresh
wait_for 5 screen_has default/fresh 'agent id=' || fail "fresh never started"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | cut -f3 | sort | tr '\n' ' ')" "default/fresh trails-proj " "both listed"

# The picker attaches to the 0.6 session as before.
FZF_PICK='agent ready' trails_bg
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx trails-proj" || fail "not attached to the 0.6 session"

# ctrl-x ends it as a session, record and all.
wid=$(tmux display-message -pt trails-proj '#{window_id}')
(cd "$PROJ" && "$TRAILS" --kill "$wid")
wait_for 3 no_session trails-proj || fail "the 0.6 session survived ctrl-x"
assert_no_file "$STATE/trails-proj" "its record went"

# 0.6 records whose sessions died with tmux restore into the workspace: an unnamed one
# (trails-<project>-2) under the codebase, a named one under its name, mode and all.
id2=22222222-2222-3333-4444-555555555555
id3=33333333-2222-3333-4444-555555555555
touch "$HOME/.agent/$id2" "$HOME/.agent/$id3"
printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=\n' "$PROJ" "$id2" >"$STATE/trails-proj-2"
printf 'agent=stub\ndir=%s\nid=%s\nyolo=yolo\ntask=\n' "$PROJ" "$id3" >"$STATE/trails-billing"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$2 == "lost" { print $3 }' | sort | tr '\n' ' ')" \
  "trails-billing trails-proj-2 " "both lost"

out=$(cd "$T" && "$TRAILS" restore 2>&1)
assert_match "$out" 'restored proj-2 as default/proj' "the unnamed one"
assert_match "$out" 'restored billing as default/billing' "the named one"
wait_for 5 screen_has default/billing "id=$id3 name= resume=1 yolo=1" || fail "billing did not resume in its mode"
wait_for 5 screen_has default/proj "id=$id2 name= resume=1 yolo=0" || fail "proj-2 did not resume"
assert_eq "$(tmux display-message -pt default/billing '#{@trails_name}')" billing "named on its window"
assert_eq "$(tmux display-message -pt default/proj '#{@trails_name}')" "" "unnamed on its window"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "proj·billing proj·fresh proj·stub " "three windows"
assert_no_file "$STATE/trails-proj-2" "the old record went"
assert_no_file "$STATE/trails-billing" "the old record went"
assert_eq "$(sed -n 's/^name=//p' "$STATE/default/billing")" billing "the new record is named"
assert_eq "$(sed -n 's/^yolo=//p' "$STATE/default/billing")" yolo "and keeps its mode"
