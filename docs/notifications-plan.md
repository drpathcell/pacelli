# Pacelli notifications — design & delivery plan

Target: **1.3.0**. Agreed scope (2026-08-11): full push with on-device
decryption, triggering on task due reminders, someone joining the household,
and a new task being added or assigned.

## The one idea that makes this work

Pacelli is end-to-end encrypted — the server cannot read a task title, so it
can never compose "Chloe added: Buy milk".

It doesn't have to. **The Cloud Function copies the already-encrypted title
straight out of Firestore into the APNs payload.** The server moves ciphertext
it already holds and never decrypts anything; the Notification Service
Extension on the recipient's device unwraps it with the household key and
rewrites the notification body before iOS displays it.

    Firestore  tasks/{id}.title = "base64(iv||ct)"   ← already encrypted at rest
        │
        ▼  Cloud Function (reads the ciphertext, does NOT decrypt)
    APNs payload { mutable-content: 1,
                   alert.body: "New task in your household",   ← safe fallback
                   enc_title: "base64(iv||ct)", household_id, task_id }
        │
        ▼  Notification Service Extension (on device, has the household key)
    Lock screen: "Buy milk"

If the extension can't decrypt — key not cached yet, first launch, 30s budget
blown — iOS displays the generic body it arrived with. **Failure degrades to
the privacy-safe text, never to a blank or a crash.** That fallback is the
reason this design is safe to ship.

## Phases

### Phase A — local notifications — DONE (1.3.0, build 39)

Delivers the core value on its own and ships even if push slips.

- `NotificationService` over `UNUserNotificationCenter`.
- Schedule on task create/edit, cancel on complete/delete, reconcile on
  foreground (a reminder must not fire for a task someone else finished).
- Settings: on/off, timing (day before / morning of), and a **time of day**.
- Permission asked when the user first sets a due date or enables reminders —
  never at launch. Guest-first stays intact.

**Due dates are date-only.** `TaskDetailView` uses
`DatePicker(displayedComponents: .date)`, so "at due" means 00:00 — a useless
3am buzz. The time-of-day preference is not polish, it is what makes local
reminders usable. Either add it, or drop the "at due" option entirely.

**iOS allows ~64 pending local notifications per app.** Schedule the nearest N
by due date and top up on launch and on every mutation.

### Phase B — push transport — DONE (2026-08-11, untagged on main)

- Push Notifications capability on the App ID; `aps-environment` entitlement;
  match profiles regenerated.
- `FirebaseMessaging` added from the existing `firebase-ios-sdk` SPM pin (12.15.0).
- `device_tokens/{token}`: `{ user_id, household_id, platform, updated_at }`.
  Rules: create/update/delete only where `user_id == request.auth.uid`; no list.
  Token registered on launch and on refresh; **deleted on sign-out and on burn**
  — a stale token keeps pushing a household's activity to a device that has
  been signed out of it.
- Cloud Functions:
  - `onCreate tasks/{id}` → notify household members except the author.
  - `onCreate household_members/{id}` → "Someone joined your household".
    Non-sensitive, no encrypted content in the body.
- Every body generic; entity IDs in the payload for deep linking — the standing
  standard in the pacelli-security-audit skill.

### Phase C — on-device decryption (the NSE) — BUILT & PROVEN, not yet shippable

- App Group + **Keychain access group**, so the extension can read
  `hk_<householdId>`.
- `SecureStore` gains `kSecAttrAccessGroup` and migrates existing items:
  read via the old query, rewrite into the access group. Low risk —
  `KeyManager.loadHouseholdKey` already falls back to Firestore on a cache
  miss, so a failed migration self-heals rather than showing "[encrypted]".
- New extension target in `project.yml`, linking `PacelliKit` (already a SPM
  package, so `PacelliCrypto` is reusable as-is — no crypto is reimplemented).
- Extension decrypts `enc_title`, rewrites `bestAttemptContent.body`, falls
  back to the generic body on any failure or timeout.

## What only Juan could do — DONE 2026-08-11

APNs key `TJ273J69AU` created (Sandbox & Production, Team Scoped) and uploaded
to both Firebase slots. See `docs/apns-key-runbook.md`. Original notes below.

## What only Juan can do

1. **Create an APNs auth key** — developer portal → Certificates, Identifiers &
   Profiles → Keys → new key with Apple Push Notifications service enabled.
   Download the `.p8` (one-time download — it cannot be re-downloaded) and note
   the Key ID. There is no public App Store Connect API for creating this.
   *The `AuthKey_MMWTC97VR7.p8` already on the Mac is the ASC API key — a
   different thing, it will not work for push.*
2. **Upload that `.p8` to Firebase** → Project Settings → Cloud Messaging →
   APNs Auth Key, with the Key ID and Team ID.

Everything else — the capability on the App ID (ASC API `bundleIdCapabilities`),
entitlements, code, functions, rules, tests — is scriptable from here.

## Risks and open decisions

- **Widening the keychain to an access group is a real security change.** The
  household key becomes readable by a second process. It needs a
  pacelli-security-audit addendum before shipping, not after.
- **Ciphertext transits Apple's servers** in the payload. It is encrypted with
  the household key, which Apple never has, so exposure is nil — but it should
  be stated explicitly in the Privacy & Encryption screen, whose claims must
  stay literally true.
- **Payload budget is 4KB.** Fine for titles; if a description is ever added,
  truncate the ciphertext rather than dropping the notification.
- **Notification noise for two people sharing one list.** "New task added"
  will fire often. Suggest defaulting it off and letting it be switched on,
  rather than the reverse.
- **Burn-all-data must cancel every pending local notification and delete the
  device token**, or a wiped account keeps buzzing. Add it to the burn
  checklist and to the audit.

## Gates — status

- [x] Rules tests for `device_tokens` (self-only, not listable) — 14 tests.
- [x] E2E: the other person adds a task, this device buzzes —
      `scripts/check_push_e2e.sh`, which asserts the opt-in negative first.
- [x] pacelli-security-audit addendum — `AUDIT_2026-08-11_push_addendum.md`.
- [x] Phase C: NSE decrypt test (`scripts/check_push_decrypt_e2e.sh`, both
      directions) + audit addendum (`AUDIT_2026-08-11_phasec_addendum.md`).
- [ ] Phase C signing: App ID `com.pacelli.pacelli.NotificationService` +
      match appstore profile (needs the certs repo writable). Until then the
      extension exists only in simulator builds.
- [ ] Access-group ISOLATION on a device — the simulator does not enforce
      entitlements, so decryption is proven but the boundary is not.
- [ ] Push bodies are English regardless of the user's language. Fix is
      `loc-key`/`title-loc-key` in the APNs payload so iOS localises from the
      app's own strings.

Note: the payload round-trip test named below is superseded — the delivered
payload was inspected directly and carried `enc_title` verbatim.

## Original gates before shipping 1.3.0

- Rules tests for `device_tokens` (self-only, not listable).
- A PacelliKit test that a payload ciphertext round-trips through
  `PacelliCrypto` exactly as the extension will do it.
- E2E: two accounts, one device — task created on A appears as a decrypted
  notification for B, and a failed decrypt still shows the generic body.
- pacelli-security-audit addendum covering the access group, the token
  lifecycle, and the payload contents.
