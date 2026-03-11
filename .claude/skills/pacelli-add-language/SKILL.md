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
Read `lib/l10n/app_en.arb` to get all the keys and their English values. This is the source of truth. The file contains ~665 translation keys including parameterised strings with `@key` metadata entries.

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
- **Burn All Data**: confirmation dialog, password prompt, fire animation status messages, Drive/local warning
- **Notification Settings**: toggle labels, reminder descriptions, permission prompts
- **Import/Export**: export data button, import data, format labels, success/failure messages (now includes inventory)
- **Inventory List Screen**: empty state, item cards with status badges (expired/expiring/low stock), view mode toggle (by category/location/all)
- **Inventory Item Detail**: quantity adjuster, barcode/QR code viewer, activity log, attachments, auto-task creation button
- **Create/Edit Inventory Item**: barcode options (scan real/generate virtual/none), all form fields (name, category, location, quantity, unit, expiry, purchase date, notes, low stock threshold)
- **Batch Create Screen**: portions input, preview list, per-portion naming pattern
- **Barcode Scanner Screen**: camera overlay, scan instructions, flash/camera-switch controls
- **Virtual Barcode View**: QR code display with item name and barcode string
- **Manage Inventory Categories / Locations**: list with add/delete, icon/colour picker
- **Calendar → Expiring Items**: collapsible section showing inventory items expiring on selected day
- **Home Screen → Inventory Snapshot**: stat cards for total/low stock/expired/expiring soon
- **Bottom Nav Bar**: Home/Tasks/Calendar/Settings labels
- **Dialogs & Alerts**: delete confirmations, error messages, coming-soon messages

### 7. Common pitfalls
- **Missing keys**: If any key from `app_en.arb` is missing in the new file, `flutter gen-l10n` will fail at build time with a clear error message listing the missing key
- **Broken JSON**: A trailing comma or unescaped quote will cause a parse error — validate the JSON
- **Translated placeholders**: If you translate `{count}` to `{cantidad}`, the app will crash — placeholders must match exactly
- **Metadata entries**: Including `@key` entries in non-template ARB files causes warnings (harmless but messy)

## Key Count Reference
As of March 2026, `app_en.arb` contains approximately 665 translation keys (800 lines including `@key` metadata) covering:
- Tasks & task detail (~77 keys)
- Plans & checklists (~77 keys)
- Inventory (~107 keys: general CRUD, barcode/QR, batch create, notifications, auto-tasks, calendar integration)
- Settings (~38 keys)
- Household management (~34 keys)
- Auth screens (~33 keys)
- Privacy & encryption (~31 keys)
- Burn/wipe (~29 keys including password prompt, status messages, Drive warning)
- Drive/storage (~25 keys)
- Home screen (~24 keys including inventory snapshot)
- Common/shared strings (~18 keys)
- Attachments (~16 keys)
- Notifications & reminders (~15 keys)
- Calendar (~14 keys)
- Appearance/themes (~14 keys)
- Import/Export (~12 keys)
- Priority labels (~5 keys)
- Recurrence labels (~5 keys)
- Navigation (~4 keys)
- Error/loading states (~remaining)
