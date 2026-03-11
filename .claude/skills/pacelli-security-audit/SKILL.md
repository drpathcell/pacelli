# Pacelli — Security, Encryption & Data Wipe Audit

## Purpose
Focused audit of the three pillars of Pacelli's trust story: **encryption implementation**, **privacy screen accuracy**, and **burn-all-data completeness**. Run this after any change to crypto code, key management, the privacy screen, or the burn flow.

## Project Location
Pacelli lives at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Key Files

| Concern | File |
|---------|------|
| AES-256-CBC encrypt/decrypt | `lib/core/crypto/encryption_service.dart` |
| Key lifecycle (create/load/share/clear) | `lib/core/crypto/key_manager.dart` |
| Field-level enc/dec in Firestore | `lib/core/data/firebase_data_repository.dart` |
| Privacy & Encryption screen (user-facing claims) | `lib/features/settings/presentation/screens/privacy_encryption_screen.dart` |
| Burn confirmation dialog | `lib/features/settings/presentation/screens/settings_screen.dart` (method `_showBurnConfirmation`) |
| Burn animation + wipe sequence | `lib/features/settings/presentation/screens/burn_data_screen.dart` |
| Household service (creates key on household creation) | `lib/features/household/data/household_service.dart` |
| Privacy l10n keys | `lib/l10n/app_en.arb` (search `privacy` and `burn`) |
| Local data repository (SQLite layer) | `lib/core/data/local_data_repository.dart` |
| Local database (SQLite schema + helpers) | `lib/core/data/local_database.dart` |
| Attachment models (Task + Plan) | `lib/core/models/attachment.dart` |
| Inventory models (5 classes) | `lib/core/models/inventory_item.dart` |
| Inventory providers | `lib/features/inventory/data/inventory_providers.dart` |
| Inventory auto-task service | `lib/features/inventory/data/inventory_task_service.dart` |
| Inventory screens (9) | `lib/features/inventory/presentation/screens/` |
| Inventory widgets (5) | `lib/features/inventory/presentation/widgets/` |

## Audit Checklist

### Phase 1: Encryption Algorithm Verification

#### 1.1 Core algorithm
- [ ] Algorithm is AES-256-CBC (check `enc.AESMode.cbc` in `encryption_service.dart`)
- [ ] Key length is 256 bits (32 bytes → 64-char hex string)
- [ ] IV is 16 bytes, generated fresh per encrypt call via `IV.fromSecureRandom(16)`
- [ ] IV is prepended to ciphertext: `base64(iv_bytes + ciphertext_bytes)`
- [ ] Decrypt correctly splits first 16 bytes as IV, rest as ciphertext

#### 1.2 Key derivation
- [ ] `generateHouseholdKey()` uses `Random.secure()` for 256-bit key generation
- [ ] `deriveUserKey(uid)` uses HMAC-SHA256 with salt
- [ ] **KNOWN ISSUE**: Salt is hardcoded (`pacelli_e2e_key_derivation_v1`) — anyone with Firestore admin access + source code can derive user keys
- [ ] **MIGRATION TARGET**: Switch to PBKDF2 with user password input so that even server admins cannot derive keys
- [ ] Household key is encrypted per-user before Firestore storage (`encryptKeyForUser`)
- [ ] Decryption failure returns `'[encrypted]'` placeholder, never leaks ciphertext to UI

#### 1.3 Key storage
- [ ] Decrypted household key cached in memory only (`_cachedHouseholdKey`)
- [ ] Local cache uses `FlutterSecureStorage` (Keychain on iOS, EncryptedSharedPreferences on Android)
- [ ] Firestore `household_keys` collection stores only encrypted keys
- [ ] Each user doc has: `household_id`, `user_id`, `encrypted_key`, `created_at`

### Phase 2: Field Encryption Completeness

Run this grep to find all `_enc()`/`_encN()` calls and verify coverage:

```bash
grep -n '_enc\b\|_encN\b' lib/core/data/firebase_data_repository.dart
```

#### 2.1 Fields that MUST be encrypted
- [ ] Task titles (`_enc`)
- [ ] Task descriptions (`_encN` — nullable)
- [ ] Subtask titles (`_enc`)
- [ ] Checklist titles (`_enc`)
- [ ] Checklist item titles (`_enc`)
- [ ] Plan titles (`_enc`)
- [ ] Plan entry titles (`_enc`)
- [ ] Plan entry labels (`_encN`)
- [ ] Plan entry descriptions (`_encN`)
- [ ] Plan template names (`_encN`)
- [ ] Category names (`_enc`)
- [ ] Household name (encrypted in `household_service.dart`)
- [ ] User display name / full name (`_encN`)
- [ ] Task attachment file names (`_enc`)
- [ ] Task attachment descriptions (`_encN`)
- [ ] Task attachment mime types (`_enc`)
- [ ] Task attachment web view links (`_enc`)
- [ ] Task attachment thumbnail URLs (`_encN`)
- [ ] Plan attachment file names (`_enc`)
- [ ] Plan attachment mime types (`_enc`)
- [ ] Plan attachment web view links (`_enc`)
- [ ] Plan attachment thumbnail URLs (`_encN`)
- [ ] Plan attachment descriptions (`_encN`)
- [ ] Inventory item names (`_enc`)
- [ ] Inventory item descriptions (`_encN`)
- [ ] Inventory item unit (`_enc`)
- [ ] Inventory item barcode (`_encN`)
- [ ] Inventory item notes (`_encN`)

#### 2.2 Fields that must NOT be encrypted (structural/query fields)
- [ ] Task status, priority, due dates, recurrence
- [ ] Checked/completed booleans
- [ ] Sort order, position indices
- [ ] Category icons and colours
- [ ] Timestamps (created_at, updated_at)
- [ ] IDs (document IDs, household IDs, user IDs)
- [ ] Attachment file IDs (Google Drive IDs)
- [ ] Attachment file sizes
- [ ] Inventory: quantity, low_stock_threshold, expiry_date, purchase_date, barcode_type, category_id, location_id, household_id, created_by, created_at, updated_at

#### 2.3 New fields check
Whenever a new data field is added to any model:
- [ ] Decide: personal content → encrypt, structural metadata → don't encrypt
- [ ] Update `firebase_data_repository.dart` accordingly
- [ ] Update the Privacy screen and ARB files if the encrypted/not-encrypted lists change

### Phase 3: Privacy Screen Accuracy

The privacy screen makes user-facing claims. Every claim must match the code.

#### 3.1 Cross-reference encrypted fields
- [ ] Read `privacy_encryption_screen.dart` — list every field shown under "What IS encrypted"
- [ ] Compare against Phase 2.1 above — flag any mismatch
- [ ] Read every field under "What is NOT encrypted"
- [ ] Compare against Phase 2.2 above — flag any mismatch

#### 3.2 Cross-reference prose claims
- [ ] "AES-256 encryption" → verify in `encryption_service.dart`
- [ ] "End-to-end encrypted before it leaves your device" → verify enc happens client-side before Firestore write
- [ ] "Only you and your household members can read your data" → true, but see key derivation caveat (Phase 1.2)
- [ ] "Not even the app developers can see it" → **CURRENTLY INACCURATE** due to hardcoded salt. Track PBKDF2 migration status.
- [ ] "Your encryption key is generated on your device" → verify in `generateHouseholdKey()`
- [ ] "Never stored in readable form on the server" → verify Firestore only has `encrypted_key`
- [ ] "Each household member receives their own encrypted copy" → verify in `shareKeyWithMember()`
- [ ] File attachment Drive explanation → verify files go to owner's Drive, names encrypted in Pacelli DB

#### 3.3 l10n sync
- [ ] All `privacy*` keys exist in `app_en.arb`, `app_es.arb`, and `app_it.arb`
- [ ] Translations are accurate and not misleading in any language
- [ ] Any new encrypted field gets a corresponding privacy screen tile + l10n key in all locales

### Phase 4: Burn All Data Completeness

#### 4.1 Confirmation dialog (`settings_screen.dart`)
- [ ] Lists everything that will be deleted (tasks, categories, local DB, cloud data, keys, credentials, session)
- [ ] Shows irreversible warning
- [ ] Shows Google Drive / local storage manual deletion note
- [ ] Requires explicit tap on "Burn Everything" — no accidental triggers

#### 4.2 Pre-burn authentication
- [ ] For email/password users: password prompt dialog shown BEFORE burn starts
- [ ] Dialog uses `barrierDismissible: false` — user cannot tap outside to dismiss
- [ ] Cancel button returns `null` → burn is aborted, user returns to settings
- [ ] Password stored in memory only (`emailPassword` variable) — never persisted
- [ ] TextEditingController disposed after dialog animation finishes via `addPostFrameCallback`
- [ ] `_burnEverything()` deferred with `addPostFrameCallback` to prevent dialog dismissal during `didChangeDependencies`

#### 4.3 Burn sequence (`burn_data_screen.dart`)
Verify each step actually runs and succeeds:
- [ ] **Step 0**: `notificationServiceProvider.cancelAll()` — cancels all pending notifications (including inventory expiry reminders with stable IDs `'expiry_$itemId'` and `'lowstock_$itemId'`)
- [ ] **Step 1**: `repo.wipeAllData(userId)` — deletes all Firestore user data:
  - tasks, subtasks, checklists, checklist_items, scratch_plans, plan_entries, plan_checklist_items
  - task_categories, task_attachments, plan_attachments, household_invites
  - inventory_items, inventory_categories, inventory_locations, inventory_logs, inventory_attachments
  - household_members, households, household_drive_config
  - profiles, household_keys (encryption keys)
  - Granular `debugPrint` logging for each collection's doc count
  - Batch deletes in chunks of 400 (under Firestore 500-op limit)
  - Empty households case: graceful return (no throw), logs warning
- [ ] **Step 2**: `LocalDatabase.deleteDatabase()` — deletes local SQLite file
- [ ] **Step 3**: `FlutterSecureStorage().deleteAll()` — clears encryption keys from secure storage
- [ ] **Step 4**: Firebase Auth account deletion:
  - Google users: re-authenticate via `GoogleSignIn().signIn()` + `reauthenticateWithCredential()`
  - Email/password users: re-authenticate via `EmailAuthProvider.credential()` with prompted password
  - `user.delete()` — permanently deletes the Firebase Auth account
  - Wrong password: catches `wrong-password`/`invalid-credential`, shows localised error, sets `_hasFailed = true`
  - Other auth errors: caught silently (account stays but data is gone)
- [ ] **Step 5a**: `FirebaseAuth.instance.signOut()` — Firebase sign-out
- [ ] **Step 5b**: `GoogleSignIn().signOut()` + `disconnect()` — Google sign-out + token revocation
- [ ] **Step 6**: `SharedPreferences.clear()` — clears all app preferences
- [ ] **Step 7**: Navigates to login screen after completion

#### 4.4 What burn does NOT delete (and warns the user)
- [ ] Google Drive Pacelli folder and files → user must delete manually
- [ ] Files on device storage → user must delete manually
- [ ] Firestore household key docs for OTHER members (they keep their own copies)
- [ ] Drive warning shown in both confirmation dialog AND burn completion screen
- [ ] All burn status messages are localised (`burnStatus*` and `burnPassword*` l10n keys)

#### 4.5 Error handling during burn
- [ ] If `wipeAllData` throws → shows error status → sets `_hasFailed = true` → shows Retry/Cancel buttons
- [ ] Does NOT proceed to sign-out on failure — prevents false success
- [ ] Retry button calls `_burnEverything()` again from the beginning
- [ ] Cancel button navigates back to settings

#### 4.6 Edge cases
- [ ] Burn works even if user has no internet (local wipe still succeeds, Firestore wipe handled gracefully)
- [ ] Burn works if Google Sign-In was never used (catches thrown error)
- [ ] Burn works if local DB doesn't exist (catches thrown error)
- [ ] Burn works if no households found for user (graceful return, continues to auth deletion)
- [ ] Wrong password during burn → shows error → allows retry
- [ ] Fatal error during burn → shows error message with Retry/Cancel
- [ ] `mounted` checks before `setState` and navigation

### Phase 5: Key Derivation Migration Tracking

**Current state**: UID-based derivation with hardcoded HMAC salt.
**Target state**: Password-based derivation (PBKDF2 or Argon2id).

#### Migration requirements (when ready to implement)
- [ ] Add password input during initial setup / key creation
- [ ] Use PBKDF2 (or Argon2id) with user password + random salt to derive user key
- [ ] Store salt per-user in Firestore (salt is not secret, only the password is)
- [ ] Re-encrypt existing household keys with new user keys during migration
- [ ] Handle password change: re-derive key, re-encrypt household key
- [ ] Handle password reset: requires household admin to re-share key
- [ ] Update privacy screen claim: "Not even the app developers can see it" becomes accurate
- [ ] Add l10n keys for password prompt UI

## How to Run This Audit

1. Read this skill file
2. Open each key file listed in the table above
3. Walk through each phase's checklist, using `grep` and `Read` to verify
4. Log findings as a numbered list: `[PASS]`, `[FAIL]`, or `[KNOWN ISSUE]` with file + line
5. Fix `[FAIL]` items in priority order: encryption bugs > privacy screen inaccuracy > burn gaps > l10n gaps
6. After fixes: `flutter clean && flutter pub get && flutter run`

## When to Run

| Trigger | Phases to run |
|---------|---------------|
| Changed crypto code or key management | 1, 2, 3 |
| Added/changed a data model field | 2, 3 |
| Modified privacy screen or its l10n keys | 3 |
| Modified burn flow or settings dialog | 4 |
| Changed attachment model or upload flow | 2, 3 |
| Modified Firestore security rules | 4, 5 |
| Before any release | All phases |
| Starting PBKDF2 migration | 1, 5 |
