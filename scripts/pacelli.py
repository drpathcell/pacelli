#!/usr/bin/env python3
"""Pacelli household CLI — what an AI assistant drives.

Pair once with a code from the app, then read and edit the household from a
computer. No admin credential is involved at any point: pairing exchanges a
one-shot code for an assistant session, and from then on this holds a normal
Firebase refresh token, exactly like a signed-in client would.

    ./scripts/pacelli.py link ABCD2345      # once, code comes from the app
    ./scripts/pacelli.py whoami
    ./scripts/pacelli.py tasks
    ./scripts/pacelli.py task-add "Water the plants" --due 2026-08-20
    ./scripts/pacelli.py task-done <id>
    ./scripts/pacelli.py checklists
    ./scripts/pacelli.py plans
    ./scripts/pacelli.py photos
    ./scripts/pacelli.py photo-save <id> /tmp/out.jpg
    ./scripts/pacelli.py item-add <checklistId> "White pepper" --qty 2
    ./scripts/pacelli.py unlink                # forget local credentials

Credentials live in ~/.config/pacelli/credentials.json, chmod 600. That file is
a household credential — treat it like an app password. Revoking from the app
(Members → remove the assistant) kills it server-side regardless of this file.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.request

API = "https://us-central1-pacelli-35621.cloudfunctions.net"
# The Firebase *web* API key. Public by design — it ships inside every copy of
# the app and identifies the project, it does not authorise anything on its own.
WEB_API_KEY = "AIzaSyCr"  # placeholder, filled from the plist at runtime
CRED_PATH = pathlib.Path.home() / ".config/pacelli/credentials.json"
TOKEN_SKEW_S = 120


def _post(url: str, payload: dict, bearer: str | None = None) -> dict:
    body = json.dumps(payload).encode()
    headers = {"Content-Type": "application/json"}
    if bearer:
        headers["Authorization"] = f"Bearer {bearer}"
    req = urllib.request.Request(url, data=body, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        try:
            msg = json.loads(detail).get("error") or detail
        except Exception:
            msg = detail
        sys.exit(f"error {e.code}: {msg}")


def _load() -> dict:
    if not CRED_PATH.exists():
        sys.exit("not linked — run: pacelli.py link <CODE>  (get a code from the app)")
    return json.loads(CRED_PATH.read_text())


def _save(cred: dict) -> None:
    CRED_PATH.parent.mkdir(parents=True, exist_ok=True)
    CRED_PATH.write_text(json.dumps(cred, indent=2))
    # A household credential. Not group- or world-readable.
    os.chmod(CRED_PATH, 0o600)


def _api_key() -> str:
    """Read the project's web API key out of the app bundle.

    Kept out of this file so there is exactly one copy in the repo, and so a
    project change does not silently leave a stale key behind here.
    """
    import plistlib

    p = pathlib.Path(__file__).resolve().parent.parent / \
        "PacelliApp/Resources/GoogleService-Info.plist"
    return plistlib.load(p.open("rb"))["API_KEY"]


def _id_token() -> str:
    """A valid ID token, refreshing when it is close to expiry.

    Firebase ID tokens last an hour; the refresh token does not expire until it
    is revoked. Refreshing here rather than at pair time is what makes the link
    durable — the alternative is re-pairing every hour, which no one would do.
    """
    cred = _load()
    if cred.get("id_token") and cred.get("expires_at", 0) - TOKEN_SKEW_S > time.time():
        return cred["id_token"]

    d = _post(
        f"https://securetoken.googleapis.com/v1/token?key={_api_key()}",
        {"grant_type": "refresh_token", "refresh_token": cred["refresh_token"]},
    )
    cred["id_token"] = d["id_token"]
    cred["refresh_token"] = d.get("refresh_token", cred["refresh_token"])
    cred["expires_at"] = time.time() + int(d.get("expires_in", 3600))
    _save(cred)
    return cred["id_token"]


def call(fn: str, payload: dict | None = None) -> dict:
    d = _post(f"{API}/{fn}", payload or {}, bearer=_id_token())
    if not d.get("success"):
        sys.exit(f"error: {d.get('error')}")
    return d.get("data")


# ── commands ────────────────────────────────────────────────────────────


def cmd_link(a) -> None:
    d = _post(f"{API}/aiLinkRedeem", {"code": a.code})
    if not d.get("success"):
        sys.exit(f"error: {d.get('error')}")
    data = d["data"]

    # A custom token is not a session. Exchange it for the ID + refresh pair
    # that a normal signed-in client would hold.
    ex = _post(
        f"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken"
        f"?key={_api_key()}",
        {"token": data["customToken"], "returnSecureToken": True},
    )
    _save({
        "assistant_uid": data["assistantUid"],
        "household_id": data["householdId"],
        "refresh_token": ex["refreshToken"],
        "id_token": ex["idToken"],
        "expires_at": time.time() + int(ex.get("expiresIn", 3600)),
    })
    print(f"linked to household {data['householdId']}")
    print(f"credentials: {CRED_PATH} (chmod 600)")


def cmd_unlink(_) -> None:
    if CRED_PATH.exists():
        CRED_PATH.unlink()
        print("local credentials removed")
        print("NOTE: this only forgets them here. To cut off access properly, "
              "disconnect the assistant in the app: Settings > Connect an AI. "
              "Removing it from Members does NOT revoke the session.")
    else:
        print("not linked")


def cmd_whoami(_) -> None:
    cred = _load()
    print(f"assistant: {cred['assistant_uid']}")
    print(f"household: {cred['household_id']}")
    stats = call("tasksStats")
    print(f"tasks: {json.dumps(stats)}")


def cmd_tasks(a) -> None:
    for t in call("tasksList", {"status": a.status} if a.status else {}):
        mark = "x" if t.get("status") == "completed" else " "
        due = f"  due {t['dueDate'][:10]}" if t.get("dueDate") else ""
        print(f"[{mark}] {t['id']}  {t['title']}{due}")


def cmd_task_add(a) -> None:
    body = {"title": a.title}
    if a.due:
        body["dueDate"] = a.due
    if a.priority:
        body["priority"] = a.priority
    t = call("tasksCreate", body)
    print(f"added {t['id']}  {t['title']}")


def cmd_task_done(a) -> None:
    # `tasksComplete` returns false for a task id it cannot find; it does not
    # raise. This printed "completed" regardless, so on 2026-08-24 it reported
    # four tasks done and changed nothing — the id had been copied from this
    # script's own truncated `tasks` output, which no command could accept back.
    # Both halves of that are fixed: ids print in full, and a false is a
    # failure.
    task_id = _resolve_task_id(a.task_id)
    if not call("tasksComplete", {"taskId": task_id}):
        raise SystemExit(
            f"tasksComplete refused {task_id!r} — no such task in this "
            f"household, or it is already completed. Nothing was changed.")
    print(f"completed {task_id}")


def _resolve_task_id(given: str) -> str:
    """Accept a full id or an unambiguous prefix.

    Convenience, but also a guard: a prefix that matches nothing, or matches
    more than one task, stops here rather than being sent to the API to fail
    quietly.
    """
    matches = [t["id"] for t in call("tasksList", {})
               if t["id"] == given or t["id"].startswith(given)]
    if not matches:
        raise SystemExit(f"no task id starts with {given!r}")
    if len(matches) > 1:
        raise SystemExit(
            f"{given!r} is ambiguous — matches {len(matches)}: "
            + ", ".join(m[:12] for m in matches))
    return matches[0]


def cmd_checklists(_) -> None:
    for c in call("checklistsList"):
        items = c.get("items") or []
        done = sum(1 for i in items if i.get("isChecked"))
        print(f"{c['id']}  {c['title']}  ({done}/{len(items)})")
        for i in items:
            mark = "x" if i.get("isChecked") else " "
            qty = f"  x{i['quantity']}" if i.get("quantity") else ""
            print(f"    [{mark}] {i['id']}  {i['title']}{qty}")


def cmd_photos(a) -> None:
    """Every picture in the household, or just the ones on one item."""
    body = {"subjectId": a.subject} if a.subject else {}
    rows = call("photosList", body)
    if a.ids:
        # Full ids, one per line — what a script wants. The pretty form
        # truncates them, which is fine to read and useless to pipe.
        for p in rows:
            print(p["id"])
        return
    for p in rows:
        state = "" if p.get("uploadState") == "ready" else f"  [{p.get('uploadState')}]"
        seen = p.get("recognisedText") or ""
        seen = f"  \u201c{seen[:40]}\u2026\u201d" if seen else ""
        print(f"{p['id']}  {p.get('subjectType')}/{p.get('subjectId','')[:8]}"
              f"  {p.get('createdAt','')[:16]}{state}{seen}")


def cmd_photo_save(a) -> None:
    """Fetch one picture and write it to disk.

    This is the assistant actually looking at a photo rather than counting it:
    the Cloud Function opens the household key server-side, decrypts the object
    and hands back base64 — the same trust boundary every other endpoint has
    always sat on for task titles and manual entries.
    """
    import base64
    d = call("photosGet", {"photoId": a.photo_id, "includeImage": True})
    raw = base64.b64decode(d["imageBase64"])
    pathlib.Path(a.path).write_bytes(raw)
    print(f"wrote {a.path}  {len(raw)} bytes  {d.get('width')}x{d.get('height')}")


def cmd_connect_another(a) -> None:
    """Try to mint a pairing code from this assistant's own session.

    **This is expected to FAIL**, and it exists so that the refusal is
    testable. An assistant is a household member, and the security rules judge
    membership by the member doc's existence rather than its role — so without
    the role check in `createLink` an assistant could connect a second
    assistant and keep it after the first was revoked. `check_ai_link_e2e.sh`
    runs this as a negative control.
    """
    d = call("aiLinkCreate", {"label": a.label})
    print(f"UNEXPECTED: minted {d['code']} for {d['assistantUid']}")


def cmd_disconnect_self(_) -> None:
    """Hand back this assistant's own access, from the assistant's side.

    `aiLinkRevoke` is scoped to the caller's household and refuses anything
    that is not an assistant row, so an assistant calling it on its own uid is
    exactly the one case it can do — no elevation, no reach into anyone else.

    Useful when decommissioning the machine this credential lives on, and it
    is what keeps `check_ai_link_e2e.sh` from leaving a ghost member behind
    every time a run fails midway.
    """
    cred = _load()
    call("aiLinkRevoke", {"assistantUid": cred["assistant_uid"]})
    CRED_PATH.unlink(missing_ok=True)
    print("disconnected and local credentials removed")


def cmd_plans(_) -> None:
    """Plans, with their entries.

    `plansGet` is the only read that touches `plan_entries` with two filters
    and two sorts, so it is the only way to notice that its composite index is
    missing — `plansList` alone would pass with the index absent.
    """
    for p in call("plansList"):
        print(f"{p['id']}  {p['title']}  {p.get('status', '')}")
        for e in call("plansGet", {"planId": p["id"]}).get("entries") or []:
            date = f"  {e['entryDate'][:10]}" if e.get("entryDate") else ""
            print(f"    {e['id']}  {e['title']}{date}")


def cmd_item_add(a) -> None:
    body = {"checklistId": a.checklist_id, "title": a.title}
    if a.qty:
        body["quantity"] = a.qty
    i = call("checklistItemsAdd", body)
    print(f"added {i['id']}  {i['title']}")


def cmd_item_toggle(a) -> None:
    call("checklistItemsToggle", {"itemId": a.item_id})
    print("toggled")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("link"); p.add_argument("code"); p.set_defaults(fn=cmd_link)
    sub.add_parser("unlink").set_defaults(fn=cmd_unlink)
    sub.add_parser("whoami").set_defaults(fn=cmd_whoami)

    p = sub.add_parser("tasks"); p.add_argument("--status"); p.set_defaults(fn=cmd_tasks)
    p = sub.add_parser("task-add"); p.add_argument("title")
    p.add_argument("--due"); p.add_argument("--priority"); p.set_defaults(fn=cmd_task_add)
    p = sub.add_parser("task-done"); p.add_argument("task_id"); p.set_defaults(fn=cmd_task_done)

    sub.add_parser("checklists").set_defaults(fn=cmd_checklists)
    sub.add_parser("plans").set_defaults(fn=cmd_plans)
    p = sub.add_parser("photos"); p.add_argument("--subject")
    p.add_argument("--ids", action="store_true")
    p.set_defaults(fn=cmd_photos)
    p = sub.add_parser("photo-save"); p.add_argument("photo_id")
    p.add_argument("path"); p.set_defaults(fn=cmd_photo_save)
    p = sub.add_parser("connect-another"); p.add_argument("label")
    p.set_defaults(fn=cmd_connect_another)
    sub.add_parser("disconnect-self").set_defaults(fn=cmd_disconnect_self)
    p = sub.add_parser("item-add"); p.add_argument("checklist_id"); p.add_argument("title")
    p.add_argument("--qty"); p.set_defaults(fn=cmd_item_add)
    p = sub.add_parser("item-toggle"); p.add_argument("item_id"); p.set_defaults(fn=cmd_item_toggle)

    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
