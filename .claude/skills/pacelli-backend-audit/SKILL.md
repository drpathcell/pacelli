# Pacelli — Backend Audit & Remediation Checklist

## Overview
This skill provides a systematic checklist for auditing the Pacelli app's backend layer: data providers, repositories, encryption, error handling, and Riverpod state management. Use it periodically (e.g., before a release) or after major changes to catch issues early.

## Project Location
The Pacelli project is at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Architecture Context
- **Backend**: Firebase (Firestore) with end-to-end encryption (AES-256)
- **State management**: Riverpod (FutureProvider, StateNotifierProvider, Provider)
- **Data layer**: `lib/core/data/data_repository.dart` (abstract interface), `firebase_data_repository.dart` (Firestore+encryption), `local_data_repository.dart` (SQLite cache), `local_database.dart` (SQLite schema)
- **Feature providers**: `lib/features/{feature}/data/{feature}_providers.dart`
- **Encryption**: Applied at the repository level before write, decrypted after read
- **File storage**: Google Drive via household owner's account
- **Auth**: Firebase Auth + Google Sign-In
- **Notifications**: Local push notifications via `flutter_local_notifications` (`lib/core/services/notification_service.dart`)
- **Import/Export**: JSON export/import of household data (`lib/features/import_export/data/`)
- **Burn All Data**: Full wipe sequence including Firestore, local DB, secure storage, SharedPreferences, and Firebase Auth account deletion with re-authentication (`lib/features/settings/presentation/screens/burn_data_screen.dart`)

## Audit Checklist

### Phase 1: Data Layer Integrity

#### 1.1 Repository Provider
- [ ] `data_repository_provider.dart` exists and is the single source of truth
- [ ] All Firestore reads/writes go through the repository — no direct Firestore calls from UI
- [ ] Repository methods return typed data (or `Map<String, dynamic>` consistently)
- [ ] No business logic leaks into the repository — it's a pure data layer
- [ ] `local_data_repository.dart` mirrors all read/write methods from the Firebase implementation
- [ ] `local_database.dart` schema includes tables for: tasks, subtasks, plans, plan_entries, plan_checklist_items, categories, checklists, checklist_items, task_attachments, plan_attachments, household_members, households

#### 1.2 Feature Providers
For each feature (`tasks`, `plans`, `checklists`, `household`, `settings`, `auth`, `attachments`, `import_export`, `onboarding`):
- [ ] Providers use `ref.watch(dataRepositoryProvider)` to get the repo
- [ ] `FutureProvider.family` is used for household-scoped queries (takes `householdId`)
- [ ] Providers are properly scoped — no global state that should be per-household
- [ ] `.autoDispose` is used where appropriate (screens that are popped)
- [ ] Error states are handled (providers return `AsyncError` not silent failures)

#### 1.3 Data Flow
- [ ] Create → Read → Update → Delete operations all go through repository
- [ ] Optimistic updates are consistent (if used)
- [ ] Cache invalidation works: after a write, relevant providers are refreshed
- [ ] No stale data: check that `ref.invalidate()` or `ref.refresh()` is called after mutations

### Phase 2: Encryption Audit

#### 2.1 What MUST be encrypted (personal content)
- [ ] Task titles and descriptions
- [ ] Subtask titles
- [ ] Checklist and checklist item titles
- [ ] Plan titles, entry titles, labels, and descriptions
- [ ] Plan template names
- [ ] Category names
- [ ] Household name
- [ ] User display name
- [ ] Task attachment file names, descriptions, mime types, web view links, thumbnail URLs
- [ ] Plan attachment file names, mime types, web view links, thumbnail URLs

#### 2.2 What must NOT be encrypted (structural fields)
- [ ] Task status (pending, completed)
- [ ] Priority levels
- [ ] Due dates and timestamps
- [ ] Checked/completed booleans
- [ ] Sort order
- [ ] Category icons and colours
- [ ] Recurrence values
- [ ] Attachment file IDs (Google Drive IDs) and file sizes

#### 2.3 Encryption implementation
- [ ] Encryption key is generated on-device
- [ ] Key is never stored in readable form on the server
- [ ] Each household member gets their own encrypted copy of the shared key
- [ ] Encryption happens before Firestore write
- [ ] Decryption happens after Firestore read
- [ ] Null/empty values are handled gracefully (no crash on decrypt of empty string)

### Phase 3: Error Handling

#### 3.1 Network errors
- [ ] All Firestore calls wrapped in try-catch
- [ ] Network errors show user-friendly messages via l10n keys (not raw error strings)
- [ ] Retry mechanisms exist for transient failures
- [ ] Offline behaviour is graceful (Firestore offline persistence is enabled)

#### 3.2 Auth errors
- [ ] Token expiry is handled (auto-refresh or re-login prompt)
- [ ] Google Sign-In failure shows a clear message
- [ ] Sign-out clears all local state and providers

#### 3.3 UI error states
For each screen, check:
- [ ] Loading state uses `LoadingView` (or equivalent spinner)
- [ ] Error state uses `ErrorView` with retry callback
- [ ] Empty state has a helpful message (not blank screen)
- [ ] All error messages use `context.l10n` keys — no hardcoded English

### Phase 4: Riverpod State Management

#### 4.1 Provider hygiene
- [ ] No circular dependencies between providers
- [ ] No `ref.read` in build methods (should be `ref.watch`)
- [ ] `ref.read` used only in callbacks (onTap, onPressed, etc.)
- [ ] Family providers use appropriate keys (not entire objects)
- [ ] No redundant providers (two providers fetching the same data)

#### 4.2 State mutations
- [ ] Mutations (create/update/delete) call `ref.invalidate()` on affected list providers
- [ ] Snackbar/toast feedback after successful mutations
- [ ] Navigation after mutations is correct (e.g., pop after delete)
- [ ] Confirmation dialogs before destructive actions (delete task, burn data)

#### 4.3 Memory leaks
- [ ] `autoDispose` on providers for screens that get popped
- [ ] Controllers (TextEditingController, etc.) disposed in `dispose()` method
- [ ] Stream subscriptions cancelled on dispose
- [ ] No listeners attached without cleanup

### Phase 5: Security

#### 5.1 Auth & Firestore rules
- [ ] Firestore security rules enforce household membership
- [ ] Users can only read/write data in their own household
- [ ] Admin-only operations (e.g., Drive connect) are enforced server-side
- [ ] No sensitive data in Firestore document IDs or collection paths
- [ ] All Firestore collections referenced in code have corresponding security rules in `firestore.rules`
- [ ] Verify `plan_attachments` rule exists (was missing historically — caused burn failures with permission-denied)
- [ ] Verify `household_invites` rule exists
- [ ] Burn flow: `wipeAllData()` deletes from ALL collections including `household_invites` and `plan_attachments`

#### 5.2 Google Drive
- [ ] Drive access scope is minimal (only Pacelli folder)
- [ ] Drive tokens are stored securely (flutter_secure_storage)
- [ ] Disconnecting Drive revokes token
- [ ] File URLs are shareable view-only links (not edit links)
- [ ] Attachments upload to the household owner's Drive folder via `GoogleDriveService`
- [ ] Attachment metadata (file name, mime type, links) is encrypted in Firestore; only the Drive file ID and size are plaintext

#### 5.3 Local storage
- [ ] Encryption keys stored in flutter_secure_storage (not SharedPreferences)
- [ ] No sensitive data in plain-text logs
- [ ] Debug prints removed from production code

### Phase 6: Internationalisation (i18n)

#### 6.1 String audit
- [ ] Run a grep for hardcoded English strings in all `lib/features/` files:
  ```bash
  grep -rn "'[A-Z][a-z]" lib/features/ --include="*.dart" | grep -v "import\|//\|case\|Icons\|Color\|Font\|Key\|Route\|const\|return '"
  ```
- [ ] Check bottom nav labels use `context.l10n.nav*`
- [ ] Check all dialog titles and messages use l10n keys
- [ ] Check all snackbar messages use l10n keys
- [ ] Check all form labels and hints use l10n keys

#### 6.2 ARB file sync
- [ ] All keys in `app_en.arb` exist in `app_es.arb`
- [ ] All keys in `app_en.arb` exist in `app_it.arb`
- [ ] No orphaned keys (keys in ES/IT that don't exist in EN)
- [ ] Placeholder consistency: all `{param}` names match across locales

## How to Run the Audit
1. Read this checklist
2. For each section, use `grep`, `Read`, and code inspection to verify
3. Log any findings as a numbered list with file paths and line numbers
4. Fix issues in priority order: security > encryption > data integrity > error handling > i18n > state management
5. After fixes, rebuild and test: `flutter clean && flutter pub get && flutter run`

### Phase 7: Notifications & Import/Export

#### 7.1 Notification service
- [ ] `NotificationService` properly initialises `flutter_local_notifications`
- [ ] Notification permissions requested gracefully (no crash on denial)
- [ ] Task reminders schedule correctly based on due date/time
- [ ] Notification settings screen toggles persist via SharedPreferences
- [ ] Notifications cleared on burn/sign-out

#### 7.2 Import/Export
- [ ] Export service serialises all household data (tasks, plans, checklists, categories, attachments)
- [ ] Encrypted fields are decrypted before export (export is plaintext JSON)
- [ ] Import service validates JSON structure before writing
- [ ] Import handles both Firebase and SQLite backends
- [ ] Import does not create duplicate entries (check for existing IDs)
- [ ] Error handling for corrupt/malformed import files
- [ ] All import/export status messages use l10n keys

## Audit Frequency
- **Before every release**: Full audit (all phases)
- **After adding a new feature**: Phases 1, 3, 4, 6, and 7
- **After changing auth/encryption**: Phases 2 and 5
- **After adding a new locale**: Phase 6 only
- **After adding/changing attachment support**: Phases 2 and 5
