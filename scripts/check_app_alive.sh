#!/usr/bin/env bash
# Is the app still running, and did it crash while we were not looking?
#
# Build 46 shipped a crash that killed the app seconds after every photo was
# attached, and the photo E2E was green for it. Not because a flow was wrong —
# because `flow_photo_01` ended at its own success and `flow_photo_02` opens
# with `stopApp`, so the corpse was cleared away by the next flow before
# anything looked at it.
#
# The static shape of a flow cannot catch that. "tap Done, assert the
# thumbnail" and "tap Settings, assert Privacy" are the same three steps; only
# meaning separates the work from a liveness poke, and meaning is not
# greppable. What IS mechanical is asking the simulator whether the process is
# still there. So the drivers ask, after every flow.
#
#   ./scripts/check_app_alive.sh <SIM_UDID> [BUNDLE] [context]
#
# NEGATIVE-CONTROL: find the host pid with `ps ax | grep PacelliApp.app` and
# send it SIGSEGV, then run this — it must go red, once for the missing
# process and, after relaunching the app with a stamp older than the report,
# again for the crash report. Both were run on 2026-08-24 before this was
# wired into anything, and the second one is why branch 2 exists in the form
# it does: two earlier versions of it could not fire at all.
set -euo pipefail

SIM="${1:?usage: check_app_alive.sh <SIM_UDID> [BUNDLE] [context]}"
BUNDLE="${2:-com.pacelli.pacelli}"
CONTEXT="${3:-}"

RED=$'\033[31m'; GREEN=$'\033[32m'; OFF=$'\033[0m'
where() { [[ -n "$CONTEXT" ]] && printf ' (after %s)' "$CONTEXT"; }

fail() {
  printf '%sFAIL: %s%s%s\n' "$RED" "$1" "$(where)" "$OFF" >&2
  exit 1
}

# ── 1. the process ──────────────────────────────────────────────────────────
# `launchctl list` prints "PID  STATUS  LABEL". A live app has a real pid; one
# that died leaves "-" and the exit status that killed it.
ROW="$(xcrun simctl spawn "$SIM" launchctl list 2>/dev/null \
       | grep -F "UIKitApplication:$BUNDLE" | head -1 || true)"

[[ -n "$ROW" ]] || fail "$BUNDLE is not running at all — nothing for the next flow to test"

PID="$(printf '%s' "$ROW" | awk '{print $1}')"
STATUS="$(printf '%s' "$ROW" | awk '{print $2}')"

if [[ "$PID" == "-" ]]; then
  fail "$BUNDLE has no pid — it exited with status $STATUS. If that status is a
      signal, the app crashed and the flow that just passed did not notice."
fi
[[ "$STATUS" == "0" ]] || fail "$BUNDLE is running as pid $PID but its last exit status was $STATUS"

# ── 2. the crash reports ────────────────────────────────────────────────────
# The process check alone can be fooled: iOS relaunches an app, so a flow that
# ends after a relaunch shows a healthy pid sitting on top of a fresh crash.
# Ask the crash reports too.
#
# They are written to the HOST's DiagnosticReports, NOT the simulator's own
# CrashReporter directory. The first version of this looked in the simulator,
# found an empty folder, and would have been dead code that could never fire.
# The path was settled by crashing the app on purpose and following the report:
# ~/Library/Logs/DiagnosticReports/PacelliApp-*.ips, with the bundle id inside.
#
# The SECOND version could not fire either, for a better reason. It used
# `find -newermt "@$EPOCH"`, which is GNU syntax; BSD find on macOS answers
# "Can't parse date/time: @1787561228", and that message went to /dev/null
# while `|| true` ate the exit status. A crash check that silently matched
# nothing, inside the script written to catch silent failures. So the baseline
# is a STAMP FILE and `-newer`, which both finds understand, and nothing here
# is redirected or defaulted away.
#
# The driver creates the stamp once, before its first flow. Historical reports
# must not count — there are real ones in there from build 46's Vision crash on
# 2026-08-22, and without a baseline this would be red forever and then be
# switched off.
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
STAMP="${PACELLI_CRASH_BASELINE:-}"

if [[ -n "$STAMP" ]]; then
  [[ -f "$STAMP" ]] || fail "PACELLI_CRASH_BASELINE=$STAMP does not exist.
      It must be a stamp file the driver touched before its first flow; a
      missing one would make this check match nothing and pass forever."

  if [[ -d "$CRASH_DIR" ]]; then
    NEW="$(find "$CRASH_DIR" -maxdepth 1 -type f -name '*.ips' -newer "$STAMP" \
           | xargs grep -l -F "$BUNDLE" 2>/dev/null || true)"
    if [[ -n "$NEW" ]]; then
      FIRST="$(printf '%s' "$NEW" | head -1)"
      SIG="$(grep -oE '"signal":"[A-Z]+"' "$FIRST" | head -1 || true)"
      printf '%sFAIL: %s crashed during this run%s — %s%s\n' \
        "$RED" "$BUNDLE" "$(where)" "${SIG:-signal unknown}" "$OFF" >&2
      printf '%s\n' "$NEW" >&2
      exit 1
    fi
  fi
fi

printf '%sOK: %s alive as pid %s%s%s\n' "$GREEN" "$BUNDLE" "$PID" "$(where)" "$OFF"
