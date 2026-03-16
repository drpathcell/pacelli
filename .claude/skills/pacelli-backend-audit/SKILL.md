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
- **Notifications**: Local push notifications via `flutter_local_notifications` (`lib/core/services/notification_service.dart`) — separate channels for `task_reminders` and `inventory_reminders`
- **Import/Export**: JSON export/import of household data (`lib/features/import_export/data/`) — version 3 format includes inventory + manual
- **Inventory**: Full CRUD with barcode scanning (`mobile_scanner`), virtual QR codes (`qr_flutter`), batch creation, expiry/low-stock notifications, calendar integration, and auto-task creation (`lib/features/inventory/`)
- **House Manual**: Knowledge base with Markdown entries, categories, tags, pinning — `lib/features/manual/`
- **Feedback & Learning Loop**: Feedback collection, diagnostic logging, weekly usage digests — `lib/features/feedback/` (Firestore-direct via `FeedbackService`, not through `DataRepository`)
- **Burn All Data**: Full wipe sequence including Firestore, local DB, secure storage, SharedPreferences, notification cancellation, and Firebase Auth account deletion with re-authentication (`lib/features/settings/presentation/screens/burn_data_screen.dart`)

## Audit Checklist

### Phase 1: Data Layer Integrity

#### 1.1 Repository Provider
- [ ] `data_repository_provider.dart` exists and is the single source of truth
- [ ] All Firestore reads/writes go through the repository — no direct Firestore calls from UI
- [ ] Repository methods return typed data (or `Map<String, dynamic>` consistently)
- [ ] No business logic leaks into the repository — it's a pure data layer
- [ ] `local_data_repository.dart` mirrors all read/write methods from the Firebase implementation
- [ ] `local_database.dart` schema includes tables for: tasks, subtasks, plans, plan_entries, plan_checklist_items, categories, checklists, checklist_items, task_attachments, plan_attachments, household_members, households, inventory_items, inventory_categories, inventory_locations, inventory_logs, inventory_attachments, manual_entries, manual_categories (+ 7 indexes on inventory tables)
- [ ] DataRepository interface includes inventory methods: `createInventoryItem`, `getInventoryItems`, `getInventoryItem`, `updateInventoryItem`, `deleteInventoryItem`, inventory categories CRUD, inventory locations CRUD, `logInventoryAction`, `getInventoryLogs`, inventory attachments CRUD, `getInventoryStats`
- [ ] DataRepository interface includes manual methods: `createManualEntry`, `getManualEntries`, `getManualEntry`, `updateManualEntry`, `deleteManualEntry`, manual categories CRUD
- [ ] `searchHousehold` includes `'inventory'` in default `entityTypes`

#### 1.2 Feature Providers
For each feature (`tasks`, `plans`, `checklists`, `household`, `settings`, `auth`, `attachments`, `import_export`, `onboarding`, `inventory`, `manual`, `feedback`):
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
- [ ] Inventory item names (`_enc`), descriptions (`_encN`), unit (`_enc`), barcode (`_encN`), notes (`_encN`)
- [ ] Manual entry titles (`_enc`), content (`_enc`), tags (`_enc` per tag)
- [ ] Feedback entry messages (`_enc`), context (`_encN`)
- [ ] Diagnostic summaries (`_enc`), details (`_encN`)
- [ ] Weekly digest summaries (`_encN`)

#### 2.2 What must NOT be encrypted (structural fields)
- [ ] Task status (pending, completed)
- [ ] Priority levels
- [ ] Due dates and timestamps
- [ ] Checked/completed booleans
- [ ] Sort order
- [ ] Category icons and colours
- [ ] Recurrence values
- [ ] Attachment file IDs (Google Drive IDs) and file sizes
- [ ] Inventory: quantity, low_stock_threshold, expiry_date, purchase_date, barcode_type, category_id, location_id, household_id, created_by, timestamps

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

#### 4.1b Inventory providers
- [ ] 7 providers in `inventory_providers.dart`: `inventoryItemsProvider`, `inventoryItemProvider`, `inventoryCategoriesProvider`, `inventoryLocationsProvider`, `inventoryStatsProvider`, `inventoryLogsProvider`, `inventoryViewModeProvider`
- [ ] `inventoryViewModeProvider` is a `StateProvider<String>` (not FutureProvider)
- [ ] `inventoryTaskServiceProvider` in `inventory_task_service.dart` is `Provider.family<InventoryTaskService, String>`

#### 4.1c Manual providers
- [ ] 5 providers in `manual_providers.dart`: `manualEntriesProvider`, `manualEntriesByCategoryProvider`, `manualEntryProvider`, `manualCategoriesProvider`, `manualSearchProvider`

#### 4.1d Feedback providers
- [ ] `FeedbackService` is Firestore-direct (like `HouseholdService`) — NOT through `DataRepository`
- [ ] `FeedbackService` uses constructor-injected `householdId` — NOT `SharedPreferences` lookup
- [ ] 4 providers in `feedback_providers.dart`: `feedbackServiceProvider`, `feedbackListProvider`, `diagnosticsProvider`, `weeklyDigestsProvider`
- [ ] `feedbackServiceProvider` watches `keyManagerProvider` AND `currentHouseholdProvider`
- [ ] Household ID extracted via nested path: `(household?['household'] as Map<String, dynamic>?)?['id']` — NOT `household?['id']`

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
- [ ] Inventory parent collections (inventory_items, inventory_categories, inventory_locations) use `isMember()` Firestore rules
- [ ] Inventory child collections (inventory_logs, inventory_attachments) use `isAuth()` because queries filter by item_id without household_id
- [ ] Manual collections (manual_entries, manual_categories) use `isMember()` Firestore rules
- [ ] Feedback collections (feedback, diagnostics) use `isMember()` Firestore rules
- [ ] Weekly digests collection (weekly_digests) uses `isMember()` for read/create/update (no delete)
- [ ] Burn flow: `wipeAllData()` deletes from ALL collections including `household_invites`, `plan_attachments`, all 5 inventory collections, `manual_entries`, `manual_categories`, `feedback`, `diagnostics`, `weekly_digests`

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
- [ ] Notifications cleared on burn/sign-out (burn screen calls `notificationServiceProvider.cancelAll()` as Step 0)
- [ ] Inventory notification methods: `scheduleExpiryReminder()`, `cancelExpiryReminder()`, `sendLowStockNotification()`
- [ ] Android notification channel: `inventory_reminders` / `Inventory Reminders` (separate from `task_reminders`)
- [ ] Stable notification IDs: `_stableId('expiry_$itemId')` and `_stableId('lowstock_$itemId')`

#### 7.2 Import/Export
- [ ] Export service serialises all household data (tasks, plans, checklists, categories, attachments, inventory, manual)
- [ ] Export version is 3 (includes inventory + `manual_entries`, `manual_categories`)
- [ ] Encrypted fields are decrypted before export (export is plaintext JSON)
- [ ] Import service validates JSON structure before writing
- [ ] Import handles both Firebase and SQLite backends
- [ ] Import handles v1 backups (without inventory) and v2 backups (without manual) gracefully — missing arrays default to empty
- [ ] Import order for inventory: categories → locations → items (with ID remapping for foreign keys)
- [ ] Import order for manual: categories → entries (with category ID remapping)
- [ ] Import does not create duplicate entries (check for existing IDs)
- [ ] Error handling for corrupt/malformed import files
- [ ] All import/export status messages use l10n keys

### Phase 8: Cloud Functions API Layer

The Cloud Functions REST API (`functions/`) is the server-side entry point for all AI-assisted access. Every endpoint is wrapped by `apiHandler()` which chains auth → rate limiting → error handling.

#### 8.1 API Handler Pattern
- [ ] `apiHandler()` in `functions/src/index.ts` applies auth, rate limiting, and error handling in that order
- [ ] Every exported Cloud Function uses `apiHandler()` — no raw `onRequest()` exports
- [ ] Error handling: `AuthError` → 401/403, `RateLimitError` → 429 with `Retry-After` header, generic → 500
- [ ] CORS is enabled (`cors: true`) on all endpoints
- [ ] `region` is set to `us-central1`

#### 8.2 Auth Middleware (`functions/src/middleware/auth.ts`)
- [ ] Verifies Firebase ID token via `admin.auth().verifyIdToken()`
- [ ] Returns `AuthContext` with `uid`, `householdId`, `householdKey`
- [ ] Resolves household via `resolveHouseholdId()` — queries `household_members` by `user_id`
- [ ] Loads encryption key via `loadHouseholdKey()` from `household_keys` collection
- [ ] Key decryption uses `decryptKeyWithMigration()` — supports v1→v2 HKDF transparent migration
- [ ] Missing/invalid token → 401, no household → 403, no key → 500

#### 8.3 Server-Side Encryption Middleware (`functions/src/middleware/encryption.ts`)
- [ ] `createFieldCrypto(householdKey)` returns `enc`/`dec`/`encN`/`decN` — mirrors client-side `_enc`/`_dec`/`_encN`/`_decN`
- [ ] `dec()` catches decrypt failures and returns `"[encrypted]"` placeholder (never leaks ciphertext)
- [ ] All business logic functions in `functions/src/functions/*.ts` use `createFieldCrypto()` — no raw crypto calls

#### 8.4 Server-Side Key Manager (`functions/src/crypto/key-manager.ts`)
- [ ] `loadHouseholdKey()` queries `household_keys` → derives user key via HKDF → decrypts → returns plaintext hex
- [ ] If v1 wrapping detected, auto-migrates to v2 by re-wrapping with HKDF-derived key
- [ ] `resolveHouseholdId()` queries `household_members` by `user_id` — returns first household
- [ ] No caching between requests (Cloud Functions are stateless)

#### 8.5 Rate Limiting (`functions/src/middleware/rate-limiter.ts`)
- [ ] Dual sliding window: short (per-minute) + long (per-hour) per user per operation type
- [ ] Current limits: Read 100/min + 500/hour, Write 30/min + 200/hour
- [ ] `classifyOperation()` auto-classifies: names ending in `List`/`Get`/`Stats`/`Search` → read, else → write
- [ ] `operationHint` override available for endpoints that don't fit the naming convention
- [ ] Rate limit data in `_rate_limits` collection keyed by `{uid}_{read|write}`
- [ ] Uses Firestore transactions for atomic check-and-increment
- [ ] Old timestamps pruned on every check (keeps documents small)
- [ ] `RateLimitError` includes `retryAfterSec` → sent as `Retry-After` header in 429 responses

#### 8.6 Endpoint Completeness
Verify every Cloud Function export in `functions/src/index.ts` has:
- [ ] Required parameter validation with explicit `throw new Error("x is required")`
- [ ] Correct rate limit classification (auto or `operationHint`)
- [ ] Corresponding MCP tool in `mcp-server/src/index.ts` inside `_registerTools()`
- [ ] Corresponding OpenAPI entry in `openapi/pacelli-api.yaml`

Endpoint count check (should match `functions/src/index.ts` exports):
- [ ] Tasks: 8 endpoints (tasksList, tasksGet, tasksCreate, tasksUpdate, tasksComplete, tasksReopen, tasksDelete, tasksStats)
- [ ] Subtasks: 3 (subtasksAdd, subtasksToggle, subtasksDelete)
- [ ] Categories: 3 (categoriesList, categoriesCreate, categoriesDelete)
- [ ] Checklists: 8 (checklistsList, checklistsGet, checklistsCreate, checklistsUpdate, checklistsDelete, checklistItemsAdd, checklistItemsToggle, checklistItemsDelete) + checklistItemsPushAsTask
- [ ] Plans: 5 + entries 3 + checklist items 4 + templates 3 = 15
- [ ] Attachments: 7 (task 3 + plan 4)
- [ ] Inventory: 15 (items 5 + categories 3 + locations 3 + logs 2 + attachments 3) + inventoryStats
- [ ] Feedback: 5 (feedbackList, diagnosticsList, diagnosticStatsGet, weeklyDigestGenerate, weeklyDigestList)
- [ ] Search: 1 (searchAll)

### Phase 9: MCP Server

The MCP server (`mcp-server/`) exposes the Cloud Functions API as MCP tools for AI assistants.

#### 9.1 Tool Registration
- [ ] All tools registered inside `_registerTools()` function — NOT outside (required for dual-transport)
- [ ] `_registerResources()` registers all resources — same dual-transport requirement
- [ ] `registerToolsAndResources()` called once for stdio server and once per HTTP session
- [ ] Every tool uses `z` (zod) for input validation with `.describe()` on parameters
- [ ] Tool names use snake_case: `list_tasks`, `get_task`, `create_task`, etc.
- [ ] Every `api.call()` function name matches the exported Cloud Function name exactly

#### 9.2 Resources
- [ ] `pacelli://schema` — static JSON describing the data model (entities and fields, including manual, feedback, diagnostic, and digest entities)
- [ ] `pacelli://summary` — live data: task stats, inventory stats, checklist count, plan count
- [ ] `pacelli://capabilities` — complete capability catalogue (8 groups with 24 capabilities)
- [ ] `pacelli://diagnostics` — live 7-day diagnostic summary (errors, warnings, feedback sentiment)
- [ ] Summary resource has try/catch with helpful fallback message on failure
- [ ] Schema resource accurately reflects current data model (including all inventory, manual, feedback entities)

#### 9.3 Transport Modes
- [ ] Stdio mode: `StdioServerTransport` — used by Claude Desktop locally
- [ ] HTTP mode: `StreamableHTTPServerTransport` — used by Cloud Run hosted deployment
- [ ] HTTP mode creates a fresh `McpServer` per session with `registerToolsAndResources()`
- [ ] `/health` endpoint returns 200 for Cloud Run health checks
- [ ] `MCP_ALLOWED_ORIGINS` environment variable controls CORS for HTTP mode

#### 9.4 Service Account Authentication (`mcp-server/src/token-manager.ts`)
- [ ] `TokenManager` initialises Firebase Admin SDK with Application Default Credentials
- [ ] Creates custom token via `admin.auth().createCustomToken(SERVICE_USER_UID)`, exchanges for ID token via Firebase Auth REST API
- [ ] Token cached with 5-minute expiry buffer, concurrent refreshes deduplicated via `refreshPromise`
- [ ] `ApiClient` uses `tokenProvider: () => tokenManager.getValidToken()` — no static auth token
- [ ] `FIREBASE_API_KEY` and `SERVICE_USER_UID` provided via Secret Manager, not env vars or source

#### 9.5 MCP Server Hardening
- [ ] HTTPS enforcement: `PACELLI_API_URL` must start with `https://` in HTTP mode
- [ ] Default-deny origins: `MCP_ALLOWED_ORIGINS` must be non-empty in HTTP mode
- [ ] Session TTL: 30-minute idle timeout, 60-second cleanup interval
- [ ] Rate limiting: 100 req/min per IP with sliding window, 429 + Retry-After on exceed
- [ ] Non-root container: `USER appuser` (UID 1001) in Dockerfile
- [ ] Health endpoint sanitised: returns only `{"status":"ok"}`

#### 9.6 Configuration & Secrets
- [ ] `PACELLI_API_URL` required — server exits on startup if missing
- [ ] Secrets in Google Cloud Secret Manager: `firebase-api-key`, `mcp-service-uid`, `mcp-sa-key`
- [ ] No secrets baked into Docker image — injected via Cloud Run `--set-secrets` at runtime
- [ ] `.env` files excluded from version control

#### 9.5 OpenAPI Spec (`openapi/pacelli-api.yaml`)
- [ ] Spec exists and is valid OpenAPI 3.0
- [ ] All Cloud Function endpoints have corresponding path entries
- [ ] All endpoints documented as POST with JSON body
- [ ] Request/response schemas match actual function signatures
- [ ] `components/schemas` includes models for all entity types

### Phase 10: Deployment & Build

#### 10.1 Cloud Functions
- [ ] `cd functions && npx tsc --noEmit` compiles cleanly
- [ ] `firebase deploy --only functions` deploys all endpoints
- [ ] Region set to `us-central1` in `apiHandler()`

#### 10.2 MCP Server Docker
- [ ] `mcp-server/Dockerfile` — multi-stage Node 20 slim build
- [ ] Production image: no dev dependencies, no source code, non-root user (UID 1001)
- [ ] Port 3000, health check at `/health`
- [ ] CMD: `node dist/index.js --http`

#### 10.3 Cloud Run Deployment
- [ ] Service: `pacelli-mcp` in `us-central1`
- [ ] Service account: `pacelli-mcp-sa@pacelli-35621.iam.gserviceaccount.com`
- [ ] IAM: service account has `roles/secretmanager.secretAccessor` for each secret
- [ ] Secrets mounted via `--set-secrets`: `FIREBASE_API_KEY=firebase-api-key:latest`, `SERVICE_USER_UID=mcp-service-uid:latest`
- [ ] Environment variables: `PACELLI_API_URL`, `MCP_ALLOWED_ORIGINS`
- [ ] Resource limits: 256Mi memory, 1 CPU, 0–3 max instances, 300s timeout
- [ ] Source-based deploy: `gcloud run deploy pacelli-mcp --source ./mcp-server --region us-central1`
- [ ] Service allows unauthenticated invocations (MCP protocol handles its own auth layer)

#### 10.4 TypeScript Compilation
- [ ] `cd functions && npx tsc --noEmit` — zero errors
- [ ] `cd mcp-server && npx tsc --noEmit` — zero errors

## Audit Frequency
- **Before every release**: Full audit (all phases)
- **After adding a new feature**: Phases 1, 3, 4, 6, 7, and 8–9 (if the feature is AI-accessible)
- **After changing auth/encryption**: Phases 2, 5, and 8.2–8.4
- **After adding a new locale**: Phase 6 only
- **After adding/changing attachment support**: Phases 2 and 5
- **After adding/changing a Cloud Function or MCP tool**: Phases 8 and 9
- **After changing rate limiting**: Phase 8.5
- **After changing MCP server auth or hardening**: Phases 9.4, 9.5, 9.6
- **After changing Cloud Run deployment config**: Phase 10.3
- **After changing deployment config**: Phase 10
