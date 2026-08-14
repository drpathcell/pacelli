#!/usr/bin/env python3
"""Does every REST API create write a document the native app can read?

There are two writers into the same Firestore collections: the SwiftUI app, and
71 deployed Cloud Functions built for the retired Flutter app. Nothing checked
that the second produces documents the first can parse — and on 2026-08-14 it
did not. Every single create endpoint omitted the `id` FIELD.

That matters because the app parses from document FIELDS and never injects the
document path:

    guard let item = ChecklistItem(map: data) else { continue }

`init?(map:)` requires `map["id"]`, so an item without it is silently skipped.
No error, no empty state — just absent. The API returns 200 either way, so
nothing on either side could notice. An AI given write access would have
appeared to work perfectly while nothing showed up in the app.

Two rules enforced here:

  1. Every `collection(...).doc()` create writes an `id` field.
  2. `quantity` on checklist items is NOT encrypted — the app writes and reads
     it raw, and it is the live writer with existing plaintext data.

The Swift side is pinned by ApiWireContractTests; this is the half a Swift test
cannot see.

    ./scripts/verify_api_wire.py

Exit 0 = the two writers agree. Exit 1 = the API writes something the app
cannot read.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HANDLERS = ROOT / "functions/src/functions"

failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)
    print(f"\033[31mFAIL\033[0m {msg}")


def ok(msg: str) -> None:
    print(f"\033[32m  ok\033[0m {msg}")


def check_id_fields() -> None:
    print("\n\033[1m== every create writes an `id` field\033[0m")
    sites = 0
    for f in sorted(HANDLERS.glob("*.ts")):
        lines = f.read_text().splitlines()
        for i, ln in enumerate(lines):
            m = re.search(r'collection\("([a-z_]+)"\)\s*\.doc\(\)', ln)
            if not m:
                continue
            sites += 1
            # The written payload is either an inline .set({...}) / batch.set(ref, {...})
            # or a `const data: Record<string, unknown> = {...}` assigned just below.
            block = "\n".join(lines[i:i + 34])
            body_m = re.search(
                r'(?:\.set\((?:\w+,\s*)?\{|const \w+: Record<string, unknown> = \{)(.*?)\n\s*\}',
                block, re.S)
            body = body_m.group(1) if body_m else ""
            if not re.search(r'^\s*id:', body, re.M):
                fail(f"{f.name}:{i + 1} creates `{m.group(1)}` with no `id` field "
                     f"— the app will silently drop it")
    if not failures:
        ok(f"{sites} create site(s), all writing an id field")


def check_quantity_plaintext() -> None:
    print("\n\033[1m== checklist quantity is plaintext on both sides\033[0m")
    src = (HANDLERS / "checklists.ts").read_text()
    # encN/decN are the encrypt/decrypt-nullable helpers. Either applied to
    # quantity means the API disagrees with the app.
    bad = re.findall(r'quantity:\s*(?:enc|dec)N?\(', src)
    if bad:
        fail("checklists.ts encrypts or decrypts `quantity` "
             f"({len(bad)} site(s)). The app stores it raw, so an API-created "
             "item shows a base64 blob in the Qty field.")
    else:
        ok("neither encrypted on write nor decrypted on read")


def main() -> int:
    check_id_fields()
    check_quantity_plaintext()
    print()
    if failures:
        print(f"\033[31m{len(failures)} disagreement(s) between the API and the app.\033[0m")
        print("An AI writing through the API would appear to succeed and produce "
              "nothing the user can see.")
        return 1
    print("\033[32mThe REST API writes documents the native app can read.\033[0m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
