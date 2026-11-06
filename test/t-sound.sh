#!/bin/sh
# Notifications (ADR 28): a sound, afplay on macOS and canberra-gtk-play elsewhere, whatever
# terminal is in front; the bell in the status line says which trail. test/bin stands in for the
# players and logs what each was given, so no test plays one.
. "$REPO/test/lib.sh"
t_setup

notify() {
  jq --argjson n "$1" '. + { notify: $n }' "$XDG_CONFIG_HOME/trails/config.json" >"$T/cfg" &&
    cat "$T/cfg" >"$XDG_CONFIG_HOME/trails/config.json"
}
log=$HOME/sound.log
lines() { [ -f "$log" ] && grep -c . "$log" || echo 0; }
last() { tail -n 1 "$log" 2>/dev/null; }
# What was played, by the sound's name.
case $(uname -s) in
  Darwin) want() { printf 'afplay /System/Library/Sounds/%s.aiff ' "$1"; } ;;
  *) want() { case $1 in Blow) printf 'canberra-gtk-play -i message-new-instant ' ;; *) printf 'canberra-gtk-play -i %s ' "$1" ;; esac; } ;;
esac

# The default: unfocused, the system sound.
notify '{ "idle_after": 0 }'
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "never attached"
pane=$(tmux list-panes -t default/payments -F '#{pane_id}')
sleep 1
assert_eq "$(lines)" 0 "the agent starting, no sound"

type_in default/payments ask
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 1 ]" || fail "no sound for needs you: [$(cat -v "$log" 2>&1)] state=$(tmux show -pqv -t "$pane" @trails_state)"
assert_eq "$(last)" "$(want Blow)" "the system sound"

# The same word again: nothing more.
type_in default/payments "hook waiting"
sleep 1
assert_eq "$(lines)" 1 "waiting again, no second sound"

# Your turn.
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook idle"
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 2 ]" || fail "no sound for your turn"

# Silent: nothing.
notify '{ "idle_after": 0, "sound": "silent" }'
type_in default/payments "hook waiting"
sleep 1.5
assert_eq "$(lines)" 2 "silent, nothing played"

# A sound by name.
notify '{ "idle_after": 0, "sound": "Ping" }'
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 3 ]" || fail "no sound by name"
assert_eq "$(last)" "$(want Ping)" "the sound named"

# Not while a focused terminal shows the trail's window: the driver's client, told it has focus.
notify '{ "idle_after": 0 }'
tmux set -g focus-events on
type_in default/payments "hook working"
sleep 0.5
client=$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt driver-1 '#{pane_tty}')" '$2 == t { print $1 }')
tmux send-keys -t driver-1 -H 1b 5b 49
wait_for 5 sh -c "tmux list-clients -F '#{client_name} #{client_flags}' | grep -q '^$client .*focused'" ||
  fail "the driver's client never had focus: $(tmux list-clients -F '#{client_name} #{client_flags}')"
type_in default/payments "hook waiting"
sleep 1.5
assert_eq "$(lines)" 3 "watched, no sound"
# The terminal loses focus: it comes.
tmux send-keys -t driver-1 -H 1b 5b 4f
wait_for 5 sh -c "! tmux list-clients -F '#{client_name} #{client_flags}' | grep -q '^$client .*focused'" || fail "the client kept its focus"
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 4 ]" || fail "unfocused, no sound"
# show always: even while watched.
notify '{ "idle_after": 0, "show": "always" }'
tmux send-keys -t driver-1 -H 1b 5b 49
wait_for 5 sh -c "tmux list-clients -F '#{client_name} #{client_flags}' | grep -q '^$client .*focused'" || fail "focus never came back"
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 5 ]" || fail "show always, watched, no sound"

# "notify": false: none.
notify 'false'
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
sleep 1.5
assert_eq "$(lines)" 5 "notify false, nothing"

# A turn shorter than idle_after: no your-turn.
notify '{ "idle_after": 60 }'
type_in default/payments busy
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_state)\" = working ]" || fail "busy never started"
wait_for 5 sh -c "[ \"\$(tmux show-options -pqv -t '$pane' @trails_state)\" = idle ]" || fail "busy never ended"
sleep 1
assert_eq "$(lines)" 5 "a short turn, no your-turn"

# Only the words "on" lists: needs you left out.
notify '{ "on": ["idle"], "idle_after": 0, "show": "always" }'
type_in default/payments "hook waiting"
sleep 1.5
assert_eq "$(lines)" 5 "waiting, not on the list"

# "only": "starred": nothing from a trail without a star, then once it has one.
notify '{ "idle_after": 0, "show": "always", "only": "starred" }'
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
sleep 1.5
assert_eq "$(lines)" 5 "not starred, nothing"
"$TRAILS" star "$(tmux display-message -pt '=default/payments:' '#{@trails_trail}')"
type_in default/payments "hook working"
sleep 0.5
type_in default/payments "hook waiting"
wait_for 5 sh -c "[ \"\$(grep -c . '$log' 2>/dev/null)\" = 6 ]" || fail "starred, no sound"
