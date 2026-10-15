#!/bin/sh
# trails ls: the piped contract (12 tab-separated fields), scoped to this directory, a
# named one, or every directory with -a.
. "$REPO/test/lib.sh"
t_setup

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')

row=$(cd "$PROJ" && "$TRAILS" ls | cat)
assert_eq "$(printf '%s\n' "$row" | wc -l | tr -d ' ')" 1 "one row here"
assert_eq "$(printf '%s\n' "$row" | awk -F'\t' '{ print NF }')" 12 "twelve fields"
assert_eq "$(printf '%s\n' "$row" | cut -f1,3,4,5,6,7,8,9,10,11)" \
  "running	default/payments	stub	-	$PROJ	$id	-	-	-	default" "the fixed fields"
assert_match "$(printf '%s\n' "$row" | cut -f2)" '^(your-turn|working)$' "a state"
assert_eq "$(printf '%s\n' "$row" | cut -f12)" "payments ready" "the title"

# The title follows the pane title.
type_in default/payments 'title Fix the retry budget'
wait_for 3 sh -c "cd '$PROJ' && '$TRAILS' ls | cut -f12 | grep -q 'Fix the retry budget'" ||
  fail "the title never updated"

# On a terminal, a table: the badge leads, the workspace follows the agent.
driver "sh -c '$TRAILS ls; sleep 30'"
wait_for 5 screen_has driver-2 'retry budget' || fail "no table"
assert_match "$(screen driver-2)" '^#payments +● (your turn|working) +stub +default +~/proj +Fix the retry budget' "the table row"

# Elsewhere sees nothing; -a and DIR see it.
mkdir -p "$T/elsewhere"
out=$(cd "$T/elsewhere" && "$TRAILS" ls | cat)
assert_eq "$out" "" "nothing elsewhere"
assert_eq "$(cd "$T/elsewhere" && "$TRAILS" ls -a | cut -f3)" default/payments "-a lists it"
assert_eq "$(cd "$T/elsewhere" && "$TRAILS" ls "$PROJ" | cut -f3)" default/payments "DIR lists it"

# Lost after the server dies: the record stays and ls says so, workspace and all.
tmux kill-server
sleep 0.3
assert_file "$STATE/default/payments" "record survives kill-server"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | cut -f1,2,3,11)" "stopped	lost	default/payments	default" "lost row"
