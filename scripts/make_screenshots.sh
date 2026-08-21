#!/usr/bin/env bash
# Regenerate the App Store screenshot set, end to end, from nothing.
#
# The set that shipped with 1.5.0 was produced by hand, which is why 1.6.0
# nearly went out advertising a Checklists screen that no longer looked like
# that. This makes the whole thing one command, so a stale set is a choice
# rather than an accident:
#
#   erase sim -> build -> install -> freeze the status bar -> drive the app
#   with Maestro -> collect -> check every PNG is a size Apple accepts
#
# Upload is deliberately NOT here. Capture is safe and repeatable; upload
# mutates a live App Store listing and has its own guard rails:
#
#   ./scripts/make_screenshots.sh
#   ./scripts/asc.py screenshots-list 1.6.0          # what is up there now
#   ./scripts/asc.py screenshots-sync 1.6.0          # replace it
#
# The simulator MUST be a 6.9" iPhone (1320x2868). A 6.3" device produces
# perfectly good-looking PNGs that Apple rejects several minutes later, at
# asset-validation time, with an error that does not mention the size.
set -euo pipefail

DEVICE="${DEVICE:-iPhone 17 Pro Max}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAESTRO="$HOME/.maestro/bin/maestro"
E2E="$ROOT/PacelliApp/e2e"
OUT="${OUT:-$ROOT/fastlane/metadata/ios/en-GB/screenshots}"
DD="${DD:-/tmp/pacelli-shots-dd}"
SCHEME="PacelliApp"
BUNDLE="com.pacelli.pacelli"
KEEP_SIM="${KEEP_SIM:-0}"

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

[[ -x "$MAESTRO" ]] || fail "maestro not found at $MAESTRO"

# Maestro is a JVM app and dies with "Unable to locate a Java Runtime" if
# JAVA_HOME is unset. Homebrew's openjdk is keg-only: it is installed but
# deliberately not linked into /Library/Java, so /usr/libexec/java_home
# cannot see it and neither can Maestro.
if [[ -z "${JAVA_HOME:-}" ]] && ! /usr/libexec/java_home >/dev/null 2>&1; then
  for candidate in /opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home \
                   /usr/local/opt/openjdk/libexec/openjdk.jdk/Contents/Home; do
    [[ -x "$candidate/bin/java" ]] && { export JAVA_HOME="$candidate"; break; }
  done
fi
[[ -n "${JAVA_HOME:-}" ]] && export PATH="$JAVA_HOME/bin:$PATH"
java -version >/dev/null 2>&1 || fail "no Java runtime; Maestro needs one (brew install openjdk)"

SIM="$(xcrun simctl list devices available -j \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for rt in sorted(d, reverse=True):
    for dev in d[rt]:
        if dev['name'] == '''$DEVICE''':
            print(dev['udid']); sys.exit(0)
sys.exit(1)")" || fail "no available simulator named '$DEVICE'"
say "simulator $DEVICE ($SIM)"

# A dirty simulator is the single biggest source of bad screenshots: leftover
# tasks from the last run, an already-signed-in account, a half-finished
# checklist. Erase, always.
say "erasing"
xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b >/dev/null

say "building"
xcodebuild -project "$ROOT/PacelliApp/PacelliApp.xcodeproj" \
  -scheme "$SCHEME" -configuration Debug \
  -destination "id=$SIM" -derivedDataPath "$DD" \
  build > /tmp/pacelli-shots-build.log 2>&1 \
  || { tail -40 /tmp/pacelli-shots-build.log; fail "build failed"; }
APP="$DD/Build/Products/Debug-iphonesimulator/Pacelli.app"
[[ -d "$APP" ]] || APP="$(find "$DD/Build/Products" -maxdepth 2 -name '*.app' \
  -not -path '*PlugIns*' | head -1)"
[[ -d "$APP" ]] || fail "no .app in $DD/Build/Products"
ok "built $(basename "$APP")"

xcrun simctl install "$SIM" "$APP"

# `--args -CurrentDeviceUDID` is read at LAUNCH and ignored by an already
# running Simulator. Leaving it at that is how the Face ID menu ends up
# toggling biometrics on whatever device the front window happens to show —
# which on a machine with several booted simulators is not this one. Restart
# it so the front window is definitely $SIM.
killall Simulator >/dev/null 2>&1 || true
sleep 1
open -a Simulator --args -CurrentDeviceUDID "$SIM"
sleep 5
osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
sleep 1

# The Face ID row in Settings is hidden outright when the device cannot
# evaluate a biometric policy, and a freshly erased simulator has neither a
# face nor a passcode. Without this the capture flow fails looking for a row
# that the app is correctly refusing to draw. There is no simctl verb for it —
# enrolment is a Features menu item, same as in check_lock_e2e.sh.
face_menu() {
  osascript -e "tell application \"System Events\" to tell process \"Simulator\" \
    to click menu item \"$1\" of menu 1 of menu item \"Face ID\" of menu 1 of menu bar item \"Features\" of menu bar 1" \
    >/dev/null 2>&1
}
enrolled() {
  osascript -e 'tell application "System Events" to tell process "Simulator" to return value of attribute "AXMenuItemMarkChar" of menu item "Enrolled" of menu 1 of menu item "Face ID" of menu 1 of menu bar item "Features" of menu bar 1' 2>/dev/null
}
[[ "$(enrolled)" == "✓" ]] || { face_menu "Enrolled"; sleep 1; }
[[ "$(enrolled)" == "✓" ]] || fail "could not enrol Face ID — the Settings shot needs it.
  Checked, in order:
    - is Simulator showing THIS device? (several booted sims => wrong menu target)
    - Automation access: System Settings > Privacy & Security > Automation
    - the menu path itself: Features > Face ID > Enrolled, reached as
      'menu 1 of menu bar item \"Features\"'. The 'menu \"Features\"' form
      raises -1719 and was silently swallowed here until 2026-08-21."
ok "Face ID enrolled"

# 9:41 and a full battery, the same as every other app on the store. Without
# this the shots carry the real clock and whatever battery the Mac reports,
# which reads as amateur next to everything around it.
xcrun simctl status_bar "$SIM" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularMode active --cellularBars 4 --dataNetwork wifi

rm -f /tmp/asc_*.png

say "driving the app"
MAESTRO_DRIVER_STARTUP_TIMEOUT=120000 \
  "$MAESTRO" --device "$SIM" test "$E2E/flow_asc_screenshots.yaml" \
  || fail "capture flow failed — the app changed under the flow; fix $E2E/flow_asc_screenshots.yaml"

say "collecting"
shopt -s nullglob
shots=(/tmp/asc_*.png)
(( ${#shots[@]} )) || fail "the flow reported success but wrote no PNGs"
mkdir -p "$OUT"
rm -f "$OUT"/*.png
for f in "${shots[@]}"; do cp "$f" "$OUT/"; done

# Apple validates dimensions server side, minutes after accepting the upload.
# Catching a wrong size here costs a second; catching it there costs a
# rejected submission.
python3 - "$OUT" <<'PY'
import sys, pathlib
ALLOWED = {(1290, 2796), (1320, 2868)}
bad = []
files = sorted(pathlib.Path(sys.argv[1]).glob("*.png"))
if not files:
    sys.exit("no PNGs collected")
for f in files:
    raw = f.read_bytes()
    w = int.from_bytes(raw[16:20], "big")
    h = int.from_bytes(raw[20:24], "big")
    flag = "" if (w, h) in ALLOWED else "  <-- WRONG SIZE"
    print(f"  {f.name:<30} {w}x{h}  {f.stat().st_size//1024} KB{flag}")
    if (w, h) not in ALLOWED:
        bad.append(f.name)
if bad:
    sys.exit(f"{len(bad)} screenshot(s) are not a size Apple accepts: {bad}")
PY

if [[ "$KEEP_SIM" != "1" ]]; then
  xcrun simctl status_bar "$SIM" clear >/dev/null 2>&1 || true
  xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
fi

ok "${#shots[@]} screenshot(s) in $OUT"
echo
echo "Look at them before uploading. Then:"
echo "  ./scripts/asc.py screenshots-sync <version>"
