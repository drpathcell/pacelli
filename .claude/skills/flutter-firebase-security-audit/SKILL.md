---
name: flutter-firebase-security-audit
description: >
  Comprehensive security audit for any Flutter app that uses Firebase (Firestore, Auth, Storage).
  Covers Firestore security rules, client-side encryption, data wipe flows, export/import security,
  notification privacy, Android/iOS platform hardening, and OAuth configuration.
  Use this skill whenever the user asks to audit, review, harden, or assess the security of a
  Flutter+Firebase app — even if they just say "check security" or "are we safe from hacking".
---

# Flutter + Firebase Security Audit

A reusable security audit checklist for Flutter applications backed by Firebase. This skill is app-agnostic — adapt each section to the specific app's data model, features, and architecture.

## How to Use This Skill

1. **Discover the app's architecture** — read the app's README, CLAUDE.md, or main entry point to understand: what data is stored, where (Firestore collections, local DB, secure storage), and what sensitive features exist (auth, exports, notifications, file uploads).
2. **Walk through each phase below**, skipping any that don't apply (e.g., skip Phase 3 if the app has no encryption).
3. **Log findings** as `[PASS]`, `[FAIL]`, or `[KNOWN ISSUE]` with file and line number.
4. **Prioritise fixes**: Firestore rules > encryption flaws > auth issues > data leaks > platform hardening.

---

## Phase 1: Firestore Security Rules

Firestore rules are the single most important security surface. A misconfigured rule can expose your entire database to any authenticated (or unauthenticated) user.

### 1.1 Rule structure
- [ ] Rules file exists (`firestore.rules`) and is deployed
- [ ] Default rule is **deny all** — no open `allow read, write: if true` at the root
- [ ] Each collection has explicit read/write rules

### 1.2 Ownership verification
For each Firestore collection, verify:
- [ ] **Parent collections** (top-level entities): rules check that the requesting user is a member/owner of the resource. The standard pattern: store a `household_id`, `team_id`, or `owner_uid` on every document and verify membership via a helper function.
- [ ] **Child collections** (subcollections or related docs): rules verify membership on the *child* document, not just the parent. A common vulnerability is using `request.auth != null` (any logged-in user) instead of checking actual ownership.
- [ ] **Denormalization check**: if child documents reference a parent, ensure the ownership field (e.g., `household_id`) is denormalized onto the child so rules can check it without cross-document reads.

### 1.3 Write validation
- [ ] Create rules validate required fields are present
- [ ] Update rules prevent changing ownership fields (e.g., `household_id` cannot be modified after creation)
- [ ] Delete rules are appropriately restricted (not just "any authenticated user")

### 1.4 Invite / sharing rules
If the app has invite or sharing functionality:
- [ ] Read: only the invited user or existing members can read invites
- [ ] Create: only members can create invites
- [ ] Invites cannot be enumerated by arbitrary authenticated users

### 1.5 Composite indexes
- [ ] Indexes exist for all queries that filter on ownership field + other fields (e.g., `household_id` + `task_id`)

```bash
# Quick check: find all rules
cat firestore.rules

# Check for overly permissive rules
grep -n 'allow.*true\|isAuth()' firestore.rules
```

---

## Phase 2: Authentication & OAuth

### 2.1 Sign-in methods
- [ ] All enabled sign-in methods are intentional (check Firebase console)
- [ ] Email/password: email verification enforced where appropriate
- [ ] OAuth providers: client IDs configured correctly per platform

### 2.2 Client ID management
- [ ] iOS: OAuth client ID read from `GoogleService-Info.plist` — not hardcoded in Dart
- [ ] Android: OAuth client ID from `google-services.json` — not hardcoded in Dart
- [ ] Web client ID (for `serverClientId`): stored in constants file, clearly labelled as non-secret
- [ ] No client *secrets* in source code or version control

### 2.3 Re-authentication
- [ ] Destructive operations (account deletion, data wipe) require re-authentication
- [ ] Re-auth for email/password: prompts for password, uses `reauthenticateWithCredential()`
- [ ] Re-auth for OAuth: triggers fresh sign-in flow before destructive action
- [ ] Password entered for re-auth is held in memory only, never persisted

---

## Phase 3: Client-Side Encryption

Skip this phase if the app does not implement client-side encryption.

### 3.1 Algorithm verification
- [ ] Algorithm is a recognised standard (AES-256-CBC, AES-256-GCM, ChaCha20-Poly1305)
- [ ] Key length matches algorithm requirements (e.g., 256 bits for AES-256)
- [ ] IV/nonce is generated fresh per encryption call using a cryptographic RNG
- [ ] IV is stored alongside ciphertext (prepended or in a separate field) — not reused
- [ ] Decrypt correctly extracts IV before decrypting

### 3.2 Key derivation
- [ ] Key derivation uses a standard KDF (HKDF, PBKDF2, Argon2id) — not raw hashing
- [ ] Salt is unique per user or per key — ideally not hardcoded
- [ ] If UID-based derivation: document that anyone with Firestore admin + source can derive keys. Plan migration to password-based KDF.
- [ ] If password-based derivation: salt stored in Firestore (not secret), password never persisted

### 3.3 Key storage
- [ ] Keys at rest use platform secure storage (`FlutterSecureStorage` → Keychain / EncryptedSharedPreferences)
- [ ] Keys in memory are cleared on sign-out / app termination
- [ ] Server (Firestore) stores only encrypted keys, never plaintext
- [ ] Key sharing between users (if applicable): key is re-encrypted per recipient

### 3.4 Field-level encryption
- [ ] All personal/sensitive content fields are encrypted before Firestore writes
- [ ] Structural fields needed for queries (IDs, timestamps, booleans, enums) are NOT encrypted
- [ ] Decryption failures show a safe placeholder (e.g., `[encrypted]`), never raw ciphertext

```bash
# Find encryption/decryption calls
grep -rn 'encrypt\|decrypt\|_enc\b\|_encN\b' lib/
```

---

## Phase 4: Data Wipe / Account Deletion

If the app has a "delete all my data" or account deletion feature, verify completeness.

### 4.1 Confirmation UX
- [ ] Requires explicit confirmation (not a single tap)
- [ ] Shows what will be deleted
- [ ] Shows what will NOT be deleted (e.g., external files the app can't reach)
- [ ] Irreversible warning is prominent

### 4.2 Wipe sequence
For each data store, verify deletion happens:
- [ ] **Firestore**: all user-owned documents across all collections
- [ ] **Local database** (SQLite, Hive, etc.): database file deleted or all tables cleared
- [ ] **Secure storage**: all keys and cached credentials cleared
- [ ] **SharedPreferences**: all app preferences cleared
- [ ] **Firebase Auth**: account deleted via `user.delete()`
- [ ] **OAuth tokens**: sign-out + disconnect/revoke
- [ ] **Notifications**: all pending notifications cancelled
- [ ] **Temporary files**: any cached/exported files cleaned up

### 4.3 Resilience
- [ ] Firestore batch deletes handle partial failures (retry with backoff)
- [ ] SQLite wipe wrapped in transaction for atomicity
- [ ] Failure at any step shows error + allows retry — does not pretend success
- [ ] `mounted` checks before `setState` and navigation

---

## Phase 5: Export & Import Security

Skip if the app has no export/import functionality.

### 5.1 Export
- [ ] Sensitive exports offer optional encryption (passphrase-based)
- [ ] Encrypted files use a distinguishable extension (e.g., `.json.enc`)
- [ ] Temp export files are auto-deleted after a timeout
- [ ] Passphrase is never persisted

### 5.2 Import
- [ ] Import validates data structure before processing
- [ ] Errors are collected per-entity (not silent failures)
- [ ] Duplicate detection prevents creating duplicate records
- [ ] ID remapping prevents conflicts with existing data
- [ ] Encrypted imports require matching passphrase; wrong passphrase fails gracefully

---

## Phase 6: Notification Privacy

Push notifications are visible on lock screens and in notification centres. They should not leak personal data.

### 6.1 Content check
- [ ] Notification titles and bodies use generic text — no personal names, task titles, item details
- [ ] Entity identifiers passed via `payload` (for deep linking), not in visible text
- [ ] All notification channels have appropriate importance levels

### 6.2 Orphaned notifications
- [ ] App clears stale notifications on fresh install (check via SharedPreferences flag)
- [ ] Notifications are cancelled when the associated entity is deleted

---

## Phase 7: Platform Hardening

### 7.1 Android
- [ ] `android:allowBackup="false"` in `AndroidManifest.xml` (prevents cloud backup of app data including databases)
- [ ] `dataExtractionRules` XML excludes app data from backup and device transfer (Android 12+)
- [ ] `networkSecurityConfig` blocks cleartext HTTP traffic
- [ ] No API keys or secrets in `AndroidManifest.xml` metadata (Firebase config keys are fine — they're project identifiers, not secrets)
- [ ] ProGuard/R8 rules don't strip security-critical code

### 7.2 iOS
- [ ] Keychain items have appropriate accessibility level (e.g., `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- [ ] `NSAppTransportSecurity` blocks cleartext unless explicitly needed
- [ ] No hardcoded secrets in `Info.plist`

### 7.3 General
- [ ] `flutter_secure_storage` (or equivalent) used for all sensitive local data — not SharedPreferences
- [ ] Debug logging does not print sensitive data (encryption keys, tokens, personal content) in release builds
- [ ] No `print()` or `debugPrint()` of keys, passwords, or decrypted content outside of debug mode

```bash
# Check for potential secret leaks
grep -rn 'debugPrint\|print(' lib/ | grep -i 'key\|password\|token\|secret'

# Check Android manifest
grep -n 'allowBackup\|cleartext\|networkSecurity' android/app/src/main/AndroidManifest.xml
```

---

## Phase 8: Local Storage Security

### 8.1 SQLite / local database
- [ ] If the app stores data locally without encryption, document that local data is protected by device-level encryption only
- [ ] If local encryption is used, verify key management (where is the local DB key stored?)
- [ ] Database file is deleted during account wipe (not just tables cleared)

### 8.2 Secure storage
- [ ] `FlutterSecureStorage` used for: encryption keys, auth tokens, cached credentials, sensitive profile data
- [ ] SharedPreferences used ONLY for non-sensitive preferences (theme, locale, feature flags)
- [ ] Verify nothing sensitive stored in SharedPreferences

```bash
# Check what's stored in SharedPreferences vs SecureStorage
grep -rn 'SharedPreferences\|FlutterSecureStorage' lib/
```

---

## Severity Classification

When logging findings, use this severity guide:

| Severity | Description | Example |
|----------|-------------|---------|
| **CRITICAL** | Data accessible to unauthorised users | Firestore rules allow any auth'd user to read/write |
| **HIGH** | Sensitive data could leak | Notification bodies contain personal names |
| **MEDIUM** | Defence-in-depth gap | Android backup not disabled |
| **LOW** | Best practice not followed | Debug prints contain decrypted values |

---

## Output Format

```
## Security Audit Report — [App Name]
### Date: YYYY-MM-DD

### Phase 1: Firestore Security Rules
1. [PASS] Default deny rule in place (firestore.rules:1)
2. [FAIL] subtasks collection uses isAuth() instead of isMember() (firestore.rules:45) — CRITICAL
3. [KNOWN ISSUE] No rate limiting on writes (Firestore limitation)

### Phase 2: Authentication & OAuth
...

### Summary
- CRITICAL: 1
- HIGH: 2
- MEDIUM: 3
- LOW: 1
- KNOWN ISSUES: 2

### Recommended Fix Order
1. [CRITICAL] Fix subtasks Firestore rules
2. [HIGH] Remove personal data from notifications
...
```
