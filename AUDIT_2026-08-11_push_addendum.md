# Security audit addendum — push notifications (Phase B)

Scope: `device_tokens`, the token lifecycle, and the APNs payload. Companion
to `AUDIT_2026-08-09_1.2.0_addendum.md`. Phase C (the Notification Service
Extension and the Keychain access group) is **not** covered here and must not
ship without its own addendum — widening the keychain to a second process is a
real change to who can read the household key.

## The threat that matters

A `device_tokens` row says *"send this household's activity to this device."*
It is the only object in the system whose mere existence causes household data
to be transmitted somewhere. Everything else about push is secondary to who can
create one.

**[PASS] `create`/`update` require `isMember(household_id)`** —
`firestore.rules`. Without it any signed-in user could register their own
device against someone else's household id and receive that household's
notifications, without ever touching a ciphertext. Locked by
`firestore-tests/device-tokens.test.js` ("a stranger CANNOT register against a
household they are not in").

**[PASS] `update` checks the existing row as well as the incoming one.**
Checking only `request.resource` would let anyone who learned another device's
token rewrite the row to themselves and take over its pushes. The token is the
document id, so this is the difference between "hard to guess" and "enforced".

**[PASS] No cross-user reads.** `get`/`list` are scoped to
`user_id == request.auth.uid`, so tokens cannot be enumerated — by household or
at all. Self-listing is permitted because burn sweeps every device that way.

**[PASS] Field set pinned.** `keys().hasOnly([...])` on create and update.

## Token lifecycle

**[PASS] Revoked before the session ends.** `AppState.resetSession()` calls
`PushService.unregister()` *before* `Auth.signOut()`, and `BurnService` calls
`unregisterAllDevices()` while still authenticated. The rules key deletion to
`user_id == request.auth.uid`, so doing either afterwards is denied — and a
token that cannot be deleted keeps pushing a household's activity to a phone
that has left it. This ordering is the finding; the code without it looks
identical and fails silently.

**[PASS] Burn clears every device, sign-out only the current one.** Signing out
of one phone must not silence another; burning the account must silence all of
them.

**[PASS] Household changes re-register.** The row carries `household_id`, and
registration re-runs whenever `AppState.phase` lands on `.home`, so someone who
joins a different household stops receiving the old one's activity.

**[PASS] Dead tokens pruned** from the send result (`push.ts`). Retained
tokens are retried indefinitely and inflate every future send.

## Payload

**[PASS] No plaintext leaves the server.** `enc_title` is the byte-identical
ciphertext already at rest in Firestore (`TasksRepository` encrypts `title`
before write). No function decrypts anything; `push.ts` performs no crypto.

**[PASS] No content logged.** `logger.info("push sent", { attempted, ok,
pruned })` — counts only. `logger.warn` records an error code, never a title.

**[PASS] Visible body is generic and stays generic.** "A new task was added to
your household" is what iOS shows today and what it will still show whenever
the Phase C extension cannot decrypt. Failure degrades to privacy-safe text
rather than to a blank, a crash, or a leak.

**[NOTED] Ciphertext transits Apple's servers.** Encrypted with the household
key, which Apple never holds. Now stated explicitly on the Privacy &
Encryption screen — that screen's claims have to stay literally true, and push
had made it quietly incomplete.

**[NOTED] Metadata is visible to Apple**: that a notification was sent, when,
and to which device. Unavoidable for push, and it reveals activity timing but
no content.

## Platform

**[PASS] Entitlements still minimal** — `aps-environment` (required for push)
and `com.apple.developer.applesignin`. `aps-environment` is per-configuration
(`development` for Debug, `production` for Release); the App Store match
profile already carried `aps-environment: production`, verified against the
profile before the entitlement was added, so the release pipeline was never at
risk.

## Verified, not assumed

- 14 rules tests for `device_tokens`; 84 rules tests overall, all passing.
- `scripts/check_push_e2e.sh` — fresh install → token registered → **nothing
  delivered while opted out** → opt in → notification actually delivered. The
  negative assertion is the important one: a push feature that ignores its own
  opt-in passes every other test.
- The delivered payload was inspected directly: `enc_title` carried the
  ciphertext verbatim, `mutable-content: 1` present for Phase C.

## Open

- **Phase C needs its own addendum before shipping** — Keychain access group,
  extension entitlements, and the 30-second decryption budget.
- Rate limiting: a member can trigger a push per task created. Bounded by
  household size and unremarkable for two people, but worth a cap if households
  ever grow.
