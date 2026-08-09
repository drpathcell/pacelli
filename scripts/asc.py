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

Read-only by default: only version-create / version-attach / whats-new /
review-notes / submit mutate, and `submit` prints exactly what it will do
and requires --yes.
"""

from __future__ import annotations

import argparse
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
        print(f"  {s['id']}  state={a['state']}  platform={a.get('platform')}")


def main():
    p = argparse.ArgumentParser(description="Pacelli App Store Connect client")
    sub = p.add_subparsers(dest="cmd", required=True)

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
