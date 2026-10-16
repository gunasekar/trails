#!/bin/sh
# Shared by every test: an isolated environment, a few assertions, and a way to run
# trails on a real terminal. Sourced, never run.
#
# Isolation is by environment, not by patching trails:
#   HOME, XDG_CONFIG_HOME, XDG_STATE_HOME  a throwaway directory, so config and records
#                                          are the test's own
#   TMUX_TMPDIR                            puts the tmux socket there, so plain `tmux`
#                                          inside trails reaches a private server
#   TMUX, TMUX_PANE                        unset, so trails thinks it is outside tmux
#                                          even when the tests run inside one
#   TERM_PROGRAM, NVIM, ZED_TERM, TRAILS_ATTACH
#                                          unset, so trails sees a plain terminal, not
#                                          the editor the tests may be run from
#   PATH                                   test/bin first: the stub agent, the stub fzf
#
# The directory is under /tmp, not the usual scratch locations: a unix socket path has
# to fit in about 100 bytes, and tmux refuses anything longer.

set -u

t_setup() {
  T=$(mktemp -d /tmp/tt.XXXXXX) || exit 1
  T=$(cd "$T" && pwd -P)
  HOME=$T
  XDG_CONFIG_HOME=$T/.config
  XDG_STATE_HOME=$T/.local/state
  TMUX_TMPDIR=$T
  PATH=$REPO/test/bin:$PATH
  export HOME XDG_CONFIG_HOME XDG_STATE_HOME TMUX_TMPDIR PATH
  unset TMUX TMUX_PANE TERM_PROGRAM NVIM ZED_TERM TRAILS_ATTACH TRAILS_CLIENT
  trap 't_teardown' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  TRAILS=$REPO/bin/trails
  STATE=$XDG_STATE_HOME/trails/sessions
  PROJ=$T/proj
  mkdir -p "$XDG_CONFIG_HOME/trails" "$PROJ"
  t_config
}

t_teardown() {
  tmux kill-server 2>/dev/null
  sleep 0.2
  rm -rf "$T"
}

# The agents trails can start here: "agent", the stub in test/bin, under two names so a
# test can tell a second agent from a second session of the first. Both record a session
# ID the way claude does, so launch writes a record and a resume carries the ID.
t_config() {
  cat >"$XDG_CONFIG_HOME/trails/config.json" <<'EOF'
{
  "mode": "default",
  "default_agent": "stub",
  "agents": [
    { "name": "stub", "program": "agent", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid",
                   "name": "--name {name}" } },
    { "name": "other", "program": "agent --other", "yolo": "--yolo",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } }
  ]
}
EOF
}

# Run a command on a terminal of its own: a "driver" session on the test server, whose
# pane is the pseudo-terminal. tmux attach and fzf both need one, and the test server is
# already there. Not script(1): it passes an EOF on its own stdin through the pty as ^D,
# which the agent's `read` takes as end of input, and it won't take a FIFO for stdin.
#
# TMUX is unset for the command, so trails sees itself outside tmux and attaches as a
# nested client, the way the map does. The command's own variables (FZF_PICK, say) are
# passed with -e, since a pane starts from the server's environment, not the caller's; any
# other goes as a NAME=VALUE word in front of the command, which env takes. The command runs
# in $PROJ, or in $DRIVER_DIR when set. Drivers are numbered so one test can run several.
#
# The size is set again with resize-window, which also pins it: tmux 3.4 gives a detached
# session's window the size of the most recently active client rather than -x/-y, and that
# is the nested client in a trail's window, a fraction of a window wide, once that window has an editor
# beside the agent. 3.8 honours -x/-y. resize-window makes the window's size manual.
DRIVERS=0
driver() {
  DRIVERS=$((DRIVERS + 1))
  tmux new-session -d -s "driver-$DRIVERS" -c "${DRIVER_DIR:-$PROJ}" -x 120 -y 40 \
    -e "FZF_PICK=${FZF_PICK:-}" -e "FZF_QUERY=${FZF_QUERY:-}" -e "FZF_KEYS=${FZF_KEYS:-}" \
    -e "FZF_DUMP=${FZF_DUMP:-}" -e "FZF_PICKS=${FZF_PICKS:-}" -e "FZF_KEY=${FZF_KEY:-}" \
    "env -u TMUX -u TMUX_PANE $*" \
    \; resize-window -t "driver-$DRIVERS:" -x 120 -y 40
}

# Run trails attached, in a driver of its own: the session it starts or joins stays
# attached until the test kills it. $1.. are trails' arguments.
trails_bg() { driver "$TRAILS" "$@"; }

# Wait until the latest driver's trails has handed over to `tmux attach`: its pane runs
# tmux. A test that goes on before that races the trails still running in the driver.
driver_attached() {
  wait_for 10 sh -c "tmux display-message -pt 'driver-$DRIVERS' '#{pane_current_command}' 2>/dev/null | grep -qx tmux"
}

# Wait until a command succeeds, up to $1 seconds (default 5), polling every 0.1s.
wait_for() {
  secs=${1:-5}
  shift
  n=$((secs * 10))
  while [ "$n" -gt 0 ]; do
    "$@" >/dev/null 2>&1 && return 0
    sleep 0.1
    n=$((n - 1))
  done
  return 1
}

# Where client $1 is: its session and current window, as `session window-name` (or with a
# second argument, that format instead). From list-clients, whose formats are expanded in
# the client's own context — display-message -c only picks where a message is *shown*, and
# expands against a target pane, so it answers for the wrong client.
client_at() {
  ca_fmt=${2:-}
  [ -n "$ca_fmt" ] || ca_fmt='#{session_name} #{window_name}'
  tmux list-clients -F "#{client_name}$(printf '\t')$ca_fmt" 2>/dev/null |
    awk -F'\t' -v c="$1" '$1 == c { print $2; exit }'
}

has_session() { tmux has-session -t "=$1" 2>/dev/null; }
no_session() { ! tmux has-session -t "=$1" 2>/dev/null; }
screen() { tmux capture-pane -pt "$1" 2>/dev/null; }
screen_has() { screen "$1" | grep -q "$2"; }

# Type a line into a session's pane: the stub agent reads it as a command.
type_in() { tmux send-keys -t "$1" "$2" Enter; }

# Wait until the pane runs a shell again, before typing the next command into it: keys
# sent while the previous command is still exiting reach dash as a broken line.
wait_shell() {
  wait_for 5 sh -c "tmux display-message -pt '$1' '#{pane_current_command}' | grep -qE '^(sh|bash|dash|zsh)$'"
}

fail() {
  echo "fail: $*" >&2
  exit 1
}

assert_eq() {
  [ "$1" = "$2" ] || fail "${3:-assert_eq}: got '$1', want '$2'"
}

assert_match() {
  printf '%s\n' "$1" | grep -Eq "$2" || fail "${3:-assert_match}: '$1' doesn't match /$2/"
}

assert_file() { [ -f "$1" ] || fail "${2:-assert_file}: no file $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "${2:-assert_no_file}: $1 exists"; }
