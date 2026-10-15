#!/bin/sh
# trails ls: the piped contract (11 tab-separated fields), scoped to this directory, a
# named one, or every directory with -a.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has trails-payments 'agent id=' || fail "agent never started"
id=$(tmux display-message -pt trails-payments '#{@trails_id}')

row=$(cd "$PROJ" && "$TRAILS" ls | cat)
assert_eq "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" 1 "one row here"
assert_eq "$(printf '%s\n' "$row" | awk -F'\t' '{ print NF }')" 11 "eleven fields"
assert_eq "$(printf '%s\n' "$row" | cut -f1,3,4,5,6,7,8,9,10)" \
  "running	trails-payments	stub	-	$PROJ	$id	-	-	-" "the fixed fields"
assert_match "$(printf '%s\n' "$row" | cut -f2)" '^(your-turn|working)$' "a state"
assert_eq "$(printf '%s\n' "$row" | cut -f11)" "payments ready" "the title"

# The title follows the pane title.
type_in trails-payments 'title Fix the retry budget'
wait_for 3 sh -c "cd '$PROJ' && '$TRAILS' ls | cut -f11 | grep -q 'Fix the retry budget'" ||
  fail "the title never updated"

# Elsewhere sees nothing; -a and DIR see it.
mkdir -p "$T/elsewhere"
out=$(cd "$T/elsewhere" && "$TRAILS" ls | cat)
assert_eq "$out" "" "nothing elsewhere"
assert_eq "$(cd "$T/elsewhere" && "$TRAILS" ls -a | cut -f3)" trails-payments "-a lists it"
assert_eq "$(cd "$T/elsewhere" && "$TRAILS" ls "$PROJ" | cut -f3)" trails-payments "DIR lists it"

# Lost after the server dies: the record stays and ls says so.
tmux kill-server
sleep 0.3
assert_file "$STATE/trails-payments" "record survives kill-server"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | cut -f1,2,3)" "stopped	lost	trails-payments" "lost row"
