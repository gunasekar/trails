#!/bin/sh
# Workspaces at the status line's left, as `trails keys` sets it: the running ones by name,
# the one a terminal is on in reverse video, no trail's own session among them; and prefix ( and )
# (`trails ws prev` / `next`) moving a terminal through them, round the end.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/other/b"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"], "beta": ["~/other/*"] } }
CFG

# A trail in each workspace; the second's driver goes, so the first is the one terminal.
DRIVER_DIR=$T/code/a driver "$TRAILS" new one
wait_for 5 screen_has alpha/one 'agent id=' || fail "one never started"
driver_attached || fail "the terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt driver-1 '#{pane_tty}')" '$2 == t { print $1 }')
[ -n "$term" ] || fail "no terminal"
DRIVER_DIR=$T/other/b driver "$TRAILS" new two
wait_for 5 screen_has beta/two 'agent id=' || fail "two never started"
driver_attached || fail "two's driver never attached"
tmux kill-session -t driver-2
on() { client_at "$term" '#{session_name}'; }
tmux switch-client -c "$term" -t =alpha
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = alpha ]" || fail "not on alpha"

# The status line, as the terminal draws it: alpha in reverse, beta not, and no alpha/one.
"$TRAILS" keys | grep '^set -g status-left' >"$T/bar.conf"
tmux source-file "$T/bar.conf" || fail "tmux refused the status lines"
sleep 1
bar=$(tmux capture-pane -ep -t driver-1 | tail -n 1)
esc=$(printf '\033')
assert_match "$bar" "${esc}\\[7m(${esc}\\[[0-9;]*m)* alpha " "alpha in reverse"
assert_match "$bar" " alpha (${esc}\\[[0-9;]*m)* beta " "beta not"
assert_match "$(printf '%s' "$bar" | sed 's/\x1b\[[0-9;]*m//g')" "^ alpha  beta │" "both workspaces, in order, and nothing else"

# ws next and prev, as the keys run them: from run-shell, the terminal in TRAILS_CLIENT.
sock=$(tmux display-message -p '#{socket_path}')
step() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' '$TRAILS' ws $1"; }
step next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" || fail "next did not reach beta: $(on)"
step next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = alpha ]" || fail "next did not wrap to alpha: $(on)"
step prev
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" || fail "prev did not wrap to beta: $(on)"

# A terminal on a session grouped with alpha's steps on from alpha.
tmux new-session -d -t alpha -s 'alpha~2'
tmux switch-client -c "$term" -t '=alpha~2'
sleep 0.5
step next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" || fail "next from alpha~2 did not reach beta: $(on)"

# next and prev are no workspace's names.
"$TRAILS" ws add next "$T/code/a" >/dev/null 2>&1 && fail "'next' taken as a workspace name"
assert_match "$(cd "$T" && "$TRAILS" ws next 2>&1)" "in tmux" "outside tmux, said so"
