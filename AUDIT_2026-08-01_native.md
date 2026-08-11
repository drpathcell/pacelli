# Security & Encryption Audit — Native SwiftUI Surface

**Date:** 2026-08-01 · **Scope:** `PacelliApp/` @ `af8cba8` (build 29) ·
**Skill:** pacelli-security-audit · **Trigger:** overdue since phases 2–4;
new encryption call sites landed with the tasks feature.

**Verdict: PASS.** No CRITICAL/HIGH/MEDIUM findings. Open items are
pre-existing backlog, listed at the end.

## Phase 1 — Crypto correctness: PASS (verbatim)

`PacelliKit/Sources/PacelliKit/Crypto/PacelliCrypto.swift`:

- [PASS] AES-256-CBC + PKCS7 via CommonCrypto (`aesCBC`, kCCAlgorithmAES +
  kCCOptionPKCS7Padding)
- [PASS] Wire format `base64(iv_16 || ct)`; decrypt splits `prefix(16)`
- [PASS] Fresh IV per encrypt via `SecRandomCopyBytes` (precondition on rc)
- [PASS] `combined.count >= 17` guard (`ciphertextTooShort`)
- [PASS] Keys 64-char lowercase hex; `generateHouseholdKey()` uses
  `SecRandomCopyBytes(32)` + `hexEncode`
- [PASS] v2 extract `HMAC-SHA256(key:"pacelli_hkdf_salt_v2", msg:uid)`;
  expand `HMAC-SHA256(key:PRK, msg:"pacelli_e2e_user_key_v2" || 0x01)` —
  counter byte present
- [PASS] v1 legacy `"pacelli_e2e_key_derivation_v1"`;
  `decryptKeyWithMigration` tries v2 → v1
- [PASS] `encryptNullable` nil/empty short-circuit (PointyCastle parity)
- [PASS] `decryptNullable` → `"[encrypted]"` on failure, never raw ciphertext
- [PASS] **Gate:** `swift test` 22/22 (2026-08-01, includes cross-language
  vector suites both directions)

## Phase 2 — Field encryption coverage: PASS

All call sites (`grep PacelliCrypto\.` over `Sources/`):

- [PASS] tasks.title/description — encrypted on create (`TasksRepository:51`)
  AND partial update (`:93,:96`); decrypted on read (`:26,:29`)
- [PASS] subtasks.title — encrypted (`SubtasksRepository:73`); decrypted in
  both fetch paths (`:25,:46`)
- [PASS] task_categories.name — encrypted (`CategoriesRepository:53`);
  decrypted (`:24`)
- [PASS] households.name (`HouseholdService:27,:87`), profiles.full_name
  backfill (`:61`, runs in `createHousehold`)
- [PASS] Structural plaintext (correct, matches Dart contract): ids,
  household_id, status, priority, dates, booleans, sort_order, icon, color
- Note: `updateTask` supports explicit clears (`String??` → NSNull) — a
  superset of the Dart API; resulting doc shape identical to create-with-null.

## Phase 3 — Firestore rules: PASS

- [PASS] `isMember` = exists() on deterministic
  `household_members/{uid}_{householdId}` (rules:7-10)
- [PASS] tasks (:78), subtasks (:84), task_categories (:90) all
  `isMember(resource.data.household_id)`; create checks
  `request.resource.data.household_id`
- [PASS] household_id denormalized on every native write (models' `toMap`)
- [PASS] household_keys (:70): read/update/delete gated on own `user_id`;
  doc carries only encrypted_key + metadata
- [PASS] Default deny `/{document=**}` (:204)
- [PASS] Membership-before-write: native `createHousehold` commits household
  + member doc in one batch before any feature write; `getCurrentHousehold`
  probes membership first (build 10→11 lesson honoured)
- [PASS] Queries are equality-only (household_id, task_id, user_id) —
  served by single-field index merging; identical shapes ran in the Dart app

## Phase 4 — Keychain, auth, guest mode: PASS

- [PASS] SecureStore service `com.pacelli.pacelli`, account `hk_<id>`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, delete-before-add
- [PASS] `deleteAll()` clears service-wide; `KeyManager` is an actor;
  `clearKeys()` clears memory + Keychain and runs on sign-out/reset
- [PASS] SIWA fresh random nonce, SHA-256 hashed (AuthService:24,:32)
- [PASS] Google clientID from `FirebaseApp.app()?.options.clientID` (:76);
  no secrets in Sources/ (URL scheme = public reversed client id)
- [PASS] Guest upgrade via `current.link(with: credential)` (:117) — same
  uid/household/keys preserved
- [PASS] `resetSession()` deadline-bound restore, no stranded anon session
- [PASS] No prints of keys/tokens/decrypted content. DEBUG-only sim hook
  prints the debug email; compiled out of Release (`#if DEBUG`). LOW/accepted.

## Phase 6 — Platform: PASS

- [PASS] Entitlements minimal: `com.apple.developer.applesignin` only
- [PASS] No ATS exceptions in Info.plist (only CFBundleIconName + Google
  URL scheme)
- [PASS] GoogleService-Info.plist: project identifiers only

## Phase 5 — [NOT BUILT] (acceptance criteria on file, not failures)

burn-all-data · notifications privacy · export/import · privacy&encryption
screen · local store encryption-at-rest. Hold ports to the criteria in the
skill when they land.

## Open items (backlog, pre-existing)

1. **Face ID gating** on Keychain reads — rewrite plan calls for it;
   usage string already shipped. (LOW)
2. **Google sign-in button branding** — placeholder bordered style; swap to
   brand-compliant asset before App Store submit. (LOW, ASC-gate)
3. KeyManager caches one household key at a time — fine for the single-
   household UX; revisit if multi-household lands. (INFO)

## Addendum — settings/burn surface (build 32, same day)

Delta audit for the settings module (KeyManager, AuthService and burn
surface changed after the main audit):

- [PASS] `KeyManager.deleteKeyFromFirestore` deletes only docs matching
  `household_id` + own `user_id` — within the household_keys rule.
- [PASS] AuthService re-auth paths (email/Apple/Google): credentials are
  transient, never persisted or logged; the password prompt clears its
  state after use.
- [PASS] `BurnService` meets the Phase 5 acceptance criteria: batched ≤400
  with ×3 backoff retry; member+household docs deleted LAST; orphan sweep
  and final verification are SERVER-source; fails loudly with Retry; UI
  warns about Drive files and household-wide effect. Guest fallback: a
  stale anonymous session that can't be deleted is signed out and
  abandoned (holds no data) — logged, not hidden.
- [PASS] Privacy & Encryption screen lists match Phase 2 exactly (incl.
  quantities/icons/colours as NOT encrypted); prose claims verified
  against PacelliCrypto/KeyManager behaviour.
- [PASS] Burn E2E executed for real on sim guest account 2026-08-01:
  full wipe verified server-side, app returned to Welcome, fresh guest
  provisioning confirmed after.
- [NOT BUILT] notification cancellation, local-store deletion — no-ops
  today; wire into BurnService when those subsystems land.

## Addendum 2 — invite key handshake (build 33)

New crypto-adjacent surface: `MembershipService.inviteByEmail` wraps the
household key with `deriveUserKey(lowercased email)` and stores it on the
invite doc; acceptance unwraps and re-wraps for the joiner's uid.

Honest analysis: anyone who can READ an invite doc can unwrap that key
(the email is in the same doc). Per firestore.rules, readers are household
members (who already hold the key) and the invited email (the intended
recipient) — no privilege escalation among clients. The Firestore
operator could also do this, but that is NOT a new weakness: the baseline
design derives user keys deterministically from uids the server already
knows, so operator-level access was never in the threat model. The
handshake fixes a real availability bug (Flutter's shareKeyWithMember had
no callers — invited members could never decrypt) at equivalent trust.
Invite docs should be revoked (deleted) when unused — the UI exposes
revoke; consider TTL cleanup later. [PASS with note]
