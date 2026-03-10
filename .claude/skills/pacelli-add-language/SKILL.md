# Pacelli — Add a New Language

## Overview
This skill adds a new language/locale to the Pacelli Flutter app. The i18n infrastructure is already in place using Flutter's `flutter_localizations` SDK with ARB files. Adding a new language only requires creating a translated ARB file — no code changes needed.

## Project Location
The Pacelli project is located at the user's local path (typically `~/Developer/pacelli`). In Cowork sessions it is mounted at `/sessions/*/mnt/pacelli/`.

## Architecture
- **l10n config**: `pacelli/l10n.yaml`
- **ARB directory**: `lib/l10n/`
- **Template (English)**: `lib/l10n/app_en.arb`
- **Existing translations**: `lib/l10n/app_es.arb` (Spanish), `lib/l10n/app_it.arb` (Italian)
- **Generated code**: `lib/l10n/app_localizations.dart` and per-locale files
- **Extension**: `lib/core/utils/extensions.dart` — provides `context.l10n` shorthand
- **Root widget**: `lib/app.dart` — configures `localizationsDelegates` and `supportedLocales`

## Steps to Add a New Language

### 1. Identify the locale code
Use the standard ISO 639-1 code for the language (e.g., `it` for Italian, `fr` for French, `de` for German, `pt` for Portuguese, `ar` for Arabic, etc.).

### 2. Read the English template
Read `lib/l10n/app_en.arb` to get all the keys and their English values. This is the source of truth. The file contains ~464 keys including parameterised strings with `@key` metadata entries.

### 3. Create the new ARB file
Create `lib/l10n/app_{locale_code}.arb` (e.g., `app_it.arb` for Italian).

**Rules:**
- First line must be `{ "@@locale": "{locale_code}",`
- Copy EVERY key from `app_en.arb` (excluding `@@locale` and `@`-prefixed metadata keys)
- Translate every value to the target language
- **DO NOT** copy `@key` metadata entries (e.g., `@commonError`, `@calendarTasksSectionTitle`) — these are only needed in the template file (`app_en.arb`)
- **DO** preserve placeholders exactly as they appear: `{name}`, `{count}`, `{error}`, `{feature}`, `{dayLabel}`, etc. — these must NOT be translated
- **DO** preserve any ICU syntax (plurals, selects) if present
- Ensure valid JSON (no trailing commas, proper escaping of quotes)
- Use natural, native-speaker-quality translations — not robotic literal translations

### 4. Verify — no code changes needed
Flutter's `gen-l10n` automatically discovers new ARB files in `lib/l10n/`. The `supportedLocales` list in `AppLocalizations` is auto-generated. No changes to `app.dart`, `l10n.yaml`, `pubspec.yaml`, or any Dart files are required.

### 5. Build and test
Run:
```bash
cd ~/Developer/pacelli && flutter clean && flutter pub get && flutter run
```
Then change the iOS Simulator's system language to the new locale (Settings → General → Language & Region) and hot restart the app (Shift+R in the terminal).

### 6. Verify all screens
Check these screens for correct translations:
- **Home**: greeting, date, household card, "Today's Overview" section (Completed/Pending/Overdue), "Recent Tasks"
- **Tasks**: title, tab labels (All/Pending/Done), category chips, empty states
- **Calendar**: title, day labels (Today/Tomorrow), section headers (Tasks/Plans/Checklists), "New Plan" button
- **Settings**: title, all menu items (Household, Notifications, Privacy, Data Storage, Appearance, About), coming-soon dialogs, logout
- **Appearance**: title, theme mode labels (Light/Dark/Auto), scheme names and descriptions
- **Task Detail**: title, priority badge (Urgent/High/Medium/Low/None), field labels (Starts, Due, Assigned to, Repeats, Created by), subtasks section, action buttons
- **Task Create/Edit**: all form labels and placeholders
- **Attachments**: pick source bottom sheet, uploading overlay, success/failure messages
- **Bottom Nav Bar**: Home/Tasks/Calendar/Settings labels
- **Dialogs & Alerts**: delete confirmations, error messages, coming-soon messages

### 7. Common pitfalls
- **Missing keys**: If any key from `app_en.arb` is missing in the new file, `flutter gen-l10n` will fail at build time with a clear error message listing the missing key
- **Broken JSON**: A trailing comma or unescaped quote will cause a parse error — validate the JSON
- **Translated placeholders**: If you translate `{count}` to `{cantidad}`, the app will crash — placeholders must match exactly
- **Metadata entries**: Including `@key` entries in non-template ARB files causes warnings (harmless but messy)

## Key Count Reference
As of March 2026, `app_en.arb` contains approximately 464 translation keys covering:
- Tasks & task detail (~77 keys)
- Plans & checklists (~77 keys)
- Settings (~38 keys)
- Household management (~34 keys)
- Auth screens (~33 keys)
- Privacy & encryption (~31 keys)
- Drive/storage (~25 keys)
- Home screen (~22 keys)
- Common/shared strings (~18 keys)
- Attachments (~16 keys)
- Calendar (~14 keys)
- Appearance/themes (~14 keys)
- Navigation (~4 keys)
- Priority labels (~5 keys)
- Recurrence labels (~5 keys)
- Burn/wipe (~8 keys)
- Error/loading states (~remaining)
