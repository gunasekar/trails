#!/bin/sh
# The one list (ADR 30): prefix P, a click on [session] or a bare trails lists everything worth
# going to on trails' server: each workspace, the one you're in first, with its trails (state,
# how long it has waited, codebase, agent, task), lost trails beside their codebase's and
# windows of yours, in window order; the map as a row of its own; then the sessions you made.
# Enter goes there. A star (prefix S, ctrl-s in the picker, trails star) marks a trail with ★,
# in its record too, so a restore keeps it.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$T/code/a" "$T/other/c"
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ],
  "workspaces": { "alpha": ["~/code/*"], "beta": ["~/other/*"] } }
CFG

DRIVER_DIR=$T/code/a driver "$TRAILS" new one
wait_for 5 screen_has alpha/one 'agent id=' || fail "one never started"
driver_attached || fail "the terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{client_tty}' | awk -v t="$(tmux display-message -pt driver-1 '#{pane_tty}')" '$2 == t { print $1 }')
DRIVER_DIR=$T/code/a driver "$TRAILS" new two
wait_for 5 screen_has alpha/two 'agent id=' || fail "two never started"
driver_attached || fail "two's driver never attached"
DRIVER_DIR=$T/other/c driver "$TRAILS" new three
wait_for 5 screen_has beta/three 'agent id=' || fail "three never started"
driver_attached || fail "three's driver never attached"
for d in 2 3; do tmux kill-session -t "driver-$d"; done
tmux new-window -d -t '=alpha:' -n notes 'sleep 300'
tmux new-session -d -s mine 'sleep 300'
type_in "$(tmux list-panes -t '=beta/three:' -F '#{pane_id}')" 'hook waiting'
wait_for 5 sh -c "[ \"\$(tmux show -pqv -t \"\$(tmux list-panes -t '=beta/three:' -F '#{pane_id}')\" @trails_state)\" = waiting ]" || fail "three never waiting"

sock=$(tmux display-message -p '#{socket_path}')
# The picker, as the terminal's prefix P runs it, its rows dumped and nothing picked.
picker() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' $* '$TRAILS' 2>>'$T/picker.err'"; }
menu() {
  rm -f "$T/dump"
  picker "FZF_DUMP='$T/dump'"
  sed 1d "$T/dump"
}
drawn() { menu | cut -f3 | perl -pe 's/\e\[[0-9;]*m//g' | sed 's/ *$//'; }
tid() { tmux display-message -pt "=$1:" '#{@trails_trail}'; }

# ── What it lists, in order ──────────────────────────────────────────────────────
tmux switch-client -c "$term" -t '=beta:'
rows=$(drawn)
order=$(printf '%s\n' "$rows" | sed -E 's/^ *(★ )? *[0-9]* *//' | awk '{ print $1 }' | tr '\n' ' ')
case $order in
  "＋ beta c·three alpha a·one a·two notes ── driver-1 mine ") ;;
  *) fail "not new trail, the workspace you're in first, their windows, then yours: $order" ;;
esac
assert_match "$rows" "beta +1 trail · 1 needs you" "a workspace's header says what it holds"
assert_match "$rows" "alpha +2 trails" "and the other's"
assert_match "$rows" "[0-9] c·three +needs you +[0-9]+m +c +stub" "a trail: number, name, state, for how long, codebase, agent"
assert_match "$rows" "[0-9] notes +yours" "a window of yours, in its workspace"
case $rows in *"alpha/"* | *"beta/"* | *"●"*) fail "a trail's own session listed, or a dot: $rows" ;; *) ;; esac
assert_match "$rows" "＋ new trail… +in c \(beta\)" "new trail, for the codebase you're on"
tmux switch-client -c "$term" -t '=alpha:'
assert_eq "$(drawn | sed -n 2p | awk '{ print $1 }')" alpha "the workspace you're in comes first"

# ── A star ──────────────────────────────────────────────────────────────────────
t2=$(tid alpha/two)
"$TRAILS" star "$t2"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" 1 "starred on its window"
assert_eq "$(grep -h '^starred=' "$STATE"/*/"$t2")" starred=1 "and in its record"
rows=$(drawn)
assert_match "$rows" "^ +★ [0-9] a·two +" "two has its star, in its place"
assert_eq "$(printf '%s\n' "$rows" | grep -c '★')" 1 "once: no list of the starred of its own"

# A restore keeps it.
tmux kill-session -t '=alpha/two'
"$TRAILS" restore >/dev/null 2>&1
wait_for 10 sh -c "tmux has-session -t '=alpha/two' 2>/dev/null" || fail "two never came back"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" 1 "still starred after a restore"
assert_eq "$(tmux list-windows -t '=alpha:' -F '#{@trails_window} #{@trails_starred}' | awk '$1 == "alpha/two" { print $2 }')" 1 "its workspace window too"

# Again: off.
"$TRAILS" star "$t2"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" "" "unstarred on its window"
assert_eq "$(grep -ch '^starred=' "$STATE"/*/"$t2")" 0 "and in its record"
"$TRAILS" star ''
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" "" "an empty TRAIL stars nothing"

# ctrl-s in the picker: the row's trail, and no other kind of row.
picker "FZF_PICK='a·two' FZF_KEYS=ctrl-s"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" 1 "ctrl-s stars the row's trail"
assert_match "$(drawn)" "★ [0-9] a·two" "and the list shows it"
picker "FZF_PICK=' notes ' FZF_KEYS=ctrl-s"
assert_eq "$(tmux list-windows -t '=alpha:' -F '#{window_name} #{@trails_starred}' | awk '$1 == "notes" { print $2 }')" "" "a window of yours takes no star"
picker "FZF_PICK='a·two' FZF_KEYS=ctrl-s"
assert_eq "$(tmux show -wqv -t '=alpha/two:' @trails_starred)" "" "ctrl-s again unstars it"

# ── Enter goes there ────────────────────────────────────────────────────────────
tmux switch-client -c "$term" -t '=alpha:'
picker "FZF_PICK='c·three'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" ||
  fail "Enter on three did not take the terminal to beta"
# To a window that isn't its workspace's current one: two, while alpha is on one.
tmux select-window -t "$(tmux list-windows -t '=alpha:' -F '#{window_id} #{@trails_window}' | awk '$2 == "alpha/one" { print $1 }')"
picker "FZF_PICK='a·two '"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = alpha ]" ||
  fail "Enter on two did not take the terminal to alpha"
assert_eq "$(tmux display-message -p -t '=alpha:' '#{@trails_window}')" alpha/two "and to two's window"
# A workspace's header: to it. A session of yours: to it.
picker "FZF_PICK='beta.{0,8}  [0-9] trail'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = beta ]" ||
  fail "Enter on beta's header did not go to beta: $(cat $T/picker.err)"
picker "FZF_PICK='  mine$'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = mine ]" ||
  fail "Enter on mine did not go to mine: $(cat $T/picker.err) $(tmux list-clients -F '#{client_name} #{session_name}')"
tmux switch-client -c "$term" -t '=alpha:'
# The cursor starts on where you are: two's row, from two's window.
want=$(menu | awk -F'\t' '$3 ~ /a·two/ { print NR }')
[ -n "$want" ] || fail "no row for two"

# ── Next: the starred trail that most wants you ─────────────────────────────────
on_term() { tmux list-clients -F '#{client_name} #{session_name} #{window_id}' | awk -v c="$term" '$1 == c { print $2 " " $3 }'; }
next() { tmux run-shell "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' '$TRAILS' next"; }
wid_of() { tmux list-windows -t "=$1:" -F '#{window_id} #{@trails_window}' | awk -v t="$2" '$2 == t { print $1 }'; }
before=$(on_term)
next
sleep 0.5
assert_eq "$(on_term)" "$before" "nothing starred, next stays"
# three needs you, in beta, seen already; one is done with a turn, its bell not yet seen.
"$TRAILS" star "$(tid beta/three)"
"$TRAILS" star "$(tid alpha/one)"
a1=$(tmux list-panes -t '=alpha/one:' -F '#{pane_id}' | head -n 1)
type_in "$a1" 'hook working'
sleep 0.3
type_in "$a1" 'hook idle'
wait_for 5 sh -c "[ \"\$(tmux display-message -p -t '$(wid_of alpha alpha/one)' '#{window_bell_flag}')\" = 1 ]" || fail "one's bell never rang"
next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = '$(wid_of alpha alpha/one)' ]" ||
  fail "next did not go to one, unseen, first: $(on_term)"
next
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{window_id}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = '$(wid_of beta beta/three)' ]" ||
  fail "next again did not go on to three: $(on_term)"
assert_eq "$(on_term | cut -d' ' -f1)" beta "in its workspace"

# ── The keys ────────────────────────────────────────────────────────────────────
"$TRAILS" keys | tmux source-file - || fail "tmux refused the keys"
assert_eq "$(tmux list-keys -T prefix W 2>/dev/null)" "" "no prefix W: the picker has it all"
assert_eq "$(tmux list-keys -T prefix A 2>/dev/null)" "" "no prefix A"
assert_match "$(tmux list-keys -T root MouseDown1StatusLeft)" "display-popup .*-w .60%.*/trails. [|][|]" "the click, the picker"
assert_match "$(tmux list-keys -T prefix S)" "run-shell .* star" "prefix S, a star"
assert_match "$(tmux list-keys -T prefix F)" "run-shell .* next" "prefix F, next"

# ── A lost trail, beside its codebase's ────────────────────────────────────────
# alpha holds one and two (codebase a) and notes: one, lost, follows two, the last of a's.
tmux kill-session -t '=alpha/one'
wait_for 5 sh -c "! tmux list-windows -t '=alpha:' -F '#{@trails_window}' | grep -qx alpha/one" || fail "one's window stayed"
tmux switch-client -c "$term" -t '=alpha:'
rows=$(drawn)
assert_eq "$(printf '%s\n' "$rows" | sed -n '/^alpha /,/^beta /p' | sed -E 's/^ *(★ )? *[0-9]* *//' | awk '{ print $1, $2 }' | tr '\n' '|')" \
  "alpha 1|a·two your|a·one lost|notes yours|beta 1|" "one, lost, after two, before notes"
assert_match "$rows" "^alpha +1 trail · .*1 lost" "the header counts it"
assert_match "$rows" "a·one +lost +a +stub +agent ready" "drawn as lost, with its codebase, agent and task"
picker "FZF_PICK='a·one +lost'"
wait_for 10 sh -c "tmux has-session -t '=alpha/one' 2>/dev/null" || fail "Enter on the lost row did not restore it"

# ── The map ──────────────────────────────────────────────────────────────────────
"$TRAILS" map 2 >/dev/null 2>&1 </dev/null
wait_for 5 sh -c "tmux has-session -t '=trails_map' 2>/dev/null" || fail "no map"
rows=$(drawn)
assert_eq "$(printf '%s\n' "$rows" | sed -n 2p | cut -c1-5)" "▦ map" "the map, its own row under new trail"
assert_match "$(printf '%s\n' "$rows" | sed -n 2p)" "2 trails · c·three needs you" "with what it shows, and who wants you"
case $(printf '%s\n' "$rows" | sed -n '/── yours ──/,$p') in *map*) fail "the map among yours" ;; *) ;; esac
picker "FZF_PICK='^map	'"
wait_for 5 sh -c "[ \"\$(tmux list-clients -F '#{client_name} #{session_name}' | awk -v c='$term' '\$1 == c { print \$2 }')\" = trails_map ]" ||
  fail "Enter on the map did not go to it"
assert_eq "$(menu | awk -F'\t' '$1 == "map" { print NR }')" 2 "the map's row"
picker "FZF_PICK='^map	' FZF_KEYS=ctrl-x"
wait_for 5 sh -c "! tmux has-session -t '=trails_map' 2>/dev/null" || fail "ctrl-x left the map"
tmux has-session -t '=beta/three' || fail "closing the map ended a trail"

# ── Esc closes it ───────────────────────────────────────────────────────────────
rm -f "$T/dump"
picker "FZF_PICK='!esc' FZF_DUMP='$T/dump'"
sleep 0.5
assert_eq "$(grep -c '^--- ' "$T/dump")" 1 "esc closes the picker"

# ── The preview: the popup's, not a terminal's ─────────────────────────────────────
# In the popup (tmux, no pane of its own) the preview shows; a bare `trails` in a terminal
# starts without it, and ctrl-/ still brings it. Both 40 rows, room for a preview.
FZF_PICK='!esc' driver env "TMUX=$sock,1,0" "TRAILS_CLIENT=$term" "FZF_ARGS=$T/args-popup" "$TRAILS"
wait_for 5 grep -q '^--preview-window=' "$T/args-popup" || fail "the popup's picker never opened"
pw=$(grep '^--preview-window=' "$T/args-popup")
case $pw in *hidden*) fail "the popup hid its preview: $pw" ;; *) ;; esac
FZF_PICK='!esc' driver env "FZF_ARGS=$T/args-term" "$TRAILS"
wait_for 5 grep -q '^--preview-window=' "$T/args-term" || fail "the terminal's picker never opened"
assert_match "$(grep '^--preview-window=' "$T/args-term")" ',hidden$' "a terminal's list starts without the preview"
grep -qx -- '--bind=ctrl-/:toggle-preview' "$T/args-term" || fail "ctrl-/ no longer brings it"
