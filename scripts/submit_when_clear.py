#!/usr/bin/env python3
"""Submit a version to App Review, but only once the queue is actually clear.

App Store Connect allows one version in review at a time, so a follow-up
release has to wait for the one ahead of it. This does the waiting: run it on a
schedule and it no-ops until the path is clear, then creates the version,
attaches the build, writes the notes and submits.

    ./scripts/submit_when_clear.py 1.3.1 --build 40 \
        --whats-new-file docs/release-notes/1.3.1.md

Every step is guarded and idempotent — a version that already exists is reused,
an already-attached build is left alone, an already-submitted version exits
cleanly. Safe to run repeatedly from cron.

Exit codes: 0 submitted or nothing to do, 1 blocked or failed.
"""

import argparse
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
IN_FLIGHT = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE",
             "PENDING_DEVELOPER_RELEASE", "PROCESSING_FOR_APP_STORE"}


def load_asc():
    spec = importlib.util.spec_from_file_location("asc", HERE / "asc.py")
    m = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(m)
    except SystemExit:
        pass
    return m


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("version")
    ap.add_argument("--build", required=True)
    ap.add_argument("--whats-new-file", type=pathlib.Path)
    ap.add_argument("--review-notes-file", type=pathlib.Path)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    asc = load_asc()
    versions = {v["attributes"]["versionString"]: v for v in asc.app_versions()}

    # Anything ahead of us still in flight? Then this is not our turn.
    blocking = [
        (name, v["attributes"]["appStoreState"])
        for name, v in versions.items()
        if name != a.version and v["attributes"]["appStoreState"] in IN_FLIGHT
    ]
    if blocking:
        for name, state in blocking:
            print(f"waiting: {name} is {state}")
        return 0

    mine = versions.get(a.version)
    if mine and mine["attributes"]["appStoreState"] in IN_FLIGHT:
        print(f"nothing to do: {a.version} is already "
              f"{mine['attributes']['appStoreState']}")
        return 0
    if mine and mine["attributes"]["appStoreState"] == "READY_FOR_SALE":
        print(f"nothing to do: {a.version} is already live")
        return 0

    # The build has to exist and be processed, or the submission fails later
    # in a much more annoying way.
    build = next((b for b in asc.builds()
                  if b["attributes"]["version"] == str(a.build)), None)
    if build is None:
        print(f"blocked: build {a.build} is not on App Store Connect yet")
        return 1
    if build["attributes"].get("processingState") not in (None, "VALID"):
        print(f"blocked: build {a.build} is "
              f"{build['attributes'].get('processingState')}, not VALID")
        return 1

    if a.dry_run:
        print(f"dry run: would create {a.version}, attach build {a.build}, submit")
        return 0

    if not mine:
        asc.version_create(a.version)
        print(f"created version {a.version}")
    asc.version_attach(a.version, str(a.build))
    if a.whats_new_file:
        asc.whats_new(a.version, a.whats_new_file.read_text().strip(), None)
    if a.review_notes_file:
        asc.review_notes(a.version, a.review_notes_file.read_text().strip())
    asc.submit(a.version)
    print(f"SUBMITTED {a.version} (build {a.build}) for review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
