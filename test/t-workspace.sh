#!/bin/sh
# Workspaces from the config: which workspace a directory belongs to, by path, glob,
# repository and worktree; and `trails ws` to list, ask and add.
. "$REPO/test/lib.sh"
t_setup

ws() { "$TRAILS" ws "$@"; }
ws_of() { "$TRAILS" ws of "$1" 2>/dev/null; }

mkdir -p "$T/workspace/lattiq/augur/cmd" "$T/workspace/lattiq/special" \
  "$T/workspace/gunasekar/trails" "$T/.dotfiles/zsh" "$T/other" "$T/infra"

# No workspaces configured: everything is "default".
assert_eq "$(ws_of "$T/workspace/lattiq/augur")" default "default with no config"
assert_match "$(ws 2>&1)" 'no workspaces in' "ws says so"

# Three workspaces, as the design doc spells them: object form, bare list, root or not.
cat >"$XDG_CONFIG_HOME/trails/config.json" <<EOF
{
  "agents": [ { "name": "stub", "program": "agent" } ],
  "workspaces": {
    "lattiq":   { "root": "~/workspace/lattiq", "codebases": ["~/workspace/lattiq/*"] },
    "personal": ["~/workspace/gunasekar/*", "~/.dotfiles", "~/workspace/lattiq/special/"],
    "empty":    {},
    "bad.name": ["~/other"]
  }
}
EOF

assert_eq "$(ws_of "$T/workspace/lattiq/augur")" lattiq "a glob"
assert_eq "$(ws_of "$T/workspace/gunasekar/trails")" personal "another glob"
assert_eq "$(ws_of "$T/.dotfiles")" personal "an exact path"
assert_eq "$(ws_of "$T/workspace/lattiq/special")" personal "an exact path beats a glob"
assert_eq "$(ws_of "$T/workspace/lattiq/augur/cmd")" lattiq "a glob reaches subdirectories"
assert_eq "$(ws_of "$T/other")" "" "a bad workspace name claims nothing"
assert_match "$(ws of "$T/other" 2>&1)" 'no workspace claims ~/other.*trails ws add' "and says what to do"
assert_match "$(ws of "$T/other" 2>&1)" 'skipping workspace "bad.name"' "the bad name is reported"
( cd "$T/.dotfiles" && [ "$(ws of 2>/dev/null)" = personal ] ) || fail "ws of defaults to here"

# A worktree follows its main checkout, and a subdirectory of a repo follows the repo.
g() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@"; }
( cd "$T/workspace/lattiq/augur" && g init -q && touch a && g add a && g commit -qm a &&
  g worktree add -q "$T/wt/augur-retry" -b retry ) >/dev/null 2>&1 || fail "git setup"
( cd "$T/.dotfiles" && g init -q && touch a && g add a && g commit -qm a ) >/dev/null 2>&1 || fail "git setup"
assert_eq "$(ws_of "$T/wt/augur-retry")" lattiq "a worktree follows its repo"
assert_eq "$(ws_of "$T/.dotfiles/zsh")" personal "a repo's subdirectory follows the repo"

# The listing: names in config order, roots, entries as written (the ~ is the point).
list=$(ws 2>/dev/null)
assert_eq "$(printf '%s\n' "$list" | cut -f1 | tr '\n' ' ')" "lattiq personal empty " "listed in order"
# shellcheck disable=SC2088
assert_eq "$(printf '%s\n' "$list" | awk -F'\t' '$1 == "lattiq" { print $2 "|" $3 }')" \
  '~/workspace/lattiq|~/workspace/lattiq/*' "root and entry"
assert_eq "$(printf '%s\n' "$list" | awk -F'\t' '$1 == "empty" { print $2 "|" $3 }')" "-|" "no root, no entries"

# Adding: a new workspace, an existing one, the same entry twice, a bad name.
assert_eq "$(cd "$T/infra" && ws add infra)" "added ~/infra to infra" "add here to a new workspace"
assert_eq "$(ws_of "$T/infra")" infra "and it resolves"
assert_eq "$(ws add lattiq "$T/other")" "added ~/other to lattiq" "add a directory to an existing one"
assert_eq "$(ws_of "$T/other")" lattiq "and it resolves"
assert_match "$(ws add lattiq "$T/other" 2>&1)" 'already in lattiq' "no duplicates"
# shellcheck disable=SC2088
assert_eq "$(jq -r '.workspaces.lattiq.codebases | join(",")' "$XDG_CONFIG_HOME/trails/config.json")" \
  '~/workspace/lattiq/*,~/other' "the config as written"
assert_match "$(ws add 'no/slash' "$T/other" 2>&1)" 'letters, digits' "a bad name is refused"
assert_match "$(ws add infra "$T/nope" 2>&1)" 'no such directory' "a missing directory is refused"

# With no config at all, add writes the built-ins first.
rm "$XDG_CONFIG_HOME/trails/config.json"
out=$(ws add home "$T" 2>&1)
assert_match "$out" 'wrote the built-in agents' "config created"
assert_match "$out" 'added ~ to home' "and the workspace added"
assert_eq "$(jq -r '.agents[0].name' "$XDG_CONFIG_HOME/trails/config.json")" claude "built-ins kept"
assert_eq "$(ws_of "$T")" home "~ resolves"
