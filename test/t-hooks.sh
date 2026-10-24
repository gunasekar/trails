#!/bin/sh
# What the agent's hooks say (ADR 18, ADR 19): `trails state WORD --id ID` marks the agent's
# pane, the word answers for its state (else unknown), and the ID moves its record; a trail
# that ends goes into the history, to resume. Nothing of the agent's own is read.
. "$REPO/test/lib.sh"
t_setup

# The stub with its hooks off: nothing but a hook typed in can say what it is doing.
cfg() {
  cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent --no-hooks",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid"$1 } } ] }
CFG
}
cfg ''

state() { (cd "$PROJ" && "$TRAILS" ls | awk -F'\t' -v t="${TRAIL:-default/payments}" '$3 == t { print $2 }'); }
state_is() { [ "$(state)" = "$1" ]; }

# ── trails state: silent, and 0, whatever it is given ───────────────────────────────────
for args in "state working" "state bogus" "state"; do
  # shellcheck disable=SC2086 # the words are the arguments
  out=$(env -u TMUX -u TMUX_PANE "$TRAILS" $args 2>&1)
  rc=$?
  assert_eq "$out$rc" 0 "outside tmux, '$args': nothing said, 0"
done
out=$(TMUX=/nonexistent/sock,1,0 TMUX_PANE=%1 "$TRAILS" state idle 2>&1)
rc=$?
assert_eq "$out$rc" 0 "no server there: nothing said, 0"

# ── No hooks, no file: unknown ──────────────────────────────────────────────────────────
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
wait_for 5 state_is unknown || fail "an agent nothing speaks for should be unknown, got $(state)"
assert_match "$(cd "$PROJ" && "$TRAILS" ls -a | cat)" "unknown" "the TSV says unknown"

# ── The hook's word, each of the three ──────────────────────────────────────────────────
type_in default/payments "hook working"
wait_for 5 state_is working || fail "hook working: got $(state)"
type_in default/payments "hook waiting"
wait_for 5 state_is needs-you || fail "hook waiting: got $(state)"
type_in default/payments "hook idle"
wait_for 5 state_is your-turn || fail "hook idle: got $(state)"
pane=$(tmux list-panes -t default/payments -F '#{pane_id}')

# ── --id: the conversation the agent says it is in ───────────────────────────────────
# An ID that isn't one is left out, and the word still counts: characters no ID has, one an
# agent would read as a flag, a path.
for bad in 'bad;id' '-x' '..'; do
  tmux set-option -pu -t "$pane" @trails_state
  type_in default/payments "hook working --id $bad"
  wait_for 5 state_is working || fail "hook working with the ID $bad: got $(state)"
  assert_eq "$(tmux show-options -pqv -t "$pane" @trails_said_id)" "" "the ID $bad, left out"
done

# The agent says the conversation it is in from its hooks; an agent it started, from its shell,
# says its own from further down, and is not the trail's.
carried=$(tmux display-message -pt default/payments '#{@trails_id}')
type_in default/payments "hook idle --id $carried"
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_said_id)\" = '$carried' ]" || fail "its own ID, not taken"
type_in default/payments "nested idle --id 99999999-0000-0000-0000-000000000000"
sleep 1
assert_eq "$(tmux show-options -pqv -t "$pane" @trails_said_id)" "$carried" "a nested agent's ID, left out"
assert_eq "$(sed -n 's/^id=//p' "$(trec default/payments)")" "$carried" "and the record kept"

# Another program's hooks, though in the trail's pane (a claude -p run from a gemini, say): not
# the trail's agent (@trails_program, from launch), so neither their word nor their ID counts.
assert_eq "$(tmux display-message -pt default/payments '#{@trails_program}')" agent "the trail's program, kept"
type_in default/payments "hook working --agent agent"
wait_for 5 state_is working || fail "its own program's word: got $(state)"
type_in default/payments "hook idle --agent claude --id 88888888-0000-0000-0000-000000000000"
sleep 1
assert_eq "$(state)" working "another program's word, dropped"
assert_eq "$(tmux show-options -pqv -t "$pane" @trails_said_id)" "$carried" "and its ID"

# The agent moves to another conversation (a /clear, a /resume): the record follows it, and
# the one it left goes into the history, to resume.
HIST=$XDG_STATE_HOME/trails/history
old=$(sed -n 's/^id=//p' "$(trec default/payments)")
new=11111111-2222-3333-4444-555555555555
: >"$HOME/.agent/$new" # as the agent would keep it, so it can be resumed
type_in default/payments "hook idle --id $new"
# At once, not at the next listing: nothing lists the trails here.
wait_for 5 grep -qx "id=$new" "$(trec default/payments)" ||
  fail "the record did not follow the agent: $(cat "$(trec default/payments)")"
# The window is told after the record is written, so it is waited for too.
wait_for 5 sh -c "[ \"\$(tmux display-message -pt default/payments '#{@trails_id}')\" = '$new' ]" ||
  fail "the trail does not carry it: $(tmux display-message -pt default/payments '#{@trails_id}')"
assert_file "$HIST/$old" "the conversation it left, in the history"
assert_eq "$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$2 == "closed" { print $7 }')" "$old" "listed as closed, to resume"

# The agent ends: its trail goes into the history too, with what it was working on. A turn
# first: a conversation that never had one stays out (see t-tools).
type_in default/payments "hook working"
type_in default/payments "title Fix the retry budget"
wait_for 5 sh -c "'$TRAILS' ls -a >/dev/null; grep -qx 'task=Fix the retry budget' \"\$(trec default/payments)\"" ||
  fail "the task never reached the record"
tmux new-session -d -s hold # the server outlives the trail's session
type_in default/payments exit
wait_for 5 no_session default/payments || fail "the trail outlived its agent"
assert_no_file "$(trec default/payments)" "no record: it ended"
assert_match "$(cat "$HIST/$new")" "ended=[0-9]+" "in the history, ended"
closed=$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$7 == "'"$new"'"')
assert_match "$closed" "^stopped	closed	-	stub	-	$PROJ	$new	[0-9]+	default	-	Fix the retry budget$" "a closed row, its task its title"

# ctrl-x on a closed row, in the picker's old trails, forgets it; and the picker's list of
# them is read again, so the reload drops it.
oldtitle=$(sed -n 's/^task=//p' "$HIST/$old")
(cd "$PROJ" && TRAILS_PICKER=old FZF_KEYS=ctrl-x FZF_PICK="$oldtitle" "$TRAILS" >/dev/null 2>&1)
assert_no_file "$HIST/$old" "forgotten by ctrl-x"
(cd "$PROJ" && "$TRAILS" ls >/dev/null)
(cd "$PROJ" && TRAILS_RECENT_CACHE=$T/recent "$TRAILS" --kill "stub:$new-not:$PROJ")
assert_eq "$(cut -f4 "$T/recent")" "$new" "the list, read again, holds the one left"

# Resuming one starts a trail on its conversation, and takes it out of the history.
printf '%s\n' "resume old trails" "Fix the retry budget" >"$T/pick"
DRIVER_DIR=$PROJ FZF_PICKS=$T/pick driver "$TRAILS"
wait_for 5 screen_has default/payments "id=$new .*resume=1" || fail "not resumed: $(screen default/payments)"
# Once it has survived starting, not before: a resume that dies on arrival keeps its entry.
wait_for 5 sh -c "[ ! -e '$HIST/$new' ]" || fail "still in the history once running"

# A resume the agent refuses (a conversation it doesn't have) dies on arrival, and keeps its
# entry, to try again or forget.
gone=33333333-4444-5555-6666-777777777777
printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=Lost cause\nworkspace=default\nlabel=proj\nname=\nended=%s\n' \
  "$PROJ" "$gone" "$(date +%s)" >"$HIST/$gone"
printf '%s\n' "resume old trails" "Lost cause" >"$T/pick2"
DRIVER_DIR=$PROJ FZF_PICKS=$T/pick2 driver "$TRAILS"
sleep 3
assert_file "$HIST/$gone" "a resume that died on arrival, still in the history"

# A fresh trail that dies on arrival (an agent that can't start) never ran: nothing to resume.
cp "$XDG_CONFIG_HOME/trails/config.json" "$T/cfg.keep"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "dud", "agents": [ { "name": "dud", "program": "false",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ] }
CFG
n_before=$(ls "$HIST" | wc -l)
(cd "$PROJ" && "$TRAILS" new dud >/dev/null 2>&1)
sleep 1
assert_eq "$(ls "$HIST" | wc -l)" "$n_before" "a trail that died on arrival, not in the history"
cp "$T/cfg.keep" "$XDG_CONFIG_HOME/trails/config.json"

# A closed named trail whose name an unnamed trail's session holds now comes back unnamed,
# rather than refused.
tmux new-session -d -s default/proj # held, as an unnamed trail in codebase proj would hold it
named=44444444-5555-6666-7777-888888888888
: >"$HOME/.agent/$named"
printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=Named one\nworkspace=default\nlabel=proj\nname=proj\nended=%s\n' \
  "$PROJ" "$named" "$(date +%s)" >"$HIST/$named"
printf '%s\n' "resume old trails" "Named one" >"$T/pick3"
DRIVER_DIR=$PROJ FZF_PICKS=$T/pick3 driver "$TRAILS"
wait_for 5 sh -c "tmux list-windows -a -F '#{@trails_id}' | grep -qx '$named'" ||
  fail "a named trail whose session is taken was not resumed: $(tmux ls)"

# ── An agent that picks its own ID: its record waits for its hooks to say it ────────────
# No session.start: launch() has no ID to write down, and nothing is read from the agent.
tmux kill-session -t '=default/payments'
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "own", "agents": [ { "name": "own", "program": "agent --no-hooks",
    "session": { "resume": "--resume {id}" } } ] }
CFG
trails_bg new mine
wait_for 5 screen_has default/mine 'agent' || fail "the agent never started"
assert_no_file "$(trec default/mine)" "no record before its ID is known"
own=22222222-3333-4444-5555-666666666666
type_in default/mine "hook idle --id $own"
wait_for 5 sh -c "'$TRAILS' ls -a >/dev/null; grep -qx 'id=$own' \"\$(trec default/mine)\" 2>/dev/null" ||
  fail "no record once the hook said the ID"
tmux kill-session -t '=default/mine'

# ── An agent with no session block: its hooks still speak ───────────────────────────────
# Its pane carries no @trails_id, an empty field between the ones that say its state.
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub", "agents": [ { "name": "stub", "program": "agent --no-hooks" } ] }
CFG
trails_bg new plain
wait_for 5 screen_has default/plain 'agent' || fail "the session-less agent never started"
type_in default/plain "hook waiting"
TRAIL=default/plain
wait_for 5 state_is needs-you || fail "no session block, hook waiting: got $(state)"

# ── The Claude Code plugin is the hooks the README gives Claude, and never drifts ────────
claude_doc=$(awk '/^##### Claude Code/ { c = 1 } c && /^```json/ { f = 1; next } f && /^```/ { exit } f' "$REPO/README.md")
assert_eq "$(jq -S . "$REPO/plugins/trails/hooks/hooks.json")" "$(printf '%s\n' "$claude_doc" | jq -S .)" \
  "the plugin's hooks are the docs' Claude hooks"
