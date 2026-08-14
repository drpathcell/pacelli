#!/usr/bin/env python3
"""Is `quantity` actually ciphertext in storage, or do we just believe it is?

`check_quantity_e2e.sh` proves the round trip: type 347, kill the app, read 347
back. That is necessary and it is not sufficient — an app that skipped
encryption on both sides would pass every assertion in it. The round trip and
the storage form are different claims, and only one of them was ever checked.

This reads the simulator's Firestore persistence, which is not the app. Firestore
caches documents in their SERVER form, so whatever sits in that LevelDB is what
Google sees: if the plaintext quantity is in there, it was never encrypted.

    ./scripts/check_quantity_at_rest.py [--sim UDID] [--probe 347]

## The positive control matters more than the assertion

"I searched for 347 and did not find it" is worth nothing unless the search
could have found it. The first run of the E2E failed with zero items written,
and a naive version of this script would have called that a pass — no item, no
plaintext, green. So this checks, in order:

  1. a checklist_items document EXISTS         (else the whole check is vacuous)
  2. plaintext string values ARE readable here (an ISO-8601 created_at proves
     the reader can see field values inside a document, not just keys)
  3. only then: the probe quantity is ABSENT

Step 2 is the control. Without it a change to Firestore's on-disk format would
turn this check green forever while proving nothing.
"""
import argparse
import pathlib
import re
import subprocess
import sys

DEFAULT_SIM = "EA8C6A85-98F9-43AE-A0EE-338D5F1526B6"
BUNDLE_ID = "com.pacelli.pacelli"

failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)
    print(f"\033[31m  FAIL\033[0m {msg}")


def ok(msg: str) -> None:
    print(f"\033[32m  ok\033[0m {msg}")


def section(msg: str) -> None:
    print(f"\n\033[1m== {msg}\033[0m")


def leveldb_dir(sim: str) -> pathlib.Path:
    try:
        container = subprocess.run(
            ["xcrun", "simctl", "get_app_container", sim, BUNDLE_ID, "data"],
            capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        sys.exit(f"{BUNDLE_ID} is not installed on {sim} — run check_quantity_e2e.sh first.")

    roots = list((pathlib.Path(container) / "Library/Application Support/firestore").glob("*/*/main"))
    if not roots:
        sys.exit("No Firestore persistence in the app container — the app never "
                 "reached Firestore on this device.")
    return roots[0]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sim", default=DEFAULT_SIM)
    ap.add_argument("--probe", default="347",
                    help="the quantity flow_qty_01_write typed")
    ap.add_argument("--title-probe", default="Peppercorns",
                    help="the item title, encrypted since long before quantity was")
    args = ap.parse_args()

    root = leveldb_dir(args.sim)
    blobs = sorted(root.glob("*.ldb")) + sorted(root.glob("*.log"))
    if not blobs:
        sys.exit(f"No LevelDB files under {root}")
    raw = b"".join(p.read_bytes() for p in blobs)
    print(f"Read {len(raw):,} bytes from {len(blobs)} file(s) in {root}")

    section("1. there is something to inspect")
    items = set(re.findall(rb"checklist_items/[A-Za-z0-9-]{8,}", raw))
    if items:
        ok(f"{len(items)} checklist_items document(s) in the cache")
    else:
        fail("No checklist_items document at all. Nothing was written, so an "
             "absence of plaintext below would prove nothing. Run "
             "check_quantity_e2e.sh and make sure its write flow passes.")

    section("2. positive control — plaintext field values are readable here")
    # created_at is stored as a plain ISO-8601 string and always has been.
    stamps = re.findall(rb"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}", raw)
    if stamps:
        ok(f"{len(stamps)} plaintext timestamp(s) visible — the reader can see "
           f"field values, so an absence below is meaningful")
    else:
        fail("Could not find a single plaintext timestamp. Either the on-disk "
             "format changed or this reader is blind — until that is fixed, "
             "a 'no plaintext quantity' result here means nothing.")

    section("3. the quantity is not sitting there in the clear")
    if not failures:  # only meaningful once 1 and 2 hold
        if args.probe.encode() in raw:
            fail(f"The plaintext quantity {args.probe!r} IS in Firestore storage. "
                 f"It is not being encrypted on write.")
        else:
            ok(f"{args.probe!r} does not appear anywhere in storage")

        if args.title_probe.encode() in raw:
            fail(f"The item title {args.title_probe!r} is in storage in the clear. "
                 f"title has been encrypted since the Dart schema — this is a "
                 f"bigger regression than quantity.")
        else:
            ok(f"{args.title_probe!r} does not appear either")
    else:
        print("  \033[2mskipped — the checks above did not hold\033[0m")

    print()
    if failures:
        print(f"\033[31m{len(failures)} problem(s): quantity is not proven encrypted at rest.\033[0m")
        return 1
    print("\033[32mThe quantity a user typed is not recoverable from storage.\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
