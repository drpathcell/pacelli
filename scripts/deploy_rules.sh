#!/usr/bin/env bash
# The only sanctioned way to deploy firestore.rules.
#
# Runs the rules test suite, then the deploy guard, then the deploy. Every one
# of those has been the missing step at least once:
#
#   tests    — rules have shipped that the suite would have caught
#   guard    — twice a rules change went out that the LIVE build could not
#              satisfy; see scripts/check_rules_deploy.py for both dates
#   deploy   — the part everybody remembers
#
# NEGATIVE-CONTROL: put a `requires-live-version:` header above the live
# version in firestore.rules and this script must stop before `firebase
# deploy`. RUN on 2026-08-25 with 99.0.0.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "── rules tests ──"
(cd firestore-tests && npm test)

echo
echo "── deploy guard ──"
python3 scripts/check_rules_deploy.py

# /usr/local/bin/firebase is an x86_64 standalone that this Mac cannot run
# ("Bad CPU type in executable", 2026-09-22). Fall back to the npm CLI, which
# is what both the 1.11.1 function deploy and this one actually used.
FB=(firebase)
if ! firebase --version >/dev/null 2>&1; then
  echo "(firebase binary unusable here; using npx firebase-tools)"
  FB=(npx -y firebase-tools@latest)
fi

echo
echo "── deploy ──"
"${FB[@]}" deploy --only firestore:rules
