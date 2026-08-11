#!/usr/bin/env python3
"""Firestore helper for scripts/check_push_e2e.sh.

Three jobs, all read/write against the live project with the maintainer's own
ADC credentials:

    push_probe.py household        -> the household id of the newest device token
    push_probe.py activity         -> that token's activity_push flag
    push_probe.py task <household> -> write a task authored by SOMEONE ELSE

The task write is deliberately admin-side. It stands in for a second member's
client, which is the only way one simulator can test a feature whose entire
point is that a DIFFERENT person did something. The Cloud Function sees exactly
the document it would see in real life.
"""
import datetime
import json
import pathlib
import sys
import urllib.parse
import urllib.request
import uuid

PROJECT = "pacelli-35621"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
OTHER_PERSON = "e2e-other-person-uid"


def token() -> str:
    adc = pathlib.Path.home() / ".config/gcloud/application_default_credentials.json"
    if not adc.exists():
        sys.exit("no ADC — run: gcloud auth application-default login")
    c = json.loads(adc.read_text())
    body = urllib.parse.urlencode({
        "client_id": c["client_id"], "client_secret": c["client_secret"],
        "refresh_token": c["refresh_token"], "grant_type": "refresh_token"}).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", body) as r:
        return json.loads(r.read())["access_token"]


def get(path: str, tok: str):
    req = urllib.request.Request(f"{BASE}/{path}", headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def newest_token_row(tok: str):
    docs = get("device_tokens?pageSize=50", tok).get("documents", [])
    if not docs:
        return None
    # updateTime, not a field — the row is rewritten on every registration.
    return sorted(docs, key=lambda d: d.get("updateTime", ""))[-1]["fields"]


def derive_user_key(uid: str) -> str:
    """The v2 wrapping key, byte-for-byte as PacelliCrypto derives it.

    Extract: PRK = HMAC-SHA256(key: "pacelli_hkdf_salt_v2", msg: uid)
    Expand:  OKM = HMAC-SHA256(key: PRK, msg: "pacelli_e2e_user_key_v2" || 0x01)

    The trailing 0x01 is the RFC 5869 single-block counter. Dropping it changes
    every key ever derived, which is why it is spelled out here as well as in
    the Swift.
    """
    import hashlib
    import hmac
    prk = hmac.new(b"pacelli_hkdf_salt_v2", uid.encode(), hashlib.sha256).digest()
    okm = hmac.new(prk, b"pacelli_e2e_user_key_v2" + bytes([0x01]), hashlib.sha256).digest()
    return okm.hex()


def _aes(key_hex: str):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    return algorithms.AES(bytes.fromhex(key_hex)), Cipher, modes


def decrypt_field(ciphertext_b64: str, key_hex: str) -> str:
    """base64(iv[16] || ct), AES-256-CBC, PKCS7 — the Pacelli wire format."""
    import base64
    from cryptography.hazmat.primitives import padding
    alg, Cipher, modes = _aes(key_hex)
    blob = base64.b64decode(ciphertext_b64)
    iv, ct = blob[:16], blob[16:]
    dec = Cipher(alg, modes.CBC(iv)).decryptor()
    padded = dec.update(ct) + dec.finalize()
    unp = padding.PKCS7(128).unpadder()
    return (unp.update(padded) + unp.finalize()).decode()


def encrypt_field(plaintext: str, key_hex: str) -> str:
    import base64
    import os
    from cryptography.hazmat.primitives import padding
    alg, Cipher, modes = _aes(key_hex)
    iv = os.urandom(16)
    pad = padding.PKCS7(128).padder()
    data = pad.update(plaintext.encode()) + pad.finalize()
    enc = Cipher(alg, modes.CBC(iv)).encryptor()
    return base64.b64encode(iv + enc.update(data) + enc.finalize()).decode()


def household_key(tok: str, household: str, uid: str) -> str:
    """Unwrap the household key exactly as a client would.

    Admin-side only so the test can encrypt a title the DEVICE will be able to
    read. It proves the whole chain rather than a stand-in: derive the user
    key from the uid, unwrap `encrypted_key`, and you hold what the device
    holds. It also doubles as a cross-language check of the v2 derivation.
    """
    body = {"structuredQuery": {
        "from": [{"collectionId": "household_keys"}],
        "where": {"compositeFilter": {"op": "AND", "filters": [
            {"fieldFilter": {"field": {"fieldPath": "household_id"},
                             "op": "EQUAL", "value": {"stringValue": household}}},
            {"fieldFilter": {"field": {"fieldPath": "user_id"},
                             "op": "EQUAL", "value": {"stringValue": uid}}}]}},
        "limit": 1}}
    req = urllib.request.Request(
        f"{BASE}:runQuery", data=json.dumps(body).encode(),
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        rows = json.loads(r.read())
    docs = [x["document"] for x in rows if "document" in x]
    if not docs:
        sys.exit(f"no household_keys row for {uid} in {household}")
    wrapped = docs[0]["fields"]["encrypted_key"]["stringValue"]
    return decrypt_field(wrapped, derive_user_key(uid))


def write_task(tok: str, household: str, title_ciphertext: str) -> int:
    tid = str(uuid.uuid4())
    now = datetime.datetime.now().isoformat()
    doc = {"fields": {
        "id": {"stringValue": tid},
        "household_id": {"stringValue": household},
        "title": {"stringValue": title_ciphertext},
        "is_completed": {"booleanValue": False},
        "priority": {"stringValue": "medium"},
        "created_by": {"stringValue": OTHER_PERSON},
        "created_at": {"stringValue": now},
        "updated_at": {"stringValue": now},
    }}
    req = urllib.request.Request(
        f"{BASE}/tasks?documentId={tid}", data=json.dumps(doc).encode(),
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"},
        method="POST")
    urllib.request.urlopen(req)
    print(tid)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    tok = token()
    cmd = sys.argv[1]

    if cmd in ("household", "activity"):
        row = newest_token_row(tok)
        if not row:
            return 1  # no registration yet; the caller polls
        if cmd == "household":
            print(row["household_id"]["stringValue"])
        else:
            print(row.get("activity_push", {}).get("booleanValue", False))
        return 0

    if cmd == "task":
        household = sys.argv[2]
        tid = str(uuid.uuid4())
        now = datetime.datetime.now().isoformat()
        doc = {"fields": {
            "id": {"stringValue": tid},
            "household_id": {"stringValue": household},
            # Stands in for base64(iv||ct). The function copies this straight
            # into the payload and never decrypts it, so its shape is all that
            # matters here.
            "title": {"stringValue": "ZTJlLWNpcGhlcnRleHQtcGxhY2Vob2xkZXI="},
            "is_completed": {"booleanValue": False},
            "priority": {"stringValue": "medium"},
            "created_by": {"stringValue": OTHER_PERSON},
            "created_at": {"stringValue": now},
            "updated_at": {"stringValue": now},
        }}
        req = urllib.request.Request(
            f"{BASE}/tasks?documentId={tid}", data=json.dumps(doc).encode(),
            headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"},
            method="POST")
        urllib.request.urlopen(req)
        print(tid)
        return 0

    if cmd == "encrypted-task":
        household, uid, title = sys.argv[2], sys.argv[3], sys.argv[4]
        hk = household_key(tok, household, uid)
        return write_task(tok, household, encrypt_field(title, hk))

    if cmd == "whoami":
        row = newest_token_row(tok)
        if not row:
            return 1
        print(row["user_id"]["stringValue"], row["household_id"]["stringValue"])
        return 0

    if cmd == "household-key":
        print(household_key(tok, sys.argv[2], sys.argv[3]))
        return 0

    sys.exit(f"unknown command: {cmd}")


if __name__ == "__main__":
    raise SystemExit(main())
