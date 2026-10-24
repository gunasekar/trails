#!/bin/sh
# The picker's screens: the workspaces from ~, a workspace's trails from a shell in its
# session, "＋ new trail…" through the codebase tree and "browse…" to an agent, a new workspace
# from ctrl-n, and the question a directory no workspace claims gets. And `trails ws NAME`.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/work/lattiq/augur" "$T/work/lattiq/ledger" "$T/work/lattiq/extra" "$T/.dotfiles" "$T/stray" "$T/elsewhere/spike" "$T/work/lattiq/extra/deep"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [
    { "name": "stub", "program": "agent", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } },
    { "name": "other", "program": "agent --other",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": {
    "lattiq":   { "root": "~/work/lattiq", "codebases": ["~/work/lattiq/*"] },
    "personal": ["~/.dotfiles"] } }
CFG
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
# The rows of the Nth fzf a run opened (the stub numbers them in the dump).
dumped() { plain "$1" | awk -v n="$2" '/^--- / { cur = $2; next } cur == n'; }

# From ~: the workspaces, nothing running in either, no "default" since nothing is there.
rm -f "$T/d1"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d1 driver "$TRAILS"
wait_for 5 test -s "$T/d1" || fail "the workspace picker never reached fzf"
assert_eq "$(dumped "$T/d1" 1 | cut -f1,2 | tr '\t\n' '  ')" "workspace lattiq workspace personal " "the workspaces"
assert_match "$(dumped "$T/d1" 1 | head -n 1 | cut -f3)" '^lattiq +nothing running$' "drawn"

# Two lost trails in a workspace list it once (rec_ws prints no newline of its own).
mkdir -p "$STATE/personal"
printf 'agent=stub\ndir=%s\nid=a\nyolo=\ntask=\nworkspace=personal\nlabel=x\nname=\n' "$T/.dotfiles" >"$STATE/personal/x"
printf 'agent=stub\ndir=%s\nid=b\nyolo=\ntask=\nworkspace=personal\nlabel=y\nname=\n' "$T/.dotfiles" >"$STATE/personal/y"
rm -f "$T/d1b"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d1b driver "$TRAILS"
wait_for 5 test -s "$T/d1b" || fail "the workspace picker never reached fzf"
assert_eq "$(dumped "$T/d1b" 1 | cut -f2 | tr '\n' ' ')" "lattiq personal " "each workspace once"
rm -rf "$STATE/personal"

# A trail in augur: lattiq now shows it, and is marked as where you were.
DRIVER_DIR=$T/work/lattiq/augur driver "$TRAILS" new api
wait_for 5 screen_has lattiq/api 'agent id=' || fail "api never started"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx lattiq" || fail "not attached to lattiq"
rm -f "$T/d2"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d2 driver "$TRAILS"
wait_for 5 test -s "$T/d2" || fail "the workspace picker never reached fzf"
assert_match "$(dumped "$T/d2" 1 | head -n 1 | cut -f3)" '^lattiq +● 1 trail · 1 your turn +· last$' "lattiq counted and marked"

# Picking lattiq attaches to it, on its trail: a second client there (the first is the
# driver that started api), waited for by count, since the attach comes after BOOT.
DRIVER_DIR=$T FZF_PICK='^workspace	lattiq' driver "$TRAILS"
wait_for 10 sh -c "[ \"\$(tmux list-clients -F '#{session_name} #{window_name}' | grep -cx 'lattiq augur·api')\" -ge 2 ]" ||
  fail "picking lattiq did not attach to it: $(tmux list-clients -F '#{session_name} #{window_name}' | tr '\n' '|')"

# Picking personal, with nothing running, shows its screen: no trails, only "＋ new trail…" —
# which lists ~/.dotfiles, then its agents, where "stub · new trail" starts a trail in personal.
rm -f "$T/d3"
printf '%s\n' '^workspace	personal' 'new trail…' '\.dotfiles$' 'stub · new trail' >"$T/p3"
DRIVER_DIR=$T FZF_PICKS=$T/p3 FZF_DUMP=$T/d3 driver "$TRAILS"
wait_for 5 screen_has personal/_dotfiles 'agent id=' || fail "no trail in personal: $(plain "$T/d3")"
assert_eq "$(dumped "$T/d3" 2 | cut -f1 | tr '\n' ' ')" "browse " "personal's screen: only the way to a new trail"
assert_match "$(dumped "$T/d3" 2 | cut -f3)" 'new trail…  \(1 codebase\)$' "the count"
assert_eq "$(dumped "$T/d3" 3 | cut -f1 | tr '\n' ' ')" "$T/.dotfiles browse:$T " "its codebase, then browse…, not every folder under ~"
assert_eq "$(dumped "$T/d3" 4 | cut -f1,2 | tr '\t\n' '  ')" "new stub new other " "then the agents, and nothing else"
assert_eq "$(tmux list-windows -t personal -F '#{window_name}')" "_dotfiles" "the trail's window"

# From a shell in the workspace session: lattiq's screen, its trails with a codebase column,
# and "＋ new trail…" — no rows per codebase and agent.
shp=$(tmux new-window -P -F '#{pane_id}' -t lattiq -c "$T/work/lattiq/ledger" sh)
rm -f "$T/d4"
type_in "$shp" "FZF_DUMP=$T/d4 $TRAILS"
wait_for 5 test -s "$T/d4" || fail "the workspace screen never reached fzf"
rows=$(dumped "$T/d4" 1)
assert_match "$(printf '%s\n' "$rows" | grep '^attach' | cut -f3)" '● your turn +augur +stub' "the trail, under its codebase"
assert_match "$(printf '%s\n' "$rows" | grep '^browse' | cut -f3)" '\(3 codebases\)' "every codebase behind the row"
assert_eq "$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ')" "browse attach " "the way to a new trail first, then the trails"

# Esc on the agents goes back to the workspace's screen, not the codebase's: the re-entry says
# which screen, where an empty one would work it out from the session again.
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4a"
printf '%s\n' 'new trail…' 'ledger$' '!esc' '' >"$T/p4a"
type_in "$shp" "FZF_PICKS=$T/p4a FZF_DUMP=$T/d4a $TRAILS"
wait_for 5 sh -c "grep -q '^--- 4' '$T/d4a'" || fail "esc never came back: $(plain "$T/d4a" | tr '\n' '|')"
assert_eq "$(dumped "$T/d4a" 2 | cut -f1 | tr '\n' ' ')" \
  "browse:$T/work/lattiq $T/work/lattiq/augur $T/work/lattiq/extra $T/work/lattiq/ledger browse:$T/work/lattiq " \
  "the tree: the workspace directory, augur with its trail first, then the rest, then browse…"
assert_match "$(dumped "$T/d4a" 2 | sed -n 2p | cut -f2)" '^    augur +● 1 trail$' "drawn under it, with its trail"
assert_eq "$(dumped "$T/d4a" 3 | cut -f1 | tr '\n' ' ')" "new new " "ledger's agents"
assert_eq "$(dumped "$T/d4a" 4 | cut -f1 | tr '\n' ' ')" "browse attach " "back on lattiq's screen"

# "browse…" walks from the root to a folder no workspace claims: the question lists default
# first, then the workspace browsed from, and default starts the trail there, adding nothing.
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4w"
printf '%s\n' 'new trail…' 'browse…' '^up' '^up' 'elsewhere/$' 'spike/$' '^use' '^default' 'stub · new trail' >"$T/p4w"
type_in "$shp" "FZF_PICKS=$T/p4w FZF_DUMP=$T/d4w $TRAILS"
wait_for 10 has_session default/spike || fail "no trail in spike: $(plain "$T/d4w" | tail -n 12 | tr '\n' '|')"
assert_eq "$(dumped "$T/d4w" 3 | cut -f1 | tr '\n' ' ')" "use up in in in " "the walk from ~/work/lattiq"
assert_eq "$(dumped "$T/d4w" 8 | cut -f1 | tr '\n' ' ')" "default lattiq personal " "default first, then where you browsed from"
assert_match "$(dumped "$T/d4w" 8 | head -n 1 | cut -f2)" '^default +not added to a workspace$' "says what default means"
assert_eq "$(jq -r '[.workspaces[] | if type == "array" then .[] else .codebases[] end] | map(select(test("spike"))) | length' "$XDG_CONFIG_HOME/trails/config.json")" 0 "and adds it nowhere"

# Picked through, "＋ new trail…" starts the agent in the codebase picked and switches the
# client to it.
wait_shell "$shp" || fail "the shell never came back"
printf '%s\n' 'new trail…' 'ledger$' 'stub · new trail' >"$T/p4b"
type_in "$shp" "FZF_PICKS=$T/p4b $TRAILS"
wait_for 10 has_session lattiq/ledger || fail "no trail in ledger"
wait_shell "$shp" || fail "the shell never came back"
printf '%s\n' 'new trail…' '	    augur ' 'other · new trail' >"$T/p4c"
type_in "$shp" "FZF_PICKS=$T/p4c $TRAILS"
wait_for 10 has_session lattiq/augur ||
  fail "no second trail in augur; windows: $(tmux list-windows -t lattiq -F '#{window_name}' | tr '\n' ' '); pane: $(tmux capture-pane -pt "$shp" | grep -v '^$' | tail -3 | tr '\n' '|')"
wait_for 5 screen_has lattiq/augur 'agent (other)' || fail "the other agent never started"
# The trails' windows only, not the shell this test types into, whatever it is called.
wins() { tmux list-windows -t lattiq -F '#{?@trails_window,#{window_name},}' | grep . | sort | tr '\n' ' '; }
wait_for 5 sh -c "[ \"\$(tmux list-windows -t lattiq -F '#{@trails_window}' | grep -c .)\" -ge 3 ]" || true
assert_eq "$(wins)" "augur augur·api ledger " "its window"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -qx 'lattiq augur'" ||
  fail "the client was not switched to the new trail"

# A trail in a folder deeper than the tree lists belongs to its workspace directory's workspace
# without asking, and the tree lists it under that directory from then on.
DRIVER_DIR=$T/work/lattiq/extra/deep driver "$TRAILS" new deep
wait_for 5 screen_has lattiq/deep 'agent id=' || fail "no trail in extra/deep"
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4d"
printf '%s\n' 'new trail…' '!esc' '' >"$T/p4d"
type_in "$shp" "FZF_PICKS=$T/p4d FZF_DUMP=$T/d4d $TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d4d'" || fail "the tree never came back: $(plain "$T/d4d" | tr '\n' '|')"
assert_match "$(dumped "$T/d4d" 2 | grep "^$T/work/lattiq/extra/deep$(printf '\t')" | cut -f2)" '^    extra/deep +● 1 trail$' "extra/deep, under the workspace directory"

# Esc goes up a level: a codebase's screen to its workspace's, that to the workspaces, and
# there it quits. ctrl-c quits from any of them.
rm -f "$T/d7"
printf '%s\n' '!esc' '!esc' '!esc' >"$T/p7"
DRIVER_DIR=$T/work/lattiq/ledger FZF_PICKS=$T/p7 FZF_DUMP=$T/d7 driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d7'" || fail "esc never climbed: $(plain "$T/d7" | tr '\n' '|')"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7")" 3 "and quit at the top"
assert_eq "$(dumped "$T/d7" 1 | head -n 1 | cut -f1)" agents "ledger's screen"
assert_eq "$(dumped "$T/d7" 2 | head -n 1 | cut -f1)" browse "lattiq's"
assert_eq "$(dumped "$T/d7" 3 | cut -f1 | sort -u)" workspace "the workspaces"
rm -f "$T/d7b"
printf '%s\n' '^agents' '' >"$T/p7b"
DRIVER_DIR=$T/work/lattiq/ledger FZF_PICKS=$T/p7b FZF_DUMP=$T/d7b driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 2' '$T/d7b'" || fail "no agents screen"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7b")" 2 "ctrl-c on the agents quits"

# An editor's terminal sees one codebase: Esc on its screen quits.
rm -f "$T/d7e"
DRIVER_DIR=$T/work/lattiq/ledger FZF_PICK='!esc' FZF_DUMP=$T/d7e driver NVIM=1 "$TRAILS"
wait_for 5 test -s "$T/d7e" || fail "no picker from the editor"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7e")" 1 "esc in an editor quits"

# ctrl-n on the workspace picker names a new workspace, takes its first codebase from the
# directories under ~, and goes on to that codebase's screen.
printf '%s\n' '.' 'work$' '^agents' 'stub · new trail' >"$T/p5"
printf '%s\n' ctrl-n >"$T/k5"
DRIVER_DIR=$T FZF_KEYS=$T/k5 FZF_QUERY=newws FZF_PICKS=$T/p5 driver "$TRAILS"
wait_for 5 screen_has newws/work 'agent id=' || fail "no trail in the new workspace"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.newws.codebases[0]' "$XDG_CONFIG_HOME/trails/config.json")" "~/work" "the config gained it"

# A bare `trails` in a directory no workspace claims asks the same question: a workspace's row
# adds it there, and the codebase's screen follows.
printf '%s\n' '^personal' '^agents' 'stub · new trail' >"$T/p6"
DRIVER_DIR=$T/stray FZF_PICKS=$T/p6 driver "$TRAILS"
wait_for 5 screen_has personal/stray 'agent id=' || fail "no trail in stray"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.personal.codebases | join(",")' "$XDG_CONFIG_HOME/trails/config.json")" "~/.dotfiles,~/stray" "stray added to personal"

# `trails ws NAME` goes there; an unknown name is refused; piped, `trails ws` lists.
DRIVER_DIR=$T driver "$TRAILS" ws personal
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx personal" || fail "ws personal did not attach"
assert_match "$(cd "$T" && "$TRAILS" ws nope 2>&1)" 'no workspace named "nope"' "unknown refused"
assert_eq "$(cd "$T" && "$TRAILS" ws | cut -f1 | tr '\n' ' ')" "lattiq personal newws " "piped list"
