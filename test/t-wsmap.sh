#!/bin/sh
# The map a key away: prefix M (`trails map here`) goes to the map, which the status line
# lists after the workspaces as ▦ map; with none up, its pick (`trails map new`, in a popup)
# builds it, four trails at most from every workspace, the four that most want you ticked.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/code/b" "$T/other/c"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"], "beta": ["~/other/*"] } }
CFG

# Five trails over two workspaces; the first's driver is the one terminal, on alpha.
DRIVER_DIR=$T/code/a driver "$TRAILS" new t1
wait_for 5 screen_has alpha/t1 'agent id=' || fail "t1 never started"
driver_attached || fail "the terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt driver-1 '#{pane_tty}')" '$2 == t { print $1 }')
for n in t2 t3; do
  DRIVER_DIR=$T/code/b driver "$TRAILS" new "$n"
  wait_for 5 screen_has "alpha/$n" 'agent id=' || fail "$n never started"
done
for n in t4 t5; do
  DRIVER_DIR=$T/other/c driver "$TRAILS" new "$n"
  wait_for 5 screen_has "beta/$n" 'agent id=' || fail "$n never started"
done
for d in 2 3 4 5; do tmux kill-session -t "driver-$d" 2>/dev/null; done
tmux switch-client -c "$term" -t '=alpha:'
sleep 0.5

sock=$(tmux display-message -p '#{socket_path}')
as_term() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' $*"; }
on() { client_at "$term" '#{session_name}'; }
on_is() { wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = '$1' ]"; }

# The pick, as prefix M's popup runs it: every trail offered, from both workspaces; four at
# most taken; the terminal moved to the map.
rm -f "$T/d1"
as_term "FZF_PICK='!all:.' FZF_DUMP='$T/d1' '$TRAILS' map new"
on_is trails_map || fail "the terminal is not on the map: $(on)"
assert_eq "$(grep -cv '^--- ' "$T/d1")" 5 "all five trails offered"
assert_eq "$(tmux list-panes -t '=trails_map:' | wc -l | tr -d ' ')" 4 "four panes, no more"

# The status line lists the map after the workspaces.
"$TRAILS" keys | grep -E '^(set -g status-left|%if|%else|%endif)' | tmux source-file - || fail "tmux refused the status lines"
sleep 1
bar=$(tmux capture-pane -ep -t driver-1 | tail -n 1 | sed 's/\x1b\[[0-9;]*m//g')
assert_match "$bar" "^ alpha  beta  ▦ map │" "the workspaces, then the map"

# prefix M from a workspace goes to the map, building nothing.
tmux switch-client -c "$term" -t '=alpha:'
on_is alpha || fail "not back on alpha"
map_id=$(tmux display-message -pt '=trails_map:' '#{session_id}')
as_term "'$TRAILS' map here"
on_is trails_map || fail "prefix M did not go to the map: $(on)"
assert_eq "$(tmux display-message -pt '=trails_map:' '#{session_id}')" "$map_id" "the same map, not a new one"

# Outside tmux, it says where it works.
assert_match "$(cd "$T" && "$TRAILS" map here 2>&1)" "inside tmux" "outside tmux, said so"
