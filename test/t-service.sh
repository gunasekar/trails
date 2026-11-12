#!/bin/sh
# With the trails service installed and no tmux server up, trails has the service start the
# server rather than starting it itself, under the terminal it runs in, where a Force Quit of
# that terminal would end it with every agent. And should the service not come, trails starts
# the server anyway and says what that costs.
. "$REPO/test/lib.sh"
t_setup
# A service manager of the test's own: launchctl on macOS, systemctl elsewhere, either of which
# starts `trails boot` in the background, as the real one would, and notes how it was asked.
SVC=$T/svc
mkdir -p "$SVC"
cat >"$SVC/manager" <<EOF
#!/bin/sh
echo "\$*" >>"$T/manager.calls"
[ -z "\${SVC_FAIL:-}" ] || exit 1
TRAILS_BOOT_ENV=1 nohup "$TRAILS" boot >>"$T/boot.log" 2>&1 </dev/null &
EOF
chmod +x "$SVC/manager"
ln -s manager "$SVC/launchctl"
ln -s manager "$SVC/systemctl"
PATH=$SVC:$PATH
export PATH

trails_bg new payments
wait_for 5 screen_has default/payments 'agent id=' || fail "payments never started"
id=$(tmux display-message -pt default/payments '#{@trails_id}')
tmux kill-server
sleep 0.3

# A restore from a terminal, with no server: the service starts it, and the trail comes back in
# the service's server, under trails boot.
out=$(TRAILS_SERVICE=test.trails "$TRAILS" restore 2>&1)
assert_match "$out" "restored default/payments" "the trail came back"
assert_eq "$(tmux display-message -pt '=default/payments:' '#{@trails_id}' 2>/dev/null)" "$id" "as itself"
case $(uname -s) in
  Darwin) assert_match "$(cat "$T/manager.calls")" "^kickstart gui/$(id -u)/test.trails$" "launchd was asked to start the service" ;;
  *) assert_match "$(cat "$T/manager.calls")" "^--user start test.trails$" "systemd was asked to start the service" ;;
esac
spid=$(tmux display-message -p '#{pid}')
p=$(ps -o ppid= -p "$spid" | tr -d ' ')
case $(ps -o command= -p "$p") in
  *trails\ boot*) ;;
  *) fail "the server is not under trails boot: $(ps -o command= -p "$p")" ;;
esac
assert_match "$(cat "$T/boot.log")" "starting the tmux server" "boot started it"

# The service refusing: the server starts here, as before the service, and trails says so.
tmux kill-server
# [b]oot: the pattern must not match the sh -c running it, which the procps pgrep (Linux) does
# not leave out the way the BSD one (macOS) leaves out its ancestors.
wait_for 5 sh -c "! pgrep -f '$TRAILS [b]oot' >/dev/null" || fail "boot outlived its server"
out=$(SVC_FAIL=1 TRAILS_SERVICE=test.trails "$TRAILS" restore 2>&1)
assert_match "$out" "restored default/payments" "the trail came back without the service"
assert_match "$out" "starting tmux here instead" "and trails said where the server is"

# No service installed: nothing asked of any manager.
tmux kill-server
rm -f "$T/manager.calls"
"$TRAILS" restore >/dev/null 2>&1
has_session default/payments || fail "no restore without a service"
assert_no_file "$T/manager.calls" "no manager was asked without a service"
