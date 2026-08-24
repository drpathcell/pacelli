#!/usr/bin/env bash
# Push end-to-end check: the OTHER person adds a task, this device buzzes.
#
# Push is the one feature a single device cannot verify on its own, so this
# plays both parts: the simulator is the recipient, and a Firestore write with
# a different `created_by` is "the other person". That write goes in with admin
# credentials on purpose — it is standing in for a second member's client, and
# the Cloud Function sees exactly what it would see in real life.
#
# Asserts three things in order, because passing the first two while failing
# the third is the shape of every broken push feature:
#   1. the device registers a token at all;
#   2. with activity pushes OFF, nothing is delivered  (the opt-in is real);
#   3. with them ON, a notification actually arrives.
#
#   ./scripts/check_push_e2e.sh [--sim UDID] [--app PATH]
#
# NEGATIVE-CONTROL: remove a push string from the string catalog without
# rebuilding and the catalog check must fail; or skip the toggle tap and the
# device_tokens row must never appear. The first has been seen red.
set -euo pipefail
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "\033[31maborted at line $LINENO (exit $rc)\033[0m\n" >&2' ERR

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/dd_pacelli/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BODY="A new task was added to your household"
UN="$HOME/Library/Developer/CoreSimulator/Devices/$SIM/data/Library/UserNotifications"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --app) APP="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

[[ -d "$APP" ]]     || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]] || fail "maestro not found at $MAESTRO"

hierarchy() { "$MAESTRO" --device "$SIM" hierarchy 2>/dev/null; }

# Maestro cannot flip a SwiftUI List Toggle — see e2e/README.md. Aim at the
# switch on the trailing edge instead.
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
    a = n.get("attributes", {}); b = bounds(a)
    if not screen and b[2] > 0 and b[0] == 0: screen.append(b[2])
    if (a.get("text") or a.get("accessibilityText") or "") == want and not a.get("resource-id"):
        hit.append(b)
    for c in n.get("children", []) or []: walk(c)
walk(d)
if not hit: sys.exit(f"label not found: {want}")
x1, y1, x2, y2 = hit[0]
print(f"{screen[0] - 45},{(y1 + y2) // 2}")
')" || fail "tap_switch: could not locate \"$label\""
  cat > /tmp/tap_switch.yaml <<YAML
appId: $BUNDLE
---
- tapOn:
    point: "$point"
- waitForAnimationToEnd:
    timeout: 8000
YAML
  "$MAESTRO" --device "$SIM" test /tmp/tap_switch.yaml >/dev/null || fail "tap at $point failed"
  ok "flipped \"$label\" at $point"
}

# `|| true` is load-bearing: pipefail turns grep's "no match" (exit 1) into a
# failed pipeline and set -e kills the script with no FAIL line. Zero
# notifications is the NORMAL state at the start of this check.
delivered_count() {
  # E2E-HONESTY-WAIVER[H4]: this returns a COUNT, and zero is a real answer —
  # the three lines above say why. The caller compares the number; nothing here
  # is being proved by this line's exit status.
  grep -rl "$BODY" "$UN"/*/DeliveredNotifications.plist 2>/dev/null | wc -l | tr -d ' ' || true
}

# The push body is an APNs `loc-key`, resolved on the device against the app's
# own compiled strings. If the key is missing from the bundle, iOS does not
# fall back to showing the key — it DROPS THE NOTIFICATION ENTIRELY, with no
# error anywhere. An incremental build that skipped recompiling the string
# catalog is enough to cause it, which is exactly what happened on 2026-08-11:
# every push silently stopped arriving and the only symptom was silence.
say "0/5  The loc-keys exist in the build (a missing one silently drops pushes)"
for key in push_task_created push_member_joined; do
  found=0
  for d in "$APP"/*.lproj; do
    [[ -f "$d/Localizable.strings" ]] || continue
    if plutil -extract "$key" raw -o - "$d/Localizable.strings" >/dev/null 2>&1; then
      found=1; break
    fi
  done
  [[ "$found" == "1" ]] || fail "$key is not in the built app — every push using it will be dropped, silently. Rebuild after regenerating the string catalog."
done
ok "loc-keys present in $(ls -d "$APP"/*.lproj 2>/dev/null | wc -l | tr -d ' ') localisations"

say "1/5  Fresh install (notification authorisation back to notDetermined)"
xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install  "$SIM" "$APP"
ok "installed"

say "2/5  Launch and confirm the device registers a push token"
"$MAESTRO" --device "$SIM" test "$ROOT/PacelliApp/e2e/flow_push_optin.yaml" \
  || fail "flow_push_optin"
HH=""
for _ in $(seq 1 12); do
  HH="$(python3 "$ROOT/scripts/push_probe.py" household || true)"
  [[ -n "$HH" ]] && break
  sleep 3
done
[[ -n "$HH" ]] || fail "no device_tokens row — the device never registered for push"
ok "registered, household $HH"

say "3/5  Activity pushes are OFF by default — nothing should arrive"
BEFORE="$(delivered_count)"
python3 "$ROOT/scripts/push_probe.py" task "$HH" >/dev/null
sleep 35
[[ "$(delivered_count)" == "$BEFORE" ]] \
  || fail "a push arrived while activity notifications were off — the opt-in does nothing"
ok "nothing delivered, as intended"

say "4/5  Opt in"
tap_switch "Tell me when someone adds a task"
"$MAESTRO" --device "$SIM" test "$ROOT/PacelliApp/e2e/flow_push_grant.yaml" \
  || fail "flow_push_grant (permission not granted?)"
for _ in $(seq 1 12); do
  [[ "$(python3 "$ROOT/scripts/push_probe.py" activity)" == "True" ]] && break
  sleep 3
done
[[ "$(python3 "$ROOT/scripts/push_probe.py" activity)" == "True" ]] \
  || fail "toggled on, but the device_tokens row still says activity_push=false"
ok "activity_push=true reached the server"

say "5/5  The other person adds a task — this device should buzz"
BEFORE="$(delivered_count)"
# Backgrounded so the notification is delivered rather than presented inline.
xcrun simctl launch "$SIM" com.apple.Preferences >/dev/null
sleep 2
python3 "$ROOT/scripts/push_probe.py" task "$HH" >/dev/null
DEADLINE=$(( $(date +%s) + 90 ))
while [[ $(date +%s) -lt $DEADLINE ]]; do
  [[ "$(delivered_count)" -gt "$BEFORE" ]] && break
  sleep 5
done
[[ "$(delivered_count)" -gt "$BEFORE" ]] \
  || fail "opted in, but no notification arrived within 90s"

xcrun simctl io "$SIM" screenshot /tmp/pacelli_push_02_delivered.png >/dev/null 2>&1 || true
ok "push delivered: \"$BODY\""
printf '\n\033[32mThe other person adds a task and this device buzzes.\033[0m\n'
