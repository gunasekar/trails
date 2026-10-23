#!/bin/sh
# States from the agent's hooks (ADR 18): `trails state` marks the agent's pane, and that word
# answers, against the agent's own file the newer of the two; else unknown.
. "$REPO/test/lib.sh"
t_setup

# The stub with its hooks off: nothing but a hook typed in can say what it is doing.
cfg() {
  cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub",
  "agents": [ { "name": "stub", "program": "agent --no-hooks",
    "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid"$1 } } ] }
CFG
}
cfg ''

state() { (cd "$PROJ" && "$TRAILS" ls | awk -F'\t' -v t="${TRAIL:-default/payments}" '$3 == t { print $2 }'); }
state_is() { [ "$(state)" = "$1" ]; }

# ── trails state: silent, and 0, whatever it is given ───────────────────────────────────
for args in "state working" "state bogus" "state"; do
  # shellcheck disable=SC2086 # the words are the arguments
  out=$(env -u TMUX -u TMUX_PANE "$TRAILS" $args 2>&1)
  rc=$?
  assert_eq "$out$rc" 0 "outside tmux, '$args': nothing said, 0"
done
out=$(TMUX=/nonexistent/sock,1,0 TMUX_PANE=%1 "$TRAILS" state idle 2>&1)
rc=$?
assert_eq "$out$rc" 0 "no server there: nothing said, 0"

# ── No hooks, no file: unknown ──────────────────────────────────────────────────────────
trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "agent never started"
wait_for 5 state_is unknown || fail "an agent nothing speaks for should be unknown, got $(state)"
assert_match "$(cd "$PROJ" && "$TRAILS" ls -a | cat)" "unknown" "the TSV says unknown"

# ── The hook's word, each of the three ──────────────────────────────────────────────────
type_in default/payments "hook working"
wait_for 5 state_is working || fail "hook working: got $(state)"
type_in default/payments "hook waiting"
wait_for 5 state_is needs-you || fail "hook waiting: got $(state)"
type_in default/payments "hook idle"
wait_for 5 state_is your-turn || fail "hook idle: got $(state)"
pane=$(tmux list-panes -t default/payments -F '#{pane_id}')
assert_match "$(tmux show-options -pv -t "$pane" @trails_state_at)" "^[0-9]+$" "when it was said, kept"

# ── Hook and the agent's own file: the newer wins ───────────────────────────────────────
# The stub read as claude: a state file under $HOME/.claude/sessions named for the pane's
# process, as claude keeps one.
cfg ', "find": "claude"'
pid=$(tmux display-message -pt default/payments '#{pane_pid}')
id=$(cd "$PROJ" && "$TRAILS" ls | awk -F'\t' '$3 == "default/payments" { print $7 }')
mkdir -p "$HOME/.claude/sessions"
claude_file() { # status, when (seconds)
  printf '{"pid":%s,"sessionId":"%s","status":"%s","statusUpdatedAt":%s000}\n' "$pid" "$id" "$1" "$2" \
    >"$HOME/.claude/sessions/$pid.json"
}
now=$(date +%s)
tmux set-option -p -t "$pane" @trails_state working \; set-option -p -t "$pane" @trails_state_at "$now"
claude_file idle $((now - 60))
assert_eq "$(state)" working "the hook is newer than the file"
claude_file idle $((now + 60))
assert_eq "$(state)" your-turn "the file is newer than the hook (an interrupted turn)"
tmux set-option -pu -t "$pane" @trails_state
claude_file waiting "$now"
assert_eq "$(state)" needs-you "no hook: the file answers"

# ── trails hooks ───────────────────────────────────────────────────────────────────────
# The Claude Code plugin ships the hooks `trails hooks claude` prints, and never drifts from them.
assert_eq "$(jq -S . "$REPO/plugins/trails/hooks/hooks.json")" "$("$TRAILS" hooks claude 2>/dev/null | jq -S .)" \
  "the plugin's hooks are trails hooks claude's"

# It prints them, and says where they go; there is nothing to install.
assert_match "$("$TRAILS" hooks copilot 2>/dev/null | jq -r '.hooks.agentStop[0].bash')" "^trails state idle" "copilot's, to paste"
assert_match "$("$TRAILS" hooks copilot 2>&1 >/dev/null)" "copilot/hooks/trails.json" "and where they go"
assert_match "$("$TRAILS" hooks claude --install 2>&1)" "prints its hooks to paste" "no --install"
assert_match "$("$TRAILS" hooks)" "^stub +no hooks" "an agent trails has no hooks for, said so"

# The Claude Code plugin installed counts as hooked, and pasting the hooks too is warned off.
mkdir -p "$HOME/.claude/plugins"
printf '{"version":2,"plugins":{"trails@trails":[{"scope":"user"}]}}\n' >"$HOME/.claude/plugins/installed_plugins.json"
assert_match "$("$TRAILS" hooks claude 2>&1 >/dev/null)" "would run each twice" "the plugin has them already"
rm "$HOME/.claude/plugins/installed_plugins.json"

# ── An agent with no session block: its hooks still speak ───────────────────────────────
# Its pane carries no @trails_id, an empty field between the ones that say its state.
tmux new-session -d -s hold # the server outlives the trail's session
tmux kill-session -t '=default/payments'
cat >"$XDG_CONFIG_HOME/trails/config.json" <<CFG
{ "default_agent": "stub", "agents": [ { "name": "stub", "program": "agent --no-hooks" } ] }
CFG
trails_bg new plain
wait_for 5 screen_has default/plain 'agent' || fail "the session-less agent never started"
type_in default/plain "hook waiting"
TRAIL=default/plain
wait_for 5 state_is needs-you || fail "no session block, hook waiting: got $(state)"
