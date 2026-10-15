#!/bin/sh
# Surviving tmux: a record outlives kill-server, `trails restore` brings the session back
# on its old conversation, and a conversation the agent refuses comes back fresh.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has trails-payments 'agent id=' || fail "payments never started"
trails_bg new fast
wait_for 5 screen_has trails-fast 'agent id=' || fail "fast never started"
id1=$(tmux display-message -pt trails-payments '#{@trails_id}')
id2=$(tmux display-message -pt trails-fast '#{@trails_id}')

tmux kill-server
sleep 0.3
assert_file "$STATE/trails-payments" "record survives"
assert_file "$STATE/trails-fast" "record survives"

# fast's conversation is gone from the agent's store, so its resume will be refused.
rm -f "$HOME/.agent/$id2"

out=$(cd "$T" && "$TRAILS" restore 2>&1)
assert_match "$out" "restored payments" "payments restored"
assert_match "$out" "nothing to resume for fast.*starting stub fresh" "fast refused, started fresh"
assert_match "$out" "restored fast" "fast restored"

wait_for 5 screen_has trails-payments 'agent id=' || fail "payments never came back"
assert_match "$(screen trails-payments)" "id=$id1 name= resume=1" "resumed on its conversation"
assert_eq "$(tmux display-message -pt trails-payments '#{@trails_id}')" "$id1" "@trails_id kept"
assert_eq "$(sed -n 's/^id=//p' "$STATE/trails-payments")" "$id1" "record id kept"

wait_for 5 screen_has trails-fast 'agent id=' || fail "fast never came back"
assert_match "$(screen trails-fast)" 'resume=0' "fast started fresh"
newid=$(tmux display-message -pt trails-fast '#{@trails_id}')
[ "$newid" != "$id2" ] || fail "fast should have a new id"
assert_eq "$(sed -n 's/^id=//p' "$STATE/trails-fast")" "$newid" "record follows the new id"

# Nothing left to restore.
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "idempotent"
