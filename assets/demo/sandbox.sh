# Sourced by the tapes before recording: a world for trails to run in that shows none of the
# recording machine's own sessions, and runs the real Claude Code.
#
#   trails   its config, records and caches go to a throwaway XDG tree, and tmux to its own
#            server (TMUX_TMPDIR) — the machine's sessions are never seen or touched
#   claude   the real one, with the real HOME, since its login lives there; the conversation it
#            records under ~/.claude/projects is removed by demo_done. trails itself reads a
#            sandboxed claude history (CLAUDE_CONFIG_DIR) holding only the demo's two ended
#            conversations — otherwise `trails ls` would list every project on the machine —
#            and a wrapper drops that setting before running the real claude
#   project  ~/code/checkout, so paths read as they would for anyone; created here and removed
#            by demo_done, and refused if it already exists
#   codex    a stand-in (agent), only ever listed, never started
real_claude=$(command -v claude) || {
  echo "trails demo: needs claude on PATH, logged in" >&2
  return 1
}
demo=$(mktemp -d /tmp/trails-demo.XXXXXX)
here=$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)
project="$HOME/code/checkout"
history="$HOME/.claude/projects/$(printf '%s' "$project" | sed 's/[^A-Za-z0-9]/-/g')"
if [ -e "$project" ] || [ -e "$history" ]; then
  echo "trails demo: $project or its claude history already exists — not touching it" >&2
  return 1
fi
made_code=
[ -d "$HOME/code" ] || made_code=1

# The repo's own trails first, so the demo shows the version you're about to release.
export XDG_CONFIG_HOME="$demo/config" XDG_STATE_HOME="$demo/state" XDG_CACHE_HOME="$demo/cache" \
  TMUX_TMPDIR="$demo/tmux" PATH="$demo/bin:$here/../../bin:$PATH"
unset TMUX XDG_DATA_HOME
# Recorded from inside another claude (or anything else that sets them), these would tell the
# demo's claude it is a child of that one. It should start as the top-level session it shows.
for v in $(env | grep -o -E '^CLAUDE[A-Z_]*='); do unset "${v%=}"; done
export CLAUDE_CONFIG_DIR="$demo/claude"
demo_history="$CLAUDE_CONFIG_DIR/projects/${history##*/}"
mkdir -p "$project/payments" "$TMUX_TMPDIR" "$demo/bin" "$XDG_CONFIG_HOME/trails" "$demo_history"
ln -s "$here/agent" "$demo/bin/codex"
printf '#!/bin/sh\nunset CLAUDE_CONFIG_DIR\nexec "%s" "$@"\n' "$real_claude" >"$demo/bin/claude"
chmod +x "$demo/bin/claude"

# The agents by full path, not by name: a terminal that runs its command through the user's
# login shell (Neovim's :terminal does) can reorder PATH, and the real claude would then run
# without the wrapper — on the sandbox's empty settings, straight into its first-run screens.
cat >"$XDG_CONFIG_HOME/trails/config.json" <<JSON
{
  "mode": "yolo",
  "agents": [
    { "name": "claude", "program": "$demo/bin/claude", "yolo": "--dangerously-skip-permissions",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid", "find": "claude" } },
    { "name": "codex", "program": "$demo/bin/codex", "yolo": "--dangerously-bypass-approvals-and-sandbox" }
  ]
}
JSON

# Two conversations that ended here, in claude's own history format, for "resume old trails".
n=0
for title in "Release notes for v2.3" "Tighten the refund window"; do
  n=$((n + 1))
  id=00000000-0000-4000-8000-00000000000$n
  printf '{"type":"user","entrypoint":"cli","cwd":"%s","sessionId":"%s"}\n{"type":"ai-title","aiTitle":"%s","sessionId":"%s"}\n' \
    "$project" "$id" "$title" "$id" >"$demo_history/$id.jsonl"
  touch -t "$(date -v-"$((n * 2))"d +%Y%m%d%H%M)" "$demo_history/$id.jsonl"
done

# Something for claude to work on, and to have open in the Neovim demo: a package that builds
# and has a test, so the agent can show it working rather than explain why it can't.
cat >"$project/go.mod" <<'GO'
module example.com/checkout

go 1.22
GO
cat >"$project/payments/retry.go" <<'GO'
package payments

import "time"

// Payment is one charge to send to the processor.
type Payment struct {
	ID     string
	Amount int64
}

// Client sends payments to the processor.
type Client interface {
	Send(p Payment) error
}

// Retry sends a payment again after a transient failure.
func Retry(c Client, p Payment, attempts int) error {
	var err error
	for i := 0; i < attempts; i++ {
		if err = c.Send(p); err == nil {
			return nil
		}
		time.Sleep(time.Duration(i) * time.Millisecond)
	}
	return err
}
GO
cat >"$project/payments/retry_test.go" <<'GO'
package payments

import (
	"errors"
	"testing"
)

type flaky struct{ fails int; sent []Payment }

func (f *flaky) Send(p Payment) error {
	f.sent = append(f.sent, p)
	if len(f.sent) <= f.fails {
		return errors.New("timeout")
	}
	return nil
}

func TestRetrySucceedsAfterFailures(t *testing.T) {
	f := &flaky{fails: 2}
	if err := Retry(f, Payment{ID: "p1", Amount: 500}, 3); err != nil {
		t.Fatal(err)
	}
	if len(f.sent) != 3 {
		t.Fatalf("sent %d times, want 3", len(f.sent))
	}
}
GO
(cd "$project" && git init -q && git add . && git -c user.name=demo -c user.email=demo@example.com commit -qm init)

# Neovim with no personal config (--clean), on the terminal's own black rather than its
# default scheme's grey, so the panel reads like the editors trails usually sits in. Its
# :terminal runs through /bin/sh, not the login shell, whose startup files would put the
# machine's own trails and claude back in front of the sandbox's on PATH.
nvim() {
  command nvim --clean -c 'set shell=/bin/sh' \
    -c 'hi Normal guibg=NONE ctermbg=NONE' -c 'hi NormalNC guibg=NONE ctermbg=NONE' \
    -c 'hi EndOfBuffer guibg=NONE ctermbg=NONE' -c 'hi SignColumn guibg=NONE ctermbg=NONE' "$@"
}

# The tape's last, hidden step: the tmux server, the project, its claude history, the sandbox.
demo_done() {
  tmux kill-server 2>/dev/null
  cd "$HOME" || return
  rm -rf "$project" "$history" "$demo"
  [ -n "$made_code" ] && rmdir "$HOME/code" 2>/dev/null
  return 0
}

cd "$project" || return
# shellcheck disable=SC2088 # a literal ~: the prompt shows it, nothing expands it
export PS1='~/code/checkout $ '
