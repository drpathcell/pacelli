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
        print(f"[{mark}] {t['id'][:8]}  {t['title']}{due}")


def cmd_task_add(a) -> None:
    body = {"title": a.title}
    if a.due:
        body["dueDate"] = a.due
    if a.priority:
        body["priority"] = a.priority
    t = call("tasksCreate", body)
    print(f"added {t['id'][:8]}  {t['title']}")


def cmd_task_done(a) -> None:
    call("tasksComplete", {"taskId": a.task_id})
    print("completed")


def cmd_checklists(_) -> None:
    for c in call("checklistsList"):
        items = c.get("items") or []
        done = sum(1 for i in items if i.get("isChecked"))
        print(f"{c['id'][:8]}  {c['title']}  ({done}/{len(items)})")
        for i in items:
            mark = "x" if i.get("isChecked") else " "
            qty = f"  x{i['quantity']}" if i.get("quantity") else ""
            print(f"    [{mark}] {i['id'][:8]}  {i['title']}{qty}")


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
        print(f"{p['id'][:8]}  {p['title']}  {p.get('status', '')}")
        for e in call("plansGet", {"planId": p["id"]}).get("entries") or []:
            date = f"  {e['entryDate'][:10]}" if e.get("entryDate") else ""
            print(f"    {e['id'][:8]}  {e['title']}{date}")


def cmd_item_add(a) -> None:
    body = {"checklistId": a.checklist_id, "title": a.title}
    if a.qty:
        body["quantity"] = a.qty
    i = call("checklistItemsAdd", body)
    print(f"added {i['id'][:8]}  {i['title']}")


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
