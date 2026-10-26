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
assert_file "$(trec default/payments)" "record survives"
assert_file "$(trec default/fast)" "record survives"
pay_file=$(trec default/payments)
pay_tid=$(sed -n 's/^trail=//p' "$pay_file")

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
assert_eq "$(sed -n 's/^id=//p' "$(trec default/payments)")" "$id1" "record id kept"
assert_eq "$(tmux display-message -pt default/payments '#{@trails_trail}')" "$pay_tid" "the same trail: its ID kept"
assert_eq "$(trec default/payments)" "$pay_file" "its record where it was"
assert_eq "$(tmux list-windows -t default -F '#{window_name}' | sort | tr '\n' ' ')" "proj·fast proj·payments " "both windows, in the workspace"

wait_for 5 screen_has default/fast 'agent id=' || fail "fast never came back"
assert_match "$(screen default/fast)" 'resume=0' "fast started fresh"
newid=$(tmux display-message -pt default/fast '#{@trails_id}')
[ "$newid" != "$id2" ] || fail "fast should have a new id"
assert_eq "$(sed -n 's/^id=//p' "$(trec default/fast)")" "$newid" "record follows the new id"
# Refused inside BOOT, restore_one starts it fresh; the wrapper's --refused asks the same, and
# must find it back already rather than start a second (lattiq/consent and consent-2, both
# fresh, both one trail, before the launch lock checked).
fast_tid=$(tmux display-message -pt default/fast '#{@trails_trail}')
sleep 6
assert_eq "$(tmux list-windows -a -F '#{@trails_trail}' | grep -cxF "$fast_tid")" 1 "started fresh once"

# Nothing left to restore.
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "idempotent"

# A killed trail's window is not a lost trail: the trail lives in its session, the record is alive, and
# the next attach from a terminal rebuilds the trail's window.
win=$(tmux list-windows -t default -F '#{window_id} #{window_name}' | awk '$2 == "proj·fast" { print $1 }')
tmux kill-window -t "$win"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$3 == "default/fast" { print $1 }')" running "still running"
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "nothing lost"
FZF_PICK='#fast' trails_bg
wait_for 5 sh -c "tmux list-windows -t default -F '#{@trails_window}' | grep -qx default/fast" || fail "the trail's window was not rebuilt"
win=$(tmux list-windows -t default -F '#{window_id} #{@trails_window}' | awk '$2 == "default/fast" { print $1 }')
assert_eq "$(tmux display-message -pt "$win" '#{window_name}')" "proj·fast" "named like the trail"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_id}' | grep -qx 'default $win'" || fail "not attached on the rebuilt window"

# A record that can never come back is forgotten, and said so: its directory gone, or the
# record unreadable. The conversation it pointed to is named, since it stays in the agent's
# own history.
mkdir -p "$STATE/default"
printf 'agent=stub\ndir=%s\nid=conv-1\nyolo=\ntask=\nworkspace=default\n' "$T/nowhere" >"$STATE/default/gone"
printf 'id=conv-2\n' >"$STATE/default/broken"
out=$(cd "$T" && "$TRAILS" restore 2>&1)
assert_match "$out" "forgot default/gone — $T/nowhere is gone \(conversation conv-1 stays in the history of stub\)" "a gone directory, said so"
assert_match "$out" "forgot default/broken — its record was unreadable" "an unreadable record, said so"
assert_no_file "$(trec default/gone)" "the gone one forgotten"
assert_no_file "$(trec default/broken)" "the broken one forgotten"

# A lost trail whose session something else took after the reboot (a tmux session of your
# own by that name) comes back as the next -N, and is the same trail: its ID, and its record,
# unmoved, with session= rewritten.
FZF_PICK='' trails_bg new solo
wait_for 5 screen_has default/solo 'agent id=' || fail "solo never started"
solo_tid=$(tmux display-message -pt default/solo '#{@trails_trail}')
solo_file=$(trec default/solo)
tmux kill-server
sleep 0.3
tmux new-session -d -s default/solo sh
out=$(cd "$T" && "$TRAILS" restore 2>&1)
# Once on CI it came back as default/proj, its name dropped; what held the name, if it fails again.
printf '%s\n' "$out" | grep -q "restored default/solo as default/solo-2" ||
  fail "back under the next -N: '$out'; name=solo in: $(grep -rlx name=solo "$STATE" | tr '\n' ' ')windows: $(tmux list-windows -a -F '#{session_name}:#{@trails_name}:#{@trails_trail}' | tr '\n' ' ')record: $(tr '\n' ' ' <"$solo_file" 2>/dev/null)"
wait_for 5 screen_has default/solo-2 'agent id=' || fail "solo-2 never came up"
assert_eq "$(tmux display-message -pt default/solo-2 '#{@trails_trail}')" "$solo_tid" "the same trail"
assert_file "$solo_file" "its record where it was"
assert_eq "$(sed -n 's/^session=//p' "$solo_file")" default/solo-2 "its session rewritten"

# An unnamed trail comes back under its session, named by its ID: the same name, as the same
# trail.
FZF_PICK='^agents	|stub · new trail' trails_bg
wait_for 5 has_unnamed default proj || fail "no unnamed trail: $(tmux ls)"
un=$(unnamed default proj 1)
un_tid=$(tmux display-message -pt "$un" '#{@trails_trail}')
assert_eq "$un" "default/proj-${un_tid#t}" "its session, named by its ID"
tmux kill-server
sleep 0.3
out=$(cd "$T" && "$TRAILS" restore 2>&1)
printf '%s\n' "$out" | grep -qx "restored $un" || fail "not back under its own session: '$out'"
wait_for 5 screen_has "$un" 'agent id=' || fail "$un never came back"
assert_eq "$(tmux display-message -pt "$un" '#{@trails_trail}')" "$un_tid" "the same trail"

# A restore the agent refuses after BOOT (claude, with MCP servers to start first): trails has
# said "restored" by then, and the wrapper keeps the record, so it would come back lost and be
# refused again by every restore. Instead the trail starts fresh in its place, as itself.
FZF_PICK='' trails_bg new late
wait_for 5 screen_has default/late 'agent id=' || fail "late never started"
late_tid=$(tmux display-message -pt default/late '#{@trails_trail}')
late_id=$(tmux display-message -pt default/late '#{@trails_id}')
tmux kill-server
sleep 0.3
rm -f "$HOME/.agent/$late_id"
out=$(cd "$T" && AGENT_REFUSE_AFTER=2.5 "$TRAILS" restore 2>&1)
assert_match "$out" "restored default/late" "said restored, before the refusal"
wait_for 12 sh -c "tmux capture-pane -pt default/late 2>/dev/null | grep -q 'resume=0'" ||
  fail "never started fresh after the late refusal: $(cat "$(trec default/late)")"
assert_eq "$(tmux display-message -pt default/late '#{@trails_trail}')" "$late_tid" "the same trail"
assert_eq "$(sed -n 's/^trail=//p' "$(trec default/late)")" "$late_tid" "its record, the same"
[ "$(sed -n 's/^id=//p' "$(trec default/late)")" != "$late_id" ] || fail "still on the refused conversation"
assert_eq "$(cd "$T" && "$TRAILS" restore 2>&1)" "trails: nothing to restore" "nothing lost after"

# Two restores at once (the tmux.conf line as the server starts, and one typed): each lost trail
# comes back once.
tmux kill-server
sleep 0.3
(cd "$T" && "$TRAILS" restore >"$T/restore-1.out" 2>&1) &
(cd "$T" && "$TRAILS" restore >"$T/restore-2.out" 2>&1) &
wait
sleep 1
both=$(cat "$T/restore-1.out" "$T/restore-2.out")
for k in default/payments default/fast; do
  ktid=$(sed -n 's/^trail=//p' "$(trec "$k")")
  assert_eq "$(tmux list-windows -a -F '#{@trails_trail}' | grep -cxF "$ktid")" 1 "$k back once, under two restores"
  # Said once: "restored" by the one that brought it back, and at most one "back already" from
  # the other, never a "restored … as" with no session after it.
  assert_eq "$(printf '%s\n' "$both" | grep -cx "restored $k")" 1 "$k said restored once: $both"
  [ "$(printf '%s\n' "$both" | grep -c "$k is back already")" -le 1 ] || fail "$k said back already twice: $both"
done
if printf '%s\n' "$both" | grep -q ' as $'; then fail "a restore said 'as' and no session: $both"; fi
