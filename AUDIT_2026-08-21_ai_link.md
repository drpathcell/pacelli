# Pacelli security audit — 1.7.0 addendum: the AI-link surface

**Scope:** what 1.7.0 adds, not a full re-audit. Commit `3a2450f` + the
`aiLinkCreate` role guard deployed the same day. Build 45, about to be
submitted to App Review.

**Verdict: PASS with two LOW items open and one MEDIUM fixed during the audit.**

The full-surface audit of 2026-08-01 (`AUDIT_2026-08-01_native.md`) and its
addenda remain the baseline. Phase 1 (crypto correctness) is untouched by this
release and was re-run as a gate: **PacelliKit 66 tests / 11 suites green**,
including the cross-language vectors and the HKDF derivation.

---

## What is new, and why it needed looking at

1.7.0 adds the **first HTTP client in the native app**
(`Sources/Core/AILinkService.swift`) and a screen that handles a **bearer
secret** (`Sources/App/ConnectAIView.swift`). Every previous release talked
only to Firestore under the security rules. Both are new attack surface of a
kind this app has not had before.

---

## [PASS] Transport and credentials — `AILinkService.swift`

| Check | Result |
|---|---|
| HTTPS only, no cleartext URL anywhere in the file | PASS |
| ATS not weakened — `NSAppTransportSecurity` absent from `Info.plist` | PASS |
| No secret in source: base URL derived from `PROJECT_ID` in the bundled plist | PASS |
| Bearer token obtained per call via `user.getIDToken()`; not cached locally | PASS |
| No `print` / `NSLog` / `os_log` of tokens, codes or decrypted content | PASS |
| No `UserDefaults` / Keychain / file / Firestore persistence in either new file | PASS |
| Entitlements unchanged — still only SIWA, APS and the shared keychain group | PASS |

Fetching the ID token per call rather than caching it is deliberate: Firebase
already caches and refreshes internally, so a second cache here could only ever
serve an expired one.

## [PASS] The pairing code is treated as a secret

- Held in `@State` only. Never written to `UserDefaults`, the Keychain, a file,
  or read back from Firestore.
- Rendered only while live; `liveCode` returns nil past `expiresAt`, so an
  expired code disappears rather than sitting on screen inviting a paste.
- Server-side enforcement is the real one: single-use inside a transaction,
  ten-minute TTL, ~41 bits over an alphabet with no look-alikes.
- `ai_link_codes` is `allow read, write: if false` in `firestore.rules` — the
  wrapped household key on those documents is unreachable from any client.

**Proven, not asserted:** `scripts/check_ai_link_e2e.sh` redeems a real code
against production and then fails if the same code is accepted a second time.

## [PASS] Revocation actually revokes

`AILinkService.revoke` calls `aiLinkRevoke`, which revokes refresh tokens and
disables the account **before** deleting the `household_keys` row and the
membership row.

The failure mode this avoids is specific: `MembershipService.removeMember`
deletes the membership row and nothing else, leaving a live refresh token and a
usable wrapped key. The assistant would keep reading for up to an hour while
the UI reported it gone. Assistants are therefore excluded from the Members
swipe (`HouseholdView`), and Connect an AI is the only path.

**Proven:** the E2E disconnects from the app UI and then requires the CLI to be
refused on its very next call.

---

## [FIXED] MEDIUM — an assistant could connect another assistant

**Found during this audit. Fixed and deployed the same day.**

`aiLinkCreate` authenticated the caller and checked nothing else. An assistant
is a household member, and both the security rules and `authenticateRequest`
judge membership by the member document existing — not by its role. So an
assistant holding a session could mint a second pairing code and stand up a
second assistant.

That quietly undoes revocation: disconnecting the assistant you know about
leaves the one it created still attached, still holding its own refresh token
and its own copy of the wrapped household key.

**Fix:** `createLink` now loads the caller's member row and refuses when its
role is `assistant`. Backend-only — no app change, so build 45 is unaffected.
Deployed to `pacelli-35621` 2026-08-21.

**Regression control:** `check_ai_link_e2e.sh` now runs `pacelli.py
connect-another` from a live assistant session and fails if it succeeds — and
asserts on the *reason* in the error, not merely on a non-zero exit, so the
control cannot pass because the network was down or the subcommand was
misspelled.

---

## [OPEN] MEDIUM — an assistant has full member rights, including removing people

Not introduced by 1.7.0, but 1.7.0 is what makes it reachable in practice.

`firestore.rules` allows any member to update or delete any
`household_members` row in their household:

```
allow update, delete: if isAuth() && (
  resource.data.user_id == request.auth.uid ||
  isMember(resource.data.household_id)
);
```

The app gates removal on `isAdmin`, but the rules do not. An assistant is a
member, so an assistant — or anything that can talk it into acting — can remove
a human member. This is the classic prompt-injection consequence: the model does
not need a vulnerability, only an instruction.

**Not fixed today, deliberately.** Tightening member deletion to
admins-or-self is a rules change that also gates the burn-all-data flow, which
deletes the user's own member row last and depends on `isMember` staying true
through the earlier batches. That is not a change to make on the way out the
door. **Recommended for 1.8.0, with `flow_settings_burn_e2e.yaml` re-run as
the gate**, plus a role check in the destructive `functions/` handlers.

Note the exposure is bounded by design in one useful way: an assistant is
household-scoped, it cannot reach another household, and it can no longer
create a successor.

## [OPEN] LOW — the assistant's label is stored in plaintext

`ai_link_codes.label` and `household_members.display_name` hold the
user-authored label ("Claude on my laptop") as plaintext, while a human's name
is encrypted in `profiles.full_name`.

No claim on the Privacy & Encryption screen is falsified by this — that screen
says "your display name", which this is not — so it is a coverage
inconsistency rather than a broken promise. The UI placeholder steers toward a
device name rather than a person's name. Encrypt it in 1.8.0, or document it.

## [OPEN] LOW — the pairing code goes to the general pasteboard unbounded

`UIPasteboard.general.string = code.code` leaves a dead code in the clipboard,
and on Universal Clipboard across the user's other devices, long after it stops
working.

The live-secret window is unchanged either way (ten minutes, and iOS 16+ makes
another app show a paste banner before reading), which is why this is LOW.
Fix in 1.8.0 with `setItems(_:options:)` and an `expirationDate` of
`code.expiresAt`, keeping sync on — copying on the phone and pasting on the Mac
is the actual workflow.

---

## Verification run for this addendum

| Gate | Result |
|---|---|
| PacelliKit `swift test` (crypto vectors, HKDF, wire parity) | 66/66 green |
| `xcodebuild -configuration **Release**` iOS-sim | BUILD SUCCEEDED, 0 errors |
| `check_ai_link_e2e.sh` against the **Release** build | PASS |
| — pair, decrypt a task the app wrote, walk the read surface | PASS |
| — negative: reused code refused | PASS |
| — negative: assistant cannot connect another assistant | PASS |
| — negative: locked out immediately after disconnect | PASS |
| `verify_api_wire.py` | PASS |
| Native CI (entitlements, wire-contract, functions-tests, kit-tests, app-build) | 5/5 green |

The Release-configuration run matters: every earlier E2E in this repo has run a
Debug build. This one exercised the shipping configuration — strict
concurrency, release optimisation, production APS entitlement — which is the
closest available substitute for the on-device verification skipped for this
release.

## Carried to 1.8.0

1. Restrict `household_members` update/delete to admins-or-self, gated on the burn E2E.
2. Role checks on destructive `functions/` handlers.
3. Encrypt the assistant label.
4. `expirationDate` on the pasteboard item.
