#!/bin/sh
# Config "server", TRAILS_SOCKET, record server=, the upgrade from the ordinary default socket,
# and `trails server NAME` moving the records and the config to another.
. "$REPO/test/lib.sh"
t_setup

CFG=$XDG_CONFIG_HOME/trails/config.json
uid=$(id -u)
sock_dir=$TMUX_TMPDIR/tmux-$uid
STATE=$XDG_STATE_HOME/trails/sessions

rec_server() {
  awk -F= '$1 == "server" { print $2; exit }' "$STATE"/*/"$1" 2>/dev/null
}
trail_key() {
  tmux ${1:+-L "$1"} list-windows -a -F '#{@trails_trail} #{@trails_session}' 2>/dev/null |
    awk -v s="$2" '$2 == s { print $1; exit }'
}
cfg_server() {
  jq -r 'if has("server") then (.server | if type == "string" then . else "null" end) else "ABSENT" end' "$CFG" 2>/dev/null
}
# Agents block shared by the scenario configs below.
agents_json='{ "name": "stub", "program": "agent", "yolo": "--yolo",
  "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } }'
write_cfg() {
  # $1 = server JSON fragment: absent | '""' | '"default"' | '"mine"' | '"trails"'
  case $1 in
    absent)
      cat >"$CFG" <<EOF
{ "mode": "default", "default_agent": "stub",
  "agents": [ $agents_json ] }
EOF
      ;;
    *)
      cat >"$CFG" <<EOF
{ "mode": "default", "default_agent": "stub", "server": $1,
  "agents": [ $agents_json ] }
EOF
      ;;
  esac
}
seed_record() {
  # $1=tid (t + 4 hex) $2=optional server= value; omit $2 for no server= line
  mkdir -p "$STATE/proj"
  {
    printf 'agent=stub\ndir=%s\nid=conv-%s\nyolo=\ntask=\nworkspace=default\nlabel=proj\nname=\ntrail=%s\nsession=default/proj-%s\n' \
      "$PROJ" "$1" "$1" "${1#t}"
    [ -n "${2+x}" ] && printf 'server=%s\n' "$2"
  } >"$STATE/proj/$1"
}

# ── Explicit / empty / TRAILS_SOCKET ──────────────────────────────────────────
# t_setup pins TRAILS_SOCKET=default; a trail's record matches.
trails_bg new on-default
wait_for 5 screen_has default/on-default 'agent id=' || fail "trail on default never started"
key=$(trail_key "" default/on-default)
[ -n "$key" ] || fail "no trail id for on-default"
assert_eq "$(rec_server "$key")" default "record stores the configured socket"

# Named server in config (TRAILS_SOCKET cleared in the driver).
write_cfg '"mine"'
driver env -u TRAILS_SOCKET "$TRAILS" new on-mine
wait_for 10 sh -c "tmux -L mine list-windows -a -F '#{@trails_session}' 2>/dev/null | grep -qx default/on-mine" ||
  fail "trail did not land on the configured socket"
[ -S "$sock_dir/mine" ] || fail "no socket named mine"
tmux -L default has-session -t '=default/on-mine' 2>/dev/null &&
  fail "configured socket leaked onto the ordinary default"
key=$(trail_key mine default/on-mine)
[ -n "$key" ] || fail "no trail id on mine"
assert_eq "$(rec_server "$key")" mine "record stores mine"
# And the terminal is attached to it there: the attach is an `exec tmux`, which no shell
# function reaches, so it has to name the socket itself. Without it, it went to the ordinary
# default and tmux said "no sessions" (1.17 and 1.18).
# The driver's own terminal, by its tty: the trail's window holds a nested client of its own.
dtty=$(tmux display-message -pt "driver-$DRIVERS" '#{pane_tty}')
wait_for 10 sh -c "tmux -L mine list-clients -F '#{client_tty}' 2>/dev/null | grep -qx '$dtty'" ||
  fail "the terminal never attached on mine: $(screen "driver-$DRIVERS")"

# Empty string means trails (dedicated), not the ordinary default.
write_cfg '""'
driver env -u TRAILS_SOCKET "$TRAILS" new on-empty
wait_for 10 sh -c "tmux -L trails list-windows -a -F '#{@trails_session}' 2>/dev/null | grep -qx default/on-empty" ||
  fail "empty server did not use the trails socket"
key=$(trail_key trails default/on-empty)
[ -n "$key" ] || fail "no trail id on trails"
assert_eq "$(rec_server "$key")" trails "empty server records as trails"

tmux -L mine kill-server 2>/dev/null || true
tmux -L trails kill-server 2>/dev/null || true
tmux kill-server 2>/dev/null || true
sleep 0.2

# ── Upgrade / missing key ─────────────────────────────────────────────────────
# Fresh: no server key, no session records → trails (do not invent a config key).
rm -rf "$STATE"
write_cfg absent
assert_eq "$(cfg_server)" ABSENT "fresh config has no server key"
out=$(cd "$PROJ" && env -u TRAILS_SOCKET "$TRAILS" ls -a 2>&1)
assert_eq "$(cfg_server)" ABSENT "fresh install does not write server into the config"
# And a new trail lands on -L trails.
driver env -u TRAILS_SOCKET "$TRAILS" new fresh
wait_for 10 sh -c "tmux -L trails list-windows -a -F '#{@trails_session}' 2>/dev/null | grep -qx default/fresh" ||
  fail "absent server on a fresh install did not use the trails socket"
key=$(trail_key trails default/fresh)
assert_eq "$(rec_server "$key")" trails "fresh trail records trails"
tmux -L trails kill-server 2>/dev/null || true
sleep 0.2

# Legacy: no server key, records still on default → pin config to default, stamp untagged.
rm -rf "$STATE"
write_cfg absent
seed_record tabc1 default
seed_record tdef2
# tdef2 has no server= line
out=$(cd "$PROJ" && env -u TRAILS_SOCKET "$TRAILS" ls -a 2>&1)
assert_match "$out" 'ordinary tmux server' "legacy pin says what it did"
assert_eq "$(cfg_server)" default "legacy pin wrote server default into the config"
assert_eq "$(rec_server tabc1)" default "explicit default record kept"
assert_eq "$(awk -F= '$1 == "server" { print $2; exit }' "$STATE/proj/tdef2")" default "untagged legacy record stamped default"
# Piped TSV (no badge column): life state session … workspace trail title
assert_match "$(printf '%s\n' "$out" | awk -F'\t' '$10 == "tabc1" { print $1, $2 }')" '^stopped lost$' "legacy default record reads lost on default"
assert_match "$(printf '%s\n' "$out" | awk -F'\t' '$10 == "tdef2" { print $1, $2 }')" '^stopped lost$' "stamped untagged record reads lost on default"

# Second run: already pinned, no repeat of the notice when the key is present.
out2=$(cd "$PROJ" && env -u TRAILS_SOCKET "$TRAILS" ls -a 2>&1)
assert_eq "$(printf '%s\n' "$out2" | grep -c 'ordinary tmux server')" 0 "pin notice only once"

# Move to trails: `trails server trails` rewrites the records and the config together; the
# config alone moved nothing, a record being restored only on its own server. Refused while a
# trail still runs on the old server, which would keep running with no record claiming it.
assert_eq "$(env -u TRAILS_SOCKET "$TRAILS" server)" default "trails server says where it is"
tmux -L default new-session -d -s held 'sleep 60'
tmux -L default set-option -w -t '=held:' @trails_trail tlive
out=$(env -u TRAILS_SOCKET "$TRAILS" server trails 2>&1)
assert_eq "$?" 1 "refused while a trail runs on the old server"
assert_match "$out" "1 trail windows still run on the default tmux server; stop it first" "and says what to do"
assert_eq "$(cfg_server) $(rec_server tabc1)" "default default" "nothing moved"
tmux -L default kill-server
out=$(env -u TRAILS_SOCKET "$TRAILS" server bad/name 2>&1)
assert_match "$out" "a server name is letters" "a name tmux can't take, refused"
out=$(env -u TRAILS_SOCKET "$TRAILS" server trails 2>&1)
assert_eq "$out" "trails: moved 2 trails from the default tmux server to trails; brew services start trails (or trails restore) brings them up there" "moved"
assert_eq "$(cfg_server) $(rec_server tabc1) $(rec_server tdef2)" "trails trails trails" "the config and every record"
assert_eq "$(env -u TRAILS_SOCKET "$TRAILS" server trails 2>&1)" "trails: already on the trails tmux server" "again, nothing to do"
out=$(cd "$PROJ" && env -u TRAILS_SOCKET "$TRAILS" restore 2>&1)
assert_match "$out" 'restored' "restore brings legacy trails onto the trails socket"
wait_for 10 sh -c "tmux -L trails list-windows -a -F '#{@trails_trail}' 2>/dev/null | grep -qx tabc1" ||
  fail "tabc1 did not come back on trails"
assert_eq "$(rec_server tabc1)" trails "restore rewrote the record onto trails"

tmux -L trails kill-server 2>/dev/null || true
tmux -L mine kill-server 2>/dev/null || true
