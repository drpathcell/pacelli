#!/usr/bin/env bash
# Phase C: does the notification actually say "Buy milk"?
#
# Phase B proved a push arrives. This proves the part that makes it worth
# having — that the Notification Service Extension opens the encrypted title on
# device and rewrites the body before iOS draws it.
#
# It plays both sides. The simulator is the recipient; the script is "the other
# person", and it encrypts the title with the household's REAL key — unwrapped
# from `household_keys` by deriving the user key from the uid, exactly as a
# client would. Nothing here is a stand-in: if the derivation or the wire
# format drifted, this stops passing.
#
# Asserts BOTH directions, because only one of them is a feature:
#   1. a title encrypted with the household key  -> body is the plaintext title
#   2. a title that cannot be opened             -> body stays generic
#
# The second is the safety property. An extension that shows a blank, a crash
# or a raw ciphertext on failure is worse than no extension at all.
#
#   ./scripts/check_push_decrypt_e2e.sh [--sim UDID] [--app PATH]
#
# NOTE: verifies the DECRYPTION. It cannot verify keychain access-group
# ISOLATION — the simulator does not enforce entitlements. That needs a device.
set -euo pipefail
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "\033[31maborted at line $LINENO (exit $rc)\033[0m\n" >&2' ERR

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/dd_pacelli/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
GENERIC="A new task was added to your household"
TITLE="Buy milk"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

[[ -d "$APP" ]] || fail "app bundle not found: $APP"
[[ -d "$APP/PlugIns/PacelliNotificationService.appex" ]] \
  || fail "the build has no notification extension embedded — nothing to test"

# Reads the body iOS would DISPLAY, out of the archived notification, rather
# than grepping the file. Both strings are present in a delivered payload —
# the generic one as the original request — so grep alone would pass on a
# broken extension.
displayed_body() {
  local f
  f="$(grep -rl "task_created" "$UN"/*/DeliveredNotifications.plist 2>/dev/null | head -1 || true)"
  [[ -n "$f" ]] || return 1
  python3 - "$f" <<'PY'
import plistlib, sys
objs = plistlib.loads(open(sys.argv[1], "rb").read()).get("$objects", [])
for o in objs:
    if isinstance(o, dict):
        for k, v in o.items():
            if k == "body" and isinstance(v, plistlib.UID):
                print(objs[v.data]); raise SystemExit
PY
}

clear_delivered() { rm -f "$UN"/*/DeliveredNotifications.plist 2>/dev/null || true; }

await_body() {
  local deadline=$(( $(date +%s) + 120 )) body
  while [[ $(date +%s) -lt $deadline ]]; do
    body="$(displayed_body || true)"
    [[ -n "$body" ]] && { echo "$body"; return 0; }
    sleep 5
  done
  return 1
}

WHO="$(python3 "$ROOT/scripts/push_probe.py" whoami)" \
  || fail "no registered device — run scripts/check_push_e2e.sh first"
USER_ID="${WHO%% *}"; HH="${WHO##* }"
ok "recipient $USER_ID in household $HH"

[[ "$(python3 "$ROOT/scripts/push_probe.py" activity)" == "True" ]] \
  || fail "activity pushes are off for this device — run check_push_e2e.sh first"

say "1/2  A title encrypted with the household's real key"
clear_delivered
xcrun simctl launch "$SIM" com.apple.Preferences >/dev/null; sleep 2
python3 "$ROOT/scripts/push_probe.py" encrypted-task "$HH" "$USER_ID" "$TITLE" >/dev/null
BODY="$(await_body)" || fail "no notification arrived within 120s"
[[ "$BODY" == "$TITLE" ]] \
  || fail "body is \"$BODY\", expected \"$TITLE\" — the extension did not decrypt"
ok "notification says \"$BODY\""

say "2/2  A title this household cannot open — must stay generic"
clear_delivered
xcrun simctl launch "$SIM" com.apple.Preferences >/dev/null; sleep 2
python3 "$ROOT/scripts/push_probe.py" task "$HH" >/dev/null
BODY="$(await_body)" || fail "no notification arrived within 120s"
[[ "$BODY" == "$GENERIC" ]] \
  || fail "body is \"$BODY\" — a failed decrypt must fall back to the generic text"
ok "fell back to \"$BODY\""

printf '\n\033[32mThe title is decrypted on device, and failure degrades safely.\033[0m\n'
