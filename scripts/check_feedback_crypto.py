#!/usr/bin/env python3
"""Prove Swift and Python agree on the feedback envelope.

`FeedbackSeal.swift` derives its AES key with CryptoKit's
`hkdfDerivedSymmetricKey`; `read_feedback.py` uses `cryptography`'s `HKDF`.
If those two ever disagree the app keeps sealing feedback happily and nothing
can open it — which is precisely the failure that shipped from the Flutter
days until 2026-08-11 and left four unreadable messages in Firestore.

So the compatibility is a test, not an assumption. Swift writes the vectors:

    PACELLI_WRITE_FEEDBACK_VECTORS=1 swift test   # in PacelliApp/Packages/PacelliKit
    python3 scripts/check_feedback_crypto.py

Exits non-zero if any vector fails to open or round-trip.
"""

import base64
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from read_feedback import PREFIX, unseal  # noqa: E402  — same code the reader uses

VECTORS = pathlib.Path(__file__).parent.parent / "functions/tests/cross-language"


def main() -> int:
    keyfile = VECTORS / "feedback_seal_testkey.json"
    vecfile = VECTORS / "feedback_seal_vectors.json"
    for f in (keyfile, vecfile):
        if not f.exists():
            sys.exit(f"missing {f.name} — regenerate with "
                     "PACELLI_WRITE_FEEDBACK_VECTORS=1 swift test")

    priv = base64.b64decode(json.loads(keyfile.read_text())["private_key_b64"])
    doc = json.loads(vecfile.read_text())

    if doc.get("format") != PREFIX:
        sys.exit(f"format drift: vectors say {doc.get('format')!r}, "
                 f"read_feedback.py expects {PREFIX!r}")

    failures = 0
    for i, v in enumerate(doc["vectors"], 1):
        try:
            got = unseal(v["sealed"], priv)
        except Exception as e:                          # noqa: BLE001
            print(f"  {i}. \033[31mFAIL\033[0m could not unseal: {type(e).__name__}: {e}")
            failures += 1
            continue
        if got != v["plaintext"]:
            print(f"  {i}. \033[31mFAIL\033[0m opened but differs\n"
                  f"      want {v['plaintext']!r}\n      got  {got!r}")
            failures += 1
            continue
        # Opening is not enough: the payload has to survive as JSON, because
        # that is what the reader hands you.
        json.loads(got)
        print(f"  {i}. \033[32mok\033[0m {json.loads(got)['message'][:48]!r}")

    n = len(doc["vectors"])
    if failures:
        print(f"\n\033[31m{failures}/{n} vectors failed — Swift and Python have drifted. "
              f"Do NOT ship: feedback sealed by the app would be unreadable.\033[0m")
        return 1
    print(f"\n\033[32mAll {n} Swift-sealed vectors open in Python.\033[0m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
