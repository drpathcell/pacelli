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

### State Management & DI

- **Riverpod** (`flutter_riverpod`) for all state management and dependency injection
- Providers are defined alongside their feature data layer (e.g., `lib/features/tasks/data/task_providers.dart`)
- `dataRepositoryProvider` is the central DI point — all feature providers read from it
- `keyManagerProvider` provides the encryption key manager globally

### Routing

- **GoRouter** configured in `lib/config/routes/app_router.dart`
- Route path constants live in `AppRoutes` class — use these instead of hardcoded strings
- `ShellRoute` wraps the four main tabs (Home, Tasks, Calendar, Settings) with `MainShell` bottom nav
- Full-screen routes (create task, task detail, plans, onboarding) sit outside the shell

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
- Shared semantic colours (success, warning, error, info) in `SharedColors`
- Use the `/pacelli-theme-colours` skill for theme/colour changes

### Firestore Security Rules

- `firestore.rules` uses deterministic doc IDs for membership: `{userId}_{householdId}`
- `isMember()` helper checks membership via `exists()` on the deterministic doc path
- Parent-level collections (tasks, categories, checklists, plans) verify household membership
- Child collections (subtasks, checklist items, plan entries) allow any authenticated user (membership checked at app level)

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
