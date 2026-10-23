#!/bin/sh
# States as an agent's hooks give them: a question is "needs you", a turn under way is
# "working", a finished one is "your turn".
. "$REPO/test/lib.sh"
t_setup

state() { (cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$3 == "default/payments" { print $2 }'); }
state_is() { [ "$(state)" = "$1" ]; }

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"

wait_for 5 state_is your-turn || fail "a started agent should be your-turn, got $(state)"

type_in default/payments ask
wait_for 5 state_is needs-you || fail "a question should be needs-you, got $(state)"

type_in default/payments busy
wait_for 5 state_is working || fail "a turn under way should be working, got $(state)"
wait_for 5 state_is your-turn || fail "the turn over, your-turn again, got $(state)"
