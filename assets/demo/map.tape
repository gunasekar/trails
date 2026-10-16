# trails map: four real Claude Code sessions in four projects, watched in one window. Three run
# YOLO and get on with it; the fourth (api) runs in its normal mode, so it stops to ask — and
# the map puts it first, top left.
#
#   vhs assets/demo/map.tape         (from the repo root; writes assets/map.gif)
#
# Off camera: a trail is started in each project (all in the acme workspace) and detached, and
# demo_task hands each one its task through its editor view, answering claude's trust question
# for a new folder only if it asks. Four real tasks, so a recording costs a little of your
# plan. Runs in sandbox.sh's sandbox.

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
Type "export DEMO_EXTRA='storefront notify api' && source assets/demo/sandbox.sh && clear"
Enter
Sleep 2s

# A trail in each project, detached as soon as it starts.
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

Type "cd ~/code/notify && trails"
Enter
Sleep 2.5s
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s

# api in its normal mode: Tab flips the row from the config's yolo.
Type "cd ~/code/api && trails"
Enter
Sleep 2.5s
Tab
Sleep 500ms
Enter
Sleep 6s
Ctrl+B
Type "d"
Sleep 1s

# One line, so nothing queues behind it: hand out the four tasks, wait until api is asking,
# then clear. VHS's Wait holds until the prompt is back.
Type "demo_task acme/checkout 'Add an idempotency key to Retry: one key per payment, sent on every attempt. Run the tests, then reply in one sentence.'; demo_task acme/storefront 'Lazy-load the product images in catalog/images.go with loading=lazy, and update the test. Run the tests, then reply in one sentence.'; demo_task acme/notify 'Make SendAll send in batches of at most 50 messages, and test it. Run the tests, then reply in one sentence.'; demo_task acme/api 'Add a request ID to every log line in server/log.go, and test it. Run the tests, then reply in one sentence.'; demo_wait acme/api 'Do you want'; clear"
Enter
Wait+Line@240s /checkout \$\s*$/
Sleep 500ms
Set TypingSpeed 55ms
Show

# Four agents, four projects, one window — the one asking for you first.
Type "trails map 4"
Sleep 400ms
Enter
Sleep 20s

Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "demo_done"
Enter
# demo_done waits for the agents to exit before removing their history; give it time.
Sleep 15s
