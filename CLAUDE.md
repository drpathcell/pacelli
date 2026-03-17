# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
# Run the app (iOS / Android / macOS)
flutter run

# Analyze code (linting)
flutter analyze

# Run tests
flutter test
# Single test file
flutter test test/path_to_test.dart

# Code generation (Riverpod generators, localisation)
dart run build_runner build --delete-conflicting-outputs

# Regenerate localisation files after editing .arb files
flutter gen-l10n

# Install dependencies
flutter pub get
```

## Architecture Overview

**Pacelli** is a Flutter household management app with a dual-backend architecture (Firebase Cloud Firestore or local SQLite) and end-to-end encryption.

### Dual Storage Backend

The app supports two storage backends, chosen during onboarding (`StorageSetupScreen`):

- **Firebase** (`FirebaseDataRepository`) — Cloud Firestore with E2E encryption via `EncryptionService`. Human-readable fields (titles, descriptions, names) are encrypted before leaving the device. Structural metadata (IDs, status, timestamps, booleans) is stored unencrypted for query support.
- **Local SQLite** (`LocalDataRepository`) — Offline-first, on-device storage via `sqflite`. Schema mirrors Firestore collections so models use the same `fromMap()` factories.

Both implement the `DataRepository` abstract interface (`lib/core/data/data_repository.dart`). The active backend is resolved at runtime by `dataRepositoryProvider` in `lib/core/data/data_repository_provider.dart`, which checks `SharedPreferences` for the user's choice and whether a local `Database` instance is available.

### Encryption System

- **AES-256-CBC** with per-household symmetric keys (`EncryptionService` in `lib/core/crypto/encryption_service.dart`)
- `KeyManager` (`lib/core/crypto/key_manager.dart`) handles key lifecycle: generation, per-user wrapping (encrypted with a key derived from Firebase UID), Firestore storage in `household_keys`, local caching via `flutter_secure_storage`
- When a new member joins, the existing member's device re-encrypts the household key for the new member's UID
- The local SQLite backend does not encrypt data (it stays on-device)
- **Empty string guard**: `_enc()` checks `plaintext.isNotEmpty` before encrypting — AES-256-CBC crashes on empty strings (`RangeError`). `_dec()` checks `ciphertext.isEmpty` before decrypting.
- **Static vs singleton pitfall in HouseholdService**: The static `keyManager` field is often `null`. Always use `final km = keyManager ?? KeyManager.instance` and reference `km.householdKey` directly — the static `_key` getter returns `null` when `keyManager` is `null` even if the singleton has the key loaded.
- **Burn flow batch ordering**: When wiping household data, the user's own `household_members` doc and the `households` doc must be deleted in the LAST batch. Earlier deletion breaks `isMember()` for remaining batches. Batch retry must throw on failure, not silently break.
- **Firestore offline cache**: After burn, must call `FirebaseFirestore.instance.terminate()` then `clearPersistence()` to wipe the local disk cache. Without this, the SDK serves stale data on re-login, bypassing security rules.

### State Management & DI

- **Riverpod** (`flutter_riverpod`) for all state management and dependency injection
- Providers are defined alongside their feature data layer (e.g., `lib/features/tasks/data/task_providers.dart`)
- `dataRepositoryProvider` is the central DI point — all feature providers read from it
- `keyManagerProvider` provides the encryption key manager globally

### Routing

- **GoRouter** configured in `lib/config/routes/app_router.dart`
- Route path constants live in `AppRoutes` class — use these instead of hardcoded strings
- `ShellRoute` wraps five nav destinations (Home, Tasks, AI Chat spacer, Calendar, Settings) with `MainShell` bottom nav
- Center FAB (semicircle above nav bar) opens the AI Chat screen via `context.push(AppRoutes.aiChat)`
- Full-screen routes (create task, task detail, plans, AI chat, onboarding) sit outside the shell

### Feature Structure

```
lib/features/<feature>/
  data/           # Service classes, Riverpod providers
  presentation/
    screens/      # Full page widgets
    widgets/      # Reusable feature-specific widgets
  utils/          # Feature-specific helpers
```

Domain entities: Tasks, Subtasks, Categories, Checklists, Plans (scratch plans with entries), Attachments (Google Drive), Inventory. Models live in `lib/core/models/` with a barrel export in `models.dart`.

### In-App AI Chat

The app includes a built-in AI chat accessible from every tab via a center FAB in the bottom nav:
- **Feature directory**: `lib/features/ai_chat/` — data models, service, providers, screens, widgets
- **Entry point**: Center semicircle FAB in `MainShell` → pushes `/ai-chat` route
- **ChatService**: Calls the `aiChat` Cloud Function with Firebase ID tokens (auto-cached 55 min)
- **State**: Riverpod `chatMessagesProvider` (StateNotifier), `chatServiceProvider`, `chatLoadingProvider`
- **Cloud Function**: `aiChat` export in `functions/src/index.ts` — MVP uses keyword-based intent routing; future: LLM function-calling
- **l10n keys**: `aiChat*` prefix across all 3 locales (EN/ES/IT)

### AI Assistant Settings

The Settings → AI Assistant screen lets users connect an external AI provider:
- **Feature directory**: `lib/features/settings/` — `ai_assistant_screen.dart` + `ai_assistant_service.dart`
- **Provider picker**: Card-based selection of Claude, Gemini, or ChatGPT (`AiProvider` enum in screen file)
- **API key storage**: Encrypted via `FlutterSecureStorage`, provider name in `SharedPreferences`
- **Service**: `AiAssistantService` — manages provider config, API key CRUD, Firebase token generation
- **Advanced section**: Collapsible MCP configuration (token gen, API URL, connection mode, config JSON) for developers
- **l10n keys**: `aiAssistant*` prefix across all 3 locales (EN/ES/IT)
- **Route**: `/ai-assistant` via `AppRoutes.aiAssistant`

### Capability Discovery

The app includes a "What can Pacelli do?" discovery screen accessible from Settings:
- **Feature directory**: `lib/features/capabilities/` — static data catalogue + presentation screen
- **Data**: `capability_data.dart` — 8 `CapabilityGroup`s with 24 `Capability` entries, each with icon, l10n title/desc keys, and `aiSupported` flag
- **Screen**: `capabilities_screen.dart` — expandable group cards via `ExpansionTile`, "AI" badge on AI-capable features
- **MCP resource**: `pacelli://capabilities` registered in `mcp-server/src/index.ts` — static JSON for AI agent discovery
- **Route**: `/capabilities` via `AppRoutes.capabilities`
- **l10n keys**: `cap*` prefix (capScreenTitle, capGroup*, capTask*, capChecklist*, etc.) across all 3 locales

### Feedback & Learning Loop

User feedback collection, automated diagnostics, and weekly usage digests in `lib/features/feedback/`:
- **3 models** (`lib/core/models/feedback_entry.dart`): `FeedbackEntry` (type, rating, message), `AppDiagnostic` (kind, summary, detail, source), `WeeklyDigest` (activity counts + AI summary)
- **FeedbackService** (`lib/features/feedback/data/feedback_service.dart`): Firestore-direct service (not DataRepository) for submitting feedback, logging diagnostics, and fetching digests. Encrypts message/context fields.
- **3 providers** in `feedback_providers.dart`: `feedbackServiceProvider`, `feedbackListProvider`, `diagnosticsProvider`, `weeklyDigestsProvider`
- **1 screen**: `FeedbackScreen` with 3 tabs — Submit (form with type/rating/message), History (feedback cards), Digests (weekly summary cards with stat chips)
- **AI chat feedback**: Thumbs up/down buttons on assistant chat bubbles in `ChatBubble` widget, tracked by `_ratedMessageIds` in `ChatScreen`
- **3 Firestore collections**: `feedback`, `diagnostics`, `weekly_digests` — all with `household_id` membership rules
- **5 Cloud Functions**: `feedbackList`, `diagnosticsList`, `diagnosticStatsGet`, `weeklyDigestGenerate`, `weeklyDigestList`
- **Cloud Function logic**: `functions/src/functions/feedback.ts` — list/stats/digest generation with encrypted field handling
- **4 MCP tools**: `list_feedback`, `get_diagnostic_stats`, `generate_weekly_digest`, `list_weekly_digests`
- **1 MCP resource**: `pacelli://diagnostics` — live 7-day error/warning/feedback sentiment summary
- **Route**: `/feedback` via `AppRoutes.feedback`
- **l10n keys**: `feedback*` + `settingsFeedback*` prefix across all 3 locales (EN/ES/IT)

### House Manual

Knowledge base / reference guide feature in `lib/features/manual/`:
- **2 models** (`lib/core/models/manual_entry.dart`): `ManualEntry` (Markdown content, tags, pin support, creator/editor tracking), `ManualCategory`
- **5 screens**: manual list (with category filter chips + search), entry detail, create entry, edit entry, manage categories
- **1 widget**: `ManualEntryCard` — card with title, content preview, category chip, tags, relative date
- **5 providers** in `manual_providers.dart`: `manualEntriesProvider`, `manualEntriesByCategoryProvider`, `manualEntryProvider`, `manualCategoriesProvider`, `manualSearchProvider`
- **2 Firestore collections**: `manual_entries`, `manual_categories` — both with `household_id` membership rules
- **Encryption**: title, content, tags encrypted; category_id, is_pinned, timestamps unencrypted
- **SQLite**: `manual_entries` + `manual_categories` tables (migration v3→v4), tags stored as JSON string
- **Export/Import**: manual data included in v3 JSON backup format with category ID remapping on import
- **Routes**: `/manual`, `/manual/create`, `/manual/:entryId`, `/manual/:entryId/edit`, `/manual/categories`
- **l10n keys**: `manual*` prefix + `settingsManual*` across all 3 locales (EN/ES/IT)

### Inventory Feature

Full household inventory management in `lib/features/inventory/`:
- **5 models** (`lib/core/models/inventory_item.dart`): `InventoryItem`, `InventoryCategory`, `InventoryLocation`, `InventoryLog`, `InventoryAttachment`
- **9 screens**: inventory list, item detail, create/edit item, batch create, barcode scanner, virtual barcode view, manage categories, manage locations
- **5 widgets**: inventory_item_card, inventory_category_chip, inventory_log_tile, quantity_adjuster, calendar_inventory_section
- **7 providers** in `inventory_providers.dart` + `inventoryTaskServiceProvider` in `inventory_task_service.dart`
- **5 Firestore collections**: inventory_items, inventory_categories, inventory_locations, inventory_logs, inventory_attachments
- **Barcode scanning**: `mobile_scanner` (v7+, Apple Vision framework) for real barcodes, `qr_flutter` for virtual QR code generation
- **Notifications**: expiry reminders (`scheduleExpiryReminder`), low stock alerts (`sendLowStockNotification`) via `inventory_reminders` Android channel
- **Calendar integration**: `CalendarInventorySection` shows expiring items on selected day with orange dot markers
- **Auto-task creation**: `InventoryTaskService` creates restock/expiry tasks with duplicate detection
- **Export/Import**: inventory data included in v2 JSON backup format with category/location ID remapping on import

### Localisation

- ARB-based (`flutter_localizations`), config in `l10n.yaml`
- Template: `lib/l10n/app_en.arb`, translations: `app_es.arb`, `app_it.arb`
- Generated output: `lib/l10n/app_localizations.dart` (do not edit manually)
- Access via `AppLocalizations.of(context)` — all user-facing strings must be localised
- Use the `/pacelli-add-arb-keys` skill to add new keys across all locales

### Theming

- Material 3 with Plus Jakarta Sans font
- Three colour schemes: `pacelli` (sage green), `claude` (purple), `gemini` (ocean blue) — defined in `lib/config/theme/color_schemes.dart`
- Theme preferences (mode + scheme) persisted via `SharedPreferences`, managed by `ThemePreferencesNotifier`
- `AppTheme.lightThemeFor(scheme)` / `darkThemeFor(scheme)` build complete `ThemeData`
- **Minimum font size: 13px** — enforced via theme (`bodySmall: 13`, `labelSmall: 13`, `labelMedium: 13`) and explicit overrides. No text in the app should be below 13px.
- Shared semantic colours (success, warning, error, info) in `SharedColors`
- **AI icon**: Custom smiling robot SVG (`assets/icons/pacelli_ai.svg`) rendered via `PacelliAiIcon` widget (`lib/shared/widgets/pacelli_ai_icon.dart`). Uses `flutter_svg` with `ColorFilter` for tinting. Used in nav FAB, chat bubbles, settings, capabilities badges, feedback.
- Use the `/pacelli-theme-colours` skill for theme/colour changes

### Firestore Security Rules

- `firestore.rules` uses deterministic doc IDs for membership: `{userId}_{householdId}`
- `isMember()` helper checks membership via `exists()` on the deterministic doc path
- **ALL collections** (parent and child) enforce `isMember(resource.data.household_id)` for read/write rules
- `household_id` is denormalized onto every document in every collection (including subtasks, checklist_items, plan_entries, plan_checklist_items, all attachment and inventory child collections)
- **CRITICAL**: Every Firestore list/query on a child collection MUST include `.where('household_id', isEqualTo: ...)` — the security rules require it. Queries without this filter will get `permission-denied`. Single document reads (`.doc(id).get()`) are fine without it since rules evaluate against the document data.
- When a query needs both `household_id` and a parent ID (e.g. `task_id`), query by `household_id` and filter client-side, or use both filters with a composite index
- Composite indexes for `household_id` + parent ID combinations are defined in `firestore.indexes.json`

### Household Service

`HouseholdService` (`lib/features/household/data/household_service.dart`) handles household CRUD separately from `DataRepository`. It uses static methods and directly accesses Firestore. It is not part of the `DataRepository` interface because household management (invites, members, encryption key sharing) is Firebase-only.

## Custom Skills

The `.claude/skills/` directory contains project-specific skills invocable as slash commands:
- `/pacelli-add-screen` — scaffold a new screen/feature
- `/pacelli-add-arb-keys` — add localisation keys across all locales
- `/pacelli-add-language` — add a new language
- `/pacelli-theme-colours` — manage theme and colour schemes
- `/pacelli-backend-audit` — audit backend (Firestore + SQLite) consistency
- `/pacelli-security-audit` — audit encryption and data wipe flows
