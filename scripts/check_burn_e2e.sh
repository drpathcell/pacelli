#!/usr/bin/env bash
# Burn permissions end to end, against real Firebase. 1.10.0.
#
# The feature makes three promises, and they fail in different places, so all
# three are checked in one run:
#
#   1. the owner can restrict who burns             — flow_burn_01_restrict
#   2. a restricted caller is REFUSED BY THE SERVER — this script, via the API
#   3. account deletion is never gated              — flow_burn_03_delete_account
#
# Promise 2 is the one a UI test cannot make. A hidden button stops nobody who
# is not using the app, and after 1.7.0 the household contains a member that
# never uses the app at all: a paired AI assistant. So the refusal is proved
# the same way flow_photo_03_live proves a listener — from ANOTHER PROCESS,
# holding a real credential, reading a real answer. `pacelli.py burn
# --expect-refusal` inverts its exit code, so a burn that is quietly ALLOWED
# fails this script instead of passing it silently.
#
# The order is load-bearing. Restrict, prove the refusal, permit, prove the
# burn, then delete the account — because deleting the account destroys the
# credential everything above needs.
#
#   ./scripts/check_burn_e2e.sh [--sim UDID] [--app PATH] [--code PAIRING_CODE]
#
# NEGATIVE-CONTROL: delete the `mayBurn` check from
# functions/src/functions/burn.ts and step 2 goes red — the restricted call
# succeeds and `--expect-refusal` turns that success into a failure. Confirmed
# reachable by construction; NOT YET RUN against a live project, because doing
# so destroys a real household's data and no disposable one exists yet. Read
# that as: this harness has never been seen to fail. Build a throwaway
# household before trusting a green run.
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/pacelli_dd/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/PacelliApp/e2e"
CODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --app) APP="$2"; shift 2 ;;
    --code) CODE="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo; echo "── $* ──"; }

[[ -d "$APP" ]]     || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]] || fail "maestro not found at $MAESTRO"
[[ -n "$CODE" ]]    || fail "--code is required: pair an assistant from the app (Settings → Connect an AI) and pass its code, so the refusal can be proved from outside the app"

# Crash + liveness after every flow. The app dying mid-flow otherwise reads as
# a passing run right up until the next assertion happens to be on screen.
PACELLI_CRASH_BASELINE="$(mktemp -t pacelli_crash_baseline)"
export PACELLI_CRASH_BASELINE
alive() { "$ROOT/scripts/check_app_alive.sh" "$SIM" "$BUNDLE" "${1:-}"; }

# The assistant credential lives in a throwaway HOME so a failed run cannot
# leave a ghost assistant attached to the household forever.
CLI_HOME="$(mktemp -d)"
cleanup() {
  if [[ -f "$CLI_HOME/.config/pacelli/credentials.json" ]]; then
    HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" disconnect-self || true
  fi
  rm -rf "$CLI_HOME"
}
trap cleanup EXIT
cli() { HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" "$@"; }

step "0. pairing the assistant that will attempt the refused burn"
cli link "$CODE" >/dev/null || fail "could not redeem the pairing code"
cli whoami

step "1. owner restricts burning to nobody (flow_burn_01_restrict)"
"$MAESTRO" --device "$SIM" test "$E2E/flow_burn_01_restrict.yaml"
alive "flow_burn_01_restrict"

step "2. the assistant's burn must be REFUSED BY THE SERVER"
# The whole point of the run. Not 'the button was hidden' — a real call, a
# real credential, a real 403.
cli burn-policy
cli burn --expect-refusal

step "3. owner widens the policy to everyone (flow_burn_02_permit)"
"$MAESTRO" --device "$SIM" test "$E2E/flow_burn_02_permit.yaml"
alive "flow_burn_02_permit"

step "4. the same call must now SUCCEED"
# Paired with step 2 deliberately. A suite that only proves a denial passes
# just as well against a server that refuses everything.
cli burn-policy
cli burn --yes-i-mean-it

step "5. account deletion is available regardless (flow_burn_03_delete_account)"
# Runs last: it destroys the account the steps above authenticated against.
"$MAESTRO" --device "$SIM" test "$E2E/flow_burn_03_delete_account.yaml"
alive "flow_burn_03_delete_account"

echo
echo "PASS — restricted burn refused by the server, permitted burn allowed, account deletion never gated"
