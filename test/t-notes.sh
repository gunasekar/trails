#!/bin/sh
# A codebase's notes: `trails note TEXT`, a line typed in prefix N's popup, the config's
# "notes" path, and a note from a popup over a trail's window, filed under its
# codebase.
. "$REPO/test/lib.sh"
t_setup

cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ] }
CFG
NOTES=$PROJ/.scratch/trails/notes.md

# From the command line: the file is made under a heading, and the note is an item, plain.
(cd "$PROJ" && "$TRAILS" note "first thought") >/dev/null || fail "trails note failed"
assert_eq "$(head -n 1 "$NOTES")" "# proj: notes" "the heading names the codebase"
assert_match "$(tail -n 1 "$NOTES")" "^- \[ \] first thought\$" "an item, nothing after it"

# Inside a git repository, from a folder in it: the notes are at the repository's top.
mkdir -p "$PROJ/repo/deep/er"
git -C "$PROJ/repo" init -q
(cd "$PROJ/repo/deep/er" && "$TRAILS" note "from deep") >/dev/null || fail "note from a subfolder failed"
assert_match "$(tail -n 1 "$PROJ/repo/.scratch/trails/notes.md")" '^- \[ \] from deep' "at the repo's root"

# Typed on the popup's line: Enter adds it, Esc adds nothing, and Enter on an empty line opens
# the notes.
typed() {
  DRIVER_DIR=$PROJ FZF_PICK=$1 FZF_QUERY=$2 driver env EDITOR=ed "$TRAILS" note
}
typed '!query' 'typed in the popup'
wait_for 5 sh -c "grep -q 'typed in the popup' '$NOTES'" || fail "the typed note was not added: $(screen "driver-$DRIVERS" | tr '\n' '|')"
assert_match "$(tail -n 1 "$NOTES")" "^- \[ \] typed in the popup\$" "an item"
before=$(cat "$NOTES")
typed '' 'never mind'
wait_for 5 no_session "driver-$DRIVERS" || fail "esc left trails note running"
assert_eq "$(cat "$NOTES")" "$before" "esc adds nothing"
typed '!query' ''
wait_for 5 screen_has "driver-$DRIVERS" "ed on $NOTES" || fail "an empty line did not open the notes: $(screen "driver-$DRIVERS" | tr '\n' '|')"
assert_eq "$(cat "$NOTES")" "$before" "and adds nothing"

# trails notes opens them.
DRIVER_DIR=$PROJ driver env EDITOR=ed "$TRAILS" notes
wait_for 5 screen_has "driver-$DRIVERS" "ed on $NOTES" || fail "the notes did not open: $(screen "driver-$DRIVERS" | tr '\n' '|')"

# The config's "notes": ~ and {codebase}, so one folder holds every codebase's notes.
cp "$XDG_CONFIG_HOME/trails/config.json" "$T/config.keep"
jq '.notes = "~/notes/{codebase}.md"' "$T/config.keep" >"$XDG_CONFIG_HOME/trails/config.json"
(cd "$PROJ" && "$TRAILS" note "kept elsewhere") >/dev/null || fail "note with a configured path failed"
assert_match "$(tail -n 1 "$T/notes/proj.md")" '^- \[ \] kept elsewhere' "at the configured path"
cp "$T/config.keep" "$XDG_CONFIG_HOME/trails/config.json"

# From a popup over a trail's window (no TMUX_PANE, the terminal in TRAILS_CLIENT): the note
# goes to the trail's codebase, wherever the popup started.
DRIVER_DIR=$PROJ driver "$TRAILS" new idea
wait_for 5 screen_has default/idea 'agent id=' || fail "idea never started"
driver_attached || fail "the trail's terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
[ -n "$term" ] || fail "no terminal on default"
sock=$(tmux display-message -p '#{socket_path}')
tmux run-shell -c "$T" "env TMUX='$sock,1,0' TRAILS_CLIENT='$term' '$TRAILS' note 'from the popup'"
wait_for 5 sh -c "grep -q 'from the popup' '$NOTES'" || fail "the popup's note did not reach the trail's codebase"
assert_match "$(tail -n 1 "$NOTES")" "^- \[ \] from the popup\$" "in the trail's codebase"

# Enter on an empty line there: the notes open in a popup of their own, sized for them, not in
# the one-line popup the note was typed in.
# shellcheck disable=SC2016 # the $(...) is the stand-in editor's, run when it opens
printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(stty size </dev/tty | cut -d" " -f1)" "$1" >"%s/opened"\n' "$T" >"$T/marked"
chmod +x "$T/marked"
tmux set-environment -g EDITOR "$T/marked"
tmux display-popup -c "$term" -h 3 -E "env FZF_PICK='!query' FZF_QUERY= '$TRAILS' note"
wait_for 5 test -s "$T/opened" || fail "the notes never opened in a popup"
rows=$(cut -d" " -f1 "$T/opened")
assert_eq "$(cut -d" " -f2- "$T/opened")" "$NOTES" "the notes"
[ "$rows" -gt 3 ] || fail "the notes opened $rows rows high, in the note's popup"

# trails keys offers the note box on prefix N.
assert_match "$("$TRAILS" keys)" "bind N display-popup .*\"'$TRAILS' note\"" "the binding"
