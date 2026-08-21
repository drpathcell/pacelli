#!/usr/bin/env bash
# Connect an AI end-to-end check (iOS Simulator + the real CLI).
#
# Proves the whole pairing chain against real Firebase rather than in unit
# tests:
#
#   app mints a code -> CLI redeems it -> the assistant reads a task title
#   the app wrote, IN PLAINTEXT -> the app lists the assistant -> the app
#   disconnects it -> the assistant can no longer read anything.
#
# The plaintext read is the assertion that matters. A uid that did not exist
# when "Water the plants" was encrypted cannot decrypt it unless the code was
# redeemed, the member row written, and the household key wrapped for that uid
# and unwrapped again. Nothing short of the full chain produces it.
#
# Two negative controls run BEFORE the pass is believed, because a harness
# that has never been seen to fail is not evidence of anything:
#
#   1. the same code is redeemed twice — the second must be refused
#   2. the CLI is exercised again after disconnect — it must be refused
#
# Maestro drives the UI (PacelliApp/e2e/flow_ai_link_0{1,2}_*.yaml).
# Everything Maestro cannot do lives here: the erase, the pasteboard read,
# and every assertion that involves the CLI.
#
#   ./scripts/check_ai_link_e2e.sh [--sim UDID] [--app PATH]
#
# Exits non-zero with a named FAIL on the first broken link.
set -euo pipefail

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/pacelli_dd/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
TITLE="Water the plants"
LABEL="E2E laptop"
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
fail() { printf '\033[31mFAIL: %s\033[0m\n' "$*" >&2; exit 1; }
ok()   { printf '\033[32mOK: %s\033[0m\n' "$*"; }

[[ -d "$APP" ]]     || fail "app bundle not found: $APP (build it first)"
[[ -x "$MAESTRO" ]] || fail "maestro not found at $MAESTRO"

# The CLI keys its credentials off $HOME. Pointing it at a scratch directory
# is not tidiness — without it this script silently destroys the operator's
# own pairing in ~/.config/pacelli/credentials.json.
CLI_HOME="$(mktemp -d)"

# A failed run used to leave the assistant it had just paired attached to the
# household forever: the erase wipes the simulator, not the server, so every
# iteration added another ghost member. `disconnect-self` is a no-op once the
# happy path has already revoked it.
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
}

# ── Fresh device ──────────────────────────────────────────────────────
# ERASE, never uninstall. The keychain survives an uninstall, so the guest
# account and everything it owns on the server come back with it — and this
# flow asserts that nothing is connected yet.
say "erasing $SIM"
xcrun simctl shutdown "$SIM" 2>/dev/null || true
xcrun simctl erase "$SIM"
xcrun simctl boot "$SIM"
xcrun simctl bootstatus "$SIM" -b
xcrun simctl install "$SIM" "$APP"
ok "clean simulator"

# ── 1. Mint a code ────────────────────────────────────────────────────
flow flow_ai_link_01_create.yaml

CODE="$(xcrun simctl pbpaste "$SIM" | tr -d '[:space:]')"
[[ "$CODE" =~ ^[0-9A-Z]{8}$ ]] \
  || fail "pasteboard did not hold an 8-character code (got: '${CODE}')"
ok "code on the pasteboard: $CODE"

# ── 2. Redeem it as the assistant would ───────────────────────────────
say "redeeming with scripts/pacelli.py"
cli link "$CODE" || fail "link refused a fresh code"
ok "paired"

# THE assertion.
say "reading the household as the assistant"
OUT="$(cli tasks)" || fail "assistant could not list tasks"
grep -qF "$TITLE" <<<"$OUT" \
  || fail "assistant did not see '$TITLE' in plaintext — got: $OUT"
grep -q "\[encrypted\]" <<<"$OUT" \
  && fail "assistant read ciphertext — the household key was not wrapped for it"
ok "assistant decrypted '$TITLE'"

# A missing composite index shows up as a 500 on the ONE endpoint that needs
# it, so the read surface has to be walked rather than sampled. `tasksList`
# had been dead since the API shipped and nothing noticed, because the app
# queries Firestore directly and sorts client-side — only an assistant
# driving the REST API ever hits those queries.
say "walking the rest of the read surface"
cli whoami     >/dev/null || fail "tasksStats refused"
cli checklists >/dev/null || fail "checklistsList refused"
cli plans      >/dev/null || fail "plansList refused"
ok "read surface clean"

# ── Negative control 1: single use ────────────────────────────────────
# If this passes, the code is not a one-shot secret and the whole trust model
# is weaker than the screen claims.
say "negative control: redeeming the same code twice"
SECOND_HOME="$(mktemp -d)"
if HOME="$SECOND_HOME" python3 "$ROOT/scripts/pacelli.py" link "$CODE" \
     >/dev/null 2>&1; then
  rm -rf "$SECOND_HOME"
  fail "a used pairing code was accepted a second time"
fi
rm -rf "$SECOND_HOME"
ok "used code refused"

# ── Negative control 3: no self-propagation ───────────────────────────
# An assistant is a household member, and the rules judge membership by the
# member doc existing, not by its role. Without the role check in createLink
# an assistant could mint a second assistant and keep it after the first was
# revoked — which would quietly undo revocation.
say "negative control: an assistant connecting another assistant"
ESC_OUT="$(cli connect-another "escalation probe" 2>&1)" && \
  fail "an assistant minted another assistant: $ESC_OUT"
# Assert on the REASON, not merely on a non-zero exit. A control that passes
# on any failure passes when the network is down, the token is stale or the
# subcommand is misspelled — it would be a red harness lying, which is the
# same disease as a green one.
grep -q "cannot connect another assistant" <<<"$ESC_OUT" \
  || fail "refused, but not for the expected reason: $ESC_OUT"
ok "assistant self-propagation refused, for the right reason"

# ── 3. The app sees it, and cuts it off ───────────────────────────────
flow flow_ai_link_02_connected.yaml

# ── Negative control 2: revocation actually revokes ───────────────────
# Deleting the membership row alone would leave this passing for up to an
# hour on the CLI's cached ID token. It must fail immediately.
say "negative control: reading after disconnect"
if cli tasks >/dev/null 2>&1; then
  fail "the assistant still has access after being disconnected"
fi
ok "assistant locked out"

printf '\n\033[32mPASS — pair, read, list, disconnect, lock out\033[0m\n'
