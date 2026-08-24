#!/usr/bin/env bash
# Does a checklist quantity survive encryption, storage, and a cold read?
#
# `quantity` became ciphertext in 1.7.0. Unit tests prove the classifier, and
# scripts/verify_api_wire.py proves every writer calls it, but neither can prove
# the round trip: a build that encrypts on write and never decrypts on read
# passes both and shows the user a base64 blob where their quantity was.
#
#   ./scripts/check_quantity_e2e.sh [--sim UDID] [--no-build]
#
# ## KNOWN FAILURE, 2026-08-14 — step 3 does not pass yet
#
# Step 3 currently fails: after a cold launch the checklist comes back but its
# ITEMS do not, so the quantity is never on screen to assert.
#
# This is NOT caused by the quantity migration. Verified by stashing the two
# repository changes, rebuilding unmodified main (babae89) and running these
# same two flows: it fails at exactly the same step, in exactly the same way.
# What is known so far:
#
#   - the write's `await` returns and the UI shows the item, so nothing throws
#   - a 10s flush before the cold read does not help
#   - no Firestore error of any kind appears in the device log
#   - the rules for `checklist_items` are identical to those for `checklists`,
#     and the checklist itself survives the restart
#
# The shape of it — a write that resolves locally and is absent server-side,
# silently — matches a rules rejection rolled back after an optimistic local
# commit, but that is a hypothesis, not a finding. Worth chasing, because if it
# reproduces outside guest mode it means checklist items can be lost.
#
# Until it is understood, run this expecting step 3 to fail, and read a step-1
# pass as confirmation that the write path works.
#
# Two things about this script are load-bearing and were each learned the hard
# way on 2026-08-14.
#
# ## 1. Do NOT build with CODE_SIGNING_ALLOWED=NO
#
# native-ci.yml uses that flag, correctly — it only needs to know the thing
# compiles. But the artifact it produces has no entitlements, so it has no
# keychain access group, so FirebaseAuth cannot read or write the keychain:
#
#     SecItemCopyMatching (-34018) A required entitlement isn't present.
#
# The app then fails to start guest mode and shows "Couldn't start guest mode.
# Please check your connection and try again." — which reads as a network fault
# and sends you looking in entirely the wrong place. Build signed for a concrete
# simulator, as make_screenshots.sh does.
#
# ## 2. The two flows are separate, with a real sleep between them
#
# Firestore's `setData` resolves against the local cache. Killing the app one
# frame after the await can drop the write before it reaches the server, and the
# cold read then finds an empty checklist — a failure that looks exactly like
# broken decryption and is nothing of the sort. The sleep is the fix, and it has
# to live out here because Maestro has no way to express "wait for the network".
#
# NEGATIVE-CONTROL: write `quantity` raw in ChecklistsRepository and step 4 must
# fail with "not encrypted in storage"; revert `.onSubmit` on the Qty field and
# step 2 must fail to create the item. Both have been seen red — the second is
# a bug that shipped.
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
FLUSH_S="${FLUSH_S:-10}"
BUILD=1
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAESTRO="$HOME/.maestro/bin/maestro"
E2E="$ROOT/PacelliApp/e2e"
DD="/tmp/pacelli-qty-dd"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --no-build) BUILD=0; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

mkdir -p /tmp/pv
xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM" >/dev/null 2>&1 || true

if (( BUILD )); then
  say "0/3  Build (signed — see the note at the top of this file)"
  xcodebuild -project "$ROOT/PacelliApp/PacelliApp.xcodeproj" \
    -scheme PacelliApp -configuration Debug \
    -destination "id=$SIM" -derivedDataPath "$DD" \
    build > /tmp/pacelli-qty-build.log 2>&1 \
    || { tail -40 /tmp/pacelli-qty-build.log; fail "build failed"; }
  ok "built"
fi

APP="$(find "$DD/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' \
  -not -path '*PlugIns*' 2>/dev/null | head -1)"
[[ -d "$APP" ]] || fail "no .app in $DD — run without --no-build"

# ERASE the simulator — an uninstall is NOT enough, and believing otherwise cost
# the first run of this script.
#
# Uninstalling clears the app container but leaves the KEYCHAIN, and the guest
# user's Firebase Auth session lives there. The reinstalled app therefore signs
# back in as the SAME anonymous user and inherits that user's household, with
# every checklist any previous run left on the server. `tapOn: "QtyProbe"` then
# hits whichever one Firestore returns first — usually an empty leftover — and
# the cold read fails with "Peppercorns is not visible" while the write it is
# supposed to be checking worked perfectly. (Same keychain-survives-uninstall
# behaviour that stranded build 26 on "Loading your home…".)
#
# Erasing also clears the biometric-lock flag, which check_lock_e2e.sh leaves
# ENABLED — otherwise the app opens on the Face ID screen and every assertion
# here fails as "element not visible".
#
# make_screenshots.sh erases for the same reason. Do not downgrade this to an
# uninstall to save the ~20s.
say "0.5/4  Erase the simulator (see the note above — uninstall is not enough)"
xcrun simctl shutdown "$SIM" >/dev/null 2>&1 || true
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl install "$SIM" "$APP"
ok "erased, then installed $(basename "$APP") on $SIM"

say "1/4  Write an item with a quantity"
"$MAESTRO" --device "$SIM" test "$E2E/flow_qty_01_write.yaml" \
  || fail "flow_qty_01_write — could not create the item.
  If this stopped at \"New task\", check the app is not showing
  \"Couldn't start guest mode\": that is the unsigned-build trap, not the network."

say "2/4  Let the write reach the server (${FLUSH_S}s)"
sleep "$FLUSH_S"
ok "flushed"

say "3/4  Cold read — a fresh process, straight out of Firestore"
"$MAESTRO" --device "$SIM" test "$E2E/flow_qty_02_coldread.yaml" \
  || fail "flow_qty_02_coldread — the quantity did not survive the round trip.
  Either the write stored something the read cannot decrypt, or the read is
  not using PacelliCrypto.readMigrating. Compare /tmp/pv/qty_01_written.png
  with /tmp/pv/qty_02_after_cold_read.png."

ok "a quantity written encrypted comes back as what the user typed"

# Everything above proves the ROUND TRIP, which an app that skipped encryption
# on both sides would also pass. This step is the other claim: that what sits in
# storage is not the user's value. It reads the simulator's Firestore
# persistence — a reader that is not the app — and refuses to report a pass
# unless it first proves it could have seen plaintext.
say "4/4  At rest — is the stored value actually ciphertext?"
"$ROOT/scripts/check_quantity_at_rest.py" --sim "$SIM" \
  || fail "the quantity is not encrypted in storage (see above)"

printf '\n\033[32mThe quantity round-trips, AND it is not recoverable from storage.\033[0m\n'
