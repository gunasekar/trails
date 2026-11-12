#!/bin/sh
# The picker's screens around the one list (ADR 30): every workspace, from ~ or from a shell
# in a workspace's session, "＋ new trail…" through the codebase tree and "browse…" to an agent,
# a workspace with nothing running, a new workspace from ctrl-n, and the question a directory
# no workspace claims gets. And `trails ws NAME`.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/work/acme/orbit" "$T/work/acme/ledger" "$T/work/acme/extra" "$T/.dotfiles" "$T/stray" "$T/elsewhere/spike" "$T/work/acme/extra/deep"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [
    { "name": "stub", "program": "agent", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } },
    { "name": "other", "program": "agent --other",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": {
    "acme":   { "root": "~/work/acme", "codebases": ["~/work/acme/*"] },
    "personal": ["~/.dotfiles"] } }
CFG
plain() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }
# The rows of the Nth fzf a run opened (the stub numbers them in the dump).
dumped() { plain "$1" | awk -v n="$2" '/^--- / { cur = $2; next } cur == n'; }

# From ~: the workspaces, nothing running in either, no "default" since nothing is there.
rm -f "$T/d1"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d1 driver "$TRAILS"
wait_for 5 test -s "$T/d1" || fail "the picker never reached fzf"
assert_eq "$(dumped "$T/d1" 1 | grep '^workspace' | cut -f1,2 | tr '\t\n' '  ')" "workspace acme workspace personal " "the workspaces"
assert_match "$(dumped "$T/d1" 1 | grep '^workspace' | head -n 1 | cut -f3)" '^acme +nothing running$' "drawn"

# Two lost trails in a workspace list it once (rec_ws prints no newline of its own). Written
# as 1.7 wrote them, so the run moves them to 1.8's layout first (rec_migrate).
mkdir -p "$STATE/personal"
printf 'agent=stub\ndir=%s\nid=a\nyolo=\ntask=\nworkspace=personal\nlabel=x\nname=\nserver=default\n' "$T/.dotfiles" >"$STATE/personal/x"
printf 'agent=stub\ndir=%s\nid=b\nyolo=\ntask=\nworkspace=personal\nlabel=y\nname=\nserver=default\n' "$T/.dotfiles" >"$STATE/personal/y"
rm -f "$T/d1b"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d1b driver "$TRAILS"
wait_for 5 test -s "$T/d1b" || fail "the picker never reached fzf"
assert_eq "$(dumped "$T/d1b" 1 | grep '^workspace' | cut -f2 | tr '\n' ' ')" "acme personal " "each workspace once"
assert_eq "$(dumped "$T/d1b" 1 | awk -F'\t' '$1 == "workspace" { w = $2 } $1 == "restore" { print w }' | tr '\n' ' ')" "personal personal " "the lost trails, in their workspace"
assert_match "$(dumped "$T/d1b" 1 | grep '^workspace	personal' | cut -f3)" '2 lost' "which counts them"
rm -f "$(trec personal/x)" "$(trec personal/y)"

# A trail in orbit: acme now counts it.
DRIVER_DIR=$T/work/acme/orbit driver "$TRAILS" new api
wait_for 5 screen_has acme/api 'agent id=' || fail "api never started"
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx acme" || fail "not attached to acme"
rm -f "$T/d2"
DRIVER_DIR=$T FZF_PICK='' FZF_DUMP=$T/d2 driver "$TRAILS"
wait_for 5 test -s "$T/d2" || fail "the picker never reached fzf"
assert_match "$(dumped "$T/d2" 1 | grep '^workspace	acme' | cut -f3)" '^acme +1 trail · 1 your turn$' "acme counted"

# Picking acme, with a trail running, is a new trail there too: its codebase tree, not its
# trail (which is a row of its own). Esc comes back to the list.
rm -f "$T/d2b"
printf '%s\n' '^workspace	acme' '!esc' '' >"$T/p2b"
DRIVER_DIR=$T FZF_PICKS=$T/p2b FZF_DUMP=$T/d2b driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d2b'" || fail "esc never came back: $(plain "$T/d2b" | tr '\n' '|')"
assert_match "$(dumped "$T/d2b" 2 | cut -f1 | tr '\n' ' ')" "$T/work/acme/orbit .*browse:" "acme's codebase tree"
assert_match "$(dumped "$T/d2b" 3 | sed -n 1p)" "new trail" "back on the list"
assert_eq "$(tmux list-clients -F '#{session_name} #{window_name}' | grep -cx 'acme orbit·api')" 1 "and not attached to api"
# A second terminal on acme, for the shell below to be seen in: `trails ws` attaches.
DRIVER_DIR=$T driver "$TRAILS" ws acme
wait_for 10 sh -c "[ \"\$(tmux list-clients -F '#{session_name}' | grep -cx acme)\" -ge 2 ]" ||
  fail "trails ws acme did not attach: $(tmux list-clients -F '#{session_name} #{window_name}' | tr '\n' '|')"

# Picking personal, with nothing running, starts a trail there: its codebase tree lists
# ~/.dotfiles, then its agents, where "stub · new trail" starts a trail in personal.
rm -f "$T/d3"
printf '%s\n' '^workspace	personal' '\.dotfiles$' 'stub · new trail' >"$T/p3"
DRIVER_DIR=$T FZF_PICKS=$T/p3 FZF_DUMP=$T/d3 driver "$TRAILS"
wait_for 5 has_unnamed personal _dotfiles || fail "no trail in personal: $(plain "$T/d3")"
dots=$(unnamed personal _dotfiles 1)
wait_for 5 screen_has "$dots" 'agent id=' || fail "the agent never started in personal"
assert_eq "$(dumped "$T/d3" 2 | cut -f1 | tr '\n' ' ')" "$T/.dotfiles browse:$T " "its codebase, then browse…, not every folder under ~"
assert_eq "$(dumped "$T/d3" 3 | cut -f1,2 | tr '\t\n' '  ')" "new stub new other " "then the agents, and nothing else"
assert_eq "$(tmux list-windows -t personal -F '#{window_name}')" "${dots#personal/}" "the trail's window"

# From a shell in the workspace session: acme first, its trails with a codebase column, and
# "＋ new trail…" for acme — no rows per codebase and agent.
shp=$(tmux new-window -P -F '#{pane_id}' -t acme -c "$T/work/acme/ledger" sh)
rm -f "$T/d4"
type_in "$shp" "FZF_DUMP=$T/d4 $TRAILS"
wait_for 5 test -s "$T/d4" || fail "the picker never reached fzf"
rows=$(dumped "$T/d4" 1)
assert_match "$(printf '%s\n' "$rows" | grep '^attach' | cut -f3)" 'orbit·api +your turn .* orbit +stub' "the trail, with its codebase"
assert_match "$(printf '%s\n' "$rows" | grep '^browse' | cut -f3)" 'in acme \(3 codebases\)' "every codebase behind the row"
assert_eq "$(printf '%s\n' "$rows" | cut -f1,2 | sed -n 1,4p | cut -f1 | tr '\n' ' ')" "browse workspace attach window " "the way to a new trail first, then acme, its trail and the shell"

# Esc on the agents goes back to the picker.
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4a"
printf '%s\n' 'new trail…' 'ledger$' '!esc' '' >"$T/p4a"
type_in "$shp" "FZF_PICKS=$T/p4a FZF_DUMP=$T/d4a $TRAILS"
wait_for 5 sh -c "grep -q '^--- 4' '$T/d4a'" || fail "esc never came back: $(plain "$T/d4a" | tr '\n' '|')"
assert_eq "$(dumped "$T/d4a" 2 | cut -f1 | tr '\n' ' ')" \
  "browse:$T/work/acme $T/work/acme/orbit $T/work/acme/extra $T/work/acme/ledger browse:$T/work/acme " \
  "the tree: the workspace directory, orbit with its trail first, then the rest, then browse…"
assert_match "$(dumped "$T/d4a" 2 | sed -n 2p | cut -f2)" '^    orbit +● 1 trail$' "drawn under it, with its trail"
assert_eq "$(dumped "$T/d4a" 3 | cut -f1 | tr '\n' ' ')" "new new " "ledger's agents"
assert_eq "$(dumped "$T/d4a" 4 | head -n 1 | cut -f1,2 | tr '\t' ' ')" "browse acme" "back on the picker"

# "browse…" walks from the root to a folder no workspace claims: the question lists default
# first, then the workspace browsed from, and default starts the trail there, adding nothing.
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4w"
printf '%s\n' 'new trail…' 'browse…' '^up' '^up' 'elsewhere/$' 'spike/$' '^use' '^default' 'stub · new trail' >"$T/p4w"
type_in "$shp" "FZF_PICKS=$T/p4w FZF_DUMP=$T/d4w $TRAILS"
wait_for 10 has_unnamed default spike || fail "no trail in spike: $(plain "$T/d4w" | tail -n 12 | tr '\n' '|')"
assert_eq "$(dumped "$T/d4w" 3 | cut -f1 | tr '\n' ' ')" "use up in in in " "the walk from ~/work/acme"
assert_eq "$(dumped "$T/d4w" 8 | cut -f1 | tr '\n' ' ')" "default acme personal " "default first, then where you browsed from"
assert_match "$(dumped "$T/d4w" 8 | head -n 1 | cut -f2)" '^default +not added to a workspace$' "says what default means"
assert_eq "$(jq -r '[.workspaces[] | if type == "array" then .[] else .codebases[] end] | map(select(test("spike"))) | length' "$XDG_CONFIG_HOME/trails/config.json")" 0 "and adds it nowhere"

# Picked through, "＋ new trail…" starts the agent in the codebase picked and switches the
# client to it.
wait_shell "$shp" || fail "the shell never came back"
printf '%s\n' 'new trail…' 'ledger$' 'stub · new trail' >"$T/p4b"
type_in "$shp" "FZF_PICKS=$T/p4b $TRAILS"
wait_for 10 has_unnamed acme ledger || fail "no trail in ledger"
ledger=$(unnamed acme ledger 1)
wait_shell "$shp" || fail "the shell never came back"
printf '%s\n' 'new trail…' '	    orbit ' 'other · new trail' >"$T/p4c"
type_in "$shp" "FZF_PICKS=$T/p4c $TRAILS"
wait_for 10 has_unnamed acme orbit ||
  fail "no second trail in orbit; windows: $(tmux list-windows -t acme -F '#{window_name}' | tr '\n' ' '); pane: $(tmux capture-pane -pt "$shp" | grep -v '^$' | tail -3 | tr '\n' '|')"
orbit=$(unnamed acme orbit 1)
wait_for 5 screen_has "$orbit" 'agent (other)' || fail "the other agent never started"
# The trails' windows only, not the shell this test types into, whatever it is called.
wins() { tmux list-windows -t acme -F '#{?@trails_window,#{window_name},}' | grep . | sort | tr '\n' ' '; }
wait_for 5 sh -c "[ \"\$(tmux list-windows -t acme -F '#{@trails_window}' | grep -c .)\" -ge 3 ]" || true
assert_eq "$(wins)" "$(printf '%s\n' "${orbit#acme/}" orbit·api "${ledger#acme/}" | sort | tr '\n' ' ')" "its window"
wait_for 5 sh -c "tmux list-clients -F '#{session_name} #{window_name}' | grep -qx 'acme ${orbit#acme/}'" ||
  fail "the client was not switched to the new trail"

# A trail in a folder deeper than the tree lists belongs to its workspace directory's workspace
# without asking, and the tree lists it under that directory from then on.
DRIVER_DIR=$T/work/acme/extra/deep driver "$TRAILS" new deep
wait_for 5 screen_has acme/deep 'agent id=' || fail "no trail in extra/deep"
wait_shell "$shp" || fail "the shell never came back"
rm -f "$T/d4d"
printf '%s\n' 'new trail…' '!esc' '' >"$T/p4d"
type_in "$shp" "FZF_PICKS=$T/p4d FZF_DUMP=$T/d4d $TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d4d'" || fail "the tree never came back: $(plain "$T/d4d" | tr '\n' '|')"
assert_match "$(dumped "$T/d4d" 2 | grep "^$T/work/acme/extra/deep$(printf '\t')" | cut -f2)" '^    extra/deep +● 1 trail$' "extra/deep, under the workspace directory"

# Esc closes the picker; ctrl-c quits from any screen. From a codebase, "＋ new trail…" says so,
# and opens its workspace's tree on it.
rm -f "$T/d7"
printf '%s\n' '!esc' '!esc' >"$T/p7"
DRIVER_DIR=$T/work/acme/ledger FZF_PICKS=$T/p7 FZF_DUMP=$T/d7 driver "$TRAILS"
wait_for 5 test -s "$T/d7" || fail "no picker"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7")" 1 "esc closes it"
assert_eq "$(dumped "$T/d7" 1 | head -n 1 | cut -f1,2 | tr '\t' ' ')" "browse acme" "new trail, through acme's tree"
assert_match "$(dumped "$T/d7" 1 | head -n 1 | cut -f3)" 'in ledger \(acme\)$' "for ledger"
rm -f "$T/d7b"
printf '%s\n' 'new trail…' 'acme/ledger	' '' >"$T/p7b"
DRIVER_DIR=$T/work/acme/ledger FZF_PICKS=$T/p7b FZF_DUMP=$T/d7b driver "$TRAILS"
wait_for 5 sh -c "grep -q '^--- 3' '$T/d7b'" || fail "no agents screen: $(plain "$T/d7b" | tr "\n" "|")"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7b")" 3 "ctrl-c on the agents quits"

# An editor's terminal sees one codebase: Esc on its screen quits.
rm -f "$T/d7e"
DRIVER_DIR=$T/work/acme/ledger FZF_PICK='!esc' FZF_DUMP=$T/d7e driver NVIM=1 "$TRAILS"
wait_for 5 test -s "$T/d7e" || fail "no picker from the editor"
sleep 1
assert_eq "$(grep -c '^--- ' "$T/d7e")" 1 "esc in an editor quits"

# ctrl-n on the picker names a new workspace, takes its first codebase from the directories
# under ~, and goes on to that codebase's agents.
printf '%s\n' '.' 'work$' 'stub · new trail' >"$T/p5"
printf '%s\n' ctrl-n >"$T/k5"
DRIVER_DIR=$T FZF_KEYS=$T/k5 FZF_QUERY=newws FZF_PICKS=$T/p5 driver "$TRAILS"
wait_for 5 screen_has newws/work 'agent id=' || fail "no trail in the new workspace"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.newws.codebases[0]' "$XDG_CONFIG_HOME/trails/config.json")" "~/work" "the config gained it"

# A new trail in a directory no workspace claims asks the same question: a workspace's row
# adds it there, and the agents follow.
printf '%s\n' '^agents' '^personal' 'stub · new trail' >"$T/p6"
DRIVER_DIR=$T/stray FZF_PICKS=$T/p6 driver "$TRAILS"
wait_for 5 has_unnamed personal stray || fail "no trail in stray"
wait_for 5 screen_has "$(unnamed personal stray 1)" 'agent id=' || fail "the agent never started in stray"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.personal.codebases | join(",")' "$XDG_CONFIG_HOME/trails/config.json")" "~/.dotfiles,~/stray" "stray added to personal"

# `trails ws NAME` goes there; an unknown name is refused; piped, `trails ws` lists.
DRIVER_DIR=$T driver "$TRAILS" ws personal
wait_for 5 sh -c "tmux list-clients -F '#{session_name}' | grep -qx personal" || fail "ws personal did not attach"
assert_match "$(cd "$T" && "$TRAILS" ws nope 2>&1)" 'no workspace named "nope"' "unknown refused"
assert_eq "$(cd "$T" && "$TRAILS" ws | cut -f1 | tr '\n' ' ')" "acme personal newws " "piped list"
