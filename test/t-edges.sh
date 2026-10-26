#!/bin/sh
# What a bug hunt turned up, each pinned: keys that name no trail, broken and odd configs, odd
# folder names, two trails or two restores at once, a deleted directory, missing tools. Each
# check is a bug that was fixed; see docs/test-plan.md.
. "$REPO/test/lib.sh"
t_setup

CFG=$XDG_CONFIG_HOME/trails/config.json
stub_cfg() {
  cat >"$CFG" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } } ] }
CFG
}
stub_cfg

# ── The preview: only a trail's ─────────────────────────────────────────────────────────
DRIVER_DIR=$PROJ driver "$TRAILS" new one
wait_for 5 screen_has default/one 'agent id=' || fail "one never started"
# The preview shows a running trail or nothing: never "-" read as the last window, nor a
# name that is gone read as another's prefix.
assert_eq "$("$TRAILS" --peek -)" "" "no preview for a row that is no trail"
assert_eq "$("$TRAILS" --peek default/on)" "" "no preview for a trail that is gone"

# With the system's PATH alone (a tab another app opened, launchd), trails still finds tmux,
# and so its trails: Resume read a running trail as gone.
assert_match "$(PATH=/usr/bin:/bin "$TRAILS" ls -a 2>&1 | grep default/one)" "^running" "a bare PATH still sees the trail running"

# ── Names ──────────────────────────────────────────────────────────────────────────────
# stderr alone: the refusal, not what a start would print.
# shellcheck disable=SC2069
nm() { (cd "$PROJ" && "$TRAILS" new "$@" 2>&1 >/dev/null); }
"$TRAILS" new -x >/dev/null 2>&1 && fail "new -x was taken as a name"
printf '%s\n' '' ctrl-n >"$T/kx"
printf '%s\n' '^agents' 'stub · new trail' >"$T/px"
assert_match "$(cd "$PROJ" && FZF_KEYS=$T/kx FZF_QUERY=-x FZF_PICKS=$T/px "$TRAILS" 2>&1 </dev/null)" "can't start with -" "ctrl-n with a name starting with -"
assert_match "$(nm proj-5)" "reads as an unnamed trail" "a name like an unnamed trail's"
assert_match "$(nm proj-3f9a)" "reads as an unnamed trail" "a name like an unnamed trail's session"
assert_match "$(nm beef)" "reads as the #ID of an unnamed trail" "a name like an unnamed trail's badge"

# ── Two at once ────────────────────────────────────────────────────────────────────────
# One name started twice at once: one runs, one is refused, and the record is the runner's.
(cd "$PROJ" && "$TRAILS" new twin >/dev/null 2>&1 &)
(cd "$PROJ" && "$TRAILS" new twin >/dev/null 2>&1 &)
wait_for 10 screen_has default/twin 'agent id=' || fail "twin never started"
sleep 2
assert_eq "$(tmux list-sessions -F '#S' | grep -c '^default/twin')" 1 "one twin, not two"
assert_eq "$(sed -n 's/^id=//p' "$(trec default/twin)")" "$(tmux show-options -wqv -t '=default/twin:' @trails_id)" "its record is the running one's"
# Two restores at once bring a trail back once, on its own conversation.
DRIVER_DIR=$PROJ driver "$TRAILS" new pay
wait_for 5 screen_has default/pay 'agent id=' || fail "pay never started"
pay_id=$(sed -n 's/^id=//p' "$(trec default/pay)")
tmux kill-server
wait_for 5 sh -c '! tmux ls >/dev/null 2>&1' || fail "the server stayed up"
(cd "$T" && "$TRAILS" restore >/dev/null 2>&1 &)
(cd "$T" && "$TRAILS" restore >/dev/null 2>&1 &)
wait_for 10 has_session default/pay || fail "pay never came back"
sleep 3
assert_eq "$(tmux list-sessions -F '#S' | grep -cE "^default/(pay|proj)$")" 1 "pay back once, no fresh duplicate"
assert_eq "$(sed -n 's/^id=//p' "$(trec default/pay)")" "$pay_id" "on its own conversation"

# ── A folder name with a | ─────────────────────────────────────────────────────────────
mkdir -p "$T/a|b"
DRIVER_DIR="$T/a|b" driver "$TRAILS" new piped
wait_for 5 screen_has default/piped 'agent id=' || fail "piped never started"
assert_match "$("$TRAILS" ls -a | grep 'default/piped')" "	$T/a\\|b	" "listed with its directory whole"

# ── A deleted directory ────────────────────────────────────────────────────────────────
mkdir -p "$T/gone"
assert_match "$(cd "$T/gone" && rmdir "$T/gone" && "$TRAILS" new ghost 2>&1)" "this directory is gone" "refused"
no_session default/ghost || fail "a trail was made in a deleted directory"

# ── Config ─────────────────────────────────────────────────────────────────────────────
cp "$CFG" "$T/cfg.keep"
printf '{ "agents": [ ' >"$CFG"
assert_match "$("$TRAILS" ws list 2>&1)" "is not valid JSON" "broken JSON named"
(cd "$PROJ" && "$TRAILS" note x >/dev/null 2>&1) && fail "a note was written past a broken config"
"$TRAILS" ls >/dev/null 2>&1 || fail "ls stopped on a broken config"
: >"$CFG"
assert_match "$("$TRAILS" ws list 2>&1)" "is empty" "an empty config named"
printf '[1]\n' >"$CFG"
assert_match "$("$TRAILS" ws list 2>&1)" "is not a JSON object" "a config that isn't an object named"
# Agents: an entry that isn't an object, and a second by one name, are skipped and said so.
printf '{ "agents": [ "claude", { "name": "a", "program": "sh" }, { "name": "a", "program": "cat" } ] }\n' >"$CFG"
out=$("$TRAILS" ls 2>&1 >/dev/null)
assert_match "$out" "skipping agent 'claude'" "a string for an agent skipped"
assert_match "$out" "skipping a second agent named 'a'" "a duplicate skipped"
printf '{ "agents": [] }\n' >"$CFG"
assert_match "$(cd "$PROJ" && "$TRAILS" new z 2>&1)" "no agent to start" "no agents, said so"
cp "$T/cfg.keep" "$CFG"

# ── Workspaces ─────────────────────────────────────────────────────────────────────────
# ws add writes through a link into dotfiles, and keeps its mode.
mkdir -p "$T/dots" "$T/w1" "$T/a[1]" "$T/a1" "$T/sp ace"
mv "$CFG" "$T/dots/config.json" && chmod 600 "$T/dots/config.json" && ln -s "$T/dots/config.json" "$CFG"
"$TRAILS" ws add w "$T/w1" >/dev/null 2>&1 || fail "ws add failed"
[ -L "$CFG" ] || fail "ws add replaced the linked config with a file"
# GNU stat's -f is the filesystem, not a format: ask which stat this is, as trails does.
if stat -c %a / >/dev/null 2>&1; then mode=$(stat -c %a "$T/dots/config.json"); else mode=$(stat -f %Lp "$T/dots/config.json"); fi
assert_eq "$mode" 600 "and kept its mode"
# A folder named with glob characters claims itself, not others.
"$TRAILS" ws add g "$T/a[1]" >/dev/null 2>&1
assert_eq "$("$TRAILS" ws of "$T/a[1]" 2>/dev/null)" g "a[1] is g's"
assert_eq "$("$TRAILS" ws of "$T/a1" 2>/dev/null)" "" "a1 isn't"
# A workspace given as one string keeps it when another is added.
jq '.workspaces.s = "~/w1"' "$T/dots/config.json" >"$T/c.tmp" && cat "$T/c.tmp" >"$T/dots/config.json"
"$TRAILS" ws add s "$T/sp ace" >/dev/null 2>&1
assert_eq "$(jq -c '.workspaces.s.codebases' "$T/dots/config.json")" '["~/w1","~/sp ace"]' "the string kept"
"$TRAILS" ws add list "$T/w1" >/dev/null 2>&1 && fail "'list' accepted as a workspace name"
"$TRAILS" ws add r / >/dev/null 2>&1 && fail "/ accepted as a codebase"
# A path with a space is in the tree, and a workspace with none counts none.
jq '.workspaces.e = []' "$T/dots/config.json" >"$T/c.tmp" && cat "$T/c.tmp" >"$T/dots/config.json"
rm -f "$T/d1"
printf '%s\n' 'new trail…' '' >"$T/p1"
(cd "$T" && FZF_PICKS=$T/p1 FZF_DUMP=$T/d1 TRAILS_PICKER=workspace TRAILS_WS=s "$TRAILS" >/dev/null 2>&1)
assert_match "$(cat "$T/d1")" "$T/sp ace	" "the codebase with a space, in the tree"
rm -f "$T/d2"
(cd "$T" && FZF_PICK='' FZF_DUMP=$T/d2 TRAILS_PICKER=workspace TRAILS_WS=e "$TRAILS" >/dev/null 2>&1)
assert_match "$(cat "$T/d2")" "\\(0 codebases\\)" "an empty workspace counts none"

# ── Checklist ──────────────────────────────────────────────────────────────────────────
mkdir -p "$T/R&D"
jq '.notes = "~/n/{codebase}.md"' "$T/dots/config.json" >"$T/c.tmp" && cat "$T/c.tmp" >"$T/dots/config.json"
(cd "$T/R&D" && "$TRAILS" note amp >/dev/null 2>&1)
[ -f "$T/n/R&D.md" ] || fail "{codebase} lost the & in R&D: $(ls "$T/n" 2>&1)"
jq '.notes = "/nonexistent-root/x.md"' "$T/dots/config.json" >"$T/c.tmp" && cat "$T/c.tmp" >"$T/dots/config.json"
# Not as root, who can write anywhere (a container's test run).
[ "$(id -u)" -eq 0 ] ||
  assert_match "$(cd "$PROJ" && "$TRAILS" note x 2>&1)" "can't write the checklist at" "an unwritable checklist path, said so"
jq 'del(.notes)' "$T/dots/config.json" >"$T/c.tmp" && cat "$T/c.tmp" >"$T/dots/config.json"
"$TRAILS" checklist --edit "$T/nope" >/dev/null 2>&1 && fail "the checklist made a directory that wasn't there"
[ -e "$T/nope" ] && fail "the checklist created $T/nope"

# ── The map's argument ─────────────────────────────────────────────────────────────────
for a in abc 0 -1 99999999999999999999; do
  assert_match "$("$TRAILS" map "$a" 2>&1)" "map takes a number" "map $a refused as such"
done

# ── trails edit that starts the server leaves no editor's markers in it, and no other
# server's pane: a TMUX_PANE left by an `unset TMUX` would be every binding's pane ──
tmux kill-server 2>/dev/null
wait_for 5 sh -c '! tmux ls >/dev/null 2>&1' || fail "the server stayed up"
(cd "$PROJ" && unset TMUX && TMUX_PANE=%99 NVIM=/tmp/nvimsock ZED_TERM=1 EDITOR=ed "$TRAILS" edit >/dev/null 2>&1 &)
wait_for 5 sh -c 'tmux ls >/dev/null 2>&1' || fail "edit started no server"
assert_eq "$(tmux show-environment -g 2>/dev/null | grep -cE '^(NVIM|ZED_TERM|TMUX_PANE)=')" 0 "no NVIM, ZED_TERM or TMUX_PANE in the server"
assert_match "$(cd "$PROJ" && EDITOR=nosuch-editor "$TRAILS" edit 2>&1)" "nosuch-editor, which isn't installed" "a missing editor, said so"

# ── Without fzf ────────────────────────────────────────────────────────────────────────
mkdir -p "$T/nofzf"
for b in sh tmux jq awk sed grep cat tr cut head tail ls mkdir mktemp rm date dirname basename git stty sort wc env od dd printf ps id readlink find; do
  p=$(command -v "$b") && ln -sf "$p" "$T/nofzf/$b"
done
out=$(cd "$PROJ" && PATH=$T/nofzf "$TRAILS" 2>&1 </dev/null)
rc=$?
assert_match "$out" "needs fzf" "fzf missing, said so"
[ "$rc" -ne 0 ] || fail "and exits with an error"

# ── The keys, alone (? in the picker) and within trails help, once ──────────────────────
keys=$("$TRAILS" help keys)
assert_match "$keys" "^In the picker" "the picker's keys"
assert_match "$keys" "^  \? +these keys; q comes back" "? among them"
assert_match "$keys" "^In tmux, from trails keys" "and the tmux ones"
assert_eq "$("$TRAILS" help | grep -c '^In tmux, from trails keys')" 1 "trails help has them, once"
assert_match "$("$TRAILS" keys)" '^bind -N "[^"]*" H run-shell "TRAILS_CLIENT=#{client_name} .* --keys"$' "prefix H shows them"
# Every key trails binds is a capital letter, but ` for the shell (ADR 24): tmux's own lower-case
# keys and symbols stay tmux's.
assert_eq "$("$TRAILS" keys | sed -n 's/^bind -N "[^"]*" \([^ ]*\) .*/\1/p' | grep -v '^[A-Z]$' | tr '\n' ' ')" '` ' "capitals only, and the backtick"
# Every one with a note, so tmux's own list of keys (prefix ?, list-keys -N) shows it.
assert_eq "$("$TRAILS" keys | grep '^bind ' | grep -cv '^bind -N "trails: [^"]*" ')" 0 "every binding noted"
assert_eq "$("$TRAILS" keys | grep -c '^bind -N "trails: ')" 12 "all twelve"
