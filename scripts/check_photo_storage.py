#!/usr/bin/env python3
"""Proves the server half of the photo pipeline against the real project.

No client can reach the bucket — `storage.rules` denies every path — so the
only way bytes get in or out is a signed URL minted by a Cloud Function that
has already checked the caller's household. This walks that whole path and then
kills it:

    create the document        -> the Firestore rule accepts a member
    photoUploadUrl + PUT       -> a member can put bytes there
    photoDownloadUrl + GET     -> the same bytes come back
    a stranger asks for a URL  -> refused
    delete the document        -> the OBJECT dies with it

The last one is the important one. Burn-all-data walks Firestore collections
and knows nothing about Cloud Storage; it stays correct only because deleting a
photo document deletes its object through the `onPhotoDeleted` trigger. A blob
that outlives its document is invisible until somebody goes looking, so it gets
proven here with a download URL minted BEFORE the delete and replayed after it.

    ./scripts/check_photo_storage.py --cred ~/.config/pacelli/credentials.json

`check_ai_link_e2e.sh` mints a credential in about two minutes.

NEGATIVE-CONTROL: drop the `onPhotoDeleted` trigger and the replay after
delete must still return the bytes, failing the run. The download URL is
minted BEFORE the delete precisely so this control is available: a blob that
outlives its document is otherwise invisible.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import plistlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

PROJECT = "pacelli-35621"
API = f"https://us-central1-{PROJECT}.cloudfunctions.net"
FS = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
ROOT = pathlib.Path(__file__).resolve().parent.parent

GREEN, RED, RESET = "\033[32m", "\033[31m", "\033[0m"
failures = 0


def ok(msg: str) -> None:
    print(f"{GREEN}OK{RESET}   {msg}")


def bad(msg: str) -> None:
    global failures
    failures += 1
    print(f"{RED}FAIL{RESET} {msg}")


def api_key() -> str:
    return plistlib.load(
        (ROOT / "PacelliApp/Resources/GoogleService-Info.plist").open("rb"))["API_KEY"]


def http(url: str, *, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def post_json(url: str, payload: dict, token: str | None = None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    code, raw = http(url, data=json.dumps(payload).encode(), headers=headers)
    try:
        return code, json.loads(raw or b"{}")
    except Exception:
        return code, {"raw": raw[:300].decode(errors="replace")}


def fresh_token(cred: dict) -> str:
    code, d = post_json(
        f"https://securetoken.googleapis.com/v1/token?key={api_key()}",
        {"grant_type": "refresh_token", "refresh_token": cred["refresh_token"]})
    return d["id_token"]


def anonymous_token() -> str:
    code, d = post_json(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signUp?key={api_key()}",
        {"returnSecureToken": True})
    return d["idToken"]


def call(fn: str, payload: dict, token: str):
    code, d = post_json(f"{API}/{fn}", payload, token)
    return code, d


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--cred", default=str(pathlib.Path.home()
                                          / ".config/pacelli/credentials.json"))
    a = ap.parse_args()

    cred_path = pathlib.Path(a.cred)
    if not cred_path.exists():
        sys.exit(f"no credential at {cred_path} — run check_ai_link_e2e.sh to mint one")
    cred = json.loads(cred_path.read_text())
    hid, uid = cred["household_id"], cred["assistant_uid"]
    member = fresh_token(cred)
    stranger = anonymous_token()

    photo_id = f"chk{int(time.time())}"
    # Not a real envelope — the household key never leaves the devices, so this
    # script cannot make one. Byte fidelity is what is being proven here; that
    # the app's real ciphertext opens again is proven by the simulator E2E.
    blob = bytes(range(256)) * 64  # 16 KiB of definitely-not-an-image

    print(f"\nhousehold {hid}\nphoto     {photo_id}\n")

    # ── the Firestore rule ───────────────────────────────────────────
    doc = {"fields": {
        "id": {"stringValue": photo_id},
        "household_id": {"stringValue": hid},
        "subject_type": {"stringValue": "task"},
        "subject_id": {"stringValue": "check-only"},
        "upload_state": {"stringValue": "pending"},
        "created_by": {"stringValue": uid},
        "created_at": {"stringValue": time.strftime("%Y-%m-%dT%H:%M:%S.000000")},
    }}
    code, out = post_json(f"{FS}/photos?documentId={photo_id}", doc, member)
    (ok if code == 200 else bad)(
        f"a member creates the photo document (HTTP {code})"
        + ("" if code == 200 else f" {json.dumps(out)[:180]}"))
    if code != 200:
        return 1

    # ── upload ───────────────────────────────────────────────────────
    code, out = call("photoUploadUrl", {"photoId": photo_id}, member)
    if code != 200 or not out.get("success"):
        bad(f"photoUploadUrl (HTTP {code}) {json.dumps(out)[:200]}")
        return 1
    ok("photoUploadUrl mints a signed URL")
    put_url = out["data"]["url"]

    code, _ = http(put_url, data=blob, method="PUT",
                   headers={"Content-Type": out["data"]["contentType"]})
    (ok if code in (200, 201) else bad)(f"PUT the encrypted bytes (HTTP {code})")

    # ── download, and byte fidelity ──────────────────────────────────
    code, out = call("photoDownloadUrl", {"photoId": photo_id}, member)
    if code != 200 or not out.get("success"):
        bad(f"photoDownloadUrl (HTTP {code}) {json.dumps(out)[:200]}")
        return 1
    ok("photoDownloadUrl mints a signed URL")
    get_url = out["data"]["url"]

    code, body = http(get_url)
    (ok if code == 200 else bad)(f"GET the object back (HTTP {code})")
    (ok if body == blob else bad)("the bytes that come back are the bytes that went in")

    # ── the stranger ─────────────────────────────────────────────────
    code, out = call("photoUploadUrl", {"photoId": photo_id}, stranger)
    (ok if code >= 400 else bad)(
        f"a signed-in stranger is refused a URL (HTTP {code})")

    # ── deletion is a consequence ────────────────────────────────────
    # This URL stays valid for fifteen minutes. If the object survives its
    # document, this replay succeeds — which is exactly the failure that would
    # leave orphaned photos in the bucket after a burn.
    code, _ = http(f"{FS}/photos/{photo_id}", method="DELETE",
                   headers={"Authorization": f"Bearer {member}"})
    (ok if code == 200 else bad)(f"delete the photo document (HTTP {code})")

    print("     waiting for the onPhotoDeleted trigger…")
    gone = False
    for _ in range(20):
        time.sleep(3)
        code, _ = http(get_url)
        if code in (403, 404):
            gone = True
            break
    (ok if gone else bad)(
        "the object died with its document"
        if gone else "the object OUTLIVED its document — burn would orphan blobs")

    print()
    if failures:
        print(f"{RED}{failures} check(s) failed{RESET}")
        return 1
    print(f"{GREEN}PASS — signed-URL access works and deletion reaches the bucket{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
