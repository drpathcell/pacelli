#!/usr/bin/env bash
# Photos end to end, against real Firebase.
#
# The claim this feature makes is precise: the picture is readable on the
# devices of the household and nowhere else. That is two assertions, and they
# have to be made in the same run or neither means much:
#
#   on the device      the original is a plaintext JPEG you could open
#   in Cloud Storage   the same photo is bytes with no JPEG in them
#
# Then the third: a paired assistant asks the API for the image and gets a
# real JPEG back, because Juan asked for assistants to be able to see them.
#
# And the fourth, which is the one that keeps burn honest: deleting the
# document takes the object with it.
#
#   ./scripts/check_photo_e2e.sh [--sim UDID] [--app PATH]
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/pacelli_dd/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/PacelliApp/e2e"
FIXTURE="/tmp/pacelli_test_photo.jpg"

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

CLI_HOME="$(mktemp -d)"
cleanup() {
  if [[ -f "$CLI_HOME/.config/pacelli/credentials.json" ]]; then
    HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" disconnect-self >/dev/null 2>&1 || true
  fi
  rm -rf "$CLI_HOME"
}
trap cleanup EXIT
cli() { HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" "$@"; }

flow() { say "maestro $1"; "$MAESTRO" --device "$SIM" test "$E2E/$1" || fail "flow $1"; }

# A JPEG with structure in it, so "is this a real image" is answerable.
if [[ ! -f "$FIXTURE" ]]; then
  say "making the fixture"
  python3 - "$FIXTURE" <<'PY'
import struct, subprocess, sys, tempfile, zlib, pathlib
w = h = 640
rows = b''.join(
    b'\x00' + bytes([v for x in range(w) for v in ((240, 240, 10) if (y // 40) % 2 == 0 else (40, 40, 210))])
    for y in range(h))
def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
       + chunk(b'IDAT', zlib.compress(rows, 6)) + chunk(b'IEND', b''))
p = pathlib.Path(tempfile.mkdtemp()) / "f.png"
p.write_bytes(png)
subprocess.run(["sips", "-s", "format", "jpeg", str(p), "--out", sys.argv[1]],
               check=True, capture_output=True)
PY
fi

# ── clean device ──────────────────────────────────────────────────────
# ERASE, never uninstall: the keychain survives an uninstall and brings the
# guest account and its server-side data back with it.
say "erasing $SIM"
xcrun simctl shutdown "$SIM" 2>/dev/null || true
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b >/dev/null
xcrun simctl addmedia "$SIM" "$FIXTURE"
xcrun simctl install "$SIM" "$APP"
ok "clean simulator with a photo in its library"

# ── attach ────────────────────────────────────────────────────────────
flow flow_photo_01_attach.yaml

flow flow_photo_02_gallery.yaml

# ── the plaintext original really is on the device ────────────────────
say "the original on this device"
CONTAINER="$(xcrun simctl get_app_container "$SIM" "$BUNDLE" data)"
LOCAL="$(find "$CONTAINER/Documents/Photos" -name '*.jpg' 2>/dev/null | head -1)"
[[ -n "$LOCAL" ]] || fail "no local original under Documents/Photos"
MAGIC="$(xxd -p -l2 "$LOCAL")"
[[ "$MAGIC" == "ffd8" ]] || fail "the local original is not a JPEG (magic $MAGIC)"
ok "readable JPEG on the device: $(basename "$LOCAL"), $(wc -c < "$LOCAL") bytes"
# It is in Documents, which is what puts it in the Files app.
case "$LOCAL" in
  */Documents/Photos/*) ok "it is in Documents/Photos, so it appears in Files" ;;
  *) fail "the original is not in Documents/Photos: $LOCAL" ;;
esac

# ── pair an assistant ─────────────────────────────────────────────────
flow flow_ai_link_01_create.yaml
CODE="$(xcrun simctl pbpaste "$SIM" | tr -d '[:space:]')"
[[ "$CODE" =~ ^[0-9A-Z]{8}$ ]] || fail "no pairing code on the pasteboard (got '$CODE')"
cli link "$CODE" >/dev/null || fail "pairing refused"
ok "assistant paired"

# ── the assistant can list it ─────────────────────────────────────────
say "what the assistant sees"
LIST="$(cli photos)"
[[ -n "$LIST" ]] || fail "the assistant sees no photos"
ok "listed: $(wc -l <<<"$LIST" | tr -d ' ') photo(s)"

PHOTO_ID="$(cli photos --ids | head -1)"
[[ -n "$PHOTO_ID" ]] || fail "could not read a photo id"

# ── the assistant can SEE it ──────────────────────────────────────────
cli photo-save "$PHOTO_ID" /tmp/pacelli_assistant_view.jpg >/dev/null \
  || fail "the assistant could not fetch the image"
AMAGIC="$(xxd -p -l2 /tmp/pacelli_assistant_view.jpg)"
[[ "$AMAGIC" == "ffd8" ]] || fail "the assistant got back something that is not a JPEG ($AMAGIC)"
ok "the assistant decrypted a real JPEG ($(wc -c < /tmp/pacelli_assistant_view.jpg) bytes)"

# ── and the bytes at rest are NOT an image ────────────────────────────
say "what the server holds"
python3 - "$CLI_HOME" "$PHOTO_ID" "$ROOT" <<'PY' || exit 1
import base64, importlib.util, os, pathlib, sys, urllib.request
home, photo_id, root = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
os.environ["HOME"] = home
spec = importlib.util.spec_from_file_location("p", root / "scripts/pacelli.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
url = m.call("photoDownloadUrl", {"photoId": photo_id})["url"]
raw = urllib.request.urlopen(url).read()
pathlib.Path("/tmp/pacelli_at_rest.bin").write_bytes(raw)
if raw[:2] == b"\xff\xd8":
    sys.exit("\033[31mFAIL: the object in Cloud Storage IS a JPEG — it was never encrypted\033[0m")
if b"\xff\xd8\xff" in raw[:64]:
    sys.exit("\033[31mFAIL: JPEG magic found near the start of the stored object\033[0m")
# Prove the reader could have seen an image if there had been one.
plain = pathlib.Path("/tmp/pacelli_assistant_view.jpg").read_bytes()
assert plain[:2] == b"\xff\xd8", "the control image is not a JPEG"
print(f"\033[32mOK: {len(raw)} bytes at rest, no JPEG in them; "
      f"the same reader sees JPEG magic in the decrypted copy\033[0m")
PY

# ── deletion reaches the bucket ───────────────────────────────────────
say "deleting the photo"
python3 - "$CLI_HOME" "$PHOTO_ID" "$ROOT" <<'PY' || exit 1
import importlib.util, json, os, pathlib, sys, time, urllib.error, urllib.request
home, photo_id, root = sys.argv[1], sys.argv[2], pathlib.Path(sys.argv[3])
os.environ["HOME"] = home
spec = importlib.util.spec_from_file_location("p", root / "scripts/pacelli.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)

# Mint a URL that stays valid for fifteen minutes, THEN delete the document.
# If the object outlives it, this replay succeeds — which is exactly the
# failure that would leave orphaned photos behind after a burn.
url = m.call("photoDownloadUrl", {"photoId": photo_id})["url"]
tok = m._id_token()
cred = json.loads(pathlib.Path(home, ".config/pacelli/credentials.json").read_text())
req = urllib.request.Request(
    "https://firestore.googleapis.com/v1/projects/pacelli-35621/databases/(default)"
    f"/documents/photos/{photo_id}",
    headers={"Authorization": f"Bearer {tok}"}, method="DELETE")
urllib.request.urlopen(req).read()
print("document deleted")

for _ in range(20):
    time.sleep(3)
    try:
        urllib.request.urlopen(url).read()
    except urllib.error.HTTPError as e:
        if e.code in (403, 404):
            print("\033[32mOK: the object died with its document\033[0m")
            break
else:
    sys.exit("\033[31mFAIL: the object OUTLIVED its document — burn would orphan blobs\033[0m")
PY

printf '\n\033[32mPASS — plaintext on the device, ciphertext on the server, visible to the assistant, and gone when deleted\033[0m\n'
