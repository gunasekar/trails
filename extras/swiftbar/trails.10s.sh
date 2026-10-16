#!/usr/bin/env bash

# trails in the macOS menu bar: the agents that want you back.
#
# <swiftbar.title>trails</swiftbar.title>
# <swiftbar.version>v1.0</swiftbar.version>
# <swiftbar.desc>Which trails agent sessions are blocked, idle, or working</swiftbar.desc>
# <swiftbar.dependencies>tmux,trails,jq</swiftbar.dependencies>
# <swiftbar.hideAbout>true</swiftbar.hideAbout>
# <swiftbar.hideRunInTerminal>true</swiftbar.hideRunInTerminal>
# <swiftbar.hideLastUpdated>true</swiftbar.hideLastUpdated>
# <swiftbar.hideDisablePlugin>true</swiftbar.hideDisablePlugin>
# <swiftbar.hideSwiftBar>true</swiftbar.hideSwiftBar>
# <swiftbar.refreshOnOpen>true</swiftbar.refreshOnOpen>
#
# The picker (`trails`) only tells you when you go and look, and it is scoped to the
# project you are standing in. This is the other half: every agent on the box, polled,
# whether or not you are looking — the "what did I leave running while I walked away"
# view. All the thinking lives in `trails ls -a`, which decides blocked/idle/working
# from the agent's own state where it writes one down, else by diffing each session's
# screen (see trails' docs/ARCHITECTURE.md); this file only renders it.
#
# Ships with trails, in its share directory. `trails swiftbar` links it into SwiftBar's
# plugin folder, so `brew upgrade trails` updates the plugin along with the tool whose
# output it reads — the two can't drift apart.
#
# It emits nothing at all when no agent is running, which is how SwiftBar is told to
# hide the menu bar item entirely — an icon that is always there is one you stop seeing.
#
# ─── When it speaks ──────────────────────────────────────────────────────────
# It announces the working → stopped edge, but not the instant it sees it: an agent has
# to sit stopped for TRAILS_NOTIFY_AFTER seconds (default 30) before it may speak.
#
# The wait is there because nothing here can tell whether you are *looking* at a session.
# With no wait, an agent you are sitting in front of crosses that edge at the end of every
# single turn, so you would hear about the one you are looking at — once per reply. There
# is no way to ask tmux whether you are looking: every session has a client attached (a
# Ghostty window, a Zed thread, an nvim panel), so attachment says nothing, and
# #{client_activity} — which does track your keystrokes and not pane output, verified: it
# did not move once through 48s of an agent painting flat out — answers "when did you last
# type", which after a three-minute turn reads the same whether you are staring at the pane
# or asleep.
#
# The lever that does work is time, and it is the only one. Sitting there, you reply in
# seconds and it goes back to working before the wait is up; walked away, it just sits and,
# once the wait passes, speaks. So the wait silences the session you are working with for
# free — no focus detection, no heuristic, nothing to get wrong — at the cost of that much
# latency on a genuine walk-away, and it makes any future misclassification persist for the
# whole wait before it can reach you. TRAILS_NOTIFY_AFTER is that dial, in seconds: 0 puts
# the sound back on every reply, 60 was the older default, 30 is the middle it sits at now.
#
# `said` bounds it either way: one banner per stop, however many times the screen is
# re-read. Only a return to working re-arms it.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

# Two paths to this file. $0 is the one SwiftBar ran, the link `trails swiftbar` made in
# its plugin folder, and it is what the menu's actions call back: it survives a `brew
# upgrade`. The real path, through Homebrew's Cellar, carries the version, and the old
# version's directory goes with the upgrade, so a menu built before one pointed its Resume
# and End at a file that was gone until the next refresh. The real path is for what sits
# beside this file: the icons, and a by-hand install's trails.
SCRIPT_PATH="$0"
REAL_PATH="$(realpath -q "$0")"

# trails comes from Homebrew (gunasekar/tap). SwiftBar runs plugins from launchd, whose
# PATH is not the shell's, which is what the export above is for: both Homebrew prefixes
# go first, so the lookup finds it on Apple Silicon and Intel alike.
#
# Then the trails this plugin shipped with, found from the plugin's own real path: a by-hand
# install (bin/trails in ~/.local/bin, say, which launchd's PATH never has) links the plugin
# out of a checkout, where trails is ../../bin/trails, and Homebrew's Cellar keeps it at
# ../../../bin/trails. Without this a by-hand install showed nothing, forever, exactly like
# "no agents running". Found nowhere, the plugin still says nothing.
TRAILS=$(command -v trails) || {
  for t in "$(dirname "$REAL_PATH")/../../bin/trails" "$(dirname "$REAL_PATH")/../../../bin/trails"; do
    [ -x "$t" ] && TRAILS=$t && break
  done
  [ -n "$TRAILS" ] || exit 0
}

# Posted by SwiftBar itself rather than by osascript, which delivered them as "Script
# Editor" — an app nobody chose, sharing a bucket with every other script on the machine,
# so tuning or muting agent alerts meant tuning every AppleScript you own. SwiftBar tags
# each notification with threadIdentifier = this plugin, so Notification Center collapses
# the pile into one "trails" group, and clicking through has somewhere to go.
#
# It cannot clear the previous one. swiftbar://notify accepts no identifier, and SwiftBar
# stamps every request with a fresh UUID (v2.0.1, PluginManger.swift:374), so "replace
# what this session said last time" is not expressible through this API at all — six
# finishes leave six entries in the group. Only the *banner* is bounded, by `said` below:
# one per stop, however the screen is re-read.
#
# No silent=true, so these make a sound — the osascript they replaced never did, because
# `display notification` is mute unless asked. A banner is Temporary by default: it shows
# for a few seconds and is gone, which is no use to the one case this exists for, where
# you are not at the screen. The sound is the part that survives not looking.
#
# Which also makes it the part that grates. `said` below holds it to one per stop, but
# with no wait configured a stop is every turn-end, so on a session you are sitting in
# it sounds once per reply — see the note up top. Muting it is at least a per-app toggle
# now that it is SwiftBar's own notification, rather than silencing every AppleScript on
# the machine, which is what the old shared "Script Editor" identity would have meant.
#
# jq's @uri, not hand-rolled escaping: the title and the agent's own task text are being
# pasted into a URL, and the task is arbitrary prose. A bare & truncates the notification
# at the ampersand and a bare # drops the rest, both silently. @uri also gets multi-byte
# right (· and — survive), which a byte-wise shell loop would mangle.
#
# One thing encoding cannot save: SwiftBar rewrites "+" back to a space on the way out,
# so a task title containing a plus loses it. Cosmetic, and not ours to fix.
urlenc() { printf '%s' "$1" | jq -sRr @uri; }

notify() { # title, body
  # name= is the plugin, which SwiftBar knows by its file name: trails.10s.sh is "trails".
  open -g "swiftbar://notify?name=trails&title=$(urlenc "$1")&body=$(urlenc "$2")" \
    >/dev/null 2>&1 || true
}

# ─── Actions (SwiftBar re-runs this file with the function name as param1) ───
# Resume: open the trail in your terminal — a new tab in the front window where the terminal
# has one, a new window otherwise — through `trails open`, so it lands where the picker
# would: the workspace on the trail's window, editor and shell beside the agent. The command
# *is* the attach, so detaching closes it. trails by absolute path, since the new tab does
# not get this file's PATH. macOS asks once to let SwiftBar control the terminal.
#
# Which terminal is yours to pick, from "Open sessions in" at the bottom of the menu:
# Terminal (the default, since every Mac has it), iTerm or Ghostty. One that isn't
# installed falls back to Terminal rather than doing nothing.
#
# The pick lives with trails' own settings, in ~/.config/trails/terminal — not in SwiftBar's
# storage for the plugin, where it first went. SwiftBar names that folder after the plugin's
# real path once links are followed, and through Homebrew that path has the version in it
# (…/Cellar/trails/0.3.0/…): every upgrade got a new, empty folder, and the pick quietly
# went back to Terminal. A pick saved there is still read, until a new one is made.
TERMINALS="terminal iterm ghostty"
TERMINAL_FILE="${XDG_CONFIG_HOME:-${HOME}/.config}/trails/terminal"
OLD_TERMINAL_FILE="${SWIFTBAR_PLUGIN_DATA_PATH:-}/terminal"

terminal_app() { # terminal id -> app name
  case $1 in
    iterm) echo iTerm ;;
    ghostty) echo Ghostty ;;
    *) echo Terminal ;;
  esac
}
installed() { open -Ra "$(terminal_app "$1")" 2>/dev/null; }

chosen_terminal() {
  t=$(cat "$TERMINAL_FILE" 2>/dev/null || cat "$OLD_TERMINAL_FILE" 2>/dev/null)
  case " $TERMINALS " in *" $t "*) ;; *) t=terminal ;; esac
  installed "$t" || t=terminal
  echo "$t"
}

function set_terminal() {
  case " $TERMINALS " in *" $1 "*) ;; *) return 0 ;; esac
  mkdir -p "$(dirname "$TERMINAL_FILE")" && printf '%s\n' "$1" >"$TERMINAL_FILE"
}

function resume() {
  case $(chosen_terminal) in
    ghostty)
      osascript - "$TRAILS" "$1" <<'OSA' >/dev/null
on run argv
  set cmd to quoted form of (item 1 of argv) & " open " & quoted form of (item 2 of argv)
  tell application "Ghostty"
    activate
    set cfg to new surface configuration
    set command of cfg to cmd
    if (count of windows) > 0 then
      new tab in front window with configuration cfg
    else
      new window with configuration cfg
    end if
  end tell
end run
OSA
      ;;
    iterm)
      osascript - "$TRAILS" "$1" <<'OSA' >/dev/null
on run argv
  set cmd to quoted form of (item 1 of argv) & " open " & quoted form of (item 2 of argv)
  tell application "iTerm"
    activate
    if (count of windows) > 0 then
      tell current window to create tab with default profile command cmd
    else
      create window with default profile command cmd
    end if
  end tell
end run
OSA
      ;;
    *)
      # Terminal runs the command in a shell, so exec: detaching ends the shell too, rather
      # than leaving a prompt behind.
      osascript - "$TRAILS" "$1" <<'OSA' >/dev/null
on run argv
  set cmd to "exec " & quoted form of (item 1 of argv) & " open " & quoted form of (item 2 of argv)
  tell application "Terminal"
    activate
    do script cmd
  end tell
end run
OSA
      ;;
  esac
}

# End: stop the trail for good — a hard stop, the agent gets no chance to tidy up, though
# its transcript stays on disk for its own --resume. `trails end` closes its window (and the
# session that holds it) or, for a session from before 1.0, the session, and forgets the
# restore record — `trails restore` exists for trails tmux took down, not ones you closed.
# A refusal is shown as a notification rather than lost: a click that did nothing, with
# the row still there on the next refresh, is otherwise impossible to tell from a slow one.
function end() {
  local out
  out=$("$TRAILS" end "$1" 2>&1) || notify "trails: could not end $1" "${out:-trails end failed}"
}

# Picking a terminal from the menu: param2 is a terminal id, checked against the list.
if [[ $# -ge 2 && $1 == set_terminal ]]; then
  set_terminal "$2"
  exit 0
fi

# Only ever act on a trail: param2 comes back from our own menu, but a stray `name=` reaching
# an attach or an end is not a thing to leave to trust. A key is <workspace>/<name> since
# 1.0, or trails-<project> from before.
if [[ $# -ge 2 && ($2 == */* || $2 == trails-*) ]]; then
  case $1 in
    resume | end) "$1" "$2" ;;
    *) ;;
  esac
  exit 0
fi

# Every directory's (-a: plain `trails ls` is only the directory it runs in, which for a
# launchd job is nobody's project). Running sessions only (`life` is running): `trails ls`
# also lists ones lost with tmux and ended conversations, and neither is anything to
# announce. The life column is cut off, so what's read below starts at the state.
# TRAILS_RECENT_MAX=0 skips reading conversation history altogether, the bulk of an ls,
# every 10 seconds.
ROWS=$(TRAILS_RECENT_MAX=0 "$TRAILS" ls -a 2>/dev/null |
  awk -F'\t' '$1 == "running"' | cut -f2-)

# One line per session: name, state, when it entered that state, whether it has been
# seen working (so a session that was already idle when the plugin first saw it is not
# announced — that is not news), and whether we have already spoken about this episode.
STATE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/trails"
STATE_FILE="${STATE_DIR}/swiftbar-state"
mkdir -p "$STATE_DIR"

# One run at a time from here to the state file's rename. SwiftBar overlaps runs — the timer,
# refreshOnOpen when you open the menu, a refresh=true click — and two that both read the
# same state both saw said=0, and both announced the same stop. mkdir is the lock because it
# is atomic. A run waits up to 5s for one in progress (a run takes about one), and a lock
# older than a minute is from a run that was killed, so it is taken over. One that still has
# no lock after the wait goes ahead without it, and leaves the other run's lock alone.
LOCK="${STATE_FILE}.lock"
LOCKED='' NEXT=''
for _ in 1 2 3 4 5 6 7 8 9 10; do
  mkdir "$LOCK" 2>/dev/null && LOCKED=1 && break
  [ -n "$(find "$LOCK" -maxdepth 0 -mmin +1 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null
  sleep 0.5
done
trap '[ -n "$LOCKED" ] && rmdir "$LOCK" 2>/dev/null; [ -n "$NEXT" ] && rm -f "$NEXT"' EXIT

# No agent running: forget every session rather than leave the last poll's rows behind. Kept,
# a row outlived its session and was inherited by the next one to take its name — days later,
# a fresh trails-foo read the old one's seen=1 said=0 and was announced the moment it opened.
[ -n "$ROWS" ] || {
  rm -f "$STATE_FILE"
  exit 0
}

DIM='#5c6370' # the summary footer

# How long an agent has to sit there wanting you before it is allowed to say so.
# Default 30 seconds; TRAILS_NOTIFY_AFTER overrides (AGENT_NOTIFY_AFTER, its old name, still does). Zero would make the poll that sees it
# stop the poll that says so — see the note above for why the default is a wait, not zero.
# Whole seconds only: anything else ("30s", 0.5) made the comparison below an error on every
# poll, and no agent was ever announced. Not a number falls back to the default.
GRACE=${TRAILS_NOTIFY_AFTER:-${AGENT_NOTIFY_AFTER:-30}}
[[ $GRACE =~ ^[0-9]+$ ]] || GRACE=30
NOW=$(date +%s)

PREV=$(cat "$STATE_FILE" 2>/dev/null)
NEXT=$(mktemp "${STATE_FILE}.XXXXXX") || exit 0

# 3 -> ³, so the count rides on the icon's shoulder, instead of
# sitting beside it at full height.
superscript() {
  local n=$1 out='' i sup=(⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹)
  for ((i = 0; i < ${#n}; i++)); do out+=${sup[${n:i:1}]}; done
  printf '%s' "$out"
}

# Which terminal Resume opens in, worked out once per refresh: each check asks LaunchServices.
CURRENT_TERMINAL=$(chosen_terminal)
TERMINAL_NAME=$(terminal_app "$CURRENT_TERMINAL")

blocked=0 idle=0 working=0
menu=''

# The TSV is `life state session agent yolo dir id when pid peer workspace title`, with - for
# an empty field (see trails' README). Read as fields, and the title taken as the last one
# rather than by position: a trails from before the peer or workspace columns has fewer
# fields, and a plugin linked out of a checkout can meet an older trails from Homebrew.
while IFS=$'\t' read -ra f; do
  state=${f[0]:-} name=${f[1]:-} agent=${f[2]:-} yolo=${f[3]:-}
  task='' peer=''
  ((${#f[@]} >= 9)) && task=${f[${#f[@]} - 1]}
  ((${#f[@]} >= 10)) && [ "${f[8]}" != - ] && peer=${f[8]}
  [ -n "$name" ] || continue
  # trails names a running agent's state needs-you, your-turn or working; this file's logic
  # keeps its own shorter names for them, and shows trails' words.
  case $state in
    needs-you) state=blocked word="needs you" ;;
    your-turn) state=idle word="your turn" ;;
    *) state=working word=working ;;
  esac
  label=$agent
  [ "$yolo" = yolo ] && label+=" (YOLO)"

  # lattiq/my_api-2 (or trails-my_api-2 before 1.0)  ->  project "my_api", badge "#2". A
  # project name may itself contain a dash, so only a *trailing* -<digits> is the sibling
  # counter.
  proj=${name#trails-}
  proj=${proj##*/}
  badge=''
  if [[ $proj =~ ^(.*)-([0-9]+)$ ]]; then
    proj="${BASH_REMATCH[1]}"
    badge=" #${BASH_REMATCH[2]}"
  fi

  # `trails ls` owns these names, and *) means working — so a state it grows that this
  # does not know lands in the "leave it alone" pile rather than raising a false alarm.
  # The cost of that default is that renaming one there fails silently here: the arm stops
  # matching, and every agent that wants you is counted as busy and left unannounced. The
  # two files have to move together.
  #
  # The state is carried by an SF Symbol, its shape rather than a colour: SwiftBar 2.1.1
  # repaints a coloured sfimage on a menu row as a plain template on macOS 26
  # (swiftbar/SwiftBar#537, fixed in 2.1.2), and a color= would tint the whole line. So the
  # icon and the text both take the menu's own colour, and follow light/dark.
  #
  # refresh=true is what keeps the text that colour. A row with no action and no color is a
  # *disabled* item to AppKit, and disabled items are drawn grey — which is exactly how the
  # working rows came out once their color= went. It also keeps the row's Resume/End
  # submenu usable: SwiftBar 2.1.0–2.1.1 greys out an *actionless* submenu parent for good
  # once its child count changes (swiftbar/SwiftBar#512), and a row's count does change as
  # it goes idle and back. An action makes the row SwiftBar's, which that bug never touches.
  case $state in
    blocked)
      icon=hand.raised
      ((blocked++))
      ;;
    idle)
      icon=moon.zzz
      ((idle++))
      ;;
    *)
      icon=hourglass
      ((working++))
      ;;
  esac

  # @peer is the name another Claude session messages this one by. Left out when the
  # trail's own name already says it (a named trail: lattiq/payments is shown as payments,
  # and its claude answers to payments), and so is a task that repeats it.
  line="${word} · ${label} · ${proj}${badge}"
  [ -n "$peer" ] && [ "$peer" != "$proj" ] && line+=" @${peer}"
  [ -n "$task" ] && [ "$task" != "$peer" ] && line+=" — ${task}"
  menu+="${line//|/－} | sfimage=${icon} refresh=true"$'\n'
  # What to do about it, one level down. Resume for every state — even a working one is
  # worth watching. End only once it has gone idle: killing a session mid-turn, or one that
  # is waiting on your answer, is a decision this menu should not make that easy.
  menu+="--Resume in ${TERMINAL_NAME} | bash='${SCRIPT_PATH}' param1=resume param2=${name} terminal=false sfimage=play"$'\n'
  [ "$state" = idle ] &&
    menu+="--End session | bash='${SCRIPT_PATH}' param1=end param2=${name} terminal=false refresh=true sfimage=xmark.circle"$'\n'

  # What we knew about this session last poll (all empty the first time we see it).
  IFS=$'\t' read -r p_state p_since p_seen p_said < <(
    printf '%s\n' "$PREV" | awk -F'\t' -v n="$name" '$1 == n { print $2 "\t" $3 "\t" $4 "\t" $5; exit }'
  )

  if [ "$state" = working ]; then
    # Working resets everything: it has now been seen working, so the next time it
    # stops that is a real episode, and it has not been spoken about yet.
    since=$NOW seen=1 said=0
  else
    case $p_state in
      working)
        # The edge this notifier exists for: it was working, now it is not.
        since=$NOW seen=1 said=0
        ;;
      '')
        # First sight, and already stopped. We never saw it finish, so there is no
        # episode to announce — seen=0 keeps it quiet until it works and stops again.
        since=$NOW seen=0 said=0
        ;;
      *)
        # Stopped -> stopped, which includes idle <-> blocked. Carry the clock and the
        # guard straight across it.
        #
        # Those two are not two events. They are one motionless screen read twice, and
        # which name it gets is decided by grepping whatever text happens to occupy the
        # bottom 15 lines — so a flip means the text moved, not that the agent did
        # anything. It is a guess by construction (trails' own comment calls it "the one
        # heuristic"), and it is wrong often enough to matter: any agent that merely
        # prints the words "Do you want" reads as blocked while it sits there idle.
        #
        # Resetting `said` here announced one stop twice — once as idle, again as
        # blocked — for a screen that never changed. Only working re-arms.
        since=${p_since:-$NOW} seen=${p_seen:-0} said=${p_said:-0}
        ;;
    esac

    if [ "$seen" = 1 ] && [ "$said" = 0 ] && [ $((NOW - since)) -ge "$GRACE" ]; then
      if [ "$state" = blocked ]; then
        notify "${agent} · needs you · ${proj}" "${task:-Waiting on a permission prompt}"
      else
        notify "${agent} · your turn · ${proj}" "${task:-Finished — waiting for your next move}"
      fi
      said=1
    fi
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$state" "$since" "$seen" "$said" >>"$NEXT"
done <<<"$ROWS"

mv -f "$NEXT" "$STATE_FILE"

# Menu bar: the trails mark, its two dots the state — the top one "wants you" (red when an
# agent is asking you something, amber when one finished its turn, grey otherwise), the
# bottom one "working" (green while anything is). Beside it, how many want you, or when
# nothing does, how many are working.
#
# Pre-drawn PNGs, one per state and bar appearance, from trails' assets/render.swift
# (`swift assets/render.swift --menubar extras/swiftbar/icons`): SwiftBar takes an image as
# base64, and drawing one here every ten seconds would mean a renderer this script doesn't
# have. They ship in icons/ next to this file, found through the link `trails swiftbar` made
# — not in SwiftBar's plugin folder, where it would try each one as a plugin.
# Each is 36 px at 144 dpi, which SwiftBar sizes as 18 pt — sharp on a Retina bar.
#
# The bar's appearance is the system's: a coloured image can't be a template image, so it
# can't follow the bar by itself, and the ink has to be picked here.
ICONS="$(dirname "$REAL_PATH")/icons"
want=$((blocked + idle))
top=none
[ "$idle" -gt 0 ] && top=idle
[ "$blocked" -gt 0 ] && top=blocked
bottom=rest
[ "$working" -gt 0 ] && bottom=working
bar=light
[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null)" = Dark ] && bar=dark
count=$want
[ "$want" -gt 0 ] || count=$working
icon="${ICONS}/trails-${bar}-${top}-${bottom}.png"
if [ -f "$icon" ]; then
  echo "$(superscript "$count") | image=$(base64 <"$icon" | tr -d '\n')"
else
  # No icons next to this copy of the plugin: a stock symbol rather than nothing.
  echo "$(superscript "$count") | sfimage=point.bottomleft.forward.to.point.topright.scurvepath"
fi

echo '---'
printf '%s' "$menu"
echo '---'
echo "${blocked} needs you · ${idle} your turn · ${working} working | color=${DIM} size=11"
echo "Open sessions in"
for t in $TERMINALS; do
  name=$(terminal_app "$t")
  if ! installed "$t"; then
    echo "--${name} (not installed) | color=${DIM}"
  elif [ "$t" = "$CURRENT_TERMINAL" ]; then
    echo "--${name} | checked=true bash='${SCRIPT_PATH}' param1=set_terminal param2=${t} terminal=false refresh=true"
  else
    echo "--${name} | bash='${SCRIPT_PATH}' param1=set_terminal param2=${t} terminal=false refresh=true"
  fi
done
echo "Refresh | refresh=true"
