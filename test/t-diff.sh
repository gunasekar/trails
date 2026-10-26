#!/bin/sh
# trails diff: a codebase's changes (staged, unstaged and untracked) through the config's
# "diff", in a popup from prefix G, in the terminal from a shell; a "gui" one run instead.
. "$REPO/test/lib.sh"
t_setup

cd "$PROJ" || exit 1
{ git init -q && echo a >a.txt && echo s >s.txt && git add . &&
  git -c user.name=t -c user.email=t@t commit -qm init; } || fail "no repo"
echo a2 >>a.txt
echo s2 >>s.txt && git add s.txt
echo new >n.txt
cfg() { jq -n --argjson d "$1" '{ default_agent: "stub", diff: $d,
  agents: [{ name: "stub", program: "agent" }] }' >"$XDG_CONFIG_HOME/trails/config.json"; }

# ── From a shell: all three changes, through the command ─────────────────────────────────
cfg '"cat"'
out=$("$TRAILS" diff)
for f in a.txt s.txt n.txt; do
  assert_match "$out" "^diff --git a/$f b/$f" "$f in the diff"
done
assert_match "$out" "^\+new$" "the untracked file's content"
git stash -q -u
assert_eq "$("$TRAILS" diff)" "No changes in ~/proj." "a clean codebase, said so"
git stash pop -q
assert_match "$(cd "$T" && "$TRAILS" diff "$T" 2>&1)" "isn't a git repository" "not a repo, said so"

# ── A gui one is run in the codebase, nothing piped ───────────────────────────────────────
cfg "{ \"command\": \"pwd >$T/gui\", \"gui\": true }"
(cd "$T" && "$TRAILS" diff "$PROJ")
assert_eq "$(cat "$T/gui")" "$PROJ" "run in the codebase"

# ── "pipe": false: run in the codebase, finding the changes itself; not started with none ──
cfg "{ \"command\": \"pwd >$T/ran\", \"pipe\": false }"
(cd "$T" && "$TRAILS" diff "$PROJ")
assert_eq "$(cat "$T/ran")" "$PROJ" "run in the codebase"
rm -f "$T/ran"
git stash -q -u
assert_eq "$("$TRAILS" diff)" "No changes in ~/proj." "nothing to show, said so"
[ -e "$T/ran" ] && fail "started with nothing to show"
git stash pop -q

# ── prefix G: a popup on the terminal that pressed it, a stale TMUX_PANE in the job or not ──
# The viewer keeps its environment too: a popup's process has the server's, without the
# key job's TRAILS_CLIENT, so one shown in the job instead (unseen) gives itself away.
cfg "\"cat >$T/seen; env >$T/env\""
"$TRAILS" keys | grep -q '^bind -N "[^"]*" G run-shell "TRAILS_CLIENT=#{client_name} .* diff"$' || fail "no prefix G in trails keys"
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
driver_attached || fail "the terminal never attached"
term=$(tmux list-clients -F '#{client_name} #{session_name}' | awk '$2 == "default" { print $1; exit }')
sock=$(tmux display-message -p '#{socket_path}')
rm -f "$T/seen"
tmux run-shell "env TMUX='$sock,1,0' TMUX_PANE=%999 TRAILS_CLIENT='$term' '$TRAILS' diff"
wait_for 5 test -s "$T/seen" || fail "the popup showed nothing"
assert_match "$(cat "$T/seen")" "^diff --git a/n.txt b/n.txt" "the trail's codebase, in the popup"
! grep -q '^TRAILS_CLIENT=' "$T/env" || fail "shown in the key's job, where nobody sees it, not in a popup"
