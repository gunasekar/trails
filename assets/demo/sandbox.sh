# Sourced by demo.tape before recording: a throwaway world for trails, so the demo shows none of
# the recording machine's sessions, history or config. Its own HOME (records, config, agent
# history) and its own tmux server (TMUX_TMPDIR), stand-in agents first on PATH, and a project.
demo=$(mktemp -d /tmp/trails-demo.XXXXXX)
here=$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)
# The repo's own trails first, so the demo shows the version you're about to release.
export HOME="$demo/home" TMUX_TMPDIR="$demo/tmux" PATH="$demo/bin:$here/../../bin:$PATH"
unset TMUX XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME CLAUDE_CONFIG_DIR
mkdir -p "$HOME/code/checkout" "$TMUX_TMPDIR" "$demo/bin" "$HOME/.config/trails"
for a in claude codex; do ln -s "$here/agent" "$demo/bin/$a"; done

# Only the two stand-ins, so whatever real agents this machine has stay off screen.
cat >"$HOME/.config/trails/config.json" <<'JSON'
{
  "mode": "default",
  "agents": [
    { "name": "claude", "program": "claude", "yolo": "--dangerously-skip-permissions",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } },
    { "name": "codex", "program": "codex", "yolo": "--dangerously-bypass-approvals-and-sandbox" }
  ]
}
JSON

# Two conversations that ended here, in claude's own history format, for "resume old trails".
proj="$HOME/.claude/projects/$(printf '%s' "$HOME/code/checkout" | sed 's/[^A-Za-z0-9]/-/g')"
mkdir -p "$proj"
n=0
for title in "Release notes for v2.3" "Tighten the refund window"; do
  n=$((n + 1))
  id=00000000-0000-4000-8000-00000000000$n
  printf '{"type":"user","entrypoint":"cli","cwd":"%s","sessionId":"%s"}\n{"type":"ai-title","aiTitle":"%s","sessionId":"%s"}\n' \
    "$HOME/code/checkout" "$id" "$title" "$id" >"$proj/$id.jsonl"
  touch -t "$(date -v-"$((n * 2))"d +%Y%m%d%H%M)" "$proj/$id.jsonl"
done

# Something to have open in an editor, for the Neovim demo.
mkdir -p "$HOME/code/checkout/payments"
cat >"$HOME/code/checkout/payments/retry.go" <<'GO'
package payments

// Retry sends a payment again after a transient failure.
func Retry(c *Client, p Payment, attempts int) error {
	var err error
	for i := 0; i < attempts; i++ {
		if err = c.Send(p); err == nil {
			return nil
		}
		backoff(i)
	}
	return err
}
GO

cd "$HOME/code/checkout" || return
# shellcheck disable=SC2088 # a literal ~: the prompt shows it, nothing expands it
export PS1='~/code/checkout $ '

# Neovim with no personal config (--clean), on the terminal's own black rather than its
# default scheme's grey, so the panel reads like the editors trails usually sits in.
nvim() {
  command nvim --clean \
    -c 'hi Normal guibg=NONE ctermbg=NONE' -c 'hi NormalNC guibg=NONE ctermbg=NONE' \
    -c 'hi EndOfBuffer guibg=NONE ctermbg=NONE' -c 'hi SignColumn guibg=NONE ctermbg=NONE' "$@"
}

# The tape's last, hidden step: take the sandbox's tmux server and files with it.
demo_done() {
  tmux kill-server 2>/dev/null
  rm -rf "$demo"
}
