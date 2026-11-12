# trails from one terminal: the picker's one list of every workspace's trails, the same list in
# a popup over a trail, the live diff popup, the editor beside the agent and a floating
# pane, the workspaces moved between with a key, and the map: every trail side by side.
#
#   vhs assets/demo/trails.tape      (from the repo root; writes assets/trails.gif)
#
# Off camera: two real Claude Code trails in the acme workspace (one handed a task, so its
# row and its diff have something to show) and one in personal. Runs in sandbox.sh's sandbox, on the
# demo's own tmux config (the `trails tmux-config` lines, C-b prefix); requires tmux 3.8+
# for the floating-pane shortcut.
Output assets/trails.gif
Require claude
Require tmux
Require fzf
Require jq
Require nvim
Require hunk
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
# Two trails in acme and one in personal, each through "＋ new trail…" (typed: the cursor starts on a trail that wants you), its codebase (the
# cursor already on it) and claude, detached as soon as it starts.
Type "cd ~/code/checkout && trails"
Enter
Sleep 2.5s
Type "new trail"
Sleep 500ms
Enter
Sleep 1.5s
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
Type "new trail"
Sleep 500ms
Enter
Sleep 1.5s
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
Type "new trail"
Sleep 500ms
Enter
Sleep 1.5s
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
# Twenty seconds more off camera: the agent in checkout reads before it writes, and the diff
# popup should have something to show when the camera gets there.
Sleep 20s
Set TypingSpeed 55ms
Show
# From nowhere in particular: one list, every workspace with its trails and what each is
# doing; typing filters it.
Type "trails"
Sleep 400ms
Enter
Sleep 3.5s
# To checkout's trail, typed, in acme: the status line is acme's windows.
Type "checkout"
Sleep 2s
Enter
Sleep 3.5s
# The same list in a popup over the trail, prefix P; esc closes it.
Ctrl+B
Type "P"
Sleep 3.5s
Escape
Sleep 1.5s
# The agent's changes in the live Hunk popup: prefix H.
Ctrl+B
Type "H"
Sleep 5s
# Quit the popup, then open the editor beside the agent and a floating shell.
Type "q"
Sleep 1s
Ctrl+B
Type "E"
Sleep 4s
Ctrl+B
Type "`"
Sleep 3.5s
Ctrl+D
Sleep 1s
# To the next workspace and back, with prefix J and K.
Ctrl+B
Type "J"
Sleep 3s
Ctrl+B
Type "K"
Sleep 3s
# The map: prefix M offers every trail in every workspace, ticked; enter puts them side by side.
Ctrl+B
Type "M"
Wait+Screen@20s /tab: pick a trail/
Sleep 3s
Enter
Sleep 8s
Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
