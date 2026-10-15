#!/bin/sh
# Surviving tmux: a record outlives kill-server, `trails restore` brings the trail back into
# its workspace on its old conversation, and a conversation the agent refuses comes back fresh.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
trails_bg new fast
wait_for 5 screen_has default/fast 'agent id=' || fail "fast never started"
id1=$(tmux display-message -pt default/payments '#{@trails_id}')
id2=$(tmux display-message -pt default/fast '#{@trails_id}')

tmux kill-server
sleep 0.3
assert_file "$STATE/default/payments" "record survives"
assert_file "$STATE/default/fast" "record survives"

# fast's conversation is gone from the agent's store, so its resume will be refused.
rm -f "$HOME/.agent/$id2"

out=$(cd "$T" && "$TRAILS" restore 2>&1)
assert_match "$out" "restored default/payments" "payments restored"
assert_match "$out" "nothing to resume for default/fast.*starting stub fresh" "fast refused, started fresh"
assert_match "$out" "restored default/fast" "fast restored"

wait_for 5 screen_has default/payments 'agent id=' || fail "payments never came back"
assert_match "$(screen default/payments)" "id=$id1 name= resume=1" "resumed on its conversation"
assert_eq "$(tmux display-message -pt default/payments '#{@trails_id}')" "$id1" "@trails_id kept"
assert_eq "$(tmux display-message -pt default/payments '#{@trails_name}')" payments "its name kept"
assert_eq "$(sed -n 's/^id=//p' "$STATE/default/payments")" "$id1" "record id kept"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "proj·fast proj·payments " "both windows, in the workspace"

wait_for 5 screen_has default/fast 'agent id=' || fail "fast never came back"
assert_match "$(screen default/fast)" 'resume=0' "fast started fresh"
newid=$(tmux display-message -pt default/fast '#{@trails_id}')
[ "$newid" != "$id2" ] || fail "fast should have a new id"
assert_eq "$(sed -n 's/^id=//p' "$STATE/default/fast")" "$newid" "record follows the new id"

# Nothing left to restore.
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "idempotent"

# A killed editor view is not a lost trail: the window lives on in the workspace, the
# record is alive, and the next attach rebuilds the view.
tmux kill-session -t default/fast
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$3 == "default/fast" { print $1 }')" running "still running"
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "nothing lost"
wid=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·fast" { print $1 }')
FZF_PICK='#fast' driver TRAILS_ATTACH=view "$TRAILS"
wait_for 5 has_session default/fast || fail "the view was not rebuilt"
assert_eq "$(tmux list-windows -t default/fast -F '#{window_id}')" "$wid" "and holds the trail's window"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx default/fast" || fail "the editor was not attached to the view"
