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

Three rules enforced here:

  1. Every `collection(...).doc()` create writes an `id` field.
  2. `quantity` on checklist and plan-checklist items is ENCRYPTED on write, in
     both the API and the app.
  3. `quantity` on those items is read with the migration-tolerant decryptor,
     never the plain one, because both forms are still live in the collections.

Rules 2 and 3 replaced their own opposite. Until 1.7.0 this script asserted that
`quantity` must stay plaintext, which was the right call at the time — the app
was the live writer and had plaintext data on real devices. What that framing
missed is that it only ever checked `checklists.ts`. `plans.ts` had been
encrypting `quantity` on write since the API shipped while `PlansRepository`
wrote it raw, so a plan item created through the API rendered a base64 blob in
the app's Qty field and an app-created one came back from the API as
"[encrypted]". A guard that covers one of two collections is how that survived.
Hence rule 2 and 3 name every file that owns either collection, in both
languages.

    ./scripts/verify_api_wire.py

Exit 0 = the writers agree. Exit 1 = someone writes something someone else
cannot read.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HANDLERS = ROOT / "functions/src/functions"
SWIFT_CORE = ROOT / "PacelliApp/Sources/Core"

# Every file that writes or reads `checklist_items` / `plan_checklist_items`.
# `inventory.ts` also has a `quantity`, but it is a number on a different
# collection and has never been encrypted — deliberately not listed.
QUANTITY_OWNERS_TS = ["checklists.ts", "plans.ts"]
QUANTITY_OWNERS_SWIFT = ["ChecklistsRepository.swift", "PlansRepository.swift"]

failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)
    print(f"\033[31mFAIL\033[0m {msg}")


def ok(msg: str) -> None:
    print(f"\033[32m  ok\033[0m {msg}")


def check_id_fields() -> None:
    print("\n\033[1m== every create writes an `id` field\033[0m")
    sites = 0
    before = len(failures)
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
    if len(failures) == before:
        ok(f"{sites} create site(s), all writing an id field")


def check_quantity_encrypted_ts() -> None:
    print("\n\033[1m== the API encrypts `quantity` and reads it tolerantly\033[0m")
    before = len(failures)
    for name in QUANTITY_OWNERS_TS:
        src = (HANDLERS / name).read_text()

        # Every handler mentions `quantity` twice per endpoint: once in the
        # Firestore payload and once in the DTO it returns to the caller. Only
        # the first is storage. They are told apart by their keys — a payload
        # is snake_case because that is the wire schema, a DTO is camelCase
        # because that is the API surface. Confusing them would demand that
        # the API hand the caller back ciphertext it just encrypted.
        lines = src.splitlines()
        for i, ln in enumerate(lines):
            m = re.match(r'\s*quantity:\s*(.+?),\s*$', ln)
            if not m:
                continue
            expr = m.group(1).strip()
            window = "\n".join(lines[max(0, i - 6):i + 7])
            if re.search(r'^\s*(?:isChecked|createdAt|createdBy|checkedAt|'
                         r'checklistId|planId|householdId):', window, re.M):
                continue  # a returned DTO — plaintext is the correct form here
            if expr.startswith(("enc(", "encN(")):
                continue
            if expr.startswith(("dec(", "decN(", "decMig(", "decryptMigrating(")):
                continue  # a read; checked below
            # `cd.quantity` inside createFromTemplate copies stored→stored and
            # is correct in either form.
            if re.fullmatch(r'\w+\.quantity', expr):
                continue
            fail(f"{name}:{i + 1} writes `quantity` as `{expr}` — not encrypted. "
                 f"The app encrypts it, so this row would render as plaintext "
                 f"in a field the app expects to decrypt.")

        # decN is the wrong decryptor: it answers "[encrypted]" for the
        # pre-migration plaintext still sitting in these collections.
        for m in re.finditer(r'^\s*quantity:\s*decN\(', src, re.M):
            line = src[:m.start()].count("\n") + 1
            fail(f"{name}:{line} reads `quantity` with decN. Use decMig / "
                 f"decryptMigrating — plaintext rows still exist and decN "
                 f"would hide them behind a placeholder.")

        if not re.search(r'quantity:\s*(?:decMig|decryptMigrating)\(', src):
            fail(f"{name} never reads `quantity` with the migration-tolerant "
                 f"decryptor. If this file stopped reading the field, delete "
                 f"it from QUANTITY_OWNERS_TS deliberately.")

    if len(failures) == before:
        ok(f"{', '.join(QUANTITY_OWNERS_TS)}: encrypted on write, tolerant on read")


def check_quantity_encrypted_swift() -> None:
    print("\n\033[1m== the app encrypts `quantity` and reads it tolerantly\033[0m")
    before = len(failures)
    collections = ("checklist_items", "plan_checklist_items")

    for name in QUANTITY_OWNERS_SWIFT:
        src = (SWIFT_CORE / name).read_text()
        lines = src.splitlines()
        sites = 0

        # Per WRITE SITE, not per file. The repositories build a document with
        # toMap() — which emits `quantity` raw — and then overwrite the
        # encrypted fields just before the write. So the thing that has to be
        # true is local: every setData into these collections is preceded by an
        # override of ITS OWN map variable.
        #
        # Checking the file as a whole is not enough, and that is not
        # hypothetical: the first version of this check asserted only that the
        # file contained some encrypting override. Deleting the override from
        # `addItem` left the ones in `updateItem` and `createChecklist(from:)`
        # standing, the check stayed green, and every newly added item would
        # have been written in the clear.
        for i, ln in enumerate(lines):
            m = re.search(r'setData\((\w+)', ln)
            if not m:
                continue
            var = m.group(1)
            # The collection may be named on this line (`db.collection(...)
            # .document(id).setData(map)`) or on the next (`batch.setData(
            # itemMap, forDocument: db.collection(...))`).
            here = "\n".join(lines[i:i + 3])
            if not any(f'"{c}"' in here for c in collections):
                continue
            sites += 1
            back = "\n".join(lines[max(0, i - 20):i])
            pattern = re.escape(var) + r'\["quantity"\]\s*=[\s\S]{0,120}?encrypt'
            if not re.search(pattern, back):
                fail(f"{name}:{i + 1} writes `{var}` to a checklist-item "
                     f"collection without encrypting `quantity` first. "
                     f"toMap() emits it raw, so this document would store the "
                     f"user's quantity in the clear.")

        if not sites:
            fail(f"{name} has no setData into {' or '.join(collections)}. "
                 f"If it stopped owning those writes, remove it from "
                 f"QUANTITY_OWNERS_SWIFT deliberately.")

        # updateData writes the field too, and takes a dictionary literal
        # rather than a prepared map.
        for m in re.finditer(r'"quantity":\s*(.+?)(?:,\s*$|\n)', src, re.M):
            expr = m.group(1).strip()
            line = src[:m.start()].count("\n") + 1
            if "encrypt" in expr:
                continue
            # `toMap()` itself is allowed to emit the raw value — it is the
            # in-memory shape, and every caller overrides it before writing.
            if expr == "quantity ?? NSNull()":
                continue
            fail(f"{name}:{line} writes `\"quantity\": {expr}` without encrypting.")

        if "readMigrating" not in src:
            fail(f"{name} does not use PacelliCrypto.readMigrating. Reading "
                 f"`quantity` any other way either breaks pre-migration rows "
                 f"or risks re-encrypting ciphertext.")

    if len(failures) == before:
        ok(f"{', '.join(QUANTITY_OWNERS_SWIFT)}: every write site encrypts, "
           f"reads are tolerant")


def main() -> int:
    check_id_fields()
    check_quantity_encrypted_ts()
    check_quantity_encrypted_swift()
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
