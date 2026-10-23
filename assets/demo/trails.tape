# trails from one terminal: the workspaces, a workspace's trails with the live preview, the
# editor and a shell beside the agent, and the status line's workspaces, moved between with a
# key.
#
#   vhs assets/demo/trails.tape      (from the repo root; writes assets/trails.gif)
#
# Off camera: two real Claude Code trails in the acme workspace (one handed a task, so the
# preview has something to show) and one in personal. Runs in sandbox.sh's sandbox, on the
# demo's own tmux config (the `trails keys` lines, C-b prefix).
Output assets/trails.gif
Require claude
Require tmux
Require fzf
Require jq
Require nvim
Set Shell bash
Set FontSize 14
Set Width 1600
Set Height 900
Set Padding 12
# Black, like the editors and terminals trails usually lives in.
Set Theme { "name": "trails-black", "background": "#000000", "foreground": "#e6e6e6", "cursor": "#e6e6e6", "selection": "#303030", "black": "#000000", "red": "#e06c75", "green": "#98c379", "yellow": "#e5c07b", "blue": "#61afef", "magenta": "#c678dd", "cyan": "#56b6c2", "white": "#dcdfe4", "brightBlack": "#5c6370", "brightRed": "#ef7c86", "brightGreen": "#a8d389", "brightYellow": "#f0cd8b", "brightBlue": "#74bff5", "brightMagenta": "#d38bea", "brightCyan": "#66c6d2", "brightWhite": "#ffffff" }
Set TypingSpeed 55ms
Set CursorBlink false
Hide
Set TypingSpeed 5ms
Type "export DEMO_EXTRA='storefront' DEMO_PERSONAL='blog' && source assets/demo/sandbox.sh && clear"
Enter
Sleep 2s
# Two trails in acme and one in personal, each through "＋ new trail…" and claude, detached
# as soon as it starts.
Type "cd ~/code/checkout && trails"
Enter
Sleep 2.5s
Enter
Sleep 1.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "cd ~/code/storefront && trails"
Enter
Sleep 2.5s
Enter
Sleep 1.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "cd ~/src/blog && trails"
Enter
Sleep 2.5s
Enter
Sleep 1.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "demo_task acme/storefront ''; demo_task personal/blog ''; demo_task acme/checkout 'Add an idempotency key to Retry: one key per payment, sent on every attempt. Run the tests, then reply in one sentence.'; cd ~; export PS1='~ $ '; clear"
Enter
Wait+Line@90s /^~ \$\s*$/
Sleep 500ms
Set TypingSpeed 55ms
Show
# From nowhere in particular: the workspaces, with what runs in each.
Type "trails"
Sleep 400ms
Enter
Sleep 3s
# Into acme: the status line lists the workspaces, acme in reverse.
Type "acme"
Sleep 600ms
Enter
Sleep 3.5s
# The workspace's trails, in a popup, the live preview under them: down to checkout, open it.
Ctrl+B
Type "P"
Sleep 3s
Down
Sleep 3.5s
Enter
Sleep 2.5s
# The editor beside the agent, then a shell along the bottom: one key each.
Ctrl+B
Type "e"
Sleep 3.5s
Ctrl+B
Type "`"
Sleep 3.5s
# To the next workspace and back, with prefix ) and (.
Ctrl+B
Type ")"
Sleep 3s
Ctrl+B
Type "("
Sleep 3s
Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
