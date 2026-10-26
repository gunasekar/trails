# The map a key away: prefix M offers every trail in every workspace, the four that most want
# you ticked, and puts them in one window, 2×2, four agents at work side by side. The status
# line lists the map after the workspaces, ▦ map, one key from any of them.
#
#   vhs assets/demo/map.tape         (from the repo root; writes assets/map.gif)
#
# Off camera: a trail in each of four acme projects and in personal's blog, each started and
# detached, and demo_task hands each one its task just before the camera rolls, answering
# claude's trust question for a new folder only if it asks. Five real tasks, so a recording
# costs a little of your plan. Runs in sandbox.sh's sandbox, on the demo's own tmux config (`trails keys`, C-b prefix).

Output assets/map.gif

Require claude
Require tmux
Require fzf
Require jq

Set Shell bash
Set FontSize 13
Set Width 1600
Set Height 900
Set Padding 12
# Black, like the editors and terminals trails usually lives in.
Set Theme { "name": "trails-black", "background": "#000000", "foreground": "#e6e6e6", "cursor": "#e6e6e6", "selection": "#303030", "black": "#000000", "red": "#e06c75", "green": "#98c379", "yellow": "#e5c07b", "blue": "#61afef", "magenta": "#c678dd", "cyan": "#56b6c2", "white": "#dcdfe4", "brightBlack": "#5c6370", "brightRed": "#ef7c86", "brightGreen": "#a8d389", "brightYellow": "#f0cd8b", "brightBlue": "#74bff5", "brightMagenta": "#d38bea", "brightCyan": "#66c6d2", "brightWhite": "#ffffff" }
Set TypingSpeed 55ms
Set CursorBlink false

Hide
Set TypingSpeed 5ms
Type "export DEMO_EXTRA='storefront notify api' DEMO_PERSONAL='blog' && source assets/demo/sandbox.sh && clear"
Enter
Sleep 2s
# A trail in each project, through "＋ new trail…" and claude, detached as soon as it starts.
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
Type "cd ~/code/notify && trails"
Enter
Sleep 2.5s
Enter
Sleep 1.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s
Type "cd ~/code/api && trails"
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
# One line, so nothing queues behind it: hand out the four tasks, then clear. VHS's Wait holds
# until the prompt is back; the agents are at work by then.
Type "demo_task personal/blog 'Write a short first post in posts/hello.md: three paragraphs on why I started this blog. Then reply in one sentence.'; demo_task acme/checkout 'Add an idempotency key to Retry: one key per payment, sent on every attempt. Run the tests, then reply in one sentence.'; demo_task acme/storefront 'Lazy-load the product images in catalog/images.go with loading=lazy, and update the test. Run the tests, then reply in one sentence.'; demo_task acme/notify 'Make SendAll send in batches of at most 50 messages, and test it. Run the tests, then reply in one sentence.'; demo_task acme/api 'Add a request ID to every log line in server/log.go, and test it. Run the tests, then reply in one sentence.'; cd ~; export PS1='~ $ '; clear"
Enter
Wait+Line@240s /^~ \$\s*$/
Sleep 500ms
Set TypingSpeed 55ms
Show
# Into acme.
Type "trails"
Sleep 400ms
Enter
Sleep 2.5s
Type "acme"
Sleep 600ms
Enter
Sleep 3s
# prefix M: every trail in every workspace, the four that most want you ticked.
Ctrl+B
Type "M"
Wait+Screen@20s /tab: pick a trail/
Sleep 2.5s
# Tab changes the pick: one trail out, the one below it in.
Down
Sleep 400ms
Down
Sleep 400ms
Down
Sleep 800ms
Tab
Sleep 1s
Tab
Sleep 2s
Enter
# Four agents, four projects, one window.
Sleep 16s
# The map is in the status line beside the workspaces: prefix J to acme, prefix M back.
Ctrl+B
Type "J"
Sleep 3s
Ctrl+B
Type "M"
Sleep 5s
Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
