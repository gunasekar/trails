#!/bin/sh
# Batched record reads: alive IDs, pre-ID windows, server scope, and held history.
. "$REPO/test/lib.sh"
t_setup

mkdir -p "$STATE/proj" "$XDG_STATE_HOME/trails/history"
record() {
  printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=%s\nworkspace=default\nlabel=proj\nname=\nserver=%s\ntrail=%s\nsession=%s\n' \
    "$PROJ" "$2" "$1 task" "$3" "$1" "$4" >"$STATE/proj/$1"
}
record t1111 live-id default default/live
record t2222 legacy-id default default/legacy
record t3333 lost-id default default/lost
record t4444 foreign-id other default/foreign
record t5555 different-id default default/mismatch

tmux new-session -d -s live 'sleep 300'
tmux set-option -w -t '=live:' @trails_trail t1111
tmux new-session -d -s legacy 'sleep 300'
tmux set-option -w -t '=legacy:' @trails_session default/legacy
tmux set-option -w -t '=legacy:' @trails_id legacy-id
tmux new-session -d -s mismatch 'sleep 300'
tmux set-option -w -t '=mismatch:' @trails_session default/mismatch
tmux set-option -w -t '=mismatch:' @trails_id other-id

# A held conversation is not repeated as history; an unheld one is.
for id in lost-id history-id; do
  printf 'agent=stub\ndir=%s\nid=%s\nyolo=\ntask=%s\nended=%s\n' \
    "$PROJ" "$id" "$id history" "$(date +%s)" >"$XDG_STATE_HOME/trails/history/$id"
done
out=$(cd "$PROJ" && "$TRAILS" ls -a)
assert_eq "$(printf '%s\n' "$out" | awk -F '\t' '$1 == "stopped" && $2 == "lost" {print $10}' | sort | tr '\n' ' ')" \
  't3333 t5555 ' 'only dead records on this server are lost'
assert_eq "$(printf '%s\n' "$out" | grep -c 'lost-id history')" 0 'a held ID is omitted from history'
assert_eq "$(printf '%s\n' "$out" | grep -c 'history-id history')" 1 'unheld history remains visible'
