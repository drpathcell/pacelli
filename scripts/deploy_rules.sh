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

echo
echo "── deploy ──"
firebase deploy --only firestore:rules
