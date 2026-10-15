#!/bin/sh
# Runs the integration tests: every test/t-*.sh, or the ones named on the command line
# (`test/run.sh launch` runs t-launch.sh). Each test is its own process on its own tmux
# server, in a throwaway HOME, with the stub agent and stub fzf from test/bin on PATH
# (see test/lib.sh); one test can't see another's sessions, records or config.
#
# A test passes when it exits 0. Its output is kept and shown only when it fails, so a
# green run reads as one line per test.
set -u

cd "$(dirname "$0")/.." || exit 1
REPO=$(pwd -P)
export REPO

if [ $# -gt 0 ]; then
  tests=
  for t in "$@"; do
    tests="$tests test/t-${t#t-}"
    tests="${tests%.sh}.sh"
  done
else
  tests=$(ls test/t-*.sh)
fi

pass=0 fail=0 failed=
for t in $tests; do
  name=$(basename "$t" .sh)
  name=${name#t-}
  out=$(sh "$t" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "ok    $name"
    pass=$((pass + 1))
  else
    echo "FAIL  $name"
    printf '%s\n' "$out" | sed 's/^/      /'
    fail=$((fail + 1))
    failed="$failed $name"
  fi
done

echo
echo "$pass passed, $fail failed${failed:+:$failed}"
[ "$fail" -eq 0 ]
