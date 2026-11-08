#!/bin/sh
# tmux-config supplies neutral theme slots only on the configured server.
. "$REPO/test/lib.sh"
t_setup

cat >"$T/tmux.conf" <<CONF
set -g window-status-format '#{E:@window_label_prefix}#[fg=white]#{E:@window_label_style}#I:#W#{E:@window_label_suffix}'
run-shell "$TRAILS tmux-config | tmux source-file -"
CONF
tmux -f "$T/tmux.conf" new-session -d -s mine 'sleep 30'
wait_for 5 sh -c "tmux show -gv @window_label_prefix 2>/dev/null | grep -q trails_star" ||
  fail "tmux-config did not install theme slots"
assert_eq "$(tmux show -gv @window_label_style)" '#{E:@trails_bell_style}' "bell colour slot"
assert_eq "$(tmux show -gv @window_label_suffix)" '#{E:@trails_bell}' "bell glyph slot"
tmux set -w @trails_starred 1
assert_match "$(tmux display -p '#{E:window-status-format}')" '★' "star expands in theme"
tmux source-file "$T/tmux.conf"
assert_eq "$(tmux show -gv @window_label_prefix)" '#{E:@trails_star}' "reload is idempotent"
tmux -L other -f "$T/tmux.conf" new-session -d -s yours 'sleep 30'
sleep 1
assert_eq "$(tmux -L other show -gqv @window_label_prefix)" '' "foreign server has no slots"
assert_eq "$(tmux -L other list-keys -T prefix P 2>/dev/null | grep -c trails)" 0 "foreign server has no keys"
