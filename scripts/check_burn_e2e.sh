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
# is not using the app, and since 1.7.0 the household contains a member that
# never uses the app at all: a paired AI assistant. So the refusal is proved
# the way flow_photo_03_live proves a listener — from ANOTHER PROCESS, holding
# a real credential, reading a real answer.
#
# ## It provisions its own household
#
# The first version of this script demanded a pairing code by hand, and that is
# exactly why it sat unrun: a harness that needs a human to set the scene does
# not get run, and one that has never been run is not evidence. It now erases
# the simulator, signs in as a guest — which auto-provisions a household the
# guest OWNS — seeds a task, and pairs its own assistant off the pasteboard,
# the same way check_ai_link_e2e.sh does. Everything it destroys is something
# it created ninety seconds earlier.
#
# ## The pairings that make it honest
#
# A denial proves nothing on its own — a server that refuses everything passes
# a suite of denials. So every refusal is paired with the same call succeeding
# once the policy is widened, and every burn is paired with a check on the
# CONTENT rather than on the status code:
#
#   refused  -> the seeded task must STILL BE THERE (a refusal that deleted
#               anything would be the worst outcome of the three, and a
#               status-code-only check cannot see it)
#   allowed  -> the seeded task must be GONE
#
#   ./scripts/check_burn_e2e.sh [--sim UDID] [--app PATH]
#
# NEGATIVE-CONTROL: RUN 2026-08-25, against the real project, not described.
# `mayBurn`'s branch in functions/src/functions/burn.ts was disabled, the
# function deployed, and this script run: it went red at step 2 with "the burn
# was ALLOWED — expected the server to refuse it", on a household whose policy
# said `nobody`. Check restored and redeployed the same minute. So the refusal
# this harness reports is load-bearing, and has been seen to fail when it is
# not.
#
# It has also been red twice for its own reasons on the way to the first green
# run — a Maestro `extendedWaitUntil: id:` that needs the id nested under
# `visible:`, and a CLI that exited on the 403 before it could read it, which
# made this script report a CORRECT refusal as "the burn was ALLOWED".
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/pacelli_dd/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
TITLE="Water the plants"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E="$ROOT/PacelliApp/e2e"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) SIM="$2"; shift 2 ;;
    --app) APP="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

say()  { printf '\n\033[1m== %s\033[0m\n' "$*"; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }

[[ -d "$APP" ]]     || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]] || fail "maestro not found at $MAESTRO"

# Crash + liveness after every flow. A flow can pass while the app dies the
# moment after its last assertion, and the next flow's stopApp clears away the
# evidence — that is how build 46 shipped a crash with a green harness.
PACELLI_CRASH_BASELINE="$(mktemp -t pacelli_crash_baseline)"
export PACELLI_CRASH_BASELINE
alive() { "$ROOT/scripts/check_app_alive.sh" "$SIM" "$BUNDLE" "${1:-}"; }

# The CLI keys credentials off $HOME. Pointing it at a scratch directory is not
# tidiness — without it this script destroys the operator's own pairing.
CLI_HOME="$(mktemp -d)"
cleanup() {
  if [[ -f "$CLI_HOME/.config/pacelli/credentials.json" ]]; then
    HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" disconnect-self \
      >/dev/null 2>&1 || true
  fi
  rm -rf "$CLI_HOME"
}
trap cleanup EXIT
cli() { HOME="$CLI_HOME" python3 "$ROOT/scripts/pacelli.py" "$@"; }

flow() {
  say "maestro $1"
  "$MAESTRO" --device "$SIM" test "$E2E/$1" || fail "flow $1"
  alive "$1"
}

# ── 0. A household of our own ─────────────────────────────────────────
# ERASE, never uninstall: the keychain survives an uninstall, so the guest
# account and everything it owns on the server come back with it.
say "erasing $SIM"
xcrun simctl shutdown "$SIM" 2>/dev/null || true
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl install "$SIM" "$APP"
ok "clean simulator"

# Guest sign-in auto-provisions a household with the guest as created_by — so
# the account driving the UI is the OWNER, which is what the permission screen
# requires. Also seeds the task everything below is measured against.
flow flow_ai_link_01_create.yaml

CODE="$(xcrun simctl pbpaste "$SIM" | tr -d '[:space:]')"
[[ "$CODE" =~ ^[0-9A-Z]{8}$ ]] \
  || fail "pasteboard did not hold an 8-character code (got: '${CODE}')"
cli link "$CODE" >/dev/null || fail "could not redeem the pairing code"
ok "assistant paired: $(cli whoami | head -1)"

cli tasks | grep -qF "$TITLE" \
  || fail "the assistant cannot see '$TITLE' — the household is not set up as expected, and every assertion below would be measuring nothing"
ok "content exists and the assistant can see it"

# ── 1. The owner restricts burning to nobody ──────────────────────────
flow flow_burn_01_restrict.yaml

# ── 2. …and the SERVER refuses, not just the screen ───────────────────
say "the restricted burn must be refused by the server"
cli burn-policy
# `burn --expect-refusal` exits 0 ONLY on a refusal, and prints which it saw.
# Do not restate its diagnosis here — the first version of this line claimed
# "the burn was ALLOWED" for any non-zero exit, and then said exactly that
# about a correct 403 that the CLI had simply died on.
cli burn --expect-refusal || fail "expected the server to refuse the burn — see the CLI output above for what actually happened"
ok "server refused the burn"

# ── 3. A refusal must not have deleted anything ───────────────────────
# The check a status code cannot make. A function that refuses AFTER deleting
# would return 403 and pass a naive test while destroying the household.
say "nothing may have been deleted by the refused call"
cli tasks | grep -qF "$TITLE" \
  || fail "'$TITLE' is GONE after a REFUSED burn — the refusal deleted data"
ok "content untouched"

# ── 4. The owner widens the policy ────────────────────────────────────
flow flow_burn_02_permit.yaml

# ── 5. …and the same call now succeeds ────────────────────────────────
# Paired with step 2 deliberately: a suite that only proves denials passes just
# as well against a server that refuses everything.
say "the same call must now succeed"
cli burn-policy
cli burn --yes-i-mean-it || fail "the burn did not succeed while the policy said everyone — see the CLI output above"

# ── 6. …and the content is actually gone ──────────────────────────────
say "the burn must have deleted the content"
if cli tasks | grep -qF "$TITLE"; then
  fail "'$TITLE' survived a burn the server reported as successful"
fi
ok "content deleted"

# ── 7. Account deletion is available regardless ───────────────────────
# Runs last: it destroys the account everything above authenticated against.
flow flow_burn_03_delete_account.yaml

echo
printf '\033[32mPASS — restricted burn refused by the server and deleted nothing; permitted burn deleted the content; account deletion never gated\033[0m\n'
