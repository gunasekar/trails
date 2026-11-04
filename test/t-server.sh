#!/bin/sh
# The config's "server" (and TRAILS_SOCKET): which tmux socket trails talks to.
. "$REPO/test/lib.sh"
t_setup

CFG=$XDG_CONFIG_HOME/trails/config.json
uid=$(id -u)
sock_dir=$TMUX_TMPDIR/tmux-$uid

rec_server() {
  awk -F= '$1 == "server" { print $2; exit }' "$STATE"/*/"$1" 2>/dev/null
}
trail_key() {
  tmux ${1:+-L "$1"} list-windows -a -F '#{@trails_trail} #{@trails_session}' 2>/dev/null |
    awk -v s="$2" '$2 == s { print $1; exit }'
}

# Default TRAILS_SOCKET from t_setup keeps the ordinary name; a trail's record matches.
trails_bg new on-default
wait_for 5 screen_has default/on-default 'agent id=' || fail "trail on default never started"
key=$(trail_key "" default/on-default)
[ -n "$key" ] || fail "no trail id for on-default"
assert_eq "$(rec_server "$key")" default "record stores the configured socket"

# A named server: trails uses -L that name. The driver pane inherits the tmux server's
# environment (TRAILS_SOCKET=default from t_setup), so clear it for this launch or the
# config's server would be ignored.
cat >"$CFG" <<'EOF'
{
  "mode": "default",
  "default_agent": "stub",
  "server": "mine",
  "agents": [
    { "name": "stub", "program": "agent", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } }
  ]
}
EOF
driver env -u TRAILS_SOCKET "$TRAILS" new on-mine
wait_for 10 sh -c "tmux -L mine list-windows -a -F '#{@trails_session}' 2>/dev/null | grep -qx default/on-mine" ||
  fail "trail did not land on the configured socket"
[ -S "$sock_dir/mine" ] || fail "no socket named mine"
tmux -L default has-session -t '=default/on-mine' 2>/dev/null &&
  fail "configured socket leaked onto the ordinary default"
key=$(trail_key mine default/on-mine)
[ -n "$key" ] || fail "no trail id on mine"
assert_eq "$(rec_server "$key")" mine "record stores mine"

# Empty server string means trails, same as missing.
cat >"$CFG" <<'EOF'
{
  "server": "",
  "default_agent": "stub",
  "agents": [
    { "name": "stub", "program": "agent", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } }
  ]
}
EOF
driver env -u TRAILS_SOCKET "$TRAILS" new on-trails
wait_for 10 sh -c "tmux -L trails list-windows -a -F '#{@trails_session}' 2>/dev/null | grep -qx default/on-trails" ||
  fail "empty server did not use the trails socket"
key=$(trail_key trails default/on-trails)
[ -n "$key" ] || fail "no trail id on trails"
assert_eq "$(rec_server "$key")" trails "empty server records as trails"

tmux -L mine kill-server 2>/dev/null || true
tmux -L trails kill-server 2>/dev/null || true
