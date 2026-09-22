#!/usr/bin/env bash
# Shopping-list pricing end-to-end (iOS Simulator + the real API).
#
# The API writes catalogue items with an encrypted `source.price` into a fresh
# guest household; the app must decrypt them, wrap the long titles, show price
# each and line totals, and sum the list, excluding the free-text row.
#
#   ./scripts/check_pricing_e2e.sh [--sim UDID] [--app PATH]
#
# NEGATIVE-CONTROL: SOUP_PRICE=2.60 ./scripts/check_pricing_e2e.sh must FAIL
# (the soup row then reads €2.60 and the list €12.36). Seen red, at the soup row,
# 2026-09-22 before the green run was believed.
set -euo pipefail

SIM="${SIM:-$(cat /tmp/pv_sim 2>/dev/null || true)}"
APP="${APP:-/tmp/pv-dd/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/PacelliApp/e2e"
SOUP_PRICE="${SOUP_PRICE:-2.50}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --app) APP="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }
PACELLI_CRASH_BASELINE="$(mktemp -t pacelli_crash_baseline)"
export PACELLI_CRASH_BASELINE
alive() { "$ROOT/scripts/check_app_alive.sh" "$SIM" "$BUNDLE" "${1:-}"; }

[[ -n "$SIM" ]]      || fail "no simulator (pass --sim)"
[[ -d "$APP" ]]      || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]]  || fail "maestro not found at $MAESTRO"

# Two runs on one simulator collide: the previous run's teardown flow was still
# driving it when the next erase came, and the erase failed "in current state:
# Booted". Hit twice on 2026-09-22. Refuse rather than race.
if pgrep -f "maestro.*--device $SIM" >/dev/null; then
  fail "another Maestro run is driving $SIM; wait for it to finish"
fi
# (Before the trap: a refused run must not tear down someone else's guest.)

# The assistant credentials live in a throwaway HOME, never Juan's real link.
CLI_HOME="$(mktemp -d)"
cleanup() {
  if [[ -f "$CLI_HOME/.config/pacelli/credentials.json" ]]; then
    HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" disconnect-self >/dev/null 2>&1 || true
  fi
  rm -rf "$CLI_HOME"
  "$ROOT/scripts/teardown_guest.sh" "$SIM" || true
}
trap cleanup EXIT
cli() { HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" "$@"; }
flow() {
  say "maestro $1"
  "$MAESTRO" --device "$SIM" test "$E2E/$1" || fail "flow $1"
  alive "$1"
}

say "erasing $SIM"
xcrun simctl shutdown "$SIM" 2>/dev/null || true
for _ in $(seq 1 30); do
  xcrun simctl list devices | grep "$SIM" | grep -q "(Shutdown)" && break
  sleep 1
done
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl install "$SIM" "$APP"
ok "clean simulator"

# Guest household + pairing code (the AI-link flow is the only way in).
flow flow_ai_link_01_create.yaml
CODE="$(xcrun simctl pbpaste "$SIM" | tr -d '[:space:]')"
[[ "$CODE" =~ ^[0-9A-Z]{8}$ ]] || fail "no pairing code on the pasteboard (got '$CODE')"
cli link "$CODE" || fail "link refused"
ok "paired"

say "seeding PriceProbe through the API"
HOME="$CLI_HOME" SOUP_PRICE="$SOUP_PRICE" python3 - "$ROOT/scripts/pacelli.py" <<'PY' || fail "seeding failed"
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("pc", sys.argv[1]); pc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pc)
def ok(r):
    if not r.get("success"): raise SystemExit(f"API refused: {r.get('error')}")
    return r["data"]
cl = ok(pc.call_raw("checklistsCreate", {"title": "PriceProbe"}))["id"]
def src(sku, name, price):
    return {"retailer": "dunnes", "sku": sku, "name": name, "price": price,
            "pricePerUnit": "", "observedAt": "2026-09-22T19:00:00Z"}
rows = [
    ("Dunnes Stores Still Irish Spring Water 6 x 2litre", "2", src("100292577", "water", 3.10)),
    ("Dunnes Stores Baked Beans 420g", "4", src("100741402", "beans", 0.89)),
    ("Heinz Vegetable Soup 400g", None, src("100676940", "soup", float(os.environ["SOUP_PRICE"]))),
    ("Torch (LED) - not stocked online at Dunnes", "2", None),
]
ids = []
for title, qty, source in rows:
    body = {"checklistId": cl, "title": title}
    if qty: body["quantity"] = qty
    if source: body["source"] = source
    ids.append(ok(pc.call_raw("checklistItemsAdd", body))["id"])
# Tick the beans from the server side: the app must pick it up, not cause it.
ok(pc.call_raw("checklistItemsToggle", {"itemId": ids[1], "isChecked": True}))
print("seeded", cl, ids)
PY
ok "seeded 4 rows, beans ticked"

flow flow_pricing_01_totals.yaml
printf '\n\033[32mPASS: line prices, wrapped titles, total excluding the unpriced row\033[0m\n'
