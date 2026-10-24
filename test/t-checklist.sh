#!/bin/sh
# A codebase's checklist: `trails note TEXT`, the list prefix N opens (a new item typed, an
# item ticked or copied), the config's "checklist" path (and the "notes" it was), the old
# notes file moved, an item from a popup over a trail's window, and the count for the status
# line.
. "$REPO/test/lib.sh"
t_setup

cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ] }
CFG
NOTES=$PROJ/.trails/checklist.md

# From the command line: the file is made under a heading, and the note is an item, plain.
(cd "$PROJ" && "$TRAILS" note "first thought") >/dev/null || fail "trails note failed"
assert_eq "$(head -n 1 "$NOTES")" "# proj: checklist" "the heading names the codebase"
assert_match "$(tail -n 1 "$NOTES")" "^- \[ \] first thought\$" "an item, nothing after it"

# Inside a git repository, from a folder in it: the notes are at the repository's top.
mkdir -p "$PROJ/repo/deep/er"
git -C "$PROJ/repo" init -q
(cd "$PROJ/repo/deep/er" && "$TRAILS" note "from deep") >/dev/null || fail "note from a subfolder failed"
assert_match "$(tail -n 1 "$PROJ/repo/.trails/checklist.md")" '^- \[ \] from deep' "at the repo's root"

# The notes file from before 1.7 is moved to the checklist's name the first time it is wanted.
mkdir -p "$PROJ/old/.scratch/trails"
printf '# old: notes\n\n- [ ] kept\n' >"$PROJ/old/.scratch/trails/notes.md"
(cd "$PROJ/old" && "$TRAILS" note "added") >/dev/null
assert_no_file "$PROJ/old/.scratch/trails/notes.md" "the old file moved"
assert_eq "$(grep -c '^- \[ \]' "$PROJ/old/.trails/checklist.md")" 2 "with its items, and the new one"
# So is one from 1.7's first builds, under .scratch.
mkdir -p "$PROJ/early/.scratch/trails"
printf '# early: checklist\n\n- [ ] kept\n' >"$PROJ/early/.scratch/trails/checklist.md"
(cd "$PROJ/early" && "$TRAILS" note "added") >/dev/null
assert_no_file "$PROJ/early/.scratch/trails/checklist.md" "the .scratch checklist moved"
assert_eq "$(grep -c '^- \[ \]' "$PROJ/early/.trails/checklist.md")" 2 "to .trails, with its items"

# The list: typed and Enter adds an item; Esc adds nothing; with nothing typed, Enter copies
# the item under the cursor (into tmux's buffer, here the test server's) and ctrl-e opens the
# file. The stub fzf types FZF_QUERY and lands on the row FZF_PICK matches.
list() { # pick, query, [key]
  DRIVER_DIR=$PROJ FZF_PICK=$1 FZF_QUERY=$2 FZF_KEY=${3:-} driver env EDITOR=ed "$TRAILS" checklist
}
list '!query' 'typed in the popup'
wait_for 5 sh -c "grep -q 'typed in the popup' '$NOTES'" || fail "the typed item was not added: $(screen "driver-$DRIVERS" | tr '\n' '|')"
assert_match "$(tail -n 1 "$NOTES")" "^- \[ \] typed in the popup\$" "an item"
before=$(cat "$NOTES")
list '' 'never mind'
wait_for 5 no_session "driver-$DRIVERS" || fail "esc left the checklist running"
assert_eq "$(cat "$NOTES")" "$before" "esc adds nothing"
# Inside tmux, as the list always is from prefix N, so the copy goes to tmux's buffer.
tmux new-session -d -s copier -c "$PROJ" "env FZF_PICK='first thought' FZF_QUERY= '$TRAILS' checklist; sleep 9"
wait_for 5 sh -c "[ \"\$(tmux show-buffer 2>/dev/null)\" = 'first thought' ]" || fail "enter on an item did not copy it: [$(tmux show-buffer 2>&1)]"
assert_eq "$(cat "$NOTES")" "$before" "and adds nothing"
list 'first thought' '' ctrl-e
wait_for 5 screen_has "driver-$DRIVERS" "ed on $NOTES" || fail "ctrl-e did not open the checklist: $(screen "driver-$DRIVERS" | tr '\n' '|')"

# The rows, open items first; ticking one (space, in the list) moves it to the done ones, and
# again back; only an item's own line is touched.
printf '\nsome prose\n- [x] already done\n- [ ] second\n  its detail\n' >>"$NOTES"
rows() { "$TRAILS" checklist --rows "$NOTES" | sed 's/\x1b\[[0-9;]*m//g' | cut -f2 | tr '\n' '|'; }
assert_eq "$(rows)" "☐ first thought|☐ typed in the popup|☐ second|☑ already done|" "open first, then done"
line=$(grep -n '^- \[ \] second' "$NOTES" | cut -d: -f1)
"$TRAILS" checklist --toggle "$NOTES" "$line"
assert_match "$(sed -n "${line}p" "$NOTES")" '^- \[x\] second$' "ticked"
"$TRAILS" checklist --toggle "$NOTES" "$((line + 1))"
assert_eq "$(sed -n "$((line + 1))p" "$NOTES")" "  its detail" "a line that is no item, left alone"
assert_eq "$(cd "$PROJ" && "$TRAILS" checklist --count "$PROJ")" "☑ 2/4 " "the count: open of all"
"$TRAILS" checklist --toggle "$NOTES" "$line"
assert_match "$(sed -n "${line}p" "$NOTES")" '^- \[ \] second$' "and back"
tmux run-shell "'$TRAILS' checklist --copy '$NOTES' $line"
assert_eq "$(tmux show-buffer)" "second
its detail" "an item copied with the lines under it"
assert_eq "$(cd "$T" && "$TRAILS" checklist --count "$T")" "" "no count where there is no checklist"

# An item of several paragraphs is copied with its blank lines.
(cd "$PROJ" && "$TRAILS" note "$(printf 'Refactor X\n\nKeep the API\n\nAdd tests')") >/dev/null
line=$(grep -n '^- \[ \] Refactor X' "$NOTES" | cut -d: -f1)
tmux run-shell "'$TRAILS' checklist --copy '$NOTES' $line"
assert_eq "$(tmux show-buffer)" "$(printf 'Refactor X\n\nKeep the API\n\nAdd tests')" "its paragraphs kept"
# Enter in the list (a transform): with nothing typed, accept, to copy and close; with an item
# typed, it is added and the list stays, reloaded, the cursor on the new item, the last open one.
assert_eq "$("$TRAILS" checklist --enter "$NOTES" proj '  ')" "accept-or-print-query" "nothing typed: accept"
n_open=$(grep -c '^- \[ \] ' "$NOTES")
acts=$("$TRAILS" checklist --enter "$NOTES" proj 'typed and kept')
assert_match "$(tail -n 1 "$NOTES")" '^- \[ \] typed and kept$' "the item added"
assert_match "$acts" "^clear-query\+reload-sync\('$TRAILS' checklist --rows '$NOTES'\)\+pos\($((n_open + 1))\)\$" "the list reloaded, on it"
assert_eq "$("$TRAILS" checklist --rows "$NOTES" | sed -n "$((n_open + 1))p" | cut -f2)" "☐ typed and kept" "which is that row"
# The pane under the list shows the item whole, as it is copied; over an empty list, nothing.
assert_eq "$("$TRAILS" checklist --text "$NOTES" "$line")" "$(printf 'Refactor X\n\nKeep the API\n\nAdd tests')" "the item whole, in the pane"
assert_eq "$("$TRAILS" checklist --text "$NOTES" '')" "" "nothing for no row"

# A checklist that is a link (into a synced folder, say) stays one when an item is ticked.
mkdir -p "$PROJ/linked/.trails" "$T/vault"
printf '# linked: checklist\n\n- [ ] in the vault\n' >"$T/vault/linked.md"
ln -s "$T/vault/linked.md" "$PROJ/linked/.trails/checklist.md"
"$TRAILS" checklist --toggle "$PROJ/linked/.trails/checklist.md" 3
[ -L "$PROJ/linked/.trails/checklist.md" ] || fail "ticking replaced the link with a file"
assert_match "$(sed -n 3p "$T/vault/linked.md")" '^- \[x\] in the vault$' "ticked where the link points"

# The status line's count reads a pre-1.7 notes file where it is, and moves nothing: only opening
# or adding to the checklist does.
mkdir -p "$PROJ/older/.scratch/trails"
printf '# older: notes\n\n- [ ] one\n- [x] two\n' >"$PROJ/older/.scratch/trails/notes.md"
assert_eq "$("$TRAILS" checklist --count "$PROJ/older")" "☑ 1/2 " "the old file counted"
assert_file "$PROJ/older/.scratch/trails/notes.md" "and left where it is"

# A directory that isn't there is refused, not made.
assert_match "$("$TRAILS" checklist "$T/no-such" 2>&1 </dev/null)" "no such directory" "a missing directory, said so"
[ -e "$T/no-such" ] && fail "the checklist made $T/no-such"

# The config's "data": every codebase's checklist in a folder of yours (a synced one, with a
# space in its name and a trailing /, as iCloud Drive's has), at trails/<path>/checklist.md,
# <path> the codebase's root from $HOME with every non-alphanumeric as -. Codebases of their own
# here, not proj, whose checklist the tests below keep in the codebase.
cp "$XDG_CONFIG_HOME/trails/config.json" "$T/config.keep"
jq '.data = "~/Cloud Docs/"' "$T/config.keep" >"$XDG_CONFIG_HOME/trails/config.json"
DATA="$T/Cloud Docs/trails"
mkdir -p "$T/code/my.api"
git -C "$T/code/my.api" init -q
git -C "$T/code/my.api" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
(cd "$T/code/my.api" && "$TRAILS" note "in the cloud") >/dev/null || fail "note with data set failed"
assert_match "$(tail -n 1 "$DATA/code-my-api/checklist.md")" '^- \[ \] in the cloud$' "at data/trails/<path>/checklist.md"
# A worktree's items are its repository's: a branch's notes outlive its worktree.
git -C "$T/code/my.api" worktree add -q "$T/code/my.api@retry" -b retry 2>/dev/null
(cd "$T/code/my.api@retry" && "$TRAILS" note "from the worktree") >/dev/null
assert_match "$(tail -n 1 "$DATA/code-my-api/checklist.md")" '^- \[ \] from the worktree$' "a worktree, in its repository's"
# A checklist left in the codebase moves there the first time it is wanted.
mkdir -p "$T/code/moved/.trails"
printf '# moved: checklist\n\n- [ ] was local\n' >"$T/code/moved/.trails/checklist.md"
(cd "$T/code/moved" && "$TRAILS" note "added") >/dev/null
assert_no_file "$T/code/moved/.trails/checklist.md" "the codebase's own, moved"
assert_eq "$(grep -c '^- \[ \]' "$DATA/code-moved/checklist.md")" 2 "with its items, and the new one"
# A codebase outside $HOME keeps its whole path, from its leading -.
outside=$(mktemp -d /tmp/tt-out.XXXXXX)
outside=$(cd "$outside" && pwd -P)
(cd "$outside" && "$TRAILS" note "outside home") >/dev/null
key=$(printf '%s' "$outside" | sed 's/[^A-Za-z0-9]/-/g')
assert_file "$DATA/$key/checklist.md" "outside \$HOME: the whole path"
rm -rf "$outside"

# The "notes" key from before 1.7: ~ and {codebase}, read as it was.
jq '.notes = "~/notes/{codebase}.md"' "$T/config.keep" >"$XDG_CONFIG_HOME/trails/config.json"
(cd "$PROJ" && "$TRAILS" note "the old key") >/dev/null
assert_match "$(tail -n 1 "$T/notes/proj.md")" '^- \[ \] the old key' "the old key, still read"
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

# ctrl-e there: the checklist opens in a popup of its own, sized for an editor, and once the
# editor quits the list is back. The stand-in editor sets FZF_DUMP for what the server starts
# next, so the list that comes back says so, and the first, already running, doesn't.
# shellcheck disable=SC2016 # the $(...) is the stand-in editor's, run when it opens
printf '#!/bin/sh\nprintf "%%s %%s\\n" "$(stty size </dev/tty | cut -d" " -f1)" "$1" >"%s/opened"\ntmux set-environment -g FZF_DUMP "%s/back"\n' "$T" "$T" >"$T/marked"
chmod +x "$T/marked"
tmux set-environment -g EDITOR "$T/marked"
tmux display-popup -c "$term" -h 5 -E "env FZF_PICK='from the popup' FZF_QUERY= FZF_KEY=ctrl-e '$TRAILS' checklist"
wait_for 5 test -s "$T/opened" || fail "the checklist never opened in a popup"
rows=$(cut -d" " -f1 "$T/opened")
assert_eq "$(cut -d" " -f2- "$T/opened")" "$NOTES" "the checklist"
[ "$rows" -gt 5 ] || fail "the checklist opened $rows rows high, in the list's popup"
wait_for 5 test -e "$T/back" || fail "the list did not come back after the editor"
grep -q 'from the popup' "$T/back" || fail "the list came back without the items: $(cat "$T/back")"
tmux set-environment -gu FZF_DUMP

# trails keys offers the checklist on prefix N, and its count in the status line, before the clock.
assert_match "$("$TRAILS" keys)" "bind N display-popup .*\"'$TRAILS' checklist\"" "the binding"
assert_match "$("$TRAILS" keys)" "^set -g status-right \"#\\('$TRAILS' checklist --count .*\\)%H:%M \"" "the count, then the clock"
