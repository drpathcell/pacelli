---
name: "pacelli-security-audit"
description: "Security audit of the native SwiftUI Pacelli iOS app and its Firebase backend: PacelliKit crypto, Keychain, firestore.rules, Cloud Functions, burn permissions, guest sweep, AI-assistant linking, photos and catalogue images. Run after any change to crypto, rules, functions, auth, burn or the sweep, or when Juan says security audit, encryption check, crypto vectors, rules review or keychain review for Pacelli."
---

# Pacelli - Security Audit (native SwiftUI + Firebase)

Pacelli is a native SwiftUI iOS app, shipping on the App Store since 2026-08-04
(1.11.x as of September 2026), with a Firebase backend: Firestore, 81 Cloud
Functions (Node 22), Cloud Storage for photos, and a REST API used by paired AI
assistants. Everything is at `~/Developer/pacelli/`. The Flutter tree (`lib/`,
`android/`) is frozen and is never audited; never cite a `lib/**.dart` path.
iOS only. Firebase project `pacelli-35621`, bundle id `com.pacelli.pacelli`.

## Method, always

1. **Find the last audit**: `ls -t AUDIT_*.md | head -1`, then
   `git log -1 --format=%h -- <that file>` gives the baseline commit.
2. **Scope is the diff**: `git diff --stat <baseline>..HEAD -- PacelliApp
   firestore.rules functions/src firestore.indexes.json`. Read every changed
   file in those paths. Re-reading unchanged code is waste.
3. **Run the gates before reading**: PacelliKit `swift test` (run it 5 times,
   the CBC wrong-key flake is ~1/130), `functions/` `npx jest`, and
   `firestore-tests/` `npm test`. After jest run `git checkout --
   functions/tests/cross-language/ts_encrypted_vectors.json` (it rewrites IVs).
4. **Every FAIL gets a test that ran RED first**, then the fix, then GREEN. Say
   in the report which tests were run red. A negative control never seen to
   fail is not a control.
5. **Write `AUDIT_YYYY-MM-DD_<topic>.md`** at the repo root (tracked in git):
   `[PASS]` / `[FAIL -> FIXED]` / `[ACCEPTED]` / `[INFO]`, each with file:line,
   severity, exploit scenario, fix and test.
6. Delegating the reading to a subagent is fine. Verify each HIGH yourself
   in the source before reporting it.

## Mac tooling traps
- `/usr/local/bin/firebase` is an x86_64 binary that does not run on this Mac
  ("Bad CPU type"). Use `npx firebase-tools@latest`, or the `firestore-tests`
  devDependency. `scripts/deploy_rules.sh` already falls back.
- The MacOS-MCP shell has a ~60 s ceiling: `swift test`, the emulator suite,
  xcodebuild and every deploy go through `nohup ... > /tmp/x.log &` + polling.
- Confirm a rules deploy from the server, not from the CLI's own output: read
  `tokens.access_token` from `~/.config/configstore/firebase-tools.json`, GET
  `https://firebaserules.googleapis.com/v1/projects/pacelli-35621/releases/cloud.firestore`,
  then GET the `rulesetName`, and grep its source for the changed line.
- Deploy rules ONLY with `./scripts/deploy_rules.sh` (suite, live-version
  guard, deploy). Read the `requires-live-version:` header first, and
  `python3 scripts/asc.py status` for what is READY_FOR_SALE.

## Key files
| Concern | File |
|---|---|
| AES-256-CBC + HKDF + key wrapping (Swift) | `PacelliApp/Packages/PacelliKit/Sources/PacelliKit/Crypto/PacelliCrypto.swift` |
| Same, TypeScript | `functions/src/crypto/encryption-service.ts`, `functions/src/middleware/encryption.ts`, `functions/src/crypto/key-manager.ts` |
| Cross-language vectors (the gate) | `PacelliApp/Packages/PacelliKit/Tests/PacelliKitTests/CryptoVectorTests.swift`, `functions/tests/cross-language/` |
| Lazy field migration | `PacelliKit/.../FieldMigration.swift`, `QuantityMigration.swift` |
| Keychain, key lifecycle | `PacelliApp/Sources/Core/SecureStore.swift`, `KeyManager.swift` |
| Auth, guest upgrade, session reset | `PacelliApp/Sources/Auth/AuthService.swift`, `AccountSheet.swift`, `Sources/App/AppState.swift` |
| Burn (two halves) | `PacelliApp/Sources/Core/BurnService.swift`, `BurnPolicyService.swift`, `Sources/App/BurnPermissionView.swift`, `functions/src/functions/burn.ts` |
| Guest sweep | `functions/src/functions/maintenance.ts` |
| AI assistant linking | `functions/src/functions/ai-link.ts`, `PacelliApp/Sources/Core/AILinkService.swift` |
| Photos | `PacelliApp/Sources/Core/PhotoService.swift`, `PhotosRepository.swift`, `functions/src/functions/photos.ts` |
| Catalogue images (Dunnes) | `functions/src/functions/catalog-images.ts`, `PacelliKit/.../Models/ChecklistItemSource.swift`, `Sources/App/ChecklistItemDetailView.swift` |
| API auth wrapper | `functions/src/middleware/auth.ts` (`apiHandler`) |
| Rules + tests + guard | `firestore.rules`, `firestore-tests/*.test.js`, `scripts/check_rules_deploy.py`, `scripts/deploy_rules.sh` |
| Entitlements, ATS, OAuth scheme | `PacelliApp/Resources/PacelliApp.entitlements`, `Info.plist`, `GoogleService-Info.plist` |

## Invariants to verify verbatim

### Crypto (load-bearing constants: a change bricks every existing user)
- AES-256-CBC + PKCS7 via CommonCrypto (CryptoKit has no CBC). Wire
  `base64(iv16 || ct)`, fresh IV via `SecRandomCopyBytes`, `count >= 17` guard.
  Keys are 64-char lowercase hex from `SecRandomCopyBytes`.
- **No MAC.** Fields, photo objects, thumbnails and key wrapping all share this
  unauthenticated format. A wrong key decrypts to garbage ~1/130 instead of
  failing. The authenticated envelope is the planned fix (Swift + TS + vectors
  in lockstep, read old and new, write new). Until it ships, any code that
  decides "is this ciphertext mine" by decrypt-success is suspect.
- v2: `PRK = HMAC-SHA256("pacelli_hkdf_salt_v2", uid)`,
  `OKM = HMAC-SHA256(PRK, "pacelli_e2e_user_key_v2" || 0x01)`; the `0x01`
  byte is load-bearing. v1 legacy `HMAC("pacelli_e2e_key_derivation_v1", uid)`
  migration only; `decryptKeyWithMigration()` tries v2 then v1.
- `encryptNullable` short-circuits nil/empty without calling `encrypt`.
  `decryptNullable` returns `"[encrypted]"` on failure, never ciphertext.
- A valid-but-unopenable envelope is NEVER rewritten (encrypting a ciphertext
  is unrecoverable).
- Encrypted: every content-bearing field (titles, descriptions, names,
  quantity, `source`, captions, thumbnails). Not encrypted: ids,
  `household_id`, `created_by`, status, priority, timestamps, booleans, sort
  order. Every new field gets an explicit decision at review.

### Firestore rules
- `isMember(hid)` via `household_members/{uid}_{hid}` exists; every content
  collection uses `isMember(resource.data.household_id)`, never bare `isAuth`.
  Default deny at `/{document=**}`. Composite index for every new
  `household_id` + field query (the app sorts client-side, so gaps only show
  through the API).
- Ownership anchor is `households.created_by`: pinned on create, frozen on
  update. `household_members.role` is client-written and never trusted;
  create pins it, update freezes it, delete is self-or-owner.
- **households delete: owner, or a member once the owner's member row is
  gone** (2026-09-23). Open delete + open create was ownership in two writes.
- `burnPolicyUnchanged()` compares `burn_permission` AND the whole
  `burn_allowed_uids` list. Only the owner may change either.
- Rules cannot gate a burn (it is ordinary deletes). Accepted 2026-08-25. Any
  UI copy that calls the setting a lock is a finding.
- `household_keys` rows are self-only. The Storage bucket denies all clients;
  photo access is via signed URLs from a function.
- Await the membership doc before any household-scoped write (build 10 to 11).
- Deploy ordering: a rule the LIVE app cannot satisfy breaks 5.1.1(v) account
  deletion (2026-08-10, 2026-08-24). The guard script enforces the header.

### Cloud Functions
- Every export in `functions/src/index.ts` is `apiHandler`, scheduled, or the
  deliberately open `aiLinkRedeem`.
- `burnHousehold` reads the policy from the stored household doc, checks
  before deleting anything, batches of 400, verifies after.
- `sweepAbandonedGuests`: scheduled only, `lastRefreshTime` first, skips
  email/phone/provider/`ai_`/disabled, cap 100 per run, and
  `protectsHousehold()` keeps any household with a person OR a guest inside
  the idle window.
- `resolveHouseholdId` is deterministic and warns when a caller is in more
  than one household.
- Assistant revocation goes through `aiLinkRevoke` (token and key before the
  row), never a bare member-row delete.
- Catalogue images: only `https://images.cdn.dunnesstoresgrocery.com`, path
  regex, `redirect: "error"`, 2 MB cap, JPEG header check, no SKU in logs,
  cache keyed on sku AND index. Nutrition numbers bounded server-side.

### App
- Keychain `com.pacelli.pacelli`, account `hk_<hid>`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Face ID gating is the
  app lock, not kSecAccessControl (the notification extension reads headless).
  `SecureStore.deleteAll()` and `KeyManager.clearKeys()` on sign-out.
- SIWA uses a fresh random nonce, SHA-256 hashed into the request. Google
  `clientID` from `FirebaseApp.app()?.options.clientID`, never hardcoded. No
  client secrets in `Sources/` (the OAuth URL scheme is public).
- Guest upgrade via `linkWithCredential` keeps uid, household and key.
  `resetSession()` must not strand a half-provisioned anonymous session.
- `BurnService.leaveHousehold`: only non-assistant rows count as people; the
  last person out revokes assistants, then wipes the household. Delete my
  account is never gated (5.1.1(v)); burn household data is.
- Anything member-writable that the app converts with `Int(_:)` must be
  clamped (`ChecklistItemDetailView.clampedInt`).
- No `print`/logger of keys, tokens or decrypted content.
- Privacy screen claims must be literally true of the implementation.
- Entitlements minimal, ATS not weakened, `GoogleService-Info.plist` holds
  only project identifiers.

## Known accepted items (do not re-report)
- Readable photos in a Files-visible folder are not covered by the app lock
  (stated on the Privacy screen).
- Direct-delete bypass of the burn setting (rules cannot see a burn).
- Plaintext catalogue cache and `content_hash` reveal WHICH products some
  household added, not which household.
- After the owner deletes their account, a remaining member can refound and
  become owner; succession is an open product decision.

## Severity
| CRITICAL | Data reachable by unauthorised users, or crypto that breaks existing ciphertext |
| HIGH | Privilege escalation, sensitive data leak, logged secrets |
| MEDIUM | Defence-in-depth gap, data loss for a subset of users, crash from member input |
| LOW | Best practice not followed |

Fix order: crypto vectors > rules > functions auth > key handling > guest
upgrade > app. Then ship: rules via the script, functions via
`npx firebase-tools@latest deploy --only functions --force`, bump BOTH
`MARKETING_VERSION` lines in `PacelliApp/project.yml`, write
`docs/release-notes/X.Y.Z.md` and `X.Y.Z-review-notes.md`, signed tag
`vX.Y.Z+NN` (`-a -m`), wait for Release (native) CI, then
`scripts/submit_when_clear.py X.Y.Z --build NN --whats-new-file ...
--review-notes-file ...`.