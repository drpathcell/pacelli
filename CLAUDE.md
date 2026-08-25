# CLAUDE.md

Guidance for Claude working in this repository.

## What ships

**`PacelliApp/` — a native SwiftUI iOS app.** That is the product. iPhone-only,
Firebase backend, end-to-end field encryption.

**`lib/` is the Flutter app and it is FROZEN.** It is kept only as the
wire-contract reference: every native repository is a field-parity port of
`lib/core/data/firebase_data_repository.dart`. Read it to answer "what shape
does this document have on the server". **Do not edit it, do not run
`flutter` anything, and never take its architecture as current** — Riverpod,
GoRouter, the SQLite second backend and the ARB localisation described in the
pre-2026-07 version of this file are all gone from the shipping app. Same for
`android/`, `macos/`, `linux/`, `windows/`, `web/`.

## Layout

```
PacelliApp/
  project.yml            XcodeGen spec — SOURCE OF TRUTH; .xcodeproj is generated & gitignored
  Sources/App/           SwiftUI screens (RootView, HomeView, TasksView, SettingsView, …)
  Sources/Core/          Services & repositories (Firestore, keys, push, export, burn)
  Sources/Auth/          SIWA / Google / email, guest upgrade via link(with:)
  Packages/PacelliKit/   Crypto + wire-parity models. No Firebase, no UIKit.
  NotificationService/   NSE that decrypts push titles on device
  e2e/                   Maestro flows (see e2e/README.md — read its Lessons section)
functions/               Cloud Functions: the REST API an AI assistant drives
firestore.rules          household_id + isMember() on EVERY collection
firestore.indexes.json   see the trap below — this file has lied twice
scripts/                 asc.py, submit_when_clear.py, pacelli.py, check_*_e2e.sh
docs/release-notes/      X.Y.Z.md (What's New) + X.Y.Z-review-notes.md (for Apple)
```

## Commands

```bash
cd PacelliApp && xcodegen generate            # after ANY project.yml edit
cd PacelliApp/Packages/PacelliKit && swift test
cd PacelliApp && xcodebuild -project PacelliApp.xcodeproj -scheme PacelliApp \
  -configuration Debug -destination 'generic/platform=iOS Simulator' build

python3 scripts/asc.py status                 # what App Store Connect actually thinks
python3 scripts/asc.py screenshots-verify X.Y.Z  # listing == repo, byte for byte
python3 scripts/verify_api_wire.py            # REST API writes what the app can read
./scripts/check_ai_link_e2e.sh                # pair → read → revoke → locked out
./scripts/check_burn_e2e.sh                   # restricted burn refused BY THE SERVER
./scripts/deploy_rules.sh                     # tests + guard + deploy. NEVER a bare
                                              # `firebase deploy --only firestore:rules`
./scripts/make_screenshots.sh                 # then: asc.py screenshots-sync <version>
```

**`firestore.rules` carries a `// requires-live-version:` header and a script
reads it.** `deploy_rules.sh` runs the rules suite, then
`check_rules_deploy.py`, which asks App Store Connect for the highest version
READY_FOR_SALE and refuses the deploy if the file needs a newer one. Deploying
by hand skips both. This exists because the comment it replaced was not a
guard: 2026-08-10 shipped a rule the live build could not satisfy and locked
people out of accepting invitations for a day, and 2026-08-24 nearly repeated it
with account deletion.

CI: `native-ci.yml` runs five jobs on every push — `entitlements`,
`wire-contract`, `functions-tests`, `kit-tests`, `app-build`. `release.yml`
fires on a `vX.Y.Z+NN` tag.

## Architecture, briefly

- SwiftUI + `@Observable`, Swift 6 **strict concurrency complete**, iOS 26 target.
- Firebase iOS SDK 12.15 via SPM (Auth/Firestore/Messaging) + GoogleSignIn 9.2.
- **Encryption**: AES-256-CBC, per-household key, HKDF with an explicit HMAC.
  `PacelliKit/Crypto`. Cross-language vectors pin Swift against the Dart and TS
  ports — if you change crypto, that gate is the thing that must stay green.
- Titles, notes, names, **item quantities** are encrypted. IDs, timestamps,
  status, sort order are not (the server has to query them).
- **`SettingsView.PrivacyEncryptionView` is a promise to the user.** Change what
  gets encrypted and you change that screen in the same commit. It ships in the
  store.

## Traps that have each cost a session

- **Every Firebase await is deadline-bound** — `withTimeout(_:)` in
  `Core/Timeout.swift`. Build 26 shipped without it and hung forever on a stale
  keychain session. There is no caller-side timeout in the SDK.
- **Never run `swift test` and the `functions/` jest suite at the same time.**
  jest rewrites `functions/tests/cross-language/ts_encrypted_vectors.json`,
  which the Swift suite reads; you get a phantom PacelliKit failure.
- **An E2E that creates server-side data must `simctl erase`, not uninstall.**
  The keychain survives an uninstall, so the guest account and everything it
  owns on the server come back with it.
- **Cloud Function queries need composite indexes nothing else proves.** The app
  reads Firestore directly and sorts client-side, so a two-filter + `orderBy`
  query exists only in `functions/` — and `tasksList` returned HTTP 500 from the
  day the API shipped because its index was never in `firestore.indexes.json`.
  Add a query there, add the index, and prove it with a real call. ASC vs DESC
  is not cosmetic: an index can only be scanned backwards if *every* field
  reverses.
- **Revoking an AI assistant goes through `aiLinkRevoke`, never
  `removeMember`.** Deleting the membership row leaves a live refresh token and
  a usable wrapped household key. Assistants are excluded from the Members swipe
  for exactly this reason — do not "fix" that.
- **Firestore child-collection queries must filter on `household_id`** or the
  rules deny them. `household_id` is denormalised onto every document.
- **`CURRENT_PROJECT_VERSION` in `project.yml` is a floor, not the build
  number.** The real one is `max(floor, latest_testflight + 1)`, computed in the
  Fastfile `native_build` lane. Do not "update" it.
- **Assume a green harness is lying until you have made it fail.**

## Shipping

```
tag vX.Y.Z+NN  →  Release (native) CI  →  TestFlight
                →  python3 scripts/submit_when_clear.py X.Y.Z --build NN \
                     --whats-new-file docs/release-notes/X.Y.Z.md \
                     --review-notes-file docs/release-notes/X.Y.Z-review-notes.md
```

`submit_when_clear.py` is idempotent and waits for the review queue. Releases
are `AFTER_APPROVAL` — approval puts it live, so a submission is the last
reversible moment. Cancelling a `WAITING_FOR_REVIEW` version drops it to
`DEVELOPER_REJECTED`, unlocks the metadata, and keeps the build and notes.

**Screenshots must show the release.** 1.6.0 was submitted once with 1.5.0's
screenshots and had to be cancelled and redone; 1.8.0 came one command from
doing the same with a set that had been stale since 1.5.0. `submit_when_clear`
now refuses to call `submit` unless every screenshot on the listing byte-matches
`fastlane/metadata/ios/en-GB/screenshots` — checked AFTER the version exists,
because `version_create` is where the staleness comes from (Apple copies the
previous version's screenshots onto a new one). Bailing there is cheap: version,
build and notes survive, so `screenshots-sync` then a re-run continues from that
point. `./scripts/asc.py screenshots-verify X.Y.Z` runs the same check alone.

## Repo skills (`.claude/skills/`)

`/pacelli-security-audit` (native surface), `/pacelli-backend-audit`,
`/pacelli-deploy`, `/pacelli-add-screen`, `/pacelli-theme-colours`,
`/pacelli-ai-integration`, `/pacelli-rename-app`.

`/pacelli-add-arb-keys`, `/pacelli-add-language` and
`/flutter-firebase-security-audit` target the frozen Flutter tree. The native
app localises through `Resources/Localizable.xcstrings` and
`String(localized:)`; ignore the ARB skills unless you are deliberately reading
Flutter history.
