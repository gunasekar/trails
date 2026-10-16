# trails over one connection: the workspaces, a workspace with its trails, and the editor and a
# shell brought up beside the agent with one key each. What `ssh host -t trails` looks like.
#
#   vhs assets/demo/workspace.tape   (from the repo root; writes assets/workspace.gif)
#
# Off camera: two real Claude Code trails are started in the acme workspace and one is handed a
# task, so the picker has something to count. Runs in sandbox.sh's sandbox, on the demo's own
# tmux config (the `trails keys` bindings, C-b prefix).

Output assets/workspace.gif

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
Type "export DEMO_EXTRA='storefront' && source assets/demo/sandbox.sh && clear"
Enter
Sleep 2s

# Two trails in acme, detached as soon as they start; checkout gets a task.
Type "cd ~/code/checkout && trails"
Enter
Sleep 2.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "cd ~/code/storefront && trails"
Enter
Sleep 2.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "demo_task acme/storefront ''; demo_task acme/checkout 'Add an idempotency key to Retry: one key per payment, sent on every attempt. Run the tests, then reply in one sentence.'; cd ~; export PS1='~ $ '; clear"
Enter
Wait+Line@60s /^~ \$\s*$/
Sleep 500ms
Set TypingSpeed 55ms
Show

# From nowhere in particular: the workspaces, with what runs in each.
Type "trails"
Sleep 400ms
Enter
Sleep 3.5s

# Into acme, landing on the trail that most wants you.
Enter
Sleep 4s

# The editor beside it, then a shell along the bottom: one key each.
Ctrl+B
Type "e"
Sleep 4s
Ctrl+B
Type "S"
Sleep 3s

# The workspace's trails, in a popup, from anywhere in it.
Ctrl+B
Type "a"
Sleep 4s
Escape
Sleep 1.5s

Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
