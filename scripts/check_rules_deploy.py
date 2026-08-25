#!/usr/bin/env python3
"""Refuse a firestore.rules deploy the live App Store build cannot survive.

This exists because the convention it replaces failed. Twice a rules change
was written that the LIVE build could not satisfy, and both times the only
thing standing between it and production was a comment at the top of the file
and somebody remembering to read it:

  2026-08-10  Proof-of-authorisation on `household_members` create was checked
              against TestFlight builds 36/37 and not the build actually live
              (1.1.0/35). Juan and Chloe could not accept invitations for a day.
  2026-08-24  Owner-or-self delete on `household_members` would have broken
              Guideline 5.1.1(v) account deletion for every non-owner, because
              live 1.8.0's BurnService deleted other members unconditionally.
              Caught by writing the banner. Held 24 hours by remembering it.

A comment is not a guard. This is.

## How it works

`firestore.rules` may carry a machine-readable header:

    // requires-live-version: 1.9.0

meaning: do not deploy this file until App Store Connect reports 1.9.0 (or
later) READY_FOR_SALE. The guard asks ASC, compares, and exits non-zero when
the live version is behind. No header means no constraint — the common case,
and it stays silent.

## Why READY_FOR_SALE and not the newest version

The whole failure mode is trusting a version that exists but is not yet what
people are running. A version in WAITING_FOR_REVIEW or PENDING_DEVELOPER_RELEASE
is not live and does not count, however new it is.

NEGATIVE-CONTROL: set the header to a version above the live one and this must
exit 1 with "live is behind". RUN on 2026-08-25 with `requires-live-version:
99.0.0` -> refused; with `1.9.0` -> allowed; header removed -> silent pass.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc  # noqa: E402  — same directory, same credentials, one ASC client

HEADER = re.compile(r"^//\s*requires-live-version:\s*([0-9]+(?:\.[0-9]+)*)\s*$", re.M)
RULES = Path(__file__).resolve().parent.parent / "firestore.rules"


def parse(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def live_version() -> str | None:
    """The highest version App Store Connect reports READY_FOR_SALE."""
    ready = [
        v["attributes"]["versionString"]
        for v in asc.app_versions()
        if v["attributes"].get("appStoreState") == "READY_FOR_SALE"
    ]
    return max(ready, key=parse) if ready else None


def main() -> int:
    text = RULES.read_text()
    match = HEADER.search(text)
    if not match:
        print("rules-deploy-guard: no requires-live-version header — nothing to check")
        return 0

    required = match.group(1)
    live = live_version()
    if live is None:
        print(
            "rules-deploy-guard: REFUSED — firestore.rules requires "
            f"{required} live, and App Store Connect reports NO version "
            "READY_FOR_SALE at all",
            file=sys.stderr,
        )
        return 1

    if parse(live) < parse(required):
        print(
            f"rules-deploy-guard: REFUSED — firestore.rules requires {required} "
            f"live; App Store Connect says {live} is the live version.\n"
            "\n"
            "This is the 2026-08-10 lockout's guard rail. If you are certain "
            "the rules are safe against the live build, delete the "
            "requires-live-version header (and say why in the commit) rather "
            "than bypassing this script — a bypass leaves nothing behind for "
            "the next person.",
            file=sys.stderr,
        )
        return 1

    print(f"rules-deploy-guard: OK — requires {required}, live is {live}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
