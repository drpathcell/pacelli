# Pacelli Native Rewrite — SwiftUI Migration Plan

**Decided:** 2026-07-07 (see Claude-KB decision record `2026-07-07-pacelli-native-swiftui-rewrite`)
**Scope:** Full SwiftUI rewrite. Flutter 1.0 review abandoned — the native app ships as the App Store build. iOS-only; Android dropped. Flutter tree frozen (reference only) until deletion.

## Invariants (do not break)

- **Same ASC app record, same bundle ID** `com.pacelli.pacelli` — keeps match certs, provisioning, demo account, app name/SKU. Native ships as the next build on the existing record.
- **Same Firebase backend** — Firestore data, security rules, and existing user ciphertexts are untouched. The app layer changes; the data layer contract does not.
- **Guest mode is first-class from day one** (Guideline 5.1.1(v) lesson, build 25 rejection). Anonymous auth → auto-provisioned household → usable Home with zero walls. Port `enterGuestMode()` semantics (commit b0f7f56), incl. anon→real `linkWithCredential` upgrade preserving household + keys.
- **household_members migration semantics** — rules call `isMember()` against `/household_members/{uid}_{householdId}`; await migration before any household-scoped write (build 10→11 race lesson).

## Source inventory (Flutter, 44.5k Dart LOC)

Features: auth, capabilities, checklists, feedback, household, import_export, inventory, manual, onboarding, plans, search, settings, tasks. Core: crypto, data, diagnostics, errors, models, services, utils, widgets. l10n: en/es/it.

## Stack mapping

| Flutter | Native |
|---|---|
| flutter_riverpod | SwiftUI + `@Observable` (Swift 6 strict concurrency) |
| go_router | `NavigationStack` / `TabView` |
| firebase_core/auth/cloud_firestore | Firebase iOS SDK via SPM |
| encrypt + pointycastle (AES-256-CBC/PKCS7) + crypto (HKDF) | **CommonCrypto or CryptoSwift** — CryptoKit has no CBC. Byte-exact port validated against the repo's cross-language test vectors. Mind the PointyCastle empty-plaintext short-circuit (`encryptNullable`). |
| flutter_secure_storage | Keychain (Face ID gated — usage string already written) |
| sqflite | SwiftData (or GRDB if relational pain) |
| sign_in_with_apple / google_sign_in | AuthenticationServices / GoogleSignIn SDK |
| googleapis (Drive) | GoogleSignIn scopes + Drive REST |
| l10n .arb (en/es/it) | String Catalogs — use bridge `StringCatalog*` + `LocalizationPlanner` tools |
| confetti / theming (pacelli/claude/gemini) | SwiftUI particles + native theming; adopt Liquid Glass |

## Phases

1. **Foundation** — `PacelliApp/` Xcode project in this repo; SPM deps; scheme; CI lane (reuse match + ASC keys; replace Flutter steps with `xcodebuild`/gym). Repo stays monorepo — history, secrets, and CI survive.
2. **Crypto port + vectors** — first, because everything else is blocked on decrypting real user data. Gate: all cross-language vectors pass both directions.
3. **Data layer** — Codable Firestore models, repositories, rules-compatible writes, membership probe/self-heal.
4. **Auth + onboarding** — guest-first flow, SIWA (`accessToken: authorizationCode` fix carries over conceptually), Google, email; account upgrade path.
5. **Features by daily-use priority** — tasks → checklists → plans/calendar → inventory (photos) → household → settings (themes, burn-all-data, privacy screen) → manual → feedback → search → import/export → capabilities.
6. **iOS-native surface** — widgets, App Intents, Live Activities; Foundation Models for on-device suggestions. This is the payoff of going native; v1.x backlog.
7. **Ship** — TestFlight, then submit on the existing app record (supersedes the rejected Flutter submission — no resubmission of build 26; tag discipline continues `v2026.x` or `v1.0.0+27+`, decide at first tag).

## Tooling (why now is the right time)

- Xcode 27 bridge is live: `.mcp.json` (project-scoped `xcrun mcpbridge`) + `scripts/mcpbridge_call.py` (47 tools: BuildProject, RunAllTests, RenderPreview, RunCodeSnippet, StringCatalog*, DeviceInteraction*, GetTopCrashIssues…).
- `xcrun mcpbridge run-agent claude` — Xcode-bundled Claude Code, pre-wired tools.
- Apple skills exported to `~/Developer/xcode-skills` — use `swiftui-specialist`, `swiftui-whats-new-27`, `modernize-tests`, `audit-xcode-security-settings` during the port.
- Security: rerun `pacelli-security-audit` skill against the Swift crypto/Keychain/rules surface at end of phases 2–4.

## Explicitly dropped

Android (Flutter frozen), build 26 ship, Resolution Center reply for submission 5cd2182f (superseded — the rejected version dies with the Flutter app).
