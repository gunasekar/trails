#!/bin/sh
# From 1.7 to 1.8: records filed as sessions/<workspace>/<name>, with no trail ID, move to
# 1.8's layout the first time anything reads them, once; a trail still running from before has
# its window given its record's ID and reads running; and the wrapper 1.7 started, which
# forgets by session, still closes its trail into the history.
. "$REPO/test/lib.sh"
t_setup

# A trail started now, then made to look like 1.7's: its record moved back to the old place
# without the new fields, and the ID taken off its window.
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')
new_file=$(trec default/payments)
mkdir -p "$STATE/default"
grep -v '^trail=\|^session=' "$new_file" >"$STATE/default/payments"
rm -f "$new_file"
tmux set-option -wu -t default/payments @trails_trail
# And a lost one, with no window at all.
printf 'agent=stub\ndir=%s\nid=conv-lost\nyolo=\ntask=Old work\nworkspace=default\nlabel=proj\nname=\n' "$PROJ" >"$STATE/default/proj-9"

out=$(cd "$PROJ" && "$TRAILS" ls | cat)
assert_no_file "$STATE/default/payments" "the old record moved"
assert_no_file "$STATE/default/proj-9" "the lost one's too"
[ -d "$STATE/default" ] && fail "the old workspace folder left behind"
f=$(trec default/payments)
assert_match "$f" "/sessions/proj/t[0-9a-f]{8}\$" "filed by ID under its codebase"
assert_eq "$(sed -n 's/^id=//p' "$f")" "$id" "the same conversation"
assert_eq "$(tmux display-message -pt default/payments '#{@trails_trail}')" "$(sed -n 's/^trail=//p' "$f")" "the running window given its record's ID"
assert_match "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "default/payments" { print $1 }')" '^running$' "it reads running"
assert_match "$(printf '%s\n' "$out" | awk -F'\t' '$3 == "default/proj-9" { print $1, $2 }')" '^stopped lost$' "the lost one reads lost"

# Once: a second run moves nothing.
before=$(find "$STATE" -type f | sort)
"$TRAILS" ls -a >/dev/null
assert_eq "$(find "$STATE" -type f | sort)" "$before" "nothing moved the second time"

# The wrapper 1.7 started forgets by session: the record closes into the history all the same.
tmux set-option -p -t default/payments @trails_worked 1
"$TRAILS" --forget default/payments
assert_no_file "$(trec default/payments)" "an old wrapper's --forget closes it"
assert_file "$XDG_STATE_HOME/trails/history/$id" "into the history"
