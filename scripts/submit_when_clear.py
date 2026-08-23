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
import fcntl
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
LOCK_PATH = pathlib.Path("/tmp/pacelli-submit-when-clear.lock")
IN_FLIGHT = {"WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE",
             "PENDING_DEVELOPER_RELEASE", "PROCESSING_FOR_APP_STORE"}


def acquire_lock():
    """One submitter at a time.

    Two concurrent runs both pass the state checks, both reach submit(), and
    the loser creates a second, empty reviewSubmission that Apple will neither
    delete nor cancel. Learned 2026-08-12 on 1.4.0.
    """
    fh = LOCK_PATH.open("w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return None
    return fh


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
    ap.add_argument(
        "--screenshots-dir",
        default="fastlane/metadata/ios/en-GB/screenshots",
        help="checked against the listing before submitting")
    ap.add_argument(
        "--allow-stale-screenshots", action="store_true",
        help="submit even when the listing's screenshots are not the ones on "
             "disk. There is one honest reason to use this — the repo's set is "
             "mid-edit and the listing already holds what you meant to ship — "
             "and it is not the reason you are about to use it.")
    a = ap.parse_args()

    lock = acquire_lock()
    if lock is None:
        print(f"another submit_when_clear is already running ({LOCK_PATH})")
        return 0

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

    # The last gate, and deliberately AFTER the version exists rather than
    # before. A version can be submitted carrying the PREVIOUS release's
    # screenshots and nothing anywhere complains — 1.6.0 went out advertising a
    # Checklists screen it no longer had and had to be cancelled and redone, and
    # 1.8.0 came one command from shipping a photos release whose listing had
    # shown no photos since 1.5.0.
    #
    # Checking earlier would have missed both, because `version_create` is where
    # the staleness comes from: Apple copies the previous version's metadata and
    # screenshots onto a newly created one. Before creation there is nothing to
    # compare; after it, the listing is holding last release's pictures and
    # saying so. So the check runs here, with everything else already in place
    # and only `submit` left.
    #
    # Bailing here is cheap: the version, build and notes all survive, the state
    # is still PREPARE_FOR_SUBMISSION, so `screenshots-sync` works and re-running
    # this picks up exactly where it stopped.
    if not a.allow_stale_screenshots:
        folder = pathlib.Path(a.screenshots_dir)
        if not folder.is_absolute():
            folder = HERE.parent / folder
        problems = asc.screenshots_verify(a.version, folder, "en-GB")
        if problems:
            print(f"NOT SUBMITTED: the screenshots on {a.version} are not the "
                  f"ones in {a.screenshots_dir}")
            for pr in problems:
                print(f"  - {pr}")
            print(f"\n  ./scripts/asc.py screenshots-sync {a.version}")
            print("  then re-run this — the version, build and notes are "
                  "already in place.")
            print("  (or --allow-stale-screenshots, if you can say why)")
            return 1
        print(f"screenshots on {a.version} match {a.screenshots_dir}")

    asc.submit(a.version)
    print(f"SUBMITTED {a.version} (build {a.build}) for review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
