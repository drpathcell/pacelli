#!/usr/bin/env python3
"""Firestore helper for scripts/check_push_e2e.sh.

Three jobs, all read/write against the live project with the maintainer's own
ADC credentials:

    push_probe.py household        -> the household id of the newest device token
    push_probe.py activity         -> that token's activity_push flag
    push_probe.py task <household> -> write a task authored by SOMEONE ELSE

The task write is deliberately admin-side. It stands in for a second member's
client, which is the only way one simulator can test a feature whose entire
point is that a DIFFERENT person did something. The Cloud Function sees exactly
the document it would see in real life.
"""
import datetime
import json
import pathlib
import sys
import urllib.parse
import urllib.request
import uuid

PROJECT = "pacelli-35621"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
OTHER_PERSON = "e2e-other-person-uid"


def token() -> str:
    adc = pathlib.Path.home() / ".config/gcloud/application_default_credentials.json"
    if not adc.exists():
        sys.exit("no ADC — run: gcloud auth application-default login")
    c = json.loads(adc.read_text())
    body = urllib.parse.urlencode({
        "client_id": c["client_id"], "client_secret": c["client_secret"],
        "refresh_token": c["refresh_token"], "grant_type": "refresh_token"}).encode()
    with urllib.request.urlopen("https://oauth2.googleapis.com/token", body) as r:
        return json.loads(r.read())["access_token"]


def get(path: str, tok: str):
    req = urllib.request.Request(f"{BASE}/{path}", headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def newest_token_row(tok: str):
    docs = get("device_tokens?pageSize=50", tok).get("documents", [])
    if not docs:
        return None
    # updateTime, not a field — the row is rewritten on every registration.
    return sorted(docs, key=lambda d: d.get("updateTime", ""))[-1]["fields"]


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    tok = token()
    cmd = sys.argv[1]

    if cmd in ("household", "activity"):
        row = newest_token_row(tok)
        if not row:
            return 1  # no registration yet; the caller polls
        if cmd == "household":
            print(row["household_id"]["stringValue"])
        else:
            print(row.get("activity_push", {}).get("booleanValue", False))
        return 0

    if cmd == "task":
        household = sys.argv[2]
        tid = str(uuid.uuid4())
        now = datetime.datetime.now().isoformat()
        doc = {"fields": {
            "id": {"stringValue": tid},
            "household_id": {"stringValue": household},
            # Stands in for base64(iv||ct). The function copies this straight
            # into the payload and never decrypts it, so its shape is all that
            # matters here.
            "title": {"stringValue": "ZTJlLWNpcGhlcnRleHQtcGxhY2Vob2xkZXI="},
            "is_completed": {"booleanValue": False},
            "priority": {"stringValue": "medium"},
            "created_by": {"stringValue": OTHER_PERSON},
            "created_at": {"stringValue": now},
            "updated_at": {"stringValue": now},
        }}
        req = urllib.request.Request(
            f"{BASE}/tasks?documentId={tid}", data=json.dumps(doc).encode(),
            headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json"},
            method="POST")
        urllib.request.urlopen(req)
        print(tid)
        return 0

    sys.exit(f"unknown command: {cmd}")


if __name__ == "__main__":
    raise SystemExit(main())
