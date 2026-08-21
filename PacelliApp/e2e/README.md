# Maestro E2E flows (iOS Simulator)

Re-runnable UI flows for the native app, written 2026-08-01 while verifying
the tasks feature (edit/delete/subtasks/categories).

```bash
# Build + install on a booted sim first, then:
maestro --device <SIM-UDID> test PacelliApp/e2e/flow_tasks_e2e.yaml
```

- `flow_tasks_e2e.yaml` — guest onboarding → create task → open detail →
  edit priority/notes. (Historical note: typing into the multiline Notes
  field steals focus — later flows avoid it.)
- `flow_tasks_e2e2.yaml` — subtasks add/toggle, category creation.
- `flow_tasks_e2e3.yaml` — continuation experiment (nav-chevron point tap).
- `flow_tasks_e2e4.yaml` — category assignment via picker + Save.
- `flow_tasks_e2e5.yaml` — relaunch persistence check + swipe-to-delete.
- `flow_checklists_e2e.yaml` — checklists tab: create → items add/toggle →
  push-item-as-task (full swipe) → relaunch persistence + cross-feature
  verify (pushed item appears on the Tasks tab).
- `flow_plans_e2e.yaml` — plans tab: weekly plan → day entry → checklist →
  finalise → relaunch persistence.
- `flow_settings_burn_e2e.yaml` — settings: theme switch → privacy screen →
  ⚠️ REAL burn-all-data (wipes the signed-in account — guest/test only) →
  back-to-Welcome.
- `flow_reminders_01_task.yaml` / `_02_settings.yaml` / `_03_grant.yaml` —
  task reminders. Split into three because the runner has to flip SwiftUI
  switches between them (see below). Driven by
  `scripts/check_reminders_e2e.sh`, which owns the fresh install and the
  assertions Maestro cannot make: that iOS accepted the schedule with the
  real task title, and that it actually fired.
- `flow_household_manual_search_e2e.yaml` — members list → manual entry
  create → feedback submit → cross-entity search (task + manual hits).
  Re-runnable (conditional seeding).
- `flow_ai_link_01_create.yaml` / `_02_connected.yaml` — Connect an AI.
  Driven by `scripts/check_ai_link_e2e.sh`, which owns the erase, the
  pasteboard read that carries the code out of Maestro, and every assertion
  involving the CLI: that `scripts/pacelli.py` redeems the code, reads a task
  title the app encrypted, is refused a second use of the same code, and is
  locked out the moment the app disconnects it. **First run found a shipped
  bug** — `tasksList` had 500'd since the API shipped on a missing
  `subtasks(household_id, task_id, sort_order)` composite index, invisible
  because the app queries Firestore directly and sorts client-side.

Lessons (Maestro 2.5.1 + iOS 27 sim):
- `back` (edge swipe) and `hideKeyboard` are unreliable with the keyboard
  up — prefer `stopApp`/`launchApp` between segments; data persists in
  Firestore so relaunch-based flows double as persistence tests.
- `pressKey: Enter` fires `onSubmit` on single-line TextFields (used for
  New task / Add a subtask), but inserts text in multiline fields.
- Text matching is exact (regex), so "Milk" does not match "Milk, eggs".
- A full `swipe` across a row EXECUTES the leading/trailing swipe action
  directly (standard iOS) — don't follow it with a tap on the action label.
  This is about the FULL swipe only. `swipe: {from: <row>, direction: LEFT}`
  merely REVEALS the trailing action and must be followed by a tap on it
  (as in `flow_tasks_e2e5`); reading the line above as covering both cost a
  failed run on `flow_ai_link_02`.
- SwiftUI back buttons have id `BackButton` — `tapOn: id: "BackButton"`
  beats both `back` (flaky edge swipe) and point taps (frame is [16,62]–
  [60,106]pt; a 7%-height tap lands 1pt above it).
- When a screen title repeats a button label, `tapOn: <text>` hits the
  title — give the button an `accessibilityIdentifier` and tap by id.
- SwiftUI List recycles off-screen rows: an assert can't see a row outside
  the viewport — `scrollUntilVisible` to it instead.
- `maestro hierarchy` dumps the accessibility tree with bounds — the fastest
  way to debug a failing tap without screenshots.
- Segmented pickers do NOT render their label text — never assert on it.
- An app killed by a failed run shows a springboard-only hierarchy while its
  process may still be resident — `simctl launch` returns the existing pid
  WITHOUT foregrounding; use stopApp+launchApp to get a deterministic state.

Lessons (reminders, 2026-08-11 — Maestro 2.5.1 + iOS 26.2 sim):
- **Maestro cannot flip a SwiftUI `Toggle` in a `List`.** SwiftUI publishes
  the row as ONE accessibility element spanning its full width, so `tapOn`
  hits the centre — the label — and a List Toggle only responds to a hit on
  the switch itself. The tap reports COMPLETED and nothing happens: no
  @AppStorage write, no state change, no log line, no error. Cost two full
  runs on two different toggles. `tap_switch` in `check_reminders_e2e.sh`
  reads the label's bounds and aims at the trailing edge instead.
- Compute the screen width from the FIRST node with real bounds, not
  `max()` over every node — some accessibility frames extend past the
  screen and put the tap off-canvas, where it also silently does nothing.
- A conditional `runFlow: when: visible: "Allow"` races the async
  `requestAuthorization`: it evaluates before the alert is on screen,
  reports SKIPPED, and the flow fails on the next assertion.
  `extendedWaitUntil` on the alert instead — and anchor the regex, because
  bare `Allow` also matches `Don't Allow`, which denies the app and lets
  the flow pass green.
- Notification authorisation resets to `notDetermined` on
  `simctl uninstall` + `install`. There is no `simctl privacy notifications`
  service — `reminders` in that list is EventKit, not UNUserNotificationCenter.
- The app's `UserDefaults` live in the app DATA CONTAINER, not the
  device-wide preferences domain. `simctl spawn <sim> defaults write
  <bundle-id> ...` writes the device-wide domain, which the app never reads.
- Write prefs through the SIMULATOR's cfprefsd — `simctl spawn <sim>
  defaults write <container-path> ...`. A host-side `plutil -replace` on the
  same file changes the bytes and the running app still sees its cached
  copy. Read them back with `plutil -extract`, though: host `defaults read
  <path> <key>` reports "does not exist" for keys plainly in the file.
- `data/Library/UserNotifications/<uuid>/PendingNotifications.plist` and
  `DeliveredNotifications.plist` are the ground truth for "did iOS accept
  this / did it fire", and both carry the title. Far better than screenshots.
- `set -euo pipefail` + `X="$(grep ... | head -1)"` kills the script with no
  message when grep finds nothing — pipefail propagates grep's exit 1.
  Append `|| true` or you get a silent abort that reads like a hang.

Push (2026-08-11):
- `flow_push_optin.yaml` / `flow_push_grant.yaml` + `scripts/check_push_e2e.sh`
  — the other person adds a task, this device buzzes. One simulator plays the
  recipient; a Firestore write with a different `created_by` plays the other
  member, which is the only way a single device can test a feature whose whole
  point is that SOMEONE ELSE did something.
- The check asserts the negative first: with activity pushes off, nothing must
  arrive. A push feature that ignores its own opt-in passes every other test.
- **Apple Silicon simulators do receive real APNs pushes.** Worth knowing
  before reaching for a physical device — the full FCM → APNs → device chain
  was verified on the simulator.
- `DeliveredNotifications.plist` again beats screenshots: it holds the full
  payload, so `enc_title` and `mutable-content` can be asserted directly.
- `set -euo pipefail` + `X="$(grep ... | wc -l)"` aborts silently when grep
  matches nothing — and "nothing delivered yet" is the NORMAL starting state
  for a push check. Same trap as the reminders script, walked into twice.

Phase C — on-device decryption (2026-08-11):
- `scripts/check_push_decrypt_e2e.sh` — encrypts a title with the household's
  REAL key (unwrapped by deriving the user key from the uid, as a client does)
  and asserts the notification body is the plaintext; then sends a title this
  household cannot open and asserts the body stays generic.
- **Read the archived `body` field, do not grep.** A delivered payload contains
  BOTH the decrypted title and the generic fallback (the latter as the original
  request), so `grep "Buy milk"` passes on a broken extension. Parse the
  NSKeyedArchiver plist and read the value under the `body` key.
- The simulator does NOT enforce entitlements, so this proves decryption but
  not keychain access-group isolation. That needs a device.
- `UID` is a read-only shell variable — `UID=$(...)` silently keeps 501 and
  every downstream command gets the wrong value. Name it anything else.

Localised push bodies (2026-08-11):
- The body is an APNs `loc-key`; a Cloud Function is a trigger, not a session,
  and has no idea what language the recipient reads. iOS resolves the key
  against the app's own compiled strings.
- **A missing loc-key does not degrade — iOS DROPS the notification entirely**,
  silently, with no error on either side. An incremental build that skipped
  recompiling the String Catalog was enough to cause it: pushes just stopped
  arriving. `check_push_e2e.sh` step 0 now asserts the keys are in the built
  bundle before testing anything else.
- The Admin SDK spells it `locKey` (camelCase) and maps it to the wire's
  `loc-key`; writing the wire spelling is a TypeScript error.
- Loc-keys need an explicit `en` value. The key is an identifier, not English
  text, so without one an English reader sees "push_task_created".
