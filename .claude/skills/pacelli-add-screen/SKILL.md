# Pacelli — Add a New Screen / Feature

## Overview
This skill scaffolds a new screen or feature in the Pacelli Flutter app following the established architecture: clean architecture layers, Riverpod for state, GoRouter for navigation, and full i18n support across all locales.

## Project Location
The Pacelli project is at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Architecture Overview
```
lib/
├── config/
│   ├── routes/app_router.dart          # GoRouter config + AppRoutes constants
│   └── theme/
│       ├── app_colors.dart             # Legacy colour constants (backward compat)
│       ├── app_theme.dart              # Light/dark ThemeData builder
│       └── color_schemes.dart          # AppColorScheme enum + palettes
├── core/
│   ├── crypto/
│   │   ├── encryption_service.dart     # AES-256-CBC encrypt/decrypt
│   │   └── key_manager.dart            # Key lifecycle (create/load/share/clear)
│   ├── data/
│   │   ├── data_repository.dart        # Abstract repository interface
│   │   ├── data_repository_provider.dart # Riverpod provider
│   │   ├── firebase_data_repository.dart # Firestore implementation (encrypted)
│   │   ├── local_data_repository.dart  # SQLite implementation (offline cache)
│   │   ├── local_database.dart         # SQLite schema + helpers
│   │   └── profile_cache.dart          # User profile cache
│   ├── models/
│   │   ├── attachment.dart             # TaskAttachment + PlanAttachment models
│   │   ├── checklist.dart              # Checklist + ChecklistItem
│   │   ├── household.dart              # Household model
│   │   ├── models.dart                 # Barrel export
│   │   ├── plan.dart                   # Plan + PlanEntry models
│   │   └── task.dart                   # Task + Subtask models
│   ├── services/
│   │   └── google_drive_service.dart   # Google Drive upload/download
│   ├── utils/
│   │   └── extensions.dart             # context.l10n, context.textTheme, etc.
│   └── widgets/
│       ├── error_view.dart             # Reusable error widget
│       └── loading_view.dart           # Reusable loading widget
├── features/
│   ├── auth/
│   ├── home/
│   ├── household/
│   ├── plans/
│   │   ├── data/plan_providers.dart
│   │   └── presentation/
│   │       ├── screens/                # create, view, finalise, day_editor
│   │       └── widgets/               # entry_chip, plan_day_card
│   ├── settings/
│   │   └── presentation/screens/      # settings, appearance, privacy, burn_data
│   └── tasks/
│       ├── data/task_providers.dart
│       └── presentation/
│           ├── screens/               # tasks, create_task, edit_task, task_detail, calendar
│           └── widgets/               # attachment_list, attachment_picker, calendar_*
├── l10n/
│   ├── app_en.arb                      # English (template, ~464 keys)
│   ├── app_es.arb                      # Spanish
│   └── app_it.arb                      # Italian
└── shared/
    └── widgets/
        └── main_shell.dart             # Bottom nav shell
```

## Steps to Add a New Screen

### 1. Determine scope
Ask/clarify:
- **Feature name**: e.g., `recipes`, `budgets`, `notes`
- **Is it a new feature or a screen within an existing feature?**
- **Does it need its own tab in the bottom nav?** (rare — currently 4 tabs: Home, Tasks, Calendar, Settings)
- **Does it need data providers?** (API calls, Firestore queries)
- **What UI strings are needed?** (for l10n)

### 2. Create the feature directory structure
For a brand new feature:
```bash
mkdir -p lib/features/{feature_name}/{data,domain,presentation/{screens,widgets},utils}
```
For a new screen in an existing feature, just add the screen file.

### 3. Create the screen file
File: `lib/features/{feature_name}/presentation/screens/{screen_name}_screen.dart`

**Template (ConsumerWidget with Riverpod):**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';

class {ScreenName}Screen extends ConsumerWidget {
  const {ScreenName}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.{featurePrefix}Title),
      ),
      body: const Center(
        child: Text('TODO'),
      ),
    );
  }
}
```

**Key patterns:**
- Always use `ConsumerWidget` (or `ConsumerStatefulWidget` if you need `initState`/controllers)
- Always import `extensions.dart` for `context.l10n` and `context.textTheme`
- Use `ErrorView` and `LoadingView` for async states
- Use `context.l10n.{key}` for ALL user-visible strings — no hardcoded English

### 4. Create data providers (if the screen needs data)
File: `lib/features/{feature_name}/data/{feature}_providers.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository_provider.dart';

final {feature}ListProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, householdId) async {
    final repo = ref.watch(dataRepositoryProvider);
    return repo.get{Feature}List(householdId);
  },
);
```

### 5. Add the route to GoRouter
File: `lib/config/routes/app_router.dart`

**a) Add the route path constant:**
```dart
class AppRoutes {
  // ... existing routes ...
  static const String {featureName} = '/{feature-name}';
}
```

**b) Add the import at the top:**
```dart
import '../../features/{feature_name}/presentation/screens/{screen_name}_screen.dart';
```

**c) Add the GoRoute:**
- If it's a **top-level screen** (under the shell/bottom nav): add inside the `ShellRoute`'s `routes` list
- If it's a **detail/push screen** (no bottom nav): add as a standalone `GoRoute` outside the shell

```dart
GoRoute(
  path: AppRoutes.{featureName},
  builder: (context, state) => const {ScreenName}Screen(),
),
```

### 6. Add l10n keys to ALL ARB files
Follow the **pacelli-add-arb-keys** skill for this step. At minimum, every new screen needs:
- A title key: `{featurePrefix}Title`
- Loading state: `{featurePrefix}Loading`
- Error state: `{featurePrefix}CouldNotLoad`
- Any other UI strings

Add to ALL locale files: `app_en.arb`, `app_es.arb`, `app_it.arb`

### 7. Add to bottom nav (only if it's a new tab)
If the new screen is a new tab (rare), update:
- `lib/shared/widgets/main_shell.dart` — add a `NavigationDestination`
- `lib/config/routes/app_router.dart` — add to the `ShellRoute` and update the tab index mapping
- Add `nav{Feature}` key to all ARB files

### 8. Build and verify
```bash
flutter clean && flutter pub get && flutter run
```

## Checklist for Every New Screen
- [ ] Screen file created with `ConsumerWidget`
- [ ] `extensions.dart` imported
- [ ] All UI strings use `context.l10n.{key}` — zero hardcoded English
- [ ] l10n keys added to `app_en.arb` (with `@key` metadata if placeholders exist)
- [ ] l10n keys added to `app_es.arb` (translated Spanish)
- [ ] l10n keys added to `app_it.arb` (translated Italian)
- [ ] Route added to `app_router.dart` with path constant in `AppRoutes`
- [ ] Data providers created (if needed)
- [ ] Reusable `ErrorView` / `LoadingView` used for async states
- [ ] Builds without errors in all 3 locales
- [ ] If the screen handles user content, encrypt sensitive fields via `_enc()`/`_encN()` in the repository
- [ ] If the screen supports attachments, use `AttachmentPicker` and `AttachmentList` widgets
- [ ] If the screen has a create flow, consider deferred uploads (pick files first, upload after save)

## Common Pitfalls
- **Forgetting the extensions import**: Without it, `context.l10n` won't resolve — causes build failure
- **Hardcoding strings**: Every user-visible string must go through l10n, even "OK" and "Cancel" (use `commonOk`, `commonCancel`)
- **Missing locale files**: A key in `app_en.arb` missing from `app_es.arb` or `app_it.arb` will fail the build
- **Wrong import path depth**: Count the `../` segments carefully — screens are typically 4 levels deep from `lib/`
- **Using StatelessWidget instead of ConsumerWidget**: If the screen needs any Riverpod provider, it must be `Consumer*`
- **Forgetting the dual-repo pattern**: Both `FirebaseDataRepository` and `LocalDataRepository` need methods for any new data type
- **Not encrypting new content fields**: Any user-visible text field in Firestore must use `_enc()` or `_encN()` — check the security audit skill
