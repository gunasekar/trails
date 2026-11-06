#!/bin/sh
# A workspace whose name begins a window's: lattiq, and a trail of the codebase ~/w/lattiq
# itself, its window lattiq-1a2b. A bare -t lattiq is looked up as a window of the current
# session first, by prefix, and only then as a session: from outside tmux the current
# session is the most recent, the trail's own, whose window is lattiq-1a2b, with no
# @trails_workspace, and the workspace was refused as "isn't a trails workspace". Every check
# of a workspace's session names it exactly (=lattiq:).
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/w/lattiq/a"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "lattiq": ["~/w/lattiq/*", "~/w/lattiq"] } }
CFG

# Unnamed, as the picker's "＋ new trail…" starts one: its own session's window is lattiq-1a2b,
# the most recent session when the workspace's is looked for.
printf '%s\n' 'new trail' '    a$' 'stub · new trail' >"$T/pa"
DRIVER_DIR=$T/w/lattiq/a FZF_PICKS=$T/pa driver "$TRAILS"
wait_for 5 has_unnamed lattiq a || fail "a's trail never started: $(tmux ls)"
driver_attached || fail "a's trail never attached"
printf '%s\n' 'new trail' 'codebase itself' 'stub · new trail' >"$T/pr"
DRIVER_DIR=$T/w/lattiq FZF_PICKS=$T/pr driver "$TRAILS"
wait_for 5 has_unnamed lattiq lattiq ||
  fail "the trail in lattiq itself never started: $(tmux ls -F '#{session_name}' | tr '\n' ' ') $(tmux capture-pane -pt "driver-$DRIVERS" | grep trails:)"
driver_attached || fail "it never attached: $(tmux capture-pane -pt "driver-$DRIVERS" | grep -A1 trails:)"
printf '%s\n' 'new trail' 'w/lattiq/  ' 'stub · new trail' >"$T/pr"
DRIVER_DIR=$T/w/lattiq FZF_PICKS=$T/pr driver sh -c "'$TRAILS' 2>'$T/err'; sleep 5"
wait_for 5 sh -c "[ \$(tmux ls -F '#{session_name}' | grep -c '^lattiq/lattiq-') -ge 2 ]" ||
  fail "a second in lattiq itself never started: $(cat "$T/err")"
wait_for 5 sh -c "[ \$(tmux list-windows -t '=lattiq:' -F '#{window_name}' | grep -c '^lattiq-') -eq 2 ]" ||
  fail "not both in the workspace: $(tmux list-windows -t '=lattiq:' -F '#{window_name}' | tr '\n' ' ') $(cat "$T/err")"
# And going to the workspace by name, from outside tmux.
out=$(cd "$T" && "$TRAILS" ws lattiq </dev/null 2>&1 | grep "isn't a trails workspace")
assert_eq "$out" "" "trails ws lattiq goes to it"
exit 0
