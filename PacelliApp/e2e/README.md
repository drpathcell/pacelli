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

Lessons (Maestro 2.5.1 + iOS 27 sim):
- `back` (edge swipe) and `hideKeyboard` are unreliable with the keyboard
  up — prefer `stopApp`/`launchApp` between segments; data persists in
  Firestore so relaunch-based flows double as persistence tests.
- `pressKey: Enter` fires `onSubmit` on single-line TextFields (used for
  New task / Add a subtask), but inserts text in multiline fields.
- Text matching is exact (regex), so "Milk" does not match "Milk, eggs".
