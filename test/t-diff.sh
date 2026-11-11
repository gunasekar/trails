#!/bin/sh
# Live Hunk is used from the terminal and validates the directory.
. "$REPO/test/lib.sh"
t_setup
(cd "$PROJ" && git init -q) || fail "no repository"
out=$(printf 'q\n' | "$TRAILS" diff "$PROJ") || fail "hunk failed"
assert_match "$out" "hunk diff --watch in $PROJ context=99999" "live Hunk with whole files"
assert_match "$("$TRAILS" diff "$T" 2>&1)" "isn't a git repository" "not a repository"
if tmux list-commands | grep -q '^new-pane '; then
  "$TRAILS" tmux-config | grep -q '^bind -N "trails: a floating pane" ` new-pane$' || fail "backtick is not a floating pane"
fi
