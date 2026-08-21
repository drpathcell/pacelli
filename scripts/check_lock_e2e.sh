#!/usr/bin/env bash
# Does the Face ID lock actually lock?
#
# The lock is the only thing standing between someone holding your unlocked
# phone and the household, so "it compiles" is not evidence. This drives the
# real state machine on a simulator with Face ID enrolled, and asserts the two
# properties that matter in opposite directions:
#
#   1. background -> foreground  =>  content hidden, "Pacelli is locked"
#   2. matching face             =>  content back
#
# The first is the security property. A lock that only ever appears is useless;
# a lock that never lets you back in is worse. Both are asserted, and the
# NON-matching face is asserted in between, because a lock that opens for any
# face is exactly as good as no lock and looks identical in a screenshot.
#
#   ./scripts/check_lock_e2e.sh [--sim UDID]
#
# NOTE: this proves the STATE MACHINE. It cannot prove Secure Enclave
# behaviour — the simulator's Face ID is a menu item, not hardware. Real
# biometric matching needs a device and a face.
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAESTRO="$HOME/.maestro/bin/maestro"
E2E="$ROOT/PacelliApp/e2e"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

# Simulator Face ID lives in the Features menu; there is no simctl verb for it.
face() {
  osascript -e "tell application \"System Events\" to tell process \"Simulator\" \
    to click menu item \"$1\" of menu 1 of menu item \"Face ID\" of menu 1 of menu bar item \"Features\" of menu bar 1" \
    >/dev/null 2>&1
}
# One line on purpose: inside single quotes bash keeps a backslash-newline
# literally, and AppleScript's continuation character is not a backslash.
enrolled() {
  osascript -e 'tell application "System Events" to tell process "Simulator" to return value of attribute "AXMenuItemMarkChar" of menu item "Enrolled" of menu 1 of menu item "Face ID" of menu 1 of menu bar item "Features" of menu bar 1' 2>/dev/null
}

open -a Simulator; sleep 2
[[ "$(enrolled)" == "✓" ]] || {
  face "Enrolled"; sleep 1
  [[ "$(enrolled)" == "✓" ]] || fail "could not enrol Face ID in the simulator"
}
ok "Face ID enrolled in the simulator"

# Read the flag out of the app's OWN container.
#
# NOT `simctl spawn defaults read`: that resolves a simulator-scope domain
# which is a DIFFERENT store from the app sandbox, and it survives
# `simctl uninstall`. Reading it will happily report a lock that the app does
# not have, and writing it contaminates every later run. Learned the slow way,
# 2026-08-13.
lock_flag() {
  local d
  d="$(xcrun simctl get_app_container "$SIM" com.pacelli.pacelli data 2>/dev/null)" || return 1
  plutil -extract "pacelli.biometricLock.enabled" raw \
    "$d/Library/Preferences/com.pacelli.pacelli.plist" 2>/dev/null || echo "unset"
}

say "1/3  The toggle exists and turns on"
"$MAESTRO" test -e SIM="$SIM" "$E2E/flow_lock_01_enable.yaml" \
  || fail "flow_lock_01_enable — toggle missing or would not turn on"

# Maestro reports COMPLETED for a tap that landed on nothing, so the flow
# passing is not evidence the lock is on. Check the state it was supposed to
# change. Without this the whole script green-lights a lock that is off.
sleep 2
if [[ "$(lock_flag)" != "true" ]]; then
  fail "the toggle tap did not enable the lock (flag=$(lock_flag)).
  Almost certainly the tap missed the switch: it is a fixed percentage point,
  and the row moves if the Settings list scrolls differently. Tapping the row
  by accessibility id does NOT work — SwiftUI only flips a Toggle when the
  switch itself is hit, and Maestro taps the element's centre, i.e. the label."
fi
ok "lock enabled, and the stored flag says so"

say "2/3  Backgrounding locks it, and a wrong face keeps it locked"
# Foregrounding another app is what a real user does; simctl terminate would
# instead test a cold launch, which is a different path.
xcrun simctl launch "$SIM" com.apple.Preferences >/dev/null
sleep 3
xcrun simctl launch "$SIM" com.pacelli.pacelli >/dev/null
sleep 3
# Refuse the automatic attempt. Returning to the foreground auto-authenticates
# by design, so a matching face here would unlock before anything could be
# asserted — the lock screen would be correct and invisible. Refusing it is
# what holds the screen still, AND asserts the security property in one go: if
# a rejected face left the household on screen, this fails.
face "Non-matching Face"; sleep 3
"$MAESTRO" test -e SIM="$SIM" "$E2E/flow_lock_02_locked.yaml" \
  || fail "flow_lock_02_locked — household visible after backgrounding + a REFUSED face"
ok "locked after backgrounding; a refused face does not get in"

say "3/3  The right face gets back in"
face "Matching Face"; sleep 3
"$MAESTRO" test -e SIM="$SIM" "$E2E/flow_lock_03_unlocked.yaml" \
  || fail "flow_lock_03_unlocked — a matching face did not let us back in"
ok "matching face unlocked"

printf '\n\033[32mThe lock locks, refuses the wrong face, and opens for the right one.\033[0m\n'
printf '\033[2mState machine only — Secure Enclave behaviour needs real hardware.\033[0m\n'
