# The README demo: start an agent, lose it to a "reboot", get it back.
#
#   vhs assets/demo/demo.tape        (from the repo root; writes assets/demo.gif)
#
# Runs in a sandbox (sandbox.sh): trails' own config, records and tmux server, a sample project
# at ~/code/checkout, and the real Claude Code with your login — it really does the task, so a
# recording costs a few cents. The project and its claude history are removed afterwards.

Output assets/demo.gif

Require tmux
Require claude
Require fzf
Require jq

Set Shell bash
Set FontSize 16
Set Width 1400
Set Height 680
Set Padding 24
# Black, like the editors and terminals trails usually lives in.
Set Theme { "name": "trails-black", "background": "#000000", "foreground": "#e6e6e6", "cursor": "#e6e6e6", "selection": "#303030", "black": "#000000", "red": "#e06c75", "green": "#98c379", "yellow": "#e5c07b", "blue": "#61afef", "magenta": "#c678dd", "cyan": "#56b6c2", "white": "#dcdfe4", "brightBlack": "#5c6370", "brightRed": "#ef7c86", "brightGreen": "#a8d389", "brightYellow": "#f0cd8b", "brightBlue": "#74bff5", "brightMagenta": "#d38bea", "brightCyan": "#66c6d2", "brightWhite": "#ffffff" }
Set TypingSpeed 55ms
Set CursorBlink false

Hide
Type "source assets/demo/sandbox.sh && clear"
Enter
Sleep 1s
Show

# Pick a trail in this project: start claude, and give it a task.
Type "trails"
Sleep 400ms
Enter
Sleep 2.5s
Enter
Wait+Screen@30s /bypass permissions on/
Sleep 1s
Set TypingSpeed 18ms
Type "Add an idempotency key to Retry: one key per payment, sent on every attempt. Run the tests, then reply in two sentences."
Set TypingSpeed 55ms
Sleep 300ms
Enter
Wait+Screen@240s /for [0-9]+[sm].*done/
Sleep 4s

# Detach. The agent keeps running in tmux.
Ctrl+B
Type "d"
Sleep 1.5s

Type "trails ls"
Sleep 400ms
Enter
Sleep 3.5s

# Pull the rug out: every tmux session gone, as after a reboot.
Type "tmux kill-server   # a reboot"
Sleep 400ms
Enter
Sleep 1.5s

# trails still knows where it was, and Enter brings it back on its conversation.
Type "trails"
Sleep 400ms
Enter
Sleep 3s
Enter
Wait+Screen@30s /bypass permissions on/
Sleep 4s

Hide
Ctrl+B
Type "d"
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
