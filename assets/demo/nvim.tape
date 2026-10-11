# trails as an agents panel in Neovim: code on the left, the picker on the right, and the agent
# running in that panel once picked.
#
#   vhs assets/demo/nvim.tape        (from the repo root; writes assets/nvim.gif)
#
# Neovim runs with --clean (sandbox.sh's nvim), so no personal config or plugins are in the
# shot; the split and the terminal are plain :vsplit and :terminal. Same sandbox as demo.tape.

Output assets/nvim.gif

Require nvim
Require claude
Require tmux
Require fzf
Require jq

Set Shell bash
Set FontSize 16
Set Width 1200
Set Height 520
Set Padding 16
# Black, like the editors and terminals trails usually lives in.
Set Theme { "name": "trails-black", "background": "#000000", "foreground": "#e6e6e6", "cursor": "#e6e6e6", "selection": "#303030", "black": "#000000", "red": "#e06c75", "green": "#98c379", "yellow": "#e5c07b", "blue": "#61afef", "magenta": "#c678dd", "cyan": "#56b6c2", "white": "#dcdfe4", "brightBlack": "#5c6370", "brightRed": "#ef7c86", "brightGreen": "#a8d389", "brightYellow": "#f0cd8b", "brightBlue": "#74bff5", "brightMagenta": "#d38bea", "brightCyan": "#66c6d2", "brightWhite": "#ffffff" }
Set TypingSpeed 55ms
Set CursorBlink false

Hide
Type "source assets/demo/sandbox.sh && clear"
Enter
Sleep 1s
Show

Type "nvim payments/retry.go"
Sleep 400ms
Enter
Sleep 1.5s

# The agents panel: a split on the right running trails.
Type ":vsplit | wincmd l | terminal trails"
Sleep 400ms
Enter
Sleep 400ms
Type "i"
Sleep 2.5s

# Start claude in the panel.
Enter
Wait+Screen@30s /bypass permissions/
Sleep 3s

Hide
Ctrl+B
Type "d"
Sleep 500ms
Ctrl+\
Ctrl+N
Type ":qa!"
Enter
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
