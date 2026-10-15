#!/bin/sh
# The picker's screens: the workspaces from ~, a workspace's trails from a shell in its
# session, "＋ another codebase…" into a codebase's screen, a new workspace from ctrl-n, and
# the question a directory no workspace claims gets. And `trails ws NAME`.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/work/lattiq/augur" "$T/work/lattiq/ledger" "$T/work/lattiq/extra" "$T/.dotfiles" "$T/stray"
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

# Picking lattiq attaches to it, on its trail.
DRIVER_DIR=$T FZF_PICK='^workspace	lattiq' driver "$TRAILS"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -qx 'lattiq augur·api'" ||
  fail "picking lattiq did not attach to it"

# Picking personal, with nothing running, shows its screen: no trails, nothing to start
# from, only "another codebase…" — which lists ~/.dotfiles and leads to its screen, where
# "stub · new trail" starts a trail in personal.
rm -f "$T/d3"
printf '%s\n' '^workspace	personal' 'another codebase' '\.dotfiles$' 'stub · new trail' >"$T/p3"
DRIVER_DIR=$T FZF_PICKS=$T/p3 FZF_DUMP=$T/d3 driver "$TRAILS"
wait_for 5 screen_has personal/_dotfiles 'agent id=' || fail "no trail in personal: $(plain "$T/d3")"
assert_eq "$(dumped "$T/d3" 2 | cut -f1 | tr '\n' ' ')" "browse " "personal's screen: only the way to a codebase"
assert_match "$(dumped "$T/d3" 2 | cut -f3)" 'another codebase…  \([0-9]+ more under ~\)' "the count and root"
assert_match "$(dumped "$T/d3" 3 | cut -f2 | tr '\n' ' ')" '^~/\.dotfiles ~/proj .*~/work $' "its entry, then the directories under ~"
assert_eq "$(tmux list-windows -t personal -F '#{window_name}')" "_dotfiles·stub" "the trail's window"

# From a shell in the workspace session: lattiq's screen, with a codebase column, "new" rows
# for the codebase with a trail, and the rest behind "another codebase…".
tmux new-window -t lattiq -c "$T/work/lattiq/ledger" sh
rm -f "$T/d4"
type_in lattiq "FZF_DUMP=$T/d4 $TRAILS"
wait_for 5 test -s "$T/d4" || fail "the workspace screen never reached fzf"
rows=$(dumped "$T/d4" 1)
assert_match "$(printf '%s\n' "$rows" | grep '^attach' | cut -f3)" '● your turn +augur +stub' "the trail, under its codebase"
assert_eq "$(printf '%s\n' "$rows" | grep '^new' | cut -f2 | tr '\n' ' ')" "stub:$T/work/lattiq/augur other:$T/work/lattiq/augur " "new rows for augur, per agent"
assert_match "$(printf '%s\n' "$rows" | grep '^new' | head -n 1 | cut -f3)" '^ +augur +· new stub$' "drawn under the column"
assert_match "$(printf '%s\n' "$rows" | grep '^browse' | cut -f3)" '\(2 more under ~/work/lattiq\)' "ledger and extra behind the row"
assert_eq "$(printf '%s\n' "$rows" | cut -f1 | tr '\n' ' ')" "attach new new browse " "in that order"

# Picking "augur · new other" there starts it in augur and switches the client to it.
type_in lattiq "FZF_PICK='augur +· new other' $TRAILS"
wait_for 5 has_session lattiq/augur || fail "no second trail in augur"
wait_for 5 screen_has lattiq/augur 'agent (other)' || fail "the other agent never started"
assert_eq "$(tmux list-windows -t lattiq -F '#{window_name}' | grep '·' | sort | tr '\n' ' ')" "augur·api augur·other " "its window"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -qx 'lattiq augur·other'" ||
  fail "the client was not switched to the new trail"

# ctrl-n on the workspace picker names a new workspace, takes its first codebase from the
# directories under ~, and goes on to that codebase's screen.
printf '%s\n' '.' 'work$' 'stub · new trail' >"$T/p5"
printf '%s\n' ctrl-n >"$T/k5"
DRIVER_DIR=$T FZF_KEYS=$T/k5 FZF_QUERY=newws FZF_PICKS=$T/p5 driver "$TRAILS"
wait_for 5 screen_has newws/work 'agent id=' || fail "no trail in the new workspace"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.newws.codebases[0]' "$XDG_CONFIG_HOME/trails/config.json")" "~/work" "the config gained it"

# A directory no workspace claims is asked about once: adding it writes the config, and the
# codebase's screen follows.
printf '%s\n' 'add .* to personal' 'stub · new trail' >"$T/p6"
DRIVER_DIR=$T/stray FZF_PICKS=$T/p6 driver "$TRAILS"
wait_for 5 screen_has personal/stray 'agent id=' || fail "no trail in stray"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.personal.codebases | join(",")' "$XDG_CONFIG_HOME/trails/config.json")" "~/.dotfiles,~/stray" "stray added to personal"

# `trails ws NAME` goes there; an unknown name is refused; piped, `trails ws` lists.
DRIVER_DIR=$T driver "$TRAILS" ws personal
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx personal" || fail "ws personal did not attach"
assert_match "$(cd "$T" && "$TRAILS" ws nope 2>&1)" 'no workspace named "nope"' "unknown refused"
assert_eq "$(cd "$T" && "$TRAILS" ws | cut -f1 | tr '\n' ' ')" "lattiq personal newws " "piped list"
