#!/bin/sh
# States read off the screen, for an agent with no state file of its own: a question is
# "needs you", a changing screen is "working", a still one is "your turn".
. "$REPO/test/lib.sh"
t_setup

state() { (cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$3 == "trails-payments" { print $2 }'); }
state_is() { [ "$(state)" = "$1" ]; }

trails_bg new payments
wait_for 5 screen_has trails-payments 'agent id=' || fail "agent never started"

wait_for 5 state_is your-turn || fail "a quiet agent should be your-turn, got $(state)"

type_in trails-payments ask
wait_for 5 state_is needs-you || fail "a question should be needs-you, got $(state)"

type_in trails-payments busy
assert_eq "$(state)" working "a changing screen"
wait_for 5 state_is your-turn || fail "a quiet agent again, got $(state)"
