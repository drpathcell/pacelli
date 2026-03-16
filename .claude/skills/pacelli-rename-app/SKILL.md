---
name: pacelli-rename-app
description: >
  Complete guide for renaming the Pacelli app to a new name. Covers every codebase location
  (180+ references), third-party services (Firebase, Google Cloud, Apple Developer, Google Play,
  Google Drive API, domain/DNS), encryption salt migration, and post-rename verification.
  Use whenever the user mentions renaming the app, rebranding, changing the app name, or
  updating the bundle/package identifier.
---

# Pacelli — Rename / Rebrand the App

## Purpose
This skill provides a comprehensive, ordered checklist for renaming the app from "Pacelli" to a new name. It covers every file in the codebase, every third-party service, and every gotcha. The rename is a **breaking change** — it affects bundle IDs, database names, encryption salts, Firebase project references, and user-facing strings across 3 languages.

## Before You Start

### Prerequisites
- [ ] Decide on the **new name** (display name, e.g. "HomeHub")
- [ ] Decide on the **new package/bundle ID** (e.g. `com.newhome.homehub`) — must be lowercase, no spaces, reverse-domain
- [ ] Decide on the **new Dart package name** (e.g. `homehub`) — must be lowercase, underscores only, valid Dart identifier
- [ ] Decide whether to keep the **colour scheme enum value** `pacelli` or rename it (breaking change for persisted preferences)
- [ ] Back up the entire project: `git stash` or create a new branch `git checkout -b rename/new-name`

### Notation
Throughout this skill:
- `{NEW_NAME}` = the new display name (e.g. "HomeHub")
- `{new_name}` = lowercase version (e.g. "homehub")
- `{NEW_BUNDLE_ID}` = new bundle identifier (e.g. "com.newhome.homehub")
- `{NEW_DART_PKG}` = new Dart package name (e.g. "homehub")

---

## Phase 1: Flutter / Dart Code

### 1.1 pubspec.yaml (project name)
- [ ] `pubspec.yaml:1` — change `name: pacelli` → `name: {NEW_DART_PKG}`
- **Impact**: Every `import 'package:pacelli/...'` across the codebase breaks. Must update ALL imports.

### 1.2 Package imports (global find-and-replace)
```bash
grep -rn "package:pacelli/" lib/
```
- [ ] Replace ALL `package:pacelli/` → `package:{NEW_DART_PKG}/` across `lib/`
- Expected locations: `app.dart`, `extensions.dart`, all generated localisation files

### 1.3 App constants
- [ ] `lib/config/constants/app_constants.dart:16` — `appName = 'Pacelli'` → `appName = '{NEW_NAME}'`

### 1.4 Root widget
- [ ] `lib/app.dart:9` — update doc comment
- [ ] `lib/app.dart:13` — rename `PacelliApp` class → `{NEW_NAME}App` (optional, but consistent)
- [ ] `lib/app.dart:22` — `title: 'Pacelli'` → `title: '{NEW_NAME}'`
- [ ] `lib/main.dart:13` — update doc comment

### 1.5 Theme / colour scheme
The colour scheme `AppColorScheme.pacelli` is persisted in SharedPreferences as the string `"pacelli"`. Renaming it is a **breaking change** for existing users.

**Option A — Rename the enum (breaking):**
- [ ] `lib/config/theme/color_schemes.dart` — rename enum value `pacelli` → `{new_name}`, update all comments
- [ ] `lib/config/theme/app_theme.dart` — update default params and comments
- [ ] `lib/config/theme/app_colors.dart` — update comments
- [ ] `lib/config/theme/theme_preferences.dart:19` — update default: `AppColorScheme.{new_name}`
- [ ] `lib/config/theme/theme_preferences.dart:43` — update fallback string: `?? '{new_name}'`
- [ ] `lib/config/theme/theme_preferences.dart:94,100-101` — update parsing and serialisation
- [ ] `lib/features/settings/presentation/screens/appearance_screen.dart:183-195` — update switch cases
- [ ] Add a **migration**: if SharedPreferences has `"pacelli"`, map it to `"{new_name}"`

**Option B — Keep enum as `pacelli` (non-breaking):**
- [ ] Only update comments and display strings, leave the enum value unchanged
- This is the safer option if users already have the app installed

### 1.6 Encryption salts (CRITICAL — read carefully)
The encryption service uses hardcoded salt strings for key derivation. **Changing these breaks ALL existing encrypted data.**

- `lib/core/crypto/encryption_service.dart:93` — `'pacelli_e2e_key_derivation_v1'`
- `lib/core/crypto/encryption_service.dart:106` — `'pacelli_hkdf_salt_v2'`
- `lib/core/crypto/encryption_service.dart:111` — `'pacelli_e2e_user_key_v2'`

**RECOMMENDATION: DO NOT CHANGE THESE.** They are internal cryptographic constants, not user-facing. Changing them would make all existing household keys unreadable. If you must rename them:
- [ ] Create v3 versions with new names
- [ ] Add migration logic similar to v1→v2 migration
- [ ] Test thoroughly with existing encrypted data

### 1.7 Local database filename
- [ ] `lib/core/data/local_database.dart:16,38` — `'pacelli_local.db'` → `'{new_name}_local.db'`
- **Impact**: Existing local data will appear to be gone. Add migration to rename the file on first launch:
```dart
final oldPath = join(dbPath, 'pacelli_local.db');
final newPath = join(dbPath, '{new_name}_local.db');
if (await File(oldPath).exists()) {
  await File(oldPath).rename(newPath);
}
```

### 1.8 Google Drive folder name
- [ ] `lib/core/services/google_drive_service.dart:58` — `_rootFolderName = 'Pacelli'` → `'{NEW_NAME}'`
- [ ] `lib/core/services/google_drive_service.dart:130,134,137` — update comments and method name `ensurePacelliFolder` → `ensureAppFolder`
- [ ] `lib/features/household/presentation/screens/drive_setup_screen.dart:14,88-89` — update comments
- **Impact**: New folders will use the new name. Existing "Pacelli" folders in Google Drive stay as-is. Consider adding a migration to rename them, or document that users should manually rename.

### 1.9 Notification titles
- [ ] `lib/core/services/notification_service.dart:151,213,266` — `title: 'Pacelli'` → `title: '{NEW_NAME}'`

### 1.10 Export filenames
- [ ] `lib/features/import_export/data/export_service.dart:81` — `'pacelli_backup_$timestamp'` → `'{new_name}_backup_$timestamp'`
- [ ] `lib/features/import_export/data/export_service.dart:111` — `'pacelli_tasks_$timestamp'` → `'{new_name}_tasks_$timestamp'`
- **Note**: Old backups with `pacelli_backup_*` names should still import correctly (import validates structure, not filename).

### 1.11 Import service
- [ ] `lib/features/import_export/data/import_service.dart:14,24` — update comments only

### 1.12 Settings screen
- [ ] `lib/features/settings/presentation/screens/settings_screen.dart:19` — `applicationName: 'Pacelli'` → `applicationName: '{NEW_NAME}'`

### 1.13 Home screen
- [ ] `lib/features/tasks/presentation/screens/home_screen.dart:22` — update comment

### 1.14 AI Assistant
- [ ] `lib/features/settings/data/ai_assistant_service.dart:11,13` — update comment and possibly the default URL (see Phase 5)
- [ ] `lib/features/settings/presentation/screens/ai_assistant_screen.dart:11` — update comment
- [ ] `lib/features/settings/presentation/screens/ai_assistant_screen.dart:552,569,571` — update MCP server name in config JSON: `"pacelli"` → `"{new_name}"`

### 1.15 Other code comments
- [ ] `lib/core/errors/app_exception.dart:1` — update comment
- [ ] `lib/core/crypto/encryption_service.dart:8` — update comment

### 1.16 Firebase options (auto-generated)
- [ ] `lib/firebase_options.dart` — this file is **auto-generated** by FlutterFire CLI. After changing the Firebase project (Phase 5), re-run:
```bash
flutterfire configure
```

---

## Phase 2: Localisation (ARB Files)

There are ~15 ARB keys containing "Pacelli" across 3 locales. Each key must be updated in all locale files.

### 2.1 English (`lib/l10n/app_en.arb`)
- [ ] `authAccountCreated` — "Welcome to Pacelli" → "Welcome to {NEW_NAME}"
- [ ] `authAppName` — "Pacelli" → "{NEW_NAME}"
- [ ] `homeWelcomeToPacelli` — rename key to `homeWelcomeTo{NewName}` and update value
- [ ] `driveInfoFolder` — "A \"Pacelli\" folder" → "A \"{NEW_NAME}\" folder"
- [ ] `drivePrivacyNote` — "Pacelli only accesses" → "{NEW_NAME} only accesses"
- [ ] `drivePacelliFolder` — rename key to `drive{NewName}Folder` and update value
- [ ] `settingsAbout` — "About Pacelli" → "About {NEW_NAME}"
- [ ] `settingsAboutDescription` — "Pacelli helps your household" → "{NEW_NAME} helps your household"
- [ ] `privacyDriveExplanation` — multiple "Pacelli" references in this string
- [ ] `settingsBurnDriveWarning` — "Pacelli folder" → "{NEW_NAME} folder"
- [ ] `appearanceSchemePacelli` — rename key and value (if renaming colour scheme)
- [ ] `appearanceSchemePacelliDesc` — rename key and value (if renaming colour scheme)
- [ ] `ieImportDesc` — "Pacelli JSON backup" → "{NEW_NAME} JSON backup"
- [ ] `aiAssistantStep1Desc` — "your Pacelli account" → "your {NEW_NAME} account"
- [ ] `aiAssistantStep2Desc` — "your Pacelli instance" → "your {NEW_NAME} instance"

### 2.2 Spanish (`lib/l10n/app_es.arb`)
- [ ] Same 15 keys — translate "{NEW_NAME}" references into Spanish context

### 2.3 Italian (`lib/l10n/app_it.arb`)
- [ ] Same 15 keys — translate "{NEW_NAME}" references into Italian context

### 2.4 Dart code references to renamed keys
If any ARB key names changed (e.g. `homeWelcomeToPacelli` → `homeWelcomeTo{NewName}`):
- [ ] Update all `context.l10n.oldKeyName` references in Dart code to match

### 2.5 Regenerate
```bash
flutter gen-l10n
```

---

## Phase 3: Android Configuration

### 3.1 Package / application ID
- [ ] `android/app/build.gradle.kts:12` — `namespace = "com.pacelli.pacelli"` → `namespace = "{NEW_BUNDLE_ID}"`
- [ ] `android/app/build.gradle.kts:27` — `applicationId = "com.pacelli.pacelli"` → `applicationId = "{NEW_BUNDLE_ID}"`

### 3.2 App label
- [ ] `android/app/src/main/AndroidManifest.xml:4` — `android:label="pacelli"` → `android:label="{NEW_NAME}"`

### 3.3 Kotlin directory structure
The Kotlin source lives at `android/app/src/main/kotlin/com/pacelli/pacelli/`. The directory path must match the package name:
- [ ] Create new directory: `android/app/src/main/kotlin/{new/bundle/path}/`
- [ ] Move `MainActivity.kt` to the new directory
- [ ] Update `package` declaration in `MainActivity.kt:1`
- [ ] Delete old `com/pacelli/pacelli/` directory

### 3.4 Firebase config (Android)
- [ ] `android/app/google-services.json` — will be regenerated by Firebase CLI (Phase 5)

---

## Phase 4: iOS / macOS Configuration

### 4.1 iOS bundle identifier
- [ ] Open `ios/Runner.xcodeproj/project.pbxproj` — replace all `com.pacelli.pacelli` → `{NEW_BUNDLE_ID}` (6 occurrences)
- Or use Xcode: Runner → Signing & Capabilities → Bundle Identifier

### 4.2 iOS display name
- [ ] `ios/Runner/Info.plist:10` — CFBundleDisplayName: `Pacelli` → `{NEW_NAME}`
- [ ] `ios/Runner/Info.plist:18` — CFBundleName: `pacelli` → `{new_name}`
- [ ] `ios/Runner/Info.plist:70` — Camera usage description: update "Pacelli" → "{NEW_NAME}"

### 4.3 iOS Firebase config
- [ ] `ios/Runner/GoogleService-Info.plist` — will be regenerated by Firebase CLI (Phase 5)

### 4.4 macOS bundle identifier
- [ ] `macos/Runner/Configs/AppInfo.xcconfig:8` — `PRODUCT_NAME = pacelli` → `PRODUCT_NAME = {new_name}`
- [ ] `macos/Runner/Configs/AppInfo.xcconfig:11` — bundle identifier
- [ ] `macos/Runner/Configs/AppInfo.xcconfig:14` — copyright notice
- [ ] `macos/Runner.xcodeproj/project.pbxproj` — replace all `pacelli.app` → `{new_name}.app` and bundle IDs
- [ ] `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` — replace `pacelli.app` (4 occurrences)

### 4.5 macOS Firebase config
- [ ] `macos/Runner/GoogleService-Info.plist` — will be regenerated by Firebase CLI (Phase 5)

---

## Phase 5: Firebase & Google Cloud (THIRD-PARTY)

This is the most complex external step. Firebase project IDs **cannot be renamed** — you must either create a new project or keep the old ID.

### 5.1 Option A — Keep existing Firebase project (recommended)
The Firebase project ID `pacelli-35621` stays. Only the app display name changes:
- [ ] Go to [Firebase Console](https://console.firebase.google.com/) → Project Settings → General
- [ ] Change the **public-facing name** to "{NEW_NAME}"
- [ ] Under "Your apps", update each platform's **app nickname** to "{NEW_NAME}"
- [ ] **Android app**: register a new Android app with `{NEW_BUNDLE_ID}`, download new `google-services.json`
- [ ] **iOS app**: register a new iOS app with `{NEW_BUNDLE_ID}`, download new `GoogleService-Info.plist`
- [ ] **macOS app**: same as iOS
- [ ] Remove the old `com.pacelli.pacelli` app registrations after migration
- [ ] Run `flutterfire configure` to regenerate `firebase_options.dart`

### 5.2 Option B — Create a new Firebase project
If you want a completely new project ID:
- [ ] Create a new Firebase project in the console
- [ ] Enable: Authentication (Google, Email/Password), Cloud Firestore, Cloud Functions
- [ ] Set up Firestore security rules (copy from `firestore.rules`)
- [ ] Deploy Firestore indexes (copy from `firestore.indexes.json`)
- [ ] Register apps for each platform with `{NEW_BUNDLE_ID}`
- [ ] Download all config files
- [ ] Run `flutterfire configure`
- [ ] Update `.firebaserc` with new project alias
- [ ] Update `firebase.json` if needed
- [ ] **DATA MIGRATION**: Export all Firestore data from old project and import to new project
- [ ] **AUTH MIGRATION**: Firebase Auth users cannot be directly migrated — users will need to re-register or use Firebase Auth export/import CLI tools

### 5.3 Cloud Functions URL
- [ ] `lib/features/settings/data/ai_assistant_service.dart:13` — update `defaultApiUrl` if project ID changed
- [ ] `openapi/pacelli-api.yaml:16` — update server URL
- [ ] Deploy Cloud Functions to the new/updated project: `cd functions && npm run deploy`

### 5.4 Google Cloud Console
- [ ] If the project ID changed: update OAuth consent screen name
- [ ] Update OAuth client IDs in the Google Cloud Console if bundle IDs changed
- [ ] Update `android/app/src/main/res/values/strings.xml` with new web client ID if it changed
- [ ] Update authorized redirect URIs for each platform

---

## Phase 6: MCP Server

### 6.1 Package config
- [ ] `mcp-server/package.json:2` — `"name": "pacelli-mcp-server"` → `"{new_name}-mcp-server"`
- [ ] `mcp-server/package.json:4` — update description
- [ ] `mcp-server/package.json:8` — `"pacelli-mcp"` → `"{new_name}-mcp"` (bin command)

### 6.2 Source code
- [ ] `mcp-server/src/index.ts:43` — server name: `"pacelli"` → `"{new_name}"`
- [ ] `mcp-server/src/index.ts` — all `pacelli://` resource URIs → `{new_name}://`
- [ ] `mcp-server/src/index.ts` — resource display names: `"Pacelli Household Management API"` → `"{NEW_NAME} Household Management API"`
- [ ] `mcp-server/src/index.ts` — console.error startup messages
- [ ] `mcp-server/src/api-client.ts` — update comments

### 6.3 Dockerfile
- [ ] `mcp-server/Dockerfile:1` — update comment
- [ ] `mcp-server/Dockerfile:4-5` — update docker build/run commands: `pacelli-mcp` → `{new_name}-mcp`

### 6.4 Environment variables
- [ ] `PACELLI_API_URL` → `{NEW_NAME}_API_URL` (update in MCP server source + all deployment configs)
- [ ] `PACELLI_AUTH_TOKEN` → `{NEW_NAME}_AUTH_TOKEN` (update everywhere)
- [ ] Update the AI Assistant screen's config JSON block to show the new env var names

---

## Phase 7: OpenAPI Specification

- [ ] Rename file: `openapi/pacelli-api.yaml` → `openapi/{new_name}-api.yaml`
- [ ] `title` — update to "{NEW_NAME} Household Management API"
- [ ] `description` — update references
- [ ] `contact.name` — update to "{NEW_NAME}"
- [ ] `servers[0].url` — update if Firebase project URL changed

---

## Phase 8: Project Documentation

### 8.1 README
- [ ] `README.md:1` — update title

### 8.2 CLAUDE.md
- [ ] Update all references to "Pacelli" in the architecture documentation
- [ ] Update skill descriptions and references

### 8.3 Custom skills (`.claude/skills/`)
All 8+ skill directories and their SKILL.md files reference "Pacelli":
- [ ] Rename skill directories: `pacelli-*` → `{new_name}-*`
- [ ] Update each `SKILL.md` — name, description, and body text
- [ ] Update `evals/evals.json` files if they reference "Pacelli"
- [ ] Update the `pacelli-rename-app` skill itself (this file) to reflect the new name

---

## Phase 9: App Store Listings (when applicable)

### 9.1 Google Play Store
- [ ] Update app name in Google Play Console
- [ ] Update app description, screenshots, feature graphic
- [ ] **Note**: The `applicationId` change means this is treated as a **new app** by Google Play. You cannot simply rename an existing listing's package name. Options:
  - Publish as a new listing and sunset the old one
  - Keep the old `com.pacelli.pacelli` applicationId and only change the display name (recommended)

### 9.2 Apple App Store
- [ ] Update app name in App Store Connect
- [ ] Update bundle ID in Xcode → will require a **new App Store listing** if the bundle ID changes
- [ ] Same recommendation: keep `com.pacelli.pacelli` bundle ID, only change display name
- [ ] Update screenshots, description, keywords

### 9.3 Bundle ID decision
**STRONG RECOMMENDATION**: Unless you have a compelling reason, **keep the existing bundle/package ID** (`com.pacelli.pacelli`) and only change the **display name** shown to users. Changing the bundle ID forces a new app store listing, losing all reviews, ratings, and install history.

---

## Phase 10: Domain & DNS (if applicable)

- [ ] If you have a website (e.g. `pacelli.app`), update or redirect to the new domain
- [ ] Update any deep links or universal links configuration
- [ ] Update email addresses used in OAuth consent screen
- [ ] Update `assetlinks.json` (Android) and `apple-app-site-association` (iOS) if using deep links

---

## Phase 11: Post-Rename Verification

### 11.1 Build verification
```bash
flutter clean && flutter pub get && flutter gen-l10n && flutter analyze && flutter test
```
- [ ] `flutter analyze` reports 0 issues
- [ ] `flutter test` passes all tests
- [ ] App builds and runs on iOS Simulator
- [ ] App builds and runs on Android Emulator

### 11.2 Functional verification
- [ ] App displays the new name on home screen, settings, about dialog
- [ ] Notifications show the new name
- [ ] Google Drive creates folders with the new name
- [ ] Export files use the new filename prefix
- [ ] Import still works with old `pacelli_backup_*` files (backward compatibility)
- [ ] Theme colour scheme preference survives app restart
- [ ] Encryption/decryption still works with existing data (salts unchanged)
- [ ] AI Assistant screen shows correct config with new names
- [ ] MCP server connects and responds with new server name

### 11.3 Firebase verification
- [ ] Firebase Auth (Google + Email/Password) still works
- [ ] Firestore reads/writes work
- [ ] Cloud Functions deploy and respond
- [ ] Firebase Console shows the new display name

### 11.4 Existing user migration
- [ ] Local database file renamed on first launch (if filename changed)
- [ ] SharedPreferences colour scheme key migrated (if enum renamed)
- [ ] Google Drive "Pacelli" folder: documented that users should rename manually (or add auto-migration)

---

## Quick Reference: What NOT to Rename

| Item | Reason |
|------|--------|
| Encryption salt strings (`pacelli_hkdf_salt_v2`, etc.) | Would break ALL existing encrypted data |
| Firebase project ID (`pacelli-35621`) | Firebase project IDs are immutable |
| Bundle/package ID (`com.pacelli.pacelli`) | Changing it = new app store listing, lose reviews/installs |
| Old backup filenames | Import service validates structure, not filename |

## Estimated Effort

| Phase | Files | Effort |
|-------|-------|--------|
| Phase 1: Dart code | ~25 files | 2-3 hours |
| Phase 2: Localisation | 3 ARB files + regenerate | 1 hour |
| Phase 3: Android | 4 files + directory move | 30 min |
| Phase 4: iOS/macOS | 6 files | 30 min |
| Phase 5: Firebase | Console + CLI | 1-2 hours |
| Phase 6: MCP Server | 4 files | 30 min |
| Phase 7: OpenAPI | 1 file | 10 min |
| Phase 8: Documentation | 10+ files | 1 hour |
| Phase 9: App Stores | Console only | 1 hour |
| Phase 10: Domain/DNS | Varies | Varies |
| Phase 11: Verification | Testing | 1-2 hours |
| **Total** | **~60 files** | **~8-10 hours** |

## When to Run This Skill

| Trigger | Action |
|---------|--------|
| User says "rename the app" or "rebrand" | Run the full skill |
| User says "change the display name only" | Run Phases 1.3, 1.4, 1.9, 1.12, 2, 3.2, 4.2, 9 only |
| User says "change the bundle ID" | Run Phases 3.1, 3.3, 4.1, 4.4, 5, 9 (warn about app store impact) |
