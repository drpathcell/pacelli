# Security audit addendum — notification extension & keychain access group (Phase C)

Required by `docs/notifications-plan.md` **before** this ships, not after:
widening the keychain to a second process is a real change to who can read the
household key. Companion to `AUDIT_2026-08-11_push_addendum.md`.

**Status: built and proven on the simulator, NOT shippable yet.** An app
extension is a separate bundle id and needs its own App ID and match
provisioning profile. That work touches the release pipeline and was
deliberately not done while 1.3.0 sits in review.

## What actually changed about key custody

Before: `hk_<householdId>` lived in the app's private keychain, readable by one
process.

After: it lives in access group `5PCNU95W9V.com.pacelli.shared`, readable by
the app **and** `com.pacelli.pacelli.NotificationService`.

**[PASS] The group is team-scoped and OS-enforced.** An app can only claim
groups its `keychain-access-groups` entitlement lists, and that entitlement can
only list groups under its own team prefix. No third-party app can join
`5PCNU95W9V.*`.

**[PASS] The extension's entitlement file contains exactly one key** —
`keychain-access-groups`. No push, no Sign in with Apple, no network identity.
Its reach is deliberately visible at a glance in
`NotificationService/NotificationService.entitlements`.

**[PASS] The app's profile already permitted this.** `match AppStore
com.pacelli.pacelli` carries `keychain-access-groups: ['5PCNU95W9V.*',
'com.apple.token']` — verified by decoding the profile *before* the entitlement
was added, so the release pipeline was never at risk.

**[PASS] The extension has no Firestore client and no network.** It reads the
keychain and nothing else. A network fetch inside the ~30s budget would
sometimes work and sometimes not, which is worse than consistently showing the
generic body.

**[NOTED] The trade is real and should be stated plainly.** A second process
can now read the household key. It is a process we ship, it holds one
entitlement, and it runs only when a notification arrives — but the attack
surface for the key is larger than it was, and that is the cost of showing
"Buy milk" instead of "a task was added".

## Deletion — the one that would have leaked

**[PASS] `delete` and `deleteAll` clear BOTH the shared group and the private
keychain.** This is the finding. Sign-out and burn previously issued a single
`SecItemDelete` scoped to the service; with an access group in play, that
deletes only the private copy and **leaves the household key sitting in a group
the extension can still read**. The app would believe the key was gone. Both
locations are now cleared unconditionally, in `delete`, `deleteAll` and on
every `write`.

**[PASS] `write` deletes from both locations before adding**, so a stale copy
in the other location cannot win the next read and serve an old key.

## Migration

**[PASS] Failure self-heals and is not fatal.** `migrateToAccessGroup` is
opportunistic, idempotent, and its result is ignored. Verified rather than
assumed: `KeyManager.loadHouseholdKey` falls back to `household_keys` on a
cache miss and re-derives the key, so a device that never migrates keeps
working — it just shows the generic notification body.

**[PASS] Group write falls back to the private keychain.** Without the
entitlement — simulator, or a signing misconfiguration — a group write fails
with `errSecMissingEntitlement`. Unhandled, the key would simply not be stored,
which would break offline decryption for the whole app rather than merely
degrade a notification. The fallback keeps the pre-Phase-C behaviour exactly.

**[PASS] `read` checks the group first, then the private keychain**, so every
existing install keeps working before any migration has run.

## The extension's failure behaviour

**[PASS] Every path ends at the generic body.** Missing `enc_title`, missing
`household_id`, no cached key, undecryptable ciphertext, empty plaintext,
timeout — all fall through to the body the payload arrived with.
`serviceExtensionTimeWillExpire` hands back `bestAttempt`, which is that same
generic content.

**[PASS] Proven, both directions.** `scripts/check_push_decrypt_e2e.sh`
encrypts a title with the household's real key (unwrapped by deriving the user
key from the uid, exactly as a client does) and asserts the displayed body is
the plaintext; then sends a title this household cannot open and asserts the
body stays generic. It reads the archived `body` field rather than grepping,
because both strings are present in a delivered payload and grep alone would
pass on a broken extension.

**[PASS] One crypto implementation.** The extension links `PacelliKit` and
calls the same `PacelliCrypto`; nothing is reimplemented, and the
cross-language vectors cover this path.

## Not verified here

- **Access-group ISOLATION is unverified.** The simulator does not enforce
  entitlements, so the decryption is proven but the boundary is not. Needs a
  device build once the extension has an App ID and profile.
- **Extension signing.** New App ID `com.pacelli.pacelli.NotificationService`
  plus a match appstore profile, which needs the certs repo writable. Until
  then the extension exists only in simulator builds.

## Open

- **Push bodies are English regardless of the user's language.** The server
  composes them, so a Spanish or Italian user gets English text — and after
  Phase C they get an English fallback whenever decryption fails. The APNs fix
  is `loc-key`/`title-loc-key` in the payload so iOS localises from the app's
  own strings. Not a security issue; it is a correctness one, and the app
  otherwise ships es/it.
