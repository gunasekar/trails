#!/bin/sh
# trails new: a named trail gets its session, its options and its record; quitting the
# agent takes the session and the record away.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 has_session trails-payments || fail "no session trails-payments"
wait_for 5 screen_has trails-payments 'agent id=' || fail "agent never printed"

screen=$(screen trails-payments)
assert_match "$screen" 'agent id=[0-9a-f-]{36} name=payments resume=0 yolo=0' "the agent's arguments"
id=$(printf '%s\n' "$screen" | sed -n 's/.*id=\([0-9a-f-]*\) .*/\1/p' | head -n 1)

assert_eq "$(tmux display-message -pt trails-payments '#{@agent}')" stub "@agent"
assert_eq "$(tmux display-message -pt trails-payments '#{@trails_id}')" "$id" "@trails_id"
assert_eq "$(tmux display-message -pt trails-payments '#{session_path}')" "$PROJ" "session_path"

assert_file "$STATE/trails-payments" "the record"
assert_eq "$(sed -n 's/^agent=//p' "$STATE/trails-payments")" stub "record agent"
assert_eq "$(sed -n 's/^dir=//p' "$STATE/trails-payments")" "$PROJ" "record dir"
assert_eq "$(sed -n 's/^id=//p' "$STATE/trails-payments")" "$id" "record id"

# A second trail named the same is refused.
out=$(cd "$PROJ" && "$TRAILS" new payments 2>&1)
assert_match "$out" "payments.*(taken|in use|already)" "a taken name is refused"

# YOLO, and the other agent.
trails_bg new fast other -y
wait_for 5 screen_has trails-fast 'agent (other)' || fail "the other agent never started"
assert_match "$(screen trails-fast)" 'yolo=1' "yolo flag passed"
assert_eq "$(tmux display-message -pt trails-fast '#{@agent}')" "other (YOLO)" "@agent with YOLO"
assert_eq "$(sed -n 's/^yolo=//p' "$STATE/trails-fast")" yolo "record yolo"

# Quitting forgets.
type_in trails-payments exit
wait_for 5 no_session trails-payments || fail "session outlived its agent"
wait_for 2 test ! -e "$STATE/trails-payments" || fail "record outlived its agent"
assert_file "$STATE/trails-fast" "the other record stays"
