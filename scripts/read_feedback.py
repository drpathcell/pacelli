#!/usr/bin/env python3
"""Read user feedback out of Firestore.

Feedback is sealed to the Pacelli X25519 public key baked into the app (see
`FeedbackSeal.swift`). The app can seal but holds no private key, and Firestore
rules let no client read another household's entries — so this script, run with
the maintainer's own credentials, is the only way to read feedback at all.

    ./scripts/read_feedback.py                  # newest 25, decrypted
    ./scripts/read_feedback.py --limit 100
    ./scripts/read_feedback.py --since 2026-08-01
    ./scripts/read_feedback.py --json           # for piping

Auth is gcloud Application Default Credentials, i.e. whoever is already
logged in. No service-account key is stored anywhere.

Entries written before 2026-08-11 were encrypted with the SENDER's household
key, which never left their device. They are permanently unreadable and are
reported as such rather than skipped — a reader that hid them would under-report
how much feedback exists.
"""

import argparse
import base64
import json
import pathlib
import sys
import urllib.parse
import urllib.request

PROJECT = "pacelli-35621"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
DEFAULT_KEY = pathlib.Path.home() / ".config/jarvis/secrets/pacelli_feedback_x25519.key"
PREFIX = "pfb1:"
HKDF_INFO = b"pacelli-feedback-v1"

RED, GREEN, DIM, BOLD, OFF = "\033[31m", "\033[32m", "\033[2m", "\033[1m", "\033[0m"


def access_token() -> str:
    """Mint a short-lived token from the user's own ADC refresh token."""
    adc = pathlib.Path.home() / ".config/gcloud/application_default_credentials.json"
    if not adc.exists():
        sys.exit("no Application Default Credentials — run: gcloud auth application-default login")
    c = json.loads(adc.read_text())
    body = urllib.parse.urlencode({
        "client_id": c["client_id"], "client_secret": c["client_secret"],
        "refresh_token": c["refresh_token"], "grant_type": "refresh_token",
    }).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", body) as r:
        return json.loads(r.read())["access_token"]


def fetch(token: str, limit: int) -> list[dict]:
    """Newest first. Ordering is server-side so --limit means the newest N."""
    q = {"structuredQuery": {
        "from": [{"collectionId": "feedback"}],
        "orderBy": [{"field": {"fieldPath": "created_at"}, "direction": "DESCENDING"}],
        "limit": limit,
    }}
    req = urllib.request.Request(
        f"{BASE}:runQuery", data=json.dumps(q).encode(),
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req) as r:
        rows = json.loads(r.read())
    return [row["document"] for row in rows if "document" in row]


def plain(fields: dict, key: str):
    v = fields.get(key, {})
    if "nullValue" in v:
        return None
    return v.get("stringValue") or v.get("integerValue") or v.get("booleanValue")


def unseal(envelope: str, private_key_raw: bytes) -> str:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric.x25519 import (
        X25519PrivateKey, X25519PublicKey)
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.hazmat.primitives.kdf.hkdf import HKDF

    blob = base64.b64decode(envelope[len(PREFIX):])
    ephemeral_pub, rest = blob[:32], blob[32:]
    nonce, ct = rest[:12], rest[12:]

    shared = X25519PrivateKey.from_private_bytes(private_key_raw).exchange(
        X25519PublicKey.from_public_bytes(ephemeral_pub))
    # Must match CryptoKit's hkdfDerivedSymmetricKey exactly: HKDF-SHA256,
    # salt = the ephemeral public key, info = the version string.
    aes_key = HKDF(algorithm=hashes.SHA256(), length=32,
                   salt=ephemeral_pub, info=HKDF_INFO).derive(shared)
    return AESGCM(aes_key).decrypt(nonce, ct, None).decode()


def main() -> int:
    ap = argparse.ArgumentParser(description="Read Pacelli user feedback.")
    ap.add_argument("--limit", type=int, default=25)
    ap.add_argument("--since", help="ISO date, e.g. 2026-08-01")
    ap.add_argument("--key", type=pathlib.Path, default=DEFAULT_KEY)
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    a = ap.parse_args()

    if not a.key.exists():
        sys.exit(f"private key not found: {a.key}\n"
                 "Without it sealed feedback cannot be read by anyone, including you.")
    private_key_raw = base64.b64decode(a.key.read_text().strip())

    docs = fetch(access_token(), a.limit)
    out, legacy = [], 0

    for d in docs:
        f = d["fields"]
        created = plain(f, "created_at") or ""
        if a.since and created < a.since:
            continue
        row = {
            "id": plain(f, "id"),
            "created_at": created,
            "type": plain(f, "type"),
            "rating": plain(f, "rating"),
            "household_id": plain(f, "household_id"),
            "created_by": plain(f, "created_by"),
        }
        envelope = plain(f, "message") or ""
        if not envelope.startswith(PREFIX):
            legacy += 1
            row["readable"] = False
            row["error"] = ("encrypted with the sender's household key "
                            "(pre-2026-08-11) — permanently unreadable")
        else:
            try:
                payload = json.loads(unseal(envelope, private_key_raw))
                row["readable"] = True
                row.update({k: payload.get(k) for k in
                            ("message", "email", "app_version", "os", "locale", "is_guest")})
            except Exception as e:                      # noqa: BLE001 — report, never hide
                row["readable"] = False
                row["error"] = f"could not unseal: {type(e).__name__}: {e}"
        out.append(row)

    if a.json:
        print(json.dumps(out, indent=2))
        return 0

    if not out:
        print("No feedback.")
        return 0

    for r in out:
        print(f"\n{BOLD}{r['created_at']}{OFF}  {r['type']}/{r['rating']}"
              f"  {DIM}{r['id']}{OFF}")
        if r["readable"]:
            print(f"  {GREEN}{r['message']}{OFF}")
            bits = [f"reply-to: {r['email']}" if r.get("email") else "no reply address",
                    r.get("app_version") or "?", r.get("os") or "?",
                    r.get("locale") or "?",
                    "guest" if r.get("is_guest") else "signed in"]
            print(f"  {DIM}{' · '.join(str(b) for b in bits)}{OFF}")
        else:
            print(f"  {RED}[unreadable]{OFF} {DIM}{r['error']}{OFF}")

    readable = sum(1 for r in out if r["readable"])
    print(f"\n{len(out)} entr{'y' if len(out) == 1 else 'ies'} — "
          f"{readable} readable, {len(out) - readable} not.")
    if legacy:
        print(f"{DIM}{legacy} predate the 2026-08-11 fix and cannot be recovered: "
              f"they were encrypted with a key that only ever existed on the "
              f"sender's device.{OFF}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
