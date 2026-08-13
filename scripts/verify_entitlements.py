#!/usr/bin/env python3
"""Assert the app and the notification extension carry EXACTLY the
entitlements they are supposed to — no more.

The notification extension is a second process that holds the household key.
Phase C justified that on one promise: its reach is visibly minimal. That
promise decays silently. Someone ticks a capability in Xcode to debug
something, it lands in the entitlements plist, and the extension quietly
gains network identity or push registration that nobody re-audited.

So the allow-list lives here, in code, and the build fails if reality drifts
from it. This is the enforcement the 2026-08-11 Phase C addendum recorded as
"not verified" — turned into something that cannot go stale.

    ./scripts/verify_entitlements.py                  # source plists
    ./scripts/verify_entitlements.py --app PATH.app   # + signed binaries
    ./scripts/verify_entitlements.py --asc            # + Apple App ID caps

Exit 0 = matches the allow-list. Exit 1 = drift, printed as a diff.
"""

from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHARED_GROUP_SUFFIX = "com.pacelli.shared"

# The allow-list. Adding a key here is a deliberate act that shows up in a
# diff and should be accompanied by an audit addendum.
EXPECTED = {
    "app": {
        "path": ROOT / "PacelliApp/Resources/PacelliApp.entitlements",
        "label": "PacelliApp",
        "keys": {
            "aps-environment",
            "keychain-access-groups",
            "com.apple.developer.applesignin",
        },
    },
    "ext": {
        "path": ROOT / "PacelliApp/NotificationService/NotificationService.entitlements",
        "label": "PacelliNotificationService",
        # Deliberately one key. The extension gets the household key and
        # nothing else: no push registration, no Sign in with Apple, no
        # network identity of its own.
        "keys": {"keychain-access-groups"},
    },
}

failures: list[str] = []


def fail(msg: str) -> None:
    failures.append(msg)
    print(f"\033[31mFAIL\033[0m {msg}")


def ok(msg: str) -> None:
    print(f"\033[32m  ok\033[0m {msg}")


def check_keys(label: str, got: set[str], want: set[str], where: str) -> None:
    extra, missing = got - want, want - got
    if extra:
        fail(f"{label} ({where}) gained entitlement(s): {sorted(extra)}")
    if missing:
        fail(f"{label} ({where}) lost entitlement(s): {sorted(missing)}")
    if not extra and not missing:
        ok(f"{label} ({where}): exactly {len(want)} expected entitlement(s)")


def check_group(label: str, groups, where: str) -> None:
    """The shared group must be the ONLY keychain group claimed.

    A second group would mean the extension can reach keychain items nobody
    audited — the exact boundary Phase C left unproven.
    """
    if not isinstance(groups, list) or len(groups) != 1:
        fail(f"{label} ({where}) claims {groups!r}; expected exactly one group")
        return
    if not groups[0].endswith(SHARED_GROUP_SUFFIX):
        fail(f"{label} ({where}) claims {groups[0]!r}, not *{SHARED_GROUP_SUFFIX}")
        return
    ok(f"{label} ({where}): sole keychain group is *{SHARED_GROUP_SUFFIX}")


def check_source() -> None:
    print("\n\033[1m== source entitlements\033[0m")
    for spec in EXPECTED.values():
        p: Path = spec["path"]
        if not p.exists():
            fail(f"{spec['label']}: entitlements file missing at {p}")
            continue
        d = plistlib.loads(p.read_bytes())
        check_keys(spec["label"], set(d), spec["keys"], "source")
        check_group(spec["label"], d.get("keychain-access-groups"), "source")


def signed_entitlements(binary: Path) -> dict:
    out = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(binary)],
        capture_output=True, check=True,
    ).stdout
    return plistlib.loads(out[out.index(b"<?xml"):])


def check_signed(app: Path) -> None:
    """The source plist is the request; this is what actually got signed in.

    They differ whenever a provisioning profile trims something, which is the
    failure mode you never notice until the extension silently cannot read
    the key on a real device.
    """
    print("\n\033[1m== signed binaries\033[0m")
    targets = [(app / app.stem, "app")]
    plugins = app / "PlugIns"
    appexes = sorted(plugins.glob("*.appex")) if plugins.is_dir() else []
    if not appexes:
        fail(f"no .appex embedded in {app.name} — the extension did not ship")
    for ax in appexes:
        targets.append((ax / ax.stem, "ext"))

    for binary, kind in targets:
        spec = EXPECTED[kind]
        if not binary.exists():
            fail(f"{spec['label']}: binary not found at {binary}")
            continue
        try:
            d = signed_entitlements(binary)
        except subprocess.CalledProcessError as e:
            fail(f"{spec['label']}: codesign failed — {e.stderr.decode().strip()}")
            continue
        # Apple injects these at signing; they are not ours to allow-list.
        got = {k for k in d if k not in {
            "application-identifier", "com.apple.developer.team-identifier",
            "get-task-allow", "com.apple.security.get-task-allow",
        }}
        check_keys(spec["label"], got, spec["keys"], "signed")
        check_group(spec["label"], d.get("keychain-access-groups"), "signed")


def check_asc() -> None:
    """Apple's own record of what each App ID is allowed to ask for.

    The entitlements plist is a request; this is the ceiling. An extension
    whose App ID has no push capability cannot register for push even if a
    plist someday claims it.
    """
    print("\n\033[1m== Apple App ID capabilities\033[0m")
    sys.path.insert(0, str(ROOT / "scripts"))
    import asc  # noqa: E402

    want = {
        "com.pacelli.pacelli": {"IN_APP_PURCHASE", "PUSH_NOTIFICATIONS", "APPLE_ID_AUTH"},
        "com.pacelli.pacelli.NotificationService": {"IN_APP_PURCHASE"},
    }
    found = {}
    for b in asc.call("GET", "/bundleIds",
                      params={"limit": 200, "filter[platform]": "IOS"})["data"]:
        ident = b["attributes"]["identifier"]
        if ident in want:
            caps = asc.call("GET", f"/bundleIds/{b['id']}/bundleIdCapabilities")["data"]
            found[ident] = {c["attributes"]["capabilityType"] for c in caps}

    for ident, expected in want.items():
        got = found.get(ident)
        if got is None:
            fail(f"{ident}: no such App ID on App Store Connect")
            continue
        check_keys(ident, got, expected, "App Store Connect")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--app", type=Path, help="built .app to check signed entitlements on")
    ap.add_argument("--asc", action="store_true", help="also check Apple App ID capabilities")
    a = ap.parse_args()

    check_source()
    if a.app:
        check_signed(a.app)
    if a.asc:
        check_asc()

    print()
    if failures:
        print(f"\033[31m{len(failures)} drift(s) from the entitlement allow-list.\033[0m")
        print("If a change is intentional, update EXPECTED here and write an audit addendum.")
        return 1
    print("\033[32mEntitlements match the allow-list — the extension's reach is unchanged.\033[0m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
