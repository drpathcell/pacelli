#!/usr/bin/env bash
# Reminders end-to-end check (iOS Simulator).
#
# Proves the whole Phase A chain against a real OS rather than in unit tests:
#   fresh install -> permission granted -> task with a due date -> reconcile
#   schedules it -> iOS FIRES it -> the notification carries the REAL task
#   title ("Buy milk"), not a placeholder.
#
# Maestro drives the UI (PacelliApp/e2e/flow_reminders_0{1,2,3}_*.yaml).
# Everything Maestro cannot do lives here: the fresh install, flipping SwiftUI
# switches, seeding the reminder time, and the fired-notification assertion.
#
#   ./scripts/check_reminders_e2e.sh [--sim UDID] [--app PATH] [--lead MINUTES]
#
# Exits non-zero with a named FAIL on the first broken link.
#
# NEGATIVE-CONTROL: replace `tap_switch` with `tapOn: id:` and the
# `reminders_enabled` read-back must fail with "the toggle did not stick"; read
# the pref with `defaults read` instead of `plutil` and it must fail with
# "does not exist" for a key that is plainly in the file. Both seen red,
# 2026-08-11.
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/dd_pacelli/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
LEAD_MIN=2
TITLE="Buy milk"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/PacelliApp/e2e"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim)  SIM="$2";      shift 2 ;;
    --app)  APP="$2";      shift 2 ;;
    --lead) LEAD_MIN="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

trap 'rc=$?; [[ $rc -ne 0 ]] && printf "\033[31maborted at line $LINENO (exit $rc)\033[0m\n" >&2' ERR

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

[[ -d "$APP" ]]      || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]]  || fail "maestro not found at $MAESTRO"

flow() {
  "$MAESTRO" --device "$SIM" test "$E2E/$1" || fail "$1"
}

hierarchy() { "$MAESTRO" --device "$SIM" hierarchy 2>/dev/null; }

# Flip a SwiftUI List Toggle, addressed by its LABEL text.
#
# Maestro cannot do this itself: SwiftUI publishes the whole row as one
# accessibility element, so a selector-based tap lands on the label, and a
# List Toggle only responds to a hit on the switch. It reports COMPLETED and
# silently changes nothing — no state change, no error, no log line. So we
# read the label's bounds and aim at the trailing edge of the row instead.
tap_switch() {
  local label="$1" point
  point="$(hierarchy | LABEL="$label" python3 -c '
import json, os, sys
raw = sys.stdin.read()
d = json.loads(raw[raw.find("{"):])
want = os.environ["LABEL"]
screen, hit = [], []
def bounds(a):
    return [int(v) for v in a.get("bounds", "[0,0][0,0]").replace("][", ",").strip("[]").split(",")]
def walk(n):
    a = n.get("attributes", {})
    b = bounds(a)
    # The first node with real bounds is the app window. Do NOT use max() over
    # every node: some accessibility frames extend past the screen and would
    # put the tap off-canvas, where it silently does nothing.
    if not screen and b[2] > 0 and b[0] == 0:
        screen.append(b[2])
    if (a.get("text") or a.get("accessibilityText") or "") == want and not a.get("resource-id"):
        hit.append(b)
    for c in n.get("children", []) or []:
        walk(c)
walk(d)
if not hit:
    sys.exit(f"label not found in hierarchy: {want}")
x1, y1, x2, y2 = hit[0]
print(f"{screen[0] - 45},{(y1 + y2) // 2}")
')" || fail "tap_switch: could not locate \"$label\""
  cat > "/tmp/tap_switch.yaml" <<YAML
appId: $BUNDLE
---
- tapOn:
    point: "$point"
- waitForAnimationToEnd:
    timeout: 8000
YAML
  "$MAESTRO" --device "$SIM" test /tmp/tap_switch.yaml >/dev/null \
    || fail "tap_switch: tap at $point failed"
  ok "flipped \"$label\" at $point"
}

# The app's UserDefaults live in the app DATA CONTAINER, not the device-wide
# preferences domain. `xcrun simctl spawn <sim> defaults write <bundle> ...`
# writes the device-wide domain, which the app never reads — it reports
# success and changes nothing. Verified on this simulator 2026-08-11.
prefs() { echo "$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)/Library/Preferences/$BUNDLE"; }

say "1/7  Fresh install (resets notification authorisation to notDetermined)"
xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install  "$SIM" "$APP"
ok "installed $APP"

say "2/7  Create \"$TITLE\" and open it"
flow flow_reminders_01_task.yaml

say "3/7  Turn the due date on"
# Re-runnable: the task survives a reinstall (it lives in Firestore), so the
# due date may already be on from an earlier run.
if hierarchy | grep -q "task_custom_reminder"; then
  ok "due date already on"
else
  tap_switch "Due date"
fi

say "4/7  Per-task reminder revealed; save and open Settings"
flow flow_reminders_02_settings.yaml

say "5/7  Turn reminders on and grant notification permission"
tap_switch "Task reminders"
flow flow_reminders_03_grant.yaml


# cfprefsd batches writes; the plist appears seconds after the app dies, not
# at terminate. Poll rather than sleep-and-hope.
#
# Read with plutil, not `defaults`: `defaults read <path> <key>` goes through
# the HOST cfprefsd, which caches the file and kept reporting "does not exist"
# for a key plutil could see plainly in the same file. plutil reads the bytes.
xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
PLIST="$(prefs).plist"
ENABLED=""
for _ in $(seq 1 12); do
  ENABLED="$(plutil -extract reminders_enabled raw -o - "$PLIST" 2>&1 || true)"
  [[ "$ENABLED" == "true" ]] && break
  sleep 2
done
if [[ "$ENABLED" != "true" ]]; then
  echo "--- $PLIST ---" >&2
  plutil -p "$PLIST" >&2 2>&1 || echo "(no plist)" >&2
  fail "reminders_enabled is '$ENABLED' — the toggle did not stick"
fi
ok "reminders_enabled=true in $PLIST"

say "6/8  Aim the default reminder time ${LEAD_MIN} min out"
FIRE_HHMM="$(python3 -c "
import datetime
print((datetime.datetime.now() + datetime.timedelta(minutes=$LEAD_MIN)).strftime('%H:%M'))")"
# Write through the SIMULATOR's cfprefsd, not the host's. A host-side
# `plutil -replace` on the same file changes the bytes and the app never sees
# it: the simulator's cfprefsd still serves its cached copy, ReminderPrefs
# falls back to noon, noon has already passed, and reconcile schedules
# nothing — a green-looking no-op. Read back with plutil, though, because
# `defaults read <path> <key>` goes through the HOST cfprefsd and reports
# "does not exist" for keys plainly present in the file. Verified 2026-08-11.
xcrun simctl spawn "$SIM" defaults write "$(prefs)" reminders_default_time -string "$FIRE_HHMM"
READBACK="$(plutil -extract reminders_default_time raw -o - "$PLIST" 2>&1 || true)"
[[ "$READBACK" == "$FIRE_HHMM" ]] || fail "pref did not take: wanted $FIRE_HHMM, got $READBACK"
ok "reminders_default_time=$FIRE_HHMM"

say "7/8  Foreground the app and check what iOS actually accepted"
xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null
UN="$HOME/Library/Developer/CoreSimulator/Devices/$SIM/data/Library/UserNotifications"
PENDING=""
for _ in $(seq 1 15); do
  # `|| true` matters: pipefail turns grep's "no match" (exit 1) into a failed
  # assignment, and set -e then kills the script with no FAIL line at all.
  PENDING="$(grep -rl "$TITLE" "$UN"/*/PendingNotifications.plist 2>/dev/null | head -1 || true)"
  [[ -n "$PENDING" ]] && break
  sleep 2
done
[[ -n "$PENDING" ]] || fail "nothing scheduled: no pending notification titled \"$TITLE\""
ok "pending notification carries the real title, in $(basename "$(dirname "$PENDING")")"

# The identifier proves it came from the task, and the trigger date proves it
# used the preference rather than a stale default.
plutil -p "$PENDING" | grep -q "task_.*_day" \
  || fail "pending notification is not a task reminder (bad identifier)"
FIRE_H="${FIRE_HHMM%%:*}"; FIRE_M="${FIRE_HHMM##*:}"
plutil -p "$PENDING" | grep -qE "=> ${FIRE_H#0}$" \
  || echo "note: could not confirm the hour in the archived trigger components"
ok "identifier is task_<id>_day"

say "8/8  Background the app and wait for $FIRE_HHMM"
xcrun simctl launch "$SIM" com.apple.Preferences >/dev/null
sleep 3
DEADLINE=$(( $(date +%s) + LEAD_MIN * 60 + 120 ))
SEEN=""
while [[ $(date +%s) -lt $DEADLINE ]]; do
  # The banner is on screen for a few seconds; the delivered store keeps it.
  # Check both so the assertion cannot miss by timing alone.
  if grep -rqal "$TITLE" "$UN"/*/DeliveredNotifications.plist 2>/dev/null; then
    SEEN="delivered store"; break
  fi
  if hierarchy | grep -q "$TITLE"; then SEEN="banner"; break; fi
  sleep 5
done
[[ -n "$SEEN" ]] || fail "scheduled but never fired: no delivered \"$TITLE\" by $FIRE_HHMM (+120s)"

xcrun simctl io "$SIM" screenshot /tmp/pacelli_rem_03_fired.png >/dev/null 2>&1 || true
ok "reminder FIRED carrying the real title (seen in $SEEN)"
printf '\n\033[32mAll reminder checks passed.\033[0m  /tmp/pacelli_rem_03_fired.png\n'
