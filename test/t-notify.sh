#!/bin/sh
# Notifications (ADR 26): a trail's word changing writes an escape to every attached client's
# tty, the one the config gives its #{client_termtype}. The driver's pane is that client's
# terminal, so what reaches it is piped to a file and read back.
. "$REPO/test/lib.sh"
t_setup

# The test config, with "notify" as $1. The driver's client is tmux's (termtype tmux 3.x, or
# nothing on a tmux too old to ask), so the tests' terminals glob is "*".
notify() {
  jq --argjson n "$1" '. + { notify: $n }' "$XDG_CONFIG_HOME/trails/config.json" >"$T/cfg" &&
    cat "$T/cfg" >"$XDG_CONFIG_HOME/trails/config.json"
}
notify '{ "idle_after": 0, "terminals": { "*": "osc99" } }'

out=$T/out
: >"$out"
seen() { grep -ao "$1" "$out" 2>/dev/null | wc -l | tr -d " "; }
seen_has() { [ "$(seen "$1")" -gt "${2:-0}" ]; }
up() { tmux show-options -pqv -t "$pane" @trails_notified; }

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "never attached"
tmux pipe-pane -O -t driver-1 "cat >>'$out'"
pane=$(tmux list-panes -t default/payments -F '#{pane_id}')
tid=$(tmux display-message -pt default/payments '#{@trails_trail}')

# The start's idle is no turn ending: nothing.
sleep 1
assert_eq "$(seen ']99;')" 0 "the agent starting, no notification"

# ── needs you: osc99, named by the trail, urgent ─────────────────────────────────────────
type_in default/payments ask
wait_for 5 seen_has 'needs you' || fail "no notification for needs you: $(cat -v "$out" | tail -c 400)"
assert_match "$(cat "$out")" "\]99;i=trails-$tid:d=0:u=2:o=always:f=dHJhaWxz;stub · needs you" "osc99's title"
assert_match "$(cat "$out")" "\]99;i=trails-$tid:p=body;default/payments — payments ready" "osc99's body"
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_notified)\" = 1 ]" || fail "not marked as up"

# The same word again: nothing more.
type_in default/payments "hook waiting"
sleep 1
assert_eq "$(seen 'needs you')" 1 "waiting again, no second notification"

# ── back to work: it closes ───────────────────────────────────────────────────────────────
type_in default/payments "hook working"
wait_for 5 seen_has "i=trails-$tid:p=close" || fail "never closed"
wait_for 5 sh -c "[ -z \"\$(tmux show-options -pqv -t '$pane' @trails_notified)\" ]" || fail "still marked as up"

# ── your turn: after a turn, with idle_after 0 ───────────────────────────────────────────
type_in default/payments "hook idle"
wait_for 5 seen_has 'your turn' || fail "no notification for your turn"
assert_match "$(cat "$out")" "u=1:o=always:f=dHJhaWxz;stub · your turn" "your turn, normal urgency"

# A turn shorter than idle_after: nothing.
notify '{ "idle_after": 60, "terminals": { "*": "osc99" } }'
was=$(seen 'your turn')
type_in default/payments busy
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_state)\" = working ]" || fail "busy never started"
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_state)\" = idle ]" || fail "busy never ended"
sleep 1
assert_eq "$(seen 'your turn')" "$was" "a 2s turn under idle_after 60, no notification"

# ── the config's: words, sound, show, formats, off ──────────────────────────────────────
notify '{ "on": ["idle"], "idle_after": 0, "terminals": { "*": "osc99" } }'
was=$(seen 'needs you')
type_in default/payments ask
sleep 1
assert_eq "$(seen 'needs you')" "$was" "waiting left out of on, no notification"

notify '{ "show": "unfocused", "sound": "silent", "terminals": { "*": "osc99" } }'
type_in default/payments "hook working"
type_in default/payments ask
wait_for 5 seen_has 'o=unfocused' || fail "show not passed"
assert_match "$(cat "$out")" "o=unfocused:f=dHJhaWxz:s=c2lsZW50;" "the sound, base64"

notify '{ "terminals": { "*": "osc777" } }'
type_in default/payments "hook working"
type_in default/payments ask
wait_for 5 seen_has ']777;notify;stub · needs you;default/payments' || fail "no osc777"

notify '{ "terminals": { "*": "osc9" } }'
type_in default/payments "hook working"
type_in default/payments ask
wait_for 5 seen_has ']9;stub · needs you: default/payments' || fail "no osc9"

# A terminal no glob matches gets nothing; nor does any with notify off.
for cfg in '{ "terminals": { "kitty*": "osc99" } }' 'false'; do
  notify "$cfg"
  was=$(seen 'needs you')
  type_in default/payments "hook working"
  type_in default/payments ask
  sleep 1
  assert_eq "$(seen 'needs you')" "$was" "$cfg: no notification"
done
