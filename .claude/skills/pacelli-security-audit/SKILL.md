---
name: pacelli-security-audit
description: >
  Focused audit of Pacelli's security pillars: AES-256-CBC encryption with HKDF key derivation,
  Firestore security rules (household_id denormalization + isMember enforcement), privacy screen accuracy,
  burn-all-data completeness, encrypted export/import, notification privacy, Android/iOS platform hardening,
  Cloud Functions auth middleware, server-side key management, rate limiting, MCP server security
  (hardening: HTTPS enforcement, default-deny origins, session TTL, per-IP rate limiting, non-root container),
  service account authentication (TokenManager with auto-refreshing Firebase ID tokens via custom token exchange),
  Secret Manager integration, and Cloud Run deployment security posture.
  Run this after any change to crypto code, key management, Firestore rules, the burn flow, export/import,
  notifications, platform config, Cloud Functions, MCP tools, MCP server auth/hardening, Cloud Run config,
  or the AI Assistant screen. Use whenever the user mentions security audit, encryption check, Firestore
  rules review, data wipe verification, API security, rate limiting, Cloud Run security, or MCP hardening
  for Pacelli.
---

# Pacelli — Security, Encryption & Data Wipe Audit

## Purpose
Focused audit of the security pillars of Pacelli's trust story: **encryption implementation**, **Firestore rules**, **privacy screen accuracy**, **burn-all-data completeness**, **export security**, **notification privacy**, and **platform hardening**. Run this after any change to crypto code, key management, the privacy screen, the burn flow, Firestore rules, export/import, notifications, or Android/iOS configuration.

## Project Location
Pacelli lives at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Key Files

| Concern | File |
|---------|------|
| AES-256-CBC encrypt/decrypt + HKDF key derivation | `lib/core/crypto/encryption_service.dart` |
| Key lifecycle (create/load/share/clear/migrate) | `lib/core/crypto/key_manager.dart` |
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
| Manual models (ManualEntry, ManualCategory) | `lib/core/models/manual_entry.dart` |
| Feedback models (FeedbackEntry, AppDiagnostic, WeeklyDigest) | `lib/core/models/feedback_entry.dart` |
| Feedback service (Firestore-direct, encrypts message/context) | `lib/features/feedback/data/feedback_service.dart` |
| Cloud Functions feedback logic | `functions/src/functions/feedback.ts` |
| Firestore security rules | `firestore.rules` |
| Firestore indexes | `firestore.indexes.json` |
| Export service (encrypted exports) | `lib/features/import_export/data/export_service.dart` |
| Import service (duplicate detection) | `lib/features/import_export/data/import_service.dart` |
| Notification service | `lib/core/services/notification_service.dart` |
| Signup screens (profile name encryption) | `lib/features/auth/presentation/screens/signup_screen.dart` |
| Login screen (OAuth config) | `lib/features/auth/presentation/screens/login_screen.dart` |
| App constants | `lib/config/constants/app_constants.dart` |
| Android manifest | `android/app/src/main/AndroidManifest.xml` |
| Android data extraction rules | `android/app/src/main/res/xml/data_extraction_rules.xml` |
| Android network security config | `android/app/src/main/res/xml/network_security_config.xml` |
| Cloud Functions API handler wrapper | `functions/src/index.ts` |
| Server-side auth middleware | `functions/src/middleware/auth.ts` |
| Server-side rate limiter | `functions/src/middleware/rate-limiter.ts` |
| Server-side encryption helpers | `functions/src/middleware/encryption.ts` |
| Server-side key manager | `functions/src/crypto/key-manager.ts` |
| MCP server (tool registration + transport) | `mcp-server/src/index.ts` |
| MCP token manager (service account auth) | `mcp-server/src/token-manager.ts` |
| MCP API client (token provider pattern) | `mcp-server/src/api-client.ts` |
| MCP Dockerfile (non-root, multi-stage) | `mcp-server/Dockerfile` |
| AI Assistant screen | `lib/features/ai_assistant/presentation/screens/ai_assistant_screen.dart` |

## Audit Checklist

### Phase 1: Encryption Algorithm Verification

#### 1.1 Core algorithm
- [ ] Algorithm is AES-256-CBC (check `enc.AESMode.cbc` in `encryption_service.dart`)
- [ ] Key length is 256 bits (32 bytes → 64-char hex string)
- [ ] IV is 16 bytes, generated fresh per encrypt call via `IV.fromSecureRandom(16)`
- [ ] IV is prepended to ciphertext: `base64(iv_bytes + ciphertext_bytes)`
- [ ] Decrypt correctly splits first 16 bytes as IV, rest as ciphertext

#### 1.2 Key derivation (HKDF — RFC 5869)
- [ ] `deriveUserKey(uid)` uses HKDF extract-then-expand pattern
- [ ] Extract step: HMAC-SHA256 with salt `pacelli_hkdf_salt_v2` and UID as input key material
- [ ] Expand step: HMAC-SHA256 with extracted PRK and info string `pacelli_user_key_v2`
- [ ] Output is 32 bytes (256-bit derived key)
- [ ] Legacy v1 method `_deriveUserKeyV1(uid)` retained for migration only — uses raw HMAC-SHA256 with `pacelli_e2e_key_derivation_v1` salt
- [ ] `decryptKeyWithMigration()` tries v2 first, falls back to v1, auto-re-wraps with v2 on success
- [ ] `KeyManager.loadHouseholdKey()` uses `decryptKeyWithMigration()` for transparent v1→v2 migration

#### 1.3 Key generation and storage
- [ ] `generateHouseholdKey()` uses `Random.secure()` for 256-bit key generation
- [ ] Household key encrypted per-user before Firestore storage (`encryptKeyForUser`)
- [ ] Decrypted household key cached in memory only (`_cachedHouseholdKey`)
- [ ] Local cache uses `FlutterSecureStorage` (Keychain on iOS, EncryptedSharedPreferences on Android)
- [ ] Firestore `household_keys` collection stores only encrypted keys
- [ ] Each user doc has: `household_id`, `user_id`, `encrypted_key`, `created_at`
- [ ] Decryption failure returns `'[encrypted]'` placeholder, never leaks ciphertext to UI

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
- [ ] User display name / full name (`_encN`) — stored locally at signup, encrypted when household key becomes available
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
- [ ] Manual entry titles (`_enc`)
- [ ] Manual entry content (`_enc`)
- [ ] Manual entry tags (each tag `_enc`)
- [ ] Feedback entry messages (`_enc`) — encrypted in `FeedbackService`
- [ ] Feedback entry context (`_encN`) — encrypted in `FeedbackService`
- [ ] Diagnostic summaries (`_enc`) — encrypted in `FeedbackService`
- [ ] Diagnostic details (`_encN`) — encrypted in `FeedbackService`
- [ ] Weekly digest summaries (`_encN`) — encrypted in Cloud Function

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
- [ ] Manual: category_id, is_pinned, household_id, created_by, last_edited_by, created_at, updated_at
- [ ] Feedback: type, rating, household_id, created_by, created_at
- [ ] Diagnostics: kind, source, household_id, user_id, created_at
- [ ] Weekly digests: all count fields, week_starting, week_ending, household_id, created_at

#### 2.3 New fields check
Whenever a new data field is added to any model:
- [ ] Decide: personal content → encrypt, structural metadata → don't encrypt
- [ ] Update `firebase_data_repository.dart` accordingly
- [ ] Update the Privacy screen and ARB files if the encrypted/not-encrypted lists change

### Phase 3: Firestore Security Rules

#### 3.1 household_id denormalization
Every collection must have `household_id` on every document so rules can verify membership:
- [ ] `tasks` — has `household_id`
- [ ] `subtasks` — has `household_id` (denormalized from parent task)
- [ ] `task_categories` — has `household_id`
- [ ] `checklists` — has `household_id`
- [ ] `checklist_items` — has `household_id` (denormalized from parent checklist)
- [ ] `scratch_plans` — has `household_id`
- [ ] `plan_entries` — has `household_id` (denormalized from parent plan)
- [ ] `plan_checklist_items` — has `household_id` (denormalized from parent plan)
- [ ] `task_attachments` — has `household_id`
- [ ] `plan_attachments` — has `household_id`
- [ ] `inventory_items` — has `household_id`
- [ ] `inventory_categories` — has `household_id`
- [ ] `inventory_locations` — has `household_id`
- [ ] `inventory_logs` — has `household_id`
- [ ] `inventory_attachments` — has `household_id`
- [ ] `manual_entries` — has `household_id`
- [ ] `manual_categories` — has `household_id`
- [ ] `feedback` — has `household_id`
- [ ] `diagnostics` — has `household_id`
- [ ] `weekly_digests` — has `household_id`
- [ ] `profiles` — has `household_id`

Verify in code that `addSubtask()`, `addChecklistItem()`, `addPlanEntry()`, `addPlanChecklistItem()` all pass `householdId` to Firestore.

#### 3.2 isMember() enforcement
- [ ] `isMember(householdId)` helper checks `exists(/databases/$(database)/documents/household_members/$(request.auth.uid)_$(householdId))`
- [ ] ALL parent collections use `isMember(resource.data.household_id)` for read/write rules
- [ ] ALL child collections (subtasks, checklist_items, plan_entries, plan_checklist_items) use `isMember(resource.data.household_id)` — not just `isAuth()`
- [ ] Composite indexes exist for all child collection queries that filter by `household_id` + parent ID

#### 3.3 Invite rules
- [ ] Read: only the invited user (by email) OR household members can read invites
- [ ] Create: only household members can create invites
- [ ] Update: only household members can update invites
- [ ] Delete: only household members can delete invites
- [ ] Invites cannot be read/modified by arbitrary authenticated users

#### 3.4 SQLite schema parity
- [ ] SQLite schema (local_database.dart) has `household_id` column on subtasks, checklist_items, plan_entries, plan_checklist_items tables
- [ ] Migration from DB version 2→3 adds `household_id TEXT NOT NULL DEFAULT ''`

### Phase 4: Privacy Screen Accuracy

The privacy screen makes user-facing claims. Every claim must match the code.

#### 4.1 Cross-reference encrypted fields
- [ ] Read `privacy_encryption_screen.dart` — list every field shown under "What IS encrypted"
- [ ] Compare against Phase 2.1 above — flag any mismatch
- [ ] Read every field under "What is NOT encrypted"
- [ ] Compare against Phase 2.2 above — flag any mismatch

#### 4.2 Cross-reference prose claims
- [ ] "AES-256 encryption" → verify in `encryption_service.dart`
- [ ] "End-to-end encrypted before it leaves your device" → verify enc happens client-side before Firestore write
- [ ] "Only you and your household members can read your data" → true with HKDF; verify Firestore rules enforce this
- [ ] "Not even the app developers can see it" → more accurate with HKDF, but technically the app code + Firestore admin could re-derive keys from UID. Track PBKDF2/Argon2id migration for full accuracy.
- [ ] "Your encryption key is generated on your device" → verify in `generateHouseholdKey()`
- [ ] "Never stored in readable form on the server" → verify Firestore only has `encrypted_key`
- [ ] "Each household member receives their own encrypted copy" → verify in `shareKeyWithMember()`
- [ ] File attachment Drive explanation → verify files go to owner's Drive, names encrypted in Pacelli DB

#### 4.3 l10n sync
- [ ] All `privacy*` keys exist in `app_en.arb`, `app_es.arb`, and `app_it.arb`
- [ ] Translations are accurate and not misleading in any language
- [ ] Any new encrypted field gets a corresponding privacy screen tile + l10n key in all locales

### Phase 5: Burn All Data Completeness

#### 5.1 Confirmation dialog (`settings_screen.dart`)
- [ ] Lists everything that will be deleted (tasks, categories, local DB, cloud data, keys, credentials, session)
- [ ] Shows irreversible warning
- [ ] Shows Google Drive / local storage manual deletion note
- [ ] Requires explicit tap on "Burn Everything" — no accidental triggers

#### 5.2 Pre-burn authentication
- [ ] For email/password users: password prompt dialog shown BEFORE burn starts
- [ ] Dialog uses `barrierDismissible: false` — user cannot tap outside to dismiss
- [ ] Cancel button returns `null` → burn is aborted, user returns to settings
- [ ] Password stored in memory only (`emailPassword` variable) — never persisted
- [ ] TextEditingController disposed after dialog animation finishes via `addPostFrameCallback`
- [ ] `_burnEverything()` deferred with `addPostFrameCallback` to prevent dialog dismissal during `didChangeDependencies`

#### 5.3 Burn sequence (`burn_data_screen.dart`)
Verify each step actually runs and succeeds:
- [ ] **Step 0**: `notificationServiceProvider.cancelAll()` — cancels all pending notifications (including inventory expiry reminders with stable IDs `'expiry_$itemId'` and `'lowstock_$itemId'`)
- [ ] **Step 1**: `repo.wipeAllData(userId)` — deletes all Firestore user data:
  - tasks, subtasks, checklists, checklist_items, scratch_plans, plan_entries, plan_checklist_items
  - task_categories, task_attachments, plan_attachments, household_invites
  - inventory_items, inventory_categories, inventory_locations, inventory_logs, inventory_attachments
  - manual_entries, manual_categories
  - feedback, diagnostics, weekly_digests
  - household_members, households, household_drive_config
  - profiles, household_keys (encryption keys)
  - Granular `debugPrint` logging for each collection's doc count
  - Batch deletes in chunks of 400 (under Firestore 500-op limit)
  - Retry up to 3 times with exponential backoff per batch on failure
  - Empty households case: graceful return (no throw), logs warning
- [ ] **Step 2**: `LocalDatabase.deleteDatabase()` — deletes local SQLite file
- [ ] **Step 3**: `FlutterSecureStorage().deleteAll()` — clears encryption keys AND locally-stored profile names from secure storage
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

#### 5.4 What burn does NOT delete (and warns the user)
- [ ] Google Drive Pacelli folder and files → user must delete manually
- [ ] Files on device storage → user must delete manually
- [ ] Firestore household key docs for OTHER members (they keep their own copies)
- [ ] Drive warning shown in both confirmation dialog AND burn completion screen
- [ ] All burn status messages are localised (`burnStatus*` and `burnPassword*` l10n keys)

#### 5.5 Error handling during burn
- [ ] If `wipeAllData` throws → shows error status → sets `_hasFailed = true` → shows Retry/Cancel buttons
- [ ] Does NOT proceed to sign-out on failure — prevents false success
- [ ] Retry button calls `_burnEverything()` again from the beginning
- [ ] Cancel button navigates back to settings

#### 5.6 Edge cases
- [ ] Burn works even if user has no internet (local wipe still succeeds, Firestore wipe handled gracefully)
- [ ] Burn works if Google Sign-In was never used (catches thrown error)
- [ ] Burn works if local DB doesn't exist (catches thrown error)
- [ ] Burn works if no households found for user (graceful return, continues to auth deletion)
- [ ] Wrong password during burn → shows error → allows retry
- [ ] Fatal error during burn → shows error message with Retry/Cancel
- [ ] `mounted` checks before `setState` and navigation

### Phase 6: Export & Import Security

#### 6.1 Encrypted exports
- [ ] `exportAsJson()` accepts optional `passphrase` parameter
- [ ] When passphrase provided: derives key via `EncryptionService.deriveUserKey()`, encrypts full JSON payload
- [ ] Encrypted file saved with `.json.enc` extension (distinguishable from plain exports)
- [ ] Temp export file auto-deleted after 5 minutes via `Future.delayed`
- [ ] Passphrase never persisted — entered by user, used once, discarded

#### 6.2 Import safety
- [ ] Import service validates JSON structure before processing
- [ ] `ImportResult` carries `List<ImportError>` with entityType, entityName, message for each failure
- [ ] Duplicate detection: pre-fetches existing inventory items (by name+barcode), categories (by name), locations (by name) — skips duplicates
- [ ] ID remapping on import: category/location IDs remapped to prevent conflicts with existing data
- [ ] Encrypted imports require matching passphrase — wrong passphrase fails gracefully

### Phase 7: Notification Privacy

#### 7.1 Generic notification content
- [ ] Task reminders: body is generic (e.g., "You have a task reminder") — does NOT include task title
- [ ] Expiry reminders: body is generic (e.g., "An inventory item is expiring soon") — does NOT include item name
- [ ] Low stock alerts: body is generic (e.g., "An inventory item is running low") — does NOT include item name
- [ ] Entity IDs passed via `payload` for deep linking, not in visible notification text
- [ ] First-launch cleanup: checks `notifications_initialised` in SharedPreferences, calls `cancelAll()` on first launch to clear orphaned notifications from previous installs

### Phase 8: Platform Hardening

#### 8.1 Android
- [ ] `android:allowBackup="false"` in AndroidManifest.xml — prevents cloud backup of app data
- [ ] `data_extraction_rules.xml` excludes all app data from cloud backup and device-to-device transfer
- [ ] `network_security_config.xml` blocks cleartext HTTP traffic and trusts only system CAs
- [ ] No hardcoded API keys or client IDs in source code — `google_web_client_id` in `strings.xml` is the web client ID (not a secret)

#### 8.2 iOS
- [ ] GoogleSignIn reads `clientId` from `GoogleService-Info.plist` — no hardcoded iOS client ID in Dart code
- [ ] `google_web_client_id` used only as `serverClientId` for Firebase Auth token exchange

#### 8.3 Auth security
- [ ] OAuth client ID configuration: iOS from plist, Android from `strings.xml`, web client ID from constants
- [ ] No client secrets in source code
- [ ] Profile names stored in FlutterSecureStorage at signup, empty string written to Firestore, encrypted with household key when household is created/joined

### Phase 9: Server-Side Auth & Key Management (Cloud Functions)

The AI integration layer runs Cloud Functions with server-side access to Firestore and encryption keys. These must be audited for secure handling.

#### 9.1 Auth middleware (`functions/src/middleware/auth.ts`)
- [ ] Every Cloud Function export uses the `apiHandler()` wrapper (chains auth → rate limit → error handling)
- [ ] `authenticateRequest()` verifies Firebase ID token via `admin.auth().verifyIdToken(token)` — no custom token verification
- [ ] Bearer token extracted from `Authorization` header — rejects if missing or malformed (401)
- [ ] `resolveHouseholdId()` queries `household_members` by `user_id` — does NOT trust client-supplied household ID
- [ ] `loadHouseholdKey()` loads the per-user encrypted key from `household_keys` and decrypts server-side
- [ ] Auth errors return generic messages — no stack traces, no internal details in HTTP responses
- [ ] `AuthContext` interface passes `{ uid, householdId, householdKey }` — key lives in memory only for the request duration

#### 9.2 Server-side key management (`functions/src/crypto/key-manager.ts`)
- [ ] `loadHouseholdKey()` is stateless — loads fresh per request, no caching between requests
- [ ] Uses `decryptKeyWithMigration()` supporting transparent HKDF v1→v2 migration (same as client)
- [ ] Auto-re-wraps v1 keys with v2 derivation on successful decryption
- [ ] Key derivation uses same `deriveUserKey(uid)` HKDF pattern as client — keys are interchangeable
- [ ] No household keys logged or included in error messages

#### 9.3 Server-side encryption (`functions/src/middleware/encryption.ts`)
- [ ] `createFieldCrypto(householdKey)` returns `{ enc, dec, encN, decN }` matching client-side `_enc`/`_dec`/`_encN`/`_decN`
- [ ] `dec()` catches errors and returns `"[encrypted]"` placeholder — never exposes ciphertext to API consumers
- [ ] Same AES-256-CBC algorithm as client — encrypted fields are interchangeable between client and server
- [ ] Household key is never serialised to response bodies

#### 9.4 Rate limiting (`functions/src/middleware/rate-limiter.ts`)
- [ ] Dual sliding window: per-minute + per-hour limits per user per operation type
- [ ] Read operations: 100/min short, 500/hour long
- [ ] Write operations: 30/min short, 200/hour long
- [ ] `classifyOperation()` uses function name regex (List/Get/Stats/Search → read, else → write)
- [ ] Rate limit state stored in `_rate_limits` Firestore collection — not in memory (survives cold starts)
- [ ] Firestore transactions used for atomic check-and-increment — no race conditions
- [ ] `RateLimitError` returns `retryAfterSec` in response — no internal state leaked
- [ ] Rate limit checks happen AFTER auth — unauthenticated requests are rejected before rate counting

#### 9.5 API error handling
- [ ] `apiHandler()` catch block returns generic error messages — no stack traces in production
- [ ] Auth failures: 401 with generic "Unauthorized" message
- [ ] Rate limit failures: 429 with `retryAfterSec`
- [ ] Validation errors: 400 with field-level messages (no sensitive data)
- [ ] Internal errors: 500 with generic message — no exception details

### Phase 10: MCP Server Security

The MCP server (`mcp-server/`) bridges Claude AI to the Cloud Functions API. It must not leak credentials or bypass auth.

#### 10.1 Configuration & secrets
- [ ] `PACELLI_API_URL` read from environment variable — not hardcoded
- [ ] No secrets in source code, Dockerfile, or committed config files
- [ ] `.env` files excluded from version control (check `.gitignore`)
- [ ] Token passed as Bearer header to Cloud Functions — same auth flow as client

#### 10.2 Service Account Authentication (`mcp-server/src/token-manager.ts`)
- [ ] `TokenManager` uses Firebase Admin SDK with Application Default Credentials (ADC) — no service account key file baked into image
- [ ] Creates custom token via `admin.auth().createCustomToken(SERVICE_USER_UID)` for a dedicated service user
- [ ] Exchanges custom token for ID token via Firebase Auth REST API (`identitytoolkit.googleapis.com`)
- [ ] Firebase API key (`FIREBASE_API_KEY`) and service user UID (`SERVICE_USER_UID`) injected via Secret Manager — not in env vars or source
- [ ] Token cached in memory with 5-minute expiry buffer before the 1-hour Firebase token TTL
- [ ] Concurrent refresh requests deduplicated via `refreshPromise` — prevents token storm on cold start
- [ ] `getValidToken()` is the sole token source — `ApiClient` uses `tokenProvider: () => tokenManager.getValidToken()`
- [ ] No static `PACELLI_AUTH_TOKEN` environment variable — fully automated token lifecycle

#### 10.3 Secret Manager Integration
- [ ] Secrets stored in Google Cloud Secret Manager, NOT in environment variables or source code:
  - `firebase-api-key` — Firebase Web API key (for token exchange)
  - `mcp-service-uid` — Firebase UID of the dedicated MCP service user
  - `mcp-sa-key` — Service account JSON key (if needed for non-ADC environments)
- [ ] Cloud Run service account has `roles/secretmanager.secretAccessor` on each secret
- [ ] Secrets mounted as environment variables via Cloud Run `--set-secrets` flag — not baked into image layers
- [ ] Secret values never logged, never included in error messages, never returned in API responses

#### 10.4 MCP Server Hardening
- [ ] **HTTPS enforcement**: `PACELLI_API_URL` must start with `https://` in HTTP mode — server refuses to start otherwise
- [ ] **Default-deny origins**: `MCP_ALLOWED_ORIGINS` must be non-empty in HTTP mode — server refuses to start if empty
- [ ] **Session TTL**: 30-minute idle timeout per session via `sessionLastActivity` Map, 60-second cleanup interval
- [ ] **Rate limiting**: 100 requests/minute per IP with sliding window, returns 429 with `Retry-After` header
- [ ] **Non-root container**: Dockerfile creates `appuser` (UID 1001) in `appgroup` (GID 1001) — `USER appuser` before CMD
- [ ] **Health endpoint sanitised**: `/health` returns only `{"status":"ok"}` — no version, no env vars, no internal state
- [ ] **Multi-stage Docker build**: Builder stage discarded — production image has no dev dependencies, no source code, no tsconfig

#### 10.5 Tool registration security
- [ ] All MCP tools use zod validation for input parameters — no unvalidated user input passed to API
- [ ] Tool descriptions do not expose internal API structure or auth details
- [ ] Error responses from tools are sanitised — no raw API errors forwarded to Claude
- [ ] `_registerTools()` and `_registerResources()` use the same registrations for stdio and HTTP transports

#### 10.6 Transport security
- [ ] stdio transport: local only, no network exposure
- [ ] HTTP/SSE transport: session-scoped server instances — no shared state between sessions
- [ ] CORS headers configured via `MCP_ALLOWED_ORIGINS` — not wildcard `*` in production
- [ ] No sensitive data in MCP resource URIs

#### 10.7 Cloud Run Deployment Security
- [ ] Cloud Run service (`pacelli-mcp`) runs in `us-central1` with dedicated service account (`pacelli-mcp-sa`)
- [ ] Service account has minimal IAM roles: `roles/firebase.sdkAdminServiceAgent` (or equivalent for custom token creation) + `roles/secretmanager.secretAccessor`
- [ ] Cloud Run allows unauthenticated invocations (MCP protocol handles its own auth) — but rate limiting + origin checks protect against abuse
- [ ] Max instances capped (0–3) to limit blast radius
- [ ] Memory: 256Mi, CPU: 1 — minimal resource footprint
- [ ] Container runs as non-root user (UID 1001)
- [ ] No SSH, no shell access in production container

#### 10.8 AI Assistant screen (Flutter client)
- [ ] Firebase ID token obtained via `FirebaseAuth.instance.currentUser!.getIdToken()` — standard Firebase flow
- [ ] Token passed to Cloud Functions in Authorization header — not in URL parameters
- [ ] Token refreshed automatically by Firebase SDK — no manual token management
- [ ] No household key or encryption key exposed to the AI Assistant UI
- [ ] AI responses displayed read-only — AI cannot trigger write operations directly from the Flutter screen without user confirmation

### Phase 11: Key Derivation Future Migration

**Current state**: HKDF (RFC 5869) extract-then-expand with UID-based input. Transparent v1→v2 migration in place.
**Target state**: Password-based derivation (PBKDF2 or Argon2id) so that even server admins with Firestore access + source code cannot derive user keys.

#### Migration requirements (when ready to implement)
- [ ] Add password input during initial setup / key creation
- [ ] Use PBKDF2 (or Argon2id) with user password + random salt to derive user key
- [ ] Store salt per-user in Firestore (salt is not secret, only the password is)
- [ ] Re-encrypt existing household keys with new user keys during migration
- [ ] Handle password change: re-derive key, re-encrypt household key
- [ ] Handle password reset: requires household admin to re-share key
- [ ] Update privacy screen claim: "Not even the app developers can see it" becomes fully accurate
- [ ] Add l10n keys for password prompt UI

## How to Run This Audit

1. Read this skill file
2. Open each key file listed in the table above
3. Walk through each phase's checklist, using `grep` and `Read` to verify
4. Log findings as a numbered list: `[PASS]`, `[FAIL]`, or `[KNOWN ISSUE]` with file + line
5. Fix `[FAIL]` items in priority order: Firestore rules > encryption bugs > privacy screen inaccuracy > burn gaps > export security > notification privacy > platform hardening > l10n gaps
6. After fixes: `flutter clean && flutter pub get && flutter run`

## When to Run

| Trigger | Phases to run |
|---------|---------------|
| Changed crypto code or key management | 1, 2, 4 |
| Added/changed a data model field | 2, 3, 4 |
| Modified privacy screen or its l10n keys | 4 |
| Modified burn flow or settings dialog | 5 |
| Changed attachment model or upload flow | 2, 4 |
| Modified Firestore security rules | 3, 5 |
| Changed export/import service | 6 |
| Changed notification service | 7 |
| Modified Android/iOS config | 8 |
| Before any release | All phases |
| Starting PBKDF2/Argon2id migration | 1, 11 |
| Changed Cloud Functions auth/handler/rate limit | 9 |
| Changed MCP server tools or transport | 10.4, 10.5, 10.6 |
| Changed MCP server auth or token management | 10.2, 10.3 |
| Changed MCP server hardening (rate limit, origins, session) | 10.4 |
| Changed Cloud Run deployment config | 10.3, 10.7 |
| Changed AI Assistant screen | 10.8 |
| Modified API error handling | 9.5 |
| Added/changed manual or feedback features | 2, 3, 5 |
