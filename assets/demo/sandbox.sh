# Sourced by the tapes before recording: a world for trails to run in that shows none of the
# recording machine's own sessions, and runs the real Claude Code.
#
#   trails   its config, records and caches go to a throwaway XDG tree, and tmux to its own
#            server (TMUX_TMPDIR) — the machine's sessions are never seen or touched
#   claude   the real one, with the real HOME, since its login lives there, and the repo's
#            plugin hooks (--settings), so its trails say what they are doing; the
#            conversation it records under ~/.claude/projects is removed by demo_done. The two
#            ended trails "resume old trails" lists are seeded into trails' own history
#   projects ~/code/checkout, plus any in DEMO_EXTRA (storefront, notify, api), the acme
#            workspace's, and any in DEMO_PERSONAL (blog) under ~/src, the personal workspace's,
#            so paths read as they would for anyone; created here and removed by demo_done,
#            and refused if any of them, or its claude history, already exists
#   codex    a stand-in (agent), only ever listed, never started
#   tmux     the real one, through a wrapper that gives the demo server its own config: the
#            `trails keys` bindings for the repo's trails and a plain status line, so the
#            recording machine's tmux.conf (its prefix, its bindings) is not in the shot
real_claude=$(command -v claude) || {
  echo "trails demo: needs claude on PATH, logged in" >&2
  return 1
}
here=$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)
project="$HOME/code/checkout"
# claude's history folder for a project path: the path with every non-alphanumeric as -.
history_of() { printf '%s/.claude/projects/%s' "$HOME" "$(printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g')"; }
history=$(history_of "$project")
demo_projects="checkout ${DEMO_EXTRA:-}"
demo_dirs=$(for p in $demo_projects; do printf 'code/%s\n' "$p"; done
  for p in ${DEMO_PERSONAL:-}; do printf 'src/%s\n' "$p"; done)
for p in $demo_dirs; do
  if [ -e "$HOME/$p" ] || [ -e "$(history_of "$HOME/$p")" ]; then
    echo "trails demo: ~/$p or its claude history already exists — not touching it" >&2
    return 1
  fi
done
made_code= made_src=
[ -d "$HOME/code" ] || made_code=1
[ -d "$HOME/src" ] || made_src=1
demo=$(mktemp -d /tmp/trails-demo.XXXXXX)

# The repo's own trails first, so the demo shows the version you're about to release.
export XDG_CONFIG_HOME="$demo/config" XDG_STATE_HOME="$demo/state" XDG_CACHE_HOME="$demo/cache" \
  TMUX_TMPDIR="$demo/tmux" PATH="$demo/bin:$here/../../bin:$PATH"
unset TMUX TMUX_PANE XDG_DATA_HOME
# Recorded from inside another claude (or anything else that sets them), these would tell the
# demo's claude it is a child of that one. It should start as the top-level session it shows.
for v in $(env | grep -o -E '^CLAUDE[A-Z_]*='); do unset "${v%=}"; done
demo_history="$XDG_STATE_HOME/trails/history"
mkdir -p "$project/payments" "$TMUX_TMPDIR" "$demo/bin" "$XDG_CONFIG_HOME/trails" "$demo_history"
ln -s "$here/agent" "$demo/bin/codex"
printf '#!/bin/sh\nexec "%s" --settings "%s" "$@"\n' "$real_claude" "$here/../../plugins/trails/hooks/hooks.json" >"$demo/bin/claude"
chmod +x "$demo/bin/claude"
real_tmux=$(command -v tmux)
printf '#!/bin/sh\nexec "%s" -f "%s" "$@"\n' "$real_tmux" "$demo/tmux.conf" >"$demo/bin/tmux"
chmod +x "$demo/bin/tmux"
# default-shell /bin/sh: tmux runs popups and run-shell commands through it, and the login
# shell's startup files (a .zshenv setting XDG_CONFIG_HOME) would put the machine's own trails
# config back in front of the sandbox's. Panes keep the login shell as their command.
{
  echo 'set -g default-shell /bin/sh'
  echo "set -g default-command '$SHELL'"
  echo 'set -g focus-events on'  # or Claude Code's welcome screen asks for it
  echo 'set -g status-style "bg=default"'
  echo 'set -g status-left " #S "'
  echo 'set -g status-left-length 30'
  # The terminal title an agent's view emits, "claude · what it is working on", which the
  # map's pane borders read: tmux seeds pane_title with the hostname, so a title-less agent
  # falls back to its directory, and Claude Code's leading spinner glyph is dropped.
  echo 'set -g set-titles on'
  echo 'set -g set-titles-string "#{?@agent,#{@agent} · #{?#{==:#{pane_title},#{host}},#{b:pane_current_path},#{s|^[^ ]+ ||:pane_title}},#S:#W}"'
  # The keys, each also naming itself at the right of the status line for a few seconds, so
  # the recording shows what was pressed: `bind E CMD` becomes `bind E { set the badge ; CMD }`.
  "$here/../../bin/trails" keys | awk '
    BEGIN {
      what["P"] = "trails"; what["W"] = "workspaces"; what["E"] = "editor"; what["`"] = "shell"
      what["N"] = "note"; what["K"] = "previous workspace"; what["J"] = "next workspace"; what["M"] = "map"
      what["G"] = "diff"; what["A"] = "all trails"; what["H"] = "keys"; what["R"] = "rename"
    }
    $1 == "bind" && ($2 in what) {
      k = $2; cmd = $0; sub(/^bind [^ ]+ /, "", cmd)
      printf "bind %s { set -g @demo_key \"prefix %s · %s\" ; run-shell -b \"sleep 2.5; tmux set -g @demo_key \x27\x27\" ; %s }\n", (k == "`" ? "\\`" : k), k, what[k], cmd
      next
    }
    { print }'
  echo 'set -g status-right-length 40'
  echo 'set -g status-right "#{?@demo_key,#[fg=black#,bg=yellow#,bold] #{@demo_key} #[default] ,}"'
} >"$demo/tmux.conf"
# The demos' editor: Neovim with no personal config, as the nvim() below runs it.
export EDITOR="nvim --clean"

# The agents by full path, not by name: a terminal that runs its command through the user's
# login shell (Neovim's :terminal does) can reorder PATH, and the real claude would then run
# without the wrapper — on the sandbox's empty settings, straight into its first-run screens.
cat >"$XDG_CONFIG_HOME/trails/config.json" <<JSON
{
  "mode": "yolo",
  "agents": [
    { "name": "claude", "program": "$demo/bin/claude", "yolo": "--dangerously-skip-permissions",
      "session": { "start": "--session-id {id}", "resume": "--resume {id}", "id": "uuid" } },
    { "name": "codex", "program": "$demo/bin/codex", "yolo": "--dangerously-bypass-approvals-and-sandbox" }
  ],
  "workspaces": {
    "acme":     { "root": "~/code", "codebases": ["~/code/*"] },
    "personal": { "root": "~/src", "codebases": ["~/src/*"] }
  }
}
JSON

# Two trails that ended here, in trails' own history, for "resume old trails".
n=0
for title in "Release notes for v2.3" "Tighten the refund window"; do
  n=$((n + 1))
  id=00000000-0000-4000-8000-00000000000$n
  printf 'agent=claude\ndir=%s\nid=%s\nyolo=%s\ntask=%s\nworkspace=acme\nlabel=checkout\nname=\nserver=default\nended=%s\n' \
    "$project" "$id" "$([ "$n" = 1 ] && echo yolo)" "$title" "$(($(date +%s) - n * 2 * 86400))" >"$demo_history/$id"
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

# The acme workspace's other projects, each a small Go module with a test, so each agent has
# something real to change and check.
for p in ${DEMO_EXTRA:-}; do
  d="$HOME/code/$p"
  case $p in
    storefront)
      mkdir -p "$d/catalog"
      cat >"$d/catalog/images.go" <<'GO'
package catalog

import (
	"fmt"
	"strings"
)

// Product is one item on a listing page.
type Product struct{ Name, ImageURL string }

// ImageTags renders an <img> tag for each product.
func ImageTags(ps []Product) string {
	var b strings.Builder
	for _, p := range ps {
		fmt.Fprintf(&b, "<img src=%q alt=%q>\n", p.ImageURL, p.Name)
	}
	return b.String()
}
GO
      cat >"$d/catalog/images_test.go" <<'GO'
package catalog

import (
	"strings"
	"testing"
)

func TestImageTags(t *testing.T) {
	got := ImageTags([]Product{{Name: "Mug", ImageURL: "/mug.jpg"}})
	if !strings.Contains(got, `src="/mug.jpg"`) {
		t.Fatalf("got %q", got)
	}
}
GO
      ;;
    notify)
      mkdir -p "$d/mail"
      cat >"$d/mail/send.go" <<'GO'
package mail

// Message is one email to send.
type Message struct{ To, Subject string }

// Sender delivers a batch of messages in one request.
type Sender interface{ Send(batch []Message) error }

// SendAll sends every message, one request each.
func SendAll(s Sender, msgs []Message) error {
	for _, m := range msgs {
		if err := s.Send([]Message{m}); err != nil {
			return err
		}
	}
	return nil
}
GO
      cat >"$d/mail/send_test.go" <<'GO'
package mail

import "testing"

type counter struct{ got int }

func (c *counter) Send(batch []Message) error { c.got += len(batch); return nil }

func TestSendAll(t *testing.T) {
	c := &counter{}
	if err := SendAll(c, make([]Message, 120)); err != nil || c.got != 120 {
		t.Fatalf("sent %d, err %v", c.got, err)
	}
}
GO
      ;;
    api)
      mkdir -p "$d/server"
      cat >"$d/server/log.go" <<'GO'
package server

import (
	"log"
	"net/http"
)

// Logged logs each request's method and path.
func Logged(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}
GO
      cat >"$d/server/log_test.go" <<'GO'
package server

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestLogged(t *testing.T) {
	h := Logged(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	w := httptest.NewRecorder()
	h.ServeHTTP(w, httptest.NewRequest("GET", "/orders", nil))
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
}
GO
      ;;
    *) continue ;;
  esac
  printf 'module example.com/%s\n\ngo 1.22\n' "$p" >"$d/go.mod"
  (cd "$d" && git init -q && git add . && git -c user.name=demo -c user.email=demo@example.com commit -qm init)
done

# The personal workspace's projects: a small repo each, for a trail to sit in.
for p in ${DEMO_PERSONAL:-}; do
  d="$HOME/src/$p"
  mkdir -p "$d"
  printf '# %s\n\nNotes and drafts.\n' "$p" >"$d/README.md"
  (cd "$d" && git init -q && git add . && git -c user.name=demo -c user.email=demo@example.com commit -qm init)
done

# Neovim with no personal config (--clean), on the terminal's own black rather than its
# default scheme's grey, so it reads like the editors trails usually sits beside. Its
# :terminal runs through /bin/sh, not the login shell, whose startup files would put the
# machine's own trails and claude back in front of the sandbox's on PATH.
nvim() {
  command nvim --clean -c 'set shell=/bin/sh' \
    -c 'hi Normal guibg=NONE ctermbg=NONE' -c 'hi NormalNC guibg=NONE ctermbg=NONE' \
    -c 'hi EndOfBuffer guibg=NONE ctermbg=NONE' -c 'hi SignColumn guibg=NONE ctermbg=NONE' "$@"
}

# The tapes' off-camera step: hand a running session its task. Claude asks to trust a
# folder it hasn't seen, and only then — so this reads the screen and answers only when
# asked; pressing keys blindly could pull an old prompt out of claude's history and send it.
demo_task() { # session, task (empty: only answer the trust question, hand out nothing)
  for _ in $(seq 60); do
    screen=$(tmux capture-pane -pt "$1" 2>/dev/null)
    case $screen in
      *"Yes, I trust this folder"*) tmux send-keys -t "$1" Down Enter ;;
      *"for shortcuts"* | *"bypass permissions on"*) break ;;
      *) ;;
    esac
    sleep 0.5
  done
  [ -n "$2" ] || return 0
  sleep 1
  tmux send-keys -t "$1" -l "$2"
  tmux send-keys -t "$1" Enter
}

# The tape's last, hidden step: the tmux server, the project, its claude history, the sandbox.
demo_done() {
  # claude writes its conversation file once more as it dies; deleting the history before it
  # has would leave the file behind, and the next recording would refuse to start over it. So
  # note every process under the sandbox's panes, stop the server, and wait for those to go.
  pids=$(tmux list-panes -a -F '#{pane_pid}' 2>/dev/null)
  for _ in 1 2 3; do
    pids="$pids $(for p in $pids; do pgrep -P "$p"; done)"
  done
  tmux kill-server 2>/dev/null
  for _ in $(seq 40); do
    alive=
    for p in $pids; do kill -0 "$p" 2>/dev/null && alive=1; done
    [ -n "$alive" ] || break
    sleep 0.25
  done
  cd "$HOME" || return
  for p in $demo_dirs; do rm -rf "${HOME:?}/$p" "$(history_of "$HOME/$p")"; done
  rm -rf "$demo"
  [ -n "$made_code" ] && rmdir "$HOME/code" 2>/dev/null
  [ -n "$made_src" ] && rmdir "$HOME/src" 2>/dev/null
  return 0
}

cd "$project" || return
# shellcheck disable=SC2088 # a literal ~: the prompt shows it, nothing expands it
export PS1='~/code/checkout $ '
