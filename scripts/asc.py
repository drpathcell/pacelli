#!/usr/bin/env python3
"""Pacelli — App Store Connect API client.

Re-runnable replacement for driving the ASC web UI by hand. Every release
step Claude or Juan needs is a subcommand; nothing here depends on a browser
session that can go stale mid-flight.

Auth: ES256 JWT from ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8.

    ./scripts/asc.py status                     # app, versions, latest builds
    ./scripts/asc.py builds --limit 10
    ./scripts/asc.py version-create 1.2.0
    ./scripts/asc.py version-attach 1.2.0 38
    ./scripts/asc.py whats-new 1.2.0 "text..." [--locale en-GB]
    ./scripts/asc.py review-notes 1.2.0 "text..."
    ./scripts/asc.py submit 1.2.0
    ./scripts/asc.py submission-status
    ./scripts/asc.py screenshots-list 1.2.0
    ./scripts/asc.py screenshots-sync 1.2.0 --dir path/to/pngs
    ./scripts/asc.py submission-cancel --yes   # unlock a submitted version

Read-only by default: only version-create / version-attach / whats-new /
review-notes / submit mutate, and `submit` prints exactly what it will do
and requires --yes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import time
from pathlib import Path

import jwt
import requests

KEY_ID = "MMWTC97VR7"
ISSUER_ID = "bd761522-6b87-4462-a82e-fedf7aff7f73"
APP_ID = "6764364180"
BUNDLE_ID = "com.pacelli.pacelli"
KEY_PATH = Path.home() / ".appstoreconnect/private_keys" / f"AuthKey_{KEY_ID}.p8"
BASE = "https://api.appstoreconnect.apple.com/v1"
PLATFORM = "IOS"


class ASCError(RuntimeError):
    pass


def token() -> str:
    if not KEY_PATH.exists():
        raise ASCError(f"ASC private key missing at {KEY_PATH}")
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER_ID, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(),
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def call(method: str, path: str, *, params=None, body=None):
    url = path if path.startswith("http") else f"{BASE}{path}"
    r = requests.request(
        method,
        url,
        headers={
            "Authorization": f"Bearer {token()}",
            "Content-Type": "application/json",
        },
        params=params,
        data=json.dumps(body) if body is not None else None,
        timeout=60,
    )
    if r.status_code >= 400:
        raise ASCError(f"{method} {url} -> {r.status_code}\n{r.text}")
    if r.status_code == 204 or not r.text:
        return {}
    return r.json()


# ── Reads ────────────────────────────────────────────────────────────────


def app_versions():
    return call(
        "GET",
        f"/apps/{APP_ID}/appStoreVersions",
        params={"limit": 10, "fields[appStoreVersions]":
                "versionString,appStoreState,appVersionState,platform,createdDate,releaseType"},
    )["data"]


def builds(limit=10):
    return call(
        "GET",
        "/builds",
        params={
            "filter[app]": APP_ID,
            "limit": limit,
            "sort": "-version",
            "fields[builds]": "version,processingState,uploadedDate,expired",
        },
    )["data"]


def find_version(version_string: str):
    for v in app_versions():
        if v["attributes"]["versionString"] == version_string:
            return v
    return None


def find_build(build_number: str):
    for b in builds(limit=50):
        if b["attributes"]["version"] == str(build_number):
            return b
    return None


def submissions():
    return call(
        "GET",
        f"/apps/{APP_ID}/reviewSubmissions",
        params={"limit": 10, "fields[reviewSubmissions]": "state,platform"},
    )["data"]


# ── Writes ───────────────────────────────────────────────────────────────


def version_create(version_string: str, release_type="AFTER_APPROVAL"):
    existing = find_version(version_string)
    if existing:
        print(f"version {version_string} already exists ({existing['id']}), "
              f"state={existing['attributes'].get('appStoreState') or existing['attributes'].get('appVersionState')}")
        return existing
    out = call(
        "POST",
        "/appStoreVersions",
        body={
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "platform": PLATFORM,
                    "versionString": version_string,
                    "releaseType": release_type,
                },
                "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
            }
        },
    )["data"]
    print(f"created version {version_string} -> {out['id']}")
    return out


def version_attach(version_string: str, build_number: str):
    v = find_version(version_string)
    if not v:
        raise ASCError(f"no ASC version {version_string} — run version-create first")
    b = find_build(build_number)
    if not b:
        raise ASCError(f"build {build_number} not found on ASC")
    state = b["attributes"]["processingState"]
    if state != "VALID":
        raise ASCError(f"build {build_number} is {state}, not VALID — wait for processing")
    call(
        "PATCH",
        f"/appStoreVersions/{v['id']}/relationships/build",
        body={"data": {"type": "builds", "id": b["id"]}},
    )
    print(f"attached build {build_number} ({b['id']}) to version {version_string}")


def localizations(version_id: str):
    return call(
        "GET",
        f"/appStoreVersions/{version_id}/appStoreVersionLocalizations",
        params={"limit": 50, "fields[appStoreVersionLocalizations]": "locale,whatsNew"},
    )["data"]


def whats_new(version_string: str, text: str, locale: str | None = None):
    v = find_version(version_string)
    if not v:
        raise ASCError(f"no ASC version {version_string}")
    locs = localizations(v["id"])
    targets = [l for l in locs if locale is None or l["attributes"]["locale"] == locale]
    if not targets:
        raise ASCError(
            f"no localization {locale}; available: "
            f"{[l['attributes']['locale'] for l in locs]}")
    for l in targets:
        call(
            "PATCH",
            f"/appStoreVersionLocalizations/{l['id']}",
            body={
                "data": {
                    "type": "appStoreVersionLocalizations",
                    "id": l["id"],
                    "attributes": {"whatsNew": text},
                }
            },
        )
        print(f"whatsNew set for {l['attributes']['locale']} ({len(text)} chars)")


def review_detail(version_id: str):
    return call("GET", f"/appStoreVersions/{version_id}/appStoreReviewDetail")["data"]


def review_notes(version_string: str, text: str):
    v = find_version(version_string)
    if not v:
        raise ASCError(f"no ASC version {version_string}")
    try:
        detail = review_detail(v["id"])
        call(
            "PATCH",
            f"/appStoreReviewDetails/{detail['id']}",
            body={
                "data": {
                    "type": "appStoreReviewDetails",
                    "id": detail["id"],
                    "attributes": {"notes": text},
                }
            },
        )
        print(f"review notes updated ({len(text)} chars)")
    except ASCError:
        call(
            "POST",
            "/appStoreReviewDetails",
            body={
                "data": {
                    "type": "appStoreReviewDetails",
                    "attributes": {"notes": text},
                    "relationships": {
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": v["id"]}
                        }
                    },
                }
            },
        )
        print(f"review notes created ({len(text)} chars)")


def submit(version_string: str):
    """Create a review submission, add the version as an item, mark submitted."""
    v = find_version(version_string)
    if not v:
        raise ASCError(f"no ASC version {version_string}")

    sub = None
    for s in submissions():
        if s["attributes"]["state"] in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES"):
            sub = s
            print(f"reusing open submission {s['id']} ({s['attributes']['state']})")
            break
    if sub is None:
        sub = call(
            "POST",
            "/reviewSubmissions",
            body={
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": PLATFORM},
                    "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
                }
            },
        )["data"]
        print(f"created submission {sub['id']}")

    items = call(
        "GET", f"/reviewSubmissions/{sub['id']}/items", params={"limit": 50}
    )["data"]
    if not items:
        call(
            "POST",
            "/reviewSubmissionItems",
            body={
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {"type": "reviewSubmissions", "id": sub["id"]}
                        },
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": v["id"]}
                        },
                    },
                }
            },
        )
        print(f"added version {version_string} as submission item")
    else:
        print(f"submission already has {len(items)} item(s)")

    call(
        "PATCH",
        f"/reviewSubmissions/{sub['id']}",
        body={
            "data": {
                "type": "reviewSubmissions",
                "id": sub["id"],
                "attributes": {"submitted": True},
            }
        },
    )
    print(f"SUBMITTED {version_string} for review (submission {sub['id']})")
    return sub



# ── Screenshots ──────────────────────────────────────────────────────────
#
# Uploading a screenshot to ASC is four calls, not one, and skipping any of
# them leaves an asset stuck in UPLOAD_INCOMPLETE that the web UI shows as a
# broken tile you cannot delete:
#   1. POST /appScreenshots        reserve, and get back uploadOperations
#   2. PUT  each uploadOperation   raw bytes, to a signed URL, NO ASC auth
#   3. PATCH /appScreenshots/{id}  uploaded=true + md5 of the whole file
#   4. poll assetDeliveryState until COMPLETE (Apple re-checks the dimensions
#      server side, so a wrong-size PNG fails HERE, long after a 201)

DISPLAY_TYPE = "APP_IPHONE_67"

# What Apple accepts for the 6.7"/6.9" slot. Anything else is rejected at
# step 4 with a state we would otherwise have to guess at.
ALLOWED_SIZES = {(1290, 2796), (2796, 1290), (1320, 2868), (2868, 1320)}


def png_size(path: Path) -> tuple[int, int]:
    """Width/height straight out of the IHDR. Avoids a Pillow dependency."""
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        raise ASCError(f"{path.name} is not a PNG")
    w = int.from_bytes(raw[16:20], "big")
    h = int.from_bytes(raw[20:24], "big")
    return w, h


def screenshot_sets(loc_id: str):
    return call(
        "GET",
        f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets",
        params={"limit": 50},
    )["data"]


def screenshots_in(set_id: str):
    return call(
        "GET",
        f"/appScreenshotSets/{set_id}/appScreenshots",
        params={"limit": 50,
                "fields[appScreenshots]": "fileName,fileSize,assetDeliveryState,"
                                          "sourceFileChecksum"},
    )["data"]


def find_or_create_set(loc_id: str, display_type: str = DISPLAY_TYPE):
    for st in screenshot_sets(loc_id):
        if st["attributes"]["screenshotDisplayType"] == display_type:
            return st["id"]
    out = call(
        "POST",
        "/appScreenshotSets",
        body={"data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {"appStoreVersionLocalization": {"data": {
                "type": "appStoreVersionLocalizations", "id": loc_id}}},
        }},
    )["data"]
    print(f"created {display_type} set {out['id']}")
    return out["id"]


def upload_one(set_id: str, path: Path) -> str:
    raw = path.read_bytes()
    reserved = call(
        "POST",
        "/appScreenshots",
        body={"data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": len(raw), "fileName": path.name},
            "relationships": {"appScreenshotSet": {"data": {
                "type": "appScreenshotSets", "id": set_id}}},
        }},
    )["data"]
    for op in reserved["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in (op.get("requestHeaders") or [])}
        chunk = raw[op["offset"]:op["offset"] + op["length"]]
        r = requests.request(op["method"], op["url"], headers=headers,
                             data=chunk, timeout=180)
        if r.status_code >= 400:
            raise ASCError(f"upload {path.name} -> {r.status_code}\n{r.text}")
    call(
        "PATCH",
        f"/appScreenshots/{reserved['id']}",
        body={"data": {
            "type": "appScreenshots",
            "id": reserved["id"],
            "attributes": {"uploaded": True,
                           "sourceFileChecksum": hashlib.md5(raw).hexdigest()},
        }},
    )
    return reserved["id"]


def await_complete(ids: list[str], timeout: int = 300):
    """Apple validates after the commit, so a 200 on PATCH means nothing yet."""
    deadline = time.time() + timeout
    pending = set(ids)
    while pending and time.time() < deadline:
        time.sleep(5)
        for sid in list(pending):
            a = call("GET", f"/appScreenshots/{sid}")["data"]["attributes"]
            state = (a.get("assetDeliveryState") or {})
            if state.get("errors"):
                raise ASCError(f"{a.get('fileName')} rejected: {state['errors']}")
            if state.get("state") == "COMPLETE":
                pending.discard(sid)
    if pending:
        raise ASCError(f"{len(pending)} screenshot(s) never reached COMPLETE")


def screenshots_sync(version_string: str, folder: Path, locale: str,
                     display_type: str = DISPLAY_TYPE):
    """Make the remote set exactly match `folder`, in filename order.

    Replaces rather than appends: appending is how you end up with the 1.4.0
    screenshots still sitting behind the 1.6.0 ones.
    """
    v = find_version(version_string)
    if not v:
        raise ASCError(f"no ASC version {version_string}")
    state = v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")
    if state not in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED"):
        raise ASCError(
            f"version {version_string} is {state}; Apple locks metadata once a "
            f"version is submitted. Cancel the review submission first "
            f"(./scripts/asc.py submission-cancel), then re-run this, then submit again.")

    files = sorted(folder.glob("*.png"))
    if not files:
        raise ASCError(f"no PNGs in {folder}")
    for f in files:
        size = png_size(f)
        if size not in ALLOWED_SIZES:
            raise ASCError(
                f"{f.name} is {size[0]}x{size[1]}; {display_type} accepts "
                f"{sorted(ALLOWED_SIZES)}")

    locs = {l["attributes"]["locale"]: l["id"] for l in localizations(v["id"])}
    if locale not in locs:
        raise ASCError(f"no localization {locale}; available: {sorted(locs)}")
    set_id = find_or_create_set(locs[locale], display_type)

    for old in screenshots_in(set_id):
        call("DELETE", f"/appScreenshots/{old['id']}")
        print(f"  removed {old['attributes']['fileName']}")

    ids = []
    for f in files:
        ids.append(upload_one(set_id, f))
        print(f"  uploaded {f.name} ({f.stat().st_size // 1024} KB)")
    await_complete(ids)

    # Order is the display order on the product page, and Apple does not infer
    # it from upload order.
    call(
        "PATCH",
        f"/appScreenshotSets/{set_id}/relationships/appScreenshots",
        body={"data": [{"type": "appScreenshots", "id": i} for i in ids]},
    )
    print(f"synced {len(ids)} screenshot(s) to {version_string} / {locale} / {display_type}")


def screenshots_verify(version_string: str, folder: Path, locale: str,
                       display_type: str = DISPLAY_TYPE) -> list[str]:
    """Do the screenshots on the listing match the ones on disk, byte for byte?

    This exists because a version can be submitted with the previous release's
    screenshots and nothing anywhere complains. 1.6.0 went out advertising a
    Checklists screen it no longer had and had to be cancelled and redone; 1.8.0
    came within one command of shipping a photos release whose listing showed no
    photos, with a set that had been stale since 1.5.0.

    Comparison is `sourceFileChecksum` — the md5 `upload_one` sent with the
    commit — against the md5 of the local file, so it answers the only question
    worth asking: are the bytes on the product page the bytes in the repo? Name
    and size are compared too, since a checksum Apple has not returned would
    otherwise silently pass.

    Returns a list of complaints. Empty means they match.
    """
    problems: list[str] = []
    v = find_version(version_string)
    if not v:
        return [f"no ASC version {version_string}"]

    local = {}
    for f in sorted(folder.glob("*.png")):
        raw = f.read_bytes()
        local[f.name] = (len(raw), hashlib.md5(raw).hexdigest())
    if not local:
        return [f"no PNGs in {folder}"]

    locs = {l["attributes"]["locale"]: l["id"] for l in localizations(v["id"])}
    if locale not in locs:
        return [f"no localization {locale} on {version_string}"]

    set_id = None
    for st in screenshot_sets(locs[locale]):
        if st["attributes"]["screenshotDisplayType"] == display_type:
            set_id = st["id"]
    if set_id is None:
        return [f"{version_string} has no {display_type} screenshot set at all"]

    remote = {}
    for sh in screenshots_in(set_id):
        a = sh["attributes"]
        state = (a.get("assetDeliveryState") or {}).get("state")
        if state != "COMPLETE":
            problems.append(f"{a['fileName']} is {state}, not COMPLETE")
        remote[a["fileName"]] = (a.get("fileSize"), a.get("sourceFileChecksum"))

    for name in sorted(set(local) - set(remote)):
        problems.append(f"{name} is in {folder} but not on the listing")
    for name in sorted(set(remote) - set(local)):
        problems.append(f"{name} is on the listing but no longer in {folder}")

    for name in sorted(set(local) & set(remote)):
        lsize, lmd5 = local[name]
        rsize, rmd5 = remote[name]
        if rmd5 is None:
            if rsize != lsize:
                problems.append(
                    f"{name} differs: {lsize} bytes locally, {rsize} on the "
                    f"listing (Apple returned no checksum to compare)")
        elif rmd5 != lmd5:
            problems.append(
                f"{name} on the listing is a different image "
                f"({rmd5[:8]}… vs {lmd5[:8]}… locally)")

    return problems


def submission_cancel():
    """Pull an in-flight submission back so its version becomes editable."""
    done = 0
    for s in submissions():
        if s["attributes"]["state"] in ("WAITING_FOR_REVIEW", "IN_REVIEW"):
            call("PATCH", f"/reviewSubmissions/{s['id']}",
                 body={"data": {"type": "reviewSubmissions", "id": s["id"],
                                "attributes": {"canceled": True}}})
            print(f"cancelled submission {s['id']} ({s['attributes']['state']})")
            done += 1
    if not done:
        print("no submission in WAITING_FOR_REVIEW or IN_REVIEW")
    return done


# ── CLI ──────────────────────────────────────────────────────────────────


def cmd_status(_):
    print("== versions ==")
    for v in app_versions():
        a = v["attributes"]
        state = a.get("appStoreState") or a.get("appVersionState")
        print(f"  {a['versionString']:<10} {state:<28} {a.get('releaseType','')}  {v['id']}")
    print("== builds (latest 8) ==")
    for b in builds(limit=8):
        a = b["attributes"]
        print(f"  build {a['version']:<5} {a['processingState']:<12} "
              f"expired={a['expired']}  {a['uploadedDate']}")
    print("== review submissions ==")
    for s in submissions():
        a = s["attributes"]
        note = ""
        if a["state"] in ("READY_FOR_REVIEW", "UNRESOLVED_ISSUES"):
            n = len(call("GET", f"/reviewSubmissions/{s['id']}/items",
                         params={"limit": 50})["data"])
            note = (f"  <- OPEN, {n} item(s); the next submit() reuses this one"
                    if n else
                    "  <- OPEN but EMPTY: a race orphan. Apple allows neither "
                    "DELETE nor cancel on it; submit() reuses it, so it is "
                    "harmless. Do not try to clear it.")
        print(f"  {s['id']}  state={a['state']}  platform={a.get('platform')}{note}")


def cmd_screenshots_list(a):
    v = find_version(a.version)
    if not v:
        raise ASCError(f"no ASC version {a.version}")
    state = v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")
    print(f"version {a.version} ({state})")
    for l in localizations(v["id"]):
        loc = l["attributes"]["locale"]
        for st in screenshot_sets(l["id"]):
            shots = screenshots_in(st["id"])
            print(f"  {loc} / {st['attributes']['screenshotDisplayType']} "
                  f"({len(shots)})")
            for sh in shots:
                sa = sh["attributes"]
                dstate = (sa.get("assetDeliveryState") or {}).get("state")
                print(f"    {sa['fileName']:<28} {dstate}")


def cmd_screenshots_sync(a):
    screenshots_sync(a.version, Path(a.dir), a.locale, a.display_type)


def cmd_screenshots_verify(a):
    problems = screenshots_verify(a.version, Path(a.dir), a.locale,
                                  a.display_type)
    if problems:
        print(f"screenshots for {a.version} DO NOT match {a.dir}:")
        for pr in problems:
            print(f"  - {pr}")
        print(f"\nfix: ./scripts/asc.py screenshots-sync {a.version}")
        raise SystemExit(1)
    print(f"screenshots for {a.version} match {a.dir}")


def cmd_submission_cancel(a):
    if not a.yes:
        print("This pulls the version out of the review queue and loses its "
              "place in it. Re-run with --yes.")
        return
    submission_cancel()


def main():
    p = argparse.ArgumentParser(description="Pacelli App Store Connect client")
    sub = p.add_subparsers(dest="cmd", required=True)

    sl = sub.add_parser("screenshots-list")
    sl.add_argument("version")
    sl.set_defaults(fn=cmd_screenshots_list)

    ss = sub.add_parser("screenshots-sync")
    ss.add_argument("version")
    ss.add_argument("--dir", default="fastlane/metadata/ios/en-GB/screenshots")
    ss.add_argument("--locale", default="en-GB")
    ss.add_argument("--display-type", default=DISPLAY_TYPE)
    ss.set_defaults(fn=cmd_screenshots_sync)

    sv = sub.add_parser("screenshots-verify")
    sv.add_argument("version")
    sv.add_argument("--dir", default="fastlane/metadata/ios/en-GB/screenshots")
    sv.add_argument("--locale", default="en-GB")
    sv.add_argument("--display-type", default=DISPLAY_TYPE)
    sv.set_defaults(fn=cmd_screenshots_verify)

    sc = sub.add_parser("submission-cancel")
    sc.add_argument("--yes", action="store_true")
    sc.set_defaults(fn=cmd_submission_cancel)

    sub.add_parser("status").set_defaults(fn=cmd_status)

    b = sub.add_parser("builds")
    b.add_argument("--limit", type=int, default=10)
    b.set_defaults(fn=lambda a: [
        print(f"  build {x['attributes']['version']:<5} "
              f"{x['attributes']['processingState']:<12} "
              f"{x['attributes']['uploadedDate']}")
        for x in builds(a.limit)])

    vc = sub.add_parser("version-create")
    vc.add_argument("version")
    vc.add_argument("--release-type", default="AFTER_APPROVAL")
    vc.set_defaults(fn=lambda a: version_create(a.version, a.release_type))

    va = sub.add_parser("version-attach")
    va.add_argument("version")
    va.add_argument("build")
    va.set_defaults(fn=lambda a: version_attach(a.version, a.build))

    wn = sub.add_parser("whats-new")
    wn.add_argument("version")
    wn.add_argument("text")
    wn.add_argument("--locale", default=None)
    wn.set_defaults(fn=lambda a: whats_new(a.version, a.text, a.locale))

    rn = sub.add_parser("review-notes")
    rn.add_argument("version")
    rn.add_argument("text")
    rn.set_defaults(fn=lambda a: review_notes(a.version, a.text))

    sb = sub.add_parser("submit")
    sb.add_argument("version")
    sb.add_argument("--yes", action="store_true", required=True,
                    help="required — this sends the version to App Review")
    sb.set_defaults(fn=lambda a: submit(a.version))

    sub.add_parser("submission-status").set_defaults(
        fn=lambda a: [print(json.dumps(s, indent=2)) for s in submissions()])

    args = p.parse_args()
    try:
        args.fn(args)
    except ASCError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
