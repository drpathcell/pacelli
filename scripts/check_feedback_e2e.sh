#!/usr/bin/env bash
# Feedback end-to-end check: a stranger sends it, WE can read it.
#
# This exists because the app was perfectly capable of sending feedback for
# months while nobody could read a word of it. "Thank you!" on screen proves
# nothing; the only assertion worth making is that the message comes back out
# in plaintext at our end.
#
#   ./scripts/check_feedback_e2e.sh [--sim UDID] [--app PATH]
#
# Fresh install => brand-new anonymous account => genuinely a stranger.
#
# NEGATIVE-CONTROL: point `read_feedback.py` at a different collection and
# step 3 must fail with "never came back in plaintext". The read-back half is
# the half that was broken, so it is the half that has to be falsifiable.
set -euo pipefail
trap 'rc=$?; [[ $rc -ne 0 ]] && printf "\033[31maborted at line $LINENO (exit $rc)\033[0m\n" >&2' ERR

SIM="${SIM:-EA8C6A85-98F9-43AE-A0EE-338D5F1526B6}"
APP="${APP:-/tmp/dd_pacelli/Build/Products/Debug-iphonesimulator/PacelliApp.app}"
BUNDLE="com.pacelli.pacelli"
MAESTRO="$HOME/.maestro/bin/maestro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# A nonce, so the assertion can only pass on THIS submission. Without it an
# older entry in the collection would make a broken run look green.
NONCE="$(python3 -c "
import datetime
print(datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))")"
MESSAGE="e2e feedback check $NONCE"

say "1/4  Fresh install — a brand-new anonymous account is a real stranger"
xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install  "$SIM" "$APP"
# Keychain survives an uninstall on the simulator, so any restored session
# would make this a returning user rather than a stranger.
xcrun simctl keychain "$SIM" reset >/dev/null 2>&1 \
  && ok "keychain reset — no session carried over" \
  || echo "note: could not reset the keychain; a restored session may persist"

say "2/4  Send feedback through the UI as that stranger"
"$MAESTRO" --device "$SIM" test -e MESSAGE="$MESSAGE" \
  "$ROOT/PacelliApp/e2e/flow_feedback_e2e.yaml" || fail "flow_feedback_e2e"
ok "app reported the feedback sent"

say "3/4  Read it back — the half that was broken"
FOUND=""
for _ in $(seq 1 10); do
  OUT="$(python3 "$ROOT/scripts/read_feedback.py" --limit 10 --json 2>/dev/null || true)"
  if printf '%s' "$OUT" | python3 -c "
import json, sys
rows = json.load(sys.stdin)
print('yes' if any(r.get('message') == '''$MESSAGE''' for r in rows) else 'no')
" 2>/dev/null | grep -q yes; then FOUND=1; break; fi
  sleep 3
done
[[ -n "$FOUND" ]] || fail "sent, but \"$MESSAGE\" never came back in plaintext"
ok "read back in plaintext"

say "4/4  Check the rest of the envelope survived"
# $ROOT is passed in: inside a heredoc __file__ is "<stdin>", so deriving the
# path from it silently resolves somewhere else entirely.
python3 - "$MESSAGE" "$ROOT" <<'PY'
import json, subprocess, sys
msg, root = sys.argv[1], sys.argv[2]
rows = json.loads(subprocess.run(
    [sys.executable, f"{root}/scripts/read_feedback.py", "--limit", "10", "--json"],
    capture_output=True, text=True, check=True).stdout)
r = next(r for r in rows if r.get("message") == msg)
problems = []
if not r.get("readable"):          problems.append("entry not readable")
if r.get("email") != "stranger@example.com":
    problems.append(f"reply address lost: {r.get('email')!r}")
if not r.get("is_guest"):          problems.append("not recorded as a guest")
if not (r.get("app_version") or "").strip(): problems.append("no app version")
if not (r.get("os") or "").startswith("iOS"): problems.append(f"bad os: {r.get('os')!r}")
if problems:
    sys.exit("\033[31mFAIL: " + "; ".join(problems) + "\033[0m")
print(f"\033[32mOK: reply-to {r['email']} · {r['app_version']} · {r['os']} · "
      f"{r['locale']} · {'guest' if r['is_guest'] else 'signed in'}\033[0m")
PY

printf '\n\033[32mA stranger can send feedback and we can read it.\033[0m\n'
