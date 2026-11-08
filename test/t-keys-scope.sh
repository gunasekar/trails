#!/bin/sh
# The tmux.conf line that loads trails' keys is read by every tmux server, trails' own and any
# of yours. Only trails' server takes them; another keeps its own keys and status line.
. "$REPO/test/lib.sh"
t_setup

printf 'run-shell "%s tmux-config | tmux source-file -"\n' "$TRAILS" >"$T/tmux.conf"

# Trails' server (the tests pin it to the default socket) loads them: prefix P is trails'.
tmux -f "$T/tmux.conf" new-session -d -s mine 'sleep 30'
wait_for 5 sh -c "tmux list-keys -T prefix P 2>/dev/null | grep -q trails" ||
  fail "trails' own server did not load the keys: $(tmux list-keys -T prefix P 2>&1)"

# Another server, same tmux.conf: none of them.
tmux -L other -f "$T/tmux.conf" new-session -d -s yours 'sleep 30'
sleep 1
assert_eq "$(tmux -L other list-keys -T prefix P 2>/dev/null | grep -c trails)" 0 "another server has no trails tmux-config"
case $(tmux -L other show-options -gv status-right 2>/dev/null) in
  *trails*) fail "another server got trails' status line" ;;
  *) ;;
esac

# From a shell, outside tmux, it still prints them all.
assert_match "$("$TRAILS" tmux-config)" "bind" "outside tmux, keys prints the bindings"
