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

Lessons (Maestro 2.5.1 + iOS 27 sim):
- `back` (edge swipe) and `hideKeyboard` are unreliable with the keyboard
  up — prefer `stopApp`/`launchApp` between segments; data persists in
  Firestore so relaunch-based flows double as persistence tests.
- `pressKey: Enter` fires `onSubmit` on single-line TextFields (used for
  New task / Add a subtask), but inserts text in multiline fields.
- Text matching is exact (regex), so "Milk" does not match "Milk, eggs".
- A full `swipe` across a row EXECUTES the leading/trailing swipe action
  directly (standard iOS) — don't follow it with a tap on the action label.
- SwiftUI back buttons have id `BackButton` — `tapOn: id: "BackButton"`
  beats both `back` (flaky edge swipe) and point taps (frame is [16,62]–
  [60,106]pt; a 7%-height tap lands 1pt above it).
- When a screen title repeats a button label, `tapOn: <text>` hits the
  title — give the button an `accessibilityIdentifier` and tap by id.
- SwiftUI List recycles off-screen rows: an assert can't see a row outside
  the viewport — `scrollUntilVisible` to it instead.
- `maestro hierarchy` dumps the accessibility tree with bounds — the fastest
  way to debug a failing tap without screenshots.
