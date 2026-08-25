#!/usr/bin/env bash
# Delete the guest account an E2E run created. Called from each driver's EXIT
# trap, so it runs whether the run passed or failed.
#
# Why this exists: the simulator erase at the START of a run wipes the device,
# not Firebase. Every guest sign-in leaves an account, a household, its
# encryption key and its content on the server permanently. 106 of them had
# accumulated by 2026-08-25 — one per run since May, from seven harnesses that
# create a guest and never removed it. Only check_burn_e2e.sh cleaned up, and
# only because deleting the account IS what it tests.
#
# Never fatal. It runs after the assertions that matter, often against an app
# left somewhere unexpected by a failure, and a teardown that turns a passing
# run red — or a failing run confusing — is worse than an orphan. Set
# PACELLI_KEEP_GUEST=1 to skip it and keep the state for debugging.
#
# NEGATIVE-CONTROL: RUN 2026-08-25, all three states. App uninstalled from the
# simulator -> "could not delete the guest account"; MAESTRO pointed at a
# missing binary -> "maestro not found"; PACELLI_KEEP_GUEST=1 -> "leaving the
# guest account in place". All three exit 0, because this must never turn its
# caller red. Prevention itself was measured end to end: anonymous accounts
# before check_feedback_e2e.sh = 8, after a full run that signs in as a guest
# and creates a household = 8. Before this existed it would have gone 8 -> 9.
set -uo pipefail   # deliberately NOT -e: this must never abort its caller

SIM="${1:?usage: teardown_guest.sh <sim-udid>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAESTRO="${MAESTRO:-$HOME/.maestro/bin/maestro}"

if [[ "${PACELLI_KEEP_GUEST:-0}" == "1" ]]; then
  echo "teardown: PACELLI_KEEP_GUEST=1 — leaving the guest account in place"
  exit 0
fi

if [[ ! -x "$MAESTRO" ]]; then
  echo "teardown: maestro not found — guest account left behind"
  exit 0
fi

if "$MAESTRO" --device "$SIM" test "$ROOT/PacelliApp/e2e/flow_zz_teardown.yaml" \
     >/tmp/pacelli_teardown.log 2>&1; then
  echo "teardown: guest account deleted"
else
  # Says which, and does not pretend. sweepAbandonedGuests is the backstop.
  echo "teardown: could not delete the guest account — it will be swept after 14 idle days (see /tmp/pacelli_teardown.log)"
fi
exit 0
